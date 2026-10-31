classdef (Sealed) RippleSimulatorApp < handle
    % RIPPLESIMULATORAPP Create a Ripple Simulator application object.
    %   SIMULATOR = app.RippleSimulatorApp() constructs the application object and
    %   creates its interface. Click the surface or call SIMULATOR.addRipple([X Y])
    %   with physical coordinates in meters.
    %   Source settings affect subsequent clicks; changing GridResolution
    %   resamples existing waves without changing their physical state.
    %
    %   SIMULATOR = app.RippleSimulatorApp(Setup="Capillary") selects the
    %   smaller physical setup.
    %   Setup can be "Gravity", "Balanced", or "Capillary". Visible="off"
    %   creates a hidden figure. Paused=true starts with playback paused.
    %   AutomaticUpdates=false disables automatic updates;
    %   call update to sample elapsed time explicitly. TimeSource optionally
    %   supplies a scalar monotonic time function for reproducible timing.
    %
    %   The model assumes small disturbances, infinite depth, and a clean free
    %   surface. Open water is the default. ReflectionsEnabled=true selects
    %   domain boundaries with a default reflection coefficient of 1.
    %   Perfect reflection uses free-slip walls and a 90-degree contact angle.
    %   Changing the boundary setting clears existing waves and pending rain.
    %   HeightScale changes only the display. See the included manual
    %   for the source definition, viscosity model, and numerical rest policy.
    %
    %   RippleSimulatorApp Methods:
    %       addRipple     - Add one source at physical coordinates
    %       rain          - Schedule twenty localized sources
    %       clear         - Clear waves and pending rain
    %       reset         - Restore the default experiment
    %       applySetup    - Select a scaled water experiment
    %       update        - Process elapsed time and render
    %       snapshot      - Retrieve the wave field data at the current simulation time
    %       describe      - Read settings, provenance, and diagnostics
    %       restoreCamera - Restore the original close view
    %       setCameraView - Select Close, Top, or Wide
    %       capture       - Export the application to PNG
    %       close         - Close the application
    %       delete        - Release owned resources
    %
    %   RippleSimulatorApp Properties:
    %       Wavelength           - Source scale for new inputs, in meters
    %       PressureImpulse      - Pressure strength for new inputs, in Pa s
    %       SourceMode           - Impulse or Wavemaker excitation
    %       DomainSize           - Physical domain width in meters
    %       Material             - Water, olive oil, silicone oil, honey, chocolate, or custom fluid
    %       FluidProperties      - Complete custom fluid property record
    %       Temperature          - Fluid temperature in degrees Celsius
    %       GridResolution       - Observation nodes per side
    %       PlaybackRate         - Simulation seconds per real second
    %       Paused               - Suspend waves and scheduled input
    %       RandomSeed           - Private rain-generator seed
    %       RainStrengthScale    - Rain pressure multiplier; default 1
    %       AutoclickStrengthScale - Auto-click pressure multiplier; default 0.2
    %       ReflectionsEnabled   - Enable wave reflection at boundaries
    %       ReflectionCoefficient - Reflected amplitude fraction
    %       Wireframe            - Display black mesh edges with optional lit faces
    %       SurfaceMode          - Solid, colormap, or high-contrast presentation
    %       Colormap             - Named or custom elevation colormap
    %       ColormapReversed     - Reverse the elevation colormap
    %       FullScreen           - Show only the surface in full screen
    %       Appearance           - Named surface color preset
    %       SurfaceColor         - Custom surface color
    %       BackgroundColor      - Viewing-area background color
    %       SurfaceOpacity       - Filled-surface opacity, from 0.1 to 1
    %       SoundEnabled         - Enable splash and rain audio
    %       AutoclickEnabled     - Trace ripples with the pointer
    %       LightingEnabled      - Enable surface lighting
    %       ControlsVisible      - Show wavelength, pressure strength, and playback controls
    %       ReadoutVisible       - Show explanatory text and measurements
    %       ShowFPS              - Show rolling playback frame rate
    %       HeightScale          - Vertical display multiplier
    %       AutomaticHeightScale - Adjust display scale for the selected fluid
    %       NavigationMode       - Ripple, Rotate, Pan, or Zoom
    %       Figure               - Owned application figure (read-only)
    %       PhysicalTime         - Processed simulation time (read-only)
    %       IsAtRest             - Exact equilibrium state (read-only)
    %       MeasuredFPS          - Rolling playback frame rate (read-only)
    %       Status               - Application lifecycle (read-only)
    %       LastError            - Latest processing fault (read-only)
    %
    %   Each source retains the complete viscous response through eight settling
    %   time scales, then a smooth envelope sets it to zero by the tenth scale.
    %   The scale includes both the reference period and viscous relaxation.
    %   This finite-duration approximation is separate from material viscosity.
    %
    %   See also rippleSimulator.

    properties (Dependent)
        % GridResolution Number of observation nodes per side, from 51 to 801.
        GridResolution
        % Wavelength Characteristic wavelength of new sources, in meters.
        Wavelength
        % PressureImpulse Pressure strength for new sources, in pascal seconds.
        PressureImpulse
        % SourceMode Excitation method for new sources: "Impulse" or "Wavemaker".
        SourceMode
        % PlaybackRate Simulation seconds per real second during playback.
        PlaybackRate
        % Paused Whether the simulation and scheduled rain are paused.
        Paused
        % Wireframe Display black mesh edges; lighting controls face visibility.
        Wireframe
        % SurfaceMode Shaded, Elevation, or Contrast.
        SurfaceMode
        % Colormap Elevation colors as a function name or an N-by-3 RGB array.
        Colormap
        % ColormapReversed Whether the elevation colormap is reversed.
        ColormapReversed
        % FullScreen Hide menus, toolbar, and bottom panels to show only the surface.
        FullScreen
        % LightingEnabled Whether surface lighting is enabled.
        LightingEnabled
        % ReflectionsEnabled Whether domain boundaries reflect waves; changes clear waves.
        ReflectionsEnabled
        % ReflectionCoefficient Reflected amplitude fraction, from 0 to 1; default 1.
        %   Each reflected wave component retains this fraction of incident
        %   amplitude and its square as the fraction of incident energy.
        ReflectionCoefficient
        % ControlsVisible Whether wavelength, pressure strength, and playback controls are visible.
        ControlsVisible
        % ReadoutVisible Whether explanatory text and measurements are visible.
        ReadoutVisible
        % ShowFPS Whether the bottom panel includes frame rate.
        ShowFPS
        % HeightScale Vertical display multiplier, from 1 to 1000000.
        %   Assigning a value disables automatic height scaling.
        HeightScale
        % AutomaticHeightScale Match reference-impulse visibility across fluids.
        %   Selecting a named material applies its fixed height-scale preset.
        AutomaticHeightScale
        % NavigationMode Pointer behavior: "Ripple", "Rotate", "Pan", or "Zoom".
        NavigationMode
        % DomainSize Physical domain width, from 0.005 to 2.4 m; changes clear waves.
        DomainSize
        % Material Fluid identifier; changes start a new physical experiment.
        %   Selecting a named material restores its fluid properties, source
        %   wavelength, pressure strength, height scale, and appearance.
        Material
        % FluidProperties Density, DynamicViscosity, SurfaceTension, and Temperature; SI units.
        %   Assigning a complete structure selects a custom Newtonian fluid.
        FluidProperties
        % Appearance Named display color preset, independent of physical material.
        Appearance
        % SurfaceColor MATLAB color name, short name, hex code, or RGB triplet.
        %   The property returns a normalized RGB triplet.
        SurfaceColor
        % BackgroundColor MATLAB color specification or "Theme".
        %   Returns the displayed RGB triplet. Fixed colors persist across theme
        %   changes. The default follows the figure theme, with a white
        %   fallback on releases without theme support.
        BackgroundColor
        % SurfaceOpacity Filled-surface opacity, from 0.1 to 1 (opaque).
        %   Does not apply to Wireframe or views without lighting.
        SurfaceOpacity
        % Temperature Fluid temperature in degrees Celsius; editable for water.
        Temperature
        % SoundEnabled Play splash and rain recordings for accepted input.
        SoundEnabled
        % AutoclickEnabled Create ripples as the pointer moves.
        AutoclickEnabled
        % AutoclickStrengthScale Nonnegative pressure multiplier for new Auto-click inputs.
        %   A value of 1 matches manual input; the default is 0.2.
        AutoclickStrengthScale
        % RandomSeed Private rain-generator seed; changes affect subsequent bursts.
        RandomSeed
        % RainStrengthScale Nonnegative pressure multiplier for subsequent rain bursts.
        %   A value of 1 matches manual input. Scheduled drops retain their multiplier.
        RainStrengthScale
    end

    properties (Dependent, SetAccess = private)
        % Figure Owned MATLAB application figure.
        Figure
        % PhysicalTime Last processed physical time, in seconds.
        PhysicalTime
        % IsAtRest Whether the represented field is exactly at equilibrium.
        IsAtRest
        % MeasuredFPS Playback frames per real second over the last ten intervals.
        MeasuredFPS
    end

    properties (SetAccess = private)
        % Status Application lifecycle state.
        Status (1, 1) string = "Constructing"
        % LastError Message from the most recent unrecovered processing failure.
        LastError (1, 1) string = ""
    end

    properties (Access = private)
        Simulation app.internal.simulation.WaveExperiment = app.internal.simulation.Simulation.empty
        Clock app.internal.playback.Clock
        FrameRate app.internal.playback.FrameRate
        Scheduler app.internal.input.SourceScheduler
        View app.internal.ui.rendering.SurfaceView
        Controls app.internal.ui.Controls
        Audio app.internal.audio.SplashAudio
        Autoclick app.internal.input.AutoclickGate
        Pump timer
        FigureDestructionListener event.listener
        ThemeListener event.listener
        AutomaticUpdates (1, 1) logical = true
        TimeSource = []
        Busy (1, 1) logical = false
        ResumePumpAfterOperation (1, 1) logical = false
        ResumePumpAfterPause (1, 1) logical = false
        TickInProgress (1, 1) logical = false
        InputPresentationClock app.internal.playback.Clock
        InputPresentationRevision (1, 1) uint64 = 0
        Notifying (1, 1) logical = false
        LastRenderAtRest (1, 1) logical = true
        LastReadoutTime (1, 1) double = -Inf
        LastPendingRain (1, 1) double = -1
        Measurements (1, 1) struct = struct(Crest=0, Trough=0, WaveHeight=0)
        Display (1, 1) struct = struct()
        Boundary (1, 1) struct = struct(Enabled=false, Coefficient=1)
        RainScale (1, 1) double = 1
    end

    events
        % SettingsChanged Notification after accepted settings and views agree.
        SettingsChanged
        % PlaybackChanged Notification after accepted pause or rate changes.
        PlaybackChanged
    end

    methods
        function obj = RippleSimulatorApp(options)
        % RIPPLESIMULATORAPP Create a Ripple Simulator application object.
            arguments
                options.Setup {mustBeTextScalar, ...
                    mustBeMember(options.Setup, ["Gravity", "Balanced", "Capillary"])} = "Gravity"
                options.GridResolution (1, 1) {mustBeNumeric, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.GridResolution, 51), ...
                    mustBeLessThanOrEqual(options.GridResolution, 801)} = 201
                options.Visible {mustBeTextScalar, mustBeMember(options.Visible, ["on", "off"])} = "on"
                options.AutomaticUpdates (1, 1) {mustBeNumericOrLogical, ...
                    mustBeMember(options.AutomaticUpdates, [0, 1])} = true
                options.Paused (1, 1) {mustBeNumericOrLogical, ...
                    mustBeMember(options.Paused, [0, 1])} = false
                options.TimeSource = []
                options.ReflectionsEnabled (1, 1) {mustBeNumericOrLogical, ...
                    mustBeMember(options.ReflectionsEnabled, [0, 1])} = false
                options.ReflectionCoefficient (1, 1) double {mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(options.ReflectionCoefficient, 0), ...
                    mustBeLessThanOrEqual(options.ReflectionCoefficient, 1)} = 1
            end
            try
                obj.FrameRate = app.internal.playback.FrameRate();
                obj.Autoclick = app.internal.input.AutoclickGate();
                setup = app.internal.simulation.defaultSetup(options.Setup);
                obj.AutomaticUpdates = logical(options.AutomaticUpdates);
                obj.ResumePumpAfterPause = obj.AutomaticUpdates && logical(options.Paused);
                obj.TimeSource = options.TimeSource;
                obj.Simulation = createSimulation(setup.Fluid, setup.DomainSize, ...
                    options.GridResolution, setup.Source, logical(options.ReflectionsEnabled), ...
                    options.ReflectionCoefficient);
                obj.Boundary = struct(Enabled=logical(options.ReflectionsEnabled), ...
                    Coefficient=options.ReflectionCoefficient);
                obj.Scheduler = app.internal.input.SourceScheduler();
                obj.Display = displaySettings(setup.HeightScale);
                obj.Audio = app.internal.audio.SplashAudio();
                obj.Display.SoundEnabled = obj.Audio.Available;
                obj.View = app.internal.ui.rendering.SurfaceView(@(action, value) obj.dispatch(action, value));
                obj.Controls = app.internal.ui.Controls(obj.View, @(action, value) obj.dispatch(action, value));
                obj.View.showControls(obj.Display.ControlsVisible);
                obj.Clock = obj.createClock(setup.PlaybackRate);
                obj.Clock.hold();
                obj.View.Figure.CloseRequestFcn = @(~, ~) obj.close();
                obj.View.Figure.DeleteFcn = @(~, ~) obj.close();
                obj.View.Figure.WindowKeyPressFcn = @(~, event) obj.keyPressed(event);
                obj.render();
                obj.Status = "Running";
                if options.Paused
                    obj.Clock.pause();
                    obj.Status = "Paused";
                end
                obj.ThemeListener = addlistener(obj.View, "ThemeChanged", ...
                    @(~, ~) obj.emit("SettingsChanged"));
                obj.synchronize();
                obj.Pump = timer(ExecutionMode="fixedSpacing", Period=0.001, StartDelay=0.01, ...
                    TimerFcn=@(~, ~) obj.tick(), Name="Ripple Simulator", Tag="RippleSimulatorPump");
                ownedTimer = obj.Pump;
                obj.FigureDestructionListener = addlistener(obj.View.Figure, "ObjectBeingDestroyed", ...
                    @(~, ~) releaseTimer(ownedTimer));
                obj.View.Figure.Visible = string(options.Visible);
                obj.Clock.restart();
                obj.Clock.release();
                if obj.AutomaticUpdates && ~obj.Paused
                    start(obj.Pump);
                end
            catch exception
                delete(obj);
                rethrow(exception);
            end
            if nargout == 0
                clear obj
            end
        end

        function delete(obj)
        % DELETE Release the application's owned timer, controls, and figure.
        %   DELETE(SIMULATOR) invalidates the app and releases its resources.
        %   Other figures and timers remain open.
        %
        %   See also app.RippleSimulatorApp.close.
            obj.Status = "Closing";
            releaseTimer(obj.Pump);
            obj.releaseInputPresentation();
            if ~isempty(obj.ThemeListener) && isvalid(obj.ThemeListener)
                delete(obj.ThemeListener);
            end
            if ~isempty(obj.Audio) && isvalid(obj.Audio)
                delete(obj.Audio);
            end
            if ~isempty(obj.Controls) && isvalid(obj.Controls)
                delete(obj.Controls);
            end
            if ~isempty(obj.View) && isvalid(obj.View)
                if isgraphics(obj.View.Figure)
                    obj.View.Figure.CloseRequestFcn = [];
                    obj.View.Figure.DeleteFcn = [];
                end
                delete(obj.View);
            end
            if ~isempty(obj.FigureDestructionListener) && isvalid(obj.FigureDestructionListener)
                delete(obj.FigureDestructionListener);
            end
            obj.Status = "Closed";
        end

        function close(obj)
        % CLOSE Release the app's timer, controls, and owned figure.
        %   CLOSE(SIMULATOR) closes the application and invalidates its handle.
        %   Other figures and timers are unaffected. Closing the application
        %   figure performs the same cleanup.
        %
        %   See also app.RippleSimulatorApp, delete.
            if isvalid(obj) && obj.Status ~= "Closing" && obj.Status ~= "Closed"
                delete(obj);
            end
        end

        function identifier = addRipple(obj, position)
        % addRipple Apply the current source at a physical position.
        %   IDENTIFIER = addRipple(SIMULATOR,POSITION) adds one source at POSITION,
        %   a finite two-element row vector [X Y] in meters. Coordinates must
        %   lie within plus or minus SIMULATOR.DomainSize/2. IDENTIFIER is the
        %   accepted input number in the current experiment.
        %
        %   The source retains the wavelength, pressure strength, mode, and
        %   physical time accepted for this input. Changing source settings
        %   does not change an existing ripple. An impulse starts
        %   at zero elevation with nonzero vertical velocity.
        %
        %   Example: Add simultaneous sources
        %       simulator = app.RippleSimulatorApp();
        %       simulator.Paused = true;
        %       simulator.addRipple([-0.1, 0]);
        %       simulator.addRipple([0.1, 0]);
        %       simulator.Paused = false;
        %
        %   See also app.RippleSimulatorApp, app.RippleSimulatorApp.rain, app.RippleSimulatorApp.snapshot.
            arguments
                obj (1, 1) app.RippleSimulatorApp
                position (1, 2) {mustBeNumeric, mustBeReal, mustBeFinite}
            end
            identifier = obj.acceptRipple(double(position), true);
        end

        function rain(obj)
        % RAIN Schedule twenty reproducible clicks using the current source.
        %   RAIN(SIMULATOR) draws twenty positions uniformly within the observation
        %   domain and places each source at the nearest grid node. The first
        %   is issued immediately; later sources are spaced by 0.05 seconds
        %   of elapsed real time while playback runs. Pausing suspends the
        %   schedule; requests made while paused are ignored. Each input uses
        %   the manual-click source, multiplied by SIMULATOR.RainStrengthScale
        %   (default 1). A burst retains its multiplier; other source settings follow their values
        %   when each scheduled input occurs.
        %
        %   SIMULATOR.RandomSeed controls a private random number stream.
        %   MATLAB's global random number stream is unchanged. A complete burst
        %   must fit the loading and capacity limits. Repeated bursts retain
        %   all previously scheduled drops.
        %   Each burst plays one rain recording when sound is enabled.
        %
        %   See also app.RippleSimulatorApp.addRipple, app.RippleSimulatorApp.clear.
            arguments
                obj (1, 1) app.RippleSimulatorApp
            end
            obj.requireReady();
            drawnow;
            if ~isvalid(obj) || obj.Paused
                return
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            plan = obj.Scheduler.prepareBurst(obj.Clock.ActiveTime, obj.DomainSize, ...
                StrengthScale=obj.RainStrengthScale);
            plan.Positions = obj.gridPosition(plan.Positions);
            physicalTimes = obj.Clock.PhysicalTime+obj.PlaybackRate*(plan.ActiveTimes-obj.Clock.ActiveTime);
            obj.Simulation.reserveInputs(20, Positions=plan.Positions, ...
                StrengthScale=obj.RainStrengthScale, Times=physicalTimes);
            try
                obj.Scheduler.commitBurst(plan);
            catch exception
                obj.Simulation.cancelReservation(20);
                rethrow(exception);
            end
            obj.View.Rain.start(plan.Positions, plan.ActiveTimes, obj.DomainSize);
            obj.processTime(obj.Clock.sample());
            if obj.SoundEnabled && ~obj.Paused
                obj.Audio.playAutomatic("Rain");
            end
            obj.prepareInputPresentation();
            obj.render();
            obj.updateReadout(true);
            obj.Controls.explain("rain", obj.controlState());
        end

        function clear(obj)
        % CLEAR Cancel pending rain and return to equilibrium at the current time.
        %   CLEAR(SIMULATOR) removes active sources and pending rain.
        %   It preserves physical time, source settings,
        %   the random generator's progression, camera, and pause state.
        %
        %   See also app.RippleSimulatorApp.reset, app.RippleSimulatorApp.rain.
            arguments
                obj (1, 1) app.RippleSimulatorApp
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.Scheduler.cancel();
            obj.Simulation.clear();
            obj.View.Rain.clear();
            obj.Autoclick.reset();
            obj.render();
            obj.synchronize();
            obj.Controls.explain("rest", obj.controlState());
        end

        function reset(obj)
        % RESET Restore the default experiment, appearance, camera, and rain seed.
        %   RESET(SIMULATOR) starts the default gravity-scale experiment in water
        %   at 20 degrees Celsius, with open boundaries and 201 grid nodes
        %   per side. It restores the pressure impulse, playback rate,
        %   display settings, camera, and initial private random seed.
        %   Playback resumes from zero simulation time.
        %
        %   Reset can recover a faulted app after its underlying cause has
        %   been resolved. Preparation finishes before settings are accepted.
        %
        %   See also app.RippleSimulatorApp.clear, app.RippleSimulatorApp.applySetup.
            arguments
                obj (1, 1) app.RippleSimulatorApp
            end
            assert(ismember(obj.Status, ["Running", "Paused", "Faulted"]) && ~obj.Busy, ...
                "RippleSimulator:ApplicationState", "Reset requires an idle, open application.");
            obj.Busy = true;
            obj.releaseInputPresentation();
            previousClock = obj.Clock;
            held = obj.Status ~= "Faulted";
            if held
                try
                    previousClock.hold();
                catch exception
                    obj.Busy = false;
                    rethrow(exception);
                end
            end
            guard = onCleanup(@() obj.endReset(previousClock, held));
            preparation = obj.showPreparation();
            setup = app.internal.simulation.defaultSetup();
            candidate = createSimulation(setup.Fluid, setup.DomainSize, 201, setup.Source, false);
            clock = obj.createClock(setup.PlaybackRate);
            clock.hold();
            scheduler = app.internal.input.SourceScheduler();
            display = displaySettings(setup.HeightScale);
            display.SoundEnabled = obj.Audio.Available;
            obj.installFrame(candidate.snapshot(), setup.HeightScale, ...
                obj.Simulation.snapshot(), obj.HeightScale);
            obj.View.setWireframe(display.Wireframe);
            obj.View.setSurfaceMode(display.SurfaceMode);
            obj.View.setColormap(winter(256));
            obj.View.Figure.WindowState = "maximized";
            obj.View.setLighting(display.LightingEnabled);
            obj.View.setStyle(app.internal.ui.appearance.SurfaceStyle(), display.Wireframe);
            obj.View.setOpacity(display.SurfaceOpacity);
            obj.View.setBackgroundColor("Theme");
            obj.View.showControls(display.ControlsVisible);
            obj.View.showReadout(display.ReadoutVisible);
            obj.View.setNavigation(display.NavigationMode);
            obj.View.setAutoclick(false);
            obj.Autoclick.reset();
            obj.Autoclick.StrengthScale = 0.2;
            obj.View.restoreCamera();
            obj.View.Rain.clear();
            obj.Simulation = candidate;
            obj.Clock = clock;
            obj.Scheduler = scheduler;
            obj.RainScale = 1;
            obj.Display = display;
            obj.Boundary = struct(Enabled=false, Coefficient=1);
            obj.LastRenderAtRest = true;
            obj.LastError = "";
            obj.ResumePumpAfterPause = false;
            obj.Status = "Running";
            obj.FrameRate.resetMeasurement();
            obj.Clock.restart();
            obj.synchronize();
            delete(preparation);
            obj.Clock.release();
            if obj.AutomaticUpdates && obj.Pump.Running == "off"
                start(obj.Pump);
            end
            obj.emit("SettingsChanged");
            if isvalid(obj)
                obj.emit("PlaybackChanged");
            end
        end

        function applySetup(obj, name)
        % applySetup Start a scaled water experiment and clear existing waves.
        %   applySetup(SIMULATOR,NAME) selects "Gravity", "Balanced", or "Capillary".
        %   Each setup uses water at 20 degrees Celsius. The gravity preset
        %   uses a 50 mm source scale in a 650-by-650 mm domain; the other presets
        %   span 6.5 characteristic wavelengths. Capillary playback starts at
        %   0.10x; the other presets start at 0.25x.
        %   Pressure strength and height scale return to their preset
        %   values.
        %
        %   The current grid must resolve the new source. The selected
        %   boundary type, camera, and pause state are preserved.
        %
        %   See also app.RippleSimulatorApp.reset, app.RippleSimulatorApp.Wavelength.
            arguments
                obj (1, 1) app.RippleSimulatorApp
                name {mustBeTextScalar, mustBeMember(name, ["Gravity", "Balanced", "Capillary"])}
            end
            setup = app.internal.simulation.defaultSetup(name);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            preparation = obj.showPreparation();
            candidate = createSimulation(setup.Fluid, setup.DomainSize, ...
                obj.GridResolution, setup.Source, obj.ReflectionsEnabled, obj.ReflectionCoefficient);
            obj.replaceSimulation(candidate, setup.HeightScale);
            obj.Display.AutomaticHeightScale = true;
            obj.Clock.setRate(setup.PlaybackRate);
            obj.synchronize();
            delete(preparation);
            obj.emit("SettingsChanged");
        end

        function restoreCamera(obj)
        % restoreCamera Return to the original close oblique camera.
        %   restoreCamera(SIMULATOR) restores the close view without changing the
        %   waves, physical dimensions, or height scale.
        %
        %   See also app.RippleSimulatorApp.setCameraView.
            arguments
                obj (1, 1) app.RippleSimulatorApp
            end
            obj.setCameraView("Close");
        end

        function setCameraView(obj, name)
        % setCameraView Select a predefined camera view.
        %   setCameraView(SIMULATOR,NAME) selects "Close", "Top", or "Wide" without
        %   changing the physical field. Close fills the viewport with the
        %   original oblique view. Top and Wide expose the physical boundary.
        %
        %   See also app.RippleSimulatorApp.restoreCamera, app.RippleSimulatorApp.capture.
            arguments
                obj (1, 1) app.RippleSimulatorApp
                name {mustBeTextScalar, mustBeMember(name, ["Close", "Top", "Wide"])}
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setCameraView(name);
            obj.emit("SettingsChanged");
        end

        function update(obj)
        % UPDATE Process all due input and render the current elapsed physical time.
        %   UPDATE(SIMULATOR) samples the elapsed-time source, processes scheduled
        %   rain at its correct timestamps, and updates the existing surface.
        %   It is useful when AutomaticUpdates=false. Calling it more often
        %   changes the rendering cadence, not the wave propagation speed.
        %
        %   See also app.RippleSimulatorApp.snapshot, app.RippleSimulatorApp.PlaybackRate.
            arguments
                obj (1, 1) app.RippleSimulatorApp
            end
            obj.requireReady();
            obj.Busy = true;
            guard = onCleanup(@() obj.endFrame());
            presentationRevision = obj.InputPresentationRevision;
            obj.processFrame();
            obj.finishFrame();
            obj.releaseInputPresentation(presentationRevision);
        end

        function waveField = snapshot(obj, options)
        % SNAPSHOT Retrieve the wave field data at the current simulation time.
        %   WAVEFIELD = SNAPSHOT(SIMULATOR) retrieves the wave field in a scalar
        %   structure containing the square Elevation matrix in meters,
        %   Coordinates in meters, DomainSize in meters, Time in seconds,
        %   IsAtRest, and GeometryRevision. Rows correspond to y and columns
        %   to x. Display exaggeration is absent.
        %
        %   WAVEFIELD = SNAPSHOT(...,Derivatives=true) also returns the vertical
        %   surface Velocity in meters per second and the dimensionless
        %   surface elevation gradients GradientX and GradientY.
        %   These fields are empty when Derivatives=false, the default.
        %
        %   All quantities use the same processed simulation time. Call UPDATE
        %   first to process newly elapsed time. An interrupted settings
        %   operation raises RippleSimulator:ReentrantRead instead of returning
        %   a partially updated state.
        %
        %   See also app.RippleSimulatorApp.update, app.RippleSimulatorApp.describe.
            arguments
                obj (1, 1) app.RippleSimulatorApp
                options.Derivatives (1, 1) {mustBeNumericOrLogical, ...
                    mustBeMember(options.Derivatives, [0, 1])} = false
            end
            guard = obj.beginRead();
            waveField = obj.Simulation.snapshot(Derivatives=options.Derivatives);
            delete(guard);
        end

        function value = describe(obj)
        % DESCRIBE Return accepted settings and numerical diagnostics with SI units.
        %   INFO = DESCRIBE(SIMULATOR) returns a coherent scalar structure with
        %   fluid properties and provenance, the source definition, physical
        %   domain, grid, playback and display settings, pending rain, seed,
        %   camera, lifecycle state, and numerical diagnostics.
        %
        %   Simulation records include source counts, events, cache storage,
        %   slope limits, numerical omission bounds, and SettlingPeriods.
        %   Omission bounds do not quantify the finite-duration settling
        %   approximation or experimental uncertainty. This read does not
        %   advance simulation time.
        %
        %   See also app.RippleSimulatorApp.snapshot, app.RippleSimulatorApp.update.
            arguments
                obj (1, 1) app.RippleSimulatorApp
            end
            guard = obj.beginRead();
            value = struct(Fluid=obj.Simulation.Fluid.describe(), Source=obj.Simulation.Source.describe(), ...
                Material=obj.Material, DomainSizeMeters=obj.DomainSize, GridResolution=obj.GridResolution, ...
                PlaybackRate=obj.PlaybackRate, HeightScale=obj.HeightScale, ...
                Paused=obj.Paused, PendingRain=obj.Scheduler.PendingCount, RandomSeed=obj.RandomSeed, ...
                RainStrengthScale=obj.RainStrengthScale, ...
                AutoclickStrengthScale=obj.AutoclickStrengthScale, ...
                Display=obj.Display, Camera=obj.View.describeCamera(), ...
                ReflectionsEnabled=obj.ReflectionsEnabled, ReflectionCoefficient=obj.ReflectionCoefficient, ...
                Simulation=obj.Simulation.diagnostics(), Status=obj.Status, LastError=obj.LastError);
            value.Display.BackgroundColor = obj.BackgroundColor;
            delete(guard);
        end

        function capture(obj, filename)
        % CAPTURE Save the displayed application view as a PNG screenshot.
        %   CAPTURE(SIMULATOR) captures the current view, then opens a save dialog.
        %   CAPTURE(SIMULATOR,FILENAME) saves the current view to FILENAME.
        %   FILENAME is a text scalar ending in .png. An existing file can
        %   be overwritten; choose a new name to preserve an earlier image.
        %   The capture includes controls and visible panels.
        %
        %   See also app.RippleSimulatorApp.setCameraView, getframe, imwrite.
            arguments
                obj (1, 1) app.RippleSimulatorApp
                filename {mustBeTextScalar} = ""
            end
            obj.beginOperation(false);
            guard = onCleanup(@() obj.endOperation());
            pixels = app.internal.ui.rendering.captureFigure(obj.Figure);
            if strlength(string(filename)) == 0
                [name, folder] = uiputfile("*.png", "Save Screenshot", "ripples.png");
                if isequal(name, 0)
                    return
                end
                filename = fullfile(folder, name);
            end
            [~, ~, extension] = fileparts(string(filename));
            assert(strcmpi(extension, ".png"), "RippleSimulator:CaptureFormat", ...
                "Application captures require a .png filename.");
            imwrite(pixels, string(filename));
        end

        function value = get.Figure(obj)
            value = obj.View.Figure;
        end

        function value = get.PhysicalTime(obj)
            value = obj.Simulation.CurrentTime;
        end

        function value = get.IsAtRest(obj)
            value = obj.Simulation.IsAtRest;
        end

        function value = get.GridResolution(obj)
            value = obj.Simulation.GridResolution;
        end

        function value = get.Wavelength(obj)
            value = obj.Simulation.Source.Wavelength;
        end

        function value = get.PressureImpulse(obj)
            value = obj.Simulation.Source.PressureImpulse;
        end

        function value = get.SourceMode(obj)
            value = obj.Simulation.Source.Mode;
        end

        function value = get.PlaybackRate(obj)
            value = obj.Clock.Rate;
        end

        function value = get.MeasuredFPS(obj)
            value = obj.FrameRate.MeasuredFPS;
        end

        function value = get.ShowFPS(obj)
            value = obj.Display.ShowFPS;
        end

        function set.ShowFPS(obj, value)
            value = validateBoolean(value);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.Display.ShowFPS = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function value = get.Paused(obj)
            value = obj.Clock.IsPaused;
        end

        function value = get.Wireframe(obj)
            value = obj.Display.Wireframe;
        end

        function value = get.SurfaceMode(obj)
            value = obj.Display.SurfaceMode;
        end

        function value = get.Colormap(obj)
            value = obj.Display.Colormap;
        end

        function value = get.ColormapReversed(obj)
            value = obj.Display.ColormapReversed;
        end

        function value = get.FullScreen(obj)
            value = obj.Display.FullScreen;
        end

        function value = get.LightingEnabled(obj)
            value = obj.Display.LightingEnabled;
        end

        function value = get.SurfaceOpacity(obj)
            value = obj.Display.SurfaceOpacity;
        end

        function value = get.ReflectionsEnabled(obj)
            value = obj.Boundary.Enabled;
        end

        function value = get.ReflectionCoefficient(obj)
            value = obj.Boundary.Coefficient;
        end

        function value = get.ControlsVisible(obj)
            value = obj.Display.ControlsVisible;
        end

        function value = get.ReadoutVisible(obj)
            value = obj.Display.ReadoutVisible;
        end

        function value = get.HeightScale(obj)
            value = obj.Display.HeightScale;
        end

        function value = get.AutomaticHeightScale(obj)
            value = obj.Display.AutomaticHeightScale;
        end

        function value = get.NavigationMode(obj)
            value = obj.Display.NavigationMode;
        end

        function value = get.DomainSize(obj)
            value = obj.Simulation.DomainSize;
        end

        function value = get.Material(obj)
            switch obj.Simulation.Fluid.Name
                case "Water"
                    value = "Water";
                case "Olive oil"
                    value = "Olive oil";
                case "Silicone oil (KF-96L-5cs)"
                    value = "KF-96L-5cs";
                case "Silicone oil (KF-96-100cs)"
                    value = "KF-96-100cs";
                case "Honey (Newtonian approximation)"
                    value = "Honey";
                case "Molten compound chocolate (Newtonian approximation)"
                    value = "Chocolate";
                case "Custom"
                    value = "Custom";
                otherwise
                    error("RippleSimulator:UnsupportedMaterial", ...
                        "The active fluid has no supported material identity.");
            end
        end

        function value = get.FluidProperties(obj)
            fluid = obj.Simulation.Fluid;
            value = struct(Density=fluid.Density, DynamicViscosity=fluid.DynamicViscosity, ...
                SurfaceTension=fluid.SurfaceTension, Temperature=fluid.Temperature);
        end

        function set.FluidProperties(obj, value)
            obj.changeFluid(app.internal.materials.customFluid(value), ...
                app.internal.ui.appearance.SurfaceStyle.empty, true);
        end

        function value = get.Appearance(obj)
            value = obj.Display.Appearance;
        end

        function set.Appearance(obj, value)
            style = app.internal.ui.appearance.SurfaceStyle(value, obj.SurfaceColor);
            obj.changeAppearance(style);
        end

        function value = get.SurfaceColor(obj)
            value = obj.Display.SurfaceColor;
        end

        function set.SurfaceColor(obj, value)
            obj.changeAppearance(app.internal.ui.appearance.SurfaceStyle("Custom", validatecolor(value)));
        end

        function value = get.BackgroundColor(obj)
            value = obj.View.Axes.Color;
        end

        function set.BackgroundColor(obj, value)
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setBackgroundColor(value);
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function value = get.Temperature(obj)
            value = obj.Simulation.Fluid.Temperature;
        end

        function value = get.RandomSeed(obj)
            value = obj.Scheduler.Seed;
        end

        function value = get.RainStrengthScale(obj)
            value = obj.RainScale;
        end

        function value = get.SoundEnabled(obj)
            value = obj.Display.SoundEnabled;
        end

        function set.SoundEnabled(obj, value)
            value = validateBoolean(value);
            assert(~value || obj.Audio.Available, "RippleSimulator:AudioUnavailable", ...
                "Audio playback is unavailable: %s", obj.Audio.FailureMessage);
            assert(obj.Status == "Running" || obj.Status == "Paused", ...
                "RippleSimulator:ApplicationState", "This operation requires a running or paused application.");
            obj.Display.SoundEnabled = value;
            if ~value
                obj.Audio.stop();
            end
            if isvalid(obj) && obj.Status ~= "Closing" && obj.Status ~= "Closed"
                obj.Controls.setSoundEnabled(value);
                obj.emit("SettingsChanged");
            end
        end

        function value = get.AutoclickEnabled(obj)
            value = obj.Display.AutoclickEnabled;
        end

        function value = get.AutoclickStrengthScale(obj)
            value = obj.Autoclick.StrengthScale;
        end

        function set.AutoclickEnabled(obj, value)
            value = validateBoolean(value);
            obj.requireReady();
            obj.Display.AutoclickEnabled = value;
            obj.View.setAutoclick(value);
            obj.Autoclick.reset();
            obj.synchronize();
            obj.emit("SettingsChanged");
        end


        function set.GridResolution(obj, value)
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            previous = obj.Simulation.snapshot();
            plan = obj.Simulation.prepareGrid(value);
            obj.installFrame(plan.Snapshot, obj.HeightScale, previous, obj.HeightScale);
            obj.Simulation.commitGrid(plan);
            obj.Autoclick.reset();
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.Wavelength(obj, value)
            validateattributes(value, "numeric", {"scalar", "real", "finite", ">=", 0.005, "<=", 0.1});
            obj.changeSource(app.internal.input.Source(value, obj.PressureImpulse, obj.SourceMode));
        end

        function set.PressureImpulse(obj, value)
            obj.changeSource(app.internal.input.Source(obj.Wavelength, value, obj.SourceMode));
        end

        function set.SourceMode(obj, value)
            obj.changeSource(app.internal.input.Source(obj.Wavelength, obj.PressureImpulse, value));
        end

        function set.PlaybackRate(obj, value)
            validateattributes(value, "numeric", {"scalar", "real", "finite", ">=", 0.1, "<=", 2});
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.Simulation.retimeReservations(obj.Clock.PhysicalTime, value/obj.PlaybackRate);
            obj.Clock.setRate(value);
            obj.synchronize();
            obj.emit("PlaybackChanged");
        end

        function set.Paused(obj, value)
            value = validateBoolean(value);
            obj.beginOperation(false);
            guard = onCleanup(@() obj.endOperation());
            obj.Autoclick.reset();
            if value
                obj.ResumePumpAfterPause = obj.ResumePumpAfterPause ...
                    || obj.ResumePumpAfterOperation || obj.Pump.Running == "on";
                stop(obj.Pump);
                obj.Clock.pauseAt(obj.Simulation.CurrentTime);
                obj.Audio.stop();
                obj.FrameRate.resetMeasurement();
                obj.Status = "Paused";
            else
                obj.ResumePumpAfterOperation = obj.ResumePumpAfterOperation || obj.ResumePumpAfterPause;
                obj.ResumePumpAfterPause = false;
                obj.Clock.resume();
                obj.FrameRate.resetMeasurement();
                obj.Status = "Running";
            end
            obj.synchronize();
            obj.emit("PlaybackChanged");
        end

        function set.Wireframe(obj, value)
            value = validateBoolean(value);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            if value ~= obj.Display.Wireframe
                obj.Display.LightingEnabled = value || obj.SurfaceMode ~= "Elevation";
                obj.View.setLighting(obj.Display.LightingEnabled);
            end
            obj.View.setWireframe(value);
            obj.Display.Wireframe = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.SurfaceMode(obj, value)
            value = string(validatestring(value, ...
                ["Shaded", "Elevation", "Contrast"]));
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setSurfaceMode(value);
            obj.Display.SurfaceMode = value;
            obj.Display.Wireframe = false;
            obj.Display.LightingEnabled = value ~= "Elevation";
            obj.View.setLighting(obj.Display.LightingEnabled);
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.Colormap(obj, value)
            [colors, value] = resolveColormap(value);
            if obj.ColormapReversed
                colors = flipud(colors);
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setColormap(colors);
            obj.Display.Colormap = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.ColormapReversed(obj, value)
            value = validateBoolean(value);
            colors = resolveColormap(obj.Colormap);
            if value
                colors = flipud(colors);
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setColormap(colors);
            obj.Display.ColormapReversed = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.FullScreen(obj, value)
            value = validateBoolean(value);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            if value
                obj.View.Figure.WindowState = "fullscreen";
            else
                obj.View.Figure.WindowState = "maximized";
            end
            obj.Display.FullScreen = value;
            obj.View.showControls(obj.ControlsVisible && ~value);
            obj.View.showReadout(obj.ReadoutVisible && ~value);
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.LightingEnabled(obj, value)
            value = validateBoolean(value);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setLighting(value);
            obj.Display.LightingEnabled = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.SurfaceOpacity(obj, value)
            validateattributes(value, "numeric", {"scalar", "real", "finite", ">=", 0.1, "<=", 1}, ...
                "", "SurfaceOpacity");
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setOpacity(double(value));
            obj.Display.SurfaceOpacity = double(value);
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.ControlsVisible(obj, value)
            value = validateBoolean(value);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.showControls(value && ~obj.FullScreen);
            obj.Display.ControlsVisible = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.ReflectionsEnabled(obj, value)
            value = validateBoolean(value);
            obj.requireReady();
            if value == obj.ReflectionsEnabled
                return
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            preparation = obj.showPreparation();
            candidate = createSimulation(obj.Simulation.Fluid, obj.DomainSize, ...
                obj.GridResolution, obj.Simulation.Source, value, obj.ReflectionCoefficient);
            obj.replaceSimulation(candidate, obj.HeightScale);
            obj.Boundary.Enabled = value;
            obj.synchronize();
            delete(preparation);
            obj.emit("SettingsChanged");
        end

        function set.ReflectionCoefficient(obj, value)
            validateattributes(value, "numeric", {"scalar", "real", "finite", ">=", 0, "<=", 1});
            obj.requireReady();
            if value == obj.ReflectionCoefficient
                return
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            preparation = onCleanup.empty;
            if obj.ReflectionsEnabled
                preparation = obj.showPreparation();
                candidate = createSimulation(obj.Simulation.Fluid, obj.DomainSize, obj.GridResolution, ...
                    obj.Simulation.Source, true, double(value));
                obj.replaceSimulation(candidate, obj.HeightScale);
            end
            obj.Boundary.Coefficient = double(value);
            obj.synchronize();
            delete(preparation);
            obj.emit("SettingsChanged");
        end

        function set.ReadoutVisible(obj, value)
            value = validateBoolean(value);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.showReadout(value && ~obj.FullScreen);
            obj.Display.ReadoutVisible = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.HeightScale(obj, value)
            validateattributes(value, "numeric", {"scalar", "real", "finite", ">=", 1, "<=", 1e6});
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            waveField = obj.Simulation.snapshot();
            obj.installFrame(waveField, double(value), waveField, obj.HeightScale);
            obj.Display.HeightScale = double(value);
            obj.Display.AutomaticHeightScale = false;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.AutomaticHeightScale(obj, value)
            value = validateBoolean(value);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            if value
                preparation = obj.showPreparation();
                scale = app.internal.ui.appearance.materialHeightScale(obj.Simulation.Fluid, obj.Wavelength);
                waveField = obj.Simulation.snapshot();
                obj.installFrame(waveField, scale, waveField, obj.HeightScale);
                obj.Display.HeightScale = scale;
                delete(preparation);
            end
            obj.Display.AutomaticHeightScale = value;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.NavigationMode(obj, value)
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setNavigation(value);
            obj.Display.NavigationMode = string(value);
            obj.Autoclick.reset();
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.DomainSize(obj, value)
            validateattributes(value, "numeric", {"scalar", "real", "finite", ">=", 0.005, "<=", 2.4});
            obj.requireReady();
            if double(value) == obj.DomainSize
                return
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            preparation = obj.showPreparation();
            candidate = createSimulation(obj.Simulation.Fluid, value, ...
                obj.GridResolution, obj.Simulation.Source, obj.ReflectionsEnabled, obj.ReflectionCoefficient);
            obj.replaceSimulation(candidate, obj.HeightScale);
            obj.synchronize();
            delete(preparation);
            obj.emit("SettingsChanged");
        end

        function set.Material(obj, value)
            mustBeTextScalar(value);
            mustBeMember(value, ["Water", "Olive oil", "KF-96L-5cs", "KF-96-100cs", ...
                "Honey", "Chocolate", "Custom"]);
            obj.requireReady();
            style = materialStyle(string(value));
            opacity = 1;
            if string(value) == "Custom"
                opacity = obj.SurfaceOpacity;
            end
            source = app.internal.input.Source(0.050, 0.100, obj.SourceMode);
            scale = 100;
            automaticHeightScale = false;
            switch string(value)
                case "Water"
                    fluid = app.internal.materials.water();
                case "Olive oil"
                    fluid = app.internal.materials.oliveOil();
                case "KF-96L-5cs"
                    fluid = app.internal.materials.silicone("5cSt");
                case "KF-96-100cs"
                    fluid = app.internal.materials.silicone("100cSt");
                case "Honey"
                    fluid = app.internal.materials.honey();
                    source = app.internal.input.Source(0.100, 0.150, obj.SourceMode);
                    scale = 200;
                case "Chocolate"
                    fluid = app.internal.materials.chocolate();
                    source = app.internal.input.Source(0.075, 0.200, obj.SourceMode);
                    scale = 200;
                case "Custom"
                    fluid = app.internal.materials.customFluid(obj.FluidProperties);
                    source = obj.Simulation.Source;
                    scale = obj.HeightScale;
                    automaticHeightScale = obj.AutomaticHeightScale;
                otherwise
                    error("RippleSimulator:UnsupportedMaterial", "The requested material is unsupported.");
            end
            % scale = app.internal.ui.appearance.materialHeightScale(fluid, source.Wavelength);
            obj.changeFluid(fluid, style, true, opacity, Source=source, ...
                HeightScale=scale, AutomaticHeightScale=automaticHeightScale);
        end

        function set.Temperature(obj, value)
            assert(obj.Material == "Water", "RippleSimulator:FixedMaterialTemperature", ...
                "This material has no temperature correlation. Define a custom material with properties " ...
                + "at the required temperature, or select water to use its temperature-dependent properties.");
            fluid = app.internal.materials.water(value);
            obj.changeFluid(fluid);
        end

        function set.RandomSeed(obj, value)
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.Scheduler.setSeed(value);
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.RainStrengthScale(obj, value)
            arguments
                obj (1, 1) app.RippleSimulatorApp
                value (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.RainScale = double(value);
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function set.AutoclickStrengthScale(obj, value)
            arguments
                obj (1, 1) app.RippleSimulatorApp
                value (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.Autoclick.StrengthScale = double(value);
            obj.synchronize();
            obj.emit("SettingsChanged");
        end
    end

    methods (Access = private)
        function position = gridPosition(obj, position)
            step = obj.DomainSize/(obj.GridResolution-1);
            position = round((position+obj.DomainSize/2)/step)*step-obj.DomainSize/2;
            position = max(-obj.DomainSize/2, min(obj.DomainSize/2, position));
        end

        function guard = beginRead(obj)
            assert(~obj.Busy || obj.Notifying, "RippleSimulator:ReentrantRead", ...
                "The application state is being updated. Read it after the operation completes.");
            previous = obj.Busy;
            obj.Busy = true;
            guard = onCleanup(@() obj.endRead(previous));
        end

        function endRead(obj, previous)
            if isvalid(obj)
                obj.Busy = previous;
            end
        end

        function emit(obj, eventName)
            previous = obj.Notifying;
            obj.Notifying = true;
            guard = onCleanup(@() obj.endNotification(previous));
            notify(obj, eventName);
        end

        function endNotification(obj, previous)
            if isvalid(obj)
                obj.Notifying = previous;
            end
        end

        function guard = showPreparation(obj)
            progress = [];
            if obj.Figure.Visible == "on"
                progress = uiprogressdlg(obj.Figure, Title="Simulating the wave field", ...
                    Message="Calculating the wave response", ...
                    Indeterminate="on", Cancelable="off");
            end
            resume = obj.canSuspendPlayback();
            guard = onCleanup(@() obj.endPreparation(progress, resume));
            if resume
                stop(obj.Pump);
            end
            if ~isempty(progress)
                drawnow;
                assert(isvalid(obj) && isgraphics(obj.Figure), "RippleSimulator:PreparationCancelled", ...
                    "The application was closed while calculating the wave response.");
            end
        end

        function endPreparation(obj, progress, resume)
            closeProgress(progress);
            obj.restorePlayback(resume);
        end

        function value = canSuspendPlayback(obj)
            value = ~obj.TickInProgress && ~isempty(obj.Pump) && isvalid(obj.Pump) ...
                && obj.Pump.Running == "on";
        end

        function restorePlayback(obj, resume)
            if isvalid(obj) && resume && obj.Status == "Running" ...
                    && ~isempty(obj.Pump) && isvalid(obj.Pump) && obj.Pump.Running == "off"
                start(obj.Pump);
            end
        end

        function clock = createClock(obj, rate)
            if isempty(obj.TimeSource)
                clock = app.internal.playback.Clock(rate);
            else
                clock = app.internal.playback.Clock(rate, obj.TimeSource);
            end
        end

        function endReset(obj, previousClock, held)
            if held
                try
                    previousClock.release();
                catch exception
                    if isvalid(obj) && obj.Status ~= "Closing" && obj.Status ~= "Closed"
                        obj.fail(exception);
                    end
                end
            end
            if isvalid(obj)
                obj.Busy = false;
            end
        end

        function beginOperation(obj, advance)
            if nargin < 2
                advance = true;
            end
            obj.requireReady();
            obj.Busy = true;
            obj.ResumePumpAfterOperation = obj.canSuspendPlayback();
            try
                if obj.ResumePumpAfterOperation
                    stop(obj.Pump);
                end
                obj.Clock.hold();
            catch exception
                obj.Busy = false;
                resume = obj.ResumePumpAfterOperation;
                obj.ResumePumpAfterOperation = false;
                obj.restorePlayback(resume);
                rethrow(exception);
            end
            try
                if advance
                    obj.processTime(obj.Clock.sample());
                    if ~obj.Simulation.IsAtRest || ~obj.LastRenderAtRest
                        obj.render();
                    end
                end
            catch exception
                obj.endOperation();
                rethrow(exception);
            end
        end

        function requireReady(obj)
            assert(obj.Status == "Running" || obj.Status == "Paused", ...
                "RippleSimulator:ApplicationState", "This operation requires a running or paused application.");
            assert(~obj.Busy, "RippleSimulator:ReentrantCommand", ...
                "An application operation is already in progress.");
        end

        function endFrame(obj)
            if isvalid(obj)
                obj.Busy = false;
            end
        end

        function endTick(obj, presentationRevision)
            if isvalid(obj)
                obj.releaseInputPresentation(presentationRevision);
                obj.TickInProgress = false;
            end
        end

        function prepareInputPresentation(obj)
            if obj.AutomaticUpdates && ~obj.Paused
                obj.InputPresentationRevision = obj.InputPresentationRevision + 1;
                if isempty(obj.InputPresentationClock)
                    obj.Clock.hold();
                    obj.InputPresentationClock = obj.Clock;
                end
            end
        end

        function releaseInputPresentation(obj, presentationRevision)
            if nargin > 1 && presentationRevision ~= obj.InputPresentationRevision
                return
            end
            if ~isempty(obj.InputPresentationClock)
                clock = obj.InputPresentationClock;
                obj.InputPresentationClock = app.internal.playback.Clock.empty;
                clock.release();
            end
        end

        function endInput(obj, clock)
            guard = onCleanup(@() obj.endFrame());
            clock.release();
        end

        function endOperation(obj)
            if isvalid(obj) && obj.Status ~= "Closing" && obj.Status ~= "Closed"
                try
                    obj.Clock.release();
                    obj.FrameRate.resetMeasurement();
                    if obj.ReadoutVisible && ~obj.FullScreen
                        obj.Controls.updateFrameRate(obj.MeasuredFPS);
                    end
                catch exception
                    obj.fail(exception);
                end
                obj.Busy = false;
                resume = obj.ResumePumpAfterOperation;
                obj.ResumePumpAfterOperation = false;
                obj.restorePlayback(resume);
            end
        end

        function identifier = acceptRipple(obj, position, refresh, strengthScale, action, playSound)
            if nargin < 4
                strengthScale = 1;
            end
            if nargin < 5
                action = "click";
            end
            if nargin < 6
                playSound = false;
            end
            obj.requireReady();
            obj.Busy = true;
            clock = obj.Clock;
            try
                clock.hold();
            catch exception
                obj.endFrame();
                rethrow(exception);
            end
            guard = onCleanup(@() obj.endInput(clock));
            obj.processTime(obj.Clock.sample());
            identifier = obj.Simulation.addSource(obj.Clock.PhysicalTime, position, StrengthScale=strengthScale);
            obj.prepareInputPresentation();
            if refresh
                obj.render();
            end
            state = obj.controlState();
            updated = obj.Controls.explain(action, state);
            if refresh && ~updated
                obj.Controls.updateStatus(state);
            end
            if refresh || updated
                obj.LastReadoutTime = obj.Clock.ActiveTime;
                obj.LastPendingRain = obj.Scheduler.PendingCount;
            end
            if playSound && obj.SoundEnabled
                if action == "autoclick"
                    obj.Audio.playAutomatic("Autoclick");
                else
                    obj.Audio.play();
                end
            end
        end

        function acceptAutoclick(obj, position)
            if obj.Paused || obj.Busy || ~obj.AutoclickEnabled || obj.NavigationMode ~= "Ripple"
                return
            end
            position = obj.gridPosition(position);
            time = obj.Clock.sample();
            if ~obj.Autoclick.accepts(position, time.ActiveTime)
                return
            end
            try
                obj.acceptRipple(position, ~obj.AutomaticUpdates, obj.Autoclick.StrengthScale, "autoclick", true);
                obj.Autoclick.record(position, time.ActiveTime);
            catch exception
                if ismember(string(exception.identifier), ...
                        ["RippleSimulator:SourceCapacity", "RippleSimulator:WaveLoading"])
                    obj.Autoclick.record(position, time.ActiveTime);
                    return
                end
                rethrow(exception);
            end
        end

        function settled = processTime(obj, time)
            wasActive = ~obj.Simulation.IsAtRest || obj.Scheduler.PendingCount > 0;
            pending = obj.Scheduler.due(time.ActiveTime);
            for index = 1:numel(pending.ActiveTimes)
                eventTime = time.PhysicalTime - time.Rate*(time.ActiveTime - pending.ActiveTimes(index));
                tolerance = 32*eps(max(1, time.PhysicalTime));
                assert(eventTime >= obj.Simulation.CurrentTime - tolerance, ...
                    "RippleSimulator:ScheduledTime", "A scheduled click is earlier than the current simulation time.");
                eventTime = max(eventTime, obj.Simulation.CurrentTime);
                obj.Simulation.addSource(eventTime, pending.Positions(index, :), Reserved=true, ...
                    StrengthScale=pending.StrengthScales(index));
                obj.Scheduler.consume(1);
            end
            obj.Simulation.advanceTo(time.PhysicalTime);
            settled = wasActive && obj.Simulation.IsAtRest && obj.Scheduler.PendingCount == 0;
        end

        function tick(obj)
            if ~isvalid(obj) || obj.TickInProgress || obj.Busy || obj.Status ~= "Running"
                return
            end
            obj.TickInProgress = true;
            presentationRevision = obj.InputPresentationRevision;
            tickGuard = onCleanup(@() obj.endTick(presentationRevision));
            try
                obj.Busy = true;
                frameGuard = onCleanup(@() obj.endFrame());
                obj.processFrame();
                obj.refreshFrameReadout();
                delete(frameGuard);
                if isvalid(obj) && isgraphics(obj.Figure) && obj.Figure.Visible == "on"
                    drawnow;
                end
                if isvalid(obj) && obj.Status == "Running"
                    obj.finishFrame(false);
                end
            catch exception
                if isvalid(obj)
                    obj.fail(exception);
                end
            end
        end

        function processFrame(obj)
            settled = obj.processTime(obj.Clock.sample());
            if ~obj.Simulation.IsAtRest || ~obj.LastRenderAtRest
                obj.render();
            else
                obj.View.Rain.update(obj.Clock.ActiveTime);
            end
            if settled
                obj.Controls.explain("rest", obj.controlState());
            end
        end

        function finishFrame(obj, refreshReadout)
            if ~obj.Paused
                obj.FrameRate.recordFrameTime();
            end
            if nargin < 2 || refreshReadout
                obj.refreshFrameReadout();
            end
        end

        function refreshFrameReadout(obj)
            if obj.ReadoutVisible && ~obj.FullScreen
                obj.updateReadout(false);
                obj.Controls.updateFrameRate(obj.MeasuredFPS);
            end
        end

        function updateReadout(obj, force)
            time = obj.Clock.ActiveTime;
            pending = obj.Scheduler.PendingCount;
            if force || time < obj.LastReadoutTime || time >= obj.LastReadoutTime + 0.1 ...
                    || pending ~= obj.LastPendingRain
                obj.Controls.updateStatus(obj.controlState());
                obj.LastReadoutTime = time;
                obj.LastPendingRain = pending;
            end
        end

        function render(obj)
            waveField = obj.Simulation.renderSnapshot();
            obj.View.render(waveField, obj.HeightScale);
            obj.measureFrame(waveField);
            obj.View.Rain.update(obj.Clock.ActiveTime);
            obj.LastRenderAtRest = obj.Simulation.IsAtRest;
        end

        function measureFrame(obj, waveField)
            crest = max(waveField.Elevation, [], "all");
            trough = min(waveField.Elevation, [], "all");
            obj.Measurements = struct(Crest=crest, Trough=trough, WaveHeight=crest - trough);
        end

        function changeSource(obj, source)
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            preparation = onCleanup.empty;
            if obj.Simulation.requiresSourcePreparation(source)
                preparation = obj.showPreparation();
            end
            plan = obj.Simulation.prepareSource(source);
            scale = obj.HeightScale;
            if obj.AutomaticHeightScale && source.Wavelength ~= obj.Wavelength
                scale = app.internal.ui.appearance.materialHeightScale(obj.Simulation.Fluid, source.Wavelength);
                waveField = obj.Simulation.snapshot();
                obj.installFrame(waveField, scale, waveField, obj.HeightScale);
            end
            obj.Simulation.commitSource(plan);
            obj.Display.HeightScale = scale;
            obj.synchronize();
            delete(preparation);
            obj.emit("SettingsChanged");
        end

        function changeFluid(obj, fluid, style, enableLighting, opacity, options)
            arguments
                obj
                fluid
                style = app.internal.ui.appearance.SurfaceStyle.empty
                enableLighting = false
                opacity = obj.SurfaceOpacity
                options.Source (1, 1) app.internal.input.Source = obj.Simulation.Source
                options.HeightScale (1, 1) double = obj.HeightScale
                options.AutomaticHeightScale (1, 1) logical = obj.AutomaticHeightScale
            end
            obj.requireReady();
            sameExperiment = isequal(fluid, obj.Simulation.Fluid) ...
                && isequal(options.Source, obj.Simulation.Source);
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            preparation = onCleanup.empty;
            if ~sameExperiment
                preparation = obj.showPreparation();
                candidate = createSimulation(fluid, obj.DomainSize, obj.GridResolution, ...
                    options.Source, obj.ReflectionsEnabled, obj.ReflectionCoefficient);
            end
            scale = options.HeightScale;
            if options.AutomaticHeightScale
                scale = app.internal.ui.appearance.materialHeightScale(fluid, options.Source.Wavelength);
            end
            if sameExperiment
                if scale ~= obj.HeightScale
                    waveField = obj.Simulation.snapshot();
                    obj.installFrame(waveField, scale, waveField, obj.HeightScale);
                end
                obj.Display.HeightScale = scale;
            else
                obj.replaceSimulation(candidate, scale);
            end
            obj.Display.AutomaticHeightScale = options.AutomaticHeightScale;
            if ~isempty(style)
                obj.View.setStyle(style, obj.Wireframe);
                obj.Display.Appearance = style.Name;
                obj.Display.SurfaceColor = style.Color;
            end
            if enableLighting
                obj.View.setLighting(true);
                obj.Display.LightingEnabled = true;
            end
            obj.View.setOpacity(opacity);
            obj.Display.SurfaceOpacity = opacity;
            obj.synchronize();
            delete(preparation);
            obj.emit("SettingsChanged");
        end

        function changeAppearance(obj, style, enableLighting, opacity)
            if nargin < 3
                enableLighting = false;
            end
            if nargin < 4
                opacity = obj.SurfaceOpacity;
            end
            obj.beginOperation();
            guard = onCleanup(@() obj.endOperation());
            obj.View.setStyle(style, obj.Wireframe);
            obj.Display.Appearance = style.Name;
            obj.Display.SurfaceColor = style.Color;
            if enableLighting
                obj.View.setLighting(true);
                obj.Display.LightingEnabled = true;
            end
            obj.View.setOpacity(opacity);
            obj.Display.SurfaceOpacity = opacity;
            obj.synchronize();
            obj.emit("SettingsChanged");
        end

        function replaceSimulation(obj, candidate, verticalScale)
            previous = obj.Simulation.snapshot();
            obj.installFrame(candidate.snapshot(), verticalScale, previous, obj.HeightScale);
            obj.Simulation = candidate;
            obj.Display.HeightScale = verticalScale;
            obj.Scheduler.cancel();
            obj.View.Rain.clear();
            obj.Clock.restart();
            obj.Autoclick.reset();
            obj.LastRenderAtRest = true;
        end

        function installFrame(obj, candidate, scale, previous, previousScale)
            try
                obj.View.render(candidate, scale);
                obj.measureFrame(candidate);
            catch exception
                try
                    obj.View.render(previous, previousScale);
                    obj.measureFrame(previous);
                catch rollbackException
                    obj.fail(addCause(exception, rollbackException));
                end
                rethrow(exception);
            end
        end

        function synchronize(obj)
            obj.View.setInputPaused(obj.Paused);
            obj.Controls.synchronize(obj.controlState());
        end

        function state = controlState(obj)
            state = obj.Display;
            state.BackgroundColorSelection = obj.View.BackgroundColorSelection;
            state.GridResolution = obj.GridResolution;
            state.Wavelength = obj.Wavelength;
            state.PressureImpulse = obj.PressureImpulse;
            state.SourceMode = obj.SourceMode;
            state.PlaybackRate = obj.PlaybackRate;
            state.Paused = obj.Paused;
            state.ReflectionsEnabled = obj.ReflectionsEnabled;
            state.ReflectionCoefficient = obj.ReflectionCoefficient;
            state.DomainSize = obj.DomainSize;
            state.Material = obj.Material;
            state.FluidProperties = obj.FluidProperties;
            state.Temperature = obj.Temperature;
            state.RandomSeed = obj.RandomSeed;
            state.PhysicalTime = obj.PhysicalTime;
            state.IsAtRest = obj.IsAtRest;
            state.ActiveCount = obj.Simulation.ActiveCount;
            state.PendingRain = obj.Scheduler.PendingCount;
            state.RainStrengthScale = obj.RainStrengthScale;
            state.AutoclickStrengthScale = obj.AutoclickStrengthScale;
            state.Status = obj.Status;
            state.LastError = obj.LastError;
            state.Measurements = obj.Measurements;
            state.MeasuredFPS = obj.MeasuredFPS;
        end

        function dispatch(obj, action, value)
            if ~isvalid(obj) || obj.Status == "Closing" || obj.Status == "Closed"
                return
            end
            try
                switch string(action)
                    case "autoclickInput"
                        obj.acceptAutoclick(value);
                        return
                    case "autoclick"
                        obj.AutoclickEnabled = ~obj.AutoclickEnabled;
                    case "click"
                        if obj.Paused
                            return
                        end
                        obj.acceptRipple(obj.gridPosition(value), ~obj.AutomaticUpdates, 1, "click", true);
                        return
                    case "rain"
                        obj.rain();
                        return
                    case "clear"
                        obj.clear();
                    case "pause"
                        obj.Paused = ~obj.Paused;
                    case "reset"
                        obj.reset();
                    case "setup"
                        obj.applySetup(value);
                    case "resolution"
                        obj.GridResolution = value;
                    case "wavelength"
                        obj.Wavelength = value;
                    case "strength"
                        obj.PressureImpulse = value;
                    case "rainStrength"
                        obj.RainStrengthScale = value;
                    case "autoclickStrength"
                        obj.AutoclickStrengthScale = value;
                    case "sourceMode"
                        obj.SourceMode = value;
                    case "playback"
                        obj.PlaybackRate = value;
                    case "sound"
                        obj.SoundEnabled = ~obj.SoundEnabled;
                        return
                    case "wireframe"
                        obj.Wireframe = ~obj.Wireframe;
                    case "surfaceMode"
                        obj.SurfaceMode = value;
                    case "colormap"
                        obj.Colormap = value;
                        obj.SurfaceMode = "Elevation";
                    case "colormapReverse"
                        obj.ColormapReversed = ~obj.ColormapReversed;
                        obj.SurfaceMode = "Elevation";
                    case "fullscreen"
                        obj.FullScreen = ~obj.FullScreen;
                    case "lighting"
                        obj.LightingEnabled = ~obj.LightingEnabled;
                    case "reflections"
                        obj.ReflectionsEnabled = ~obj.ReflectionsEnabled;
                    case "reflectionCoefficient"
                        obj.ReflectionCoefficient = value;
                    case "controls"
                        obj.ControlsVisible = ~obj.ControlsVisible;
                    case "readout"
                        obj.ReadoutVisible = ~obj.ReadoutVisible;
                    case "fps"
                        obj.ShowFPS = ~obj.ShowFPS;
                    case "heightScale"
                        obj.HeightScale = value;
                    case "automaticHeight"
                        obj.AutomaticHeightScale = ~obj.AutomaticHeightScale;
                    case "navigation"
                        obj.NavigationMode = value;
                    case "camera"
                        obj.restoreCamera();
                    case "cameraView"
                        obj.setCameraView(value);
                    case "domain"
                        obj.DomainSize = value;
                    case "material"
                        obj.Material = value;
                    case "fluidProperties"
                        obj.FluidProperties = value;
                    case "appearance"
                        obj.Appearance = value;
                        obj.SurfaceMode = "Shaded";
                    case "surfaceColor"
                        obj.SurfaceColor = value;
                        obj.SurfaceMode = "Shaded";
                    case "backgroundColor"
                        obj.BackgroundColor = value;
                    case "opacity"
                        obj.SurfaceOpacity = value;
                    case "temperature"
                        obj.Temperature = value;
                    case "seed"
                        obj.RandomSeed = value;
                    case "capture"
                        obj.capture(value);
                    case "close"
                        obj.close();
                    case "help"
                        obj.Controls.showHelp(value);
                    otherwise
                        error("RippleSimulator:UnknownCommand", "Unknown application command: %s.", action);
                end
                if isvalid(obj) && obj.Status ~= "Closing" && obj.Status ~= "Closed"
                    obj.Controls.explain(action, obj.controlState());
                end
            catch exception
                if isvalid(obj) && isgraphics(obj.Figure)
                    obj.synchronize();
                    uialert(obj.Figure, exception.message, "Ripple Simulator", Icon="error");
                end
            end
        end

        function keyPressed(obj, event)
            modifier = "control";
            if ismac
                modifier = "command";
            end
            if obj.FullScreen && event.Key == "s" && isequal(string(event.Modifier), modifier)
                obj.dispatch("capture", "");
                return
            end
            focused = obj.Figure.CurrentObject;
            if isa(focused, "matlab.ui.control.NumericEditField") || isa(focused, "matlab.ui.control.EditField")
                return
            end
            if ~isempty(event.Modifier)
                return
            end
            switch event.Key
                case "p"
                    obj.dispatch("pause", []);
                case "space"
                    obj.dispatch("autoclick", []);
                case {"r", "insert"}
                    obj.dispatch("rain", []);
                case "c"
                    obj.dispatch("clear", []);
                case "w"
                    obj.dispatch("wireframe", []);
                case "s"
                    obj.dispatch("surfaceMode", "Elevation");
                case "a"
                    obj.dispatch("surfaceMode", "Shaded");
                case "d"
                    obj.dispatch("surfaceMode", "Contrast");
                case "f11"
                    obj.dispatch("fullscreen", []);
                case "home"
                    obj.dispatch("camera", []);
                case "1"
                    obj.dispatch("cameraView", "Close");
                case "2"
                    obj.dispatch("cameraView", "Top");
                case "3"
                    obj.dispatch("cameraView", "Wide");
                case "l"
                    obj.dispatch("lighting", []);
                case "m"
                    obj.dispatch("sound", []);
                case "n"
                    obj.dispatch("autoclick", []);
                case "b"
                    obj.dispatch("reflections", []);
                case "escape"
                    if obj.FullScreen
                        obj.dispatch("fullscreen", []);
                    else
                        obj.dispatch("close", []);
                    end
                case "x"
                    obj.dispatch("close", []);
                otherwise
                    % Unassigned keys retain their component-specific behavior.
            end
        end

        function fail(obj, exception)
            obj.LastError = string(exception.message);
            obj.Status = "Faulted";
            obj.Clock.freeze();
            obj.View.setInputPaused(true);
            obj.FrameRate.resetMeasurement();
            if ~isempty(obj.Pump) && isvalid(obj.Pump)
                stop(obj.Pump);
            end
            obj.View.StatusLabel.Text = "Simulation stopped. Use Experiment > Restore default experiment. " ...
                + obj.LastError;
            warning("RippleSimulator:ApplicationFault", "%s", getReport(exception, "extended", "hyperlinks", "off"));
        end
    end
end

function value = validateBoolean(value)
    validateattributes(value, ["numeric", "logical"], {"scalar", "real", "finite", "binary"});
    value = logical(value);
end

function releaseTimer(ownedTimer)
    if ~isempty(ownedTimer) && isvalid(ownedTimer)
        stop(ownedTimer);
        delete(ownedTimer);
    end
end

function model = createSimulation(fluid, domainSize, resolution, source, reflections, coefficient)
    arguments
        fluid
        domainSize
        resolution
        source
        reflections
        coefficient = 1
    end
    if reflections && coefficient == 1
        model = app.internal.simulation.ReflectingSimulation(fluid, domainSize, resolution, source, ...
            SettlingPeriods=10, Capacity=512);
    elseif reflections && coefficient > 0
        model = app.internal.simulation.Simulation(fluid, domainSize, resolution, source, SettlingPeriods=10, ...
            TablePeriods=10, ReflectionCoefficient=coefficient, CacheBytes=536870912, Capacity=512);
    else
        model = app.internal.simulation.Simulation(fluid, domainSize, resolution, source, SettlingPeriods=10, ...
            TablePeriods=10, PrepareDisplay=true, Capacity=512);
    end
end

function value = displaySettings(verticalScale)
    value = struct(Wireframe=false, LightingEnabled=true, ControlsVisible=true, ReadoutVisible=true, ...
        HeightScale=verticalScale, AutomaticHeightScale=true, ...
        NavigationMode="Ripple", SoundEnabled=true, ...
        Appearance="Blue", SurfaceColor=[0, 0, 1], SurfaceOpacity=1, ShowFPS=true, AutoclickEnabled=false, ...
        SurfaceMode="Shaded", Colormap="winter", ColormapReversed=false, FullScreen=false);
end

function [colors, value] = resolveColormap(value)
    if isstring(value) || ischar(value)
        value = app.internal.ui.appearance.parseColormapInput(value);
    end
    if isstring(value) || ischar(value)
        mustBeTextScalar(value);
        value = string(value);
        parts = split(value, ".");
        assert(all(arrayfun(@(part) isvarname(part), parts)), "RippleSimulator:ColormapName", ...
            "Specify a colormap function name, such as winter, parula, or hsv.");
        colors = feval(value, 256);
    else
        colors = value;
    end
    validateattributes(colors, "numeric", {"2d", "ncols", 3, "nonempty", ...
        "real", "finite", ">=", 0, "<=", 1}, "", "Colormap");
    colors = double(colors);
    if isnumeric(value)
        value = colors;
    end
end

function style = materialStyle(material)
    switch material
        case "Water"
            style = app.internal.ui.appearance.SurfaceStyle("Blue");
        case {"KF-96L-5cs", "KF-96-100cs"}
            style = app.internal.ui.appearance.SurfaceStyle("White");
        case "Olive oil"
            style = app.internal.ui.appearance.SurfaceStyle("Golden");
        case "Honey"
            style = app.internal.ui.appearance.SurfaceStyle("Amber");
        case "Chocolate"
            style = app.internal.ui.appearance.SurfaceStyle("Dark brown");
        otherwise
            style = app.internal.ui.appearance.SurfaceStyle.empty;
    end
end

function closeProgress(progress)
    if ~isempty(progress) && isvalid(progress)
        close(progress);
    end
end
