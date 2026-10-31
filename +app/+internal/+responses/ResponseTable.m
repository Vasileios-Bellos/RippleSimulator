classdef (Sealed) ResponseTable
    % RESPONSETABLE Immutable radial response per unit pressure strength.
    %   A tensor Hermite interpolant preserves the stored elevation, velocity,
    %   slope, and mixed derivative at its nodes. The event history remains
    %   the physical state; the table accelerates response evaluation.
    %   Queries outside its radius or age coverage are rejected.

    properties (SetAccess = immutable)
        Fluid app.internal.materials.Fluid
        Source app.internal.input.Source
        Radii (:, 1) double
        Times (1, :) double
        Fields (:, :, :) double
        Period (1, 1) double
        TimeScale (1, 1) double
        RadialStep (1, 1) double
        FutureSlopes (1, :) double
        RadialSlopeBounds (:, :) double
        Separated app.internal.responses.SeparatedResponse = app.internal.responses.SeparatedResponse.empty
    end

    properties (SetAccess = private)
        Lattice app.internal.responses.LatticeResponse = app.internal.responses.LatticeResponse.empty
    end

    methods
        function obj = ResponseTable(fluid, source, maximumRadius, options)
        % RESPONSETABLE Prepare an interpolation table per unit pressure strength.
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                source (1, 1) app.internal.input.Source
                maximumRadius (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
                options.Periods (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(options.Periods, 1), ...
                    mustBeLessThanOrEqual(options.Periods, 256)} = 64
                options.RadialDensity (1, 1) {mustBeNumeric, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.RadialDensity, 16), ...
                    mustBeLessThanOrEqual(options.RadialDensity, 128)} = 32
                options.Separate (1, 1) logical = false
            end
            obj.Fluid = fluid;
            obj.Source = app.internal.input.Source(source.Wavelength, 1, source.Mode);
            [obj.TimeScale, obj.Period] = app.internal.responses.responseTimeScale(fluid, source);
            obj.RadialStep = source.Wavelength/options.RadialDensity;
            radiusCount = ceil(maximumRadius/obj.RadialStep);
            assert(radiusCount <= 4096, "RippleSimulator:ResponseTableSize", ...
                "The physical extent requires too many radial samples for this source scale.");
            obj.Radii = (0:radiusCount)'*obj.RadialStep;
            periodNodes = createPeriodNodes(options.Periods, obj.TimeScale/obj.Period, source.Mode);
            obj.Times = periodNodes*obj.TimeScale;
            obj.Fields = app.internal.physics.radialResponse(fluid, obj.Source, obj.Radii, obj.Times);
            [obj.FutureSlopes, obj.RadialSlopeBounds] = slopeBounds(obj.Fields, obj.Times, obj.RadialStep);
            if options.Separate
                obj.Separated = app.internal.responses.SeparatedResponse( ...
                    obj.Fields, obj.Times, obj.RadialStep, obj.Period);
            end
        end

        function mapping = mapRadii(obj, radii, options)
        % MAPRADII Prepare interpolation indices for the specified radii.
            arguments
                obj (1, 1) app.internal.responses.ResponseTable
                radii {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                options.OperatorByteLimit (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 0
            end
            coordinates = double(radii(:));
            index = discretize(coordinates, obj.Radii);
            assert(all(isfinite(index)), "RippleSimulator:ResponseRadiusCoverage", ...
                "The requested radii exceed the response table coverage.");
            fraction = (coordinates - obj.Radii(index))/obj.RadialStep;
            mapping = struct(Index=uint32(index), Fraction=fraction, Step=obj.RadialStep, ...
                Shape=size(radii), RadiusCount=numel(obj.Radii), Operator=sparse(0, 0), OperatorBytes=0, ...
                SpatialBasis=zeros(0, 0), LatticeIndices=zeros(0, 0, "uint32"));
            needed = 64*numel(index) + 8*(2*numel(obj.Radii) + 1);
            separatedBytes = Inf;
            if ~isempty(obj.Separated)
                separatedBytes = 4*numel(index)*obj.Separated.Rank;
            end
            if separatedBytes <= options.OperatorByteLimit
                operator = app.internal.numerics.prepareRadialOperator(mapping);
                mapping.SpatialBasis = single(operator*obj.Separated.SpatialBasis);
                mapping.OperatorBytes = separatedBytes;
            elseif needed <= options.OperatorByteLimit
                mapping.Operator = app.internal.numerics.prepareRadialOperator(mapping);
                mapping.OperatorBytes = needed;
            end
        end

        function [elevation, velocity, slope] = sample(obj, mapping, age)
        % SAMPLE Evaluate one physical age at previously mapped spatial points.
            arguments
                obj (1, 1) app.internal.responses.ResponseTable
                mapping (1, 1) struct
                age (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(mapping.Step == obj.RadialStep && mapping.RadiusCount == numel(obj.Radii), ...
                "RippleSimulator:ResponseMapping", "The radial mapping belongs to a different table grid.");
            if ~isempty(mapping.SpatialBasis) && nargout < 3
                if nargout == 2
                    [coefficients, derivative] = obj.Separated.sample(double(age));
                    velocity = reshape(double(mapping.SpatialBasis*single(derivative)), mapping.Shape);
                else
                    coefficients = obj.Separated.sample(double(age));
                end
                elevation = reshape(double(mapping.SpatialBasis*single(coefficients)), mapping.Shape);
                return
            end
            if nargout >= 3
                [elevation, velocity, slope] = app.internal.numerics.interpolateResponse( ...
                    obj.Fields, obj.Times, mapping, double(age));
            elseif nargout == 2
                [elevation, velocity] = app.internal.numerics.interpolateResponse( ...
                    obj.Fields, obj.Times, mapping, double(age));
            else
                elevation = app.internal.numerics.interpolateResponse(obj.Fields, obj.Times, mapping, double(age));
            end
        end

        function value = memoryBytes(obj)
        % MEMORYBYTES Return numeric table storage, excluding object overhead.
            arguments
                obj (1, 1) app.internal.responses.ResponseTable
            end
            value = 8*(numel(obj.Fields) + numel(obj.Radii) + numel(obj.Times) ...
                + numel(obj.FutureSlopes) + numel(obj.RadialSlopeBounds));
            if ~isempty(obj.Separated)
                value = value + obj.Separated.MemoryBytes;
            end
            if ~isempty(obj.Lattice)
                value = value + obj.Lattice.MemoryBytes;
            end
        end

        function obj = prepareLattice(obj, domainSize, resolution, byteLimit)
        % PREPARELATTICE Return a value with bounded, shared display profiles.
            obj.Lattice = app.internal.responses.LatticeResponse.empty;
            needed = app.internal.responses.LatticeResponse.estimateBytes(resolution, numel(obj.Times));
            if needed <= byteLimit
                obj.Lattice = app.internal.responses.LatticeResponse(obj, domainSize, resolution);
            end
        end

        function value = futureSlope(obj, age)
        % FUTURESLOPE Bound the interpolated radial slope from age to table end.
            arguments
                obj (1, 1) app.internal.responses.ResponseTable
                age (1, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            index = discretize(double(age), obj.Times);
            assert(all(isfinite(index)), "RippleSimulator:ResponseTimeCoverage", ...
                "The requested age exceeds the response table coverage.");
            value = obj.FutureSlopes(index);
        end

        function value = spatialSlope(obj, minimumRadius, maximumRadius)
        % SPATIALSLOPE Bound slope throughout radial intervals and all stored ages.
            arguments
                obj (1, 1) app.internal.responses.ResponseTable
                minimumRadius double {mustBeReal, mustBeFinite, mustBeNonnegative}
                maximumRadius double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(isequal(size(minimumRadius), size(maximumRadius)) ...
                && all(minimumRadius <= maximumRadius, "all"), "RippleSimulator:RadiusInterval", ...
                "Each radial interval requires ordered endpoints with matching sizes.");
            assert(all(maximumRadius <= obj.Radii(end), "all"), "RippleSimulator:ResponseRadiusCoverage", ...
                "The requested radial intervals exceed the response table coverage.");
            count = size(obj.RadialSlopeBounds, 1);
            first = min(count, floor(minimumRadius/obj.RadialStep)+1);
            last = min(count, floor(maximumRadius/obj.RadialStep)+1);
            level = floor(log2(last-first+1));
            left = first+level*count;
            right = last-2.^level+1+level*count;
            value = reshape(max(obj.RadialSlopeBounds(left), obj.RadialSlopeBounds(right)), size(first));
        end

        function [elevation, velocity, slope] = sampleDirect(obj, mapping, age)
        % SAMPLEDIRECT Evaluate an uncached age without truncating an active wave.
            arguments
                obj (1, 1) app.internal.responses.ResponseTable
                mapping (1, 1) struct
                age (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(mapping.Step == obj.RadialStep && mapping.RadiusCount == numel(obj.Radii), ...
                "RippleSimulator:ResponseMapping", "The radial mapping belongs to a different table grid.");
            fields = app.internal.physics.radialResponse(obj.Fluid, obj.Source, obj.Radii, double(age));
            if nargout >= 3
                [elevation, velocity, slope] = app.internal.numerics.interpolateRadial(fields, mapping);
            elseif nargout == 2
                [elevation, velocity] = app.internal.numerics.interpolateRadial(fields, mapping);
            else
                elevation = app.internal.numerics.interpolateRadial(fields, mapping);
            end
        end
    end

    methods (Static)
        function value = estimateBytes(fluid, source, maximumRadius, options)
        % ESTIMATEBYTES Compute numeric storage before allocating response fields.
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                source (1, 1) app.internal.input.Source
                maximumRadius (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
                options.Periods (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(options.Periods, 1), ...
                    mustBeLessThanOrEqual(options.Periods, 256)} = 64
                options.RadialDensity (1, 1) {mustBeNumeric, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.RadialDensity, 16), ...
                    mustBeLessThanOrEqual(options.RadialDensity, 128)} = 32
            end
            radialCount = ceil(maximumRadius/(source.Wavelength/options.RadialDensity)) + 1;
            [timeScale, period] = app.internal.responses.responseTimeScale(fluid, source);
            timeCount = numel(createPeriodNodes(options.Periods, timeScale/period, source.Mode));
            rangeCount = (radialCount-1)*(floor(log2(radialCount-1))+1);
            value = 8*(4*radialCount*timeCount + radialCount + 2*timeCount - 1 + rangeCount);
        end
    end
end

function [bounds, radialBounds] = slopeBounds(fields, times, radialStep)
    steps = diff(times);
    bounds = zeros(size(steps));
    radialBounds = zeros(size(fields, 1)-1, 1);
    for start = 1:128:numel(steps)
        columns = start:min(start + 127, numel(steps));
        for control = 1:4
            switch control
                case 1
                    elevation = fields(:, columns, 1);
                    slope = fields(:, columns, 3);
                case 2
                    elevation = fields(:, columns, 1) + steps(columns).*fields(:, columns, 2)/3;
                    slope = fields(:, columns, 3) + steps(columns).*fields(:, columns, 4)/3;
                case 3
                    elevation = fields(:, columns+1, 1) - steps(columns).*fields(:, columns+1, 2)/3;
                    slope = fields(:, columns+1, 3) - steps(columns).*fields(:, columns+1, 4)/3;
                otherwise
                    elevation = fields(:, columns+1, 1);
                    slope = fields(:, columns+1, 3);
            end
            interior = 3*diff(elevation, 1, 1)/radialStep - slope(1:end-1, :) - slope(2:end, :);
            bounds(columns) = max([bounds(columns); max(abs(slope), [], 1); max(abs(interior), [], 1)], [], 1);
            controls = max(abs(slope(1:end-1, :)), abs(slope(2:end, :)));
            radialBounds = max(radialBounds, max(max(controls, abs(interior)), [], 2));
        end
    end
    bounds = flip(cummax(flip(bounds)));
    count = numel(radialBounds);
    ranges = zeros(count, floor(log2(count))+1);
    ranges(:, 1) = radialBounds;
    for level = 2:size(ranges, 2)
        indices = min((1:count)'+2^(level-2), count);
        ranges(:, level) = max(ranges(:, level-1), ranges(indices, level-1));
    end
    radialBounds = ranges;
end

function nodes = createPeriodNodes(maximum, scaleRatio, mode)
    nodes = [0:1/64:min(16, maximum), 16:1/32:min(32, maximum), ...
        32:1/16:min(64, maximum), 64:1/8:maximum, logspace(-8, 0, 161), maximum];
    nodes = unique(nodes(nodes <= maximum));
    if scaleRatio > 1
        resolvedPeriods = 1+3*(mode == "Wavemaker");
        fineNodes = (0:1/64:resolvedPeriods)/scaleRatio;
        nodes = unique([nodes, fineNodes(fineNodes <= maximum)]);
    end
end
