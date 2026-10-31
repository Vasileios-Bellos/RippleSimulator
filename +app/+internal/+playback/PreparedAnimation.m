classdef (Sealed) PreparedAnimation
    % PREPAREDANIMATION Superimpose precomputed wave responses.
    %   A rolling elevation sequence stores the sum of accepted sources. Ninth-
    %   degree temporal interpolation preserves continuous elapsed-time playback.
    %   Sources crossing an interpolation stencil's onset or endpoint use their
    %   precomputed response directly to preserve causality and exact retirement.

    properties (SetAccess = private)
        Step (1, 1) double
        Duration (1, 1) double
        CurrentTime (1, 1) double
        Resolution (1, 1) double
    end

    properties (Constant)
        SamplesPerTimeScale = 14
        InterpolationPadding = 13
    end

    properties (Constant, Access = private)
        TranslationByteLimit = 8388608
        FullTranslationByteLimit = 33554432
        InterpolationOffsets = -4:5
    end

    properties (Dependent, SetAccess = private)
        MemoryBytes (1, 1) double
        IsEmpty (1, 1) logical
        SourceCount (1, 1) double
    end

    properties (Access = private)
        Response
        Modal (1, 1) logical
        TimeScale (1, 1) double
        ForcingDuration (1, 1) double = 0
        FirstIndex (1, 1) double = 0
        LastIndex (1, 1) double = -1
        SampleCapacity (1, 1) double
        Frames (:, :) single = zeros(0, 0, "single")
        Zero (:, 1) single
        Sources (1, :) struct = struct("Time", {}, "Strength", {}, "Indices", {}, "Coefficients", {})
    end

    methods
        function obj = PreparedAnimation(response, timeScale, periods, time, options)
        % PREPAREDANIMATION Prepare a sequence of grid elevations or modal coefficients.
            arguments
                response (1, 1) {mustBeA(response, ...
                    ["app.internal.responses.LatticeResponse", "app.internal.responses.ModalResponseTable"])}
                timeScale (1, 1) double {mustBeFinite, mustBePositive}
                periods (1, 1) double {mustBeFinite, mustBePositive}
                time (1, 1) double {mustBeFinite, mustBeNonnegative} = 0
                options.Resolution (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
                options.ForcingDuration (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 0
            end
            obj.Response = response;
            obj.Modal = isa(response, "app.internal.responses.ModalResponseTable");
            obj.TimeScale = timeScale;
            obj.Step = timeScale/obj.SamplesPerTimeScale;
            obj.Duration = timeScale*periods;
            obj.SampleCapacity = ceil(periods*obj.SamplesPerTimeScale)+obj.InterpolationPadding;
            obj.ForcingDuration = options.ForcingDuration;
            obj.CurrentTime = time;
            if obj.Modal
                assert(options.Resolution > 0, "RippleSimulator:AnimationShape", ...
                    "Modal animation requires a positive coefficient-matrix size.");
                obj.Resolution = options.Resolution;
            else
                obj.Resolution = response.Resolution;
            end
            obj.Zero = zeros(obj.Resolution^2, 1, "single");
        end

        function value = get.MemoryBytes(obj)
            value = 4*(numel(obj.Frames)+numel(obj.Zero)*(1+2*numel(obj.Sources)));
        end

        function value = get.IsEmpty(obj)
            value = isempty(obj.Sources);
        end

        function value = get.SourceCount(obj)
            value = numel(obj.Sources);
        end

        function obj = add(obj, startTime, strength, indices, coefficients)
        % ADD Superimpose one complete elevation sequence at its exact onset.
            arguments
                obj (1, 1) app.internal.playback.PreparedAnimation
                startTime (1, 1) double {mustBeFinite, mustBeNonnegative}
                strength (1, 1) double {mustBeFinite, mustBeNonnegative}
                indices (:, :) uint32
                coefficients (:, 1) double {mustBeReal, mustBeFinite} = 1
            end
            assert(isequal(size(indices), [obj.Resolution, obj.Resolution]), ...
                "RippleSimulator:AnimationMapping", "The source map must match the animation grid.");
            assert(isscalar(coefficients) || numel(coefficients) == numel(indices), ...
                "RippleSimulator:AnimationCoefficients", "Source coefficients must match the animation grid.");
            if strength == 0 || startTime+obj.Duration <= obj.CurrentTime
                return
            end
            obj = obj.advanceTo(max(obj.CurrentTime, startTime));
            first = floor(obj.CurrentTime/obj.Step)+obj.InterpolationOffsets(1);
            last = ceil((startTime+obj.Duration)/obj.Step)+obj.InterpolationOffsets(end);
            resetSlots = zeros(1, 0);
            if isempty(obj.Frames)
                obj.FirstIndex = first;
                obj.LastIndex = last;
                capacity = obj.SampleCapacity;
                frames = zeros(numel(obj.Zero), capacity, "single");
            else
                frames = obj.Frames;
                if last > obj.LastIndex
                    newNodes = max(first, obj.LastIndex+1):last;
                    resetSlots = mod(newNodes, size(frames, 2))+1;
                    obj.LastIndex = last;
                end
            end
            nodes = max(first, ceil(startTime/obj.Step)):ceil((startTime+obj.Duration)/obj.Step)-1;
            profiles = obj.profiles(nodes*obj.Step-startTime, strength);
            lookup = indices(:);
            capacity = size(frames, 2);
            if 4*numel(frames) <= obj.FullTranslationByteLimit
                alignedProfiles = zeros(size(profiles, 1), capacity, "single");
                alignedProfiles(:, mod(nodes, capacity)+1) = profiles;
                % Replace recycled slots after addition to avoid an earlier copy of the sequence.
                if obj.Modal
                    frames = frames+single(coefficients).*alignedProfiles(lookup, :);
                    frames(:, resetSlots) = single(coefficients).*alignedProfiles(lookup, resetSlots);
                else
                    frames = frames+alignedProfiles(lookup, :);
                    frames(:, resetSlots) = alignedProfiles(lookup, resetSlots);
                end
            else
                frames(:, resetSlots) = 0;
                batchSize = max(1, min(64, floor(obj.TranslationByteLimit/(4*numel(lookup)))));
                for firstNode = 1:batchSize:numel(nodes)
                    lastNode = min(firstNode+batchSize-1, numel(nodes));
                    contributions = profiles(lookup, firstNode:lastNode);
                    if obj.Modal
                        contributions = single(coefficients).*contributions;
                    end
                    slots = mod(nodes(firstNode:lastNode), capacity)+1;
                    frames(:, slots) = frames(:, slots)+contributions;
                end
            end
            obj.Frames = frames;
            obj.Sources(end+1) = struct(Time=startTime, Strength=strength, Indices=indices, ...
                Coefficients=single(coefficients));
        end

        function obj = advanceTo(obj, time)
        % ADVANCETO Release past frames while retaining the interpolation stencil.
            arguments
                obj (1, 1) app.internal.playback.PreparedAnimation
                time (1, 1) double {mustBeFinite, mustBeNonnegative}
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
                return
            end
            obj.FirstIndex = floor(time/obj.Step)+obj.InterpolationOffsets(1);
        end

        function elevation = sample(obj)
        % SAMPLE Interpolate the accumulated field at the current physical time.
            elevation = obj.Zero;
            if isempty(obj.Frames) || isempty(obj.Sources)
                elevation = reshape(double(elevation), obj.Resolution, obj.Resolution);
                return
            end
            ages = obj.CurrentTime-[obj.Sources.Time];
            stencilRadius = obj.InterpolationOffsets(end)*obj.Step;
            crossings = ages < obj.ForcingDuration+stencilRadius | abs(ages-obj.Duration) < stencilRadius;
            if all(crossings)
                for source = obj.Sources
                    profile = obj.profiles(obj.CurrentTime-source.Time);
                    elevation = elevation+single(source.Strength)*source.Coefficients.*profile(source.Indices(:));
                end
                elevation = reshape(double(elevation), obj.Resolution, obj.Resolution);
                return
            end
            left = floor(obj.CurrentTime/obj.Step);
            nodes = left+obj.InterpolationOffsets;
            fraction = single(obj.CurrentTime/obj.Step-left);
            weights = interpolationWeights(fraction, obj.InterpolationOffsets);
            for index = 1:numel(nodes)
                if nodes(index) >= obj.FirstIndex && nodes(index) <= obj.LastIndex
                    slot = mod(nodes(index), size(obj.Frames, 2))+1;
                    elevation = elevation+weights(index)*obj.Frames(:, slot);
                end
            end
            for index = reshape(find(crossings), 1, [])
                source = obj.Sources(index);
                stencil = obj.profiles(nodes*obj.Step-source.Time);
                correction = obj.profiles(ages(index))-stencil*weights';
                elevation = elevation+single(source.Strength)*source.Coefficients.*correction(source.Indices(:));
            end
            if all(ages <= 0 | ages >= obj.Duration-8*eps(obj.Duration))
                elevation(:) = 0;
            end
            elevation = reshape(double(elevation), obj.Resolution, obj.Resolution);
        end
    end

    methods (Static)
        function bytes = estimateBytes(resolution, periods, sourceCount)
        % ESTIMATEBYTES Bound the sequence, zero field, and source-map storage.
            arguments
                resolution (1, 1) double {mustBeInteger, mustBePositive}
                periods (1, 1) double {mustBeFinite, mustBePositive}
                sourceCount (1, 1) double {mustBeInteger, mustBeNonnegative}
            end
            capacity = ceil(periods*app.internal.playback.PreparedAnimation.SamplesPerTimeScale) ...
                + app.internal.playback.PreparedAnimation.InterpolationPadding;
            bytes = 4*resolution^2*(capacity+1+2*sourceCount);
        end
    end

    methods (Access = private)
        function elevation = profiles(obj, ages, strength)
            if nargin < 3
                strength = 1;
            end
            response = obj.Response;
            offset = double(obj.Modal);
            elevation = zeros(size(response.Elevations, 1)+offset, numel(ages), "single");
            valid = ages > 0 & ages < obj.Duration-8*eps(obj.Duration);
            query = ages(valid);
            if isempty(query)
                return
            end
            indices = discretize(query, response.Times);
            steps = response.Times(indices+1)-response.Times(indices);
            fraction = single((query-response.Times(indices))./steps);
            envelope = app.internal.responses.SettlingEnvelope.sample(query, obj.TimeScale, obj.Duration/obj.TimeScale);
            weights = single(strength*envelope).*[2*fraction.^3-3*fraction.^2+1; ...
                single(steps).*(fraction.^3-2*fraction.^2+fraction); ...
                -2*fraction.^3+3*fraction.^2; single(steps).*(fraction.^3-fraction.^2)];
            elevations = response.Elevations;
            velocities = response.Velocities;
            columns = find(valid);
            for index = 1:numel(query)
                node = indices(index);
                elevation(1+offset:end, columns(index)) = weights(1, index).*elevations(:, node) ...
                    + weights(2, index).*velocities(:, node) ...
                    + weights(3, index).*elevations(:, node+1) ...
                    + weights(4, index).*velocities(:, node+1);
            end
        end
    end
end

function weights = interpolationWeights(fraction, nodes)
    weights = ones(1, numel(nodes), "single");
    for index = 1:numel(nodes)
        others = nodes(nodes ~= nodes(index));
        weights(index) = prod((fraction-others)./(nodes(index)-others));
    end
end
