function fields = radialResponse(fluid, source, radii, times, options)
% RADIALRESPONSE Reconstruct a localized response by a Hankel integral.
%   FIELDS = RADIALRESPONSE(FLUID, SOURCE, RADII, TIMES) returns an Nr-by-Nt-by-4
%   array containing elevation (m), vertical velocity (m/s), radial slope,
%   and the radial derivative of vertical velocity (1/s). Radii are a column
%   in meters; times are a row in seconds. Each source acts in an unbounded,
%   infinitely deep fluid with gravity 9.81 m/s^2 and a clean interface.
%   SpectralPoints is the minimum real-axis quadrature size. BranchOrder
%   controls viscous branch quadrature. Late responses use a qualified
%   low-wavenumber contour completed by a real high-wavenumber integral.
%   Large real-axis quadratures use piecewise Chebyshev interpolation of
%   the temporal response, retaining every spatial quadrature node.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
        radii (:, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        times (1, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        options.SpectralPoints (1, 1) {mustBeNumeric, mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.SpectralPoints, 257), ...
            mustBeLessThanOrEqual(options.SpectralPoints, 16385)} = 2049
        options.BranchOrder (1, 1) {mustBeNumeric, mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.BranchOrder, 16), ...
            mustBeLessThanOrEqual(options.BranchOrder, 512)} = 64
        options.Method {mustBeTextScalar, mustBeMember(options.Method, ["Auto", "Real"])} = "Auto"
    end
    fields = zeros(numel(radii), numel(times), 4);
    if isempty(radii) || isempty(times)
        return
    end
    sourceFrequency = app.internal.physics.dispersion(source.Wavenumber, fluid);
    maximumWavenumber = 12/source.Width;
    maximumFrequency = app.internal.physics.dispersion(maximumWavenumber, fluid);
    assert(fluid.KinematicViscosity*maximumWavenumber^2/maximumFrequency <= 1e3, ...
        "RippleSimulator:ViscosityRange", ...
        "This viscosity and source scale exceed the supported spectral range. " ...
        + "Increase the characteristic wavelength or use a less viscous fluid.");
    if string(options.Method) == "Real"
        late = false(size(times));
        kernel = struct();
    else
        [late, kernel] = selectLateTimes(fluid, source, max(radii), times, sourceFrequency);
    end
    if any(late)
        fields(:, late, :) = app.internal.physics.radialLateResponse(kernel, radii, times(late));
    end
    if all(late)
        return
    end
    earlyTimes = double(times(~late));
    panelCount = max([ceil(options.SpectralPoints/32), ...
        ceil(max(earlyTimes)*sourceFrequency/pi), ceil(max(radii)/source.Width/2)]);
    [nodes, weights] = app.internal.numerics.gaussLegendre(32);
    width = sqrt(12)/panelCount;
    variable = ((nodes + 1)/2 + (0:panelCount-1))*width;
    measure = repmat(weights*width/2, 1, panelCount);
    variable = variable(:);
    measure = 2*variable.*measure(:);
    q = variable.^2;
    wavenumber = q/source.Width;
    [elevation, velocity, mapping] = prepareTemporalResponse( ...
        fluid, source, wavenumber, earlyTimes, options.BranchOrder);
    potentialImpulse = source.PressureImpulse/fluid.Density;
    spectrum = -potentialImpulse*q.*wavenumber.*exp(-q.^2/2).*measure;
    argument = double(radii)*wavenumber';
    basis = besselj(0, argument);
    derivativeBasis = -besselj(1, argument);
    if isempty(mapping)
        elevationIntegrand = spectrum.*elevation;
        velocityIntegrand = spectrum.*velocity;
        fields(:, ~late, :) = cat(3, basis*elevationIntegrand, basis*velocityIntegrand, ...
            derivativeBasis*(wavenumber.*elevationIntegrand), ...
            derivativeBasis*(wavenumber.*velocityIntegrand));
    else
        basis = basis*(spectrum.*mapping);
        derivativeBasis = derivativeBasis*((wavenumber.*spectrum).*mapping);
        fields(:, ~late, :) = cat(3, basis*elevation, basis*velocity, ...
            derivativeBasis*elevation, derivativeBasis*velocity);
    end
end

function [elevation, velocity, mapping] = prepareTemporalResponse(fluid, source, wavenumber, times, branchOrder)
% PREPARETEMPORALRESPONSE Evaluate H/omega and its physical-time derivative.
    forcing = app.internal.physics.dispersion(source.Wavenumber, fluid);
    coordinates = source.Width*wavenumber;
    panelWidth = 0.125*min(1, 20*pi/(forcing*max(times)));
    order = 20;
    panelCount = ceil((max(coordinates)-min(coordinates))/panelWidth);
    mapping = sparse(0, 0);
    calculationWavenumber = wavenumber;
    if 2*order*panelCount < numel(wavenumber)
        [nodes, mapping] = app.internal.numerics.chebyshevMap(coordinates, panelWidth, order);
        calculationWavenumber = nodes/source.Width;
    end
    frequency = app.internal.physics.dispersion(calculationWavenumber, fluid);
    parameters = fluid.KinematicViscosity*calculationWavenumber.^2./frequency;
    if isempty(mapping)
        [elevation, velocity] = temporalModes(parameters, frequency, forcing, times, source.Mode, branchOrder);
    else
        elevation = zeros(numel(frequency), numel(times));
        velocity = elevation;
        for first = 1:128:numel(frequency)
            rows = first:min(first+127, numel(frequency));
            [elevation(rows, :), velocity(rows, :)] = temporalModes( ...
                parameters(rows), frequency(rows), forcing, times, source.Mode, branchOrder);
        end
    end
    elevation = elevation./frequency;
end

function [elevation, velocity] = temporalModes(parameters, frequency, forcing, times, mode, branchOrder)
    age = frequency*times;
    switch mode
        case "Impulse"
            [elevation, velocity] = app.internal.physics.viscousImpulse(parameters, age, branchOrder);
        case "Wavemaker"
            [elevation, velocity] = app.internal.physics.wavemaker(parameters, age, forcing./frequency, branchOrder);
        otherwise
            error("RippleSimulator:SourceMode", "The source mode is not supported.");
    end
end

function [late, kernel] = selectLateTimes(fluid, source, radius, times, sourceFrequency)
    late = false(size(times));
    kernel = struct();
    duration = 0;
    if source.Mode == "Wavemaker"
        duration = 8*pi/sourceFrequency;
    end
    threshold = 48*pi/sourceFrequency + duration;
    if ~any(times >= threshold)
        return
    end
    cutoff = app.internal.physics.contourCutoff(fluid, source);
    if fluid.SurfaceTension == 0
        minimumWavenumber = cutoff/source.Width;
    else
        minimumWavenumber = sqrt((2/sqrt(3) - 1)*9.81*fluid.Density/fluid.SurfaceTension);
    end
    [~, ~, minimumGroupVelocity] = app.internal.physics.dispersion(minimumWavenumber, fluid);
    threshold = max(threshold, 1.6*radius/minimumGroupVelocity + duration);
    if ~any(times >= threshold)
        return
    end
    kernel = app.internal.physics.prepareContour(fluid, source, 256, cutoff);
    growthLimit = max(radius/source.Width*abs(imag(kernel.Wavenumber))./(-real(kernel.Pole)));
    threshold = max(threshold, 1.01*growthLimit/sourceFrequency + duration);
    late = times >= threshold;
end
