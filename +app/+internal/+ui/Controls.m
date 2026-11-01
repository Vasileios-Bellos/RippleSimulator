classdef (Sealed) Controls < handle
    % CONTROLS Present accepted application state through shared command routes.
    %   Commands from menus, toolbar buttons, and sliders are routed
    %   through a shared callback function.

    properties (Access = private)
        View app.internal.ui.rendering.SurfaceView
        Command function_handle
        State (1, 1) struct = struct()
        Choices (1, :) struct = struct("Property", {}, "Value", {}, "Handle", {})
        SetupChoices (1, :) struct = struct("State", {}, "Handle", {})
        CustomChoices (1, :) struct = struct("Property", {}, "Handle", {})
        Toggles (1, 1) struct = struct()
        Buttons (1, 1) struct = struct()
        ButtonIcons (1, 1) struct = struct()
        ThemeName (1, 1) string = "light"
        ThemeListener event.listener
        ThemeChoices (:, 1) matlab.ui.container.Menu
        RainMenu matlab.ui.container.Menu
        TemperatureMenu matlab.ui.container.Menu
        SamplingMenu matlab.ui.container.Menu
        ScreenshotMenu matlab.ui.container.Menu
        TransparencyMenu matlab.ui.container.Menu
        Menus (:, 1) matlab.ui.container.Menu
        WavelengthSlider matlab.ui.control.Slider
        PressureSlider matlab.ui.control.Slider
        PlaybackSlider matlab.ui.control.Slider
        WavelengthField matlab.ui.control.NumericEditField
        PressureField matlab.ui.control.NumericEditField
        PlaybackField matlab.ui.control.NumericEditField
        WavelengthLabel matlab.ui.control.Label
        PressureLabel matlab.ui.control.Label
        PlaybackLabel matlab.ui.control.Label
        SyncRevision (1, 1) double = 0
        WavelengthDraft (1, 1) double = NaN
        PressureDraft (1, 1) double = NaN
        PlaybackDraft (1, 1) double = NaN
        ControlLayout matlab.ui.container.GridLayout
        NarrowLayout (1, 1) logical = false
        LayoutInitialized (1, 1) logical = false
        LearningMessage (1, 1) string = "Click the surface to generate a ripple. " ...
            + "Gravity and surface tension restore the displaced surface. Viscosity dissipates the wave energy.";
    end

    methods
        function obj = Controls(view, command)
        % CONTROLS Build menus, axes actions, and reusable parameter controls.
            arguments
                view (1, 1) app.internal.ui.rendering.SurfaceView
                command (1, 1) function_handle
            end
            obj.View = view;
            obj.Command = command;
            colors = app.internal.ui.appearance.themeColors(view.Figure);
            obj.ThemeName = colors.Name;
            obj.createMenus();
            obj.Menus = findall(obj.View.Figure, "Type", "uimenu", "-depth", 1);
            assignMnemonics(obj.Menus);
            obj.createToolbar();
            obj.createSliders();
            obj.applyTheme();
            obj.ThemeListener = addlistener(view, "ThemeChanged", @(~, ~) obj.applyTheme());
        end

        function delete(obj)
            if ~isempty(obj.ThemeListener) && isvalid(obj.ThemeListener)
                delete(obj.ThemeListener);
            end
            if ~isempty(obj.View) && isvalid(obj.View) && isgraphics(obj.View.ControlPanel)
                obj.View.ControlPanel.SizeChangedFcn = [];
            end
        end

        function synchronize(obj, state)
        % SYNCHRONIZE Refresh every control from one accepted state snapshot.
            arguments
                obj (1, 1) app.internal.ui.Controls
                state (1, 1) struct
            end
            obj.State = state;
            obj.SyncRevision = obj.SyncRevision + 1;
            obj.View.showFrameRate(state.ShowFPS);
            if ~isnan(obj.WavelengthDraft)
                obj.WavelengthDraft = -1;
            end
            if ~isnan(obj.PressureDraft)
                obj.PressureDraft = -1;
            end
            if ~isnan(obj.PlaybackDraft)
                obj.PlaybackDraft = -1;
            end
            for item = obj.Choices
                selected = isequal(state.(item.Property), item.Value);
                if item.Property == "SurfaceMode" && state.Wireframe
                    selected = false;
                end
                if item.Property == "HeightScale" && state.AutomaticHeightScale
                    selected = false;
                end
                item.Handle.Checked = selected;
            end
            for item = obj.CustomChoices
                choices = obj.Choices([obj.Choices.Property] == item.Property);
                item.Handle.Checked = ~any(arrayfun(@(choice) isequal(state.(item.Property), choice.Value), choices));
                if item.Property == "HeightScale" && state.AutomaticHeightScale
                    item.Handle.Checked = false;
                end
            end
            for item = obj.SetupChoices
                names = fieldnames(item.State);
                selected = true;
                for index = 1:numel(names)
                    name = names{index};
                    selected = selected && isequal(state.(name), item.State.(name));
                end
                item.Handle.Checked = selected;
            end
            names = fieldnames(obj.Toggles);
            for index = 1:numel(names)
                name = names{index};
                obj.Toggles.(name).Checked = logical(state.(name));
            end
            obj.setSoundEnabled(state.SoundEnabled);
            if obj.hasAxesToolbar()
                obj.Buttons.Pause.Value = state.Paused;
                obj.Buttons.Autoclick.Value = state.AutoclickEnabled;
                obj.Buttons.Wireframe.Value = state.Wireframe;
                obj.Buttons.Reflections.Value = state.ReflectionsEnabled;
                obj.Buttons.Lighting.Value = state.LightingEnabled;
                if state.LightingEnabled
                    obj.Buttons.Lighting.Icon = app.internal.ui.appearance.toolbarIcon("lighting-on", obj.ThemeName);
                    obj.Buttons.Lighting.Tooltip = "Lighting: on (L)";
                else
                    obj.Buttons.Lighting.Icon = app.internal.ui.appearance.toolbarIcon("lighting-off", obj.ThemeName);
                    obj.Buttons.Lighting.Tooltip = "Lighting: off (L)";
                end
                obj.Buttons.Controls.Value = state.ControlsVisible && ~state.FullScreen;
                obj.Buttons.FullScreen.Value = state.FullScreen;
            end
            if state.FullScreen
                obj.ScreenshotMenu.Accelerator = "";
            else
                obj.ScreenshotMenu.Accelerator = "S";
            end
            for menu = reshape(obj.Menus, 1, [])
                menu.Visible = ~state.FullScreen;
            end
            obj.Toggles.ControlsVisible.Enable = ~state.FullScreen;
            obj.Toggles.ReadoutVisible.Enable = ~state.FullScreen;
            if state.Paused
                obj.Toggles.Paused.Text = "&Resume (P)";
            else
                obj.Toggles.Paused.Text = "&Pause (P)";
            end
            if obj.hasAxesToolbar()
                obj.View.Axes.Toolbar.Visible = ~state.FullScreen;
                if state.FullScreen
                    obj.Buttons.Controls.ValueChangedFcn = [];
                    obj.Buttons.Controls.Tooltip = "Parameter controls are hidden in full screen";
                else
                    obj.Buttons.Controls.ValueChangedFcn = @(~, ~) obj.toolbarAction("controls");
                    obj.Buttons.Controls.Tooltip = "Parameter controls";
                end
                obj.Buttons.Rotate.Value = state.NavigationMode == "Rotate";
                obj.Buttons.Ripple.Value = state.NavigationMode == "Ripple";
                if state.Paused
                    obj.Buttons.Pause.Tooltip = "Resume playback (P)";
                    obj.Buttons.Pause.Icon = app.internal.ui.appearance.toolbarIcon("play", obj.ThemeName);
                else
                    obj.Buttons.Pause.Tooltip = "Pause playback (P)";
                    obj.Buttons.Pause.Icon = app.internal.ui.appearance.toolbarIcon("pause", obj.ThemeName);
                end
            end
            lower = max([0.005, state.DomainSize/app.internal.input.Source.MaximumDomainRatio, ...
                6*state.DomainSize/(state.GridResolution - 1)]);
            upper = 0.1;
            if state.ReflectionsEnabled && state.ReflectionCoefficient > 0 && state.ReflectionCoefficient < 1
                upper = min(upper, state.DomainSize/6.5);
            end
            if lower < upper*(1 - 64*eps)
                obj.WavelengthSlider.Limits = log10([lower, upper]);
                obj.WavelengthSlider.Enable = "on";
            else
                obj.WavelengthSlider.Limits = log10([0.5, 1.5]*state.Wavelength);
                obj.WavelengthSlider.Enable = "off";
            end
            obj.WavelengthSlider.Value = log10(state.Wavelength);
            obj.WavelengthField.Value = 1000*state.Wavelength;
            pressure = 1000*state.PressureImpulse;
            obj.PressureSlider.Limits = [10, max(200, pressure)];
            obj.PressureSlider.Value = max(10, pressure);
            obj.PressureField.Value = pressure;
            obj.PlaybackSlider.Value = log10(state.PlaybackRate);
            obj.PlaybackField.Value = state.PlaybackRate;
            obj.WavelengthLabel.Text = sprintf("Characteristic wavelength: %.3g mm", ...
                1000*state.Wavelength);
            obj.PressureLabel.Text = sprintf("Pressure strength: %.4g mPa·s", pressure);
            obj.PlaybackLabel.Text = sprintf("Playback: %.4gx", state.PlaybackRate);
            obj.TemperatureMenu.Enable = state.Material == "Water";
            obj.TransparencyMenu.Enable = ~state.Wireframe && state.LightingEnabled;
            obj.SamplingMenu.Text = sprintf("&Selected source: %.1f grid intervals per wavelength", ...
                (state.GridResolution - 1)*state.Wavelength/state.DomainSize);
            obj.updateStatus(state);
        end

        function updateStatus(obj, state)
        % UPDATESTATUS Refresh time, scale, and automatic-input availability.
            arguments
                obj (1, 1) app.internal.ui.Controls
                state (1, 1) struct
            end
            obj.State = state;
            if ~state.ReadoutVisible || state.FullScreen
                return
            end
            if state.Status == "Faulted"
                status = "Simulation stopped: " + state.LastError;
            else
                status = obj.LearningMessage;
                if state.Paused
                    status = "Paused. " + status;
                end
            end
            if string(obj.View.StatusLabel.Text) ~= status
                obj.View.StatusLabel.Text = status;
            end
            material = state.Material;
            if material == "Honey"
                material = "Honey (acacia)";
            end
            format = "Domain: %.3g x %.3g mm  |  Grid: %d x %d nodes  |  " ...
                + "Fluid: %s  |  Temperature: %.3g °C  |  Density: %.4g kg/m³  |  " ...
                + "Characteristic wavelength: %.3g mm  |  " ...
                + "Pressure strength: %.4g mPa·s  |  Height scale: %.8gx  |  Playback: %.4gx";
            scale = sprintf(format, ...
                1000*state.DomainSize, 1000*state.DomainSize, state.GridResolution, state.GridResolution, ...
                material, state.Temperature, state.FluidProperties.Density, ...
                1000*state.Wavelength, 1000*state.PressureImpulse, ...
                state.HeightScale, state.PlaybackRate);
            if string(obj.View.ScaleLabel.Text) ~= scale
                obj.View.ScaleLabel.Text = scale;
            end
            obj.updateFrameRate(state.MeasuredFPS);
            measurements = [string(sprintf("Time: %.2f s", state.PhysicalTime)), ...
                string(sprintf("Crest elevation: %.3g mm", 1000*state.Measurements.Crest)), ...
                string(sprintf("Trough depth: %.3g mm", 1000*max(0, -state.Measurements.Trough))), ...
                string(sprintf("Wave height: %.3g mm", 1000*state.Measurements.WaveHeight))];
            obj.View.showMeasurements(measurements);
        end

        function updateFrameRate(obj, framesPerSecond)
        % UPDATEFRAMERATE Refresh the optional FPS value in the bottom panel.
            if ~obj.State.ShowFPS
                return
            end
            text = sprintf("FPS: %d", round(framesPerSecond));
            if string(obj.View.FrameRateText.String) ~= text
                obj.View.FrameRateText.String = text;
            end
        end

        function setSoundEnabled(obj, enabled)
        % SETSOUNDENABLED Synchronize audio controls independently of the simulation.
            obj.State.SoundEnabled = enabled;
            obj.Toggles.SoundEnabled.Checked = enabled;
            if obj.hasAxesToolbar()
                obj.Buttons.Sound.Value = enabled;
                if enabled
                    obj.Buttons.Sound.Icon = app.internal.ui.appearance.toolbarIcon("sound-on", obj.ThemeName);
                    obj.Buttons.Sound.Tooltip = "Mute sound (M)";
                else
                    obj.Buttons.Sound.Icon = app.internal.ui.appearance.toolbarIcon("sound-off", obj.ThemeName);
                    obj.Buttons.Sound.Tooltip = "Unmute sound (M)";
                end
            end
        end

        function updated = explain(obj, action, state)
        % EXPLAIN Present a concise interpretation of the selected action.
            message = app.internal.ui.Controls.explainCommand(action, state);
            updated = strlength(message) > 0 && message ~= obj.LearningMessage;
            if updated
                obj.LearningMessage = message;
                obj.updateStatus(state);
            end
        end

        function showHelp(obj, topic)
        % SHOWHELP Open an installed documentation page or the application summary.
            arguments
                obj (1, 1) app.internal.ui.Controls
                topic {mustBeTextScalar}
            end
            if string(topic) == "about"
                address = matlab.net.URI("https://vasileios-bellos.github.io/RippleSimulator/");
                command = "web('" + replace(string(address), "'", "''") + "','-browser')";
                link = replace("matlab:" + command, ["&", """"], ["&amp;", "&quot;"]);
                message = "<p>Dispersive gravity-capillary waves in Newtonian fluids.</p>" ...
                    + "<p>Visit the <a href=""" + link + """>documentation</a> " ...
                    + "for the governing equations, numerical methods, and examples.</p>";
                uialert(obj.View.Figure, message, "About Ripple Simulator", Icon="info", Interpreter="html");
                return
            end
            folder = fileparts(fileparts(fileparts(fileparts(mfilename("fullpath")))));
            fragment = "";
            switch string(topic)
                case "index"
                    page = "index.html";
                case "reference"
                    page = "reference/index.html";
                case "sources"
                    page = "guide/physics.html";
                    fragment = "#source-definitions";
                otherwise
                    page = "guide/" + string(topic) + ".html";
            end
            filename = fullfile(folder, "docs", page);
            assert(isfile(filename), "RippleSimulator:DocumentationMissing", ...
                "The documentation page is missing: %s.", filename);
            web(filename + fragment, "-browser");
        end
    end

    methods (Access = private)
        function available = hasAxesToolbar(obj)
            toolbar = obj.View.Axes.Toolbar;
            available = ~isempty(toolbar) && isvalid(toolbar);
        end

        function applyTheme(obj)
            colors = app.internal.ui.appearance.themeColors(obj.View.Figure);
            obj.ThemeName = colors.Name;
            obj.ControlLayout.BackgroundColor = colors.Background;
            obj.WavelengthLabel.FontColor = colors.Foreground;
            obj.PressureLabel.FontColor = colors.Foreground;
            obj.PlaybackLabel.FontColor = colors.Foreground;
            if obj.hasAxesToolbar()
                icons = obj.ButtonIcons;
                if obj.Buttons.Pause.Value
                    icons.Pause = "play";
                end
                if ~obj.Buttons.Lighting.Value
                    icons.Lighting = "lighting-off";
                end
                if ~obj.Buttons.Sound.Value
                    icons.Sound = "sound-off";
                end
                names = fieldnames(icons);
                for index = 1:numel(names)
                    name = names{index};
                    obj.Buttons.(name).Icon = app.internal.ui.appearance.toolbarIcon(icons.(name), obj.ThemeName);
                end
            end
            obj.synchronizeThemeMenu();
        end

        function selectTheme(obj, name)
            [~, supported] = app.internal.ui.appearance.themeColors(obj.View.Figure);
            if ~supported
                return
            end
            if name == "auto"
                obj.View.Figure.ThemeMode = "auto";
            else
                obj.View.Figure.Theme = name;
            end
            obj.View.applyTheme();
            obj.synchronizeThemeMenu();
        end

        function synchronizeThemeMenu(obj)
            [colors, supported] = app.internal.ui.appearance.themeColors(obj.View.Figure);
            if isempty(obj.ThemeChoices) || ~supported
                return
            end
            selected = "auto";
            if string(obj.View.Figure.ThemeMode) == "manual"
                selected = colors.Name;
            end
            for index = 1:numel(obj.ThemeChoices)
                choice = obj.ThemeChoices(index);
                choice.Checked = string(choice.UserData) == selected;
            end
        end

        function createMenus(obj)
            experiment = uimenu(obj.View.Figure, Text="&Experiment");
            presets = uimenu(experiment, Text="New scaled experiment");
            names = ["Gravity", "Balanced", "Capillary"];
            labels = ["Gravity scale: 50 mm", "Gravity-capillary balance", "Capillary scale: 5 mm"];
            for index = 1:numel(names)
                setup = app.internal.simulation.defaultSetup(names(index));
                item = obj.action(presets, labels(index), "setup", names(index), names(index) + "Setup");
                state = struct(Material=setup.Fluid.Name, Temperature=setup.Fluid.Temperature, ...
                    DomainSize=setup.DomainSize, Wavelength=setup.Source.Wavelength, ...
                    PressureImpulse=setup.Source.PressureImpulse, SourceMode=setup.Source.Mode, ...
                    PlaybackRate=setup.PlaybackRate, HeightScale=setup.HeightScale, ...
                    AutomaticHeightScale=true);
                obj.SetupChoices(end + 1) = struct(State=state, Handle=item);
            end
            materials = uimenu(experiment, Text="Material");
            obj.choice(materials, "Water", "material", "Water", "Material");
            oils = uimenu(materials, Text="Oil", Tag="OilMenu");
            obj.choice(oils, "Olive oil", "material", "Olive oil", "Material");
            obj.choice(oils, "Silicone oil, 5 cSt", "material", "KF-96L-5cs", "Material");
            obj.choice(oils, "Silicone oil, 100 cSt", "material", "KF-96-100cs", "Material");
            obj.choice(materials, "Honey (acacia)", "material", "Honey", "Material");
            obj.choice(materials, "Chocolate (molten)", "material", "Chocolate", "Material");
            customMaterial = uimenu(materials, Text="Custom", Tag="CustomMaterialMenu");
            obj.Choices(end + 1) = struct(Property="Material", Value="Custom", Handle=customMaterial);
            uimenu(customMaterial, Text="Define properties...", MenuSelectedFcn=@(~, ~) obj.askFluid());
            uimenu(customMaterial, Text="Surface color...", MenuSelectedFcn=@(~, ~) obj.pickSurfaceColor());
            temperatures = uimenu(experiment, Text="Temperature", Tag="TemperatureMenu");
            obj.TemperatureMenu = temperatures;
            for temperature = [0, 10, 20, 30, 40]
                obj.choice(temperatures, sprintf("%g °C", temperature), "temperature", temperature, "Temperature");
            end
            obj.customChoice(temperatures, "Temperature", ...
                "Water temperature (°C), from 0 to 40", "temperature", 1);
            domain = uimenu(experiment, Text="Physical size", Tag="DomainSizeMenu");
            for width = [50, 100, 200, 300, 500, 650, 1000]
                obj.choice(domain, sprintf("%g mm", width), "domain", width/1000, "DomainSize");
            end
            obj.customChoice(domain, "DomainSize", "Domain width (5 to 2400 mm)", "domain", 0.001);
            resolution = uimenu(experiment, Text="Grid resolution", Tag="GridResolutionMenu");
            obj.SamplingMenu = uimenu(resolution, Text="Selected source sampling", Enable="off");
            uimenu(resolution, Text="24 or more intervals recommended for surface detail", Enable="off");
            for count = [51, 101, 201, 301, 401, 601]
                obj.choice(resolution, sprintf("%d x %d nodes", count, count), "resolution", count, "GridResolution");
            end
            obj.customChoice(resolution, "GridResolution", ...
                "Nodes per side (integer, 51 to 801)", "resolution", 1);
            reflections = uimenu(experiment, Text="Wave reflection", Tag="WaveReflectionMenu", Separator="on");
            obj.Toggles.ReflectionsEnabled = obj.action(reflections, ...
                "Reflecting boundaries (B)", "reflections", [], "ReflectionsMenu");
            reflection = uimenu(reflections, Text="Reflection coefficient", Tag="ReflectionCoefficientMenu");
            for coefficient = [1, 0.75, 0.5, 0.25, 0.1]
                obj.choice(reflection, sprintf("%g%%", 100*coefficient), ...
                    "reflectionCoefficient", coefficient, "ReflectionCoefficient");
            end
            obj.customChoice(reflection, "ReflectionCoefficient", ...
                "Reflected amplitude (0 to 100%)", "reflectionCoefficient", 0.01);
            clearSurface = obj.action(experiment, "Clear surface (C)", "clear", [], "ClearMenu");
            clearSurface.Separator = "on";
            obj.action(experiment, "Restore default experiment", "reset", [], "ResetMenu");

            source = uimenu(obj.View.Figure, Text="&Source");
            modes = uimenu(source, Text="Excitation method");
            obj.choice(modes, "Pressure impulse", "sourceMode", "Impulse", "SourceMode");
            obj.choice(modes, "Four-cycle wavemaker", "sourceMode", "Wavemaker", "SourceMode");
            wavelengths = uimenu(source, Text="Characteristic wavelength");
            for wavelength = [0.005, 0.01, 0.02, 0.025, 0.05, 0.1]
                obj.choice(wavelengths, sprintf("%g mm", 1000*wavelength), "wavelength", wavelength, "Wavelength");
            end
            obj.customChoice(wavelengths, "Wavelength", ...
                "Characteristic wavelength (5 to 100 mm)", "wavelength", 0.001);
            pressure = uimenu(source, Text="Pressure strength", Tag="PressureStrengthMenu");
            for strength = [25, 50, 75, 100, 150, 200]
                obj.choice(pressure, sprintf("%g mPa·s", strength), ...
                    "strength", strength/1000, "PressureImpulse");
            end
            obj.customChoice(pressure, "PressureImpulse", "Pressure strength (mPa·s)", "strength", 0.001);
            rain = uimenu(source, Text="Rain", Separator="on");
            obj.RainMenu = obj.action(rain, "Create rain (R)", "rain", [], "RainMenu");
            strength = uimenu(rain, Text="Pressure multiplier", Tag="RainStrengthMenu");
            for scale = [0.25, 0.5, 0.75, 1, 1.5, 2]
                obj.choice(strength, sprintf("%gx", scale), "rainStrength", scale, "RainStrengthScale");
            end
            obj.customChoice(strength, "RainStrengthScale", ...
                "Rain pressure multiplier relative to a manual click (nonnegative)", "rainStrength", 1);
            seedMenu = uimenu(rain, Text="Random seed", Tag="RandomSeedMenu");
            for seed = 0:3
                obj.choice(seedMenu, string(seed), "seed", seed, "RandomSeed");
            end
            obj.customChoice(seedMenu, "RandomSeed", "Random seed (nonnegative integer)", "seed", 1);
            autoclick = uimenu(source, Text="Auto-click", Tag="AutoclickOptionsMenu");
            obj.Toggles.AutoclickEnabled = obj.action(autoclick, "Enable (Space)", ...
                "autoclick", [], "AutoclickMenu");
            strength = uimenu(autoclick, Text="Pressure multiplier", Tag="AutoclickStrengthMenu");
            for scale = [0.1, 0.2, 0.5, 1, 1.5, 2]
                obj.choice(strength, sprintf("%gx", scale), "autoclickStrength", scale, "AutoclickStrengthScale");
            end
            obj.customChoice(strength, "AutoclickStrengthScale", ...
                "Auto-click pressure multiplier relative to a manual click (nonnegative)", "autoclickStrength", 1);

            view = uimenu(obj.View.Figure, Text="&View");
            modes = uimenu(view, Text="Surface view", Tag="SurfaceModeMenu");
            obj.choice(modes, "Solid surface (A)", "surfaceMode", "Shaded", "SurfaceMode");
            obj.Toggles.Wireframe = obj.action(modes, "Wireframe (W)", "wireframe", [], "WireframeMenu");
            obj.choice(modes, "Colormap (S)", "surfaceMode", "Elevation", "SurfaceMode");
            obj.choice(modes, "High contrast (D)", "surfaceMode", "Contrast", "SurfaceMode");
            appearance = uimenu(view, Text="Surface color", Tag="AppearanceMenu");
            for name = ["Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", "Black", "White", ...
                    "Dark brown", "Brown", "Ivory", "Amber", "Golden", "Caramel", "Sand"]
                obj.choice(appearance, name, "appearance", name, "Appearance");
            end
            customColor = uimenu(appearance, Text="Custom color...", Separator="on", ...
                Tag="CustomColorMenu", MenuSelectedFcn=@(~, ~) obj.pickSurfaceColor());
            obj.Choices(end + 1) = struct(Property="Appearance", Value="Custom", Handle=customColor);
            obj.TransparencyMenu = uimenu(view, Text="Transparency", Tag="TransparencyMenu");
            for opacity = [0.1, 0.25, 0.5, 0.75, 1]
                obj.choice(obj.TransparencyMenu, sprintf("%g%% opaque", 100*opacity), ...
                    "opacity", opacity, "SurfaceOpacity");
            end
            obj.customChoice(obj.TransparencyMenu, "SurfaceOpacity", ...
                "Surface opacity (10 to 100%)", "opacity", 0.01);
            maps = uimenu(view, Text="Colormap", Tag="ColormapMenu");
            for name = availableColormaps()
                if exist(name, "file") == 2 || exist(name, "builtin") == 5
                    obj.choice(maps, name, "colormap", name, "Colormap");
                end
            end
            custom = uimenu(maps, Text="&Custom...", Separator="on", Tag="CustomColormap", ...
                MenuSelectedFcn=@(~, ~) obj.askColormap());
            obj.CustomChoices(end + 1) = struct(Property="Colormap", Handle=custom);
            obj.Toggles.ColormapReversed = obj.action(maps, "&Reverse", ...
                "colormapReverse", [], "ColormapReverseMenu");
            obj.Toggles.ColormapReversed.Separator = "on";
            obj.Toggles.LightingEnabled = obj.action(view, "Surface lighting (L)", ...
                "lighting", [], "LightingMenu");
            heightScale = uimenu(view, Text="Height scale", Tag="HeightScaleMenu");
            obj.Toggles.AutomaticHeightScale = obj.action(heightScale, "Automatic", ...
                "automaticHeight", [], "AutomaticHeightScaleMenu");
            for factor = [20, 50, 75, 100, 150, 200]
                obj.choice(heightScale, sprintf("%gx", factor), ...
                    "heightScale", factor, "HeightScale");
            end
            obj.customChoice(heightScale, "HeightScale", ...
                "Height scale (1 to 1000000)", "heightScale", 1);
            cameras = uimenu(view, Text="Camera view", Separator="on");
            obj.action(cameras, "Close oblique (1)", "cameraView", "Close", "CloseViewMenu");
            obj.action(cameras, "Top (2)", "cameraView", "Top", "TopViewMenu");
            obj.action(cameras, "Wide oblique (3)", "cameraView", "Wide", "WideViewMenu");
            navigation = uimenu(view, Text="Pointer mode");
            for mode = ["Ripple", "Rotate", "Pan", "Zoom"]
                obj.choice(navigation, mode, "navigation", mode, "NavigationMode");
            end
            obj.action(view, "Restore camera (Home)", "camera", [], "CameraMenu");
            obj.Toggles.ControlsVisible = obj.action(view, "Parameter controls", "controls", [], "ControlsMenu");
            obj.Toggles.ControlsVisible.Separator = "on";
            obj.Toggles.ReadoutVisible = obj.action(view, "Display status", "readout", [], "ReadoutMenu");
            obj.Toggles.ShowFPS = obj.action(view, "Show FPS", "fps", [], "ShowFPSMenu");
            [~, supportsThemes] = app.internal.ui.appearance.themeColors(obj.View.Figure);
            if supportsThemes
                themeMenu = uimenu(view, Text="Theme", Tag="ThemeMenu", Separator="on", ...
                    MenuSelectedFcn=@(~, ~) obj.synchronizeThemeMenu());
                names = ["auto", "light", "dark"];
                labels = ["MATLAB Desktop", "Light", "Dark"];
                for index = 1:numel(names)
                    name = names(index);
                    obj.ThemeChoices(index, 1) = uimenu(themeMenu, Text=labels(index), ...
                        UserData=name, Tag="ThemeChoice" + name, ...
                        MenuSelectedFcn=@(~, ~) obj.selectTheme(name));
                end
            end
            background = uimenu(view, Text="Background Color", Tag="BackgroundColorMenu");
            if ~supportsThemes
                background.Separator = "on";
            end
            for name = ["Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", "Black", "White"]
                obj.choice(background, name, "backgroundColor", validatecolor(lower(name)), ...
                    "BackgroundColorSelection");
            end
            if supportsThemes
                obj.choice(background, "Theme", "backgroundColor", "Theme", "BackgroundColorSelection");
                background.Children(1).Separator = "on";
            end
            customBackground = uimenu(background, Text="Custom color...", Separator="on", ...
                Tag="CustomBackgroundColor", MenuSelectedFcn=@(~, ~) obj.pickBackgroundColor());
            obj.CustomChoices(end + 1) = struct(Property="BackgroundColorSelection", Handle=customBackground);
            obj.Toggles.FullScreen = obj.action(view, "Full screen (F11)", "fullscreen", [], "FullScreenMenu");
            obj.Toggles.FullScreen.Separator = "on";
            screenshot = obj.action(view, "Save Screenshot...", "capture", "", "ScreenshotMenu");
            screenshot.Separator = "on";
            screenshot.Accelerator = "S";
            obj.ScreenshotMenu = screenshot;

            playback = uimenu(obj.View.Figure, Text="&Playback");
            obj.Toggles.Paused = obj.action(playback, "&Pause (P)", "pause", [], "PauseMenu");
            speed = uimenu(playback, Text="Speed");
            for rate = [0.1, 0.25, 0.5, 1, 2]
                obj.choice(speed, sprintf("%gx", rate), ...
                    "playback", rate, "PlaybackRate");
            end
            obj.customChoice(speed, "PlaybackRate", ...
                "Playback multiplier (0.10 to 2)", "playback", 1);
            obj.Toggles.SoundEnabled = obj.action(playback, "S&ound", "sound", [], "SoundMenu");
            obj.Toggles.SoundEnabled.Separator = "on";

            helpMenu = uimenu(obj.View.Figure, Text="&Help");
            obj.action(helpMenu, "Getting started", "help", "index", "GettingStartedMenu");
            obj.action(helpMenu, "Controls", "help", "controls", "ControlsHelpMenu");
            obj.action(helpMenu, "Examples", "help", "examples", "ExamplesHelpMenu");
            physics = obj.action(helpMenu, "Physics of ripples", "help", "physics", "PhysicsHelpMenu");
            physics.Separator = "on";
            obj.action(helpMenu, "Material properties", "help", "materials", "MaterialHelpMenu");
            obj.action(helpMenu, "Numerical methods", "help", "numerics", "NumericsHelpMenu");
            reference = obj.action(helpMenu, "Functions and properties", "help", "reference", "ReferenceHelpMenu");
            reference.Separator = "on";
            obj.action(helpMenu, "References", "help", "references", "ReferencesHelpMenu");
            obj.action(helpMenu, "About Ripple Simulator", "help", "about", "AboutMenu");
        end

        function item = action(obj, parent, label, action, value, tag)
            item = uimenu(parent, Text=label, Tag=tag, MenuSelectedFcn=@(~, ~) obj.Command(action, value));
        end

        function choice(obj, parent, label, action, value, property)
            item = uimenu(parent, Text=label, MenuSelectedFcn=@(~, ~) obj.Command(action, value));
            obj.Choices(end + 1) = struct(Property=property, Value=value, Handle=item);
        end

        function customChoice(obj, parent, property, prompt, action, multiplier)
            item = uimenu(parent, Text="Custom...", Separator="on", Tag="Custom" + property, ...
                MenuSelectedFcn=@(~, ~) obj.askNumber(prompt, action, obj.State.(property)/multiplier, multiplier));
            obj.CustomChoices(end + 1) = struct(Property=property, Handle=item);
        end

        function createToolbar(obj)
            toolbar = axtoolbar(obj.View.Axes, {});
            if isprop(toolbar, "Expanded")
                toolbar.Expanded = "on";
            end
            if isprop(obj.View.Axes, "ToolbarLocation")
                obj.View.Axes.ToolbarLocation = "container";
            end
            obj.Buttons.Home = obj.toolbarButton(toolbar, "push", "home", "Restore camera (Home)", "camera");
            obj.Buttons.Rotate = obj.toolbarButton(toolbar, "state", "rotate", "Rotate camera", "rotate");
            obj.Buttons.Ripple = obj.toolbarButton(toolbar, "state", "ripple", ...
                "Click the surface to create ripples", "ripple");
            obj.Buttons.Controls = obj.toolbarButton(toolbar, "state", "controls", ...
                "Parameter controls", "controls");
            obj.Buttons.FullScreen = obj.toolbarButton(toolbar, "state", "fullscreen", ...
                "Full screen (F11)", "fullscreen");
            obj.Buttons.Wireframe = obj.toolbarButton(toolbar, "state", "wireframe", "Wireframe (W)", "wireframe");
            obj.Buttons.Lighting = obj.toolbarButton(toolbar, "state", "lighting-on", ...
                "Lighting: on (L)", "lighting");
            obj.Buttons.Reflections = obj.toolbarButton(toolbar, "state", "reflections", ...
                "Reflecting boundaries (B)", "reflections");
            obj.Buttons.Clear = obj.toolbarButton(toolbar, "push", "clear", "Clear surface (C)", "clear");
            obj.Buttons.Pause = obj.toolbarButton(toolbar, "state", "pause", "Pause playback (P)", "pause");
            obj.Buttons.Sound = obj.toolbarButton(toolbar, "state", "sound-on", "Mute sound (M)", "sound");
            obj.Buttons.Rain = obj.toolbarButton(toolbar, "push", "rain", "Rain (R)", "rain");
            obj.Buttons.Autoclick = obj.toolbarButton(toolbar, "state", "autoclick", ...
                "Auto-click (Space)", "autoclick");
            obj.ButtonIcons = struct(Home="home", Rotate="rotate", Ripple="ripple", ...
                Controls="controls", FullScreen="fullscreen", Wireframe="wireframe", ...
                Lighting="lighting-on", Reflections="reflections", Clear="clear", ...
                Pause="pause", Sound="sound-on", Rain="rain", Autoclick="autoclick");
            leftToRight = [obj.Buttons.Pause; obj.Buttons.Rain; obj.Buttons.Autoclick; ...
                obj.Buttons.Clear; obj.Buttons.Reflections; ...
                obj.Buttons.Wireframe; obj.Buttons.Lighting; obj.Buttons.Sound; obj.Buttons.Controls; ...
                obj.Buttons.Ripple; obj.Buttons.Rotate; obj.Buttons.FullScreen; obj.Buttons.Home];
            if isprop(toolbar, "Expanded")
                toolbar.Children = flipud(leftToRight);
            else
                toolbar.Children = leftToRight;
            end
        end

        function button = toolbarButton(obj, toolbar, type, icon, tooltip, action)
            button = axtoolbarbtn(toolbar, type, Icon=app.internal.ui.appearance.toolbarIcon(icon, obj.ThemeName), ...
                Tooltip=tooltip, Tag="RippleToolbar" + icon);
            callback = @(~, ~) obj.toolbarAction(action);
            if type == "push"
                button.ButtonPushedFcn = callback;
            else
                button.ValueChangedFcn = callback;
            end
        end

        function toolbarAction(obj, action)
            switch action
                case "rotate"
                    if obj.State.NavigationMode == "Rotate"
                        mode = "Ripple";
                    else
                        mode = "Rotate";
                    end
                    obj.Command("navigation", mode);
                case "ripple"
                    obj.Command("navigation", "Ripple");
                otherwise
                    obj.Command(action, []);
            end
            if isvalid(obj) && isgraphics(obj.View.Figure) && obj.View.Figure.Visible == "on"
                focus(obj.View.Figure);
            end
        end

        function createSliders(obj)
            layout = uigridlayout(obj.View.ControlPanel, [2, 6], ...
                RowHeight={24, "1x"}, ColumnWidth={"1x", 105, "1x", 105, "1x", 105}, ...
                Padding=[20, 6, 20, 12], ColumnSpacing=20, RowSpacing=4, BackgroundColor="white");
            obj.ControlLayout = layout;
            obj.WavelengthLabel = uilabel(layout, Text="Characteristic wavelength", FontColor=[0.2, 0.2, 0.2]);
            obj.WavelengthLabel.Layout.Row = 1;
            obj.WavelengthLabel.Layout.Column = [1, 2];
            obj.PressureLabel = uilabel(layout, Text="Pressure strength", FontColor=[0.2, 0.2, 0.2]);
            obj.PressureLabel.Layout.Row = 1;
            obj.PressureLabel.Layout.Column = [3, 4];
            obj.PlaybackLabel = uilabel(layout, Text="Playback", FontColor=[0.2, 0.2, 0.2]);
            obj.PlaybackLabel.Layout.Row = 1;
            obj.PlaybackLabel.Layout.Column = [5, 6];
            obj.WavelengthSlider = uislider(layout, Limits=log10([0.005, 0.1]), Value=log10(0.017), ...
                MajorTicks=[], MinorTicks=[], Tag="WavelengthSlider", ...
                ValueChangingFcn=@(~, event) obj.previewSlider("wavelength", event.Value), ...
                ValueChangedFcn=@(~, event) obj.commitSlider("wavelength", event.Value));
            obj.WavelengthSlider.Layout.Row = 2;
            obj.WavelengthSlider.Layout.Column = 1;
            obj.WavelengthField = uieditfield(layout, "numeric", Limits=[5, 100], Value=17, ...
                ValueDisplayFormat="%.4g mm", Tag="WavelengthField", ...
                ValueChangedFcn=@(field, ~) obj.Command("wavelength", field.Value/1000));
            obj.WavelengthField.Layout.Row = 2;
            obj.WavelengthField.Layout.Column = 2;
            obj.PressureSlider = uislider(layout, Limits=[10, 200], Value=100, ...
                MajorTicks=[], MinorTicks=[], Tag="PressureSlider", ...
                ValueChangingFcn=@(~, event) obj.previewSlider("strength", event.Value), ...
                ValueChangedFcn=@(~, event) obj.commitSlider("strength", event.Value));
            obj.PressureSlider.Layout.Row = 2;
            obj.PressureSlider.Layout.Column = 3;
            obj.PressureField = uieditfield(layout, "numeric", Limits=[0, Inf], Value=100, ...
                ValueDisplayFormat="%.4g mPa·s", Tag="PressureField", ...
                ValueChangedFcn=@(field, ~) obj.Command("strength", field.Value/1000));
            obj.PressureField.Layout.Row = 2;
            obj.PressureField.Layout.Column = 4;
            obj.PlaybackSlider = uislider(layout, Limits=log10([0.1, 2]), Value=0, ...
                MajorTicks=[], MinorTicks=[], Tag="PlaybackSlider", ...
                ValueChangingFcn=@(~, event) obj.previewSlider("playback", event.Value), ...
                ValueChangedFcn=@(~, event) obj.commitSlider("playback", event.Value));
            obj.PlaybackSlider.Layout.Row = 2;
            obj.PlaybackSlider.Layout.Column = 5;
            obj.PlaybackField = uieditfield(layout, "numeric", Limits=[0.1, 2], Value=1, ...
                ValueDisplayFormat="%.4gx", Tag="PlaybackField", ...
                ValueChangedFcn=@(field, ~) obj.Command("playback", field.Value));
            obj.PlaybackField.Layout.Row = 2;
            obj.PlaybackField.Layout.Column = 6;
            obj.View.ControlPanel.SizeChangedFcn = @(~, ~) obj.resizeControls();
            obj.resizeControls();
        end

        function resizeControls(obj)
            narrow = obj.View.Figure.Position(3) < 900;
            if obj.LayoutInitialized && narrow == obj.NarrowLayout
                return
            end
            obj.NarrowLayout = narrow;
            obj.LayoutInitialized = true;
            if narrow
                obj.PressureLabel.Layout.Row = 3;
                obj.PressureLabel.Layout.Column = [1, 2];
                obj.PressureSlider.Layout.Row = 4;
                obj.PressureSlider.Layout.Column = 1;
                obj.PressureField.Layout.Row = 4;
                obj.PressureField.Layout.Column = 2;
                obj.PlaybackLabel.Layout.Row = 5;
                obj.PlaybackLabel.Layout.Column = [1, 2];
                obj.PlaybackSlider.Layout.Row = 6;
                obj.PlaybackSlider.Layout.Column = 1;
                obj.PlaybackField.Layout.Row = 6;
                obj.PlaybackField.Layout.Column = 2;
                obj.ControlLayout.RowHeight = {24, 32, 24, 32, 24, 32};
                obj.ControlLayout.ColumnWidth = {"1x", 105};
                obj.View.setControlHeight(206);
            else
                obj.ControlLayout.ColumnWidth = {"1x", 105, "1x", 105, "1x", 105};
                obj.PressureLabel.Layout.Row = 1;
                obj.PressureLabel.Layout.Column = [3, 4];
                obj.PressureSlider.Layout.Row = 2;
                obj.PressureSlider.Layout.Column = 3;
                obj.PressureField.Layout.Row = 2;
                obj.PressureField.Layout.Column = 4;
                obj.PlaybackLabel.Layout.Row = 1;
                obj.PlaybackLabel.Layout.Column = [5, 6];
                obj.PlaybackSlider.Layout.Row = 2;
                obj.PlaybackSlider.Layout.Column = 5;
                obj.PlaybackField.Layout.Row = 2;
                obj.PlaybackField.Layout.Column = 6;
                obj.ControlLayout.RowHeight = {24, "1x"};
                obj.View.setControlHeight(80);
            end
        end

        function previewSlider(obj, name, position)
            switch name
                case "wavelength"
                    if isnan(obj.WavelengthDraft)
                        obj.WavelengthDraft = obj.SyncRevision;
                    end
                    obj.WavelengthLabel.Text = sprintf("Characteristic wavelength: %.3g mm", 1000*10^position);
                case "strength"
                    if isnan(obj.PressureDraft)
                        obj.PressureDraft = obj.SyncRevision;
                    end
                    obj.PressureLabel.Text = sprintf("Pressure strength: %.4g mPa·s", position);
                case "playback"
                    if isnan(obj.PlaybackDraft)
                        obj.PlaybackDraft = obj.SyncRevision;
                    end
                    obj.PlaybackLabel.Text = sprintf("Playback: %.4gx", 10^position);
                otherwise
                    error("RippleSimulator:UnknownControl", "The parameter control is unsupported.");
            end
        end

        function commitSlider(obj, name, position)
            switch name
                case "wavelength"
                    revision = obj.WavelengthDraft;
                    obj.WavelengthDraft = NaN;
                    value = 10^position;
                case "strength"
                    revision = obj.PressureDraft;
                    obj.PressureDraft = NaN;
                    value = position/1000;
                case "playback"
                    revision = obj.PlaybackDraft;
                    obj.PlaybackDraft = NaN;
                    limits = obj.PlaybackField.Limits;
                    value = min(limits(2), max(limits(1), 10^position));
                otherwise
                    error("RippleSimulator:UnknownControl", "The parameter control is unsupported.");
            end
            if isnan(revision) || revision == obj.SyncRevision
                obj.Command(name, value);
            else
                obj.synchronize(obj.State);
            end
        end

        function askNumber(obj, prompt, action, initial, multiplier)
            answer = obj.requestInput(prompt, "Ripple Simulator", {sprintf("%.12g", initial)});
            if ~isvalid(obj) || isempty(answer)
                return
            end
            value = str2double(answer{1});
            if ~isfinite(value) || ~isreal(value)
                uialert(obj.View.Figure, "Enter one finite real number.", "Invalid value", Icon="error");
                return
            end
            obj.Command(action, value*multiplier);
        end

        function askColormap(obj)
            name = obj.State.Colormap;
            if isnumeric(name)
                name = mat2str(name, 12);
            end
            prompt = "Colormap name or RGB matrix (values from 0 to 1)" + newline ...
                + "Examples: winter or [0 0 1; 0 1 1; 1 1 1]";
            answer = obj.requestInput(prompt, "Colormap", {char(name)});
            if isvalid(obj) && ~isempty(answer)
                obj.Command("colormap", strtrim(string(answer{1})));
            end
        end

        function askFluid(obj)
            properties = obj.State.FluidProperties;
            names = ["Density", "DynamicViscosity", "SurfaceTension", "Temperature"];
            prompts = {"Density (kg/m³)", "Dynamic viscosity (Pa s)", ...
                "Surface tension (N/m)", "Temperature (°C)"};
            initial = cell(1, numel(names));
            for index = 1:numel(names)
                initial{index} = char(string(properties.(names(index))));
            end
            answer = obj.requestInput(prompts, "Custom Newtonian fluid", initial);
            if isempty(answer)
                return
            end
            for index = 1:numel(names)
                properties.(names(index)) = str2double(answer{index});
            end
            obj.Command("fluidProperties", properties);
        end

        function pickSurfaceColor(obj)
            color = uisetcolor(obj.State.SurfaceColor, "Surface color");
            if ~isvalid(obj)
                return
            end
            obj.restoreFocus();
            if isequal(size(color), [1, 3])
                obj.Command("surfaceColor", color);
            end
        end

        function pickBackgroundColor(obj)
            color = uisetcolor(obj.View.Axes.Color, "Background Color");
            if ~isvalid(obj)
                return
            end
            obj.restoreFocus();
            if isequal(size(color), [1, 3])
                obj.Command("backgroundColor", color);
            end
        end

        function answer = requestInput(obj, prompt, title, initial)
            answer = inputdlg(prompt, title, [1, 64], initial);
            if ~isvalid(obj)
                answer = {};
                return
            end
            obj.restoreFocus();
        end

        function restoreFocus(obj)
            window = obj.View.Figure;
            if isgraphics(window) && window.Visible == "on" && window.BeingDeleted == "off"
                figure(window);
            end
        end

    end

    methods (Static, Access = private)
        function message = explainCommand(action, state)
        % EXPLAINCOMMAND Describe the physical or visual effect of an accepted action.
            arguments
                action (1, 1) string
                state (1, 1) struct
            end
            message = "";
            switch action
                case "click"
                    message = "A localized impact excites many wavelengths. " ...
                        + "Dispersion separates them as the ripple spreads.";
                case "rain"
                    message = "Rain creates multiple ripples. " ...
                        + "Their elevations are superimposed to form the wave field.";
                case "autoclick"
                    message = "Successive disturbances overlap. Their crests and troughs reinforce or cancel " ...
                        + "to form an interference pattern.";
                case {"clear", "rest"}
                    message = "At rest, the surface lies at the still water level, with no wave motion in the fluid.";
                case "pause"
                    message = "Observe the wave field. " ...
                        + "Constructive interference amplifies the surface displacement. " ...
                        + "Destructive interference attenuates it.";
                case {"reset", "setup"}
                    message = sprintf("This experiment spans %.3g mm, or %.2g characteristic wavelengths. " ...
                        + "Gravity and surface tension both contribute to the restoring force.", ...
                        1000*state.DomainSize, state.DomainSize/state.Wavelength);
                case "resolution"
                    message = sprintf("The grid has %.1f intervals per characteristic wavelength. " ...
                        + "Smaller waves require finer sampling to resolve their crests and troughs.", ...
                        (state.GridResolution - 1)*state.Wavelength/state.DomainSize);
                case "wavelength"
                    wavenumber = 2*pi/state.Wavelength;
                    ratio = state.FluidProperties.SurfaceTension*wavenumber^2/(state.FluidProperties.Density*9.81);
                    message = sprintf("Characteristic wavelength: %.3g mm. Surface tension supplies %.1f%% " ...
                        + "of the restoring term at this wavelength.", ...
                        1000*state.Wavelength, 100*ratio/(1 + ratio));
                case {"strength", "rainStrength", "autoclickStrength"}
                    message = "The surface displacement is directly proportional to the pressure strength " ...
                        + "when the other source and fluid settings are unchanged.";
                case "sourceMode"
                    if state.SourceMode == "Impulse"
                        message = "A pressure impulse changes the fluid velocity without an instantaneous " ...
                            + "change in surface elevation.";
                    else
                        message = "The wavemaker applies oscillating pressure for four cycles, " ...
                            + "producing a longer wave train.";
                    end
                case "playback"
                    message = "Playback speed changes how quickly you watch the waves. " ...
                        + "The fluid properties remain unchanged.";
                case "fps"
                    message = "FPS measures display smoothness over ten frame intervals. " ...
                        + "Elapsed time determines wave motion.";
                case "wireframe"
                    message = "Wireframe shows the observation grid. " ...
                        + "Its vertices sample the same continuous wave field.";
                case "surfaceMode"
                    if ismember(state.SurfaceMode, ["Elevation", "Contrast"])
                        message = "Color shows surface elevation on a fixed display scale. " ...
                            + "The wave field is unchanged.";
                    else
                        message = "Surface lighting reveals slopes, crests, and interference between ripples.";
                    end
                case "fullscreen"
                    message = "Surface slopes redirect reflected light, revealing the geometry of the waves.";
                case {"colormap", "colormapReverse"}
                    message = "The colormap represents surface elevation. " ...
                        + "Changing its colors leaves the wave field unchanged.";
                case "lighting"
                    message = "Reflected light reveals surface slopes. Lighting changes leave wave heights unchanged.";
                case "reflections"
                    if state.ReflectionsEnabled && state.ReflectionCoefficient > 0
                        message = "Waves reflect at the boundaries and continue to dissipate energy through viscosity.";
                    else
                        message = "Waves propagate across the fluid's unbounded surface " ...
                            + "and can travel beyond the visible area.";
                    end
                case "reflectionCoefficient"
                    message = sprintf("Each reflected wave component retains %.3g%% of its incident amplitude " ...
                        + "and %.3g%% " ...
                        + "of its incident energy. Viscous dissipation continues throughout propagation.", ...
                        100*state.ReflectionCoefficient, 100*state.ReflectionCoefficient^2);
                case {"controls", "readout"}
                    message = "Physical dimensions and wavelength determine the experiment's scale. " ...
                        + "The camera and height scale determine its presentation.";
                case {"heightScale", "automaticHeight"}
                    message = sprintf("Surface elevations are displayed %.8g times larger " ...
                        + "than their physical values. " ...
                        + "The measurements below remain unscaled.", state.HeightScale);
                case {"navigation", "camera", "cameraView"}
                    message = "Camera rotation and zoom change the view, " ...
                        + "while the physical domain and wave field remain unchanged.";
                case "domain"
                    message = sprintf("The domain spans %.3g mm, or %.2g characteristic wavelengths. " ...
                        + "The wavelength sets the balance between gravity and surface tension.", ...
                        1000*state.DomainSize, state.DomainSize/state.Wavelength);
                case "material"
                    if state.Material == "Honey"
                        message = "Honey is modeled as a Newtonian fluid. " ...
                            + "Viscosity damps the short waves more strongly than the long waves.";
                    elseif state.Material == "Chocolate"
                        message = "This molten compound chocolate is modeled as a Newtonian fluid. " ...
                            + "Its greater viscosity suppresses short waves more strongly than water.";
                    else
                        message = "Density, viscosity, and surface tension change together " ...
                            + "with the selected fluid. " ...
                            + "Equal pressure inputs can produce different wave heights.";
                    end
                case "fluidProperties"
                    message = "Density links pressure to acceleration, surface tension resists curvature, " ...
                        + "and viscosity diffuses momentum.";
                case {"appearance", "surfaceColor"}
                    message = "Color is a display choice; it does not determine a fluid's density, " ...
                        + "viscosity, or surface tension.";
                case "opacity"
                    message = "Transparency reveals overlapping parts of the surface. " ...
                        + "The wave heights and fluid properties remain unchanged.";
                case "temperature"
                    message = "Water density, viscosity, and surface tension are recalculated " ...
                        + "together at the selected temperature.";
                case "seed"
                    message = "The random seed controls drop positions in subsequent rain bursts, " ...
                        + "making rain experiments reproducible.";
                otherwise
                    % Help and closure have no additional physical interpretation.
            end
        end
    end
end

function names = availableColormaps()
% AVAILABLECOLORMAPS List colormaps supported by the installed MATLAB release.
    if exist("colormaplist", "file") == 2 || exist("colormaplist", "builtin") == 5
        names = unique(["winter", reshape(colormaplist(), 1, [])], "stable");
    else
        names = ["winter", "parula", "turbo", "jet", "hsv", "hot", "cool", "spring", ...
            "summer", "autumn", "gray", "bone", "copper", "pink", "sky", "abyss", ...
            "lines", "colorcube", "prism", "flag"];
    end
end

function assignMnemonics(menus)
% ASSIGNMNEMONICS Assign access keys without adding characters to menu labels.
    [~, order] = sort([menus.Position]);
    menus = menus(order);
    alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    owners = zeros(size(alphabet));
    fixed = false(size(menus));
    candidates = cell(size(menus));
    for index = 1:numel(menus)
        token = regexp(char(menus(index).Text), '(?<!&)&([a-zA-Z0-9])', 'tokens', 'once');
        if ~isempty(token)
            owners(alphabet == lower(token{1})) = -1;
            fixed(index) = true;
        end
    end
    for index = find(~fixed(:))'
        label = lower(char(menus(index).Text));
        [present, positions] = ismember(label, alphabet);
        candidates{index} = unique(positions(present), "stable");
    end
    for index = find(~fixed(:))'
        [owners, ~] = matchMnemonic(index, candidates, owners, false(size(alphabet)));
    end
    for index = 1:numel(menus)
        menu = menus(index);
        if ~fixed(index)
            label = char(menu.Text);
            key = alphabet(owners == index);
            if isempty(key)
                key = alphabet(candidates{index}(1));
            end
            position = find(lower(label) == key, 1);
            menu.Text = [label(1:position-1), '&', label(position:end)];
        end
        if ~isempty(menu.Children)
            assignMnemonics(menu.Children);
        end
    end
end

function [owners, assigned] = matchMnemonic(index, candidates, owners, visited)
% MATCHMNEMONIC Reassign conflicting keys without changing menu text.
    assigned = false;
    for key = candidates{index}
        if visited(key) || owners(key) < 0
            continue
        end
        visited(key) = true;
        available = owners(key) == 0;
        if ~available
            [owners, available] = matchMnemonic(owners(key), candidates, owners, visited);
        end
        if available
            owners(key) = index;
            assigned = true;
            return
        end
    end
end
