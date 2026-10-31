function bounds = realPoleEnvelope(fluid, source, ages, cutoff, order)
% REALPOLEENVELOPE Bound the future high-wavenumber pole-pair response.
%   BOUNDS contains dimensionless elevation, vertical speed, and radial slope
%   bounds over cutoff <= k*s <= 8. AGES are source-frequency-scaled times
%   since an impulse or since the end of a wavemaker. The bound is global
%   in horizontal position and remains finite when the viscous poles coalesce.
%   The branch response and spectrum beyond eight are accounted for separately.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
        ages (1, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        cutoff (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive, ...
            mustBeLessThanOrEqual(cutoff, 8)}
        order (1, 1) {mustBeNumeric, mustBeInteger, mustBeGreaterThanOrEqual(order, 64), ...
            mustBeLessThanOrEqual(order, 512)} = 256
    end
    bounds = zeros(numel(ages), 3);
    if cutoff == 8
        return
    end
    [nodes, weights] = app.internal.numerics.gaussLegendre(order);
    interval = sqrt(8) - sqrt(cutoff);
    variable = sqrt(cutoff) + (nodes + 1)*interval/2;
    q = variable.^2;
    measure = weights*interval.*variable;
    frequency = app.internal.physics.dispersion(source.Wavenumber, fluid);
    relativeFrequency = app.internal.physics.dispersion(q*source.Wavenumber, fluid)/frequency;
    parameters = fluid.KinematicViscosity*(q*source.Wavenumber).^2./(relativeFrequency*frequency);
    [polePairs, poleCoefficients] = app.internal.physics.viscousPoles(parameters);
    for index = 1:numel(q)
        poles = polePairs(:, index);
        coefficients = poleCoefficients(:, index);
        decay = -max(real(poles));
        assert(decay > 0, "RippleSimulator:PoleDecay", "The real-axis poles must decay.");
        separation = (poles(1) - poles(2))/2;
        meanPole = sum(poles)/2;
        time = relativeFrequency(index)*double(ages);
        exponential = exp(-decay*time);
        maximumTime = max(time, 1/decay);
        odd = maximumTime.*exp(-decay*maximumTime);
        if separation ~= 0
            odd = min(odd, exponential/abs(separation));
        end
        elevation = abs(coefficients(1))*exponential + abs(coefficients(2))*odd;
        velocity = abs(meanPole*coefficients(1) + coefficients(2))*exponential ...
            + abs(separation^2*coefficients(1) + meanPole*coefficients(2))*odd;
        weight = measure(index)*q(index)^2*exp(-q(index)^2/2);
        bounds(:, 1) = bounds(:, 1) + weight/relativeFrequency(index)*elevation';
        bounds(:, 2) = bounds(:, 2) + weight*velocity';
        bounds(:, 3) = bounds(:, 3) + weight/relativeFrequency(index)*q(index)*elevation';
    end
    if source.Mode == "Wavemaker"
        bounds = 8*bounds;
    end
end
