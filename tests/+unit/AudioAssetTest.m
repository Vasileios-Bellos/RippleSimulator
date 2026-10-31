classdef (Sealed) AudioAssetTest < support.ProjectTestCase
    % AUDIOASSETTEST Verify that packaged audio resources can be decoded.

    properties (TestParameter)
        Recording = {"splash.mp3", "rain.mp3"}
    end

    methods (Test, TestTags = {'Unit'})
        function recordingHasValidSamples(testCase, Recording)
            implementation = which("app.internal.audio.SplashAudio");
            filename = fullfile(fileparts(implementation), "assets", Recording);

            [samples, sampleRate] = audioread(filename);

            testCase.verifyGreaterThan(sampleRate, 0);
            testCase.verifyNotEmpty(samples);
            testCase.verifyTrue(all(isfinite(samples), "all"));
            testCase.verifyGreaterThan(max(abs(samples), [], "all"), 0);
        end
    end
end
