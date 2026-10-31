classdef (Sealed) SplashAudio < handle
    % SPLASHAUDIO Play preloaded splash and rain recordings with an audio fallback.
    %   The splash recording is normalized once and played at twice
    %   its recorded sample rate.
    %   Each rain burst plays its own recording at the recorded sample rate.

    properties (SetAccess = private)
        % Available Whether an initialized playback backend is usable.
        Available (1, 1) logical = false
        % FailureMessage Most recent audio initialization or device error.
        FailureMessage (1, 1) string = ""
        % Backend Active Java or MATLAB playback implementation.
        Backend (1, 1) string = "None"
        % SkippedSounds Sounds omitted while all voices for that input are busy.
        SkippedSounds (1, 1) double = 0
    end

    properties (Access = private)
        Players (1, :) cell = {}
        AutoclickPlayers (1, :) cell = {}
        RainPlayers (1, :) cell = {}
        AutoclickPlayer = []
        MatlabPool = []
        Clips (1, :) cell = {}
        ClipGains (1, :) cell = {}
        ClipLevels (1, 16) double = ones(1, 16)
        RainClips (1, :) cell = {}
        AutoclickClip = []
        MatlabReady (1, 1) logical = false
        AutomaticPlayback (1, 1) string = "Overlap"
        ClipUsed (1, 16) logical = false(1, 16)
        RainClipUsed (1, 20) logical = false(1, 20)
        AutoclickClipUsed (1, 1) logical = false
        AutoclickDecibels (1, 1) single
    end

    properties (Constant, Access = private)
        AutoclickGain = 0.8
    end

    methods
        function obj = SplashAudio(options)
            arguments
                options.PreferJava (1, 1) logical = true
                options.AutomaticPlayback (1, 1) string ...
                    {mustBeMember(options.AutomaticPlayback, ["Overlap", "Finish", "Restart"])} = "Overlap"
            end
            obj.AutomaticPlayback = options.AutomaticPlayback;
            obj.AutoclickDecibels = single(20*log10(obj.AutoclickGain));
            try
                filename = fullfile(fileparts(mfilename("fullpath")), "assets", "splash.mp3");
                [samples, sampleRate] = audioread(filename);
                peak = max(abs(samples), [], "all");
                if peak > 0
                    samples = samples/peak;
                end
                sampleRate = 2*sampleRate;
                rainFile = fullfile(fileparts(filename), "rain.mp3");
                [rainSamples, rainSampleRate] = audioread(rainFile);
            catch exception
                obj.FailureMessage = string(exception.message);
                return
            end
            % Prepare fallback voices before accepting interactive input.
            try
                obj.Players = cell(1, 16);
                obj.AutoclickPlayers = cell(1, 16);
                automaticSamples = obj.AutoclickGain*samples;
                for index = 1:numel(obj.Players)
                    obj.Players{index} = audioplayer(samples, sampleRate, 16);
                    obj.AutoclickPlayers{index} = audioplayer(automaticSamples, sampleRate, 16); %#ok<TNMLP>
                end
                obj.RainPlayers = cell(1, 20);
                % Each overlapping recording requires an independent playback handle.
                for index = 1:numel(obj.RainPlayers)
                    obj.RainPlayers{index} = audioplayer(rainSamples, rainSampleRate, 16); %#ok<TNMLP>
                end
                obj.AutoclickPlayer = audioplayer(obj.AutoclickGain*samples, sampleRate, 16);
                obj.MatlabPool = app.internal.audio.PlayerPool( ...
                    [obj.Players, obj.AutoclickPlayers, obj.RainPlayers, {obj.AutoclickPlayer}]);
                obj.MatlabReady = true;
                obj.Backend = "MATLAB";
                obj.Available = true;
            catch exception
                obj.FailureMessage = string(exception.message);
            end
            if options.PreferJava
                try
                    format = javaObject("javax.sound.sampled.AudioFormat", single(sampleRate), ...
                        int32(16), int32(size(samples, 2)), true, false);
                    controlClass = javaMethod("forName", "java.lang.Class", ...
                        "javax.sound.sampled.BooleanControl$Type");
                    muteType = controlClass.getField("MUTE").get([]);
                    gainClass = javaMethod("forName", "java.lang.Class", "javax.sound.sampled.FloatControl$Type");
                    gainType = gainClass.getField("MASTER_GAIN").get([]);
                    bytes = encodePcm(samples);
                    obj.Clips = cell(1, 16);
                    obj.ClipGains = cell(size(obj.Clips));
                    for index = 1:numel(obj.Clips)
                        obj.Clips{index} = openClip(format, bytes, muteType);
                        obj.ClipGains{index} = obj.Clips{index}.getControl(gainType);
                        obj.ClipGains{index}.setValue(single(0));
                    end
                    obj.RainClips = cell(1, 20);
                    rainFormat = javaObject("javax.sound.sampled.AudioFormat", single(rainSampleRate), ...
                        int32(16), int32(size(rainSamples, 2)), true, false);
                    rainBytes = encodePcm(rainSamples);
                    for index = 1:numel(obj.RainClips)
                        obj.RainClips{index} = openClip(rainFormat, rainBytes, muteType);
                    end
                    obj.AutoclickClip = openClip(format, encodePcm(obj.AutoclickGain*samples), muteType);
                    obj.Backend = "Java";
                    obj.Available = true;
                catch exception
                    obj.FailureMessage = string(exception.message);
                    obj.closeClips();
                end
            end
        end

        function play(obj)
        % PLAY Start a splash without interrupting sounds already playing.
            obj.playVoice("Manual");
        end

        function playAutomatic(obj, kind)
        % PLAYAUTOMATIC Start a rain recording or an Auto-click splash.
            arguments
                obj (1, 1) app.internal.audio.SplashAudio
                kind (1, 1) string {mustBeMember(kind, ["Rain", "Autoclick"])}
            end
            obj.playVoice(kind);
        end

        function stop(obj)
        % STOP End only audio playback owned by this application.
            if ~isvalid(obj)
                return
            end
            obj.stopVoices();
        end

        function delete(obj)
            players = [obj.Players, obj.AutoclickPlayers, obj.RainPlayers, {obj.AutoclickPlayer}];
            obj.Available = false;
            obj.stopVoices();
            obj.closeClips();
            if ~isempty(obj.MatlabPool)
                obj.MatlabPool.close();
                obj.MatlabPool = [];
                players = {};
            end
            obj.Players = {};
            obj.AutoclickPlayers = {};
            obj.RainPlayers = {};
            obj.AutoclickPlayer = [];
            for index = 1:numel(players)
                player = players{index};
                try
                    if ~isempty(player) && isvalid(player)
                        delete(player);
                    end
                catch exception
                    obj.FailureMessage = string(exception.message);
                end
            end
        end
    end

    methods (Access = private)
        function stopVoices(obj)
            players = [obj.Players, obj.AutoclickPlayers, obj.RainPlayers, {obj.AutoclickPlayer}];
            for index = 1:numel(players)
                player = players{index};
                try
                    if ~isempty(player) && isvalid(player) && isplaying(player)
                        stop(player);
                    end
                catch exception
                    obj.FailureMessage = string(exception.message);
                end
            end
            clips = [obj.Clips, obj.RainClips, {obj.AutoclickClip}];
            for index = 1:numel(clips)
                try
                    if ~isempty(clips{index}) && clips{index}.isOpen()
                        clips{index}.stop();
                    end
                catch exception
                    obj.FailureMessage = string(exception.message);
                end
            end
            obj.ClipUsed(:) = false;
            obj.RainClipUsed(:) = false;
            obj.AutoclickClipUsed = false;
        end

        function playVoice(obj, kind)
            if ~isvalid(obj) || ~obj.Available
                return
            end
            try
                if obj.Backend == "Java"
                    obj.startJavaVoice(kind);
                else
                    obj.startMatlabVoice(kind);
                end
            catch exception
                obj.FailureMessage = string(exception.message);
                if obj.Backend == "Java" && obj.MatlabReady
                    obj.Backend = "MATLAB";
                    try
                        obj.startMatlabVoice(kind);
                    catch fallbackException
                        obj.FailureMessage = string(fallbackException.message);
                        obj.Available = false;
                    end
                else
                    obj.Available = false;
                end
            end
        end

        function startJavaVoice(obj, kind)
            if kind ~= "Autoclick" || obj.AutomaticPlayback == "Overlap"
                if kind ~= "Rain"
                    clips = obj.Clips;
                    used = obj.ClipUsed;
                else
                    clips = obj.RainClips;
                    used = obj.RainClipUsed;
                end
                for index = 1:numel(clips)
                    clip = clips{index};
                    if ~obj.clipBusy(clip, used(index))
                        if kind ~= "Rain"
                            obj.setClipGain(index, kind == "Autoclick");
                            obj.ClipUsed(index) = true;
                        else
                            obj.RainClipUsed(index) = true;
                        end
                        startClip(clip);
                        return
                    end
                end
                % Voice saturation affects sound only; wave inputs remain independent.
                obj.SkippedSounds = obj.SkippedSounds+1;
                return
            end
            busy = obj.clipBusy(obj.AutoclickClip, obj.AutoclickClipUsed);
            if busy && obj.AutomaticPlayback == "Finish"
                return
            end
            if busy
                obj.AutoclickClip.stop();
                obj.AutoclickClipUsed = false;
            end
            obj.AutoclickClipUsed = true;
            startClip(obj.AutoclickClip);
        end

        function value = clipBusy(~, clip, used)
        % Reserve a started voice while the audio thread begins playback.
            assert(clip.isOpen(), "RippleSimulator:AudioClipClosed", "The audio clip is closed.");
            value = used && (clip.isRunning() || clip.isActive() || ...
                clip.getFramePosition() < clip.getFrameLength());
        end

        function setClipGain(obj, index, automatic)
            gain = 1;
            decibels = single(0);
            if automatic
                gain = obj.AutoclickGain;
                decibels = obj.AutoclickDecibels;
            end
            if gain ~= obj.ClipLevels(index)
                obj.ClipGains{index}.setValue(decibels);
                obj.ClipLevels(index) = gain;
            end
        end

        function startMatlabVoice(obj, kind)
            if kind ~= "Autoclick" || obj.AutomaticPlayback == "Overlap"
                if kind == "Manual"
                    players = obj.Players;
                    offset = 0;
                    pairedOffset = numel(obj.Players);
                elseif kind == "Autoclick"
                    players = obj.AutoclickPlayers;
                    offset = numel(obj.Players);
                    pairedOffset = 0;
                else
                    players = obj.RainPlayers;
                    offset = numel(obj.Players)+numel(obj.AutoclickPlayers);
                    pairedOffset = offset;
                end
                for index = 1:numel(players)
                    if obj.MatlabPool.isAvailable(offset+index) ...
                            && obj.MatlabPool.isAvailable(pairedOffset+index)
                        obj.MatlabPool.play(offset+index);
                        return
                    end
                end
                obj.SkippedSounds = obj.SkippedSounds+1;
                return
            end
            voice = numel(obj.Players)+numel(obj.AutoclickPlayers)+numel(obj.RainPlayers)+1;
            busy = ~obj.MatlabPool.isAvailable(voice);
            if busy && obj.AutomaticPlayback == "Finish"
                return
            end
            if busy
                stop(obj.AutoclickPlayer);
            end
            if obj.MatlabPool.isAvailable(voice)
                obj.MatlabPool.play(voice);
            end
        end

        function closeClips(obj)
            clips = [obj.Clips, obj.RainClips, {obj.AutoclickClip}];
            obj.Clips = {};
            obj.ClipGains = {};
            obj.RainClips = {};
            obj.AutoclickClip = [];
            for index = 1:numel(clips)
                try
                    if ~isempty(clips{index})
                        clips{index}.close();
                    end
                catch exception
                    obj.FailureMessage = string(exception.message);
                end
            end
        end
    end
end

function bytes = encodePcm(samples)
    samples = min(1, max(-1, samples));
    % Interleave stereo channels in signed, little-endian, 16-bit sample frames.
    bytes = typecast(reshape(int16(32767*samples.'), 1, []), "int8");
end

function clip = openClip(format, bytes, muteType)
    clip = javaMethod("getClip", "javax.sound.sampled.AudioSystem");
    try
        clip.open(format, bytes, int32(0), int32(numel(bytes)));
        assert(clip.isControlSupported(muteType), "RippleSimulator:AudioInitialization", ...
            "This Java audio device does not support silent initialization.");
        mute = clip.getControl(muteType);
        previous = mute.getValue();
        % Initialize the device stream silently before accepting interactive input.
        mute.setValue(true);
        clip.start();
        clip.stop();
        clip.setFramePosition(int32(0));
        mute.setValue(previous);
    catch exception
        clip.close();
        rethrow(exception);
    end
end

function startClip(clip)
    assert(clip.isOpen(), "RippleSimulator:AudioClipClosed", "The audio clip is closed.");
    clip.setFramePosition(int32(0));
    clip.start();
end
