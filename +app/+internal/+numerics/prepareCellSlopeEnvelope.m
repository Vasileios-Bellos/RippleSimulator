function prepared = prepareCellSlopeEnvelope(envelope, extent, position)
% PREPARECELLSLOPEENVELOPE Tabulate a unit source's complete cell-gradient bounds.
%   Rows span Cartesian cells; columns span tabulated age intervals. The
%   allowance encloses interpolation errors, spectral tails, and coarsely
%   bounded image contributions.
    arguments
        envelope (1, 1) struct
        extent (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        position (1, 2) double {mustBeReal, mustBeFinite}
    end
    if envelope.Kind == "Images"
        radial = envelope.Radial;
        positions = extent*envelope.Orders+(-1).^envelope.Orders.*position;
        weights = 1.01*envelope.Weights;
        distances = hypot(max(0, abs(positions(:, 1))-extent/2), ...
            max(0, abs(positions(:, 2))-extent/2));
        indices = min(numel(envelope.ExteriorSlope), floor(distances/radial.SpatialStep)+1);
        slopes = weights.*envelope.ExteriorSlope(indices);
        [sorted, order] = sort(slopes);
        coarseFraction = 0.001;
        omitted = order(cumsum(sorted) <= coarseFraction*sum(slopes));
        coarseAllowance = sum(slopes(omitted));
        retained = true(size(weights));
        retained(omitted) = false;
        positions = positions(retained, :);
        weights = weights(retained);
        queries = cell(1, numel(weights));
        mappings = queries;
        for image = 1:numel(weights)
            mappings{image} = app.internal.numerics.mapSlopeEnvelope( ...
                radial, extent, positions(image, :), radial.Cells);
            queries{image} = [mappings{image}.First, mappings{image}.Last];
        end
        counts = cellfun(@(value) size(value, 1), queries);
        [queries, ~, references] = unique(vertcat(queries{:}), "rows");
        cells = radial.Cells^2;
        columns = zeros(cells, numel(weights));
        offset = 0;
        for image = 1:numel(weights)
            columns(:, image) = references(offset+mappings{image}.Rows);
            offset = offset+counts(image);
        end
        rows = repmat((1:cells)', 1, numel(weights));
        operator = sparse(rows, columns, repmat(weights', cells, 1), cells, size(queries, 1));
        times = (0:numel(radial.Times)-2)*size(radial.Bounds, 1);
        values = max(radial.Bounds(queries(:, 1)+times), radial.Bounds(queries(:, 2)+times));
        values = single(operator*double(values))*(1+32*numel(weights)*eps("single"));
        allowance = sum(weights)*radial.Allowance+envelope.TailSlopeBound+coarseAllowance;
        prepared = struct(Kind="Cells", Cells=radial.Cells, Times=radial.Times, ...
            TimeScale=radial.TimeScale, Bounds=values, Allowance=allowance, Mapping=[]);
        return
    end
    mapping = app.internal.numerics.mapSlopeEnvelope(envelope, extent, position, envelope.Cells);
    if envelope.Kind == "Radial"
        times = (0:numel(envelope.Times)-2)*size(envelope.Bounds, 1);
        values = max(envelope.Bounds(mapping.First+times), envelope.Bounds(mapping.Last+times));
        values = values(mapping.Rows, :);
        mapping = [];
    else
        indices = mapping.Indices(:, :, 1);
        count = size(envelope.Bounds, 1)^2;
        times = (0:numel(envelope.Times)-2)*count;
        samples = envelope.Magnitudes(indices(:)+times);
        values = reshape(sum(reshape(samples, size(indices, 1), 4, []), 2), size(indices, 1), []);
        values = values*(1+32*eps("single"));
    end
    prepared = struct(Kind="Cells", Cells=envelope.Cells, Times=envelope.Times, ...
        TimeScale=envelope.TimeScale, Bounds=values, Allowance=envelope.Allowance, Mapping=mapping);
end
