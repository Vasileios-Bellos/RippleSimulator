classdef RippleSimulatorAppTest < support.ProjectTestCase
    % RIPPLESIMULATORAPPTEST Verify input, playback, presentation, and ownership.

    properties
        Simulator
        Time
    end

    properties (TestParameter)
        Setup = {"Gravity", "Balanced", "Capillary"}
    end

    methods (TestMethodSetup)
        function createSimulator(testCase)
            testCase.Time = support.ManualTime();
            testCase.Simulator = rippleSimulator(Visible="off", AutomaticUpdates=false, ...
                TimeSource=@() testCase.Time.Value, GridResolution=101);
            testCase.addTeardown(@() testCase.Simulator.close());
            testCase.Simulator.SoundEnabled = false;
            testCase.Simulator.PlaybackRate = 1;
        end
    end

    methods (Test, TestTags = {'Integration'})
        function launcherReturnsThePublicClass(testCase)
            testCase.verifyClass(testCase.Simulator, "app.RippleSimulatorApp");
            testCase.verifyEqual(string(testCase.Simulator.Figure.Visible), "off");
        end

        function impulseStartsAtEquilibrium(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([0, 0]);
            initial = simulator.snapshot(Derivatives=true);

            testCase.Time.Value = 0.001;
            simulator.update();
            early = simulator.snapshot(Derivatives=true);

            testCase.verifyEqual(initial.Elevation, zeros(101), AbsTol=0);
            testCase.verifyLessThan(initial.Velocity(51, 51), 0);
            testCase.verifyLessThan(early.Elevation(51, 51), 0);
            testCase.verifyFalse(initial.IsAtRest);
        end

        function pausePreservesTheDisplayedField(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([0, 0]);
            simulator.Paused = true;
            initial = simulator.snapshot(Derivatives=true);

            testCase.Time.Value = 1;
            simulator.update();

            testCase.verifyEqual(simulator.snapshot(Derivatives=true), initial);
            testCase.verifyEqual(simulator.MeasuredFPS, 0, AbsTol=0);
        end

        function pausedRainCreatesNoInputs(testCase)
            simulator = testCase.Simulator;
            simulator.Paused = true;

            simulator.rain();
            testCase.Time.Value = 2;
            simulator.update();
            state = simulator.describe();

            testCase.verifyEqual(state.PendingRain, 0);
            testCase.verifyEqual(state.Simulation.AcceptedCount, 0);
            testCase.verifyTrue(simulator.IsAtRest);
        end

        function simultaneousSourcesSuperimpose(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([-0.05, 0]);
            simulator.addRipple([0.05, 0]);
            testCase.Time.Value = 0.12;
            simulator.update();
            combined = simulator.snapshot(Derivatives=true);
            simulator.clear();
            simulator.addRipple([-0.05, 0]);
            testCase.Time.Value = 0.24;
            simulator.update();
            single = simulator.snapshot(Derivatives=true);

            testCase.verifyEqual(combined.Elevation, single.Elevation+fliplr(single.Elevation), AbsTol=2e-10);
            testCase.verifyEqual(combined.Velocity, single.Velocity+fliplr(single.Velocity), AbsTol=2e-8);
            testCase.verifyEqual(combined.Elevation, flipud(combined.Elevation), AbsTol=2e-10);
        end

        function displayPreservesPhysicalData(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([0, 0]);
            testCase.Time.Value = 0.12;
            simulator.update();
            physical = simulator.snapshot(Derivatives=true);
            surface = findobj(simulator.Figure, Tag="FluidSurface");
            displayedElevation = surface.ZData;

            simulator.HeightScale = 200;
            simulator.Wireframe = true;
            simulator.LightingEnabled = false;
            simulator.setCameraView("Top");

            testCase.verifyEqual(simulator.snapshot(Derivatives=true), physical);
            testCase.verifyEqual(findobj(simulator.Figure, Tag="FluidSurface"), surface);
            testCase.verifyEqual(surface.ZData, 2*displayedElevation, AbsTol=1e-14);
        end

        function rainRetainsScheduledImpactTimes(testCase)
            simulator = testCase.Simulator;
            simulator.PlaybackRate = 0.25;
            simulator.rain();

            testCase.Time.Value = 1;
            simulator.update();
            state = simulator.describe();

            testCase.verifyEqual(state.PendingRain, 0);
            testCase.verifyEqual(state.Simulation.AcceptedCount, 20);
            testCase.verifyEqual([state.Simulation.Events.Time], (0:19)*0.05*0.25, AbsTol=1e-14);
            testCase.verifyEqual([state.Simulation.Events.Strength], repmat(0.1, 1, 20), AbsTol=eps);
        end

        function completedMotionIsExactlyStill(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([0, 0]);

            testCase.Time.Value = 100;
            simulator.update();
            waveField = simulator.snapshot(Derivatives=true);

            testCase.verifyTrue(waveField.IsAtRest);
            testCase.verifyEqual(waveField.Elevation, zeros(101), AbsTol=0);
            testCase.verifyEqual(waveField.Velocity, zeros(101), AbsTol=0);
        end

        function rejectedPressurePreservesField(testCase)
            simulator = testCase.Simulator;
            simulator.addRipple([0, 0]);
            accepted = simulator.describe();
            physical = simulator.snapshot(Derivatives=true);

            testCase.verifyError(@() setPressure(simulator, -1), "MATLAB:validators:mustBeNonnegative");

            testCase.verifyEqual(simulator.describe(), accepted);
            testCase.verifyEqual(simulator.snapshot(Derivatives=true), physical);
        end

        function playbackReleasesOwnedTimer(testCase)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsGreaterThan

            initialTimers = timerfindall();
            automatic = rippleSimulator(Visible="off", AutomaticUpdates=true, GridResolution=101);
            testCase.addTeardown(@() automatic.close());
            automatic.SoundEnabled = false;
            automatic.addRipple([0, 0]);
            testCase.assertThat(@() automatic.PhysicalTime, Eventually(IsGreaterThan(0), WithTimeoutOf=5));
            first = automatic.PhysicalTime;

            automatic.addRipple([0.05, 0]);
            testCase.assertThat(@() automatic.PhysicalTime, Eventually(IsGreaterThan(first), WithTimeoutOf=5));
            automatic.Paused = true;

            testCase.verifyGreaterThan(first, 0);
            testCase.verifyGreaterThan(automatic.PhysicalTime, first);
            testCase.verifyEqual(automatic.describe().Simulation.AcceptedCount, 2);
            testCase.verifyEqual(automatic.LastError, "");
            automatic.close();
            testCase.verifyEqual(timerfindall(), initialTimers);
        end

        function capillaryUsesSlowerPlayback(testCase)
            simulator = testCase.Simulator;

            simulator.applySetup("Capillary");
            slider = findobj(simulator.Figure, Tag="PressureSlider");

            testCase.verifyEqual(simulator.PlaybackRate, 0.1, AbsTol=eps);
            testCase.verifyEqual(slider.Limits(1), 10, AbsTol=eps);
            testCase.verifyGreaterThan(simulator.PressureImpulse, 0.01);
            testCase.verifyLessThan(simulator.PressureImpulse, 0.011);
        end

        function pressureSliderSharesLowerLimit(testCase, Setup)
            simulator = testCase.Simulator;
            simulator.applySetup(Setup);

            simulator.PressureImpulse = 0.010;
            slider = findobj(simulator.Figure, Tag="PressureSlider");

            testCase.verifyEqual(slider.Limits(1), 10, AbsTol=eps);
            testCase.verifyEqual(slider.Value, 10, AbsTol=eps);
            testCase.verifyEqual(simulator.PressureImpulse, 0.010, AbsTol=eps);
        end
    end
end

function setPressure(simulator, pressure)
    simulator.PressureImpulse = pressure;
end
