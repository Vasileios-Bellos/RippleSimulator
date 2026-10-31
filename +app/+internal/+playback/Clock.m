classdef (Sealed) Clock < handle
    % CLOCK Convert elapsed real time to playback duration and simulation time.
    %   User pauses and temporary calculation pauses exclude elapsed real time.
    %   Rate changes preserve time accumulated at the previous rate. Delayed
    %   updates include the complete elapsed interval.

    properties (SetAccess = private)
        ActiveTime (1, 1) double = 0
        PhysicalTime (1, 1) double = 0
        Rate (1, 1) double = 1
        IsPaused (1, 1) logical = false
        HoldCount (1, 1) double = 0
    end

    properties (Access = private)
        TimeSource function_handle
        LastSample (1, 1) double
        IsBanking (1, 1) logical = false
    end

    methods
        function obj = Clock(rate, timeSource)
        % CLOCK Construct an elapsed clock with an optional monotonic source.
            arguments
                rate (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive} = 1
                timeSource (1, 1) function_handle = createTimeSource()
            end
            obj.Rate = double(rate);
            obj.TimeSource = timeSource;
            obj.LastSample = obj.readTime();
        end

        function state = sample(obj)
        % SAMPLE Accumulate elapsed time and return the current playback state.
            arguments
                obj (1, 1) app.internal.playback.Clock
            end
            obj.bank();
            state = struct(ActiveTime=obj.ActiveTime, PhysicalTime=obj.PhysicalTime, ...
                Rate=obj.Rate, IsPaused=obj.IsPaused, IsHeld=obj.HoldCount > 0);
        end

        function setRate(obj, rate)
        % SETRATE Apply a new rate after accounting for time at the previous rate.
            arguments
                obj (1, 1) app.internal.playback.Clock
                rate (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
            end
            obj.bank();
            obj.Rate = double(rate);
        end

        function pause(obj)
        % PAUSE Exclude subsequent elapsed time until playback resumes.
            arguments
                obj (1, 1) app.internal.playback.Clock
            end
            obj.bank();
            obj.IsPaused = true;
        end

        function freeze(obj)
        % FREEZE Suspend at the last valid sample after a processing failure.
            arguments
                obj (1, 1) app.internal.playback.Clock
            end
            obj.IsPaused = true;
        end

        function pauseAt(obj, physicalTime)
        % PAUSEAT Suspend playback at the latest processed simulation time.
        %   The unprocessed interval at the current rate is excluded from
        %   both simulation time and the elapsed-time rain schedule.
            arguments
                obj (1, 1) app.internal.playback.Clock
                physicalTime (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            obj.bank();
            elapsed = (obj.PhysicalTime-physicalTime)/obj.Rate;
            tolerance = 32*eps(max(1, obj.ActiveTime));
            assert(elapsed >= 0 && elapsed <= obj.ActiveTime+tolerance, "RippleSimulator:PauseTime", ...
                "The pause time must lie within the accumulated playback interval.");
            obj.ActiveTime = max(0, obj.ActiveTime-elapsed);
            obj.PhysicalTime = double(physicalTime);
            obj.IsPaused = true;
        end

        function resume(obj)
        % RESUME Continue playback without including the paused interval.
            arguments
                obj (1, 1) app.internal.playback.Clock
            end
            obj.bank();
            obj.IsPaused = false;
        end

        function hold(obj)
        % HOLD Begin a temporary calculation pause; nested calls are supported.
            arguments
                obj (1, 1) app.internal.playback.Clock
            end
            obj.bank();
            obj.HoldCount = obj.HoldCount + 1;
        end

        function release(obj)
        % RELEASE End one calculation pause without changing the user's pause state.
            arguments
                obj (1, 1) app.internal.playback.Clock
            end
            assert(obj.HoldCount > 0, "RippleSimulator:UnbalancedClockHold", ...
                "A clock hold must be active before it can be released.");
            try
                obj.bank();
            catch exception
                obj.HoldCount = obj.HoldCount - 1;
                obj.IsPaused = true;
                rethrow(exception);
            end
            obj.HoldCount = obj.HoldCount - 1;
        end

        function restart(obj)
        % RESTART Begin a new time origin while retaining playback state.
            arguments
                obj (1, 1) app.internal.playback.Clock
            end
            obj.bank();
            obj.ActiveTime = 0;
            obj.PhysicalTime = 0;
        end
    end

    methods (Access = private)
        function bank(obj)
            if obj.IsBanking
                return
            end
            obj.IsBanking = true;
            guard = onCleanup(@() obj.finishBanking());
            currentTime = obj.readTime();
            elapsed = currentTime - obj.LastSample;
            assert(elapsed >= 0, "RippleSimulator:NonmonotonicClock", ...
                "Elapsed time moved backward from %.17g to %.17g seconds.", obj.LastSample, currentTime);
            if ~obj.IsPaused && obj.HoldCount == 0
                activeTime = obj.ActiveTime + elapsed;
                physicalTime = obj.PhysicalTime + obj.Rate*elapsed;
                assert(isfinite(activeTime) && isfinite(physicalTime), ...
                    "RippleSimulator:ClockOverflow", "The elapsed-time mapping exceeded its numeric range.");
                obj.ActiveTime = activeTime;
                obj.PhysicalTime = physicalTime;
            end
            obj.LastSample = currentTime;
        end

        function finishBanking(obj)
            obj.IsBanking = false;
        end

        function value = readTime(obj)
            value = obj.TimeSource();
            validateattributes(value, "numeric", {"scalar", "real", "finite"}, ...
                "Clock", "TimeSource result");
            value = double(value);
        end
    end
end

function source = createTimeSource()
    epoch = tic();
    source = @() toc(epoch);
end
