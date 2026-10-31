function [nodes, weights] = gaussLegendre(order)
% GAUSSLEGENDRE Return Gaussian quadrature on the interval [-1, 1].
%   [NODES, WEIGHTS] = GAUSSLEGENDRE(ORDER) returns column vectors in
%   increasing node order using the symmetric tridiagonal Jacobi matrix.
    arguments
        order (1, 1) {mustBeNumeric, mustBeInteger, mustBePositive, ...
            mustBeLessThanOrEqual(order, 512)}
    end
    if order == 1
        nodes = 0;
        weights = 2;
        return
    end
    indices = (1:double(order)-1)';
    offDiagonal = indices./sqrt(4*indices.^2-1);
    [vectors, values] = eig(diag(offDiagonal, 1)+diag(offDiagonal, -1));
    [nodes, permutation] = sort(diag(values));
    weights = 2*vectors(1, permutation)'.^2;
end
