function kernel = prepareContour(fluid, source, order, cutoff)
% PREPARECONTOUR Construct a decaying contour for a weakly viscous pole pair.
%   KERNEL = PREPARECONTOUR(FLUID, SOURCE, ORDER) prepares the upper physical
%   pole on a ray at pi/9 and its terminal arc. The dimensionless variables
%   are u=sqrt(k*s) and tau=omega0*t. The diffusive branch is not included.
%   The contour is restricted to a clean interface and small viscous ratios
%   on the retained spectrum. Its coefficients retain the terminal arc.
%   CUTOFF optionally restricts the dimensionless wavenumber k*s below eight;
%   the caller must account for the remaining real-wavenumber response.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
        order (1, 1) {mustBeNumeric, mustBeInteger, mustBeGreaterThanOrEqual(order, 64), ...
            mustBeLessThanOrEqual(order, 512)} = 256
        cutoff (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive, ...
            mustBeLessThanOrEqual(cutoff, 8)} = 8
    end
    angle = pi/9;
    k0 = source.Wavenumber;
    frequency = app.internal.physics.dispersion(k0, fluid);
    cutoffFrequency = app.internal.physics.dispersion(cutoff*k0, fluid);
    cutoffRatio = fluid.KinematicViscosity*(cutoff*k0)^2/cutoffFrequency;
    assert(cutoffRatio <= 0.1, "RippleSimulator:ContourViscosityRange", ...
        "The contour evaluator requires a viscous ratio no greater than 0.1 on its retained spectrum.");
    beta = 9.81*k0/frequency^2;
    epsilon = fluid.KinematicViscosity*k0^2/frequency;
    [nodes, weights] = app.internal.numerics.gaussLegendre(order);
    limit = sqrt(cutoff);
    points = (nodes + 1)*limit/2*exp(1i*angle);
    measure = weights*limit/2*exp(1i*angle);
    [arcNodes, arcWeights] = app.internal.numerics.gaussLegendre(64);
    arcAngles = (1 - arcNodes)*angle/2;
    arcPoints = limit*exp(1i*arcAngles);
    arcMeasure = -1i*arcPoints.*arcWeights*angle/2;
    points = [points; arcPoints];
    measure = [measure; arcMeasure];
    root = -2*epsilon*points.^3 + 1i*sqrt(beta + (1 - beta)*points.^4);
    for iteration = 1:12
        verticalRoot = sqrt(root + epsilon*points.^3);
        residual = (root + 2*epsilon*points.^3).^2 + beta + (1 - beta)*points.^4 ...
            - 4*epsilon^1.5*points.^4.5.*verticalRoot;
        derivative = 2*(root + 2*epsilon*points.^3) ...
            - 2*epsilon^1.5*points.^4.5./verticalRoot;
        root = root - residual./derivative;
    end
    residual = (root + 2*epsilon*points.^3).^2 + beta + (1 - beta)*points.^4 ...
        - 4*epsilon^1.5*points.^4.5.*sqrt(root + epsilon*points.^3);
    residualScale = beta + (1 - beta)*abs(points).^4;
    assert(max(abs(residual)./residualScale) < 1e-11, "RippleSimulator:ContourRootAccuracy", ...
        "The viscous contour poles did not satisfy the required residual tolerance.");
    pole = points.*root;
    assert(all(real(pole) < 0), "RippleSimulator:ContourDecay", ...
        "The selected contour must contain only decaying poles.");
    denominator = 2*(root + 2*epsilon*points.^3) ...
        - 2*epsilon^1.5*points.^4.5./sqrt(root + epsilon*points.^3);
    coefficient = -2*points.^4.*exp(-points.^4/2)./denominator.*measure;
    offset = 0;
    forcingNorm = 1;
    if source.Mode == "Wavemaker"
        offset = 8*pi;
        forcingNorm = 8;
        coefficient = coefficient.*app.internal.physics.completedForcing(pole);
    end
    kernel = struct(Pole=pole, Coefficient=coefficient, Wavenumber=points.^2, ...
        Frequency=frequency, Width=source.Width, ...
        ElevationScale=source.PressureImpulse/(fluid.Density*source.Width*frequency), ...
        TimeOffset=offset, Beta=beta, ViscosityRatio=epsilon, ...
        Cutoff=double(cutoff), ForcingNorm=forcingNorm, Mode=source.Mode, Fluid=fluid, Source=source);
end
