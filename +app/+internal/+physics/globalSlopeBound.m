function value = globalSlopeBound(fluid, source)
% GLOBALSLOPEBOUND Bound all radial slopes per unit pressure strength.
%   Modal energy bounds the unit initial-velocity displacement by one.
%   The angular integral gives abs(J1) <= 2/pi. Gravity-only and
%   capillarity-only denominators then bound the Gaussian spectral integral.
%   The finite wavemaker contributes its dimensionless forcing L1 norm.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
    end
    wavenumber = source.Wavenumber;
    frequency = app.internal.physics.dispersion(wavenumber, fluid);
    gravityRatio = 9.81*wavenumber/frequency^2;
    tensionRatio = fluid.SurfaceTension*wavenumber^3/(fluid.Density*frequency^2);
    gravityMoment = 2^0.25*gamma(1.25)/sqrt(gravityRatio);
    tensionMoment = 2^-0.25*gamma(0.75)/sqrt(tensionRatio);
    forcingNorm = 1;
    if source.Mode == "Wavemaker"
        forcingNorm = 8;
    end
    value = forcingNorm*2/pi*min(gravityMoment, tensionMoment) ...
        *wavenumber^2/(fluid.Density*frequency);
end
