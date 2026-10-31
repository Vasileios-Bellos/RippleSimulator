classdef (Sealed) ReflectingSimulation < app.internal.simulation.WaveExperiment
    % REFLECTINGSIMULATION Evolve waves between ideal free-slip square walls.
    %   Each source retains its own cosine spectrum and full viscous response.
    %   Observation grids do not alter the physical state. Without finite
    %   settling, omission requires cumulative bounds on all future elevation,
    %   velocity, and surface slope.

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
        Capacity (1, 1) double = 128
        RestBudget (1, 3) double
        MappingByteLimit (1, 1) double = 268435456
        AnimationByteLimit (1, 1) double = 268435456
        HistoryLimit (1, 1) double = 65536
        SettlingPeriods (1, 1) double = Inf
    end

    properties (Dependent, SetAccess = private)
        ActiveCount (1, 1) double
        IsAtRest (1, 1) logical
        AvailableCount (1, 1) double
        CacheBytes (1, 1) double
    end

    properties (Access = private)
        LoadingCache (1, 1) app.internal.simulation.LoadingCache
        Tables (1, :) cell = {}
        SlopeEnvelopes (1, :) cell = {}
        SpatialBases (1, :) cell = {}
        States (1, :) cell = {[]}
        Animations (1, :) cell = {[]}
        AccumulateDisplay (1, 1) logical = true
        SelectedTable (1, 1) double = 1
        Events (1, :) struct = struct("Time", {}, "Position", {}, "Strength", {}, ...
            "TableIndex", {}, "Coefficients", {}, "MaximumSlope", {}, "Id", {})
        Retired (:, 3) double = zeros(0, 3)
        RetiredCount (1, 1) double = 0
        FrozenOmittedBound (1, 3) double = zeros(1, 3)
        TruncatedBound (1, 3) double = zeros(1, 3)
        ReservedPositions (:, 2) double = zeros(0, 2)
        ReservedSlopes (:, 1) double = zeros(0, 1)
        ReservedScales (:, 1) double = zeros(0, 1)
        ReservedTimes (:, 1) double = zeros(0, 1)
    end

    methods
        function obj = ReflectingSimulation(fluid, domainSize, resolution, source, options)
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                resolution (1, 1) double {mustBeInteger, mustBeGreaterThanOrEqual(resolution, 51), ...
                    mustBeLessThanOrEqual(resolution, 801)}
                source (1, 1) app.internal.input.Source
                options.SettlingPeriods (1, 1) double {mustBeReal, mustBePositive} = Inf
                options.AccumulateDisplay (1, 1) logical = true
                options.LoadingCacheBytes (1, 1) double {mustBeInteger, mustBeNonnegative} = 134217728
                options.AnimationByteLimit (1, 1) double {mustBeInteger, mustBeNonnegative} = 268435456
                options.Capacity (1, 1) double {mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.Capacity, 20), ...
                    mustBeLessThanOrEqual(options.Capacity, 512)} = 128
            end
            validateSampling(domainSize, resolution, source.Wavelength);
            obj.Fluid = fluid;
            obj.DomainSize = domainSize;
            obj.GridResolution = resolution;
            obj.Coordinates = linspace(-domainSize/2, domainSize/2, resolution);
            obj.Source = source;
            obj.SettlingPeriods = options.SettlingPeriods;
            obj.AccumulateDisplay = options.AccumulateDisplay;
            obj.LoadingCache = app.internal.simulation.LoadingCache(ByteLimit=options.LoadingCacheBytes);
            obj.AnimationByteLimit = options.AnimationByteLimit;
            obj.Capacity = options.Capacity;
            frequency = app.internal.physics.dispersion(source.Wavenumber, fluid);
            obj.RestBudget = 1e-7*domainSize*[1, frequency, source.Wavenumber];
            obj.Tables = {app.internal.responses.prepareTankResponse(fluid, domainSize, source, ...
                Periods=obj.SettlingPeriods)};
            obj.SlopeEnvelopes = {prepareSlopeEnvelope(obj.Tables{1})};
            assert(obj.CacheBytes <= app.internal.responses.TankResponse.MaximumCacheBytes, ...
                "RippleSimulator:CacheMemory", "The precomputed response exceeds the memory budget.");
            obj.validateSourceStrength(obj.Tables{1}, obj.SlopeEnvelopes{1}, source);
            obj.SpatialBases = prepareBases(obj.Tables, obj.Coordinates);
        end

        function value = get.ActiveCount(obj)
            value = numel(obj.Events);
        end

        function value = get.IsAtRest(obj)
            value = isempty(obj.Events);
        end

        function value = get.AvailableCount(obj)
            table = obj.Tables{obj.SelectedTable};
            used = sum(arrayfun(@(event) 8*numel(event.Coefficients), obj.Events));
            capacity = floor((obj.MappingByteLimit - used)/(8*numel(table.Amplitude)));
            value = max(0, min([obj.Capacity - obj.ActiveCount, capacity, ...
                obj.HistoryLimit - size(obj.Retired, 1)]) - obj.ReservedCount);
        end

        function value = get.CacheBytes(obj)
            value = sum(cellfun(@(table) table.MemoryBytes, obj.Tables)) + obj.stateBytes() ...
                +sum(cellfun(@(envelope) envelope.MemoryBytes, obj.SlopeEnvelopes));
        end

        function value = requiresSourcePreparation(obj, source)
            value = isempty(obj.findTable(source));
        end

        function plan = prepareSource(obj, source)
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                source (1, 1) app.internal.input.Source
            end
            validateSampling(obj.DomainSize, obj.GridResolution, source.Wavelength);
            tables = obj.Tables;
            envelopes = obj.SlopeEnvelopes;
            selected = obj.findTable(source);
            if isempty(selected)
                pinned = unique([[obj.Events.TableIndex], obj.Retired(:, 3)']);
                selected = find(~ismember(1:numel(tables), pinned), 1);
                if isempty(selected)
                    selected = numel(tables) + 1;
                end
                assert(selected <= 8, "RippleSimulator:ResponseCapacity", ...
                    "Eight source spectra are still in use. Let the waves settle or clear the surface.");
                retained = tables;
                if selected <= numel(retained)
                    retained(selected) = [];
                end
                remaining = app.internal.responses.TankResponse.MaximumCacheBytes ...
                    - sum(cellfun(@(table) table.MemoryBytes, retained));
                assert(remaining > 0, "RippleSimulator:CacheMemory", ...
                    "The existing waves occupy the response memory budget.");
                tables{selected} = app.internal.responses.prepareTankResponse(obj.Fluid, obj.DomainSize, source, ...
                    Periods=obj.SettlingPeriods, ByteLimit=remaining);
                envelopes{selected} = prepareSlopeEnvelope(tables{selected});
                assert(sum(cellfun(@(table) table.MemoryBytes, tables)) ...
                    +sum(cellfun(@(envelope) envelope.MemoryBytes, envelopes)) <= ...
                    app.internal.responses.TankResponse.MaximumCacheBytes, ...
                    "RippleSimulator:CacheMemory", "The precomputed source response exceeds the memory budget.");
            end
            obj.validateSourceStrength(tables{selected}, envelopes{selected}, source);
            slopes = obj.reservationBounds(tables{selected}, envelopes{selected}, obj.ReservedPositions);
            loading = struct(Table=tables{selected}, Envelope=envelopes{selected}, ...
                Source=source, TableIndex=selected, ...
                Positions=obj.ReservedPositions, Scales=obj.ReservedScales, Times=obj.ReservedTimes);
            obj.validateLoading(source.PressureImpulse*sum(slopes.*obj.ReservedScales), obj.CurrentTime, loading);
            bytes = sum(arrayfun(@(event) 8*numel(event.Coefficients), obj.Events)) ...
                + obj.ReservedCount*8*numel(tables{selected}.Amplitude);
            assert(bytes <= obj.MappingByteLimit, "RippleSimulator:MappingMemory", ...
                "The reserved source spectra exceed the memory budget. Finish or clear the rain burst.");
            plan = struct(Owner=obj, Revision=obj.Revision, Tables={tables}, SelectedTable=selected, ...
                Source=source, ReservedSlopes=slopes, SlopeEnvelopes={envelopes}, ...
                SpatialBases={prepareBases(tables, obj.Coordinates)});
        end

        function commitSource(obj, plan)
            obj.validateRevision(plan);
            obj.LoadingCache = obj.LoadingCache.clear();
            obj.Tables = plan.Tables;
            obj.SlopeEnvelopes = plan.SlopeEnvelopes;
            obj.SpatialBases = plan.SpatialBases;
            obj.States = cell(size(obj.Tables));
            obj.Animations(end+1:numel(obj.Tables)) = {[]};
            obj.SelectedTable = plan.SelectedTable;
            obj.Source = plan.Source;
            obj.ReservedSlopes = plan.ReservedSlopes;
            obj.Revision = obj.Revision + 1;
        end

        function reserveInputs(obj, count, options)
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                count (1, 1) double {mustBeInteger, mustBePositive}
                options.Positions (:, 2) double {mustBeReal, mustBeFinite} = zeros(0, 2)
                options.StrengthScale (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 1
                options.Times (:, 1) double {mustBeReal, mustBeFinite} = zeros(0, 1)
            end
            assert(count <= obj.AvailableCount, "RippleSimulator:SourceCapacity", ...
                "There is insufficient input capacity. Let the waves settle or clear the surface.");
            positions = options.Positions;
            if isempty(positions)
                positions = NaN(count, 2);
            else
                assert(size(positions, 1) == count && all(abs(positions) <= obj.DomainSize/2, "all"), ...
                    "RippleSimulator:SourcePosition", "Reserved positions must lie inside the domain.");
            end
            table = obj.Tables{obj.SelectedTable};
            envelope = obj.SlopeEnvelopes{obj.SelectedTable};
            times = options.Times;
            if isempty(times)
                times = NaN(count, 1);
            else
                assert(numel(times) == count && all(isfinite(times) & times >= obj.CurrentTime), ...
                    "RippleSimulator:ScheduledTime", ...
                    "Reserved times must be finite and no earlier than the current time.");
            end
            slopes = obj.reservationBounds(table, envelope, positions);
            scales = repmat(options.StrengthScale, count, 1);
            loading = struct(Table=table, Envelope=envelope, Source=obj.Source, TableIndex=obj.SelectedTable, ...
                Positions=[obj.ReservedPositions; positions], Scales=[obj.ReservedScales; scales], ...
                Times=[obj.ReservedTimes; times]);
            loadingCache = obj.validateLoading(obj.Source.PressureImpulse ...
                *sum([obj.ReservedSlopes; slopes].*[obj.ReservedScales; scales]), obj.CurrentTime, loading, ...
                LoadingCache=obj.LoadingCache);
            obj.LoadingCache = loadingCache;
            obj.ReservedPositions = [obj.ReservedPositions; positions];
            obj.ReservedSlopes = [obj.ReservedSlopes; slopes];
            obj.ReservedScales = [obj.ReservedScales; scales];
            obj.ReservedTimes = [obj.ReservedTimes; times];
            obj.ReservedCount = obj.ReservedCount + count;
            obj.Revision = obj.Revision + 1;
        end

        function cancelReservation(obj, count)
        % CANCELRESERVATION Release the most recently reserved inputs.
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                count (1, 1) double {mustBeInteger, mustBeNonnegative} = obj.ReservedCount
            end
            assert(count <= obj.ReservedCount, "RippleSimulator:ReservationCount", ...
                "The release count cannot exceed the reserved input count.");
            obj.ReservedCount = obj.ReservedCount - count;
            obj.ReservedPositions = obj.ReservedPositions(1:obj.ReservedCount, :);
            obj.ReservedSlopes = obj.ReservedSlopes(1:obj.ReservedCount);
            obj.ReservedScales = obj.ReservedScales(1:obj.ReservedCount);
            obj.ReservedTimes = obj.ReservedTimes(1:obj.ReservedCount);
            obj.Revision = obj.Revision + 1;
        end

        function retimeReservations(obj, time, factor)
        % RETIMERESERVATIONS Validate pending physical times before changing playback rate.
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                factor (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
            end
            if obj.ReservedCount == 0
                return
            end
            times = time+factor*(obj.ReservedTimes-time);
            loading = struct(Table=obj.Tables{obj.SelectedTable}, Envelope=obj.SlopeEnvelopes{obj.SelectedTable}, ...
                Source=obj.Source, Positions=obj.ReservedPositions, Scales=obj.ReservedScales, Times=times, ...
                TableIndex=obj.SelectedTable);
            obj.validateLoading(obj.Source.PressureImpulse*sum(obj.ReservedSlopes.*obj.ReservedScales), time, loading);
            obj.ReservedTimes = times;
            obj.Revision = obj.Revision+1;
        end

        function identifier = addSource(obj, time, position, options)
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                position (1, 2) double {mustBeReal, mustBeFinite}
                options.Reserved (1, 1) logical = false
                options.StrengthScale (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 1
            end
            assert(time >= obj.CurrentTime, "RippleSimulator:SimulationTime", ...
                "A source cannot be inserted before the processed simulation time.");
            assert(all(abs(position) <= obj.DomainSize/2), "RippleSimulator:SourcePosition", ...
                "The source position must lie inside the domain.");
            if options.Reserved
                available = obj.ReservedCount;
            else
                available = obj.AvailableCount;
            end
            assert(available >= 1, "RippleSimulator:SourceCapacity", "No source slot is available.");
            table = obj.Tables{obj.SelectedTable};
            envelope = obj.SlopeEnvelopes{obj.SelectedTable};
            coefficients = table.coefficients(position);
            maximumSlope = sourceSlope(table, envelope, position, coefficients);
            reservedSlope = sum(obj.ReservedSlopes.*obj.ReservedScales);
            reservedPositions = obj.ReservedPositions;
            reservedScales = obj.ReservedScales;
            reservedTimes = obj.ReservedTimes;
            if options.Reserved
                matches = all(isnan(obj.ReservedPositions), 2) | all(obj.ReservedPositions == position, 2);
                reservationIndex = find(matches & obj.ReservedScales == options.StrengthScale, 1);
                assert(~isempty(reservationIndex), "RippleSimulator:ReservedPosition", ...
                    "The source position and strength have no reserved input.");
                reservedSlope = reservedSlope ...
                    - obj.ReservedSlopes(reservationIndex)*obj.ReservedScales(reservationIndex);
                reservedPositions(reservationIndex, :) = [];
                reservedScales(reservationIndex) = [];
                reservedTimes(reservationIndex) = [];
            end
            loadingCache = obj.LoadingCache;
            strength = options.StrengthScale*obj.Source.PressureImpulse;
            loading = struct(Table=table, Envelope=envelope, Source=obj.Source, TableIndex=obj.SelectedTable, ...
                Positions=[reservedPositions; position], Scales=[reservedScales; options.StrengthScale], ...
                Times=[reservedTimes; time]);
            if ~options.Reserved
                loadingCache = obj.validateLoading( ...
                    obj.Source.PressureImpulse*reservedSlope + strength*maximumSlope, time, loading, ...
                    LoadingCache=loadingCache);
            else
                expectedTime = obj.ReservedTimes(reservationIndex);
                assert(isnan(expectedTime) || abs(time-expectedTime) <= 128*eps(max(1, time)), ...
                    "RippleSimulator:ScheduledTime", "A reserved source must retain its accepted physical time.");
            end
            assert(all(obj.TruncatedBound + strength*table.TailBound <= obj.RestBudget/10), ...
                "RippleSimulator:SpectralTailBudget", "Clear the surface before adding more source spectra.");
            animation = obj.prepareAnimation(table, time, strength, coefficients);
            obj.advanceTo(time);
            obj.LoadingCache = loadingCache;
            identifier = obj.AcceptedCount + 1;
            if strength > 0
                obj.Events(end + 1) = struct(Time=time, Position=position, Strength=strength, ...
                    TableIndex=obj.SelectedTable, Coefficients=coefficients, MaximumSlope=maximumSlope, Id=identifier);
                obj.TruncatedBound = obj.TruncatedBound + strength*table.TailBound;
                obj.Animations{obj.SelectedTable} = animation;
            end
            obj.AcceptedCount = identifier;
            if options.Reserved
                obj.ReservedCount = obj.ReservedCount - 1;
                obj.ReservedPositions(reservationIndex, :) = [];
                obj.ReservedSlopes(reservationIndex) = [];
                obj.ReservedScales(reservationIndex) = [];
                obj.ReservedTimes(reservationIndex) = [];
            end
            obj.Revision = obj.Revision + 1;
        end

        function advanceTo(obj, time)
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(time >= obj.CurrentTime, "RippleSimulator:SimulationTime", ...
                "Simulation time cannot move backward.");
            if isfinite(obj.SettlingPeriods)
                retired = false(1, obj.ActiveCount);
                for group = reshape(unique([obj.Events.TableIndex]), 1, [])
                    selected = [obj.Events.TableIndex] == group;
                    table = obj.Tables{group};
                    duration = obj.SettlingPeriods*table.TimeScale;
                    retired(selected) = time - [obj.Events(selected).Time] >= duration - 8*eps(duration);
                end
                obj.RetiredCount = obj.RetiredCount + nnz(retired);
                obj.Events(retired) = [];
                obj.CurrentTime = time;
                for group = 1:numel(obj.Animations)
                    if isempty(obj.Animations{group})
                        continue
                    end
                    if any([obj.Events.TableIndex] == group)
                        obj.Animations{group} = obj.Animations{group}.advanceTo(time);
                    else
                        obj.Animations{group} = [];
                    end
                end
                obj.Revision = obj.Revision + 1;
                return
            end
            omitted = obj.omittedBound(time);
            retired = false(1, obj.ActiveCount);
            for index = 1:obj.ActiveCount
                event = obj.Events(index);
                table = obj.Tables{event.TableIndex};
                scale = app.internal.responses.SettlingEnvelope.sample( ...
                    time - event.Time, table.TimeScale, obj.SettlingPeriods);
                if scale == 0
                    retired(index) = true;
                    continue
                end
                if isfinite(obj.SettlingPeriods)
                    continue
                end
                contribution = event.Strength*max(0, table.futureBound(time - event.Time) - table.TailBound);
                if all(omitted + contribution <= obj.RestBudget)
                    omitted = omitted + contribution;
                    retired(index) = true;
                    obj.Retired(end + 1, :) = [event.Time, event.Strength, event.TableIndex];
                end
            end
            obj.RetiredCount = obj.RetiredCount + nnz(retired);
            obj.Events(retired) = [];
            unused = ~ismember(1:numel(obj.States), [obj.Events.TableIndex]);
            obj.States(unused) = {[]};
            obj.CurrentTime = time;
            obj.compactHistory();
            obj.Revision = obj.Revision + 1;
        end

        function value = snapshot(obj, options)
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                options.Derivatives (1, 1) logical = false
            end
            value = obj.sampleEvents(obj.Coordinates, options.Derivatives);
            value.GeometryRevision = obj.GeometryRevision;
        end

        function plan = prepareGrid(obj, resolution)
            arguments
                obj (1, 1) app.internal.simulation.ReflectingSimulation
                resolution (1, 1) double {mustBeInteger, mustBeGreaterThanOrEqual(resolution, 51), ...
                    mustBeLessThanOrEqual(resolution, 801)}
            end
            validateSampling(obj.DomainSize, resolution, obj.Source.Wavelength);
            for index = reshape(unique([obj.Events.TableIndex]), 1, [])
                validateSampling(obj.DomainSize, resolution, obj.Tables{index}.Source.Wavelength);
            end
            coordinates = linspace(-obj.DomainSize/2, obj.DomainSize/2, resolution);
            value = obj.sampleEvents(coordinates, false);
            value.GeometryRevision = obj.GeometryRevision + 1;
            plan = struct(Owner=obj, Revision=obj.Revision, Resolution=resolution, ...
                Coordinates=coordinates, Snapshot=value, SpatialBases={prepareBases(obj.Tables, coordinates)});
        end

        function value = renderSnapshot(obj)
        % RENDERSNAPSHOT Evaluate accumulated modal playback on the observation grid.
            value = obj.sampleEvents(obj.Coordinates, false, true);
            value.GeometryRevision = obj.GeometryRevision;
        end

        function commitGrid(obj, plan)
            obj.validateRevision(plan);
            obj.LoadingCache = obj.LoadingCache.clear();
            obj.GridResolution = plan.Resolution;
            obj.Coordinates = plan.Coordinates;
            obj.SpatialBases = plan.SpatialBases;
            obj.GeometryRevision = obj.GeometryRevision + 1;
            obj.Revision = obj.Revision + 1;
        end

        function clear(obj)
            obj.Events = obj.Events([]);
            obj.LoadingCache = obj.LoadingCache.clear();
            obj.Retired = zeros(0, 3);
            obj.RetiredCount = 0;
            obj.FrozenOmittedBound = zeros(1, 3);
            obj.TruncatedBound = zeros(1, 3);
            obj.cancelReservation();
            obj.Tables = obj.Tables(obj.SelectedTable);
            obj.SlopeEnvelopes = obj.SlopeEnvelopes(obj.SelectedTable);
            obj.SpatialBases = obj.SpatialBases(obj.SelectedTable);
            obj.States = {[]};
            obj.Animations = {[]};
            obj.SelectedTable = 1;
        end

        function value = diagnostics(obj)
            events = rmfield(obj.Events, "Coefficients");
            selectedTable = obj.Tables{obj.SelectedTable};
            value = struct(Time=obj.CurrentTime, ActiveCount=obj.ActiveCount, ...
                AcceptedCount=obj.AcceptedCount, ReservedCount=obj.ReservedCount, Events=events, ...
                OmittedBound=obj.omittedBound(obj.CurrentTime), RestBudget=obj.RestBudget, ...
                RetiredCount=obj.RetiredCount, HistoryRecords=size(obj.Retired, 1), HistoryLimit=obj.HistoryLimit, ...
                FrozenOmittedBound=obj.FrozenOmittedBound, TruncatedBound=obj.TruncatedBound, ...
                CacheBytes=obj.CacheBytes, TableCount=numel(obj.Tables), ...
                AnimationBytes=obj.animationBytes(), AnimationByteLimit=obj.AnimationByteLimit, ...
                LoadingCache=obj.LoadingCache.diagnostics(), ...
                MappingBytes=sum(arrayfun(@(event) 8*numel(event.Coefficients), obj.Events)), ...
                MappingByteLimit=obj.MappingByteLimit, FutureSlope=obj.activeSlope(obj.CurrentTime), ...
                SlopeLimit=obj.SlopeLimit, ...
                ReservedSlope=obj.Source.PressureImpulse*sum(obj.ReservedSlopes.*obj.ReservedScales), ...
                Boundary="Free-slip reflecting walls", ContactAngleDegrees=90, SettlingPeriods=obj.SettlingPeriods, ...
                ReferencePeriod=selectedTable.Period, SettlingTimeScale=selectedTable.TimeScale, ...
                SourceLifetime=obj.SettlingPeriods*selectedTable.TimeScale);
        end
    end

    methods (Access = private)
        function animation = prepareAnimation(obj, table, time, strength, coefficients)
            animation = [];
            if ~obj.AccumulateDisplay || ~isfinite(obj.SettlingPeriods) || strength == 0
                return
            end
            previous = obj.Animations{obj.SelectedTable};
            count = nnz([obj.Events.TableIndex] == obj.SelectedTable);
            if isempty(previous) && count > 0
                return
            end
            remaining = obj.AnimationByteLimit - obj.animationBytes();
            if ~isempty(previous)
                remaining = remaining + previous.MemoryBytes;
                previous = previous.advanceTo(time);
                count = previous.SourceCount;
            end
            required = app.internal.playback.PreparedAnimation.estimateBytes( ...
                numel(table.Modes), obj.SettlingPeriods, count+1);
            if required > remaining
                return
            end
            if isempty(previous)
                forcingDuration = 4*table.Period*(table.Source.Mode == "Wavemaker" && table.TimeScale > table.Period);
                animation = app.internal.playback.PreparedAnimation(table.PreparedResponse, table.TimeScale, ...
                    obj.SettlingPeriods, time, Resolution=numel(table.Modes), ForcingDuration=forcingDuration);
            else
                animation = previous;
            end
            animation = animation.add(time, strength, uint32(table.ModeIndex+1), coefficients(:));
        end

        function bytes = animationBytes(obj)
            present = ~cellfun(@isempty, obj.Animations);
            bytes = sum(cellfun(@(animation) animation.MemoryBytes, obj.Animations(present)));
        end

        function bytes = stateBytes(obj)
            present = ~cellfun(@isempty, obj.States);
            bytes = sum(cellfun(@(state) state.MemoryBytes, obj.States(present)));
        end

        function state = combinedState(obj, group, events)
            state = obj.States{group};
            if ~isempty(state) && isequal(state.EventIds, [events.Id])
                return
            end
            obj.States{group} = [];
            state = [];
            table = obj.Tables{group};
            needed = 8*(numel(table.Amplitude) - 1)*(size(table.Kernel.BranchRate, 2) + 6) ...
                + 8*(numel(events) + 2);
            if table.Source.Mode == "Impulse" && obj.stateBytes() + needed <= 67108864
                state = app.internal.responses.TankState(table, events);
                obj.States{group} = state;
            end
        end

        function index = findTable(obj, source)
            index = find(cellfun(@(table) table.Source.Wavelength == source.Wavelength ...
                && table.Source.Mode == source.Mode, obj.Tables), 1);
        end

        function slopes = reservationBounds(~, table, envelope, positions)
            slopes = zeros(size(positions, 1), 1);
            for index = 1:numel(slopes)
                if any(isnan(positions(index, :)))
                    bound = table.futureBound(0);
                    slopes(index) = bound(3);
                else
                    slopes(index) = sourceSlope(table, envelope, positions(index, :), ...
                        table.coefficients(positions(index, :)));
                end
            end
        end

        function validateSourceStrength(obj, table, envelope, source)
        % VALIDATESOURCESTRENGTH Require a centered input within the slope limit.
        %   Each actual source position and combined loading are checked on input.
            unitSlope = sourceSlope(table, envelope, [0, 0], table.coefficients([0, 0]));
            if source.PressureImpulse*unitSlope > obj.SlopeLimit && ~isempty(envelope.Intervals)
                record = struct(Envelope=envelope.Intervals, Time=0, Position=[0, 0], Strength=1, ...
                    Duration=obj.SettlingPeriods*table.TimeScale);
                unitSlope = min(unitSlope, app.internal.numerics.boundScheduledSlopes( ...
                    record, obj.DomainSize, 0, 0, obj.SlopeLimit/source.PressureImpulse));
            end
            assert(source.PressureImpulse*unitSlope <= obj.SlopeLimit, ...
                "RippleSimulator:SourceStrength", ...
                "One source exceeds the supported small-slope range. Reduce the pressure strength to %.4g Pa s.", ...
                obj.SlopeLimit/unitSlope);
        end

        function loadingCache = validateLoading(obj, additionalSlope, time, loading, options)
            arguments
                obj
                additionalSlope
                time
                loading
                options.LoadingCache (1, 1) app.internal.simulation.LoadingCache = ...
                    app.internal.simulation.LoadingCache(ByteLimit=0)
            end
            loadingCache = options.LoadingCache;
            omitted = obj.omittedBound(time);
            maximum = omitted(3) + sum([obj.Events.Strength].*[obj.Events.MaximumSlope]);
            if maximum + additionalSlope <= obj.SlopeLimit
                return
            end
            if obj.activeSlope(time)+additionalSlope <= obj.SlopeLimit
                return
            end
            if obj.spatialLoading(time, loading) <= obj.SlopeLimit
                return
            end
            [scheduled, loadingCache] = obj.scheduledLoading(time, loading, loadingCache);
            assert(scheduled <= obj.SlopeLimit, "RippleSimulator:WaveLoading", ...
                "This input exceeds the conservative small-slope limit. Reduce the pressure strength, " ...
                + "wait for the existing waves to settle, or clear the surface.");
        end

        function value = spatialLoading(obj, time, loading)
        % SPATIALLOADING Combine source envelopes on fixed physical cells.
            omitted = obj.omittedBound(time);
            total = omitted(3);
            for event = obj.Events
                table = obj.Tables{event.TableIndex};
                scale = app.internal.responses.SettlingEnvelope.sample( ...
                    time-event.Time, table.TimeScale, obj.SettlingPeriods);
                bounds = spatialSlope(table, obj.SlopeEnvelopes{event.TableIndex}, event.Position);
                total = total+event.Strength*scale*bounds;
            end
            for index = 1:size(loading.Positions, 1)
                bounds = spatialSlope(loading.Table, loading.Envelope, loading.Positions(index, :));
                total = total+loading.Source.PressureImpulse*loading.Scales(index)*bounds;
            end
            value = max(total, [], "all")*(1+128*eps);
        end

        function value = activeSlope(obj, time)
            omitted = obj.omittedBound(time);
            value = omitted(3);
            for group = reshape(unique([obj.Events.TableIndex]), 1, [])
                table = obj.Tables{group};
                events = obj.Events([obj.Events.TableIndex] == group);
                for first = 1:64:numel(events)
                    batch = events(first:min(first+63, numel(events)));
                    ages = time - [batch.Time];
                    amplitudes = reshape([batch.Coefficients], numel(table.Amplitude), numel(batch));
                    bounds = table.futureSlopes(ages, amplitudes);
                    scale = app.internal.responses.SettlingEnvelope.sample(ages, table.TimeScale, obj.SettlingPeriods);
                    value = value + sum(scale.*[batch.Strength] ...
                        .*max(0, min(bounds, [batch.MaximumSlope])-table.TailBound(3)));
                end
            end
        end

        function [value, loadingCache] = scheduledLoading(obj, time, loading, loadingCache)
            value = Inf;
            if ~isfinite(obj.SettlingPeriods) || isempty(loading.Envelope.Intervals)
                return
            end
            template = struct(Envelope=[], Time=0, Position=[0, 0], Strength=0, Duration=0, TableIndex=0);
            records = repmat(template, 1, numel(obj.Events)+numel(loading.Times));
            for index = 1:numel(obj.Events)
                event = obj.Events(index);
                envelope = obj.SlopeEnvelopes{event.TableIndex}.Intervals;
                records(index) = struct(Envelope=envelope, Time=event.Time, Position=event.Position, ...
                    Strength=event.Strength, Duration=obj.SettlingPeriods*envelope.TimeScale, ...
                    TableIndex=event.TableIndex);
            end
            envelope = loading.Envelope.Intervals;
            for index = 1:numel(loading.Times)
                records(numel(obj.Events)+index) = struct(Envelope=envelope, Time=loading.Times(index), ...
                    Position=loading.Positions(index, :), ...
                    Strength=loading.Source.PressureImpulse*loading.Scales(index), ...
                    Duration=obj.SettlingPeriods*envelope.TimeScale, TableIndex=loading.TableIndex);
            end
            omitted = obj.omittedBound(time);
            [loadingCache, value] = loadingCache.bound(records, obj.DomainSize, time, omitted(3), obj.SlopeLimit);
        end

        function value = omittedBound(obj, time)
            value = obj.FrozenOmittedBound + obj.TruncatedBound;
            for index = 1:size(obj.Retired, 1)
                record = obj.Retired(index, :);
                table = obj.Tables{record(3)};
                value = value + record(2)*max(0, table.futureBound(time - record(1)) - table.TailBound);
            end
        end

        function compactHistory(obj)
            expired = false(size(obj.Retired, 1), 1);
            for index = 1:size(obj.Retired, 1)
                record = obj.Retired(index, :);
                table = obj.Tables{record(3)};
                bound = record(2)*max(0, table.futureBound(obj.CurrentTime - record(1)) - table.TailBound);
                if all(bound <= 1e-10*obj.RestBudget)
                    obj.FrozenOmittedBound = obj.FrozenOmittedBound + bound;
                    expired(index) = true;
                end
            end
            obj.Retired(expired, :) = [];
        end

        function validateRevision(obj, plan)
            assert(isfield(plan, "Owner") && isequal(plan.Owner, obj), "RippleSimulator:ForeignPreparation", ...
                "The prepared operation belongs to a different simulation.");
            assert(plan.Revision == obj.Revision, "RippleSimulator:StalePreparation", ...
                "The simulation changed after this operation was prepared.");
        end

        function value = sampleEvents(obj, coordinates, derivatives, prepared)
            if nargin < 4
                prepared = false;
            end
            elevation = zeros(numel(coordinates), numel(coordinates));
            velocity = zeros(0);
            gradientX = zeros(0);
            gradientY = zeros(0);
            if derivatives
                velocity = elevation;
                gradientX = elevation;
                gradientY = elevation;
            end
            for group = reshape(unique([obj.Events.TableIndex]), 1, [])
                table = obj.Tables{group};
                if isequal(coordinates, obj.Coordinates)
                    cosine = obj.SpatialBases{group}.Cosine;
                    derivative = obj.SpatialBases{group}.Derivative;
                elseif derivatives
                    [cosine, derivative] = table.basis(coordinates);
                else
                    cosine = table.basis(coordinates);
                end
                coefficients = zeros(size(table.Amplitude));
                velocityCoefficients = coefficients;
                indices = table.ModeIndex(2:end);
                events = obj.Events([obj.Events.TableIndex] == group);
                timeScale = table.TimeScale;
                state = [];
                if isinf(obj.SettlingPeriods)
                    state = obj.combinedState(group, events);
                end
                if prepared && ~derivatives && group <= numel(obj.Animations) ...
                        && ~isempty(obj.Animations{group})
                    coefficients = obj.Animations{group}.sample();
                elseif ~isempty(state)
                    if derivatives
                        [coefficients, velocityCoefficients] = state.sample(obj.CurrentTime);
                    else
                        coefficients = state.sample(obj.CurrentTime);
                    end
                elseif ~isempty(table.PreparedResponse)
                    for first = 1:64:numel(events)
                        batch = events(first:min(first+63, numel(events)));
                        ages = obj.CurrentTime-[batch.Time];
                        [scale, scaleDerivative] = app.internal.responses.SettlingEnvelope.sample( ...
                            ages, timeScale, obj.SettlingPeriods);
                        if derivatives
                            [response, responseDerivative] = table.PreparedResponse.sample(ages);
                        else
                            response = table.PreparedResponse.sample(ages);
                        end
                        amplitudes = reshape([batch.Coefficients], numel(table.Amplitude), numel(batch));
                        amplitudes = amplitudes(2:end, :).*[batch.Strength];
                        coefficients(2:end) = coefficients(2:end)+reshape( ...
                            sum(amplitudes.*response(indices, :).*scale, 2), 1, []);
                        if derivatives
                            derivativeResponse = responseDerivative(indices, :).*table.Frequency(indices).*scale ...
                                + response(indices, :).*scaleDerivative;
                            velocityCoefficients(2:end) = velocityCoefficients(2:end) ...
                                + reshape(sum(amplitudes.*derivativeResponse, 2), 1, []);
                        end
                    end
                else
                    for event = events
                        age = obj.CurrentTime - event.Time;
                        if age == 0 && ~derivatives
                            continue
                        end
                        if derivatives
                            [response, responseDerivative] = table.sample(age);
                        else
                            response = table.sample(age);
                        end
                        [scale, scaleDerivative] = app.internal.responses.SettlingEnvelope.sample( ...
                            age, timeScale, obj.SettlingPeriods);
                        coefficients(2:end) = coefficients(2:end) + event.Strength*event.Coefficients(2:end) ...
                            .*reshape(scale*response(indices), 1, []);
                        if derivatives
                            velocityCoefficients(2:end) = velocityCoefficients(2:end) ...
                                + event.Strength*event.Coefficients(2:end) ...
                                .*reshape(scale*responseDerivative(indices).*table.Frequency(indices) ...
                                + scaleDerivative*response(indices), 1, []);
                        end
                    end
                end
                elevation = elevation + cosine*coefficients*cosine';
                if derivatives
                    velocity = velocity + cosine*velocityCoefficients*cosine';
                    gradientX = gradientX + cosine*coefficients*derivative';
                    gradientY = gradientY + derivative*coefficients*cosine';
                end
            end
            value = struct(Elevation=elevation, Velocity=velocity, GradientX=gradientX, GradientY=gradientY, ...
                Coordinates=coordinates, DomainSize=obj.DomainSize, Time=obj.CurrentTime, IsAtRest=obj.IsAtRest);
        end
    end
end

function envelope = prepareSlopeEnvelope(table)
    persistent retained
    if isempty(table.PreparedResponse)
        envelope = struct(Global=zeros(0), Intervals=[], MemoryBytes=0);
        return
    end
    if isempty(retained)
        retained = cell(1, 0);
    end
    signature = struct(Fluid=table.Fluid, DomainSize=table.DomainSize, ...
        Wavelength=table.Source.Wavelength, Mode=table.Source.Mode, ...
        Frequency=table.Frequency, Times=table.PreparedResponse.Times, ...
        BranchOrder=size(table.Kernel.BranchRate, 2));
    for index = 1:numel(retained)
        if isequal(signature, retained{index}.Signature)
            envelope = retained{index}.Envelope;
            retained = retained([1:index-1, index+1:end, index]);
            return
        end
    end
    nodes = min(512, max(128, 128*ceil(24*table.DomainSize/table.Source.Wavelength/128)));
    intervals = app.internal.numerics.periodicSlopeIntervals(table, Cells=75, Nodes=nodes);
    quadrant = double(max(intervals.Magnitudes, [], 3));
    globalBound = [quadrant, fliplr(quadrant); flipud(quadrant), rot90(quadrant, 2)];
    envelope = struct(Global=globalBound, Intervals=intervals, ...
        MemoryBytes=intervals.MemoryBytes+8*numel(globalBound));
    if numel(retained) >= 2
        retained(1) = [];
    end
    retained{end+1} = struct(Signature=signature, Envelope=envelope);
end

function value = sourceSlope(table, envelope, position, coefficients)
    if isempty(envelope.Global)
        value = table.slopeBound(coefficients);
        return
    end
    forcingNorm = 1+7*(table.Source.Mode == "Wavemaker");
    modal = forcingNorm*sum(abs(coefficients).*table.Wavenumber, "all")+table.TailBound(3);
    value = min(modal, max(spatialSlope(table, envelope, position), [], "all"));
end

function bounds = spatialSlope(table, envelope, position)
    if isempty(envelope.Global) || any(isnan(position))
        value = table.futureBound(0);
        bounds = value(3);
        return
    end
    bounds = app.internal.numerics.mapPeriodicSlope(envelope.Global, table.DomainSize, position);
    forcingNorm = 1+7*(table.Source.Mode == "Wavemaker");
    interpolation = forcingNorm*5e-4*table.Source.Wavenumber^2 ...
        /(table.Fluid.Density*(2*pi/table.Period));
    bounds = bounds+table.TailBound(3)+interpolation;
end

function bases = prepareBases(tables, coordinates)
    bases = cell(size(tables));
    for index = 1:numel(tables)
        [cosine, derivative] = tables{index}.basis(coordinates);
        bases{index} = struct(Cosine=cosine, Derivative=derivative);
    end
end

function validateSampling(domainSize, resolution, wavelength)
    assert((resolution - 1)*wavelength/domainSize >= 6, "RippleSimulator:GridBandwidth", ...
        "The display grid requires at least six intervals per characteristic wavelength. " ...
        + "Increase the grid resolution.");
    assert(domainSize/wavelength <= app.internal.input.Source.MaximumDomainRatio*(1+32*eps), ...
        "RippleSimulator:SourceExtent", "The domain cannot exceed 26 characteristic source wavelengths.");
end
