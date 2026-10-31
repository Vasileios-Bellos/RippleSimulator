function [elevation, velocity] = wavemaker(viscosityRatio, age, frequencyRatio, quadratureOrder)
% WAVEMAKER Evaluate a four-cycle local pressure excitation.
%   [H, V] = WAVEMAKER(EPSILON, AGE, RATIO, ORDER) convolves the full viscous
%   impulse response with RATIO*sin(RATIO*t)*sin(RATIO*t/8)^2 over four
%   forcing periods. AGE is dimensionless modal time, and RATIO is the
%   forcing frequency divided by the inviscid modal frequency. EPSILON and
%   RATIO are columns; AGE has one row per mode. V differentiates H by AGE.
%   This source is a finite-duration wavemaker, not an instantaneous impact.
    arguments
        viscosityRatio (:, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative, ...
            mustBeLessThanOrEqual(viscosityRatio, 1e3)}
        age (:, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        frequencyRatio (:, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
        quadratureOrder (1, 1) {mustBeNumeric, mustBeInteger, ...
            mustBeGreaterThanOrEqual(quadratureOrder, 16), ...
            mustBeLessThanOrEqual(quadratureOrder, 512)} = 64
    end
    assert(size(age, 1) == numel(viscosityRatio) && numel(frequencyRatio) == numel(viscosityRatio), ...
        "RippleSimulator:ModeTimeShape", "Age and forcing ratio must match the number of modes.");
    [nodes, weights] = app.internal.numerics.gaussLegendre(quadratureOrder);
    angle = (nodes + 1)*pi/4;
    positive = viscosityRatio > 0;
    polePairs = complex(zeros(2, numel(viscosityRatio)));
    poleCoefficients = zeros(2, numel(viscosityRatio));
    [polePairs(:, positive), poleCoefficients(:, positive)] = ...
        app.internal.physics.viscousPoles(viscosityRatio(positive));
    polePairs(:, ~positive) = repmat([1i; -1i], 1, nnz(~positive));
    poleCoefficients(2, ~positive) = 1;
    if nargout > 1
        [elevation, velocity] = convolvePoleModes(polePairs, poleCoefficients, double(frequencyRatio), double(age));
    else
        elevation = convolvePoleModes(polePairs, poleCoefficients, double(frequencyRatio), double(age));
    end
    for modeIndex = reshape(find(positive), 1, [])
        parameter = double(viscosityRatio(modeIndex));
        ratio = double(frequencyRatio(modeIndex));
        times = double(age(modeIndex, :));
        frequencies = ratio*[1, 1.25, 0.75];
        factors = ratio*[0.5, -0.25, -0.25];
        duration = 8*pi/ratio;
        scale = sqrt(max(parameter, 1));
        variable = scale*tan(angle);
        jacobian = scale./cos(angle).^2*pi/4;
        measure = weights.*jacobian.*(8*parameter^1.5*variable.^2 ...
            ./(pi*(((parameter - variable.^2).^2 + 1).^2 + 16*parameter^3*variable.^2)));
        rate = -(parameter + variable.^2);
        if nargout > 1
            [branchElevation, branchVelocity] = convolveBranch(rate, measure, frequencies, factors, times, duration);
            velocity(modeIndex, :) = velocity(modeIndex, :)-branchVelocity;
        else
            branchElevation = convolveBranch(rate, measure, frequencies, factors, times, duration);
        end
        elevation(modeIndex, :) = elevation(modeIndex, :)-branchElevation;
    end
    elevation(age == 0) = 0;
    if nargout > 1
        velocity(age == 0) = 0;
    end
end

function [elevation, velocity] = convolvePoleModes(poles, coefficients, ratios, times)
% CONVOLVEPOLEMODES Evaluate independent modal convolutions in bounded arrays.
    elevation = zeros(size(times));
    if nargout > 1
        velocity = elevation;
    end
    separation = poles(1, :)-poles(2, :);
    resolved = abs(separation) > 1e-3*max(1, max(abs(poles), [], 1));
    oscillatory = imag(poles(1, :)) ~= 0;
    blockSize = min(64, max(1, floor(65536/max(1, size(times, 2)))));
    for first = 1:blockSize:size(times, 1)
        block = first:min(first+blockSize-1, size(times, 1));
        selected = block(resolved(block) & oscillatory(block));
        if ~isempty(selected)
            pole = reshape(poles(1, selected), [], 1);
            response = convolveModeForcing(pole, ratios(selected), times(selected, :));
            even = reshape(coefficients(1, selected), [], 1);
            odd = reshape(coefficients(2, selected), [], 1);
            elevation(selected, :) = even.*real(response)+odd.*imag(response)./imag(pole);
            if nargout > 1
                derivative = pole.*response;
                velocity(selected, :) = even.*real(derivative)+odd.*imag(derivative)./imag(pole);
            end
        end
        selected = block(resolved(block) & ~oscillatory(block));
        if ~isempty(selected)
            firstPole = reshape(poles(1, selected), [], 1);
            secondPole = reshape(poles(2, selected), [], 1);
            firstResponse = convolveModeForcing(firstPole, ratios(selected), times(selected, :));
            secondResponse = convolveModeForcing(secondPole, ratios(selected), times(selected, :));
            even = reshape(coefficients(1, selected), [], 1);
            odd = reshape(coefficients(2, selected), [], 1);
            difference = firstPole-secondPole;
            elevation(selected, :) = real(even.*(firstResponse+secondResponse)/2 ...
                + odd.*((firstResponse-secondResponse)./difference));
            if nargout > 1
                firstDerivative = firstPole.*firstResponse;
                secondDerivative = secondPole.*secondResponse;
                velocity(selected, :) = real(even.*(firstDerivative+secondDerivative)/2 ...
                    + odd.*((firstDerivative-secondDerivative)./difference));
            end
        end
    end
    for index = reshape(find(~resolved), 1, [])
        ratio = ratios(index);
        if nargout > 1
            [value, derivative] = convolvePoles(poles(:, index), coefficients(:, index), ...
                ratio*[1, 1.25, 0.75], ratio*[0.5, -0.25, -0.25], times(index, :), 8*pi/ratio);
            velocity(index, :) = real(derivative);
        else
            value = convolvePoles(poles(:, index), coefficients(:, index), ...
                ratio*[1, 1.25, 0.75], ratio*[0.5, -0.25, -0.25], times(index, :), 8*pi/ratio);
        end
        elevation(index, :) = real(value);
    end
end

function value = convolveModeForcing(poles, ratios, times)
    duration = 8*pi./ratios;
    activeColumns = any(times <= duration, 1);
    value = complex(zeros(size(times)));
    if any(activeColumns)
        ages = min(times(:, activeColumns), duration);
        active = convolveModeActive(poles, ratios, ages);
        value(:, activeColumns) = active.*exp(poles.*(times(:, activeColumns)-ages));
    end
    if any(~activeColumns)
        completed = convolveModeActive(poles, ratios, duration);
        value(:, ~activeColumns) = completed.*exp(poles.*(times(:, ~activeColumns)-duration));
    end
end

function value = convolveModeActive(poles, ratios, times)
    value = complex(zeros(size(times)));
    exponential = exp(poles.*times);
    harmonics = [1, 1.25, 0.75];
    weights = [0.5, -0.25, -0.25];
    for index = 1:numel(harmonics)
        frequency = ratios*harmonics(index);
        phase = exp(1i*frequency.*times);
        positive = exponentialIntegral(poles, frequency, times, exponential, phase, times);
        negative = exponentialIntegral(poles, -frequency, times, exponential, conj(phase), times);
        value = value + (ratios*weights(index)).*(positive-negative)/(2i);
    end
end

function [elevation, velocity] = convolvePoles(poles, coefficients, frequencies, factors, times, duration)
    separation = poles(1)-poles(2);
    resolved = abs(separation) > 1e-3*max(1, max(abs(poles)));
    if imag(poles(1)) ~= 0 && resolved
        response = convolveForcing(poles(1), frequencies, factors, times, duration);
        elevation = coefficients(1)*real(response)+coefficients(2)*imag(response)/imag(poles(1));
        if nargout > 1
            derivative = poles(1)*response;
            velocity = coefficients(1)*real(derivative) ...
                + coefficients(2)*imag(derivative)/imag(poles(1));
        end
        return
    end
    responses = convolveForcing(poles, frequencies, factors, times, duration);
    if resolved
        oddPart = (responses(1, :) - responses(2, :))/separation;
        if nargout > 1
            oddVelocity = (poles(1)*responses(1, :) - poles(2)*responses(2, :))/separation;
        end
    else
        [nodes, weights] = app.internal.numerics.gaussLegendre(8);
        samples = poles(2) + (nodes + 1)*separation/2;
        [values, derivatives] = convolveForcing(samples, frequencies, factors, times, duration);
        oddPart = weights'*derivatives/2;
        if nargout > 1
            oddVelocity = weights'*(values + samples.*derivatives)/2;
        end
    end
    elevation = coefficients(1)*sum(responses, 1)/2 + coefficients(2)*oddPart;
    if nargout > 1
        velocity = coefficients(1)*sum(poles.*responses, 1)/2 + coefficients(2)*oddVelocity;
    end
end

function [elevation, velocity] = convolveBranch(pole, measure, frequencies, factors, times, duration)
% CONVOLVEBRANCH Integrate quadrature weights before evaluating the forcing harmonics.
    elevation = zeros(size(times));
    if nargout > 1
        velocity = elevation;
    end
    active = times <= duration;
    % Completed columns below the double-precision exponential range are zero.
    remaining = times > duration & max(pole)*(times-duration) >= -746;
    if ~any(active) && ~any(remaining)
        return
    end
    cosineWeights = factors.*frequencies./(pole.^2+frequencies.^2);
    sineWeights = factors.*pole./(pole.^2+frequencies.^2);
    exponentialWeights = sum(cosineWeights, 2);
    if nargout > 1
        moments = [measure, measure.*pole]';
    else
        moments = measure';
    end
    if any(active)
        ages = reshape(times(active), 1, []);
        exponential = exp(pole.*ages);
        cosine = cos(frequencies'.*ages);
        sine = sin(frequencies'.*ages);
        values = (moments.*exponentialWeights')*exponential ...
            -(moments*cosineWeights)*cosine-(moments*sineWeights)*sine;
        elevation(active) = values(1, :);
        if nargout > 1
            velocity(active) = values(2, :);
        end
    end
    if any(remaining)
        decay = exp(pole.*reshape(times(remaining)-duration, 1, []));
        completed = expm1(pole*duration).*exponentialWeights;
        values = (moments.*completed')*decay;
        elevation(remaining) = values(1, :);
        if nargout > 1
            velocity(remaining) = values(2, :);
        end
    end
end

function [value, derivative] = convolveForcing(pole, frequencies, factors, times, duration)
    active = times <= duration;
    value = complex(zeros(numel(pole), numel(times)));
    if nargout > 1
        derivative = value;
    end
    if any(active)
        if nargout > 1
            [value(:, active), derivative(:, active)] = convolveActive(pole, frequencies, factors, times(active));
        else
            value(:, active) = convolveActive(pole, frequencies, factors, times(active));
        end
    end
    if any(~active)
        elapsed = times(~active) - duration;
        decay = exp(pole*elapsed);
        if nargout > 1
            [completed, completedDerivative] = convolveActive(pole, frequencies, factors, duration);
            derivative(:, ~active) = decay.*(completedDerivative + elapsed.*completed);
        else
            completed = convolveActive(pole, frequencies, factors, duration);
        end
        value(:, ~active) = decay.*completed;
    end
end

function [value, derivative] = convolveActive(pole, frequencies, factors, times)
    value = complex(zeros(numel(pole), numel(times)));
    exponential = exp(pole*times);
    expandedTimes = repmat(times, numel(pole), 1);
    if nargout > 1
        derivative = value;
    end
    for index = 1:numel(frequencies)
        frequency = frequencies(index);
        phase = exp(1i*frequency*times);
        if nargout > 1
            [positive, positiveDerivative] = exponentialIntegral( ...
                pole, frequency, times, exponential, phase, expandedTimes);
            [negative, negativeDerivative] = exponentialIntegral( ...
                pole, -frequency, times, exponential, conj(phase), expandedTimes);
            derivative = derivative + factors(index)*(positiveDerivative - negativeDerivative)/(2i);
        else
            positive = exponentialIntegral(pole, frequency, times, exponential, phase, expandedTimes);
            negative = exponentialIntegral(pole, -frequency, times, exponential, conj(phase), expandedTimes);
        end
        value = value + factors(index)*(positive - negative)/(2i);
    end
end

function [value, derivative] = exponentialIntegral(pole, frequency, times, exponential, phase, expandedTimes)
    difference = 1i*frequency - pole;
    argument = difference.*times;
    value = (phase - exponential)./difference;
    if nargout > 1
        derivative = (value - times.*exponential)./difference;
    end
    near = abs(argument) < 1e-3;
    small = argument(near);
    value(near) = exponential(near).*expandedTimes(near) ...
        .*(1 + small/2 + small.^2/6 + small.^3/24 + small.^4/120);
    if nargout > 1
        derivative(near) = exponential(near).*expandedTimes(near).^2 ...
            .*(1/2 + small/6 + small.^2/24 + small.^3/120 + small.^4/720);
    end
end
