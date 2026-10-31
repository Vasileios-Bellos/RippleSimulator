classdef (Sealed) RainStreaks < handle
    % RAINSTREAKS Animate a rain burst with one retained line object.
    %   Streaks follow elapsed playback time and meet the surface at their
    %   scheduled source times. Their geometry is a visual annotation only.

    properties (Access = private)
        Line matlab.graphics.primitive.Line
        Positions (:, 2) double = zeros(0, 2)
        ImpactTimes (:, 1) double = zeros(0, 1)
        DisplayEnabled (1, 1) logical = true
        LastTime (1, 1) double = 0
    end

    methods
        function obj = RainStreaks(axesHandle)
            arguments
                axesHandle (1, 1) matlab.graphics.axis.Axes
            end
            obj.Line = line(axesHandle, NaN, NaN, NaN, Color=[0.8, 0.8, 0.8], LineWidth=2, ...
                HitTest="off", PickableParts="none", Visible="off", Tag="RainStreaks");
        end

        function start(obj, positions, times, domainSize)
        % START Append accepted drops while preserving existing visible streaks.
            arguments
                obj (1, 1) app.internal.ui.rendering.RainStreaks
                positions (:, 2) double {mustBeReal, mustBeFinite}
                times (:, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
            end
            assert(size(positions, 1) == numel(times), "RippleSimulator:RainShape", ...
                "Each rain position requires one impact time.");
            retained = obj.ImpactTimes + 0.04 > times(1);
            obj.Positions = [obj.Positions(retained, :); positions/domainSize];
            obj.ImpactTimes = [obj.ImpactTimes(retained); times];
            obj.update(times(1));
        end

        function update(obj, time)
        % UPDATE Move visible streaks without creating graphics or wave sources.
            arguments
                obj (1, 1) app.internal.ui.rendering.RainStreaks
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            obj.LastTime = time;
            if ~obj.DisplayEnabled
                return
            end
            flight = 0.16;
            impactDuration = 0.04;
            active = time >= obj.ImpactTimes - flight ...
                & time < obj.ImpactTimes + impactDuration;
            if ~any(active)
                if obj.Line.Visible == "on"
                    obj.Line.Visible = "off";
                end
                return
            end
            remaining = obj.ImpactTimes(active) - time;
            head = max(0, remaining/flight);
            length = 0.28*min(1, max(0, 1 + remaining/impactDuration));
            tail = min(1, head + length);
            direction = [-1.25, -1.25, 50/22];
            impacts = [obj.Positions(active, :), zeros(nnz(active), 1)];
            first = impacts + tail*direction;
            last = impacts + head*direction;
            separators = NaN(nnz(active), 1);
            x = reshape([first(:, 1), last(:, 1), separators]', 1, []);
            y = reshape([first(:, 2), last(:, 2), separators]', 1, []);
            z = reshape([first(:, 3), last(:, 3), separators]', 1, []);
            set(obj.Line, XData=x, YData=y, ZData=z, Visible="on");
        end

        function setVisible(obj, enabled)
        % SETVISIBLE Control streak visibility without changing scheduled impacts.
            arguments
                obj (1, 1) app.internal.ui.rendering.RainStreaks
                enabled (1, 1) {mustBeNumericOrLogical, mustBeMember(enabled, [0, 1])}
            end
            obj.DisplayEnabled = logical(enabled);
            if obj.DisplayEnabled
                obj.update(obj.LastTime);
            else
                obj.Line.Visible = "off";
            end
        end

        function clear(obj)
        % CLEAR Remove the burst annotation while retaining its graphics object.
            obj.Positions = zeros(0, 2);
            obj.ImpactTimes = zeros(0, 1);
            set(obj.Line, XData=NaN, YData=NaN, ZData=NaN, Visible="off");
        end
    end
end
