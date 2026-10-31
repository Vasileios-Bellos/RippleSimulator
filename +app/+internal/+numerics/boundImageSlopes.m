function bound = boundImageSlopes(records, domainSize, time, allowance, limit)
% BOUNDIMAGESLOPES Enclose scheduled, partially reflected surface gradients.
%   Dominant image contributions retain their spatial and temporal envelopes.
%   The remaining contributions are enclosed by absolute future-slope bounds.
    arguments
        records (1, :) struct
        domainSize (1, 1) double {mustBeReal, mustBePositive, mustBeFinite}
        time (1, 1) double {mustBeReal, mustBeNonnegative, mustBeFinite}
        allowance (1, 1) double {mustBeReal, mustBeNonnegative, mustBeFinite}
        limit (1, 1) double {mustBeReal, mustBePositive, mustBeFinite}
    end
    bound = Inf;
    if any(~isfinite([records.Time])) || any(~isfinite([records.Duration])) ...
            || any(~isfinite(vertcat(records.Position)), "all")
        return
    end
    active = [records.Time]+[records.Duration] > time & [records.Strength] > 0;
    records = records(active);
    if isempty(records)
        bound = allowance;
        return
    end
    template = struct(Envelope=[], Time=0, Position=[0, 0], Strength=0, Duration=0);
    counts = arrayfun(@(record) size(record.Envelope.Orders, 1), records);
    images = repmat(template, 1, sum(counts));
    count = 0;
    for record = records
        envelope = record.Envelope;
        positions = domainSize*envelope.Orders+(-1).^envelope.Orders.*record.Position;
        distances = hypot(max(0, abs(positions(:, 1))-domainSize/2), ...
            max(0, abs(positions(:, 2))-domainSize/2));
        indices = min(numel(envelope.ExteriorSlope), ...
            floor(distances/envelope.Radial.SpatialStep)+1);
        strengths = 1.01*record.Strength*envelope.Weights;
        slopes = strengths.*envelope.ExteriorSlope(indices);
        [sorted, permutation] = sort(slopes);
        coarse = permutation(cumsum(sorted) <= limit/(16*numel(records)));
        retained = true(size(slopes));
        retained(coarse) = false;
        allowance = allowance+sum(slopes(coarse))+record.Strength*envelope.TailSlopeBound;
        for index = reshape(find(retained), 1, [])
            count = count+1;
            images(count) = struct(Envelope=envelope.Radial, Time=record.Time, ...
                Position=positions(index, :), Strength=strengths(index), Duration=record.Duration);
        end
    end
    bound = app.internal.numerics.boundScheduledSlopes( ...
        images(1:count), domainSize, time, allowance, limit);
end
