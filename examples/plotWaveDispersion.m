function waveProperties = plotWaveDispersion()
% PLOTWAVEDISPERSION Plot phase and group velocities for water at 20 °C.
%   WAVEPROPERTIES = PLOTWAVEDISPERSION() returns a structure containing
%   Wavelength (m), AngularFrequency (rad/s), PhaseVelocity (m/s), and
%   GroupVelocity (m/s), each a 1-by-400 array. CrossoverWavelength (m)
%   is the wavelength at which gravity and surface tension contribute
%   equally. The calculation uses the app's documented water density and
%   surface tension at 20 °C. The plotted relation is inviscid; the app
%   includes viscous dissipation.
%
%   See also rippleSimulator, app.RippleSimulatorApp, inspectWaveField
    simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false);
    closeApp = onCleanup(@() simulator.close());
    information = simulator.describe();
    density = information.Fluid.DensityKgPerM3;
    tension = information.Fluid.SurfaceTensionNPerM;
    gravity = 9.81;
    wavelength = logspace(log10(0.002), log10(0.2), 400);
    wavenumber = 2*pi./wavelength;
    frequency = sqrt(gravity*wavenumber + tension/density*wavenumber.^3);
    phaseVelocity = frequency./wavenumber;
    groupVelocity = (gravity + 3*tension/density*wavenumber.^2)./(2*frequency);
    crossover = 2*pi*sqrt(tension/(density*gravity));
    waveProperties = struct(Wavelength=wavelength, AngularFrequency=frequency, ...
        PhaseVelocity=phaseVelocity, GroupVelocity=groupVelocity, CrossoverWavelength=crossover);

    fig = figure(Name="Gravity-capillary wave propagation", Color="white");
    if ~isMATLABReleaseOlderThan("R2025a") && isprop(fig, "Theme")
        fig.Theme = "light";
    end
    layout = tiledlayout(fig, 1, 1, Padding="loose");
    ax = nexttile(layout);
    semilogx(ax, 1000*wavelength, [phaseVelocity; groupVelocity], LineWidth=1.5);
    set(ax, FontName="Helvetica", FontSize=11, TickLabelInterpreter="none", YLim=[0, 0.8]);
    xline(ax, 1000*crossover, ":");
    text(ax, 1000*crossover, 0.04, "Equal restoring contributions", ...
        HorizontalAlignment="center", VerticalAlignment="bottom", Interpreter="none", ...
        FontName="Helvetica", FontSize=9, BackgroundColor="white", Margin=3);
    xlabel(ax, "Wavelength (mm)", Interpreter="none");
    ylabel(ax, "Velocity (m/s)", Interpreter="none");
    title(ax, "Deep-water wave dispersion: water at 20 °C", Interpreter="none");
    legend(ax, ["Phase velocity", "Group velocity"], Location="north", Interpreter="none");
    grid(ax, "on");
    movegui(fig, "center");
    if nargout == 0
        clear waveProperties
    end
end
