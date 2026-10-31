function values = refinePeriodicSlopes(records, mappings, first, last, rows, columns)
% REFINEPERIODICSLOPES Enclose signed gradient sums in selected space-time cells.
    total = zeros(numel(rows), 4, "single");
    absoluteTotal = zeros(numel(rows), 2);
    for source = 1:numel(records)
        record = records(source);
        startAge = max(0, first(columns)'-record.Time);
        endAge = max(0, last(columns)'-record.Time);
        active = last(columns)' > record.Time & startAge < record.Duration;
        if ~any(active)
            continue
        end
        envelope = record.Envelope;
        lower = discretize(min(startAge(active), envelope.Times(end)), envelope.Times);
        upper = discretize(min(endAge(active), envelope.Times(end)), envelope.Times);
        mapping = mappings{source};
        [minimum, maximum] = samplePeriodicCells(envelope, mapping, rows(active), lower, upper);
        absoluteImages = reshape(sum(reshape(double(max(abs(minimum), abs(maximum))), [], 4, 2), 2), [], 2);
        minimum = reshape(sum(reshape(minimum, [], 4, 2), 2), [], 2);
        maximum = reshape(sum(reshape(maximum, [], 4, 2), 2), [], 2);
        periods = record.Duration/envelope.TimeScale;
        maximumScale = single(app.internal.responses.SettlingEnvelope.sample( ...
            startAge(active)', envelope.TimeScale, periods)');
        minimumScale = single(app.internal.responses.SettlingEnvelope.sample( ...
            endAge(active)', envelope.TimeScale, periods)');
        absoluteTotal(active, :) = absoluteTotal(active, :) ...
            +record.Strength*double(maximumScale).*absoluteImages;
        minimum = min(minimum.*maximumScale, minimum.*minimumScale);
        maximum = max(maximum.*maximumScale, maximum.*minimumScale);
        total(active, :) = total(active, :)+single(record.Strength) ...
            *[minimum(:, 1), maximum(:, 1), minimum(:, 2), maximum(:, 2)];
    end
    operations = 16*numel(records)+8;
    roundoff = operations*double(eps("single"))/(1-operations*double(eps("single")));
    componentBounds = [double(max(abs(total(:, 1)), abs(total(:, 2)))), ...
        double(max(abs(total(:, 3)), abs(total(:, 4))))]+roundoff*absoluteTotal;
    values = single(hypot(componentBounds(:, 1), componentBounds(:, 2)))*(1+eps("single"));
end

function [minimum, maximum] = samplePeriodicCells(envelope, mapping, rows, lower, upper)
    side = size(envelope.Bounds, 1);
    count = side^2;
    plane = count*(numel(envelope.Times)-1);
    firstX = mapping.FirstX(rows, :);
    firstY = mapping.FirstY(rows, :);
    spanX = mapping.SpanX(rows, :);
    spanY = mapping.SpanY(rows, :);
    minimum = inf(numel(rows), 8, "single");
    maximum = -minimum;
    for dx = 0:max(spanX, [], "all")
        column = mod(firstX+min(dx, spanX), 2*side)+1;
        foldedX = min(column, 2*side-column+1);
        for dy = 0:max(spanY, [], "all")
            row = mod(firstY+min(dy, spanY), 2*side)+1;
            foldedY = min(row, 2*side-row+1);
            indices = [foldedY+(foldedX-1)*side, foldedX+(foldedY-1)*side];
            negative = [column > side, row > side];
            for offset = 0:max(upper-lower)
                current = indices+(min(lower+offset, upper)-1)*count;
                left = envelope.Bounds(current);
                right = envelope.Bounds(current+plane);
                temporary = left(negative);
                left(negative) = -right(negative);
                right(negative) = -temporary;
                minimum = min(minimum, left);
                maximum = max(maximum, right);
            end
        end
    end
end
