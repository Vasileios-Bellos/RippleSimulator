function [spatial, temporal, relativeResidual] = factorResponse(matrix, tolerance)
% FACTORRESPONSE Compress response samples with a verified residual bound.
%   [U, C, E] = FACTORRESPONSE(A, TOL) returns factors satisfying
%   norm(A-U*C,"fro") <= TOL*max(abs(A),[],"all"). E is the measured
%   residual divided by that maximum. An adaptive orthogonal projection
%   reduces the singular-value decomposition when A has low numerical rank.
%   A full decomposition handles unresolved or high-rank matrices.
    arguments
        matrix (:, :) double {mustBeReal, mustBeFinite, mustBeNonempty}
        tolerance (1, 1) double {mustBeReal, mustBeFinite, mustBePositive, mustBeLessThan(tolerance, 1)}
    end
    scale = max(abs(matrix), [], "all");
    if scale == 0
        spatial = zeros(size(matrix, 1), 1);
        temporal = zeros(1, size(matrix, 2));
        relativeResidual = 0;
        return
    end
    threshold = tolerance*scale;
    basis = zeros(size(matrix, 1), 0);
    reduced = matrix;
    if min(size(matrix)) > 96
        [basis, reduced] = projectResponse(matrix, threshold/2);
    end
    [left, singular, right] = svd(reduced, "econ");
    [spatial, temporal] = truncateFactors(left, diag(singular), right, threshold/2);
    if ~isempty(basis)
        spatial = basis*spatial;
    end
    relativeResidual = norm(matrix-spatial*temporal, "fro")/scale;
    if relativeResidual > tolerance
        % Orthogonal projection reduces coefficient roundoff near the tolerance.
        temporal = spatial'*matrix;
        relativeResidual = norm(matrix-spatial*temporal, "fro")/scale;
    end
    if relativeResidual > tolerance && ~isempty(basis)
        [left, singular, right] = svd(matrix, "econ");
        [spatial, temporal] = truncateFactors(left, diag(singular), right, threshold/2);
        relativeResidual = norm(matrix-spatial*temporal, "fro")/scale;
        if relativeResidual > tolerance
            temporal = spatial'*matrix;
            relativeResidual = norm(matrix-spatial*temporal, "fro")/scale;
        end
    end
    assert(relativeResidual <= tolerance, "RippleSimulator:ResponseFactorization", ...
        "The response factors exceed the requested numerical tolerance.");
end

function [basis, reduced] = projectResponse(matrix, threshold)
    blockSize = 32;
    maximumRank = min(256, floor(min(size(matrix))/blockSize)*blockSize);
    basis = zeros(size(matrix, 1), maximumRank);
    residual = matrix;
    stream = RandStream("mt19937ar", Seed=1949);
    for last = blockSize:blockSize:maximumRank
        previous = 1:last-blockSize;
        current = last-blockSize+(1:blockSize);
        samples = residual*randn(stream, size(matrix, 2), blockSize);
        samples = samples-basis(:, previous)*(basis(:, previous)'*samples);
        samples = samples-basis(:, previous)*(basis(:, previous)'*samples);
        [basis(:, current), ~] = qr(samples, 0);
        retained = 1:last;
        [basis(:, retained), ~] = qr(basis(:, retained), 0);
        reduced = basis(:, retained)'*matrix;
        residual = matrix-basis(:, retained)*reduced;
        if norm(residual, "fro") <= threshold
            basis = basis(:, retained);
            return
        end
    end
    basis = zeros(size(matrix, 1), 0);
    reduced = matrix;
end

function [spatial, temporal] = truncateFactors(left, values, right, threshold)
    tails = [sqrt(flip(cumsum(flip(values.^2)))); 0];
    count = find(tails(2:end) <= threshold, 1);
    spatial = left(:, 1:count);
    temporal = values(1:count).*right(:, 1:count)';
end
