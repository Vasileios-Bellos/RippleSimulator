function bound = boundScheduledSlopes(records, domainSize, time, allowance, limit, options)
% BOUNDSCHEDULEDSLOPES Enclose a scheduled wave field throughout its remaining motion.
%   Each record supplies a precomputed gradient envelope, physical start time,
%   position, pressure strength, and finite lifetime. The bounds cover complete
%   spatial and temporal cells when checking whether additional sources satisfy
%   the surface-slope limit.
    arguments
        records (1, :) struct
        domainSize (1, 1) double {mustBeReal, mustBePositive, mustBeFinite}
        time (1, 1) double {mustBeReal, mustBeNonnegative, mustBeFinite}
        allowance (1, 1) double {mustBeReal, mustBeNonnegative, mustBeFinite} = 0
        limit (1, 1) double {mustBeReal, mustBePositive} = Inf
        options.TimeSubdivisions (1, 1) double {mustBeInteger, mustBePositive} = 16
    end
    bound = allowance;
    if isempty(records)
        return
    end
    if any(~isfinite([records.Time])) || any(~isfinite([records.Duration])) ...
            || any(~isfinite(vertcat(records.Position)), "all")
        bound = Inf;
        return
    end
    records = records([records.Time]+[records.Duration] > time & [records.Strength] > 0);
    if isempty(records)
        return
    end
    envelopes = [records.Envelope];
    coverage = arrayfun(@(record) record.Envelope.Times(end), records);
    if any([records.Duration] > coverage*(1+32*eps))
        bound = Inf;
        return
    end
    horizon = max([records.Time]+[records.Duration]);
    count = ceil((horizon-time)/(min([envelopes.TimeScale])/options.TimeSubdivisions));
    if count > 4096
        bound = Inf;
        return
    end
    times = linspace(time, horizon, count+1);
    cells = envelopes(1).Cells;
    mappings = cell(size(records));
    for source = 1:numel(records)
        mappings{source} = app.internal.numerics.mapSlopeEnvelope( ...
            records(source).Envelope, domainSize, records(source).Position, cells);
        allowance = allowance+records(source).Strength*records(source).Envelope.Allowance;
    end
    periodic = records(1).Envelope.Kind == "Periodic";
    assert(all([envelopes.Kind] == envelopes(1).Kind), "RippleSimulator:LoadingGeometry", ...
        "The loading envelopes must share the same boundary geometry.");
    rounding = 1+32*numel(records)*double(eps("single"));
    budget = (limit-allowance)/rounding;
    if ~periodic
        [records, mappings] = groupRadialSources(records, mappings);
    end
    bound = 0;
    batchColumns = 16;
    if periodic
        maximumBatchEntries = 262144;
        batchColumns = max(1, floor(maximumBatchEntries/cells^2));
    end
    for first = 1:batchColumns:count
        columns = first:min(first+batchColumns-1, count);
        total = zeros(cells^2, numel(columns), "single");
        for source = 1:numel(records)
            record = records(source);
            startAge = max(0, times(columns)-record.Time);
            endAge = max(0, times(columns+1)-record.Time);
            active = times(columns+1) > record.Time & startAge < record.Duration;
            if ~any(active)
                continue
            end
            envelope = record.Envelope;
            lower = discretize(min(startAge(active), envelope.Times(end)), envelope.Times);
            upper = discretize(min(endAge(active), envelope.Times(end)), envelope.Times);
            periods = record.Duration/envelope.TimeScale;
            maximumScale = app.internal.responses.SettlingEnvelope.sample( ...
                startAge(active), envelope.TimeScale, periods);
            if periodic
                values = periodicMagnitudes(envelope, mappings{source}, lower, upper);
            else
                values = radialIntervals(envelope, mappings{source}, lower, upper);
                if ~isempty(mappings{source}.Operator)
                    values = single(mappings{source}.Operator*double(values));
                end
            end
            total(:, active) = total(:, active)+single(record.Strength*maximumScale).*values;
        end
        if periodic
            selected = find(total > budget);
            if ~isempty(selected)
                [rows, selectedColumns] = ind2sub(size(total), selected);
                total(selected) = app.internal.numerics.refinePeriodicSlopes(records, mappings, times(columns), ...
                    times(columns+1), rows, selectedColumns);
            end
        end
        bound = max(bound, double(max(total, [], "all")));
    end
    bound = bound*rounding+allowance;
end

function [grouped, groupedMappings] = groupRadialSources(records, mappings)
    grouped = records;
    groupedMappings = mappings;
    maximumMappingEntries = 1048576;
    if numel(records)*numel(mappings{1}.Rows) > maximumMappingEntries ...
            || numel(unique([records.Time])) == numel(records)
        return
    end
    representatives = zeros(size(records));
    groups = zeros(size(records));
    count = 0;
    for index = 1:numel(records)
        record = records(index);
        group = 0;
        for candidateIndex = 1:count
            candidate = records(representatives(candidateIndex));
            if record.Time == candidate.Time && record.Duration == candidate.Duration ...
                    && isequal(record.Envelope, candidate.Envelope)
                group = candidateIndex;
                break
            end
        end
        if group == 0
            count = count+1;
            group = count;
            representatives(group) = index;
        end
        groups(index) = group;
    end
    grouped = records(representatives(1:count));
    groupedMappings = mappings(representatives(1:count));
    for group = 1:count
        selected = find(groups == group);
        if isscalar(selected)
            continue
        end
        pairs = cell(1, numel(selected));
        for member = 1:numel(selected)
            mapping = mappings{selected(member)};
            pairs{member} = [mapping.First, mapping.Last];
        end
        counts = cellfun(@(value) size(value, 1), pairs);
        [pairs, ~, queries] = unique(vertcat(pairs{:}), "rows");
        cells = numel(mappings{selected(1)}.Rows);
        columns = zeros(cells, numel(selected));
        offset = 0;
        for member = 1:numel(selected)
            mapping = mappings{selected(member)};
            columns(:, member) = queries(offset+mapping.Rows);
            offset = offset+counts(member);
        end
        rows = repmat((1:cells)', 1, numel(selected));
        strengths = repmat([records(selected).Strength], cells, 1);
        operator = sparse(rows, columns, strengths, cells, size(pairs, 1));
        groupedMappings{group} = struct(First=pairs(:, 1), Last=pairs(:, 2), ...
            Rows=(1:size(pairs, 1))', Operator=operator);
        grouped(group).Strength = 1;
    end
end

function values = radialIntervals(envelope, mapping, lower, upper)
    count = size(envelope.Bounds, 1);
    firstTime = min(lower);
    columns = (firstTime:max(upper))-1;
    samples = max(envelope.Bounds(mapping.First+columns*count), ...
        envelope.Bounds(mapping.Last+columns*count));
    values = zeros(numel(mapping.First), numel(lower), "single");
    for offset = 0:max(upper-lower)
        values = max(values, samples(:, min(lower+offset, upper)-firstTime+1));
    end
    values = values(mapping.Rows, :);
end

function values = periodicMagnitudes(envelope, mapping, lower, upper)
    count = size(envelope.Bounds, 1)^2;
    indices = mapping.Indices(:, :, 1);
    firstTime = min(lower);
    samples = envelope.Magnitudes(indices(:)+((firstTime:max(upper))-1)*count);
    maximum = zeros(numel(indices), numel(lower), "single");
    for offset = 0:max(upper-lower)
        maximum = max(maximum, samples(:, min(lower+offset, upper)-firstTime+1));
    end
    values = reshape(sum(reshape(maximum, size(indices, 1), 4, []), 2), size(indices, 1), []);
end
