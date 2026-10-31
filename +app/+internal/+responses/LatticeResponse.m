classdef (Sealed) LatticeResponse
    % LATTICERESPONSE Prepare a radial response at distinct square-grid distances.
    %   Grid-aligned sources share the same elevation and velocity profiles.
    %   Translation changes integer lookup indices only. Single-precision
    %   storage accelerates display sampling; physical snapshots retain the
    %   original double-precision tensor Hermite interpolant.

    properties (SetAccess = immutable)
        Resolution (1, 1) double
        DomainSize (1, 1) double
        Times (1, :) double
        Elevations (:, :) single
        Velocities (:, :) single
        DistanceIndices (:, :) uint32
        MemoryBytes (1, 1) double
    end

    methods
        function obj = LatticeResponse(table, domainSize, resolution)
        % LATTICERESPONSE Evaluate spatial interpolation during preparation.
            arguments
                table (1, 1) app.internal.responses.ResponseTable
                domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                resolution (1, 1) double {mustBeInteger, mustBeGreaterThan(resolution, 1)}
            end
            [x, y] = meshgrid(0:resolution-1);
            [squared, ~, indices] = unique(x.^2+y.^2);
            radii = sqrt(squared)*domainSize/(resolution-1);
            mapping = table.mapRadii(radii, OperatorByteLimit=128*numel(squared)+32*numel(table.Radii));
            obj.Elevations = single(mapping.Operator*[table.Fields(:, :, 1); table.Fields(:, :, 3)]);
            obj.Velocities = single(mapping.Operator*[table.Fields(:, :, 2); table.Fields(:, :, 4)]);
            obj.DistanceIndices = reshape(uint32(indices), resolution, resolution);
            obj.Times = table.Times;
            obj.Resolution = resolution;
            obj.DomainSize = domainSize;
            obj.MemoryBytes = 4*(numel(obj.Elevations)+numel(obj.Velocities)+numel(indices)) ...
                + 8*numel(obj.Times);
        end

        function indices = mapPosition(obj, position)
        % MAPPOSITION Return translated indices, or empty for an off-grid source.
            arguments
                obj (1, 1) app.internal.responses.LatticeResponse
                position (1, 2) double {mustBeReal, mustBeFinite}
            end
            node = (position/obj.DomainSize+0.5)*(obj.Resolution-1);
            indices = zeros(0, 0, "uint32");
            if any(abs(node-round(node)) > 1e-9) || any(node < -1e-9 | node > obj.Resolution-1+1e-9)
                return
            end
            node = round(node);
            x = abs((0:obj.Resolution-1)-node(1))+1;
            y = abs((0:obj.Resolution-1)-node(2))+1;
            indices = obj.DistanceIndices(y, x);
        end

        function elevation = sample(obj, indices, age)
        % SAMPLE Translate a precomputed profile at a continuous elapsed age.
            arguments
                obj (1, 1) app.internal.responses.LatticeResponse
                indices (:, :) uint32
                age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            index = discretize(age, obj.Times);
            assert(isfinite(index), "RippleSimulator:ResponseTimeCoverage", ...
                "The requested age exceeds the precomputed display response.");
            step = obj.Times(index+1)-obj.Times(index);
            fraction = single((age-obj.Times(index))/step);
            profile = (2*fraction^3-3*fraction^2+1)*obj.Elevations(:, index) ...
                + single(step)*(fraction^3-2*fraction^2+fraction)*obj.Velocities(:, index) ...
                + (-2*fraction^3+3*fraction^2)*obj.Elevations(:, index+1) ...
                + single(step)*(fraction^3-fraction^2)*obj.Velocities(:, index+1);
            elevation = double(profile(indices));
        end

        function elevation = accumulate(obj, mappings, ages, strengths)
        % ACCUMULATE Share equal-age, equal-strength profiles before translation.
            arguments
                obj (1, 1) app.internal.responses.LatticeResponse
                mappings (1, :) struct
                ages (1, :) double
                strengths (1, :) double
            end
            elevation = zeros(obj.Resolution, "single");
            [parameters, ~, groups] = unique([ages(:), strengths(:)], "rows");
            times = parameters(:, 1)';
            indices = discretize(times, obj.Times);
            steps = obj.Times(indices+1)-obj.Times(indices);
            fraction = single((times-obj.Times(indices))./steps);
            weights = single(parameters(:, 2)').*[2*fraction.^3-3*fraction.^2+1; ...
                single(steps).*(fraction.^3-2*fraction.^2+fraction); ...
                -2*fraction.^3+3*fraction.^2; single(steps).*(fraction.^3-fraction.^2)];
            elevations = obj.Elevations;
            velocities = obj.Velocities;
            for group = 1:numel(times)
                index = indices(group);
                profile = weights(1, group)*elevations(:, index) ...
                    + weights(2, group)*velocities(:, index) ...
                    + weights(3, group)*elevations(:, index+1) ...
                    + weights(4, group)*velocities(:, index+1);
                for event = reshape(find(groups == group), 1, [])
                    elevation = elevation + profile(mappings(event).LatticeIndices);
                end
            end
            elevation = double(elevation);
        end
    end

    methods (Static)
        function bytes = estimateBytes(resolution, timeCount)
        % ESTIMATEBYTES Determine storage before allocating the response profiles.
            [x, y] = meshgrid(0:resolution-1);
            count = numel(unique(x.^2+y.^2));
            bytes = 4*(2*count*timeCount+resolution^2)+8*timeCount;
        end
    end
end
