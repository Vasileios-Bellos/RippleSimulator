function [elevation, velocity, slope] = interpolateRadial(fields, mapping)
% INTERPOLATERADIAL Sample a radial Hermite profile on a precomputed spatial map.
%   FIELDS stores elevation, velocity, radial slope, and the mixed derivative
%   in its third dimension. The first output is independent of output count.
    arguments
        fields (:, 1, 4) double
        mapping (1, 1) struct
    end
    assert(mapping.RadiusCount == size(fields, 1), "RippleSimulator:ResponseMapping", ...
        "The radial mapping belongs to a different response grid.");
    prepared = isfield(mapping, "Operator") && ~isempty(mapping.Operator);
    if prepared
        elevation = reshape(mapping.Operator*[fields(:, 1, 1); fields(:, 1, 3)], mapping.Shape);
        if nargout >= 2
            velocity = reshape(mapping.Operator*[fields(:, 1, 2); fields(:, 1, 4)], mapping.Shape);
        end
    else
        coefficients = radialCoefficients(mapping.Step, fields(:, 1, 1), fields(:, 1, 3));
        elevation = reshape(samplePolynomial(coefficients, mapping), mapping.Shape);
        if nargout >= 2
            velocityCoefficients = radialCoefficients(mapping.Step, fields(:, 1, 2), fields(:, 1, 4));
            velocity = reshape(samplePolynomial(velocityCoefficients, mapping), mapping.Shape);
        end
    end
    if nargout >= 3
        if prepared
            coefficients = radialCoefficients(mapping.Step, fields(:, 1, 1), fields(:, 1, 3));
        end
        index = mapping.Index;
        fraction = mapping.Fraction;
        values = (coefficients(index, 2) + fraction.*(2*coefficients(index, 3) ...
            + 3*fraction.*coefficients(index, 4)))/mapping.Step;
        slope = reshape(values, mapping.Shape);
    end
end

function coefficients = radialCoefficients(step, values, slopes)
    difference = diff(values);
    left = slopes(1:end-1);
    right = slopes(2:end);
    coefficients = [values(1:end-1), step*left, ...
        3*difference - step*(2*left + right), -2*difference + step*(left + right)];
end

function values = samplePolynomial(coefficients, mapping)
    index = mapping.Index;
    fraction = mapping.Fraction;
    values = coefficients(index, 1) + fraction.*(coefficients(index, 2) ...
        + fraction.*(coefficients(index, 3) + fraction.*coefficients(index, 4)));
end
