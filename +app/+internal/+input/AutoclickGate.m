classdef (Sealed) AutoclickGate < handle
    % AUTOCLICKGATE Limit pointer-driven input by elapsed time and grid position.

    properties (Constant)
        MinimumInterval = 0.05
    end

    properties
        StrengthScale (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 0.2
    end

    properties (SetAccess = private)
        LastPosition (1, :) double = zeros(1, 0)
        NextTime (1, 1) double = 0
    end

    methods
        function value = accepts(obj, position, time)
        % ACCEPTS Identify a new grid position after the minimum input interval.
            arguments
                obj (1, 1) app.internal.input.AutoclickGate
                position (1, 2) double {mustBeReal, mustBeFinite}
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            value = ~isequal(position, obj.LastPosition) && time >= obj.NextTime;
        end

        function record(obj, position, time)
        % RECORD Store the position and time of an accepted source.
            arguments
                obj (1, 1) app.internal.input.AutoclickGate
                position (1, 2) double {mustBeReal, mustBeFinite}
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            obj.LastPosition = position;
            obj.NextTime = time + obj.MinimumInterval;
        end

        function reset(obj)
        % RESET Allow a new pointer sequence without retaining a prior position.
            obj.LastPosition = zeros(1, 0);
            obj.NextTime = 0;
        end
    end
end
