classdef (Sealed) LoadingCache
    % LOADINGCACHE Retain bounded cell envelopes for source-admission calculations.
    %   Entries are indexed by response-table slot and physical source position.
    %   Table replacement and geometry changes require explicit invalidation.

    properties (SetAccess = private)
        ByteLimit (1, 1) double
    end

    properties (Dependent, SetAccess = private)
        MemoryBytes (1, 1) double
        EntryCount (1, 1) double
    end

    properties (Access = private)
        Keys (:, 3) double = zeros(0, 3)
        Entries (1, :) cell = cell(1, 0)
        Sizes (1, :) double = zeros(1, 0)
        PreviousBound (1, :) struct = struct("Records", {}, "Time", {}, "Allowance", {}, "Value", {})
    end

    methods
        function obj = LoadingCache(options)
        % LOADINGCACHE Set the retained numeric-storage budget in bytes.
            arguments
                options.ByteLimit (1, 1) double {mustBeInteger, mustBeNonnegative} = 134217728
            end
            obj.ByteLimit = options.ByteLimit;
        end

        function value = get.MemoryBytes(obj)
            value = sum(obj.Sizes);
            if ~isempty(obj.PreviousBound)
                value = value+8*numel(obj.PreviousBound.Records)+24;
            end
        end

        function value = get.EntryCount(obj)
            value = numel(obj.Entries);
        end

        function obj = clear(obj)
        % CLEAR Release all entries while retaining the storage budget.
            obj.Keys = zeros(0, 3);
            obj.Entries = cell(1, 0);
            obj.Sizes = zeros(1, 0);
            obj.PreviousBound = struct("Records", {}, "Time", {}, "Allowance", {}, "Value", {});
        end

        function [obj, value] = bound(obj, records, extent, time, allowance, limit)
        % BOUND Enclose remaining slopes, reusing accepted source positions.
            arguments
                obj (1, 1) app.internal.simulation.LoadingCache
                records (1, :) struct
                extent (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                time (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                allowance (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                limit (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
            end
            value = allowance;
            if isempty(records)
                obj = obj.clear();
                return
            end
            if any(~isfinite([records.Time])) || any(~isfinite([records.Duration])) ...
                    || any(~isfinite(vertcat(records.Position)), "all")
                value = Inf;
                return
            end
            records = records([records.Time]+[records.Duration] > time & [records.Strength] > 0);
            if isempty(records)
                obj = obj.clear();
                return
            end
            [obj, prepared] = obj.prepare(records, extent);
            value = Inf;
            if ~isempty(prepared)
                value = obj.reuseBound(records, prepared, time, allowance);
                if value > limit
                    value = app.internal.numerics.boundPreparedSlopes(prepared, records, time, allowance, limit);
                end
            end
            if value > limit
                if records(1).Envelope.Kind == "Images"
                    original = app.internal.numerics.boundImageSlopes(records, extent, time, allowance, limit);
                else
                    original = app.internal.numerics.boundScheduledSlopes(records, extent, time, allowance, limit);
                end
                value = min(value, original);
            end
            if ~isempty(prepared) && isfinite(value) && value <= limit
                obj = obj.retainBound(records, time, allowance, value);
            end
        end

        function value = diagnostics(obj)
        % DIAGNOSTICS Report retained numeric storage and source-position count.
            value = struct(MemoryBytes=obj.MemoryBytes, ByteLimit=obj.ByteLimit, EntryCount=obj.EntryCount);
        end
    end

    methods (Access = private)
        function value = reuseBound(obj, records, prepared, time, allowance)
            value = Inf;
            previous = obj.PreviousBound;
            if isempty(previous) || time < previous.Time
                return
            end
            current = recordKeys(records);
            additions = true(size(records));
            retained = previous.Records(:, 4)+previous.Records(:, 6) > time;
            for record = previous.Records(retained, :)'
                selected = find(all(current == record', 2)' & additions, 1);
                if isempty(selected)
                    return
                end
                additions(selected) = false;
            end
            value = previous.Value+max(0, allowance-previous.Allowance);
            for record = prepared(additions)
                envelope = record.Envelope;
                if record.Duration > envelope.Times(end)*(1+32*eps)
                    value = Inf;
                    return
                end
                peak = double(max(envelope.Bounds, [], "all"))*(1+32*double(eps("single")));
                value = value+record.Strength*(peak+envelope.Allowance);
            end
            value = value*(1+32*(nnz(additions)+1)*eps);
        end

        function obj = retainBound(obj, records, time, allowance, value)
            keys = recordKeys(records);
            required = 8*numel(keys)+24;
            if sum(obj.Sizes)+required <= obj.ByteLimit
                obj.PreviousBound = struct(Records=keys, Time=time, Allowance=allowance, Value=value);
            else
                obj.PreviousBound = struct("Records", {}, "Time", {}, "Allowance", {}, "Value", {});
            end
        end

        function [obj, prepared] = prepare(obj, records, extent)
            keys = [[records.TableIndex]', vertcat(records.Position)];
            retained = ismember(obj.Keys, keys, "rows");
            obj.Keys = obj.Keys(retained, :);
            obj.Entries = obj.Entries(retained);
            obj.Sizes = obj.Sizes(retained);
            prepared = records;
            for index = 1:numel(records)
                key = keys(index, :);
                selected = find(all(obj.Keys == key, 2), 1);
                if isempty(selected)
                    required = entryBytes(records(index).Envelope);
                    if obj.MemoryBytes+required > obj.ByteLimit
                        prepared = records([]);
                        return
                    end
                    envelope = app.internal.numerics.prepareCellSlopeEnvelope( ...
                        records(index).Envelope, extent, records(index).Position);
                    selected = numel(obj.Entries)+1;
                    obj.Entries{selected} = envelope;
                    obj.Keys(selected, :) = key;
                    obj.Sizes(selected) = required;
                end
                prepared(index).Envelope = obj.Entries{selected};
            end
        end
    end
end

function keys = recordKeys(records)
    keys = [[records.TableIndex]', vertcat(records.Position), ...
        [records.Time]', [records.Strength]', [records.Duration]'];
end

function bytes = entryBytes(envelope)
    periodic = envelope.Kind == "Periodic";
    if envelope.Kind == "Images"
        envelope = envelope.Radial;
    end
    cells = envelope.Cells^2;
    times = numel(envelope.Times);
    bytes = 4*cells*(times-1)+8*times+64;
    if periodic
        bytes = bytes+192*cells;
    end
end
