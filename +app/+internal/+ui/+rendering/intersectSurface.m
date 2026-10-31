function position = intersectSurface(ray, domainSize)
% INTERSECTSURFACE Intersect an axes pointer ray with the equilibrium surface plane.
%   Display coordinates span [-0.5, 0.5] in each horizontal direction.
%   Empty output indicates a parallel ray or an intersection outside the
%   physical domain. Surface elevation and observation grid density do not affect
%   the selected physical source position.

    arguments
        ray (2, 3) {mustBeNumeric, mustBeReal, mustBeFinite}
        domainSize (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
    end
    direction = double(ray(2, :) - ray(1, :));
    position = zeros(1, 0);
    if abs(direction(3)) <= eps*max(1, norm(direction))
        return
    end
    fraction = -double(ray(1, 3))/direction(3);
    intersection = double(ray(1, 1:2)) + fraction*direction(1:2);
    if all(abs(intersection) <= 0.5)
        position = intersection*double(domainSize);
    end
end
