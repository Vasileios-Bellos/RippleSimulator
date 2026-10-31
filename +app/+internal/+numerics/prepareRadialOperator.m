function operator = prepareRadialOperator(mapping)
% PREPARERADIALOPERATOR Assemble a fixed cubic Hermite interpolation matrix.
%   Columns multiply concatenated radial elevations and slopes. Each observation
%   point uses the values and slopes at its two adjacent radial nodes.
    arguments
        mapping (1, 1) struct
    end
    count = numel(mapping.Index);
    radialCount = mapping.RadiusCount;
    index = double(mapping.Index);
    fraction = mapping.Fraction;
    row = repmat((1:count)', 1, 4);
    column = [index, index + radialCount, index + 1, index + radialCount + 1];
    weights = [2*fraction.^3 - 3*fraction.^2 + 1, ...
        mapping.Step*(fraction.^3 - 2*fraction.^2 + fraction), ...
        -2*fraction.^3 + 3*fraction.^2, mapping.Step*(fraction.^3 - fraction.^2)];
    operator = sparse(row, column, weights, count, 2*radialCount);
end
