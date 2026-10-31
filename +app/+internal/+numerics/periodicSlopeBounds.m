function envelope = periodicSlopeBounds(table)
% PERIODICSLOPEBOUNDS Bound a periodic unit source over space and tabulated time.
%   Each entry bounds the gradient magnitude over translated observation cells.
%   Temporal Bernstein controls and spatial interpolation remainders retain
%   the phase relationships among modes. Reflected sources use four translated
%   copies of this envelope. The physical response is unchanged.
    arguments
        table (1, 1) app.internal.responses.TankResponse
    end
    assert(~isempty(table.PreparedResponse), "RippleSimulator:ResponseTimeCoverage", ...
        "A finite precomputed response is required for spatial slope bounds.");
    count = min(512, 2^nextpow2(max(128, 32*table.DomainSize/table.Source.Wavelength)));
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
    moments = zeros(numel(table.Frequency), 3);
    for order = 1:3
        moments(:, order) = accumarray(mapping, ...
            abs(coefficient(selected)).*wavenumber(selected).^(2*order-1), size(table.Frequency));
    end
    step = 2*table.DomainSize/count;
    [controls, allowance, remainder] = temporalControls(table.PreparedResponse, moments, step);
    weights = moments(:, 1)+step^2/4*moments(:, 2);
    retained = weights > 0;
    weighted = weights(retained).*controls(retained, :);
    [basis, temporal] = app.internal.numerics.factorResponse(weighted, 0.05);
    residual = max(sum(abs(weighted-basis*temporal), 1));
    modal = zeros(numel(table.Frequency), size(basis, 2));
    modal(retained, :) = basis./weights(retained);
    [gradient, horizontal, vertical] = spatialBases(modal, mapping, selected, coefficient, kx, ky);
    side = count/2+1;
    quadrant = zeros(side);
    for first = 1:16:size(temporal, 2)
        columns = first:min(first+15, size(temporal, 2));
        values = reshape(gradient*temporal(:, columns), side, side, []);
        curvatureX = reshape(horizontal*temporal(:, columns), side, side, []);
        curvatureY = reshape(vertical*temporal(:, columns), side, side, []);
        correction = step^2/8*(vertexMaximum(abs(curvatureX))+vertexMaximum(abs(curvatureY))) ...
            +reshape(remainder(ceil(columns/4))+allowance(ceil(columns/4))+residual, 1, 1, []);
        magnitude = hypot(values, permute(values, [2, 1, 3]));
        bounds = vertexMaximum(magnitude)+hypot(correction, permute(correction, [2, 1, 3]));
        quadrant = max(quadrant, max(bounds, [], 3));
    end
    quadrant = quadrant(1:end-1, 1:end-1);
    envelope = [quadrant, fliplr(quadrant); flipud(quadrant), rot90(quadrant, 2)];
    [tx, ty] = meshgrid(table.Modes);
    omitted = tx >= count/2 | ty >= count/2;
    forcingNorm = 1+7*(table.Source.Mode == "Wavemaker");
    tail = forcingNorm*sum(abs(table.Amplitude(omitted)).*table.Wavenumber(omitted))/4;
    envelope = (envelope+tail)*(1+1024*eps);
    span = ceil(count/(2*101))+1;
    for dimension = 1:2
        width = 1;
        while 2*width <= span
            envelope = max(envelope, circshift(envelope, -width, dimension));
            width = 2*width;
        end
        if width < span
            envelope = max(envelope, circshift(envelope, -(span-width), dimension));
        end
    end
end

function [controls, allowance, remainder] = temporalControls(response, moments, step)
    boundaries = unique([1:16:numel(response.Times), numel(response.Times)]);
    blocks = numel(boundaries)-1;
    controls = zeros(numel(response.Frequency), 4*blocks);
    allowance = zeros(1, blocks);
    remainder = allowance;
    for block = 1:blocks
        first = boundaries(block);
        last = boundaries(block+1);
        times = response.Times(first:last);
        duration = times(end)-times(1);
        current = [response.Elevations(:, first), ...
            response.Elevations(:, first)+duration*response.Velocities(:, first)/3, ...
            response.Elevations(:, last)-duration*response.Velocities(:, last)/3, ...
            response.Elevations(:, last)];
        controls(:, (block-1)*4+(1:4)) = current;
        fraction = (times-times(1))/duration;
        values = [(1-fraction).^3; 3*fraction.*(1-fraction).^2; ...
            3*fraction.^2.*(1-fraction); fraction.^3];
        derivatives = 3/duration*[-(1-fraction).^2; (1-fraction).*(1-3*fraction); ...
            fraction.*(2-3*fraction); fraction.^2];
        difference = response.Elevations(:, first:last)-current*values;
        velocity = response.Velocities(:, first:last)-current*derivatives;
        intervals = diff(times);
        residual = max([abs(difference), ...
            abs(difference(:, 1:end-1)+intervals.*velocity(:, 1:end-1)/3), ...
            abs(difference(:, 2:end)-intervals.*velocity(:, 2:end)/3)], [], 2);
        allowance(block) = sum((moments(:, 1)+step^2/8*moments(:, 2)).*residual);
        remainder(block) = step^4/64*sum(moments(:, 3).*max(abs(current), [], 2));
    end
end

function [gradient, horizontal, vertical] = spatialBases(modal, mapping, selected, coefficient, kx, ky)
    count = size(coefficient, 1);
    nodes = 1:count/2+1;
    gradient = zeros(numel(nodes)^2, size(modal, 2));
    horizontal = gradient;
    vertical = gradient;
    for column = 1:size(modal, 2)
        spectrum = zeros(count);
        spectrum(selected) = coefficient(selected).*modal(mapping, column);
        field = real(ifft2(1i*kx.*spectrum))*count^2;
        curvature = ifft2((-1i*kx.^3+kx.*ky.^2).*spectrum)*count^2;
        field = field(nodes, nodes);
        curvature = curvature(nodes, nodes);
        gradient(:, column) = field(:);
        horizontal(:, column) = real(curvature(:));
        vertical(:, column) = imag(curvature(:));
    end
end

function values = vertexMaximum(values)
    values = max(values, circshift(values, -1, 1));
    values = max(values, circshift(values, -1, 2));
end
