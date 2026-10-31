classdef (Sealed) SettlingEnvelope
    % SETTLINGENVELOPE Apply a finite-duration approximation to a source response.
    %   The response is unchanged for the first 80 percent of its lifetime.
    %   A quintic envelope then smoothly restores the surface elevation and
    %   vertical velocity to zero. The envelope's first two time derivatives
    %   vanish at both ends of the settling interval. This finite-duration
    %   approximation is separate from viscous dissipation.

    methods (Static)
        function [value, derivative] = sample(age, timeScale, intervals)
        % SAMPLE Return the envelope and its derivative with respect to time.
            arguments
                age (1, :) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                timeScale (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                intervals (1, 1) double {mustBeReal, mustBePositive}
            end
            value = ones(size(age));
            derivative = zeros(size(age));
            if isinf(intervals)
                return
            end
            duration = intervals*timeScale;
            finished = age >= duration - 8*eps(duration);
            fading = ~finished & age > 0.8*duration;
            value(finished) = 0;
            fraction = (duration-age(fading))/(0.2*duration);
            value(fading) = fraction.^3.*(10-15*fraction+6*fraction.^2);
            derivative(fading) = -30*fraction.^2.*(1-fraction).^2/(0.2*duration);
        end
    end
end
