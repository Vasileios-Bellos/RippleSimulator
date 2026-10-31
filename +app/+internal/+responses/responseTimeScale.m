function [timeScale, period] = responseTimeScale(fluid, source)
% RESPONSETIMESCALE Preserve the longer wave or viscous relaxation time.
%   PERIOD is the inviscid reference period in seconds. TIMESCALE also retains
%   the longest Stokes relaxation time over the retained source spectrum.
%   This scale controls response sampling and the separate finite settling
%   approximation; it does not replace the full viscous evolution equations.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
    end
    frequency = app.internal.physics.dispersion(source.Wavenumber, fluid);
    period = 2*pi/frequency;
    maximumWavenumber = 12/source.Width;
    if fluid.SurfaceTension > 0
        maximumWavenumber = min(maximumWavenumber, sqrt(9.81*fluid.Density/fluid.SurfaceTension));
    end
    relaxationTime = 2*fluid.KinematicViscosity*maximumWavenumber ...
        /(9.81+fluid.SurfaceTension*maximumWavenumber^2/fluid.Density);
    timeScale = max(period, relaxationTime);
end
