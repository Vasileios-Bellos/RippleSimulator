classdef ClockTest < support.ProjectTestCase
    % CLOCKTEST Verify physical time independently of rendering cadence.

    properties
        WallTime (1, 1) double = 0
    end

    methods (Test, TestTags = {'Unit'})
        function delayedUpdatesPreserveTime(testCase)
            clock = app.internal.playback.Clock(0.25, @() testCase.WallTime);

            testCase.WallTime = 123.456;
            state = clock.sample();

            testCase.verifyEqual(state.ActiveTime, 123.456, AbsTol=1e-12);
            testCase.verifyEqual(state.PhysicalTime, 30.864, AbsTol=1e-12);
        end

        function rateChangePreservesPriorTime(testCase)
            clock = app.internal.playback.Clock(0.25, @() testCase.WallTime);
            testCase.WallTime = 4;
            clock.setRate(2);

            testCase.WallTime = 7;
            state = clock.sample();

            testCase.verifyEqual(state.PhysicalTime, 7, AbsTol=1e-14);
        end

        function pauseExcludesElapsedWallTime(testCase)
            clock = app.internal.playback.Clock(0.5, @() testCase.WallTime);
            testCase.WallTime = 2;
            clock.pause();
            testCase.WallTime = 20;
            clock.resume();

            testCase.WallTime = 24;
            state = clock.sample();

            testCase.verifyEqual(state.PhysicalTime, 3, AbsTol=1e-14);
        end

        function nestedOperationsPreservePause(testCase)
            clock = app.internal.playback.Clock(1, @() testCase.WallTime);
            testCase.WallTime = 1;
            clock.hold();
            clock.hold();
            testCase.WallTime = 10;
            clock.release();
            clock.pause();
            testCase.WallTime = 20;
            clock.release();

            testCase.WallTime = 30;
            state = clock.sample();

            testCase.verifyTrue(state.IsPaused);
            testCase.verifyFalse(state.IsHeld);
            testCase.verifyEqual(state.PhysicalTime, 1, AbsTol=eps);
        end

        function backwardTimeIsRejected(testCase)
            clock = app.internal.playback.Clock(1, @() testCase.WallTime);
            testCase.WallTime = -1;

            testCase.verifyError(@() clock.sample(), "RippleSimulator:NonmonotonicClock");
        end

        function unmatchedReleaseIsRejected(testCase)
            clock = app.internal.playback.Clock(1, @() testCase.WallTime);

            testCase.verifyError(@() clock.release(), "RippleSimulator:UnbalancedClockHold");
        end
    end
end
