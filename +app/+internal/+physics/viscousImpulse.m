function [elevation, velocity, release] = viscousImpulse(viscosityRatio, age, quadratureOrder)
% VISCOUSIMPULSE Evaluate the linear deep-water Newtonian impulse response.
%   [H, V, R] = VISCOUSIMPULSE(EPSILON, AGE, ORDER) evaluates a unit initial
%   vertical-velocity response H, its time derivative V, and a unit released
%   elevation R with initially quiescent fluid. EPSILON = nu*k^2/omega0 and
%   AGE = omega0*t are dimensionless. EPSILON is a column vector; AGE has one
%   row per mode. ORDER controls the branch-cut quadrature, default 64.
%
%   The Laplace transfer function for H is
%       1 / ((s + 2*epsilon)^2 + 1 - 4*epsilon^2*sqrt(1 + s/epsilon)).
%   The response includes the viscous pole pair and transient vorticity.
%   The transfer function follows from the linearized incompressible
%   Navier–Stokes and continuity equations subject to the linearized
%   kinematic and dynamic free-surface boundary conditions.
%   The clean interface has zero tangential stress. The normal stress
%   balance includes gravity, surface tension, and applied pressure.
%   Infinite depth is assumed; bottom friction and gas motion are excluded.
    arguments
        viscosityRatio (:, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative, ...
            mustBeLessThanOrEqual(viscosityRatio, 1e3)}
        age (:, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        quadratureOrder (1, 1) {mustBeNumeric, mustBeInteger, ...
            mustBeGreaterThanOrEqual(quadratureOrder, 16), ...
            mustBeLessThanOrEqual(quadratureOrder, 512)} = 64
    end
    assert(size(age, 1) == numel(viscosityRatio), "RippleSimulator:ModeTimeShape", ...
        "Age must have one row for each viscosity ratio.");
    viscosityRatio = double(viscosityRatio);
    age = double(age);
    [nodes, weights] = app.internal.numerics.gaussLegendre(quadratureOrder);
    angle = (nodes+1)*pi/4;
    elevation = zeros(size(age));
    if nargout > 1
        velocity = zeros(size(age));
    end
    if nargout > 2
        release = zeros(size(age));
    end
    positive = viscosityRatio > 0;
    polePairs = complex(zeros(2, numel(viscosityRatio)));
    poleCoefficients = zeros(2, numel(viscosityRatio));
    [polePairs(:, positive), poleCoefficients(:, positive)] = ...
        app.internal.physics.viscousPoles(viscosityRatio(positive));
    % Bound the quadrature decay array to 64 MiB per modal block.
    maxDecayBytes = 64*1024^2;
    bytesPerMode = 8*quadratureOrder*max(size(age, 2), 1);
    blockSize = max(1, min(64, floor(maxDecayBytes/bytesPerMode)));
    positiveIndices = find(positive);
    for first = 1:blockSize:numel(positiveIndices)
        indices = positiveIndices(first:min(first+blockSize-1, numel(positiveIndices)));
        branch = evaluateBranch(viscosityRatio(indices), age(indices, :), ...
            angle, weights, max(nargout, 1));
        elevation(indices, :) = -branch(:, :, 1);
        if nargout > 1
            velocity(indices, :) = branch(:, :, 2);
        end
        if nargout > 2
            release(indices, :) = -branch(:, :, 3);
        end
        poles = polePairs(:, indices);
        coefficients = poleCoefficients(:, indices);
        times = age(indices, :);
        if nargout > 2
            [poleElevation, poleVelocity, poleRelease] = evaluatePoles(poles, coefficients, times);
        elseif nargout > 1
            [poleElevation, poleVelocity] = evaluatePoles(poles, coefficients, times);
        else
            poleElevation = evaluatePoles(poles, coefficients, times);
        end
        elevation(indices, :) = elevation(indices, :)+real(poleElevation);
        if nargout > 1
            velocity(indices, :) = velocity(indices, :)+real(poleVelocity);
        end
        if nargout > 2
            release(indices, :) = release(indices, :)+real(poleRelease);
        end
    end
    elevation(~positive, :) = sin(age(~positive, :));
    if nargout > 1
        velocity(~positive, :) = cos(age(~positive, :));
    end
    if nargout > 2
        release(~positive, :) = cos(age(~positive, :));
    end
    % Initial conditions are exact; quadrature is needed only at positive age.
    initial = age == 0;
    elevation(initial) = 0;
    if nargout > 1
        velocity(initial) = 1;
    end
    if nargout > 2
        release(initial) = 1;
    end
end

function branch = evaluateBranch(parameters, ages, angle, weights, outputCount)
    scale = sqrt(max(parameters', 1));
    variable = tan(angle)*scale;
    jacobian = pi/4./cos(angle).^2*scale;
    weight = 8*parameters'.^1.5.*variable.^2 ...
        ./(pi*(((parameters'-variable.^2).^2+1).^2+16*parameters'.^3.*variable.^2));
    rate = parameters'+variable.^2;
    measure = weights.*jacobian.*weight;
    moments = zeros(outputCount, numel(angle), numel(parameters));
    moments(1, :, :) = permute(measure, [3, 1, 2]);
    if outputCount > 1
        moments(2, :, :) = permute(measure.*rate, [3, 1, 2]);
    end
    if outputCount > 2
        moments(3, :, :) = permute(measure./rate, [3, 1, 2]);
    end
    branch = zeros(size(ages, 1), size(ages, 2), outputCount);
    % Exponentials below -746 round to zero in double precision.
    active = any(min(rate, [], 1)'.*ages <= 746, 1);
    if any(active)
        decay = exp(-permute(rate, [1, 3, 2]).*permute(ages(:, active), [3, 2, 1]));
        branch(:, active, :) = permute(pagemtimes(moments, decay), [3, 2, 1]);
    end
end

function [elevation, velocity, release] = evaluatePoles(poles, coefficients, times)
    evenCoefficient = coefficients(1, :).';
    oddCoefficient = coefficients(2, :).';
    meanPole = real(sum(poles, 1).'/2);
    separation = (poles(1, :)-poles(2, :)).'/2;
    realModes = imag(separation) == 0;
    evenPart = zeros(size(times));
    oddPart = evenPart;
    if any(realModes)
        [evenPart(realModes, :), oddPart(realModes, :)] = ...
            realPoleParts(poles(:, realModes), meanPole(realModes), separation(realModes), times(realModes, :));
    end
    if any(~realModes)
        separation(~realModes) = 1i*imag(separation(~realModes));
        [evenPart(~realModes, :), oddPart(~realModes, :)] = ...
            oscillatoryPoleParts(meanPole(~realModes), imag(separation(~realModes)), times(~realModes, :));
    end
    elevation = evenCoefficient.*evenPart+oddCoefficient.*oddPart;
    if nargout > 1
        velocity = (meanPole.*evenCoefficient+oddCoefficient).*evenPart ...
            +(meanPole.*oddCoefficient+separation.^2.*evenCoefficient).*oddPart;
    end
    if nargout > 2
        release = ((oddCoefficient-meanPole.*evenCoefficient).*evenPart ...
            +(separation.^2.*evenCoefficient-meanPole.*oddCoefficient).*oddPart) ...
            ./(meanPole.^2-separation.^2);
    end
end

function [evenPart, oddPart] = realPoleParts(poles, meanPole, separation, times)
    first = exp(poles(1, :).'.*times);
    second = exp(poles(2, :).'.*times);
    evenPart = (first+second)/2;
    oddPart = times.*exp(meanPole.*times);
    phase = separation.*times;
    resolved = abs(phase) > 1e-4;
    denominator = 2*separation+zeros(size(times));
    oddPart(resolved) = first(resolved).*(-expm1(-2*phase(resolved)))./denominator(resolved);
    smallArgument = phase(~resolved);
    oddPart(~resolved) = oddPart(~resolved).*(1+smallArgument.^2/6+smallArgument.^4/120);
end

function [evenPart, oddPart] = oscillatoryPoleParts(meanPole, frequency, times)
    decay = exp(meanPole.*times);
    phase = frequency.*times;
    evenPart = decay.*cos(phase);
    oddPart = times.*decay;
    resolved = abs(phase) > 1e-4;
    denominator = frequency+zeros(size(times));
    oddPart(resolved) = decay(resolved).*sin(phase(resolved))./denominator(resolved);
    smallArgument = phase(~resolved);
    oddPart(~resolved) = oddPart(~resolved).*(1-smallArgument.^2/6+smallArgument.^4/120);
end
