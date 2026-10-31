classdef (Sealed) TankResponse
    % TANKRESPONSE Represent a Gaussian source between ideal reflecting walls.
    %   Cosine modes enforce impermeable free-slip walls and a 90-degree contact
    %   angle. The fluid remains infinitely deep with a clean free surface.
    %   The unit Gaussian profile is extended evenly across each wall; its
    %   integral over the domain is 2*pi*s^2, including edge clicks.

    properties (Constant)
        MaximumCacheBytes = 805306368
    end

    properties (SetAccess = immutable)
        Fluid app.internal.materials.Fluid
        Source app.internal.input.Source
        DomainSize (1, 1) double
        Modes (1, :) double
        Frequency (:, 1) double
        Wavenumber (:, :) double
        ModeIndex (:, :) double
        Amplitude (:, :) double
        Kernel app.internal.physics.ModalKernel
        TailBound (1, 3) double
        MemoryBytes (1, 1) double
        Period (1, 1) double
        TimeScale (1, 1) double
        PreparedResponse app.internal.responses.ModalResponseTable = app.internal.responses.ModalResponseTable.empty
    end

    properties (GetAccess = private, SetAccess = immutable)
        SlopeCosine (:, :) double
        SlopeDerivative (:, :) double
        SlopeRemainder (:, :) double
        BoundTimes (1, :) double = zeros(1, 0)
        BoundElevations (:, :) double = zeros(0)
    end

    methods
        function obj = TankResponse(fluid, domainSize, source, options)
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                source (1, 1) app.internal.input.Source
                options.Cutoff (1, 1) double {mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(options.Cutoff, 8), mustBeLessThanOrEqual(options.Cutoff, 12)} = 8
                options.BranchOrder (1, 1) double {mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.BranchOrder, 16), ...
                    mustBeLessThanOrEqual(options.BranchOrder, 512)} = 64
                options.Periods (1, 1) double {mustBeReal, mustBePositive} = Inf
                options.ByteLimit (1, 1) double {mustBeReal, mustBeFinite, mustBePositive} = 805306368
            end
            obj.Fluid = fluid;
            obj.Source = source;
            obj.DomainSize = domainSize;
            count = ceil(options.Cutoff*domainSize/(pi*source.Width));
            obj.Modes = 0:count;
            [modeX, modeY] = meshgrid(obj.Modes);
            squared = modeX.^2 + modeY.^2;
            [distinct, ~, mapping] = unique(squared(2:end));
            indices = zeros(size(squared));
            indices(2:end) = mapping;
            obj.ModeIndex = indices;
            obj.Wavenumber = pi/domainSize*sqrt(squared);
            wavenumber = pi/domainSize*sqrt(distinct(:));
            frequency = app.internal.physics.dispersion(wavenumber, fluid);
            obj.Frequency = frequency;
            obj.Kernel = app.internal.physics.ModalKernel( ...
                fluid.KinematicViscosity*wavenumber.^2./frequency, options.BranchOrder);
            spatial = 2*pi*source.Width^2/domainSize^2*(1 + (modeX > 0)).*(1 + (modeY > 0)) ...
                .*exp(-0.5*(source.Width*obj.Wavenumber).^2);
            amplitude = zeros(size(spatial));
            amplitude(2:end) = -spatial(2:end).*obj.Wavenumber(2:end) ...
                ./(fluid.Density*reshape(frequency(mapping), 1, []));
            obj.Amplitude = amplitude;
            [obj.TimeScale, obj.Period] = app.internal.responses.responseTimeScale(fluid, source);
            slopeCount = max(129, 2*numel(obj.Modes) - 1);
            [cosine, derivative] = obj.basis(linspace(-domainSize/2, domainSize/2, slopeCount));
            obj.SlopeCosine = abs(cosine);
            obj.SlopeDerivative = abs(derivative);
            obj.SlopeRemainder = domainSize/(sqrt(2)*(slopeCount-1))*obj.Wavenumber.^2;
            obj.TailBound = cosineTail(fluid, domainSize, source, count);
            obj.MemoryBytes = 8*(3*numel(squared) + numel(frequency)*(10 + 2*options.BranchOrder) ...
                + numel(obj.Modes) + 6 + numel(obj.SlopeCosine) ...
                + numel(obj.SlopeDerivative) + numel(obj.SlopeRemainder));
            if isfinite(options.Periods)
                obj.BoundTimes = linspace(0, options.Periods*obj.TimeScale, ceil(8*options.Periods)+1);
                duration = 4*obj.Period*(source.Mode == "Wavemaker");
                obj.BoundElevations = obj.Kernel.futureBound(frequency*max(0, obj.BoundTimes-duration));
                obj.MemoryBytes = obj.MemoryBytes + 8*(numel(obj.BoundTimes)+numel(obj.BoundElevations));
                remaining = min(obj.MaximumCacheBytes, options.ByteLimit)-obj.MemoryBytes;
                assert(remaining > 0, "RippleSimulator:CacheMemory", ...
                    "The source spectrum exceeds the remaining response memory budget.");
                obj.PreparedResponse = app.internal.responses.ModalResponseTable( ...
                    fluid, wavenumber, source, options.Periods, ...
                    BranchOrder=options.BranchOrder, ByteLimit=remaining, TimeScale=obj.TimeScale);
                obj.MemoryBytes = obj.MemoryBytes + obj.PreparedResponse.MemoryBytes;
            end
        end

        function value = coefficients(obj, position)
        % COEFFICIENTS Return the signed modal amplitudes per unit pressure strength.
            arguments
                obj (1, 1) app.internal.responses.TankResponse
                position (1, 2) double {mustBeReal, mustBeFinite}
            end
            phase = pi*(position/obj.DomainSize + 0.5);
            value = obj.Amplitude.*(cos(obj.Modes'*phase(2))*cos(obj.Modes*phase(1)));
        end

        function [elevation, velocity] = sample(obj, age)
        % SAMPLE Evaluate dimensionless modal responses at a physical source age.
            arguments
                obj (1, 1) app.internal.responses.TankResponse
                age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            if ~isempty(obj.PreparedResponse)
                if nargout > 1
                    [elevation, velocity] = obj.PreparedResponse.sample(age);
                else
                    elevation = obj.PreparedResponse.sample(age);
                end
                return
            end
            time = obj.Frequency*age;
            if obj.Source.Mode == "Impulse"
                [elevation, velocity] = obj.Kernel.sample(time);
            else
                forcing = app.internal.physics.dispersion(obj.Source.Wavenumber, obj.Fluid);
                [elevation, velocity] = app.internal.physics.wavemaker( ...
                    obj.Kernel.ViscosityRatio, time, forcing./obj.Frequency, size(obj.Kernel.BranchRate, 2));
            end
        end

        function value = futureBound(obj, age, amplitudes)
        % FUTUREBOUND Bound all later elevation, vertical speed, and slope magnitude.
            arguments
                obj (1, 1) app.internal.responses.TankResponse
                age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                amplitudes (:, :) double = abs(obj.Amplitude)
            end
            assert(isequal(size(amplitudes), size(obj.Amplitude)), "RippleSimulator:ModeShape", ...
                "Modal amplitudes must match the response basis.");
            duration = 0;
            forcingNorm = 1;
            if obj.Source.Mode == "Wavemaker"
                duration = 8*pi/app.internal.physics.dispersion(obj.Source.Wavenumber, obj.Fluid);
                forcingNorm = 8;
            end
            [elevation, velocity] = obj.Kernel.futureBound(obj.Frequency*max(0, age - duration));
            indices = obj.ModeIndex(2:end);
            weight = abs(amplitudes(2:end));
            displacement = weight.*reshape(elevation(indices), size(weight));
            speed = weight.*reshape(velocity(indices).*obj.Frequency(indices), size(weight));
            value = forcingNorm*[sum(displacement), sum(speed), ...
                sum(displacement.*obj.Wavenumber(2:end))] + obj.TailBound;
        end

        function [cosine, derivative] = basis(obj, coordinates)
        % BASIS Evaluate the continuous cosine basis and its spatial derivative.
            arguments
                obj (1, 1) app.internal.responses.TankResponse
                coordinates (1, :) double {mustBeReal, mustBeFinite}
            end
            phase = pi*(coordinates'/obj.DomainSize + 0.5)*obj.Modes;
            cosine = cos(phase);
            if nargout > 1
                derivative = -sin(phase).*(pi/obj.DomainSize*obj.Modes);
                derivative(coordinates == -obj.DomainSize/2 | coordinates == obj.DomainSize/2, :) = 0;
            end
        end

        function value = slopeBound(obj, amplitudes)
        % SLOPEBOUND Bound slope for all times using the spatial mode shapes.
            arguments
                obj (1, 1) app.internal.responses.TankResponse
                amplitudes (:, :) double
            end
            weights = abs(amplitudes);
            gradientX = obj.SlopeCosine*weights*obj.SlopeDerivative';
            gradientY = obj.SlopeDerivative*weights*obj.SlopeCosine';
            sampled = max(hypot(gradientX, gradientY), [], "all");
            remainder = sum(weights.*obj.SlopeRemainder, "all");
            forcingNorm = 1 + 7*(obj.Source.Mode == "Wavemaker");
            value = forcingNorm*(sampled + remainder) + obj.TailBound(3);
        end

        function value = futureSlopes(obj, ages, amplitudes)
        % FUTURESLOPES Evaluate source-specific modal bounds in one array operation.
            arguments
                obj (1, 1) app.internal.responses.TankResponse
                ages (1, :) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                amplitudes (:, :) double {mustBeReal, mustBeFinite}
            end
            assert(isequal(size(amplitudes), [numel(obj.Amplitude), numel(ages)]), ...
                "RippleSimulator:ModeShape", "Each source requires one column of modal amplitudes.");
            duration = 4*obj.Period*(obj.Source.Mode == "Wavemaker");
            forcingNorm = 1 + 7*(obj.Source.Mode == "Wavemaker");
            if isempty(obj.BoundTimes)
                elevation = obj.Kernel.futureBound(obj.Frequency*max(0, ages-duration));
            else
                index = discretize(ages, [obj.BoundTimes, Inf]);
                elevation = obj.BoundElevations(:, index);
            end
            indices = obj.ModeIndex(2:end);
            weight = abs(amplitudes(2:end, :)).*obj.Wavenumber(2:end)';
            value = forcingNorm*sum(weight.*elevation(indices, :), 1) + obj.TailBound(3);
        end
    end
end

function bound = cosineTail(fluid, domainSize, source, count)
    spacing = pi/domainSize;
    exponent = (spacing*source.Width)^2/2;
    powers = [0, 0.5, 1, 1.5];
    integral = gamma((powers + 1)/2)./(2*exponent.^((powers + 1)/2));
    tail = integral.*gammainc(exponent*count^2, (powers + 1)/2, "upper");
    peak = ones(size(powers));
    peak(2:end) = (powers(2:end)/(2*exponent)).^(powers(2:end)/2).*exp(-powers(2:end)/2);
    total = integral + peak;
    moments = zeros(1, 3);
    for index = 1:3
        power = powers(index + 1);
        moments(index) = 8*max(1, 2^(power - 1))*spacing^power ...
            *(tail(index + 1)*total(1) + tail(1)*total(index + 1));
    end
    bound = 2*pi*source.Width^2/domainSize^2/fluid.Density ...
        *moments./[sqrt(9.81), 1, sqrt(9.81)];
    if source.Mode == "Wavemaker"
        bound = 8*bound;
    end
    bound = bound*(1 + 128*eps);
end
