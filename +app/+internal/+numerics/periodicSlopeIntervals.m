function envelope = periodicSlopeIntervals(table, options)
% PERIODICSLOPEINTERVALS Enclose periodic gradient components over space-time cells.
%   The stored quadrant uses reflection symmetry. Signed Bernstein bounds
%   preserve cancellation when translated sources are combined at equal times.
    arguments
        table (1, 1) app.internal.responses.TankResponse
        options.Cells (1, 1) double {mustBeInteger, mustBePositive} = 101
        options.Nodes (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
        options.Intervals (1, 1) double {mustBeInteger, mustBePositive} = 16
        options.FactorTolerance (1, 1) double {mustBePositive, mustBeFinite, ...
            mustBeLessThanOrEqual(options.FactorTolerance, 1)} = 0.005
    end
    assert(~isempty(table.PreparedResponse), "RippleSimulator:ResponseTimeCoverage", ...
        "A finite precomputed response is required for spatial slope bounds.");
    count = min(512, 2^nextpow2(max(128, 32*table.DomainSize/table.Source.Wavelength)));
    if options.Nodes > 0
        count = options.Nodes;
    end
    assert(mod(count, 2) == 0, "RippleSimulator:PeriodicGrid", ...
        "The periodic gradient grid requires an even number of nodes.");
    modes = [0:count/2-1, -count/2:-1];
    [modeX, modeY] = meshgrid(modes);
    kx = pi/table.DomainSize*modeX;
    ky = pi/table.DomainSize*modeY;
    wavenumber = hypot(kx, ky);
    selected = wavenumber > 0 & abs(modeX) <= min(table.Modes(end), count/2-1) ...
        & abs(modeY) <= min(table.Modes(end), count/2-1);
    indices = sub2ind(size(table.Amplitude), abs(modeY(selected))+1, abs(modeX(selected))+1);
    multiplicity = (1+(modeX(selected) ~= 0)).*(1+(modeY(selected) ~= 0));
    coefficient = zeros(count);
    coefficient(selected) = table.Amplitude(indices)./(4*multiplicity);
    mapping = table.ModeIndex(indices);
    moments = zeros(numel(table.Frequency), 4);
    for order = 1:4
        moments(:, order) = accumarray(mapping, ...
            abs(coefficient(selected)).*wavenumber(selected).^(2*order-1), size(table.Frequency));
    end
    step = 2*table.DomainSize/count;
    [controls, allowance, remainder, times] = temporalControls( ...
        table.PreparedResponse, moments, step, table.TimeScale, options.Intervals);
    weights = moments(:, 1)+step^2/4*moments(:, 2)+step^4/16*moments(:, 3);
    retained = weights > 0;
    weighted = weights(retained).*controls(retained, :);
    [basis, temporal] = app.internal.numerics.factorResponse(weighted, options.FactorTolerance);
    residual = max(sum(abs(weighted-basis*temporal), 1));
    modal = zeros(numel(table.Frequency), size(basis, 2));
    modal(retained, :) = basis./weights(retained);
    [gradient, horizontal, vertical, fourth] = spatialBases(modal, mapping, selected, coefficient, kx, ky);
    roundingWeights = max(abs(gradient), [], 1) ...
        +step^2/8*(max(abs(horizontal), [], 1)+max(abs(vertical), [], 1)) ...
        +step^4/64*(max(abs(fourth(:, :, 1)), [], 1) ...
        +2*max(abs(fourth(:, :, 2)), [], 1)+max(abs(fourth(:, :, 3)), [], 1));
    operations = 2*size(temporal, 1)+8;
    roundoff = operations*double(eps("single"))/(1-operations*double(eps("single"))) ...
        *(roundingWeights*abs(temporal));
    gradient = single(gradient);
    horizontal = single(horizontal);
    vertical = single(vertical);
    fourth = single(fourth);
    temporal = single(temporal);
    side = count/2+1;
    intervals = numel(times)-1;
    bounds = zeros(count/2, count/2, intervals, 2, "single");
    [tx, ty] = meshgrid(table.Modes);
    omitted = tx >= count/2 | ty >= count/2;
    forcingNorm = 1+7*(table.Source.Mode == "Wavemaker");
    tail = forcingNorm*sum(abs(table.Amplitude(omitted)).*table.Wavenumber(omitted))/4;
    radius = ceil(count/(4*options.Cells)+0.5);
    for first = 1:16:size(temporal, 2)
        columns = first:min(first+15, size(temporal, 2));
        values = reshape(gradient*temporal(:, columns), side, side, []);
        curvatureX = reshape(horizontal*temporal(:, columns), side, side, []);
        curvatureY = reshape(vertical*temporal(:, columns), side, side, []);
        correction = step^2/8*(vertexMaximum(abs(curvatureX))+vertexMaximum(abs(curvatureY))) ...
            +reshape(single(remainder(ceil(columns/4))+allowance(ceil(columns/4)) ...
            +residual+tail+roundoff(columns)), 1, 1, []);
        for derivative = 1:3
            valuesFourth = reshape(fourth(:, :, derivative)*temporal(:, columns), side, side, []);
            multiplicity = 1+(derivative == 2);
            correction = correction+step^4/64*multiplicity*vertexMaximum(abs(valuesFourth));
        end
        lower = -vertexMaximum(-values)-correction;
        upper = vertexMaximum(values)+correction;
        for offset = 1:4:numel(columns)
            interval = ceil(columns(offset)/4);
            minimum = min(lower(1:end-1, 1:end-1, offset:offset+3), [], 3);
            maximum = max(upper(1:end-1, 1:end-1, offset:offset+3), [], 3);
            rounding = 8*eps("single")*max(abs(minimum), abs(maximum));
            bounds(:, :, interval, 1) = single(minimum-rounding);
            bounds(:, :, interval, 2) = single(maximum+rounding);
        end
    end
    interpolation = forcingNorm*5e-4*table.Source.Wavenumber^2 ...
        /(table.Fluid.Density*(2*pi/table.Period));
    magnitude = max(abs(bounds(:, :, :, 1)), abs(bounds(:, :, :, 2)));
    magnitude = hypot(magnitude, permute(magnitude, [2, 1, 3]));
    magnitude = [magnitude, fliplr(magnitude); flipud(magnitude), rot90(magnitude, 2)];
    magnitude = centeredMaximum(magnitude, radius);
    magnitude = magnitude(1:count/2, 1:count/2, :);
    envelope = struct(Kind="Periodic", Times=times, Bounds=bounds, SpatialStep=step, ...
        DomainSize=table.DomainSize, TimeScale=table.TimeScale, Cells=options.Cells, ...
        Magnitudes=magnitude*(1+8*eps("single")), ...
        ErrorBounds=struct(Factorization=residual, Temporal=max(allowance), ...
        SpatialRemainder=max(remainder), Truncation=tail, Roundoff=max(roundoff)), ...
        Allowance=table.TailBound(3)+interpolation, ...
        MemoryBytes=4*(numel(bounds)+numel(magnitude))+8*numel(times));

end

function [controls, allowance, remainder, times] = temporalControls( ...
        response, moments, step, timeScale, intervalsPerPeriod)
    last = response.Times(end);
    ages = unique([0:timeScale/intervalsPerPeriod:last, last]);
    boundaries = unique(interp1(response.Times, 1:numel(response.Times), ages, "nearest"));
    times = response.Times(boundaries);
    blocks = numel(boundaries)-1;
    controls = zeros(numel(response.Frequency), 4*blocks);
    allowance = zeros(1, blocks);
    remainder = allowance;
    for block = 1:blocks
        first = boundaries(block);
        last = boundaries(block+1);
        blockTimes = response.Times(first:last);
        duration = blockTimes(end)-blockTimes(1);
        current = [response.Elevations(:, first), ...
            response.Elevations(:, first)+duration*response.Velocities(:, first)/3, ...
            response.Elevations(:, last)-duration*response.Velocities(:, last)/3, ...
            response.Elevations(:, last)];
        controls(:, (block-1)*4+(1:4)) = current;
        fraction = (blockTimes-blockTimes(1))/duration;
        values = [(1-fraction).^3; 3*fraction.*(1-fraction).^2; ...
            3*fraction.^2.*(1-fraction); fraction.^3];
        derivatives = 3/duration*[-(1-fraction).^2; (1-fraction).*(1-3*fraction); ...
            fraction.*(2-3*fraction); fraction.^2];
        difference = response.Elevations(:, first:last)-current*values;
        velocity = response.Velocities(:, first:last)-current*derivatives;
        intervals = diff(blockTimes);
        residual = max([abs(difference), ...
            abs(difference(:, 1:end-1)+intervals.*velocity(:, 1:end-1)/3), ...
            abs(difference(:, 2:end)-intervals.*velocity(:, 2:end)/3)], [], 2);
        allowance(block) = sum((moments(:, 1)+step^2/4*moments(:, 2)+step^4/16*moments(:, 3)).*residual);
        remainder(block) = step^6/512*sum(moments(:, 4).*max(abs(current), [], 2));
    end
end

function [gradient, horizontal, vertical, fourth] = spatialBases(modal, mapping, selected, coefficient, kx, ky)
    count = size(coefficient, 1);
    nodes = 1:count/2+1;
    gradient = zeros(numel(nodes)^2, size(modal, 2));
    horizontal = gradient;
    vertical = gradient;
    fourth = zeros(numel(nodes)^2, size(modal, 2), 3);
    gradientMultiplier = 1i*kx;
    curvatureMultiplier = -1i*kx.^3+kx.*ky.^2;
    derivatives = {1i*kx.^5, 1i*kx.^3.*ky.^2, 1i*kx.*ky.^4};
    for column = 1:size(modal, 2)
        spectrum = zeros(count);
        spectrum(selected) = coefficient(selected).*modal(mapping, column);
        field = real(ifft2(gradientMultiplier.*spectrum))*count^2;
        curvature = ifft2(curvatureMultiplier.*spectrum)*count^2;
        field = field(nodes, nodes);
        curvature = curvature(nodes, nodes);
        gradient(:, column) = field(:);
        horizontal(:, column) = real(curvature(:));
        vertical(:, column) = imag(curvature(:));
        for derivative = 1:3
            field = real(ifft2(derivatives{derivative}.*spectrum))*count^2;
            field = field(nodes, nodes);
            fourth(:, column, derivative) = field(:);
        end
    end
end

function values = vertexMaximum(values)
    values = max(values, circshift(values, -1, 1));
    values = max(values, circshift(values, -1, 2));
end

function values = centeredMaximum(values, radius)
    for dimension = 1:2
        original = values;
        for shift = 1:radius
            values = max(values, max(circshift(original, shift, dimension), ...
                circshift(original, -shift, dimension)));
        end
    end
end
