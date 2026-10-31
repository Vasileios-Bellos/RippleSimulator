classdef (Sealed) AppExamplesTest < support.ProjectTestCase
    % APPEXAMPLESTEST Verify application examples, scenarios, and ownership.

    properties (TestParameter)
        Example = struct( ...
            Gravity=struct(Launch=@gravityWavesExample, Inputs=0), ...
            Balanced=struct(Launch=@gravityCapillaryWavesExample, Inputs=0), ...
            Capillary=struct(Launch=@capillaryWavesExample, Inputs=0), ...
            Reflection=struct(Launch=@waveReflectionExample, Inputs=0), ...
            Olive=struct(Launch=@oliveOilRipplesExample, Inputs=0), ...
            Silicone5=struct(Launch=@siliconeOil5cStRipplesExample, Inputs=0), ...
            Silicone100=struct(Launch=@siliconeOil100cStRipplesExample, Inputs=0), ...
            Chocolate=struct(Launch=@moltenChocolateRipplesExample, Inputs=0), ...
            Honey=struct(Launch=@honeyRipplesExample, Inputs=0), ...
            Wavemaker=struct(Launch=@wavemakerRipplesExample, Inputs=0), ...
            Rain=struct(Launch=@rainRipplesExample, Inputs=20), ...
            Interference=struct(Launch=@waveInterferenceExample, Inputs=2), ...
            Side=struct(Launch=@sideReflectionExample, Inputs=1), ...
            Corner=struct(Launch=@cornerReflectionExample, Inputs=1), ...
            Wireframe=struct(Launch=@wireframeRipplesExample, Inputs=0), ...
            Colormap=struct(Launch=@colormapRipplesExample, Inputs=0))
        Water = struct( ...
            Gravity=struct(Launch=@gravityWavesExample, Setup="Gravity"), ...
            Balanced=struct(Launch=@gravityCapillaryWavesExample, Setup="Balanced"), ...
            Capillary=struct(Launch=@capillaryWavesExample, Setup="Capillary"))
        Material = struct( ...
            Olive=struct(Launch=@oliveOilRipplesExample, Name="Olive oil", ...
                Temperature=23, Wavelength=0.05, Pressure=0.10, Scale=100), ...
            Silicone5=struct(Launch=@siliconeOil5cStRipplesExample, Name="KF-96L-5cs", ...
                Temperature=25, Wavelength=0.05, Pressure=0.10, Scale=100), ...
            Silicone100=struct(Launch=@siliconeOil100cStRipplesExample, Name="KF-96-100cs", ...
                Temperature=25, Wavelength=0.05, Pressure=0.10, Scale=100), ...
            Chocolate=struct(Launch=@moltenChocolateRipplesExample, Name="Chocolate", ...
                Temperature=60, Wavelength=0.075, Pressure=0.20, Scale=200), ...
            Honey=struct(Launch=@honeyRipplesExample, Name="Honey", ...
                Temperature=30, Wavelength=0.10, Pressure=0.15, Scale=200))
        Reflection = struct( ...
            Side=struct(Launch=@sideReflectionExample, Position=[0.100125, 0]), ...
            Corner=struct(Launch=@cornerReflectionExample, Position=[0.100125, 0.100125]))
        Display = struct( ...
            Wireframe=struct(Launch=@wireframeRipplesExample, Wireframe=true, ...
                Mode="Shaded", Colormap="winter"), ...
            Colormap=struct(Launch=@colormapRipplesExample, Wireframe=false, ...
                Mode="Elevation", Colormap="hsv"))
        Active = struct( ...
            Wireframe=struct(Launch=@wireframeRipplesExample, AddRipple=true), ...
            Colormap=struct(Launch=@colormapRipplesExample, AddRipple=true), ...
            Side=struct(Launch=@sideReflectionExample, AddRipple=false), ...
            Corner=struct(Launch=@cornerReflectionExample, AddRipple=false))
    end

    methods (TestMethodSetup)
        function configureHiddenFigures(testCase)
            visibility = get(groot, "DefaultFigureVisible");
            callback = get(groot, "DefaultFigureCreateFcn");
            testCase.addTeardown(@() set(groot, ...
                "DefaultFigureVisible", visibility, "DefaultFigureCreateFcn", callback));
            set(groot, "DefaultFigureVisible", "off", "DefaultFigureCreateFcn", @hideExampleFigure);
        end
    end

    methods (Test, TestTags = {'Integration'})
        function examplesRemainOpen(testCase, Example)
            originalTimers = timerfindall();
            originalRandom = rng();
            simulator = openExample(testCase, Example.Launch);
            ownedTimer = setdiff(timerfindall(), originalTimers);

            testCase.verifyClass(simulator, "app.RippleSimulatorApp");
            testCase.verifyEqual(string(simulator.Figure.Visible), "off");
            testCase.verifyEqual(simulator.Status, "Running");
            testCase.verifyFalse(simulator.Paused);
            testCase.assertNumElements(ownedTimer, 1);
            testCase.verifyEqual(string(ownedTimer.Running), "on");
            simulator.Paused = true;
            state = simulator.describe();
            testCase.verifyEqual(state.Simulation.AcceptedCount+state.PendingRain, Example.Inputs);
            testCase.verifyEqual(simulator.IsAtRest, Example.Inputs == 0);
            testCase.verifyEqual(simulator.LastError, "");
            testCase.verifyEqual(rng(), originalRandom);
            ownedFigure = simulator.Figure;

            simulator.close();

            testCase.verifyFalse(isvalid(ownedTimer));
            testCase.verifyFalse(isgraphics(ownedFigure));
            testCase.verifyEqual(timerfindall(), originalTimers);
        end

        function waterExamplesUsePresets(testCase, Water)
            expected = app.internal.simulation.defaultSetup(Water.Setup);
            simulator = openExample(testCase, Water.Launch);
            simulator.Paused = true;

            testCase.verifyEqual(simulator.Material, "Water");
            testCase.verifyEqual(simulator.DomainSize, expected.DomainSize, AbsTol=eps);
            testCase.verifyEqual(simulator.Wavelength, expected.Source.Wavelength, AbsTol=eps);
            testCase.verifyEqual(simulator.PressureImpulse, expected.Source.PressureImpulse, AbsTol=eps);
            testCase.verifyEqual(simulator.PlaybackRate, expected.PlaybackRate, AbsTol=eps);
            testCase.verifyEqual(simulator.HeightScale, expected.HeightScale, AbsTol=eps);
            testCase.verifyEqual(simulator.SourceMode, "Impulse");
            testCase.verifyTrue(simulator.IsAtRest);
        end

        function materialExamplesUsePresets(testCase, Material)
            simulator = openExample(testCase, Material.Launch);
            simulator.Paused = true;

            testCase.verifyEqual(simulator.Material, Material.Name);
            testCase.verifyEqual(simulator.Temperature, Material.Temperature, AbsTol=eps);
            testCase.verifyEqual(simulator.Wavelength, Material.Wavelength, AbsTol=eps);
            testCase.verifyEqual(simulator.PressureImpulse, Material.Pressure, AbsTol=eps);
            testCase.verifyEqual(simulator.HeightScale, Material.Scale, AbsTol=eps);
            testCase.verifyEqual(simulator.DomainSize, 0.65, AbsTol=eps);
            testCase.verifyEqual(simulator.PlaybackRate, 0.25, AbsTol=eps);
            testCase.verifyTrue(simulator.IsAtRest);
        end

        function reflectionOpensAnEmptyTank(testCase)
            simulator = openExample(testCase, @waveReflectionExample);
            simulator.Paused = true;
            state = simulator.describe();

            testCase.verifyEqual(simulator.DomainSize, 0.3, AbsTol=eps);
            testCase.verifyTrue(simulator.ReflectionsEnabled);
            testCase.verifyEqual(simulator.ReflectionCoefficient, 1, AbsTol=eps);
            testCase.verifyEqual(state.Camera.Position(1:2), [0, 0], AbsTol=eps);
            testCase.verifyEqual(state.Camera.UpVector, [0, 1, 0], AbsTol=eps);
            testCase.verifyTrue(simulator.IsAtRest);
        end

        function reflectionUsesApprovedGeometry(testCase, Reflection)
            simulator = openExample(testCase, Reflection.Launch);
            simulator.Paused = true;
            state = simulator.describe();

            testCase.verifyEqual(simulator.DomainSize, 0.3, AbsTol=eps);
            testCase.verifyTrue(simulator.ReflectionsEnabled);
            testCase.verifyEqual(simulator.ReflectionCoefficient, 1, AbsTol=eps);
            testCase.assertNumElements(state.Simulation.Events, 1);
            testCase.verifyEqual(state.Simulation.Events.Position, Reflection.Position, AbsTol=eps);
            testCase.verifyEqual(state.Simulation.Events.Strength, 0.1, AbsTol=eps);
            testCase.verifyEqual(simulator.HeightScale, 100, AbsTol=eps);
            testCase.verifyEqual(state.Camera.Position(1:2), [0, 0], AbsTol=eps);
            testCase.verifyEqual(state.Camera.UpVector, [0, 1, 0], AbsTol=eps);
        end

        function interferenceSourcesAreEqualTime(testCase)
            simulator = openExample(testCase, @waveInterferenceExample);
            simulator.Paused = true;
            state = simulator.describe();
            events = state.Simulation.Events;

            testCase.assertNumElements(events, 2);
            testCase.verifyEqual(vertcat(events.Position), ...
                [-0.063375, -0.013; 0.063375, 0.013], AbsTol=eps);
            testCase.verifyEqual([events.Time]-events(1).Time, [0, 0], AbsTol=eps);
            testCase.verifyEqual([events.Strength], [0.1, 0.1], AbsTol=eps);
            testCase.verifyEqual(simulator.DomainSize, 0.65, AbsTol=eps);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function rainCompletesItsScheduledBurst(testCase)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsEqualTo

            simulator = openExample(testCase, @rainRipplesExample);
            testCase.assertThat(@() simulator.describe().PendingRain, ...
                Eventually(IsEqualTo(0), WithTimeoutOf=10));
            simulator.Paused = true;
            state = simulator.describe();

            testCase.verifyEqual(state.Simulation.AcceptedCount, 20);
            testCase.verifyEqual(state.PendingRain, 0);
            testCase.verifyEqual(simulator.RainStrengthScale, 1, AbsTol=eps);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function wavemakerSelectsWavemakerMode(testCase)
            simulator = openExample(testCase, @wavemakerRipplesExample);
            simulator.Paused = true;

            testCase.verifyEqual(simulator.SourceMode, "Wavemaker");
            testCase.verifyEqual(simulator.Wavelength, 0.05, AbsTol=eps);
            testCase.verifyEqual(simulator.PressureImpulse, 0.1, AbsTol=eps);
            testCase.verifyTrue(simulator.IsAtRest);
        end

        function displayExamplesPreservePhysics(testCase, Display)
            simulator = openExample(testCase, Display.Launch);
            simulator.Paused = true;
            state = simulator.describe();

            testCase.verifyEqual(simulator.Wireframe, Display.Wireframe);
            testCase.verifyEqual(simulator.SurfaceMode, Display.Mode);
            testCase.verifyEqual(simulator.Colormap, Display.Colormap);
            testCase.verifyEqual(simulator.Material, "Water");
            testCase.verifyEqual(simulator.Wavelength, 0.05, AbsTol=eps);
            testCase.verifyEqual(simulator.PressureImpulse, 0.1, AbsTol=eps);
            testCase.verifyEqual(simulator.DomainSize, 0.65, AbsTol=eps);
            testCase.verifyEmpty(state.Simulation.Events);
            testCase.verifyEqual(state.Simulation.AcceptedCount, 0);
            testCase.verifyTrue(simulator.IsAtRest);
        end

        function playbackAcceptsFurtherInput(testCase, Active)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsGreaterThan

            simulator = openActiveExample(testCase, Active);
            initialTime = simulator.PhysicalTime;
            testCase.assertThat(@() simulator.PhysicalTime, ...
                Eventually(IsGreaterThan(initialTime), WithTimeoutOf=5));
            testCase.assertFalse(simulator.IsAtRest);
            surface = findobj(simulator.Figure, Tag="FluidSurface");
            beforeInput = simulator.describe();
            hit = support.SurfaceHit();
            hit.IntersectionPoint = [-0.25, -0.125, 0];

            surface.ButtonDownFcn(surface, hit);
            inputTime = simulator.PhysicalTime;
            testCase.assertThat(@() simulator.PhysicalTime, ...
                Eventually(IsGreaterThan(inputTime), WithTimeoutOf=5));
            simulator.Paused = true;
            afterInput = simulator.describe();

            testCase.verifyEqual(afterInput.Simulation.AcceptedCount, ...
                beforeInput.Simulation.AcceptedCount+1);
            testCase.verifyEqual(findobj(simulator.Figure, Tag="FluidSurface"), surface);
            testCase.verifyEqual(simulator.LastError, "");
        end

        function noOutputKeepsApplicationOpen(testCase)
            originalFigures = findall(groot, Type="figure");
            originalTimers = timerfindall();

            gravityWavesExample();
            ownedFigures = setdiff(findall(groot, Type="figure"), originalFigures);
            testCase.addTeardown(@() delete(ownedFigures(isgraphics(ownedFigures))));
            ownedTimer = setdiff(timerfindall(), originalTimers);

            testCase.assertNumElements(ownedFigures, 1);
            testCase.assertNumElements(ownedTimer, 1);
            testCase.verifyEqual(string(ownedFigures.Visible), "off");
            testCase.verifyEqual(string(ownedTimer.Running), "on");

            close(ownedFigures);

            testCase.verifyFalse(isvalid(ownedTimer));
            testCase.verifyFalse(isgraphics(ownedFigures));
        end
    end
end

function hideExampleFigure(figureHandle, ~)
    listener = addlistener(figureHandle, "Visible", "PostSet", @(~, ~) suppressDisplay(figureHandle));
    setappdata(figureHandle, "AppExamplesVisibilityListener", listener);
    suppressDisplay(figureHandle);
end

function suppressDisplay(figureHandle)
    if ~isgraphics(figureHandle) || figureHandle.Visible == "off"
        return
    end
    figureHandle.Visible = "off";
    soundMenu = findall(figureHandle, Tag="SoundMenu");
    if isscalar(soundMenu) && string(soundMenu.Checked) == "on"
        soundMenu.MenuSelectedFcn(soundMenu, []);
    end
end

function simulator = openExample(testCase, launch)
    simulator = launch();
    testCase.addTeardown(@() simulator.close());
    simulator.SoundEnabled = false;
end

function simulator = openActiveExample(testCase, scenario)
    simulator = openExample(testCase, scenario.Launch);
    if scenario.AddRipple
        simulator.Paused = true;
        simulator.addRipple([0, 0]);
        simulator.Paused = false;
    end
end
