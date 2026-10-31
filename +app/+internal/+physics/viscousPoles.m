function [poles, coefficients] = viscousPoles(viscosityRatio)
% VISCOUSPOLES Return the stable physical pole pair and combined coefficients.
%   The pole contribution is C(1)*(exp(P(1)*t)+exp(P(2)*t))/2 plus
%   C(2)*(exp(P(1)*t)-exp(P(2)*t))/(P(1)-P(2)). This representation remains
%   finite when the two poles coalesce. Each output has one column per input
%   viscosity. A scaled cubic factorization avoids general polynomial solves
%   and cancellation in the slow pole of a strongly viscous mode.
    arguments
        viscosityRatio (:, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive, ...
            mustBeLessThanOrEqual(viscosityRatio, 1e3)}
    end
    parameter = double(viscosityRatio)';
    inverseScale = min(1, parameter);
    quadratic = 4*inverseScale;
    linear = -4*min(1, 1./parameter).^2;
    constant = -16*inverseScale.^3;
    value = 2*ones(size(parameter));
    for iteration = 1:32
        residual = ((value+quadratic).*value+linear).*value+constant;
        derivative = (3*value+2*quadratic).*value+linear;
        next = value-residual./derivative;
        converged = all(abs(next-value) <= 4*eps(value));
        value = next;
        if converged
            break
        end
    end
    assert(converged, "RippleSimulator:ViscousPoles", ...
        "The viscous pole factorization did not converge.");
    inverse = sqrt(inverseScale./value);
    meanPole = 2*parameter.*(inverse-1);
    shared = 0.5+inverse+2*inverse.^2;
    product = (shared-2*inverse.^3)./(shared+2*inverse.^3);
    separation = sqrt(complex(meanPole.^2-product));
    faster = meanPole-separation;
    poles = [product./faster; faster];
    denominator = 0.5+inverse.^2+4*inverse.^6;
    coefficients = [2*(inverse.^2./parameter).*inverse.^3./denominator; ...
        (0.5+inverse.^2-inverse.^3)./denominator];
end
