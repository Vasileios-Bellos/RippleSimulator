classdef (Sealed) Simulation < app.internal.simulation.WaveExperiment
    % SIMULATION Own accepted sources and a continuously sampled physical field.
    %   The observation grid is not the wave state. Resolution changes resample
    %   the same accepted source history at the same physical time. Without
    %   finite settling, retirement requires a cumulative future-motion bound
    %   within the error budget.

    properties (SetAccess = private)
        Fluid app.internal.materials.Fluid
        Source app.internal.input.Source
        DomainSize (1, 1) double
        GridResolution (1, 1) double
        Coordinates (1, :) double
        CurrentTime (1, 1) double = 0
        Revision (1, 1) uint64 = uint64(0)
        GeometryRevision (1, 1) uint64 = uint64(0)
        AcceptedCount (1, 1) double = 0
        ReservedCount (1, 1) double = 0
        Capacity (1, 1) double
        RestBudget (1, 3) double
        MappingByteLimit (1, 1) double = 268435456
        OperatorByteLimit (1, 1) double = 536870912
        AnimationByteLimit (1, 1) double = 268435456
        HistoryLimit (1, 1) double = 65536
        SettlingPeriods (1, 1) double = Inf
        ReflectionCoefficient (1, 1) double = 0
    end

    properties (Dependent, SetAccess = private)
        ActiveCount (1, 1) double
        IsAtRest (1, 1) logical
        AvailableCount (1, 1) double
        CacheBytes (1, 1) double
    end

    properties (Access = private)
        LoadingCache (1, 1) app.internal.simulation.LoadingCache
        Cache app.internal.responses.ResponseCache
        LateCache app.internal.responses.LateResponseCache
        SelectedTable (1, 1) double
        Events (1, :) struct = struct("Time", {}, "Position", {}, "Strength", {}, ...
            "TableIndex", {}, "EnvelopeIndex", {}, "ObservationRadius", {}, "Mapping", {}, ...
            "MaximumSlope", {}, "Id", {})
        Retired (:, 3) double = zeros(0, 3)
        FrozenOmittedBound (1, 3) double = zeros(1, 3)
        RetiredCount (1, 1) double = 0
        Reservations (1, :) struct = struct("Position", {}, "Mapping", {}, "StrengthScale", {}, "Time", {})
        Animations (1, :) cell = cell(1, 8)
        AnimatedIds (1, :) double = zeros(1, 0)
        AccumulateDisplay (1, 1) logical = true
    end

    methods
        function obj = Simulation(fluid, domainSize, resolution, source, options)
        % SIMULATION Prepare one homogeneous, deep-water physical experiment.
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                domainSize (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
                resolution (1, 1) {mustBeNumeric, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(resolution, 51), mustBeLessThanOrEqual(resolution, 801)}
                source (1, 1) app.internal.input.Source
                options.Capacity (1, 1) {mustBeNumeric, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.Capacity, 20), ...
                    mustBeLessThanOrEqual(options.Capacity, 512)} = 128
                options.CacheBytes (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive} = 268435456
                options.TablePeriods (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(options.TablePeriods, 1), ...
                    mustBeLessThanOrEqual(options.TablePeriods, 256)} = 64
                options.RestFraction (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, ...
                    mustBePositive, mustBeLessThanOrEqual(options.RestFraction, 0.00001)} = 1e-7
                options.SettlingPeriods (1, 1) double {mustBeReal, mustBePositive} = Inf
                options.Separate (1, 1) logical = false
                options.PrepareDisplay (1, 1) logical = false
                options.AccumulateDisplay (1, 1) logical = true
                options.LoadingCacheBytes (1, 1) double {mustBeInteger, mustBeNonnegative} = 134217728
                options.AnimationByteLimit (1, 1) double {mustBeInteger, mustBeNonnegative} = 268435456
                options.ReflectionCoefficient (1, 1) double {mustBeReal, mustBeFinite, ...
                    mustBeNonnegative, mustBeLessThan(options.ReflectionCoefficient, 1)} = 0
            end
            validateSampling(double(domainSize), double(resolution), source.Wavelength);
            obj.Fluid = fluid;
            obj.DomainSize = double(domainSize);
            obj.GridResolution = double(resolution);
            obj.Coordinates = linspace(-obj.DomainSize/2, obj.DomainSize/2, obj.GridResolution);
            obj.Source = source;
            obj.Capacity = double(options.Capacity);
            obj.SettlingPeriods = options.SettlingPeriods;
            obj.AccumulateDisplay = options.AccumulateDisplay;
            obj.LoadingCache = app.internal.simulation.LoadingCache(ByteLimit=options.LoadingCacheBytes);
            obj.AnimationByteLimit = options.AnimationByteLimit;
            obj.ReflectionCoefficient = options.ReflectionCoefficient;
            assert(options.ReflectionCoefficient == 0 || (isfinite(options.SettlingPeriods) ...
                && options.SettlingPeriods <= options.TablePeriods), "RippleSimulator:ReflectionDuration", ...
                "Partial reflections require a finite response covering the source lifetime.");
            frequency = app.internal.physics.dispersion(source.Wavenumber, fluid);
            obj.RestBudget = double(options.RestFraction)*obj.DomainSize*[1, frequency, source.Wavenumber];
            cache = app.internal.responses.ResponseCache(fluid, sqrt(2)*obj.DomainSize, ...
                ByteLimit=options.CacheBytes, Periods=options.TablePeriods, Separate=options.Separate, ...
                ReflectionCoefficient=options.ReflectionCoefficient, GridResolution=obj.GridResolution, ...
                PrepareDisplay=options.PrepareDisplay);
            [obj.Cache, obj.SelectedTable] = cache.prepare(source, zeros(1, 0));
            obj.LateCache = app.internal.responses.LateResponseCache(fluid);
            obj.validateLoading(obj.Cache, obj.SelectedTable, source, 0, Count=0);
        end

        function value = get.ActiveCount(obj)
            value = numel(obj.Events);
        end

        function value = get.IsAtRest(obj)
            value = isempty(obj.Events);
        end

        function value = get.AvailableCount(obj)
            mappingCapacity = floor(obj.MappingByteLimit/(12*obj.GridResolution^2));
            historyCapacity = obj.HistoryLimit - size(obj.Retired, 1);
            value = min([obj.Capacity, mappingCapacity, historyCapacity]) - obj.ActiveCount - obj.ReservedCount;
            if obj.ReflectionCoefficient > 0
                table = obj.Cache.getTable(obj.SelectedTable);
                remaining = obj.OperatorByteLimit-mappingBytes(obj.Events)-mappingBytes(obj.Reservations);
                value = min(value, floor(remaining/(4*obj.GridResolution^2*table.Separated.Rank)));
            end
        end

        function value = get.CacheBytes(obj)
            value = obj.Cache.MemoryBytes + obj.LateCache.MemoryBytes;
        end

        function value = requiresSourcePreparation(obj, source)
        % REQUIRESSOURCEPREPARATION Identify changes requiring a new response table.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                source (1, 1) app.internal.input.Source
            end
            value = ~obj.Cache.containsSource(source);
        end

        function plan = prepareSource(obj, source)
        % PREPARESOURCE Prepare a new source while retaining all accepted waves.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                source (1, 1) app.internal.input.Source
            end
            validateSampling(obj.DomainSize, obj.GridResolution, source.Wavelength);
            pinned = unique([obj.Events.TableIndex]);
            [cache, selected] = obj.Cache.prepare(source, pinned);
            obj.validateLoading(cache, selected, source, obj.CurrentTime, Count=0);
            reservations = obj.Reservations;
            if source.Wavelength ~= obj.Source.Wavelength || source.Mode ~= obj.Source.Mode
                remaining = obj.OperatorByteLimit - mappingBytes(obj.Events);
                reservations = prepareReservations(reservations, cache.getTable(selected), ...
                    obj.Coordinates, remaining);
            end
            obj.validateLoading(cache, selected, source, obj.CurrentTime, Count=obj.ReservedCount, ...
                AdditionalSlope=reservationSlope(reservations, cache, selected, source), Reservations=reservations);
            plan = struct(Owner=obj, Revision=obj.Revision, Source=source, Cache=cache, ...
                SelectedTable=selected, Reservations=reservations);
        end

        function commitSource(obj, plan)
        % COMMITSOURCE Accept a prepared source without changing previous events.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                plan (1, 1) struct
            end
            obj.validateRevision(plan);
            obj.LoadingCache = obj.LoadingCache.clear();
            obj.Cache = plan.Cache;
            obj.SelectedTable = plan.SelectedTable;
            obj.Source = plan.Source;
            obj.Reservations = plan.Reservations;
            obj.Revision = obj.Revision + 1;
        end

        function reserveInputs(obj, count, options)
        % RESERVEINPUTS Reserve capacity before accepting scheduled input.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                count (1, 1) {mustBeNumeric, mustBeInteger, mustBePositive}
                options.Positions (:, 2) double {mustBeReal, mustBeFinite} = zeros(0, 2)
                options.StrengthScale (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 1
                options.Times (:, 1) double {mustBeReal, mustBeFinite} = zeros(0, 1)
            end
            assert(isempty(options.Positions) || (size(options.Positions, 1) == count ...
                && all(abs(options.Positions) <= obj.DomainSize/2, "all")), ...
                "RippleSimulator:SourcePosition", "Reserved positions must lie inside the domain.");
            assert(count <= obj.AvailableCount, "RippleSimulator:SourceCapacity", ...
                "There is insufficient input capacity at this resolution. Reduce the grid resolution, " ...
                + "let the waves settle, or clear the surface.");
            positions = options.Positions;
            if isempty(positions)
                positions = NaN(count, 2);
            end
            times = options.Times;
            if isempty(times)
                times = NaN(count, 1);
            else
                assert(numel(times) == count && all(isfinite(times) & times >= obj.CurrentTime), ...
                    "RippleSimulator:ScheduledTime", ...
                    "Reserved times must be finite and no earlier than the current time.");
            end
            reservations = repmat(struct(Position=[NaN, NaN], Mapping=[], ...
                StrengthScale=options.StrengthScale, Time=NaN), 1, count);
            for index = 1:count
                reservations(index).Position = positions(index, :);
                reservations(index).Time = times(index);
            end
            remaining = obj.OperatorByteLimit - mappingBytes(obj.Events) - mappingBytes(obj.Reservations);
            reservations = prepareReservations(reservations, obj.Cache.getTable(obj.SelectedTable), ...
                obj.Coordinates, remaining);
            additionalSlope = reservationSlope([obj.Reservations, reservations], obj.Cache, ...
                obj.SelectedTable, obj.Source);
            loadingCache = obj.validateLoading(obj.Cache, obj.SelectedTable, obj.Source, obj.CurrentTime, ...
                Count=obj.ReservedCount+double(count), AdditionalSlope=additionalSlope, ...
                Reservations=[obj.Reservations, reservations], LoadingCache=obj.LoadingCache);
            obj.LoadingCache = loadingCache;
            obj.Reservations = [obj.Reservations, reservations];
            obj.ReservedCount = obj.ReservedCount + double(count);
            obj.Revision = obj.Revision + 1;
        end

        function cancelReservation(obj, count)
        % CANCELRESERVATION Release the most recently reserved inputs.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                count (1, 1) double {mustBeInteger, mustBeNonnegative} = obj.ReservedCount
            end
            assert(count <= obj.ReservedCount, "RippleSimulator:ReservationCount", ...
                "The release count cannot exceed the reserved input count.");
            obj.ReservedCount = obj.ReservedCount - count;
            obj.Reservations = obj.Reservations(1:obj.ReservedCount);
            obj.Revision = obj.Revision + 1;
        end

        function retimeReservations(obj, time, factor)
        % RETIMERESERVATIONS Validate the pending physical times before changing playback rate.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                factor (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
            end
            if obj.ReservedCount == 0
                return
            end
            reservations = obj.Reservations;
            for index = 1:numel(reservations)
                reservations(index).Time = time+factor*(reservations(index).Time-time);
            end
            obj.validateLoading(obj.Cache, obj.SelectedTable, obj.Source, time, ...
                Count=numel(reservations), Reservations=reservations, ...
                AdditionalSlope=reservationSlope(reservations, obj.Cache, obj.SelectedTable, obj.Source));
            obj.Reservations = reservations;
            obj.Revision = obj.Revision+1;
        end

        function identifier = addSource(obj, time, position, options)
        % ADDSOURCE Accept one manual-equivalent source at its physical timestamp.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                time (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                position (1, 2) {mustBeNumeric, mustBeReal, mustBeFinite}
                options.Reserved (1, 1) {mustBeNumericOrLogical, mustBeMember(options.Reserved, [0, 1])} = false
                options.StrengthScale (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 1
            end
            assert(time >= obj.CurrentTime, "RippleSimulator:SimulationTime", ...
                "A source cannot be inserted before the processed physical time.");
            assert(all(abs(position) <= obj.DomainSize/2), "RippleSimulator:SourcePosition", ...
                "The source position must lie inside the domain.");
            if options.Reserved
                available = obj.ReservedCount;
            else
                available = obj.AvailableCount;
            end
            assert(available >= 1, "RippleSimulator:SourceCapacity", ...
                "No input slot is available at this resolution. Reduce the grid resolution, " ...
                + "let the waves settle, or clear the surface.");
            loadingCache = obj.LoadingCache;
            mapping = [];
            if options.Reserved
                positions = vertcat(obj.Reservations.Position);
                matches = all(isnan(positions), 2) | all(positions == position, 2);
                reservationIndex = find(matches ...
                    & [obj.Reservations.StrengthScale]' == options.StrengthScale, 1);
                assert(~isempty(reservationIndex), "RippleSimulator:ReservedPosition", ...
                    "The source position and strength have no reserved input.");
                reservation = obj.Reservations(reservationIndex);
                mapping = reservation.Mapping;
                assert(isnan(reservation.Time) || abs(time-reservation.Time) <= 128*eps(max(1, time)), ...
                    "RippleSimulator:ScheduledTime", "A reserved source must retain its accepted physical time.");
            end
            table = obj.Cache.getTable(obj.SelectedTable);
            if isempty(mapping) && obj.ReflectionCoefficient > 0
                events = obj.Events([obj.Events.TableIndex] == obj.SelectedTable);
                if ~isempty(events)
                    positions = vertcat(events.Position);
                    matched = find(all(positions == double(position), 2), 1);
                    if ~isempty(matched)
                        mapping = events(matched).Mapping;
                    end
                end
            end
            if isempty(mapping)
                remaining = obj.OperatorByteLimit - mappingBytes(obj.Events) - mappingBytes(obj.Reservations);
                mapping = mapPosition(table, obj.Coordinates, double(position), remaining);
            end
            if ~options.Reserved && obj.ReflectionCoefficient > 0
                pending = struct(Position=double(position), Mapping=mapping, ...
                    StrengthScale=options.StrengthScale, Time=double(time));
                additionalSlope = options.StrengthScale*obj.Source.PressureImpulse*mapping.MaximumSlope ...
                    + reservationSlope(obj.Reservations, obj.Cache, obj.SelectedTable, obj.Source);
                loadingCache = obj.validateLoading(obj.Cache, obj.SelectedTable, obj.Source, double(time), ...
                    Count=obj.ReservedCount+1, AdditionalSlope=additionalSlope, ...
                    Reservations=[obj.Reservations, pending], LoadingCache=loadingCache);
            elseif ~options.Reserved
                pending = struct(Position=double(position), Mapping=mapping, ...
                    StrengthScale=options.StrengthScale, Time=double(time));
                loadingCache = obj.validateLoading(obj.Cache, obj.SelectedTable, obj.Source, double(time), ...
                    Count=sum([obj.Reservations.StrengthScale]) + options.StrengthScale, ...
                    Reservations=[obj.Reservations, pending], LoadingCache=loadingCache);
            end
            radius = norm(obj.DomainSize/2 + abs(double(position)));
            radius = min(sqrt(2)*obj.DomainSize, ceil(32*radius/obj.DomainSize)*obj.DomainSize/32);
            if isfinite(obj.SettlingPeriods)
                cache = obj.Cache;
                radius = cache.MaximumRadius;
                envelopeIndex = cache.getEnvelopeIndex(obj.SelectedTable);
            else
                [cache, envelopeIndex] = obj.Cache.prepareEnvelope(obj.SelectedTable, radius);
            end
            identifier = obj.AcceptedCount + 1;
            if obj.ReflectionCoefficient > 0
                maximumSlope = mapping.MaximumSlope;
            else
                maximumSlope = cache.futureSlope(obj.SelectedTable, 0);
            end
            event = struct(Time=double(time), Position=double(position), ...
                Strength=options.StrengthScale*obj.Source.PressureImpulse, ...
                TableIndex=obj.SelectedTable, EnvelopeIndex=envelopeIndex, ObservationRadius=radius, ...
                Mapping=mapping, MaximumSlope=maximumSlope, Id=identifier);
            animation = obj.prepareAnimation(event, table, double(time));
            obj.advanceTo(double(time), CompactHistory=false);
            obj.Cache = cache;
            obj.LoadingCache = loadingCache;
            if event.Strength > 0
                obj.Events(end + 1) = event;
                if ~isempty(animation)
                    obj.Animations{event.TableIndex} = animation;
                    obj.AnimatedIds(end+1) = event.Id;
                end
            end
            obj.AcceptedCount = identifier;
            obj.ReservedCount = obj.ReservedCount - double(options.Reserved);
            if options.Reserved
                obj.Reservations(reservationIndex) = [];
            end
            obj.compactHistory();
            obj.Revision = obj.Revision + 1;
        end

        function advanceTo(obj, time, options)
        % ADVANCETO Process a physical timestamp without imposing a frame step.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                time (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                options.CompactHistory (1, 1) logical = true
            end
            assert(time >= obj.CurrentTime, "RippleSimulator:SimulationTime", ...
                "Physical time cannot move backward.");
            if isfinite(obj.SettlingPeriods)
                retired = false(1, obj.ActiveCount);
                for group = reshape(unique([obj.Events.TableIndex]), 1, [])
                    selected = [obj.Events.TableIndex] == group;
                    table = obj.Cache.getTable(group);
                    duration = obj.SettlingPeriods*table.TimeScale;
                    retired(selected) = double(time) - [obj.Events(selected).Time] >= duration - 8*eps(duration);
                end
                obj.RetiredCount = obj.RetiredCount + nnz(retired);
                obj.Events(retired) = [];
                obj.CurrentTime = double(time);
                obj.advanceAnimations();
                if options.CompactHistory && any(retired)
                    obj.compactHistory();
                end
                obj.Revision = obj.Revision + 1;
                return
            end
            omitted = obj.omittedBound(double(time));
            retired = false(1, obj.ActiveCount);
            records = zeros(obj.ActiveCount, 3);
            count = 0;
            for index = 1:obj.ActiveCount
                event = obj.Events(index);
                table = obj.Cache.getTable(event.TableIndex);
                scale = app.internal.responses.SettlingEnvelope.sample( ...
                    double(time) - event.Time, table.TimeScale, obj.SettlingPeriods);
                if scale == 0
                    retired(index) = true;
                    continue
                end
                if isfinite(obj.SettlingPeriods)
                    continue
                end
                envelope = obj.Cache.Envelopes{event.EnvelopeIndex}.Envelope;
                contribution = event.Strength*envelope.bound(double(time) - event.Time);
                if all(omitted + contribution <= obj.RestBudget)
                    omitted = omitted + contribution;
                    retired(index) = true;
                    count = count + 1;
                    records(count, :) = [event.Time, event.Strength, event.EnvelopeIndex];
                end
            end
            obj.Retired = [obj.Retired; records(1:count, :)];
            obj.RetiredCount = obj.RetiredCount + nnz(retired);
            obj.Events(retired) = [];
            obj.CurrentTime = double(time);
            if options.CompactHistory
                obj.compactHistory();
            end
            obj.Revision = obj.Revision + 1;
        end

        function value = snapshot(obj, options)
        % SNAPSHOT Sample the accepted state on the current observation grid.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                options.Derivatives (1, 1) {mustBeNumericOrLogical, ...
                    mustBeMember(options.Derivatives, [0, 1])} = false
            end
            value = obj.sampleEvents(obj.Events, obj.Coordinates, logical(options.Derivatives));
            value.GeometryRevision = obj.GeometryRevision;
        end

        function plan = prepareGrid(obj, resolution)
        % PREPAREGRID Resample every active event at the current physical time.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                resolution (1, 1) {mustBeNumeric, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(resolution, 51), mustBeLessThanOrEqual(resolution, 801)}
            end
            validateSampling(obj.DomainSize, double(resolution), obj.Source.Wavelength);
            needed = 12*double(resolution)^2*(obj.ActiveCount + obj.ReservedCount);
            assert(needed <= obj.MappingByteLimit, "RippleSimulator:MappingMemory", ...
                "The current and reserved waves exceed the spatial-map budget at this resolution. " ...
                + "Choose fewer grid nodes, wait for waves to settle, or clear the surface.");
            coordinates = linspace(-obj.DomainSize/2, obj.DomainSize/2, double(resolution));
            cache = obj.Cache.prepareGrid(double(resolution));
            events = obj.Events;
            remaining = obj.OperatorByteLimit;
            for index = 1:numel(events)
                table = cache.getTable(events(index).TableIndex);
                validateSampling(obj.DomainSize, double(resolution), table.Source.Wavelength);
                events(index).Mapping = mapPosition(table, coordinates, events(index).Position, remaining);
                remaining = remaining - events(index).Mapping.OperatorBytes;
            end
            reservations = prepareReservations(obj.Reservations, cache.getTable(obj.SelectedTable), ...
                coordinates, remaining);
            value = obj.sampleEvents(events, coordinates, false);
            value.GeometryRevision = obj.GeometryRevision + 1;
            plan = struct(Owner=obj, Revision=obj.Revision, Resolution=double(resolution), ...
                Coordinates=coordinates, Events=events, Reservations=reservations, Snapshot=value, Cache=cache);
            [plan.Animations, plan.AnimatedIds] = obj.rebuildAnimations(events, cache, double(resolution));
        end

        function commitGrid(obj, plan)
        % COMMITGRID Install a prepared grid without changing event ages or sources.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
                plan (1, 1) struct
            end
            obj.validateRevision(plan);
            obj.LoadingCache = obj.LoadingCache.clear();
            obj.Coordinates = plan.Coordinates;
            obj.GridResolution = plan.Resolution;
            obj.Events = plan.Events;
            obj.Reservations = plan.Reservations;
            obj.Cache = plan.Cache;
            obj.Animations = plan.Animations;
            obj.AnimatedIds = plan.AnimatedIds;
            obj.GeometryRevision = obj.GeometryRevision + 1;
            obj.Revision = obj.Revision + 1;
        end

        function value = renderSnapshot(obj)
        % RENDERSNAPSHOT Sample bounded display caches at the current physical time.
            value = obj.sampleEvents(obj.Events, obj.Coordinates, false, true);
            value.GeometryRevision = obj.GeometryRevision;
        end

        function clear(obj)
        % CLEAR Return to exact equilibrium without resetting physical time.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
            end
            obj.Events = obj.Events([]);
            obj.LoadingCache = obj.LoadingCache.clear();
            obj.Animations = cell(1, 8);
            obj.AnimatedIds = zeros(1, 0);
            obj.Retired = zeros(0, 3);
            obj.FrozenOmittedBound = zeros(1, 3);
            obj.RetiredCount = 0;
            obj.ReservedCount = 0;
            obj.Reservations = obj.Reservations([]);
            obj.LateCache.clear();
            obj.Revision = obj.Revision + 1;
        end

        function value = diagnostics(obj)
        % DIAGNOSTICS Return source and numerical-error metadata without grid maps.
            arguments
                obj (1, 1) app.internal.simulation.Simulation
            end
            events = rmfield(obj.Events, ["Mapping", "MaximumSlope"]);
            selectedTable = obj.Cache.getTable(obj.SelectedTable);
            value = struct(Time=obj.CurrentTime, ActiveCount=obj.ActiveCount, ...
                AcceptedCount=obj.AcceptedCount, ReservedCount=obj.ReservedCount, Events=events, ...
                OmittedBound=obj.omittedBound(obj.CurrentTime), RestBudget=obj.RestBudget, ...
                RetiredCount=obj.RetiredCount, HistoryRecords=size(obj.Retired, 1), HistoryLimit=obj.HistoryLimit, ...
                EnvelopeCount=numel(obj.Cache.Envelopes), EnvelopeLimit=obj.Cache.EnvelopeLimit, ...
                FrozenOmittedBound=obj.FrozenOmittedBound, CacheBytes=obj.CacheBytes, ...
                AnimationBytes=obj.animationBytes(), AnimationByteLimit=obj.AnimationByteLimit, ...
                LoadingCache=obj.LoadingCache.diagnostics(), ...
                LateCache=obj.LateCache.diagnostics(), ...
                MappingBytes=radialMappingBytes(obj.Events), MappingByteLimit=obj.MappingByteLimit, ...
                OperatorBytes=mappingBytes(obj.Events) + mappingBytes(obj.Reservations), ...
                OperatorByteLimit=obj.OperatorByteLimit, ...
                FutureSlope=obj.activeSlope(obj.CurrentTime), SlopeLimit=obj.SlopeLimit, ...
                SettlingPeriods=obj.SettlingPeriods, ...
                ReferencePeriod=selectedTable.Period, SettlingTimeScale=selectedTable.TimeScale, ...
                SourceLifetime=obj.SettlingPeriods*selectedTable.TimeScale, ...
                ReflectionCoefficient=obj.ReflectionCoefficient, ...
                ReservedSlope=reservationSlope(obj.Reservations, obj.Cache, obj.SelectedTable, obj.Source));
        end
    end

    methods (Access = private)
        function bytes = animationBytes(obj)
            present = ~cellfun(@isempty, obj.Animations);
            bytes = sum(cellfun(@(animation) animation.MemoryBytes, obj.Animations(present)));
        end

        function animation = prepareAnimation(obj, event, table, time)
            animation = [];
            if ~obj.AccumulateDisplay || ~isfinite(obj.SettlingPeriods) || event.Strength == 0
                return
            end
            images = isa(table, "app.internal.responses.ImageResponse");
            if ~images && (~isa(table, "app.internal.responses.ResponseTable") || isempty(table.Lattice) ...
                    || isempty(event.Mapping.LatticeIndices))
                return
            end
            remaining = obj.AnimationByteLimit;
            for group = 1:numel(obj.Animations)
                if group ~= event.TableIndex && ~isempty(obj.Animations{group})
                    remaining = remaining-obj.Animations{group}.MemoryBytes;
                end
            end
            if images
                animation = obj.Animations{event.TableIndex};
                if isempty(animation)
                    animation = app.internal.playback.PreparedImageAnimation(table, obj.GridResolution, ...
                        obj.SettlingPeriods, time);
                else
                    animation = animation.advanceTo(time);
                end
                required = app.internal.playback.PreparedImageAnimation.estimateBytes( ...
                    obj.GridResolution, obj.SettlingPeriods, animation.SourceCount+1);
                if required > remaining
                    animation = [];
                    return
                end
                animation = animation.add(event.Time, event.Strength, event.Mapping, event.Id);
                return
            end
            previous = obj.Animations{event.TableIndex};
            count = 1;
            if ~isempty(previous)
                previous = previous.advanceTo(time);
                count = count+previous.SourceCount;
            end
            required = app.internal.playback.PreparedAnimation.estimateBytes( ...
                obj.GridResolution, obj.SettlingPeriods, count);
            if required > remaining
                return
            end
            if isempty(previous)
                forcingDuration = 4*table.Period*(table.Source.Mode == "Wavemaker" && table.TimeScale > table.Period);
                animation = app.internal.playback.PreparedAnimation(table.Lattice, table.TimeScale, ...
                    obj.SettlingPeriods, time, ForcingDuration=forcingDuration);
            else
                animation = previous;
            end
            animation = animation.add(event.Time, event.Strength, event.Mapping.LatticeIndices);
        end

        function advanceAnimations(obj)
            obj.AnimatedIds = obj.AnimatedIds(ismember(obj.AnimatedIds, [obj.Events.Id]));
            for group = 1:numel(obj.Animations)
                if isempty(obj.Animations{group})
                    continue
                end
                if ~any([obj.Events.TableIndex] == group & ismember([obj.Events.Id], obj.AnimatedIds))
                    obj.Animations{group} = [];
                else
                    obj.Animations{group} = obj.Animations{group}.advanceTo(obj.CurrentTime);
                end
            end
        end

        function [animations, identifiers] = rebuildAnimations(obj, events, cache, resolution)
            animations = cell(1, 8);
            identifiers = zeros(1, numel(events));
            retained = 0;
            if ~obj.AccumulateDisplay || ~isfinite(obj.SettlingPeriods)
                identifiers = zeros(1, 0);
                return
            end
            remaining = obj.AnimationByteLimit;
            for group = reshape(unique([events.TableIndex]), 1, [])
                table = cache.getTable(group);
                images = isa(table, "app.internal.responses.ImageResponse");
                if ~images && (~isa(table, "app.internal.responses.ResponseTable") || isempty(table.Lattice))
                    continue
                end
                selected = events([events.TableIndex] == group);
                if ~images
                    selected = selected(arrayfun(@(event) ~isempty(event.Mapping.LatticeIndices), selected));
                end
                if isempty(selected)
                    continue
                end
                if images
                    required = app.internal.playback.PreparedImageAnimation.estimateBytes( ...
                        resolution, obj.SettlingPeriods, numel(selected));
                else
                    required = app.internal.playback.PreparedAnimation.estimateBytes( ...
                        resolution, obj.SettlingPeriods, numel(selected));
                end
                if required > remaining
                    continue
                end
                if images
                    animation = app.internal.playback.PreparedImageAnimation(table, resolution, ...
                        obj.SettlingPeriods, obj.CurrentTime);
                    for event = selected
                        animation = animation.add(event.Time, event.Strength, event.Mapping, event.Id);
                    end
                else
                    forcingDuration = 4*table.Period* ...
                        (table.Source.Mode == "Wavemaker" && table.TimeScale > table.Period);
                    animation = app.internal.playback.PreparedAnimation(table.Lattice, table.TimeScale, ...
                        obj.SettlingPeriods, obj.CurrentTime, ForcingDuration=forcingDuration);
                    for event = selected
                        animation = animation.add(event.Time, event.Strength, event.Mapping.LatticeIndices);
                    end
                end
                animations{group} = animation;
                identifiers(retained+(1:numel(selected))) = [selected.Id];
                retained = retained + numel(selected);
                remaining = remaining-required;
            end
            identifiers = identifiers(1:retained);
        end

        function loadingCache = validateLoading(obj, cache, selected, source, time, options)
            arguments
                obj
                cache
                selected
                source
                time
                options.LoadingCache (1, 1) app.internal.simulation.LoadingCache = ...
                    app.internal.simulation.LoadingCache(ByteLimit=0)
                options.Count (1, 1) double = 1
                options.AdditionalSlope (1, 1) double = NaN
                options.Reservations (1, :) struct = ...
                    struct("Position", {}, "Mapping", {}, "StrengthScale", {}, "Time", {})
            end
            loadingCache = options.LoadingCache;
            unitSlope = cache.futureSlope(selected, 0);
            centeredSlope = unitSlope;
            if obj.ReflectionCoefficient > 0
                table = cache.getTable(selected);
                centeredSlope = table.slopeBound([0, 0]);
            end
            if source.PressureImpulse*centeredSlope > obj.SlopeLimit && isfinite(obj.SettlingPeriods)
                table = cache.getTable(selected);
                duration = obj.SettlingPeriods*table.TimeScale;
                if obj.ReflectionCoefficient == 0
                    centeredSlope = cache.futureSpatialSlope(selected, table.futureSlope(0), 0, FinalAge=duration);
                else
                    envelope = cache.loadingEnvelope(selected);
                    record = struct(Envelope=envelope, Time=0, Position=[0, 0], Strength=1, Duration=duration);
                    centeredSlope = min(centeredSlope, app.internal.numerics.boundImageSlopes( ...
                        record, obj.DomainSize, 0, 0, obj.SlopeLimit/source.PressureImpulse));
                end
            end
            assert(source.PressureImpulse*centeredSlope <= obj.SlopeLimit, ...
                "RippleSimulator:SourceStrength", ...
                "One source exceeds the supported small-slope range. Reduce the pressure strength to %.4g Pa s.", ...
                obj.SlopeLimit/centeredSlope);
            if options.Count > 0
                omitted = obj.omittedBound(time);
                maximum = omitted(3) + sum([obj.Events.Strength].*[obj.Events.MaximumSlope]);
                additional = options.AdditionalSlope;
                if isnan(additional)
                    additional = options.Count*source.PressureImpulse*unitSlope;
                end
                if maximum + additional <= obj.SlopeLimit
                    return
                end
                available = max(0, obj.SlopeLimit - obj.activeSlope(time));
                if additional > available && ~isempty(options.Reservations)
                    if obj.ReflectionCoefficient == 0
                        localized = obj.spatialLoading(cache, selected, source, time, options.Reservations);
                        if localized <= obj.SlopeLimit
                            return
                        end
                    end
                    if isfinite(obj.SettlingPeriods)
                        records = obj.loadingRecords(cache, selected, source, options.Reservations);
                        [loadingCache, scheduled] = loadingCache.bound( ...
                            records, obj.DomainSize, time, omitted(3), obj.SlopeLimit);
                        if scheduled <= obj.SlopeLimit
                            return
                        end
                    end
                end
                if ~isnan(options.AdditionalSlope)
                    assert(options.AdditionalSlope <= available, "RippleSimulator:WaveLoading", ...
                        "The sources exceed the conservative small-slope limit. Reduce the pressure strength, " ...
                        + "wait for the existing waves to settle, or clear the surface.");
                    return
                end
                maximumPressure = available/(options.Count*unitSlope);
                assert(source.PressureImpulse <= maximumPressure, "RippleSimulator:WaveLoading", ...
                    "This input exceeds the conservative small-slope limit. Reduce the pressure strength, " ...
                    + "wait for the existing waves to settle, or clear the surface.");
            end
        end

        function value = activeSlope(obj, time)
            omitted = obj.omittedBound(time);
            value = omitted(3);
            for group = reshape(unique([obj.Events.TableIndex]), 1, [])
                events = obj.Events([obj.Events.TableIndex] == group);
                table = obj.Cache.getTable(group);
                ages = time - [events.Time];
                scale = app.internal.responses.SettlingEnvelope.sample(ages, table.TimeScale, obj.SettlingPeriods);
                if obj.ReflectionCoefficient > 0
                    mappings = [events.Mapping];
                    bounds = [mappings.MaximumSlope];
                else
                    bounds = zeros(size(ages));
                    for envelope = reshape(unique([events.EnvelopeIndex]), 1, [])
                        selected = [events.EnvelopeIndex] == envelope;
                        bounds(selected) = obj.Cache.futureSlope(group, ages(selected), EnvelopeIndex=envelope);
                    end
                end
                value = value + sum(scale.*[events.Strength].*bounds);
            end
        end

        function value = spatialLoading(obj, cache, selected, source, time, reservations)
        % SPATIALLOADING Bound simultaneous slopes over complete Cartesian cells.
            omitted = obj.omittedBound(time);
            total = omitted(3);
            for event = obj.Events
                table = cache.getTable(event.TableIndex);
                age = time-event.Time;
                scale = app.internal.responses.SettlingEnvelope.sample(age, table.TimeScale, obj.SettlingPeriods);
                spatial = positionSlope(table, obj.Coordinates, event.Position, event.Mapping);
                bound = cache.futureSpatialSlope(event.TableIndex, spatial, age, ...
                    FinalAge=obj.SettlingPeriods*table.TimeScale);
                total = total+event.Strength*scale*bound;
            end
            table = cache.getTable(selected);
            for reservation = reservations
                if any(isnan(reservation.Position))
                    bound = cache.futureSlope(selected, 0);
                else
                    spatial = positionSlope(table, obj.Coordinates, reservation.Position, reservation.Mapping);
                    bound = cache.futureSpatialSlope(selected, spatial, 0, ...
                        FinalAge=obj.SettlingPeriods*table.TimeScale);
                end
                total = total+source.PressureImpulse*reservation.StrengthScale*bound;
            end
            value = max(total, [], "all")*(1+128*eps);
        end

        function records = loadingRecords(obj, cache, selected, source, reservations)
            template = struct(Envelope=[], Time=0, Position=[0, 0], Strength=0, Duration=0, TableIndex=0);
            records = repmat(template, 1, numel(obj.Events)+numel(reservations));
            for index = 1:numel(obj.Events)
                event = obj.Events(index);
                envelope = cache.loadingEnvelope(event.TableIndex);
                records(index) = struct(Envelope=envelope, Time=event.Time, Position=event.Position, ...
                    Strength=event.Strength, Duration=obj.SettlingPeriods*envelope.TimeScale, ...
                    TableIndex=event.TableIndex);
            end
            envelope = cache.loadingEnvelope(selected);
            for index = 1:numel(reservations)
                reservation = reservations(index);
                records(numel(obj.Events)+index) = struct(Envelope=envelope, Time=reservation.Time, ...
                    Position=reservation.Position, Strength=source.PressureImpulse*reservation.StrengthScale, ...
                    Duration=obj.SettlingPeriods*envelope.TimeScale, TableIndex=selected);
            end
        end

        function validateRevision(obj, plan)
            assert(isfield(plan, "Owner") && isequal(plan.Owner, obj), "RippleSimulator:ForeignPreparation", ...
                "The prepared operation belongs to a different simulation.");
            assert(plan.Revision == obj.Revision, "RippleSimulator:StalePreparation", ...
                "The simulation changed after this operation was prepared.");
        end

        function value = omittedBound(obj, time)
            value = obj.FrozenOmittedBound;
            groups = unique(obj.Retired(:, 3))';
            for group = groups
                selected = obj.Retired(:, 3) == group;
                envelope = obj.Cache.Envelopes{group}.Envelope;
                ages = time - obj.Retired(selected, 1);
                index = discretize(ages, [envelope.Times, Inf]);
                assert(all(isfinite(index)), "RippleSimulator:RetirementAge", ...
                    "An omitted source predates its validated future envelope.");
                value = value + sum(envelope.Bounds(index, :).*obj.Retired(selected, 2), 1);
            end
        end

        function compactHistory(obj)
            expired = false(size(obj.Retired, 1), 1);
            for group = unique(obj.Retired(:, 3))'
                envelope = obj.Cache.Envelopes{group}.Envelope;
                selected = obj.Retired(:, 3) == group ...
                    & obj.CurrentTime - obj.Retired(:, 1) >= envelope.Times(end);
                obj.FrozenOmittedBound = obj.FrozenOmittedBound ...
                    + sum(obj.Retired(selected, 2))*envelope.Bounds(end, :);
                expired = expired | selected;
            end
            obj.Retired(expired, :) = [];
            required = unique([[obj.Events.EnvelopeIndex], obj.Retired(:, 3)']);
            [obj.Cache, mapping] = obj.Cache.compactEnvelopes(required);
            if isequal(mapping, 1:numel(mapping))
                return
            end
            for index = 1:obj.ActiveCount
                obj.Events(index).EnvelopeIndex = mapping(obj.Events(index).EnvelopeIndex);
            end
            obj.Retired(:, 3) = reshape(mapping(obj.Retired(:, 3)), [], 1);
        end

        function value = sampleEvents(obj, events, coordinates, derivatives, prepared)
            if nargin < 5
                prepared = false;
            end
            elevation = zeros(numel(coordinates), numel(coordinates));
            velocity = zeros(0);
            gradientX = zeros(0);
            gradientY = zeros(0);
            if derivatives
                velocity = zeros(size(elevation));
                gradientX = zeros(size(elevation));
                gradientY = zeros(size(elevation));
            end
            sampled = false(1, numel(events));
            if prepared && ~derivatives
                groups = [events.TableIndex];
                buffered = ismember([events.Id], obj.AnimatedIds);
                for group = reshape(unique(groups(buffered)), 1, [])
                    if isa(obj.Animations{group}, "app.internal.playback.PreparedImageAnimation")
                        elevation = elevation+obj.Animations{group}.sample(events(groups == group & buffered));
                    else
                        elevation = elevation+obj.Animations{group}.sample();
                    end
                    sampled = sampled | (buffered & groups == group);
                end
            end
            if prepared && ~derivatives && obj.ReflectionCoefficient == 0
                for group = reshape(unique(groups), 1, [])
                    table = obj.Cache.getTable(group);
                    if isempty(table.Lattice)
                        continue
                    end
                    selected = find(groups == group & ~sampled);
                    ages = obj.CurrentTime-[events(selected).Time];
                    mappings = [events(selected).Mapping];
                    supported = ages > 0 & ages <= table.Times(end) ...
                        & arrayfun(@(mapping) ~isempty(mapping.LatticeIndices), mappings);
                    selected = selected(supported);
                    if isempty(selected)
                        continue
                    end
                    ages = ages(supported);
                    scale = app.internal.responses.SettlingEnvelope.sample(ages, table.TimeScale, obj.SettlingPeriods);
                    strengths = scale.*[events(selected).Strength];
                    elevation = elevation + table.Lattice.accumulate(mappings(supported), ages, strengths);
                    sampled(selected) = true;
                end
            end
            for index = reshape(find(~sampled), 1, [])
                event = events(index);
                table = obj.Cache.getTable(event.TableIndex);
                age = obj.CurrentTime - event.Time;
                if age == 0 && ~derivatives
                    continue
                end
                if isa(table, "app.internal.responses.ResponseTable") && isempty(event.Mapping.Index)
                    [x, y] = meshgrid(coordinates-event.Position(1), coordinates-event.Position(2));
                    event.Mapping = table.mapRadii(hypot(x, y));
                end
                [scale, scaleDerivative] = app.internal.responses.SettlingEnvelope.sample( ...
                    age, table.TimeScale, obj.SettlingPeriods);
                if derivatives
                    if obj.ReflectionCoefficient > 0
                        [contribution, sourceVelocity, slopeX, slopeY] = table.sample(event.Mapping, age);
                    else
                        [contribution, sourceVelocity, slope] = obj.sampleResponse(table, event.Mapping, age);
                        [x, y] = meshgrid(coordinates - event.Position(1), coordinates - event.Position(2));
                        radius = hypot(x, y);
                        radius(radius == 0) = 1;
                        slopeX = slope.*x./radius;
                        slopeY = slope.*y./radius;
                    end
                    velocity = velocity + event.Strength*(scale*sourceVelocity + scaleDerivative*contribution);
                    gradientX = gradientX + scale*event.Strength*slopeX;
                    gradientY = gradientY + scale*event.Strength*slopeY;
                elseif prepared && isa(table, "app.internal.responses.ResponseTable") ...
                        && ~isempty(table.Lattice) && ~isempty(event.Mapping.LatticeIndices) ...
                        && age <= table.Times(end)
                    contribution = table.Lattice.sample(event.Mapping.LatticeIndices, age);
                else
                    contribution = obj.sampleResponse(table, event.Mapping, age);
                end
                elevation = elevation + scale*event.Strength*contribution;
            end
            value = struct(Elevation=elevation, Velocity=velocity, GradientX=gradientX, GradientY=gradientY, ...
                Coordinates=coordinates, DomainSize=obj.DomainSize, Time=obj.CurrentTime, IsAtRest=isempty(events));
        end

        function varargout = sampleResponse(obj, table, mapping, age)
            if age <= table.Times(end)
                [varargout{1:nargout}] = table.sample(mapping, age);
            elseif age >= 64*table.Period
                [varargout{1:nargout}] = obj.LateCache.sample(table, mapping, age);
            else
                [varargout{1:nargout}] = table.sampleDirect(mapping, age);
            end
        end
    end
end

function value = positionSlope(table, coordinates, position, mapping)
    if isstruct(mapping) && isfield(mapping, "LoadingBounds") && ~isempty(mapping.LoadingBounds)
        value = mapping.LoadingBounds;
        return
    end
    intervalCount = 101;
    edges = linspace(coordinates(1), coordinates(end), intervalCount+1);
    [left, bottom] = meshgrid(edges(1:end-1));
    width = edges(2)-edges(1);
    width = width*(1+32*eps);
    near = hypot(max(max(left-position(1), position(1)-left-width), 0), ...
        max(max(bottom-position(2), position(2)-bottom-width), 0));
    far = hypot(max(abs(left-position(1)), abs(left+width-position(1))), ...
        max(abs(bottom-position(2)), abs(bottom+width-position(2))));
    value = table.spatialSlope(near, far);
end

function mapping = mapPosition(table, coordinates, position, byteLimit)
    if isa(table, "app.internal.responses.ImageResponse")
        mapping = table.mapPosition(coordinates, position, max(0, byteLimit));
        return
    end
    mapping = [];
    loadingBytes = 8*101^2;
    retainLoading = byteLimit >= loadingBytes;
    byteLimit = byteLimit-retainLoading*loadingBytes;
    if ~isempty(table.Lattice) && table.Lattice.Resolution == numel(coordinates)
        indices = table.Lattice.mapPosition(position);
        if ~isempty(indices)
            mapping = struct(Index=zeros(0, 1, "uint32"), Fraction=zeros(0, 1), Step=table.RadialStep, ...
                Shape=size(indices), RadiusCount=numel(table.Radii), Operator=sparse(0, 0), OperatorBytes=0, ...
                SpatialBasis=zeros(0, 0), LatticeIndices=indices);
        end
    end
    if isempty(mapping)
        [x, y] = meshgrid(coordinates - position(1), coordinates - position(2));
        mapping = table.mapRadii(hypot(x, y), OperatorByteLimit=max(0, byteLimit));
    end
    mapping.LoadingBounds = zeros(0);
    if retainLoading
        mapping.LoadingBounds = positionSlope(table, coordinates, position, mapping);
        mapping.OperatorBytes = mapping.OperatorBytes+loadingBytes;
    end
end

function value = reservationSlope(reservations, cache, selected, source)
    value = 0;
    for index = 1:numel(reservations)
        mapping = reservations(index).Mapping;
        if isstruct(mapping) && isfield(mapping, "MaximumSlope")
            value = value + reservations(index).StrengthScale*mapping.MaximumSlope;
        else
            value = value + reservations(index).StrengthScale*cache.futureSlope(selected, 0);
        end
    end
    value = source.PressureImpulse*value;
end

function value = mappingBytes(records)
    value = 0;
    for index = 1:numel(records)
        if ~isempty(records(index).Mapping)
            value = value + records(index).Mapping.OperatorBytes;
        end
    end
end

function value = radialMappingBytes(records)
    value = 0;
    for record = records
        mapping = record.Mapping;
        if isfield(mapping, "Index")
            value = value + 4*numel(mapping.Index) + 8*numel(mapping.Fraction) ...
                + 4*numel(mapping.LatticeIndices);
        end
    end
end

function reservations = prepareReservations(reservations, table, coordinates, byteLimit)
    for index = 1:numel(reservations)
        if all(isnan(reservations(index).Position))
            reservations(index).Mapping = [];
        else
            reservations(index).Mapping = mapPosition(table, coordinates, reservations(index).Position, byteLimit);
            byteLimit = byteLimit - reservations(index).Mapping.OperatorBytes;
        end
    end
end

function validateSampling(domainSize, resolution, wavelength)
    assert((resolution - 1)*wavelength/domainSize >= 6, "RippleSimulator:GridBandwidth", ...
        "The display grid requires at least six intervals per characteristic wavelength. " ...
        + "Increase the grid resolution.");
    assert(domainSize/wavelength <= app.internal.input.Source.MaximumDomainRatio*(1+32*eps), ...
        "RippleSimulator:SourceExtent", "The domain cannot exceed 26 characteristic source wavelengths.");
end
