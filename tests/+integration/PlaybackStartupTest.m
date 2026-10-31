classdef (Sealed) PlaybackStartupTest < support.ProjectTestCase
    % PLAYBACKSTARTUPTEST Verify paused construction and playback ownership.

    methods (Test, TestTags = {'Integration'})
        function automaticStartupWaitsAtTimeZero(testCase)
            [simulator, time, pump] = createPausedSimulator(testCase, true);
            initial = simulator.snapshot(Derivatives=true);

            time.Value = 10;
            drawnow;
            simulator.update();

            testCase.verifyTrue(simulator.Paused);
            testCase.verifyEqual(simulator.Status, "Paused");
            testCase.verifyEqual(simulator.PhysicalTime, 0, AbsTol=0);
            testCase.verifyEqual(simulator.snapshot(Derivatives=true), initial);
            testCase.verifyEqual(string(pump.Running), "off");
            testCase.verifyEqual(pump.TasksExecuted, 0);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function configurationKeepsSourceTimes(testCase)
            [simulator, time, pump] = createPausedSimulator(testCase, true);
            time.Value = 1;
            simulator.DomainSize = 0.3;
            simulator.SurfaceMode = "Elevation";
            simulator.Colormap = "hsv";
            simulator.setCameraView("Top");
            simulator.addRipple([-0.05, 0]);

            time.Value = 2;
            simulator.addRipple([0.05, 0]);
            simulator.update();
            state = simulator.describe();

            testCase.verifyTrue(simulator.Paused);
            testCase.verifyEqual(simulator.PhysicalTime, 0, AbsTol=0);
            testCase.verifyEqual(string(pump.Running), "off");
            testCase.verifyEqual(simulator.DomainSize, 0.3, AbsTol=eps);
            testCase.verifyEqual(simulator.SurfaceMode, "Elevation");
            testCase.verifyEqual(simulator.Colormap, "hsv");
            testCase.verifyEqual(state.Camera.Position(1:2), [0, 0], AbsTol=eps);
            testCase.verifyEqual(state.Simulation.AcceptedCount, 2);
            testCase.assertNumElements(state.Simulation.Events, 2);
            testCase.verifyEqual([state.Simulation.Events.Time], [0, 0], AbsTol=0);
            testCase.verifyEqual(vertcat(state.Simulation.Events.Position), ...
                [-0.05, 0; 0.05, 0], AbsTol=eps);
            testCase.verifyFalse(simulator.IsAtRest);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function resumeAndPauseUseOwnedTimer(testCase)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsGreaterThan

            [simulator, time, pump] = createPausedSimulator(testCase, true);
            simulator.addRipple([0, 0]);

            simulator.Paused = false;
            time.Value = 0.04;
            testCase.assertThat(@() simulator.PhysicalTime, ...
                Eventually(IsGreaterThan(0), WithTimeoutOf=5));
            running = string(pump.Running);
            simulator.Paused = true;
            frozen = simulator.snapshot(Derivatives=true);
            time.Value = 10;
            drawnow;
            simulator.update();

            testCase.verifyEqual(running, "on");
            testCase.verifyGreaterThan(pump.TasksExecuted, 0);
            testCase.verifyEqual(frozen.Time, 0.04*simulator.PlaybackRate, AbsTol=1e-14);
            testCase.verifyFalse(frozen.IsAtRest);
            testCase.verifyEqual(simulator.snapshot(Derivatives=true), frozen);
            testCase.verifyTrue(simulator.Paused);
            testCase.verifyEqual(simulator.Status, "Paused");
            testCase.verifyEqual(string(pump.Running), "off");
            testCase.verifyEqual(simulator.LastError, "");
        end

        function manualUpdatesAfterResume(testCase)
            [simulator, time, pump] = createPausedSimulator(testCase, false);
            simulator.addRipple([0, 0]);
            time.Value = 2;

            simulator.Paused = false;
            time.Value = 2.04;
            drawnow;
            beforeUpdate = simulator.snapshot(Derivatives=true);
            simulator.update();
            afterUpdate = simulator.snapshot(Derivatives=true);

            testCase.verifyFalse(simulator.Paused);
            testCase.verifyEqual(simulator.Status, "Running");
            testCase.verifyEqual(string(pump.Running), "off");
            testCase.verifyEqual(pump.TasksExecuted, 0);
            testCase.verifyEqual(beforeUpdate.Time, 0, AbsTol=0);
            testCase.verifyEqual(afterUpdate.Time, 0.04*simulator.PlaybackRate, AbsTol=1e-14);
            testCase.verifyFalse(afterUpdate.IsAtRest);
            testCase.verifyGreaterThan(max(abs(afterUpdate.Elevation), [], "all"), 0);
            testCase.verifyEqual(simulator.LastError, "");
        end
    end
end

function [simulator, time, pump] = createPausedSimulator(testCase, automaticUpdates)
    originalTimers = timerfindall();
    originalFigures = findall(groot, Type="figure");
    time = support.ManualTime();
    simulator = rippleSimulator(Visible="off", Paused=true, AutomaticUpdates=automaticUpdates, ...
        TimeSource=@() time.Value, GridResolution=101);
    testCase.addTeardown(@() closeAndVerifyResources(testCase, simulator, originalTimers, originalFigures));
    pump = setdiff(timerfindall(), originalTimers);
    testCase.assertNumElements(pump, 1);
    simulator.SoundEnabled = false;
end

function closeAndVerifyResources(testCase, simulator, originalTimers, originalFigures)
    simulator.close();
    testCase.verifyFalse(isvalid(simulator));
    testCase.verifyEqual(timerfindall(), originalTimers);
    testCase.verifyEqual(findall(groot, Type="figure"), originalFigures);
end
