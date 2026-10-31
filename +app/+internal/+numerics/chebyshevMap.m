function [nodes, matrix] = chebyshevMap(points, panelWidth, order)
% CHEBYSHEVMAP Prepare piecewise barycentric interpolation at Chebyshev nodes.
%   Panels cover the range of POINTS and have width at most PANELWIDTH.
%   Each panel uses ORDER first-kind Chebyshev nodes. MATRIX maps nodal values
%   to POINTS without extrapolation beyond the panel boundaries.
    arguments
        points (:, 1) double {mustBeReal, mustBeFinite}
        panelWidth (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        order (1, 1) double {mustBeInteger, mustBeGreaterThanOrEqual(order, 2)}
    end
    assert(numel(points) >= 2 && max(points) > min(points), ...
        "RippleSimulator:InterpolationGrid", "Interpolation requires a nonzero coordinate range.");
    panelCount = ceil((max(points)-min(points))/panelWidth);
    edges = linspace(min(points), max(points), panelCount+1);
    halfWidth = diff(edges)/2;
    center = (edges(1:end-1)+edges(2:end))/2;
    angles = pi*(2*(0:order-1)'+1)/(2*order);
    localNodes = cos(angles);
    weights = (-1).^(0:order-1)'.*sin(angles);
    nodes = reshape(center+localNodes*halfWidth, [], 1);
    panel = discretize(points, edges);
    coordinates = (points-reshape(center(panel), [], 1))./reshape(halfWidth(panel), [], 1);
    difference = coordinates-localNodes';
    exact = difference == 0;
    difference(exact) = 1;
    coefficients = weights'./difference;
    exactRows = any(exact, 2);
    coefficients(exactRows, :) = double(exact(exactRows, :));
    coefficients = coefficients./sum(coefficients, 2);
    rows = repmat((1:numel(points))', 1, order);
    columns = (panel-1)*order+(1:order);
    matrix = sparse(rows(:), columns(:), coefficients(:), numel(points), numel(nodes));
end
