function [nodes, fields] = imageTailResponse(fluid, source, extent, coefficient, times, options)
% IMAGETAILRESPONSE Complete the long-wave contribution of weighted images.
%   A fourth-order Gaussian filter separates a rapidly decaying image residual
%   from a smooth infinite sum evaluated in Fourier space.
%   Subtracting the retained filtered images gives a smooth correction to the
%   finite, unfiltered image sum. The three spatial groups have even/even,
%   even/odd, and odd/odd image parity. Preparation is independent of clicks.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
        extent (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        coefficient (1, 1) double {mustBeReal, mustBeGreaterThan(coefficient, 0), ...
            mustBeLessThan(coefficient, 1)}
        times (1, :) double {mustBeReal, mustBeFinite, mustBeNonnegative}
        options.ImageOrder (1, 1) double {mustBeInteger, mustBeNonnegative} = 8
        options.SpatialNodes (1, 1) double {mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.SpatialNodes, 6)} = 17
        options.SpectralNodes (1, 1) double {mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.SpectralNodes, 257)} = 2049
        options.QuadratureOrder (1, 1) double {mustBeInteger, ...
            mustBeGreaterThanOrEqual(options.QuadratureOrder, 16)} = 64
    end
    nodes = linspace(0, extent, options.SpatialNodes);
    spectrum = prepareSpectrum(fluid, source, extent, times, options.SpectralNodes);
    [wave, measure, parity] = infiniteQuadrature(extent, coefficient, spectrum.Cells, options.QuadratureOrder);
    basis = integrateBasis(spectrum.Variable, spectrum.Spatial, wave, measure, parity, nodes);
    [wave, measure, parity] = finiteQuadrature(extent, coefficient, options.ImageOrder, spectrum.Maximum);
    basis = basis-integrateBasis(spectrum.Variable, spectrum.Spatial, wave, measure, parity, nodes);
    count = numel(times);
    fields = cat(3, basis*spectrum.Temporal(:, 1:count), ...
        spectrum.Forcing*(basis*spectrum.Temporal(:, count+1:end)));
    fields(:, times == 0, 1) = 0;
end

function spectrum = prepareSpectrum(fluid, source, extent, times, count)
% PREPARESPECTRUM Reuse filtered viscous modes across coefficient changes.
    persistent retained
    signature = struct(Fluid=fluid, Source=source, Extent=extent, Times=times, Count=count);
    if ~isempty(retained) && isequal(signature, retained.Signature)
        spectrum = retained.Spectrum;
        return
    end
    width = hypot(extent/4, source.Width);
    cells = ceil(8*extent/(width*pi)+0.5);
    maximum = (cells-0.5)*pi/extent;
    variable = linspace(0, sqrt(sqrt(2)*maximum), count);
    wavenumber = variable(2:end)'.^2;
    frequency = app.internal.physics.dispersion(wavenumber, fluid);
    forcing = app.internal.physics.dispersion(source.Wavenumber, fluid);
    ratio = fluid.KinematicViscosity*wavenumber.^2./frequency;
    if source.Mode == "Impulse"
        [elevation, velocity] = app.internal.physics.viscousImpulse(ratio, frequency*times);
    else
        [elevation, velocity] = app.internal.physics.wavemaker( ...
            ratio, frequency*times, forcing./frequency);
    end
    gaussian = exp(-0.5*(extent*wavenumber/4).^2);
    % The complementary residual has multiplier (1 - gaussian)^4.
    smooth = gaussian.*(4+gaussian.*(-6+gaussian.*(4-gaussian)));
    amplitude = -2*source.PressureImpulse*source.Width^2/(pi*fluid.Density) ...
        *wavenumber.*exp(-0.5*(source.Width*wavenumber).^2).*smooth;
    matrix = [zeros(1, 2*numel(times)); amplitude.*[elevation./frequency, velocity/forcing]];
    [spatial, temporal] = app.internal.numerics.factorResponse(matrix, 1e-12);
    bytes = 8*(numel(variable)+numel(spatial)+numel(temporal)+numel(times)+3);
    spectrum = struct(Variable=variable, Spatial=spatial, Temporal=temporal, ...
        Forcing=forcing, Cells=cells, Maximum=maximum);
    if bytes <= 8388608
        retained = struct(Signature=signature, Spectrum=spectrum);
    end
end

function [wave, measure, parity] = infiniteQuadrature(extent, coefficient, cells, order)
    [nodes, weights] = app.internal.numerics.gaussLegendre(order);
    wave = zeros(order, cells);
    measure = wave;
    factor = (1-coefficient^2)/(1+coefficient^2);
    for index = 1:cells
        if index == 1
            angle = (nodes+1)*pi/4;
            weight = weights*pi/4;
        else
            angle = nodes*pi/2;
            weight = weights*pi/2;
        end
        wave(:, index) = ((index-1)*pi+atan(factor*tan(angle)))/extent;
        measure(:, index) = weight/extent;
    end
    wave = wave(:);
    measure = measure(:);
    parity = [ones(size(wave)), 2*coefficient*cos(wave*extent)/(1+coefficient^2)];
end

function [wave, measure, parity] = finiteQuadrature(extent, coefficient, imageOrder, maximum)
    count = max(16, ceil(maximum*extent*(imageOrder+1)/(8*pi)));
    [nodes, weights] = app.internal.numerics.gaussLegendre(32);
    step = maximum/count;
    wave = ((nodes+1)/2+(0:count-1))*step;
    measure = repmat(weights*step/2, 1, count);
    wave = wave(:);
    measure = measure(:);
    parity = [ones(size(wave)), zeros(size(wave))];
    for index = 1:imageOrder
        column = 1+mod(index, 2);
        parity(:, column) = parity(:, column)+2*coefficient^index*cos(index*wave*extent);
    end
end

function basis = integrateBasis(variable, spatial, wave, measure, parity, nodes)
    [horizontal, vertical] = meshgrid(wave);
    radius = hypot(horizontal, vertical);
    operator = app.internal.numerics.interpolationMatrix(variable, sqrt(radius(:))');
    cosine = cos(nodes'*wave');
    even = cosine.*(measure.*parity(:, 1))';
    odd = cosine.*(measure.*parity(:, 2))';
    count = numel(wave);
    output = numel(nodes);
    rank = size(spatial, 2);
    block = max(1, floor(33554432/(8*count^2)));
    basis = zeros(3*output^2, rank);
    for first = 1:block:rank
        indices = first:min(rank, first+block-1);
        spectrum = operator*spatial(:, indices);
        leftEven = reshape(even*reshape(spectrum, count, []), output, count, []);
        leftOdd = reshape(odd*reshape(spectrum, count, []), output, count, []);
        leftEven = reshape(permute(leftEven, [2, 1, 3]), count, []);
        leftOdd = reshape(permute(leftOdd, [2, 1, 3]), count, []);
        evenEven = permute(reshape(even*leftEven, output, output, []), [2, 1, 3]);
        oddEven = permute(reshape(even*leftOdd, output, output, []), [2, 1, 3]);
        oddOdd = permute(reshape(odd*leftOdd, output, output, []), [2, 1, 3]);
        basis(:, indices) = [reshape(evenEven, output^2, []); ...
            reshape(oddEven, output^2, []); reshape(oddOdd, output^2, [])];
    end
end
