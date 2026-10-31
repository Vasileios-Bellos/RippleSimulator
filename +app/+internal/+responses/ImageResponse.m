classdef (Sealed) ImageResponse
    % IMAGERESPONSE Prepare partially reflected, viscous image-source waves.
    %   Each image carries R to the number of wall encounters. Reflections
    %   retain source age, dispersion, and the complete viscous response.
    %   The constant real coefficient models specular, zero-phase reflection.
    %   A filtered infinite sum completes the finite images' long-wave tail.

    properties (SetAccess = immutable)
        Fluid app.internal.materials.Fluid
        Source app.internal.input.Source
        DomainSize (1, 1) double
        ReflectionCoefficient (1, 1) double
        ImageOrder (1, 1) double
        Period (1, 1) double
        TimeScale (1, 1) double
        Times (1, :) double
        Nodes (1, :) double
        Radial app.internal.responses.ResponseTable
        Separated app.internal.responses.SeparatedResponse
        SpatialBasis (:, :, :, :) single
        ExteriorSlope (:, 1) double
        TailSlopeBound (1, 1) double
    end

    methods
        function obj = ImageResponse(fluid, source, domainSize, coefficient, periods, resolution)
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                source (1, 1) app.internal.input.Source
                domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                coefficient (1, 1) double {mustBeReal, mustBeFinite, ...
                    mustBeGreaterThan(coefficient, 0), mustBeLessThan(coefficient, 1)}
                periods (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                resolution (1, 1) double {mustBeInteger, mustBeGreaterThanOrEqual(resolution, 51)} = 201
            end
            obj.Fluid = fluid;
            obj.Source = app.internal.input.Source(source.Wavelength, 1, source.Mode);
            obj.DomainSize = domainSize;
            obj.ReflectionCoefficient = coefficient;
            assert(domainSize >= 6.5*source.Wavelength*(1-32*eps), ...
                "RippleSimulator:PartialReflectionExtent", ...
                "Partial reflections require a domain at least 6.5 characteristic wavelengths wide. " ...
                + "Increase the physical size or select a shorter wavelength.");
            assert(periods <= 10, "RippleSimulator:PartialReflectionDuration", ...
                "The partial-reflection response supports up to ten settling time scales.");
            ratio = domainSize/source.Wavelength;
            obj.ImageOrder = min(4, floor(4095/(32*sqrt(2)*ratio))-1);
            assert(obj.ImageOrder >= 2, "RippleSimulator:PartialReflectionExtent", ...
                "The requested extent exceeds the supported partial-reflection range.");
            maximumRadius = sqrt(2)*(obj.ImageOrder+1)*domainSize;
            radial = prepareRadialResponse(fluid, obj.Source, maximumRadius, periods);
            obj.Radial = radial;
            obj.Period = radial.Period;
            obj.TimeScale = radial.TimeScale;
            obj.Times = radial.Times;
            [tailNodes, tailFields] = app.internal.physics.imageTailResponse( ...
                fluid, obj.Source, domainSize, coefficient, radial.Times, ImageOrder=obj.ImageOrder);
            separated = app.internal.responses.SeparatedResponse(radial.Fields, radial.Times, ...
                radial.RadialStep, radial.Period, Supplemental=tailFields);
            obj.Separated = separated;
            subdivision = ceil(24*domainSize/((resolution-1)*source.Wavelength));
            nodeCount = subdivision*(resolution-1)+1;
            if 4*3*nodeCount^2*separated.Rank > 402653184
                nodeCount = floor(sqrt(402653184/(12*separated.Rank)));
            end
            assert((nodeCount-1)*source.Wavelength/domainSize >= 12, ...
                "RippleSimulator:ReflectionMemory", ...
                "The partial-reflection preparation budget cannot resolve this source scale.");
            assert(4*3*nodeCount^2*separated.Rank <= 402653184, "RippleSimulator:ReflectionMemory", ...
                "This combination of domain and wavelength exceeds the partial-reflection preparation budget.");
            obj.Nodes = linspace(0, domainSize, nodeCount);
            basis = prepareImages(radial, separated, obj.Nodes, domainSize, coefficient, obj.ImageOrder);
            tail = interpolateTail(separated.SpatialBasis(2*numel(radial.Radii)+1:end, :), ...
                tailNodes, obj.Nodes, separated.Rank);
            obj.TailSlopeBound = tailSlopeBound(tail, separated, obj.Nodes(2)-obj.Nodes(1));
            obj.SpatialBasis = single(basis+tail);
            obj.ExteriorSlope = exteriorSlope(radial);
        end

        function mapping = mapPosition(obj, coordinates, position, byteLimit)
        % MAPPOSITION Prepare a translated image response on the observation grid.
            arguments
                obj (1, 1) app.internal.responses.ImageResponse
                coordinates (1, :) double
                position (1, 2) double
                byteLimit (1, 1) double {mustBeNonnegative}
            end
            needed = 4*numel(coordinates)^2*obj.Separated.Rank;
            assert(needed <= byteLimit, "RippleSimulator:MappingMemory", ...
                "The precomputed reflection basis exceeds the memory budget.");
            basis = obj.translatedBasis(coordinates, position, 0);
            mapping = struct(SpatialBasis=single(reshape(basis, [], obj.Separated.Rank)), ...
                OperatorBytes=needed, Coordinates=coordinates, Position=position, ...
                MaximumSlope=obj.slopeBound(position));
        end

        function [elevation, velocity, gradientX, gradientY] = sample(obj, mapping, age)
        % SAMPLE Evaluate an accepted source without rebuilding image geometry.
            arguments
                obj (1, 1) app.internal.responses.ImageResponse
                mapping (1, 1) struct
                age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            count = numel(mapping.Coordinates);
            if nargout > 1
                [coefficients, derivative] = obj.Separated.sample(age);
                velocity = reshape(double(mapping.SpatialBasis*single(derivative)), count, count);
            else
                coefficients = obj.Separated.sample(age);
            end
            elevation = reshape(double(mapping.SpatialBasis*single(coefficients)), count, count);
            if age == 0
                elevation(:) = 0;
            end
            if nargout > 2
                horizontal = obj.translatedBasis(mapping.Coordinates, mapping.Position, 1);
                vertical = obj.translatedBasis(mapping.Coordinates, mapping.Position, 2);
                gradientX = reshape(reshape(horizontal, [], obj.Separated.Rank)*coefficients, count, count);
                gradientY = reshape(reshape(vertical, [], obj.Separated.Rank)*coefficients, count, count);
                if age == 0
                    gradientX(:) = 0;
                    gradientY(:) = 0;
                end
            end
        end

        function value = slopeBound(obj, position)
        % SLOPEBOUND Bound retained images and the smooth long-wave correction.
            arguments
                obj (1, 1) app.internal.responses.ImageResponse
                position (1, 2) double
            end
            [horizontal, vertical] = meshgrid(-obj.ImageOrder:obj.ImageOrder);
            orders = [horizontal(:), vertical(:)];
            images = obj.DomainSize*orders+(-1).^orders.*position;
            offset = max(0, abs(images)-obj.DomainSize/2);
            distance = hypot(offset(:, 1), offset(:, 2));
            index = min(numel(obj.ExteriorSlope), floor(distance/obj.Radial.RadialStep)+1);
            weights = obj.ReflectionCoefficient.^sum(abs(orders), 2);
            value = 1.01*sum(weights.*obj.ExteriorSlope(index))+obj.TailSlopeBound;
        end

        function value = futureSlope(obj, ~)
        % FUTURESLOPE Return a conservative source-position-independent slope.
            [horizontal, vertical] = meshgrid(-obj.ImageOrder:obj.ImageOrder);
            distance = obj.DomainSize*hypot(max(0, abs(horizontal)-1), max(0, abs(vertical)-1));
            index = min(numel(obj.ExteriorSlope), floor(distance(:)/obj.Radial.RadialStep)+1);
            weights = obj.ReflectionCoefficient.^(abs(horizontal(:))+abs(vertical(:)));
            value = 1.01*sum(weights.*obj.ExteriorSlope(index))+obj.TailSlopeBound;
        end

        function value = memoryBytes(obj)
        % MEMORYBYTES Return retained numeric response storage.
            value = obj.Radial.memoryBytes()+obj.Separated.MemoryBytes ...
                + 4*numel(obj.SpatialBasis)+8*(numel(obj.ExteriorSlope)+numel(obj.Nodes));
        end
    end

    methods (Access = private)
        function basis = translatedBasis(obj, coordinates, position, derivativeAxis)
            count = numel(coordinates);
            nodes = numel(obj.Nodes);
            rank = obj.Separated.Rank;
            if derivativeAxis == 0
                spacing = obj.Nodes(2)-obj.Nodes(1);
                horizontal = abs(coordinates(:)-position(1)*[1, -1])/spacing;
                vertical = abs(coordinates(:)-position(2)*[1, -1])/spacing;
                if all(abs(horizontal-round(horizontal)) < 1e-9, "all") ...
                        && all(abs(vertical-round(vertical)) < 1e-9, "all")
                    basis = translateAlignedImages(obj.SpatialBasis, round(horizontal)+1, round(vertical)+1);
                    return
                end
            end
            if derivativeAxis == 0
                basis = zeros(count, count, rank, "single");
            else
                basis = zeros(count, count, rank);
            end
            for parityX = 0:1
                for parityY = 0:1
                    x = coordinates-(-1)^parityX*position(1);
                    y = coordinates-(-1)^parityY*position(2);
                    horizontalIndex = abs(x)/(obj.Nodes(2)-obj.Nodes(1));
                    verticalIndex = abs(y)/(obj.Nodes(2)-obj.Nodes(1));
                    if derivativeAxis == 0 && all(abs(horizontalIndex-round(horizontalIndex)) < 1e-9) ...
                            && all(abs(verticalIndex-round(verticalIndex)) < 1e-9)
                        horizontalIndex = round(horizontalIndex)+1;
                        verticalIndex = round(verticalIndex)+1;
                        if parityX == 1 && parityY == 0
                            selected = permute(obj.SpatialBasis( ...
                                horizontalIndex, verticalIndex, :, 1+parityX+parityY), [2, 1, 3]);
                        else
                            selected = obj.SpatialBasis(verticalIndex, horizontalIndex, :, 1+parityX+parityY);
                        end
                        basis = basis + selected;
                        continue
                    end
                    if derivativeAxis == 1
                        [~, horizontal] = app.internal.numerics.interpolationMatrix(obj.Nodes, abs(x));
                        horizontal = spdiags(sign(x(:)), 0, count, count)*horizontal;
                    else
                        horizontal = app.internal.numerics.interpolationMatrix(obj.Nodes, abs(x));
                    end
                    if derivativeAxis == 2
                        [~, vertical] = app.internal.numerics.interpolationMatrix(obj.Nodes, abs(y));
                        vertical = spdiags(sign(y(:)), 0, count, count)*vertical;
                    else
                        vertical = app.internal.numerics.interpolationMatrix(obj.Nodes, abs(y));
                    end
                    values = double(obj.SpatialBasis(:, :, :, 1+parityX+parityY));
                    if parityX == 1 && parityY == 0
                        values = permute(values, [2, 1, 3]);
                    end
                    first = reshape(vertical*reshape(values, nodes, []), count, nodes, rank);
                    second = reshape(horizontal*reshape(permute(first, [2, 1, 3]), nodes, []), count, count, rank);
                    basis = basis + permute(second, [2, 1, 3]);
                end
            end
        end
    end
end

function basis = translateAlignedImages(spatial, horizontal, vertical)
% TRANSLATEALIGNEDIMAGES Sum image groups in bounded blocks of temporal factors.
    count = size(horizontal, 1);
    rank = size(spatial, 3);
    blockSize = 4;
    basis = zeros(count, count, rank, "single");
    for first = 1:blockSize:rank
        columns = first:min(first+blockSize-1, rank);
        selected = spatial(vertical(:, 1), horizontal(:, 1), columns, 1);
        selected = selected+spatial(vertical(:, 2), horizontal(:, 1), columns, 2);
        selected = selected+permute(spatial(horizontal(:, 2), vertical(:, 1), columns, 2), [2, 1, 3]);
        selected = selected+spatial(vertical(:, 2), horizontal(:, 2), columns, 3);
        basis(:, :, columns) = selected;
    end
end

function table = prepareRadialResponse(fluid, source, radius, periods)
% PREPARERADIALRESPONSE Reuse the physical response across coefficient changes.
    persistent retained
    signature = struct(Fluid=fluid, Source=source, Radius=radius, Periods=periods);
    if ~isempty(retained) && isequal(signature, retained.Signature)
        table = retained.Table;
        return
    end
    table = app.internal.responses.ResponseTable(fluid, source, radius, Periods=periods);
    if table.memoryBytes() <= 134217728
        retained = struct(Signature=signature, Table=table);
    end
end

function basis = prepareImages(radial, separated, nodes, extent, coefficient, order)
    [x, y] = meshgrid(nodes);
    x = x(:);
    y = y(:);
    triangle = find(y <= x);
    nodeCount = numel(nodes);
    mirrored = reshape(reshape(1:nodeCount^2, nodeCount, nodeCount)', [], 1);
    [horizontal, vertical] = meshgrid(-order:order);
    horizontal = horizontal(:)';
    vertical = vertical(:)';
    parity = mod(horizontal, 2)+mod(vertical, 2);
    transposed = mod(horizontal, 2) == 1 & mod(vertical, 2) == 0;
    radialCount = numel(radial.Radii);
    spatial = separated.SpatialBasis(1:2*radialCount, :);
    basis = zeros(numel(x), separated.Rank, 3);
    blockSize = 4096;
    for group = 0:2
        selected = parity == group & ~transposed;
        offsetsX = horizontal(selected)*extent;
        offsetsY = vertical(selected)*extent;
        scales = coefficient.^(abs(horizontal(selected))+abs(vertical(selected)));
        points = 1:numel(x);
        if group ~= 1
            % Equal-parity image groups are symmetric under exchange of x and y.
            points = triangle;
        end
        for first = 1:blockSize:numel(points)
            rows = points(first:min(first+blockSize-1, numel(points)));
            mapping = radial.mapRadii(hypot(x(rows)-offsetsX, y(rows)-offsetsY));
            operator = combineImageOperators(mapping, scales, numel(rows));
            values = operator*spatial;
            basis(rows, :, group+1) = values;
            if group ~= 1
                basis(mirrored(rows), :, group+1) = values;
            end
        end
    end
    basis = reshape(basis, numel(nodes), numel(nodes), separated.Rank, 3);
end

function operator = combineImageOperators(mapping, scales, count)
% COMBINEIMAGEOPERATORS Sum weighted Hermite maps before applying spatial factors.
    index = double(mapping.Index);
    fraction = mapping.Fraction;
    radialCount = mapping.RadiusCount;
    column = [index, index+radialCount, index+1, index+radialCount+1];
    weights = [2*fraction.^3-3*fraction.^2+1, ...
        mapping.Step*(fraction.^3-2*fraction.^2+fraction), ...
        -2*fraction.^3+3*fraction.^2, mapping.Step*(fraction.^3-fraction.^2)];
    weights = weights.*reshape(repmat(scales, count, 1), [], 1);
    row = repmat((1:count)', numel(scales), 4);
    operator = sparse(row, column, weights, count, 2*radialCount);
end

function basis = interpolateTail(spatial, nodes, points, rank)
    count = numel(points);
    operator = app.internal.numerics.interpolationMatrix(nodes, points);
    coarse = reshape(spatial, numel(nodes), numel(nodes), 3, rank);
    basis = zeros(count, count, rank, 3);
    for group = 1:3
        for index = 1:rank
            basis(:, :, index, group) = operator*coarse(:, :, group, index)*operator';
        end
    end
end

function bound = tailSlopeBound(basis, separated, step)
% TAILSLOPEBOUND Bound quintic spatial interpolation and cubic time evolution.
    [valueBound, differenceBound] = quinticBounds();
    horizontal = max(abs(diff(basis, 1, 2)), [], [1, 2]);
    vertical = max(abs(diff(basis, 1, 1)), [], [1, 2]);
    differences = reshape(max(horizontal, vertical), separated.Rank, 3)*[1; 2; 1];
    count = numel(separated.Times);
    elevation = separated.Coefficients(:, 1:count);
    velocity = separated.Frequency*separated.Coefficients(:, count+1:end);
    steps = diff(separated.Times);
    controls = [elevation, elevation(:, 1:end-1)+steps.*velocity(:, 1:end-1)/3, ...
        elevation(:, 2:end)-steps.*velocity(:, 2:end)/3];
    temporal = max(abs(controls), [], 2);
    bound = 1.01*sqrt(2)*valueBound*differenceBound/step*(differences'*temporal);
end

function [valueBound, differenceBound] = quinticBounds()
    parameter = (0:5)'/5;
    bernstein = zeros(6);
    for index = 0:5
        bernstein(:, index+1) = nchoosek(5, index)*parameter.^index.*(1-parameter).^(5-index);
    end
    valueBound = 0;
    differenceBound = 0;
    for interval = 0:4
        values = full(app.internal.numerics.interpolationMatrix(0:5, interval+parameter'));
        controls = bernstein\values;
        derivative = -cumsum(5*diff(controls, 1, 1), 2);
        valueBound = max(valueBound, max(sum(abs(controls), 2)));
        differenceBound = max(differenceBound, max(sum(abs(derivative(:, 1:5)), 2)));
    end
end

function bound = exteriorSlope(response)
    fields = response.Fields;
    steps = diff(response.Times);
    bound = zeros(numel(response.Radii)-1, 1);
    for start = 1:128:numel(steps)
        columns = start:min(start+127, numel(steps));
        for control = 1:4
            switch control
                case 1
                    elevation = fields(:, columns, 1);
                    slope = fields(:, columns, 3);
                case 2
                    elevation = fields(:, columns, 1)+steps(columns).*fields(:, columns, 2)/3;
                    slope = fields(:, columns, 3)+steps(columns).*fields(:, columns, 4)/3;
                case 3
                    elevation = fields(:, columns+1, 1)-steps(columns).*fields(:, columns+1, 2)/3;
                    slope = fields(:, columns+1, 3)-steps(columns).*fields(:, columns+1, 4)/3;
                otherwise
                    elevation = fields(:, columns+1, 1);
                    slope = fields(:, columns+1, 3);
            end
            interior = 3*diff(elevation, 1, 1)/response.RadialStep-slope(1:end-1, :)-slope(2:end, :);
            bound = max([bound, max(abs(slope(1:end-1, :)), [], 2), ...
                max(abs(slope(2:end, :)), [], 2), max(abs(interior), [], 2)], [], 2);
        end
    end
    bound = flip(cummax(flip(bound)));
end
