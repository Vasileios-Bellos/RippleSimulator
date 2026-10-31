function fields = radialHighResponse(fluid, source, radii, times, cutoff, options)
% RADIALHIGHRESPONSE Complete a restricted contour on the real wavenumber axis.
%   The integral covers cutoff <= k*s <= 8 and includes both viscous poles
%   and the diffusive branch. FIELDS contains elevation, vertical velocity,
%   radial slope, and its time derivative. The high-wavenumber contribution
%   is evaluated only when the low-wavenumber contour's late-time validity
%   conditions are satisfied.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
        radii (:, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        times (1, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        cutoff (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive, ...
            mustBeLessThanOrEqual(cutoff, 8)}
        options.SpectralPoints (1, 1) {mustBeNumeric, mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.SpectralPoints, 512), ...
            mustBeLessThanOrEqual(options.SpectralPoints, 8192)} = 2048
        options.BranchOrder (1, 1) {mustBeNumeric, mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.BranchOrder, 64), ...
            mustBeLessThanOrEqual(options.BranchOrder, 512)} = 256
    end
    fields = zeros(numel(radii), numel(times), 4);
    if cutoff == 8 || isempty(radii) || isempty(times)
        return
    end
    panelCount = ceil(options.SpectralPoints/32);
    [nodes, weights] = app.internal.numerics.gaussLegendre(32);
    width = (sqrt(8) - sqrt(cutoff))/panelCount;
    variable = sqrt(cutoff) + ((nodes + 1)/2 + (0:panelCount - 1))*width;
    measure = repmat(weights*width/2, 1, panelCount);
    variable = variable(:);
    measure = 2*variable.*measure(:);
    q = variable.^2;
    wavenumber = q/source.Width;
    frequency = app.internal.physics.dispersion(wavenumber, fluid);
    sourceFrequency = app.internal.physics.dispersion(source.Wavenumber, fluid);
    epsilon = fluid.KinematicViscosity*wavenumber.^2./frequency;
    if source.Mode == "Impulse"
        [elevation, velocity] = app.internal.physics.viscousImpulse( ...
            epsilon, frequency*double(times), options.BranchOrder);
    else
        [elevation, velocity] = app.internal.physics.wavemaker( ...
            epsilon, frequency*double(times), sourceFrequency./frequency, options.BranchOrder);
    end
    spectrum = -source.PressureImpulse/fluid.Density*q.*wavenumber.*exp(-q.^2/2).*measure;
    elevation = spectrum.*elevation./frequency;
    velocity = spectrum.*velocity;
    basis = besselj(0, double(radii)*wavenumber');
    derivativeBasis = -besselj(1, double(radii)*wavenumber');
    fields = cat(3, basis*elevation, basis*velocity, ...
        derivativeBasis*(wavenumber.*elevation), derivativeBasis*(wavenumber.*velocity));
end
