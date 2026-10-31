classdef (Sealed) SetupMenuTest < support.ProjectTestCase
    % SETUPMENUTEST Verify scaled experiment selection and accepted settings.

    properties (TestParameter)
        Setup = {"Gravity", "Balanced", "Capillary"}
    end

    methods (Test, TestTags = {'Integration'})
        function constructorSelectsPreset(testCase, Setup)
            simulator = rippleSimulator(Setup=Setup, Visible="off", AutomaticUpdates=false);
            testCase.addTeardown(@() simulator.close());
            verifyPreset(testCase, simulator, Setup);
        end

        function menuAppliesCompletePreset(testCase, Setup)
            simulator = rippleSimulator(Visible="off", AutomaticUpdates=false);
            testCase.addTeardown(@() simulator.close());
            simulator.SoundEnabled = false;
            simulator.Temperature = 30;
            simulator.PlaybackRate = 0.5;
            simulator.HeightScale = 150;
            simulator.Paused = true;
            simulator.addRipple([0, 0]);
            menu = findobj(simulator.Figure, Tag=Setup+"Setup");

            menu.MenuSelectedFcn(menu, []);

            verifyPreset(testCase, simulator, Setup);
            testCase.verifyTrue(simulator.Paused);
            testCase.verifyTrue(simulator.IsAtRest);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function gravityPrecedesOtherSetups(testCase)
            simulator = rippleSimulator(Visible="off", AutomaticUpdates=false);
            testCase.addTeardown(@() simulator.close());
            gravity = findobj(simulator.Figure, Tag="GravitySetup");
            balanced = findobj(simulator.Figure, Tag="BalancedSetup");
            capillary = findobj(simulator.Figure, Tag="CapillarySetup");

            testCase.verifyLessThan(gravity.Position, balanced.Position);
            testCase.verifyLessThan(balanced.Position, capillary.Position);
        end

        function checkmarkTracksAcceptedValues(testCase)
            simulator = rippleSimulator(Visible="off", AutomaticUpdates=false);
            testCase.addTeardown(@() simulator.close());
            gravity = findobj(simulator.Figure, Tag="GravitySetup");

            simulator.PressureImpulse = 0.075;
            testCase.verifyEqual(gravity.Checked, matlab.lang.OnOffSwitchState.off);
            simulator.PressureImpulse = 0.1;
            testCase.verifyEqual(gravity.Checked, matlab.lang.OnOffSwitchState.on);
            simulator.HeightScale = 100;
            testCase.verifyEqual(gravity.Checked, matlab.lang.OnOffSwitchState.off);
            simulator.AutomaticHeightScale = true;
            testCase.verifyEqual(gravity.Checked, matlab.lang.OnOffSwitchState.on);
            simulator.SourceMode = "Wavemaker";
            testCase.verifyEqual(gravity.Checked, matlab.lang.OnOffSwitchState.off);
            simulator.SourceMode = "Impulse";
            testCase.verifyEqual(gravity.Checked, matlab.lang.OnOffSwitchState.on);
            simulator.Material = "Honey";
            testCase.verifyEqual(gravity.Checked, matlab.lang.OnOffSwitchState.off);
            simulator.reset();
            verifyPreset(testCase, simulator, "Gravity");
        end

        function viewChangesPreserveSelection(testCase)
            simulator = rippleSimulator(Visible="off", AutomaticUpdates=false);
            testCase.addTeardown(@() simulator.close());

            simulator.setCameraView("Top");
            simulator.Paused = true;
            simulator.Wireframe = true;

            verifyPreset(testCase, simulator, "Gravity");
        end
    end
end

function verifyPreset(testCase, simulator, name)
    expected = app.internal.simulation.defaultSetup(name);
    testCase.verifyEqual(simulator.Material, expected.Fluid.Name);
    testCase.verifyEqual(simulator.FluidProperties.Density, expected.Fluid.Density);
    testCase.verifyEqual(simulator.Temperature, expected.Fluid.Temperature);
    testCase.verifyEqual(simulator.DomainSize, expected.DomainSize);
    testCase.verifyEqual(simulator.Wavelength, expected.Source.Wavelength);
    testCase.verifyEqual(simulator.PressureImpulse, expected.Source.PressureImpulse);
    testCase.verifyEqual(simulator.SourceMode, expected.Source.Mode);
    testCase.verifyEqual(simulator.PlaybackRate, expected.PlaybackRate);
    testCase.verifyEqual(simulator.HeightScale, expected.HeightScale);
    testCase.verifyTrue(simulator.AutomaticHeightScale);
    for candidate = ["Gravity", "Balanced", "Capillary"]
        item = findobj(simulator.Figure, Tag=candidate+"Setup");
        testCase.verifyEqual(string(item.Checked) == "on", candidate == name);
    end
end
