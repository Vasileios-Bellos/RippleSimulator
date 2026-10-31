function bound = boundPreparedSlopes(records, originals, time, allowance, limit)
% BOUNDPREPAREDSLOPES Combine retained cell envelopes over the remaining motion.
    arguments
        records (1, :) struct
        originals (1, :) struct
        time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
        allowance (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
        limit (1, 1) double {mustBeReal, mustBePositive}
    end
    activeRecords = [records.Time]+[records.Duration] > time & [records.Strength] > 0;
    records = records(activeRecords);
    originals = originals(activeRecords);
    bound = allowance;
    if isempty(records)
        return
    end
    envelopes = [records.Envelope];
    horizon = max([records.Time]+[records.Duration]);
    count = ceil((horizon-time)/(min([envelopes.TimeScale])/16));
    coverage = arrayfun(@(envelope) envelope.Times(end), envelopes);
    if count > 4096 || any([records.Duration] > coverage*(1+32*eps))
        bound = Inf;
        return
    end
    for record = records
        allowance = allowance+record.Strength*record.Envelope.Allowance;
    end

    coarseTimes = linspace(time, horizon, ceil(count/2)+1);
    bound = boundIntervals(records, originals, coarseTimes, allowance, limit, true);
    if bound > limit
        times = linspace(time, horizon, count+1);
        bound = boundIntervals(records, originals, times, allowance, limit, false);
    end
end

function bound = boundIntervals(records, originals, times, allowance, limit, stopAboveLimit)
    envelopes = [records.Envelope];
    count = numel(times)-1;
    rounding = 1+32*numel(records)*double(eps("single"));
    budget = (limit-allowance)/rounding;
    periodic = originals(1).Envelope.Kind == "Periodic";
    if periodic
        mappings = {envelopes.Mapping};
    end
    bound = 0;
    cells = envelopes(1).Cells;
    batchColumns = max(1, floor(262144/cells^2));
    for first = 1:batchColumns:count
        columns = first:min(first+batchColumns-1, count);
        total = zeros(cells^2, numel(columns), "single");
        for record = records
            startAge = max(0, times(columns)-record.Time);
            endAge = max(0, times(columns+1)-record.Time);
            active = times(columns+1) > record.Time & startAge < record.Duration;
            if ~any(active)
                continue
            end
            envelope = record.Envelope;
            lower = discretize(min(startAge(active), envelope.Times(end)), envelope.Times);
            upper = discretize(min(endAge(active), envelope.Times(end)), envelope.Times);
            maximum = envelope.Bounds(:, lower);
            for offset = 1:max(upper-lower)
                maximum = max(maximum, envelope.Bounds(:, min(lower+offset, upper)));
            end
            scale = app.internal.responses.SettlingEnvelope.sample( ...
                startAge(active), envelope.TimeScale, record.Duration/envelope.TimeScale);
            total(:, active) = total(:, active)+single(record.Strength*scale).*maximum;
        end
        if periodic
            selected = find(total > budget);
            if ~isempty(selected)
                [rows, selectedColumns] = ind2sub(size(total), selected);
                total(selected) = app.internal.numerics.refinePeriodicSlopes(originals, mappings, times(columns), ...
                    times(columns+1), rows, selectedColumns);
            end
        end
        bound = max(bound, double(max(total, [], "all")));
        if stopAboveLimit && bound > budget
            bound = Inf;
            return
        end
    end
    bound = bound*rounding+allowance;
end
