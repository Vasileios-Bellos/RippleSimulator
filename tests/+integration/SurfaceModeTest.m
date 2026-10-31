classdef (Sealed) SurfaceModeTest < support.ProjectTestCase
    % SURFACEMODETEST Verify view transitions during active playback.

    properties (TestParameter)
        Mode = struct(Solid="Shaded", Colormap="Elevation", Contrast="Contrast")
        Route = struct(Property=@setWireframe, Menu=@selectWireframe, Toolbar=@pressWireframe)
    end

    methods (Test, TestTags = {'Integration'})
        function leavingWireframeRestoresLighting(testCase, Mode, Route)
            [simulator, time, pump] = createSimulator(testCase);
            simulator.SurfaceMode = Mode;
            simulator.addRipple([0, 0]);
            simulator.Paused = false;
            advancePlayback(testCase, simulator, time, pump);
            surface = findobj(simulator.Figure, Tag="FluidSurface");
            physical = simulator.snapshot(Derivatives=true);
            expectedLighting = Mode ~= "Elevation";

            Route(simulator);
            testCase.verifyTrue(simulator.Wireframe);
            testCase.verifyTrue(simulator.LightingEnabled);
            simulator.LightingEnabled = ~expectedLighting;
            Route(simulator);

            testCase.verifyFalse(simulator.Wireframe);
            testCase.verifyEqual(simulator.SurfaceMode, Mode);
            testCase.verifyEqual(simulator.LightingEnabled, expectedLighting);
            testCase.verifyEqual(simulator.snapshot(Derivatives=true), physical);
            testCase.verifyEqual(findobj(simulator.Figure, Tag="FluidSurface"), surface);
            testCase.verifyEqual(string(pump.Running), "on");
            testCase.verifyFalse(simulator.IsAtRest);
            testCase.verifyEqual(simulator.LastError, "");
            verifyLightingControls(testCase, simulator, expectedLighting);
        end

        function unchangedWireframeKeepsLighting(testCase, Mode)
            [simulator, ~, ~] = createSimulator(testCase);
            simulator.SurfaceMode = Mode;
            lighting = Mode == "Elevation";
            simulator.LightingEnabled = lighting;

            simulator.Wireframe = false;

            testCase.verifyEqual(simulator.LightingEnabled, lighting);
            verifyLightingControls(testCase, simulator, lighting);
        end
    end
end

function [simulator, time, pump] = createSimulator(testCase)
    originalTimers = timerfindall();
    originalFigures = findall(groot, Type="figure");
    time = support.ManualTime();
    simulator = rippleSimulator(Visible="off", Paused=true, AutomaticUpdates=true, ...
        TimeSource=@() time.Value, GridResolution=101);
    testCase.addTeardown(@() closeSimulator(testCase, simulator, originalTimers, originalFigures));
    simulator.SoundEnabled = false;
    pump = setdiff(timerfindall(), originalTimers);
    testCase.assertNumElements(pump, 1);
end

function advancePlayback(testCase, simulator, time, pump)
    import matlab.unittest.constraints.Eventually
    import matlab.unittest.constraints.IsGreaterThan
    time.Value = 0.16;
    testCase.assertThat(@() pump.TasksExecuted, Eventually(IsGreaterThan(0), WithTimeoutOf=5));
    testCase.assertGreaterThan(simulator.PhysicalTime, 0);
end

function verifyLightingControls(testCase, simulator, expected)
    light = findobj(simulator.Figure, Type="light");
    surface = findobj(simulator.Figure, Tag="FluidSurface");
    button = findall(surface.Parent.Toolbar, Tag="RippleToolbarlighting-on");
    testCase.assertNumElements(light, 1);
    testCase.assertNumElements(button, 1);
    testCase.verifyEqual(string(light.Visible) == "on", expected);
    testCase.verifyEqual(logical(button.Value), expected);
end

function setWireframe(simulator)
    simulator.Wireframe = ~simulator.Wireframe;
end

function selectWireframe(simulator)
    menu = findobj(simulator.Figure, Tag="WireframeMenu");
    menu.MenuSelectedFcn(menu, []);
end

function pressWireframe(simulator)
    surface = findobj(simulator.Figure, Tag="FluidSurface");
    button = findall(surface.Parent.Toolbar, Tag="RippleToolbarwireframe");
    button.ValueChangedFcn(button, []);
end

function closeSimulator(testCase, simulator, originalTimers, originalFigures)
    simulator.close();
    testCase.verifyFalse(isvalid(simulator));
    testCase.verifyEqual(timerfindall(), originalTimers);
    testCase.verifyEqual(findall(groot, Type="figure"), originalFigures);
end
