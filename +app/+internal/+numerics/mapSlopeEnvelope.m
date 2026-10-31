function mapping = mapSlopeEnvelope(envelope, domainSize, position, cells)
% MAPSLOPEENVELOPE Locate precomputed radial or periodic bounds for Cartesian cells.
    arguments
        envelope (1, 1) struct
        domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        position (1, 2) double {mustBeReal, mustBeFinite}
        cells (1, 1) double {mustBeInteger, mustBePositive}
    end
    edges = linspace(-domainSize/2, domainSize/2, cells+1);
    [left, bottom] = meshgrid(edges(1:end-1));
    width = (edges(2)-edges(1))*(1+32*eps);
    if envelope.Kind == "Radial"
        near = hypot(max(max(left-position(1), position(1)-left-width), 0), ...
            max(max(bottom-position(2), position(2)-bottom-width), 0));
        far = hypot(max(abs(left-position(1)), abs(left+width-position(1))), ...
            max(abs(bottom-position(2)), abs(bottom+width-position(2))));
        count = size(envelope.Bounds, 1);
        assert(all(far <= count*envelope.SpatialStep*(1+64*eps), "all"), ...
            "RippleSimulator:ResponseRadiusCoverage", "The loading cells exceed the tabulated radial coverage.");
        first = min(count, floor(near(:)/envelope.SpatialStep)+1);
        last = min(count, floor(far(:)/envelope.SpatialStep)+1);
        level = floor(log2(last-first+1));
        stride = count*size(envelope.Bounds, 2);
        [pairs, ~, rows] = unique([first+level*stride, last-2.^level+1+level*stride], "rows");
        mapping = struct(First=pairs(:, 1), Last=pairs(:, 2), Rows=rows, Operator=[]);
        return
    end
    count = 2*size(envelope.Bounds, 1);
    indices = zeros(cells^2, 4, 2);
    firstX = zeros(cells^2, 4);
    firstY = firstX;
    spanX = firstX;
    spanY = firstX;
    image = 0;
    for signX = [-1, 1]
        for signY = [-1, 1]
            image = image+1;
            x = (left+domainSize/2+signX*(position(1)+domainSize/2))/envelope.SpatialStep;
            y = (bottom+domainSize/2+signY*(position(2)+domainSize/2))/envelope.SpatialStep;
            firstX(:, image) = floor(x(:));
            firstY(:, image) = floor(y(:));
            spanX(:, image) = floor(x(:)+width/envelope.SpatialStep)-floor(x(:));
            spanY(:, image) = floor(y(:)+width/envelope.SpatialStep)-floor(y(:));
            column = mod(floor((left+width/2+domainSize/2 ...
                +signX*(position(1)+domainSize/2))/envelope.SpatialStep), count)+1;
            row = mod(floor((bottom+width/2+domainSize/2 ...
                +signY*(position(2)+domainSize/2))/envelope.SpatialStep), count)+1;
            foldedX = min(column, count-column+1);
            foldedY = min(row, count-row+1);
            indices(:, image, 1) = sub2ind([count/2, count/2], foldedY(:), foldedX(:));
            indices(:, image, 2) = sub2ind([count/2, count/2], foldedX(:), foldedY(:));
        end
    end
    mapping = struct(Indices=indices, FirstX=firstX, FirstY=firstY, ...
        SpanX=spanX, SpanY=spanY);
end
