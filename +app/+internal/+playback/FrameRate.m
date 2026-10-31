classdef (Sealed) FrameRate < handle
    % FRAMERATE Measure playback cadence over the last ten frame intervals.
    %   FPS is the reciprocal of the mean positive interval. Reset excludes
    %   pauses and configuration changes from the next playback measurement.

    properties (SetAccess = private)
        MeasuredFPS (1, 1) double = 0
    end

    properties (Access = private)
        FrameTimeHistory (1, 10) double = zeros(1, 10)
        FrameTimeIndex (1, 1) double = 1
        LastFrameTime (1, 1) double = NaN
        TimeSource function_handle
    end

    methods
        function obj = FrameRate(timeSource)
            arguments
                timeSource (1, 1) function_handle = createTimeSource()
            end
            obj.TimeSource = timeSource;
        end

        function recordFrameTime(obj)
        % RECORDFRAMETIME Include one elapsed interval in the rolling window.
            currentTime = obj.TimeSource();
            if isnan(obj.LastFrameTime)
                obj.LastFrameTime = currentTime;
                return
            end
            elapsed = currentTime - obj.LastFrameTime;
            obj.LastFrameTime = currentTime;
            if elapsed <= 0
                return
            end
            obj.FrameTimeHistory(obj.FrameTimeIndex) = elapsed;
            obj.FrameTimeIndex = mod(obj.FrameTimeIndex, 10) + 1;
            intervals = obj.FrameTimeHistory(obj.FrameTimeHistory > 0);
            obj.MeasuredFPS = 1/mean(intervals);
        end

        function resetMeasurement(obj)
        % RESETMEASUREMENT Reset the frame-rate measurement and history.
            obj.MeasuredFPS = 0;
            obj.FrameTimeHistory(:) = 0;
            obj.FrameTimeIndex = 1;
            obj.LastFrameTime = NaN;
        end
    end
end

function source = createTimeSource()
    epoch = tic;
    source = @() toc(epoch);
end
