classdef InputPresentationTest < support.ProjectTestCase
    % INPUTPRESENTATIONTEST Verify onset through automatic playback callbacks.

    properties
        Simulator
        Time
        Pump
    end

    properties (TestParameter)
        Input = {"Click", "Autoclick", "API"}
    end

    methods (TestMethodSetup)
        function createSimulator(testCase)
            testCase.Time = support.ManualTime();
            originalTimers = timerfindall();
            testCase.Simulator = rippleSimulator(Visible="off", AutomaticUpdates=true, ...
                TimeSource=@() testCase.Time.Value, GridResolution=101);
            testCase.addTeardown(@() testCase.Simulator.close());
            testCase.Pump = setdiff(timerfindall(), originalTimers);
            testCase.assertNumElements(testCase.Pump, 1);
            stop(testCase.Pump);
            testCase.Simulator.SoundEnabled = false;
        end
    end

    methods (Test, TestTags = {'Integration'})
        function delayedFirstFramePreservesOnset(testCase, Input)
            testCase.Simulator.AutoclickEnabled = Input == "Autoclick";
            surface = findobj(testCase.Simulator.Figure, Tag="FluidSurface");
            testCase.Time.Value = 1;
            submitInput(testCase.Simulator, surface, Input);
            sourceTime = testCase.Simulator.describe().Simulation.Events.Time;
            testCase.Time.Value = 1.2;

            callback = testCase.Pump.TimerFcn;
            callback(testCase.Pump, []);
            initial = testCase.Simulator.snapshot(Derivatives=true);
            testCase.Time.Value = 1.22;
            callback(testCase.Pump, []);
            early = testCase.Simulator.snapshot();

            testCase.verifyEqual(initial.Time, sourceTime, AbsTol=eps);
            testCase.verifyEqual(initial.Elevation, zeros(101), AbsTol=0);
            testCase.verifyLessThan(initial.Velocity(51, 51), 0);
            testCase.verifyEqual(early.Time-sourceTime, 0.005, AbsTol=1e-14);
            testCase.verifyLessThan(early.Elevation(51, 51), 0);
            testCase.verifyGreaterThan(early.Elevation(51, 51), -0.0001);
            testCase.verifyEqual(testCase.Simulator.LastError, "");
        end

        function pausePreservesInitialState(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([0, 0]);
            testCase.Time.Value = 0.2;
            simulator.Paused = true;
            initial = simulator.snapshot(Derivatives=true);

            testCase.Time.Value = 1;
            simulator.update();
            paused = simulator.snapshot(Derivatives=true);

            testCase.verifyEqual(paused, initial);
            testCase.verifyEqual(paused.Elevation, zeros(101), AbsTol=0);
            testCase.verifyLessThan(paused.Velocity(51, 51), 0);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function rainPreservesItsSchedule(testCase)
            simulator = testCase.Simulator;
            simulator.rain();
            testCase.Time.Value = 0.2;
            callback = testCase.Pump.TimerFcn;
            callback(testCase.Pump, []);
            initial = simulator.describe();
            field = simulator.snapshot();

            testCase.Time.Value = 1.2;
            callback(testCase.Pump, []);
            completed = simulator.describe();

            testCase.verifyEqual(initial.Simulation.AcceptedCount, 1);
            testCase.verifyEqual(field.Elevation, zeros(101), AbsTol=0);
            testCase.verifyEqual(completed.Simulation.AcceptedCount, 20);
            testCase.verifyEqual([completed.Simulation.Events.Time], (0:19)*0.05*0.25, AbsTol=1e-14);
            testCase.verifyEqual(completed.PendingRain, 0);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function repeatedInputsSuperpose(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([-0.05, 0]);
            testCase.Time.Value = 0.1;
            simulator.addRipple([0.05, 0]);
            testCase.Time.Value = 0.2;
            callback = testCase.Pump.TimerFcn;
            callback(testCase.Pump, []);
            initial = simulator.snapshot();

            testCase.Time.Value = 0.22;
            callback(testCase.Pump, []);
            early = simulator.snapshot();
            state = simulator.describe();

            testCase.verifyEqual(initial.Time, 0, AbsTol=eps);
            testCase.verifyEqual(initial.Elevation, zeros(101), AbsTol=0);
            testCase.verifyEqual(state.Simulation.AcceptedCount, 2);
            testCase.verifyEqual([state.Simulation.Events.Time], [0, 0], AbsTol=eps);
            testCase.verifyEqual(early.Elevation, fliplr(early.Elevation), AbsTol=2e-10);
            testCase.verifyEqual(early.Time, 0.005, AbsTol=1e-14);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function resetReleasesPresentation(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([0, 0]);
            testCase.Time.Value = 0.2;
            simulator.reset();
            stop(testCase.Pump);
            simulator.SoundEnabled = false;
            simulator.addRipple([0, 0]);
            callback = testCase.Pump.TimerFcn;
            callback(testCase.Pump, []);

            testCase.Time.Value = 0.22;
            callback(testCase.Pump, []);

            testCase.verifyEqual(simulator.PhysicalTime, 0.005, AbsTol=1e-14);
            testCase.verifyEqual(simulator.describe().Simulation.AcceptedCount, 1);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function automaticTimerPreservesOnset(testCase)
            simulator = testCase.Simulator;
            surface = findobj(simulator.Figure, Tag="FluidSurface");
            callback = testCase.Pump.TimerFcn;
            testCase.Pump.TasksToExecute = 1;
            testCase.Pump.TimerFcn = @(~, ~) processOneFrame(testCase.Pump, callback);
            surface.ButtonDownFcn(surface, support.SurfaceHit());
            testCase.Time.Value = 0.2;
            start(testCase.Pump);
            wait(testCase.Pump);
            initial = simulator.snapshot();

            testCase.Time.Value = 0.22;
            start(testCase.Pump);
            wait(testCase.Pump);
            moving = simulator.snapshot();
            hit = support.SurfaceHit();
            hit.IntersectionPoint = [0.05, 0, 0];
            surface.ButtonDownFcn(surface, hit);
            testCase.Time.Value = 0.42;
            start(testCase.Pump);
            wait(testCase.Pump);
            repeated = simulator.snapshot();

            testCase.verifyEqual(initial.Time, 0, AbsTol=eps);
            testCase.verifyEqual(initial.Elevation, zeros(101), AbsTol=0);
            testCase.verifyLessThan(moving.Elevation(51, 51), 0);
            testCase.verifyEqual(repeated.Time, moving.Time, AbsTol=eps);
            testCase.verifyEqual(repeated.Elevation, moving.Elevation, AbsTol=2e-10);
            testCase.verifyEqual(simulator.describe().Simulation.AcceptedCount, 2);
            testCase.verifyEqual(findobj(simulator.Figure, Tag="FluidSurface"), surface);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function inputDuringFramePreservesOnset(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([-0.05, 0]);
            callback = testCase.Pump.TimerFcn;
            callback(testCase.Pump, []);
            surface = findobj(simulator.Figure, Tag="FluidSurface");
            injected = false;
            armed = true;
            % The visibility query follows rendering and precedes frame completion.
            listener = addlistener(simulator.Figure, "Visible", "PostGet", @insertRipple);
            releaseListener = onCleanup(@() delete(listener));
            testCase.Time.Value = 0.02;
            callback(testCase.Pump, []);
            delete(releaseListener);
            accepted = simulator.snapshot();

            testCase.Time.Value = 0.42;
            callback(testCase.Pump, []);
            initial = simulator.snapshot();
            testCase.Time.Value = 0.44;
            callback(testCase.Pump, []);
            moving = simulator.snapshot();

            testCase.verifyTrue(injected);
            testCase.verifyEqual(simulator.describe().Simulation.AcceptedCount, 2);
            testCase.verifyEqual(accepted.Time, 0.005, AbsTol=1e-14);
            testCase.verifyEqual(initial.Time, accepted.Time, AbsTol=1e-14);
            testCase.verifyEqual(initial.Elevation, accepted.Elevation, AbsTol=2e-10);
            testCase.verifyEqual(moving.Time-initial.Time, 0.005, AbsTol=1e-14);
            testCase.verifyEqual(findobj(simulator.Figure, Tag="FluidSurface"), surface);
            testCase.verifyEqual(simulator.LastError, "");

            function insertRipple(~, ~)
                if ~armed
                    return
                end
                armed = false;
                hit = support.SurfaceHit();
                hit.IntersectionPoint = [0.05, 0, 0];
                surface.ButtonDownFcn(surface, hit);
                injected = true;
                testCase.Time.Value = 0.22;
            end
        end
    end
end

function processOneFrame(pump, callback)
    callback(pump, []);
    stop(pump);
end

function submitInput(simulator, surface, input)
    if input == "API"
        simulator.addRipple([0, 0]);
    else
        surface.ButtonDownFcn(surface, support.SurfaceHit());
    end
end
