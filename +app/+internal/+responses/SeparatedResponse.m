classdef (Sealed) SeparatedResponse
    % SEPARATEDRESPONSE Factor a radial Hermite table into space and time.
    %   A singular-value decomposition shares one radial basis between
    %   elevation and velocity. The spatial and temporal derivatives follow
    %   from the same Hermite interpolant. The retained residual is bounded
    %   before the factorization is accepted. The supplemental elevation
    %   and velocity samples share the temporal basis but retain their own
    %   spatial interpolation.

    properties (SetAccess = immutable)
        SpatialBasis (:, :) double
        Coefficients (:, :) double
        Times (1, :) double
        Frequency (1, 1) double
        RelativeResidual (1, 1) double
        Rank (1, 1) double
        MemoryBytes (1, 1) double
    end

    methods
        function obj = SeparatedResponse(fields, times, radialStep, period, options)
            arguments
                fields (:, :, 4) double
                times (1, :) double
                radialStep (1, 1) double {mustBePositive}
                period (1, 1) double {mustBePositive}
                options.Supplemental (:, :, 2) double = zeros(0, 0, 2)
            end
            frequency = 2*pi/period;
            matrix = [fields(:, :, 1), fields(:, :, 2)/frequency; ...
                radialStep*fields(:, :, 3), radialStep*fields(:, :, 4)/frequency];
            if ~isempty(options.Supplemental)
                assert(size(options.Supplemental, 2) == numel(times), ...
                    "RippleSimulator:ResponseTimeShape", "Supplemental samples must share the response times.");
                matrix = [matrix; options.Supplemental(:, :, 1), options.Supplemental(:, :, 2)/frequency];
            end
            [spatial, temporal, residual] = app.internal.numerics.factorResponse(matrix, 1e-10);
            count = size(spatial, 2);
            obj.RelativeResidual = residual;
            obj.SpatialBasis = spatial;
            radialCount = size(fields, 1);
            obj.SpatialBasis(radialCount+1:2*radialCount, :) = ...
                obj.SpatialBasis(radialCount+1:2*radialCount, :)/radialStep;
            obj.Coefficients = temporal;
            obj.Times = times;
            obj.Frequency = frequency;
            obj.Rank = count;
            obj.MemoryBytes = 8*(numel(obj.SpatialBasis)+numel(obj.Coefficients)+numel(times)+3);
        end

        function [elevation, velocity] = sample(obj, age)
        % SAMPLE Return temporal coefficients and their physical time derivative.
            arguments
                obj (1, 1) app.internal.responses.SeparatedResponse
                age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            index = discretize(age, obj.Times);
            assert(isfinite(index), "RippleSimulator:ResponseTimeCoverage", ...
                "The requested age exceeds the precomputed response.");
            step = obj.Times(index+1)-obj.Times(index);
            fraction = (age-obj.Times(index))/step;
            count = numel(obj.Times);
            values = obj.Coefficients(:, [index, index+count, index+1, index+1+count]);
            basis = [2*fraction^3-3*fraction^2+1; ...
                obj.Frequency*step*(fraction^3-2*fraction^2+fraction); ...
                -2*fraction^3+3*fraction^2; obj.Frequency*step*(fraction^3-fraction^2)];
            elevation = values*basis;
            if nargout > 1
                derivative = [(6*fraction^2-6*fraction)/step; ...
                    obj.Frequency*(3*fraction^2-4*fraction+1); ...
                    (-6*fraction^2+6*fraction)/step; obj.Frequency*(3*fraction^2-2*fraction)];
                velocity = values*derivative;
            end
        end
    end
end
