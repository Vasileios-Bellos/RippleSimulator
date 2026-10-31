classdef (Sealed) ModalResponseTable
    % MODALRESPONSETABLE Store viscous modal responses over a finite time interval.
    %   Cubic Hermite interpolation preserves elevation and its time derivative
    %   at every stored age. Preparation evaluates the complete viscous response;
    %   sampling requires only adjacent columns and polynomial arithmetic.
    %   Piecewise Chebyshev interpolation expands the response to every retained
    %   wavenumber during preparation. Playback uses temporal interpolation only.
    %   Storage-limited tables retain at least 32 intervals per response time
    %   scale, together with early-time samples and resolved source forcing.

    properties (SetAccess = immutable)
        Times (1, :) double
        Elevations (:, :) double
        Velocities (:, :) double
        Frequency (:, 1) double
        MemoryBytes (1, 1) double
        SamplesPerPeriod (1, 1) double
    end

    methods
        function obj = ModalResponseTable(fluid, wavenumber, source, periods, options)
        % MODALRESPONSETABLE Prepare modal values and physical-time derivatives.
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                wavenumber (:, 1) double {mustBeReal, mustBeFinite, mustBePositive, mustBeNonempty}
                source (1, 1) app.internal.input.Source
                periods (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                options.SamplesPerPeriod (1, 1) double {mustBeInteger, mustBePositive} = 128
                options.BranchOrder (1, 1) double {mustBeInteger, mustBePositive} = 64
                options.ByteLimit (1, 1) double {mustBeReal, mustBeFinite, mustBePositive} = 268435456
                options.TimeScale (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 0
                options.InterpolateWavenumbers (1, 1) logical = true
            end
            frequency = app.internal.physics.dispersion(wavenumber, fluid);
            sourceFrequency = app.internal.physics.dispersion(source.Wavenumber, fluid);
            samples = options.SamplesPerPeriod;
            period = 2*pi/sourceFrequency;
            timeScale = max(period, options.TimeScale);
            while true
                nodes = unique([0:1/samples:periods, ...
                    logspace(-10, -1, 145), min(4, periods), periods]);
                nodes = nodes(nodes <= periods);
                times = nodes*timeScale;
                if timeScale > period
                    resolvedPeriods = 1+3*(source.Mode == "Wavemaker");
                    fineNodes = (0:1/samples:resolvedPeriods)*period;
                    times = unique([times, fineNodes(fineNodes <= periods*timeScale)]);
                end
                needed = 8*(2*numel(frequency)*numel(times) + numel(times) + numel(frequency));
                if needed <= options.ByteLimit || samples <= 32
                    break
                end
                samples = max(32, floor(samples/2));
            end
            assert(needed <= options.ByteLimit, "RippleSimulator:CacheMemory", ...
                "The modal response exceeds the available preparation memory. Reduce the physical extent.");
            [elevations, velocities] = prepareValues(fluid, wavenumber, source, times, ...
                options.BranchOrder, options.InterpolateWavenumbers);
            obj.Times = times;
            obj.Elevations = elevations;
            obj.Velocities = velocities;
            obj.Frequency = frequency;
            obj.MemoryBytes = needed;
            obj.SamplesPerPeriod = samples;
        end

        function [elevation, velocity] = sample(obj, age)
        % SAMPLE Interpolate modal elevation and its dimensionless derivative.
            arguments
                obj (1, 1) app.internal.responses.ModalResponseTable
                age (1, :) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            index = discretize(age, obj.Times);
            assert(all(isfinite(index)), "RippleSimulator:ResponseTimeCoverage", ...
                "The requested age exceeds the precomputed modal response.");
            step = obj.Times(index + 1) - obj.Times(index);
            fraction = (age - obj.Times(index))./step;
            first = obj.Elevations(:, index);
            last = obj.Elevations(:, index + 1);
            firstVelocity = obj.Velocities(:, index);
            lastVelocity = obj.Velocities(:, index + 1);
            elevation = (2*fraction.^3-3*fraction.^2+1).*first ...
                + (fraction.^3-2*fraction.^2+fraction).*step.*firstVelocity ...
                + (-2*fraction.^3+3*fraction.^2).*last ...
                + (fraction.^3-fraction.^2).*step.*lastVelocity;
            if nargout > 1
                velocity = ((6*fraction.^2-6*fraction).*(first-last)./step ...
                    + (3*fraction.^2-4*fraction+1).*firstVelocity ...
                    + (3*fraction.^2-2*fraction).*lastVelocity)./obj.Frequency;
            end
        end
    end
end

function [elevations, velocities] = prepareValues(fluid, wavenumber, source, times, branchOrder, interpolate)
    frequency = app.internal.physics.dispersion(wavenumber, fluid);
    forcing = app.internal.physics.dispersion(source.Wavenumber, fluid);
    period = 2*pi/forcing;
    coordinates = source.Width*wavenumber;
    panelWidth = 0.125*min(1, 10*period/times(end));
    order = 20;
    panelCount = ceil((max(coordinates)-min(coordinates))/panelWidth);
    useInterpolation = interpolate && panelCount > 0 && order*panelCount < numel(wavenumber);
    if useInterpolation
        [nodes, mapping] = app.internal.numerics.chebyshevMap(coordinates, panelWidth, order);
        calculationWavenumber = nodes/source.Width;
    else
        calculationWavenumber = wavenumber;
    end
    calculationFrequency = app.internal.physics.dispersion(calculationWavenumber, fluid);
    parameters = fluid.KinematicViscosity*calculationWavenumber.^2./calculationFrequency;
    count = numel(calculationFrequency);
    elevations = zeros(count, numel(times));
    velocities = elevations;
    for first = 1:128:count
        indices = first:min(first+127, count);
        age = calculationFrequency(indices)*times;
        if source.Mode == "Impulse"
            [elevations(indices, :), velocities(indices, :)] = ...
                app.internal.physics.viscousImpulse(parameters(indices), age, branchOrder);
        else
            [elevations(indices, :), velocities(indices, :)] = ...
                app.internal.physics.wavemaker(parameters(indices), age, forcing./calculationFrequency(indices), ...
                branchOrder);
        end
    end
    if useInterpolation
        % d(H/omega)/dt = dH/d(omega*t), so one map preserves the time derivative.
        [elevations, velocities] = expandModes(elevations./calculationFrequency, velocities, mapping, frequency);
    else
        velocities = velocities.*frequency;
    end
    elevations(:, 1) = 0;
    velocities(:, 1) = frequency*double(source.Mode == "Impulse");
end

function [elevations, velocities] = expandModes(nodeElevations, nodeVelocities, mapping, frequency)
    elevations = zeros(numel(frequency), size(nodeElevations, 2));
    velocities = elevations;
    for first = 1:128:size(nodeElevations, 2)
        indices = first:min(first+127, size(nodeElevations, 2));
        elevations(:, indices) = (mapping*nodeElevations(:, indices)).*frequency;
        velocities(:, indices) = (mapping*nodeVelocities(:, indices)).*frequency;
    end
end
