function scale = materialHeightScale(fluid, wavelength)
% MATERIALHEIGHTSCALE Match reference-impulse visibility to water at 20 degrees Celsius.
%   The ratio uses the peak center displacement under equal Gaussian pressure
%   impulses. It changes only the fixed vertical display multiplier. Physical
%   elevations, loading, and decay remain unchanged. The scale is independent
%   of the selected pressure strength and is never updated during playback.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        wavelength (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
    end
    reference = app.internal.materials.water(20);
    baseline = peakDisplacement(reference, double(wavelength));
    actual = peakDisplacement(fluid, double(wavelength));
    scale = min(1e6, max(1, round(100*baseline/actual, 3, "significant")));
end

function peak = peakDisplacement(fluid, wavelength)
    persistent keys peaks
    if isempty(keys)
        keys = zeros(0, 4);
        peaks = zeros(0, 1);
    end
    key = [fluid.Density, fluid.DynamicViscosity, fluid.SurfaceTension, wavelength];
    index = find(all(keys == key, 2), 1);
    if ~isempty(index)
        peak = peaks(index);
        return
    end
    source = app.internal.input.Source(wavelength, 1);
    [timeScale, period] = app.internal.responses.responseTimeScale(fluid, source);
    times = unique([0, logspace(-6, log10(4*timeScale/period), 129)*period, ...
        linspace(0, 4*period, 129)]);
    response = app.internal.physics.radialResponse(fluid, source, 0, times, ...
        Method="Real", SpectralPoints=257);
    peak = max(abs(response(:, :, 1)), [], "all");
    assert(isfinite(peak) && peak > 0, "RippleSimulator:DisplayScale", ...
        "The reference displacement must be finite and positive.");
    if size(keys, 1) == 16
        keys(1, :) = [];
        peaks(1) = [];
    end
    keys(end+1, :) = key;
    peaks(end+1, 1) = peak;
end
