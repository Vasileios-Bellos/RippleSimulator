function [elevation, velocity, slope] = interpolateResponse(fields, times, mapping, age)
% INTERPOLATERESPONSE Evaluate a tensor Hermite response at one physical age.
%   Temporal interpolation uses stored time derivatives. Radial interpolation
%   uses the corresponding spatial derivatives on the precomputed observation map.
    arguments
        fields (:, :, 4) double
        times (1, :) double
        mapping (1, 1) struct
        age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
    end
    index = discretize(age, times);
    assert(isfinite(index), "RippleSimulator:ResponseTimeCoverage", ...
        "The requested age exceeds the response table coverage.");
    step = times(index+1) - times(index);
    fraction = (age - times(index))/step;
    basis = [2*fraction^3 - 3*fraction^2 + 1, fraction^3 - 2*fraction^2 + fraction, ...
        -2*fraction^3 + 3*fraction^2, fraction^3 - fraction^2];
    profile = zeros(size(fields, 1), 1, 4);
    profile(:, 1, 1) = combineTime(fields, index, step, basis, 1);
    profile(:, 1, 3) = combineTime(fields, index, step, basis, 3);
    if nargout >= 2
        derivative = [6*fraction^2 - 6*fraction, 3*fraction^2 - 4*fraction + 1, ...
            -6*fraction^2 + 6*fraction, 3*fraction^2 - 2*fraction];
        profile(:, 1, 2) = combineTime(fields, index, step, derivative, 1)/step;
        profile(:, 1, 4) = combineTime(fields, index, step, derivative, 3)/step;
    end
    if nargout >= 3
        [elevation, velocity, slope] = app.internal.numerics.interpolateRadial(profile, mapping);
    elseif nargout == 2
        [elevation, velocity] = app.internal.numerics.interpolateRadial(profile, mapping);
    else
        elevation = app.internal.numerics.interpolateRadial(profile, mapping);
    end
end

function profile = combineTime(fields, index, step, basis, component)
    profile = basis(1)*fields(:, index, component) ...
        + step*basis(2)*fields(:, index, component+1) ...
        + basis(3)*fields(:, index+1, component) ...
        + step*basis(4)*fields(:, index+1, component+1);
end
