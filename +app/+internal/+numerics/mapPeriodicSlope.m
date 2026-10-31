function bounds = mapPeriodicSlope(envelope, domainSize, position)
% MAPPERIODICSLOPE Bound four mirror images over complete observation cells.
    arguments
        envelope (:, :) double
        domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        position (1, 2) double {mustBeReal, mustBeFinite}
    end
    count = size(envelope, 1);
    assert(count == size(envelope, 2), "RippleSimulator:SlopeEnvelopeShape", ...
        "The periodic slope envelope must be square.");
    step = 2*domainSize/count;
    cells = 101;
    coordinates = linspace(-domainSize/2, domainSize/2, cells+1);
    [left, bottom] = meshgrid(coordinates(1:end-1));
    bounds = zeros(cells);
    for signX = [-1, 1]
        for signY = [-1, 1]
            column = mod(floor((left+domainSize/2+signX*(position(1)+domainSize/2))/step), count)+1;
            row = mod(floor((bottom+domainSize/2+signY*(position(2)+domainSize/2))/step), count)+1;
            bounds = bounds+envelope(sub2ind([count, count], row, column));
        end
    end
end
