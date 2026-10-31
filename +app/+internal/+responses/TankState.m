classdef (Sealed) TankState
    % TANKSTATE Combine impulse histories in the full viscous exponential basis.
    %   The paired poles and branch quadrature are summed at the latest source
    %   time. Subsequent samples evolve that sum directly, without a time step
    %   or temporal interpolation. Accepted events remain the authoritative state.

    properties (SetAccess = immutable)
        EventIds (1, :) double
        ReferenceTime (1, 1) double
        Response app.internal.responses.TankResponse
        EvenAmplitude (:, 1) double
        OddAmplitude (:, 1) double
        BranchAmplitude (:, :) double
        ReferenceElevation (:, 1) double
        ReferenceVelocity (:, 1) double
        MemoryBytes (1, 1) double
    end

    methods
        function obj = TankState(response, events)
            arguments
                response (1, 1) app.internal.responses.TankResponse
                events (1, :) struct
            end
            assert(~isempty(events) && response.Source.Mode == "Impulse", "RippleSimulator:TankStateSource", ...
                "A combined modal state requires at least one pressure impulse.");
            obj.Response = response;
            obj.EventIds = [events.Id];
            obj.ReferenceTime = max([events.Time]);
            indices = reshape(response.ModeIndex(2:end), [], 1);
            kernel = response.Kernel;
            separation = (kernel.Poles(:, 1) - kernel.Poles(:, 2))/2;
            meanPole = sum(kernel.Poles, 2)/2;
            first = complex(zeros(numel(indices), 1));
            second = first;
            branch = zeros(numel(indices), size(kernel.BranchRate, 2));
            referenceElevation = zeros(numel(indices), 1);
            referenceVelocity = referenceElevation;
            for event = events
                age = response.Frequency*(obj.ReferenceTime - event.Time);
                [even, odd] = kernel.poleParts(age);
                firstResponse = kernel.Coefficients(:, 1).*even + kernel.Coefficients(:, 2).*odd;
                secondResponse = kernel.Coefficients(:, 1).*separation.^2.*odd ...
                    + kernel.Coefficients(:, 2).*even;
                amplitude = event.Strength*reshape(event.Coefficients(2:end), [], 1);
                first = first + amplitude.*firstResponse(indices);
                second = second + amplitude.*secondResponse(indices);
                decay = exp(-kernel.BranchRate.*age);
                branch = branch + amplitude.*decay(indices, :);
                elevation = real(firstResponse) - sum(kernel.BranchMeasure.*decay, 2);
                velocity = real(meanPole.*firstResponse + secondResponse) ...
                    + sum(kernel.BranchMeasure.*kernel.BranchRate.*decay, 2);
                elevation(age == 0) = 0;
                velocity(age == 0) = 1;
                referenceElevation = referenceElevation + amplitude.*elevation(indices);
                referenceVelocity = referenceVelocity + amplitude.*velocity(indices).*response.Frequency(indices);
            end
            obj.EvenAmplitude = first;
            obj.OddAmplitude = second;
            obj.BranchAmplitude = branch;
            obj.ReferenceElevation = referenceElevation;
            obj.ReferenceVelocity = referenceVelocity;
            obj.MemoryBytes = 8*(6*numel(first) + numel(branch) + numel(obj.EventIds) + 2);
        end

        function [elevation, velocity] = sample(obj, time)
        % SAMPLE Return signed physical cosine coefficients at the requested time.
            arguments
                obj (1, 1) app.internal.responses.TankState
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(time >= obj.ReferenceTime, "RippleSimulator:SimulationTime", ...
                "The requested time precedes the combined modal state.");
            response = obj.Response;
            if time == obj.ReferenceTime
                elevation = zeros(size(response.Amplitude));
                velocity = elevation;
                elevation(2:end) = obj.ReferenceElevation;
                velocity(2:end) = obj.ReferenceVelocity;
                return
            end
            indices = reshape(response.ModeIndex(2:end), [], 1);
            kernel = response.Kernel;
            meanPole = sum(kernel.Poles, 2)/2;
            separation = (kernel.Poles(:, 1) - kernel.Poles(:, 2))/2;
            age = response.Frequency*(time - obj.ReferenceTime);
            [even, odd] = kernel.poleParts(age);
            measure = kernel.BranchMeasure.*exp(-kernel.BranchRate.*age);
            first = obj.EvenAmplitude;
            second = obj.OddAmplitude;
            elevation = zeros(size(response.Amplitude));
            elevation(2:end) = real(first.*even(indices) + second.*odd(indices)) ...
                - sum(obj.BranchAmplitude.*measure(indices, :), 2);
            velocity = zeros(size(elevation));
            if nargout > 1
                velocity(2:end) = (real((meanPole(indices).*first + second).*even(indices) ...
                    + (separation(indices).^2.*first + meanPole(indices).*second).*odd(indices)) ...
                    + sum(obj.BranchAmplitude.*measure(indices, :).*kernel.BranchRate(indices, :), 2)) ...
                    .*response.Frequency(indices);
            end
        end
    end
end
