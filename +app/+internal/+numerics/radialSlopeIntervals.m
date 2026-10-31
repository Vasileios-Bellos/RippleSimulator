function envelope = radialSlopeIntervals(table)
% RADIALSLOPEINTERVALS Enclose radial slopes over complete space-time cells.
    arguments
        table (1, 1) app.internal.responses.ResponseTable
    end
    fields = table.Fields;
    steps = diff(table.Times);
    intervals = zeros(size(fields, 1)-1, numel(steps));
    for control = 1:4
        switch control
            case 1
                elevation = fields(:, 1:end-1, 1);
                slope = fields(:, 1:end-1, 3);
            case 2
                elevation = fields(:, 1:end-1, 1)+steps.*fields(:, 1:end-1, 2)/3;
                slope = fields(:, 1:end-1, 3)+steps.*fields(:, 1:end-1, 4)/3;
            case 3
                elevation = fields(:, 2:end, 1)-steps.*fields(:, 2:end, 2)/3;
                slope = fields(:, 2:end, 3)-steps.*fields(:, 2:end, 4)/3;
            otherwise
                elevation = fields(:, 2:end, 1);
                slope = fields(:, 2:end, 3);
        end
        interior = 3*diff(elevation, 1, 1)/table.RadialStep-slope(1:end-1, :)-slope(2:end, :);
        intervals = max(intervals, max(max(abs(slope(1:end-1, :)), abs(slope(2:end, :))), abs(interior)));
    end
    last = table.Times(end);
    ages = unique([0:table.TimeScale/16:last, last]);
    indices = unique(interp1(table.Times, 1:numel(table.Times), ages, "nearest"));
    bounds = zeros(size(intervals, 1), numel(indices)-1);
    for column = 1:size(bounds, 2)
        bounds(:, column) = max(intervals(:, indices(column):indices(column+1)-1), [], 2);
    end
    count = size(bounds, 1);
    ranges = zeros(count, size(bounds, 2), floor(log2(count))+1, "single");
    ranges(:, :, 1) = single(bounds)*(1+8*eps("single"));
    for level = 2:size(ranges, 3)
        rows = min((1:count)'+2^(level-2), count);
        ranges(:, :, level) = max(ranges(:, :, level-1), ranges(rows, :, level-1));
    end
    allowance = 5e-4*table.Source.Wavenumber^2/(table.Fluid.Density*(2*pi/table.Period));
    envelope = struct(Kind="Radial", Times=table.Times(indices), Bounds=ranges, ...
        SpatialStep=table.RadialStep, DomainSize=0, TimeScale=table.TimeScale, Cells=51, ...
        Allowance=allowance, MemoryBytes=4*numel(ranges)+8*numel(indices));
end
