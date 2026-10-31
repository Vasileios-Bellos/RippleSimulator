function waveField = inspectWaveField(options)
% INSPECTWAVEFIELD Animate the wave field and surface elevation profiles.
%   INSPECTWAVEFIELD() uses the Capillary wave setup with a central four-cycle
%   wavemaker. The wave field is precomputed at uniformly spaced time steps
%   and animated along with its centerline and outward profiles.
%
%   WAVEFIELD = INSPECTWAVEFIELD(...) returns the complete time history:
%     Time                    - Sample times (s)
%     Coordinates, DomainSize - Grid coordinates and domain width (m)
%     Elevation               - Surface elevation (m)
%     Velocity                - Vertical surface velocity (m/s)
%     GradientX, GradientY    - Horizontal elevation gradients (dimensionless)
%   For N nodes per axis and T sample times, Elevation, Velocity, GradientX,
%   and GradientY are N-by-N-by-T arrays. Rows follow y, columns follow x,
%   and each page corresponds to one sample time.
%
%   INSPECTWAVEFIELD(Name=Value) accepts these options:
%     Setup           - "Gravity", "Balanced", or "Capillary" water setup
%     SourceMode      - "Impulse" or the four-cycle "Wavemaker"
%     Wavelength      - Characteristic wavelength in meters
%     PressureImpulse - Pressure strength in Pa s
%     PlaybackRate    - Positive simulation-time multiplier
%     PlaybackMode    - "Sampled" or "ElapsedTime"
%     SampleInterval  - Maximum time step between wave-field samples, in seconds
%   The default sampling interval provides at least 40 samples per
%   reference period.
%   Sampled playback displays every time step; ElapsedTime may skip intermediate
%   time steps when rendering cannot keep pace with the requested rate.
%
%   Example:
%       inspectWaveField(Setup="Gravity", SourceMode="Wavemaker", ...
%           Wavelength=0.05, PressureImpulse=0.1, PlaybackMode="Sampled");
%
%   See also rippleSimulator, app.RippleSimulatorApp,
%   app.RippleSimulatorApp.snapshot

    arguments
        options.Setup {mustBeTextScalar, ...
            mustBeMember(options.Setup, ["Gravity", "Balanced", "Capillary"])} = "Capillary"
        options.SourceMode {mustBeTextScalar, ...
            mustBeMember(options.SourceMode, ["Impulse", "Wavemaker"])} = "Wavemaker"
        options.Wavelength (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
        options.PressureImpulse (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
        options.PlaybackRate (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
        options.PlaybackMode {mustBeTextScalar, ...
            mustBeMember(options.PlaybackMode, ["Sampled", "ElapsedTime"])} = "Sampled"
        options.SampleInterval (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
    end
    options = resolveOptions(options);
    waveField = calculateWaveField(options, nargout > 0);
    visibility = get(groot, "DefaultFigureVisible");
    [figureHandle, plots] = createFigure(waveField, options.Wavelength);
    closeFigure = onCleanup(@() releaseFigure(figureHandle));
    movegui(figureHandle, "center");
    figureHandle.Visible = visibility;
    drawnow;
    playAnimation(figureHandle, plots, waveField, options);
    delete(closeFigure);
    if nargout == 0
        clear waveField
    end
end

function resolved = resolveOptions(options)
    setup = app.internal.simulation.defaultSetup(options.Setup);
    resolved = struct(Wavelength=setup.Source.Wavelength, ...
        PressureImpulse=setup.Source.PressureImpulse, PlaybackRate=setup.PlaybackRate);
    names = fieldnames(options);
    for index = 1:numel(names)
        resolved.(names{index}) = options.(names{index});
    end
    if ~isfield(resolved, "SampleInterval")
        resolved.SampleInterval = min(resolved.PlaybackRate/50, referencePeriod(resolved.Wavelength)/40);
    end
end

function period = referencePeriod(wavelength)
    fluid = app.internal.materials.water(20);
    frequency = app.internal.physics.dispersion(2*pi/wavelength, fluid);
    period = 2*pi/frequency;
end

function waveField = calculateWaveField(options, includeDerivatives)
    [readTime, setTime] = createTimeSource();
    simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, ...
        TimeSource=readTime, Setup=options.Setup);
    closeApplication = onCleanup(@() simulator.close());
    simulator.SoundEnabled = false;
    simulator.Wavelength = options.Wavelength;
    simulator.SourceMode = options.SourceMode;
    simulator.PressureImpulse = options.PressureImpulse;
    simulator.PlaybackRate = 1;
    simulator.addRipple([0, 0]);
    information = simulator.describe();
    duration = information.Simulation.SourceLifetime;
    time = linspace(0, duration, ceil(duration/options.SampleInterval)+1);
    shape = [simulator.GridResolution, simulator.GridResolution, numel(time)];
    elevation = zeros(shape);
    velocity = zeros(0, 0, 0);
    gradientX = zeros(0, 0, 0);
    gradientY = zeros(0, 0, 0);
    if includeDerivatives
        velocity = zeros(shape);
        gradientX = zeros(shape);
        gradientY = zeros(shape);
    end
    for index = 1:numel(time)
        setTime(time(index));
        simulator.update();
        state = simulator.snapshot(Derivatives=includeDerivatives);
        elevation(:, :, index) = state.Elevation;
        if includeDerivatives
            velocity(:, :, index) = state.Velocity;
            gradientX(:, :, index) = state.GradientX;
            gradientY(:, :, index) = state.GradientY;
        end
    end
    waveField = struct(Time=time, Coordinates=state.Coordinates, DomainSize=state.DomainSize, ...
        Elevation=elevation, Velocity=velocity, GradientX=gradientX, GradientY=gradientY);
    delete(closeApplication);
end

function [readTime, setTime] = createTimeSource()
    elapsedTime = 0;
    readTime = @read;
    setTime = @write;

    function value = read()
        value = elapsedTime;
    end

    function write(value)
        elapsedTime = value;
    end
end

function [fig, plots] = createFigure(waveField, wavelength)
    coordinates = waveField.Coordinates;
    center = (numel(coordinates)+1)/2;
    outerRadius = min(wavelength/2, coordinates(end)/2);
    outward = coordinates >= outerRadius;
    fullLimit = elevationLimit(1e6*max(abs(waveField.Elevation), [], "all"));
    outerLimit = elevationLimit(1e6*max(abs(waveField.Elevation(center, outward, :)), [], "all"));
    initial = 1e6*waveField.Elevation(:, :, 1);
    fig = figure(Visible="off", Name="Surface Elevation", Color="white", ...
        Position=[100, 100, 1320, 440], DefaultAxesFontName="Helvetica", ...
        DefaultTextFontName="Helvetica", DefaultTextInterpreter="none", ...
        DefaultAxesTickLabelInterpreter="none");
    if ~isMATLABReleaseOlderThan("R2025a") && isprop(fig, "Theme")
        fig.Theme = "light";
    end
    layout = tiledlayout(fig, 1, 3, TileSpacing="compact", Padding="compact");
    timeLabel = title(layout, "Surface elevation at 0.000 s");
    surfaceAxes = nexttile(layout);
    elevationMap = imagesc(surfaceAxes, 1000*coordinates, 1000*coordinates, initial);
    axis(surfaceAxes, "xy", "image");
    xlabel(surfaceAxes, "x (mm)");
    ylabel(surfaceAxes, "y (mm)");
    title(surfaceAxes, "Wave field");
    scale = colorbar(surfaceAxes);
    scale.Label.String = "Elevation (μm)";
    scale.Label.Interpreter = "none";
    surfaceAxes.CLim = [-fullLimit, fullLimit];

    sectionAxes = nexttile(layout);
    centerline = plot(sectionAxes, 1000*coordinates, initial(center, :), ...
        LineWidth=1.5, Color=[0, 0.35, 0.65]);
    configureProfile(sectionAxes, "Centerline, y = 0", "x (mm)", ...
        1000*coordinates([1, end]), fullLimit);

    outerAxes = nexttile(layout);
    outerLine = plot(outerAxes, 1000*coordinates(outward), initial(center, outward), ...
        LineWidth=1.5, Color=[0, 0.35, 0.65]);
    configureProfile(outerAxes, sprintf("Outward profile, r ≥ %.3g mm", 1000*outerRadius), ...
        "Radius (mm)", [1000*outerRadius, 1000*coordinates(end)], outerLimit);
    plots = struct(Map=elevationMap, Centerline=centerline, Outer=outerLine, ...
        Time=timeLabel, Center=center, Outward=outward);
end

function configureProfile(ax, heading, horizontalLabel, limits, verticalLimit)
    xlabel(ax, horizontalLabel);
    ylabel(ax, "Elevation (μm)", Interpreter="none");
    title(ax, heading, Interpreter="none");
    xlim(ax, limits);
    ylim(ax, [-verticalLimit, verticalLimit]);
    grid(ax, "on");
end

function limit = elevationLimit(peak)
    peak = max(peak, eps);
    increment = 10^floor(log10(peak))/2;
    limit = increment*ceil(1.1*peak/increment);
end

function playAnimation(fig, plots, waveField, options)
    interval = waveField.Time(2)-waveField.Time(1);
    started = tic;
    presented = tic;
    index = 2;
    while isgraphics(fig) && index <= numel(waveField.Time)
        if options.PlaybackMode == "Sampled"
            pause(max(0, interval/options.PlaybackRate-toc(presented)));
        else
            pause(max(0, waveField.Time(index)/options.PlaybackRate-toc(started)));
            index = min(numel(waveField.Time), max(index, 1+floor(toc(started)*options.PlaybackRate/interval)));
        end
        if ~isgraphics(fig)
            break
        end
        presented = tic;
        elevation = 1e6*waveField.Elevation(:, :, index);
        plots.Map.CData = elevation;
        plots.Centerline.YData = elevation(plots.Center, :);
        plots.Outer.YData = elevation(plots.Center, plots.Outward);
        plots.Time.String = sprintf("Surface elevation at %.3f s", waveField.Time(index));
        drawnow;
        index = index + 1;
    end
end

function releaseFigure(fig)
    if isgraphics(fig)
        close(fig);
    end
end
