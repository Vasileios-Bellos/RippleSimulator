classdef (Sealed) ModalKernel
    % MODALKERNEL Store the full viscous impulse response for discrete modes.
    %   The physical pole pair and branch quadrature are calculated once. Modal
    %   time is omega0*t; velocity differentiates elevation with respect to it.

    properties (SetAccess = immutable)
        ViscosityRatio (:, 1) double
        Poles (:, 2) double
        Coefficients (:, 2) double
        BranchRate (:, :) double
        BranchMeasure (:, :) double
    end

    methods
        function obj = ModalKernel(parameters, order)
            arguments
                parameters (:, 1) double {mustBeReal, mustBeFinite, mustBePositive, ...
                    mustBeLessThanOrEqual(parameters, 1e3)}
                order (1, 1) double {mustBeInteger, mustBeGreaterThanOrEqual(order, 16), ...
                    mustBeLessThanOrEqual(order, 512)} = 128
            end
            obj.ViscosityRatio = parameters;
            [poles, coefficients] = app.internal.physics.viscousPoles(parameters);
            obj.Poles = poles.';
            obj.Coefficients = coefficients.';
            [nodes, weights] = app.internal.numerics.gaussLegendre(order);
            angle = (nodes' + 1)*pi/4;
            scale = sqrt(max(parameters, 1));
            variable = scale.*tan(angle);
            jacobian = scale./cos(angle).^2*pi/4;
            weight = 8*parameters.^1.5.*variable.^2 ...
                ./(pi*(((parameters - variable.^2).^2 + 1).^2 + 16*parameters.^3.*variable.^2));
            obj.BranchRate = parameters + variable.^2;
            obj.BranchMeasure = weights'.*jacobian.*weight;
        end

        function [elevation, velocity] = sample(obj, age)
        % SAMPLE Evaluate each mode at its dimensionless age.
            arguments
                obj (1, 1) app.internal.physics.ModalKernel
                age (:, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(numel(age) == numel(obj.ViscosityRatio), "RippleSimulator:ModeTimeShape", ...
                "Age must contain one value per mode.");
            meanPole = sum(obj.Poles, 2)/2;
            separation = (obj.Poles(:, 1) - obj.Poles(:, 2))/2;
            [even, odd] = obj.poleParts(age);
            evenCoefficient = obj.Coefficients(:, 1);
            oddCoefficient = obj.Coefficients(:, 2);
            decay = exp(-obj.BranchRate.*age);
            elevation = real(evenCoefficient.*even + oddCoefficient.*odd) ...
                - sum(obj.BranchMeasure.*decay, 2);
            velocity = real((meanPole.*evenCoefficient + oddCoefficient).*even ...
                + (separation.^2.*evenCoefficient + meanPole.*oddCoefficient).*odd) ...
                + sum(obj.BranchMeasure.*obj.BranchRate.*decay, 2);
            elevation(age == 0) = 0;
            velocity(age == 0) = 1;
        end

        function [even, odd] = poleParts(obj, age)
        % POLEPARTS Evaluate the paired exponential basis without pole separation loss.
            arguments
                obj (1, 1) app.internal.physics.ModalKernel
                age (:, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(numel(age) == numel(obj.ViscosityRatio), "RippleSimulator:ModeTimeShape", ...
                "Age must contain one value per mode.");
            meanPole = sum(obj.Poles, 2)/2;
            separation = (obj.Poles(:, 1) - obj.Poles(:, 2))/2;
            first = exp(obj.Poles(:, 1).*age);
            second = exp(obj.Poles(:, 2).*age);
            even = (first + second)/2;
            odd = age.*exp(meanPole.*age);
            resolved = abs(separation.*age) > 1e-4;
            odd(resolved) = first(resolved).*(-expm1(-2*separation(resolved).*age(resolved))) ...
                ./(2*separation(resolved));
            small = separation(~resolved).*age(~resolved);
            odd(~resolved) = odd(~resolved).*(1 + small.^2/6 + small.^4/120);
        end

        function [elevation, velocity] = futureBound(obj, age)
        % FUTUREBOUND Bound every later elevation and velocity for each impulse.
            arguments
                obj (1, 1) app.internal.physics.ModalKernel
                age (:, :) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(size(age, 1) == numel(obj.ViscosityRatio), "RippleSimulator:ModeTimeShape", ...
                "Each age column must contain one value per mode.");
            rate = -max(real(obj.Poles), [], 2);
            meanPole = sum(obj.Poles, 2)/2;
            separation = (obj.Poles(:, 1) - obj.Poles(:, 2))/2;
            exponential = exp(-rate.*age);
            peakTime = max(age, 1./rate);
            odd = min(peakTime.*exp(-rate.*peakTime), exponential./abs(separation));
            evenCoefficient = obj.Coefficients(:, 1);
            oddCoefficient = obj.Coefficients(:, 2);
            velocityEven = meanPole.*evenCoefficient + oddCoefficient;
            velocityOdd = separation.^2.*evenCoefficient + meanPole.*oddCoefficient;
            branchElevation = max(0, real(evenCoefficient));
            branchVelocity = max(0, real(1 - velocityEven));
            branchDecay = exp(-obj.ViscosityRatio.*age);
            elevation = abs(evenCoefficient).*exponential + abs(oddCoefficient).*odd + branchElevation.*branchDecay;
            velocity = abs(velocityEven).*exponential + abs(velocityOdd).*odd + branchVelocity.*branchDecay;
            % Passive modal energy independently bounds both responses by one.
            elevation = min(1, elevation)*(1 + 64*eps);
            if nargout > 1
                velocity = min(1, velocity)*(1 + 64*eps);
            end
        end
    end
end
