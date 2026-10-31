function [frequency, phaseVelocity, groupVelocity] = dispersion(wavenumber, fluid, gravity, depth)
% DISPERSION Evaluate the inviscid gravity-capillary wave dispersion relation.
%   [FREQUENCY, PHASEVELOCITY, GROUPVELOCITY] = DISPERSION(K, FLUID, G, H) returns
%   angular frequency in rad/s and phase and group velocities in m/s for angular
%   wavenumbers K in rad/m. H is the fluid depth in meters; Inf denotes
%   deep water. Outputs have the same shape as K. Viscous evolution is
%   evaluated separately and is not represented by this inviscid relation.
    arguments
        wavenumber {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
        fluid (1, 1) app.internal.materials.Fluid
        gravity (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative} = 9.81
        depth (1, 1) {mustBeNumeric, mustBeReal, mustBePositive} = Inf
    end
    k = double(wavenumber);
    capillarity = fluid.SurfaceTension/fluid.Density;
    assert(gravity > 0 || capillarity > 0, "RippleSimulator:NoRestoringForce", ...
        "Gravity or surface tension must be positive.");
    restoring = gravity*k + capillarity*k.^3;
    restoringDerivative = gravity + 3*capillarity*k.^2;
    if isinf(depth)
        frequency = sqrt(restoring);
        groupVelocity = restoringDerivative./(2*frequency);
    else
        depthFactor = tanh(k*depth);
        frequency = sqrt(restoring.*depthFactor);
        groupVelocity = (restoringDerivative.*depthFactor ...
            + restoring.*depth.*(1-depthFactor.^2))./(2*frequency);
    end
    phaseVelocity = frequency./k;
end
