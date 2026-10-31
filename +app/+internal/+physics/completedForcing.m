function value = completedForcing(pole)
% COMPLETEDFORCING Return the completed four-cycle forcing multiplier.
%   VALUE multiplies exp(POLE*(t-8*pi)) after the pressure forcing ends.
%   It is evaluated away from the removable resonances at imaginary forcing
%   frequencies; the supported contour and diffusive rates have negative
%   real parts.
    arguments
        pole {mustBeNumeric, mustBeFinite}
    end
    frequencies = [1, 1.25, 0.75];
    coefficients = [0.5, -0.25, -0.25];
    value = zeros(size(pole), "like", pole);
    for index = 1:3
        frequency = frequencies(index);
        value = value + coefficients(index)*frequency./(pole.^2 + frequency^2);
    end
    value = expm1(pole*(8*pi)).*value;
end
