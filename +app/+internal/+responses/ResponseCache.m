classdef (Sealed) ResponseCache
    % RESPONSECACHE Bounded value cache with explicitly pinned response tables.
    %   Preparing a replacement returns a new cache value. The accepted cache
    %   remains available until the application commits the prepared source.
    %   Compact future envelopes survive rendering-table eviction.

    properties (SetAccess = private)
        Fluid app.internal.materials.Fluid
        MaximumRadius (1, 1) double
        ByteLimit (1, 1) double
        Periods (1, 1) double
        Separate (1, 1) logical = false
        ReflectionCoefficient (1, 1) double = 0
        GridResolution (1, 1) double = 201
        PrepareDisplay (1, 1) logical = false
        EnvelopeLimit (1, 1) double = 1024
        Envelopes (1, :) cell = cell(1, 0)
    end

    properties (Dependent, SetAccess = private)
        MemoryBytes (1, 1) double
    end

    properties (Access = private)
        Records (1, :) cell = cell(1, 8)
        Sequence (1, 1) double = 0
    end

    methods
        function obj = ResponseCache(fluid, maximumRadius, options)
        % RESPONSECACHE Define the physical coverage and storage budget.
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                maximumRadius (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
                options.ByteLimit (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive} = 268435456
                options.Periods (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(options.Periods, 1), ...
                    mustBeLessThanOrEqual(options.Periods, 256)} = 64
                options.Separate (1, 1) logical = false
                options.ReflectionCoefficient (1, 1) double {mustBeNonnegative, ...
                    mustBeLessThan(options.ReflectionCoefficient, 1)} = 0
                options.GridResolution (1, 1) double {mustBeInteger, mustBePositive} = 201
                options.PrepareDisplay (1, 1) logical = false
            end
            obj.Fluid = fluid;
            obj.MaximumRadius = double(maximumRadius);
            obj.ByteLimit = double(options.ByteLimit);
            obj.Periods = double(options.Periods);
            obj.Separate = options.Separate;
            obj.ReflectionCoefficient = options.ReflectionCoefficient;
            obj.GridResolution = options.GridResolution;
            obj.PrepareDisplay = options.PrepareDisplay;
        end

        function value = get.MemoryBytes(obj)
            value = 0;
            for index = 1:numel(obj.Records)
                if ~isempty(obj.Records{index})
                    value = value + obj.Records{index}.Table.memoryBytes();
                    if ~isempty(obj.Records{index}.LoadingEnvelope)
                        value = value+obj.Records{index}.LoadingEnvelope.MemoryBytes;
                    end
                end
            end
        end

        function value = containsSource(obj, source)
        % CONTAINSSOURCE Report whether the requested response is already retained.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                source (1, 1) app.internal.input.Source
            end
            value = false;
            for index = 1:numel(obj.Records)
                record = obj.Records{index};
                if ~isempty(record) && matches(record.Source, source)
                    value = true;
                    return
                end
            end
        end

        function [prepared, selected] = prepare(obj, source, pinned)
        % PREPARE Return a cache containing the source without evicting live waves.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                source (1, 1) app.internal.input.Source
                pinned (1, :) double {mustBeInteger, mustBeNonnegative}
            end
            prepared = obj;
            prepared.Sequence = obj.Sequence + 1;
            for index = 1:numel(obj.Records)
                record = obj.Records{index};
                if ~isempty(record) && matches(record.Source, source)
                    prepared.Records{index}.LastUse = prepared.Sequence;
                    selected = index;
                    return
                end
            end
            available = setdiff(1:numel(obj.Records), pinned);
            assert(~isempty(available), "RippleSimulator:CacheCapacity", ...
                "All response tables support active waves. Clear the surface before adding another source scale.");
            needed = app.internal.responses.ResponseTable.estimateBytes( ...
                obj.Fluid, source, obj.MaximumRadius, Periods=obj.Periods);
            ages = zeros(size(available));
            for index = 1:numel(available)
                record = obj.Records{available(index)};
                if ~isempty(record)
                    ages(index) = record.LastUse;
                end
            end
            [~, order] = sort(ages);
            available = available(order);
            selected = available(1);
            prepared.Records{selected} = [];
            index = 2;
            while prepared.MemoryBytes + needed > obj.ByteLimit && index <= numel(available)
                prepared.Records{available(index)} = [];
                index = index + 1;
            end
            assert(prepared.MemoryBytes + needed <= obj.ByteLimit, "RippleSimulator:CacheMemory", ...
                "Active waves leave insufficient cache space for this source. Clear the surface and try again.");
            if obj.ReflectionCoefficient > 0
                response = app.internal.responses.prepareImageResponse(obj.Fluid, source, obj.MaximumRadius, ...
                    obj.ReflectionCoefficient, obj.Periods, obj.GridResolution);
                table = response.Table;
                envelope = response.Envelope;
                globalSlope = response.GlobalSlope;
            else
                response = app.internal.responses.prepareUnitResponse(obj.Fluid, source, ...
                    obj.MaximumRadius, obj.Periods, obj.Separate);
                table = response.Table;
                envelope = response.Envelope;
                globalSlope = response.GlobalSlope;
                if obj.PrepareDisplay
                    availableBytes = obj.ByteLimit-prepared.MemoryBytes-table.memoryBytes();
                    table = table.prepareLattice(obj.MaximumRadius/sqrt(2), obj.GridResolution, ...
                        min(134217728, availableBytes));
                end
            end
            if isa(table, "app.internal.responses.ResponseTable")
                loadingEnvelope = app.internal.numerics.radialSlopeIntervals(table);
                loadingBytes = loadingEnvelope.MemoryBytes;
            else
                radial = app.internal.numerics.radialSlopeIntervals(table.Radial);
                radial.Cells = 51;
                [horizontal, vertical] = meshgrid(-table.ImageOrder:table.ImageOrder);
                orders = [horizontal(:), vertical(:)];
                loadingBytes = radial.MemoryBytes+8*(3*numel(horizontal)+numel(table.ExteriorSlope));
                loadingEnvelope = struct(Kind="Images", Radial=radial, Orders=orders, ...
                    Weights=table.ReflectionCoefficient.^sum(abs(orders), 2), ...
                    ExteriorSlope=table.ExteriorSlope, TailSlopeBound=table.TailSlopeBound, ...
                    TimeScale=table.TimeScale, MemoryBytes=loadingBytes);
            end
            while prepared.MemoryBytes+table.memoryBytes()+loadingBytes > obj.ByteLimit ...
                    && index <= numel(available)
                prepared.Records{available(index)} = [];
                index = index+1;
            end
            assert(prepared.MemoryBytes + table.memoryBytes()+loadingBytes <= obj.ByteLimit, ...
                "RippleSimulator:CacheMemory", "The precomputed response exceeds the response memory budget.");
            envelopeIndex = prepared.findEnvelope(source, obj.MaximumRadius);
            if envelopeIndex == 0
                prepared.requireEnvelopeCapacity();
                envelopeIndex = numel(prepared.Envelopes) + 1;
                prepared.Envelopes{envelopeIndex} = struct(Source=table.Source, Envelope=envelope);
            end
            prepared.Records{selected} = struct(Source=table.Source, Table=table, ...
                EnvelopeIndex=envelopeIndex, LastUse=prepared.Sequence, ...
                GlobalSlope=globalSlope, InitialSlope=NaN, LoadingEnvelope=loadingEnvelope, ...
                SlopeAllowance=5e-4*source.Wavenumber^2/(obj.Fluid.Density*(2*pi/table.Period)));
            prepared.Records{selected}.InitialSlope = prepared.futureSlope(selected, 0);
        end

        function envelope = loadingEnvelope(obj, index)
        % LOADINGENVELOPE Return the precomputed space-time slope enclosure.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                index (1, 1) double {mustBeInteger, mustBePositive}
            end
            envelope = obj.Records{index}.LoadingEnvelope;
        end

        function obj = prepareGrid(obj, resolution)
        % PREPAREGRID Replace display profiles without changing physical tables.
            obj.GridResolution = resolution;
            if ~obj.PrepareDisplay || obj.ReflectionCoefficient > 0
                return
            end
            for index = 1:numel(obj.Records)
                if ~isempty(obj.Records{index})
                    obj.Records{index}.Table = obj.Records{index}.Table.prepareLattice( ...
                        obj.MaximumRadius/sqrt(2), resolution, 0);
                end
            end
            for index = 1:numel(obj.Records)
                if ~isempty(obj.Records{index})
                    availableBytes = min(134217728, obj.ByteLimit-obj.MemoryBytes);
                    obj.Records{index}.Table = obj.Records{index}.Table.prepareLattice( ...
                        obj.MaximumRadius/sqrt(2), resolution, availableBytes);
                end
            end
        end

        function value = futureSlope(obj, index, age, options)
        % FUTURESLOPE Bound current and future slopes with an interpolation margin.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                index (1, 1) double {mustBeInteger, mustBePositive}
                age (1, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                options.EnvelopeIndex (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
            end
            table = obj.getTable(index);
            if isa(table, "app.internal.responses.ImageResponse")
                value = repmat(table.futureSlope(0), size(age));
                return
            end
            record = obj.Records{index};
            if options.EnvelopeIndex == 0 && all(age == 0) && isfinite(record.InitialSlope)
                value = repmat(record.InitialSlope, size(age));
                return
            end
            envelopeIndex = options.EnvelopeIndex;
            if envelopeIndex == 0
                envelopeIndex = record.EnvelopeIndex;
            end
            assert(envelopeIndex <= numel(obj.Envelopes) ...
                && matches(obj.Envelopes{envelopeIndex}.Source, table.Source), ...
                "RippleSimulator:EnvelopeIdentity", "The future envelope must belong to the selected source.");
            envelope = obj.Envelopes{envelopeIndex}.Envelope;
            complete = envelope.bound(age);
            value = min(record.GlobalSlope, complete(:, 3)');
            covered = age <= table.Times(end);
            if any(covered)
                tail = envelope.bound(table.Times(end));
                value(covered) = min(value(covered), max(table.futureSlope(age(covered)), tail(3)));
            end
            value = value + record.SlopeAllowance;
        end

        function value = futureSpatialSlope(obj, index, spatialBound, age, options)
        % FUTURESPATIALSLOPE Refine stored spatial bounds with age and tail bounds.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                index (1, 1) double {mustBeInteger, mustBePositive}
                spatialBound double {mustBeReal, mustBeFinite, mustBeNonnegative}
                age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                options.FinalAge (1, 1) double {mustBeReal, mustBePositive} = Inf
            end
            table = obj.getTable(index);
            globalBound = obj.futureSlope(index, age);
            if isa(table, "app.internal.responses.ImageResponse") || age > table.Times(end)
                value = repmat(globalBound, size(spatialBound));
                return
            end
            record = obj.Records{index};
            tail = 0;
            if options.FinalAge > table.Times(end)
                envelope = obj.Envelopes{record.EnvelopeIndex}.Envelope;
                remaining = envelope.bound(table.Times(end));
                tail = remaining(3);
            end
            value = min(globalBound, max(spatialBound, tail) ...
                + record.SlopeAllowance);
        end

        function [prepared, index] = prepareEnvelope(obj, tableIndex, radius)
        % PREPAREENVELOPE Retain a future bound for a source's observation disk.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                tableIndex (1, 1) double {mustBeInteger, mustBePositive}
                radius (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
            end
            assert(radius <= obj.MaximumRadius, "RippleSimulator:EnvelopeCoverage", ...
                "The observation disk exceeds the tabulated spatial coverage.");
            table = obj.getTable(tableIndex);
            prepared = obj;
            index = obj.findEnvelope(table.Source, double(radius));
            if index == 0
                prepared.requireEnvelopeCapacity();
                envelope = app.internal.responses.RestEnvelope(obj.Fluid, table.Source, double(radius));
                index = numel(prepared.Envelopes) + 1;
                prepared.Envelopes{index} = struct(Source=table.Source, Envelope=envelope);
            end
        end

        function table = getTable(obj, index)
        % GETTABLE Return a retained unit-response table.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                index (1, 1) double {mustBeInteger, mustBePositive}
            end
            assert(index <= numel(obj.Records) && ~isempty(obj.Records{index}), ...
                "RippleSimulator:MissingResponse", "The requested response table is not retained.");
            table = obj.Records{index}.Table;
        end

        function index = getEnvelopeIndex(obj, tableIndex)
        % GETENVELOPEINDEX Return the stable envelope identity of a retained table.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                tableIndex (1, 1) double {mustBeInteger, mustBePositive}
            end
            assert(tableIndex <= numel(obj.Records) && ~isempty(obj.Records{tableIndex}), ...
                "RippleSimulator:MissingResponse", "The requested response table is not retained.");
            index = obj.Records{tableIndex}.EnvelopeIndex;
        end

        function [prepared, mapping] = compactEnvelopes(obj, required)
        % COMPACTENVELOPES Retain envelopes referenced by tables or source history.
            arguments
                obj (1, 1) app.internal.responses.ResponseCache
                required (1, :) double {mustBeInteger, mustBePositive}
            end
            retained = false(1, numel(obj.Envelopes));
            retained(required) = true;
            for index = 1:numel(obj.Records)
                if ~isempty(obj.Records{index})
                    retained(obj.Records{index}.EnvelopeIndex) = true;
                end
            end
            mapping = zeros(size(retained));
            mapping(retained) = 1:nnz(retained);
            prepared = obj;
            if all(retained)
                return
            end
            prepared.Envelopes = obj.Envelopes(retained);
            for index = 1:numel(obj.Records)
                if ~isempty(obj.Records{index})
                    prepared.Records{index}.EnvelopeIndex = mapping(obj.Records{index}.EnvelopeIndex);
                end
            end
        end
    end

    methods (Access = private)
        function requireEnvelopeCapacity(obj)
            assert(numel(obj.Envelopes) < obj.EnvelopeLimit, "RippleSimulator:EnvelopeCapacity", ...
                "The retained response history has reached its storage limit. " ...
                + "Wait for the waves to settle or clear the surface before adding another source scale.");
        end

        function index = findEnvelope(obj, source, radius)
            index = 0;
            for candidate = 1:numel(obj.Envelopes)
                if matches(obj.Envelopes{candidate}.Source, source) ...
                        && obj.Envelopes{candidate}.Envelope.Radius == radius
                    index = candidate;
                    return
                end
            end
        end
    end
end

function tf = matches(first, second)
    tf = first.Wavelength == second.Wavelength && first.Mode == second.Mode;
end
