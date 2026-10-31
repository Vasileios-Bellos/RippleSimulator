function [matrix, derivative] = interpolationMatrix(nodes, points)
% INTERPOLATIONMATRIX Prepare local quintic interpolation on a uniform grid.
%   The derivative differentiates the same local polynomial. Points must lie
%   inside the grid; endpoint stencils remain one-sided.
    arguments
        nodes (1, :) double {mustBeReal, mustBeFinite}
        points (1, :) double {mustBeReal, mustBeFinite}
    end
    assert(numel(nodes) >= 6 && all(diff(nodes) > 0), "RippleSimulator:InterpolationGrid", ...
        "Interpolation requires at least six increasing grid nodes.");
    step = nodes(2)-nodes(1);
    assert(max(abs(diff(nodes)-step)) <= 64*eps(max(abs(nodes))), ...
        "RippleSimulator:InterpolationGrid", "Interpolation requires a uniform grid.");
    assert(all(points >= nodes(1)-8*eps(nodes(end)) & points <= nodes(end)+8*eps(nodes(end))), ...
        "RippleSimulator:InterpolationCoverage", "Interpolation points must lie inside the grid.");
    points = min(nodes(end), max(nodes(1), points));
    centers = floor((points-nodes(1))/step)+1;
    start = max(1, min(numel(nodes)-5, centers-2));
    indices = start(:)+(0:5);
    offsets = (points(:)-reshape(nodes(indices), size(indices)))/step;
    weights = ones(size(indices));
    slopes = zeros(size(indices));
    for column = 1:6
        others = setdiff(1:6, column);
        factors = offsets(:, others)./(column-others);
        weights(:, column) = prod(factors, 2);
        if nargout > 1
            for omitted = 1:5
                retained = [1:omitted-1, omitted+1:5];
                slopes(:, column) = slopes(:, column) ...
                    + prod(factors(:, retained), 2)/((column-others(omitted))*step);
            end
        end
    end
    rows = repmat((1:numel(points))', 1, 6);
    matrix = sparse(rows(:), indices(:), weights(:), numel(points), numel(nodes));
    if nargout > 1
        derivative = sparse(rows(:), indices(:), slopes(:), numel(points), numel(nodes));
    end
end
