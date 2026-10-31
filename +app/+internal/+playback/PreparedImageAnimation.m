classdef (Sealed) PreparedImageAnimation
    % PREPAREDIMAGEANIMATION Accumulate partially reflected surface elevations.
    %   Spatial factors produce each source's elevation history at its exact onset.
    %   Direct onset corrections use the simulation's existing source maps.
    %   Five retained endpoint samples remove expired-source interpolation.

    properties (SetAccess = private)
        Step (1, 1) double
        Duration (1, 1) double
        CurrentTime (1, 1) double
        Resolution (1, 1) double
    end

    properties (Constant)
        SamplesPerTimeScale = 16
        InterpolationPadding = 13
    end

    properties (Dependent, SetAccess = private)
        MemoryBytes (1, 1) double
        SourceCount (1, 1) double
    end

    properties (Constant, Access = private)
        InterpolationOffsets = -4:5
        TailSamples = 5
        TranslationByteLimit = 8388608
        FullTranslationByteLimit = 33554432
    end

    properties (Access = private)
        Response app.internal.responses.ImageResponse
        ForcingDuration (1, 1) double
        SampleCapacity (1, 1) double
        FirstIndex (1, 1) double = 0
        LastIndex (1, 1) double = -1
        Frames (:, :) single = zeros(0, 0, "single")
        Zero (:, 1) single
        Sources (1, :) struct = struct("Id", {}, "Time", {}, "Strength", {}, "LastNode", {}, "Tail", {})
    end

    methods
        function obj = PreparedImageAnimation(response, resolution, periods, time)
        % PREPAREDIMAGEANIMATION Define a bounded, elapsed-time display sequence.
            arguments
                response (1, 1) app.internal.responses.ImageResponse
                resolution (1, 1) double {mustBeInteger, mustBePositive}
                periods (1, 1) double {mustBeReal, mustBeFinite, mustBePositive, mustBeLessThanOrEqual(periods, 10)}
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 0
            end
            obj.Response = response;
            obj.Resolution = resolution;
            obj.Step = response.TimeScale/obj.SamplesPerTimeScale;
            obj.Duration = periods*response.TimeScale;
            obj.CurrentTime = time;
            obj.SampleCapacity = ceil(periods*obj.SamplesPerTimeScale)+obj.InterpolationPadding;
            obj.Zero = zeros(resolution^2, 1, "single");
            obj.ForcingDuration = 4*response.Period*(response.Source.Mode == "Wavemaker" ...
                && response.TimeScale > response.Period);
        end

        function value = get.MemoryBytes(obj)
            value = 4*(numel(obj.Frames)+numel(obj.Zero)*(1+obj.TailSamples*numel(obj.Sources)));
        end

        function value = get.SourceCount(obj)
            value = numel(obj.Sources);
        end

        function obj = add(obj, time, strength, mapping, identifier)
        % ADD Superimpose a source while retaining only its endpoint samples.
            arguments
                obj (1, 1) app.internal.playback.PreparedImageAnimation
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                strength (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                mapping (1, 1) struct
                identifier (1, 1) double {mustBeInteger, mustBePositive}
            end
            assert(isequal(size(mapping.SpatialBasis), [obj.Resolution^2, obj.Response.Separated.Rank]), ...
                "RippleSimulator:AnimationMapping", "The source map must match the animation grid and response.");
            if strength == 0 || time+obj.Duration <= obj.CurrentTime
                return
            end
            obj = obj.advanceTo(max(obj.CurrentTime, time));
            capacity = obj.SampleCapacity;
            first = floor(obj.CurrentTime/obj.Step)+obj.InterpolationOffsets(1);
            last = ceil((time+obj.Duration)/obj.Step)+obj.InterpolationOffsets(end);
            reset = zeros(1, 0);
            if isempty(obj.Frames)
                frames = zeros(numel(obj.Zero), capacity, "single");
            else
                frames = obj.Frames;
                reset = mod(max(first, obj.LastIndex+1):last, capacity)+1;
            end
            obj.FirstIndex = first;
            obj.LastIndex = last;
            lastNode = ceil((time+obj.Duration)/obj.Step)-1;
            nodes = max(first, ceil(time/obj.Step)):lastNode;
            profiles = single(strength)*obj.profiles(nodes*obj.Step-time);
            basis = mapping.SpatialBasis;
            tail = zeros(numel(obj.Zero), obj.TailSamples, "single");
            if 4*numel(frames) <= obj.FullTranslationByteLimit
                temporal = zeros(size(profiles, 1), capacity, "single");
                temporal(:, mod(nodes, capacity)+1) = profiles;
                contribution = basis*temporal;
                frames = frames+contribution;
                frames(:, reset) = contribution(:, reset);
                tail = contribution(:, mod(lastNode-obj.TailSamples+1:lastNode, capacity)+1);
            else
                frames(:, reset) = 0;
                blockSize = max(1, min(64, floor(obj.TranslationByteLimit/(4*numel(obj.Zero)))));
                for start = 1:blockSize:numel(nodes)
                    columns = start:min(start+blockSize-1, numel(nodes));
                    contribution = basis*profiles(:, columns);
                    slots = mod(nodes(columns), capacity)+1;
                    frames(:, slots) = frames(:, slots)+contribution;
                    tailIndices = nodes(columns)-lastNode+obj.TailSamples;
                    selected = tailIndices >= 1 & tailIndices <= obj.TailSamples;
                    tail(:, tailIndices(selected)) = contribution(:, selected);
                end
            end
            obj.Frames = frames;
            obj.Sources(end+1) = struct(Id=identifier, Time=time, Strength=strength, LastNode=lastNode, Tail=tail);
        end

        function obj = advanceTo(obj, time)
        % ADVANCETO Retire source corrections after their interpolation stencils.
            arguments
                obj (1, 1) app.internal.playback.PreparedImageAnimation
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(time >= obj.CurrentTime, "RippleSimulator:AnimationTime", ...
                "Animation time cannot move backward.");
            obj.CurrentTime = time;
            if isempty(obj.Sources)
                return
            end
            deadlines = [obj.Sources.Time]+obj.Duration;
            expired = time >= deadlines+obj.InterpolationOffsets(end)*obj.Step;
            if all(time >= deadlines)
                expired(:) = true;
            end
            obj.Sources(expired) = [];
            if isempty(obj.Sources)
                obj.Frames = zeros(0, 0, "single");
                obj.LastIndex = -1;
            end
            obj.FirstIndex = floor(time/obj.Step)+obj.InterpolationOffsets(1);
        end

        function elevation = sample(obj, events)
        % SAMPLE Reconstruct the field with exact source-onset and endpoint treatment.
            arguments
                obj (1, 1) app.internal.playback.PreparedImageAnimation
                events (1, :) struct
            end
            elevation = obj.Zero;
            if isempty(obj.Sources)
                elevation = reshape(double(elevation), obj.Resolution, obj.Resolution);
                return
            end
            ages = obj.CurrentTime-[obj.Sources.Time];
            radius = obj.InterpolationOffsets(end)*obj.Step;
            crossings = ages < obj.ForcingDuration+radius | abs(ages-obj.Duration) < radius;
            if all(crossings)
                for source = obj.Sources
                    age = obj.CurrentTime-source.Time;
                    if age > 0 && age < obj.Duration-8*eps(obj.Duration)
                        basis = sourceBasis(events, source.Id);
                        elevation = elevation+basis*(single(source.Strength)*obj.profiles(age));
                    end
                end
                elevation = reshape(double(elevation), obj.Resolution, obj.Resolution);
                return
            end
            left = floor(obj.CurrentTime/obj.Step);
            nodes = left+obj.InterpolationOffsets;
            weights = interpolationWeights(single(obj.CurrentTime/obj.Step-left), obj.InterpolationOffsets);
            valid = nodes >= obj.FirstIndex & nodes <= obj.LastIndex;
            elevation = obj.Frames(:, mod(nodes(valid), size(obj.Frames, 2))+1)*weights(valid)';
            for index = reshape(find(crossings), 1, [])
                source = obj.Sources(index);
                if ages(index) >= obj.Duration-8*eps(obj.Duration)
                    tailIndices = nodes-source.LastNode+obj.TailSamples;
                    selected = tailIndices >= 1 & tailIndices <= obj.TailSamples;
                    elevation = elevation-source.Tail(:, tailIndices(selected))*weights(selected)';
                else
                    basis = sourceBasis(events, source.Id);
                    correction = obj.profiles(ages(index))-obj.profiles(nodes*obj.Step-source.Time)*weights';
                    elevation = elevation+basis*(single(source.Strength)*correction);
                end
            end
            elevation = reshape(double(elevation), obj.Resolution, obj.Resolution);
        end
    end

    methods (Static)
        function bytes = estimateBytes(resolution, periods, sourceCount)
        % ESTIMATEBYTES Bound retained frames and endpoint corrections in bytes.
            arguments
                resolution (1, 1) double {mustBeInteger, mustBePositive}
                periods (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                sourceCount (1, 1) double {mustBeInteger, mustBeNonnegative}
            end
            capacity = ceil(periods*app.internal.playback.PreparedImageAnimation.SamplesPerTimeScale) ...
                + app.internal.playback.PreparedImageAnimation.InterpolationPadding;
            bytes = 4*resolution^2*(capacity+1+app.internal.playback.PreparedImageAnimation.TailSamples*sourceCount);
        end
    end

    methods (Access = private)
        function values = profiles(obj, ages)
            separated = obj.Response.Separated;
            values = zeros(separated.Rank, numel(ages), "single");
            valid = ages > 0 & ages < obj.Duration-8*eps(obj.Duration);
            query = ages(valid);
            if isempty(query)
                return
            end
            indices = discretize(query, separated.Times);
            steps = separated.Times(indices+1)-separated.Times(indices);
            fraction = (query-separated.Times(indices))./steps;
            count = numel(separated.Times);
            factors = separated.Coefficients;
            profiles = (2*fraction.^3-3*fraction.^2+1).*factors(:, indices) ...
                + separated.Frequency*steps.*(fraction.^3-2*fraction.^2+fraction).*factors(:, indices+count) ...
                + (-2*fraction.^3+3*fraction.^2).*factors(:, indices+1) ...
                + separated.Frequency*steps.*(fraction.^3-fraction.^2).*factors(:, indices+count+1);
            envelope = app.internal.responses.SettlingEnvelope.sample(query, obj.Response.TimeScale, ...
                obj.Duration/obj.Response.TimeScale);
            values(:, valid) = single(envelope.*profiles);
        end
    end
end

function basis = sourceBasis(events, identifier)
    selected = find([events.Id] == identifier, 1);
    assert(~isempty(selected), "RippleSimulator:AnimationSource", ...
        "An active animation source is missing its physical response map.");
    basis = events(selected).Mapping.SpatialBasis;
end

function weights = interpolationWeights(fraction, nodes)
    weights = ones(1, numel(nodes), "single");
    for index = 1:numel(nodes)
        others = nodes(nodes ~= nodes(index));
        weights(index) = prod((fraction-others)./(nodes(index)-others));
    end
end
