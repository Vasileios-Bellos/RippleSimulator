classdef (Sealed) LateResponseCache < handle
    % LATERESPONSECACHE Retain bounded interpolation blocks for older waves.
    %   Blocks cover four reference periods with sixteen intervals per period.
    %   Responses are per unit pressure strength and shared by matching sources.
    %   Eviction affects evaluation cost only; accepted event history is separate.

    properties (SetAccess = private)
        Fluid app.internal.materials.Fluid
        ByteLimit (1, 1) double
        EntryLimit (1, 1) double = 32
        Hits (1, 1) double = 0
        Misses (1, 1) double = 0
    end

    properties (Dependent, SetAccess = private)
        MemoryBytes (1, 1) double
        EntryCount (1, 1) double
    end

    properties (Access = private)
        Records (1, :) cell = cell(1, 0)
        Sequence (1, 1) double = 0
    end

    methods
        function obj = LateResponseCache(fluid, options)
        % LATERESPONSECACHE Set the fluid and retained numeric storage limit.
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                options.ByteLimit (1, 1) double {mustBeReal, mustBeFinite, mustBePositive} = 67108864
            end
            obj.Fluid = fluid;
            obj.ByteLimit = options.ByteLimit;
        end

        function value = get.MemoryBytes(obj)
            value = 0;
            for index = 1:numel(obj.Records)
                value = value + obj.Records{index}.Bytes;
            end
        end

        function value = get.EntryCount(obj)
            value = numel(obj.Records);
        end

        function [elevation, velocity, slope] = sample(obj, table, mapping, age)
        % SAMPLE Reuse an older response without changing source age or pressure strength.
            arguments
                obj (1, 1) app.internal.responses.LateResponseCache
                table (1, 1) app.internal.responses.ResponseTable
                mapping (1, 1) struct
                age (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            assert(isequal(obj.Fluid, table.Fluid), "RippleSimulator:ResponseFluid", ...
                "The late-response cache belongs to a different fluid.");
            assert(mapping.Step == table.RadialStep && mapping.RadiusCount == numel(table.Radii), ...
                "RippleSimulator:ResponseMapping", "The radial mapping belongs to a different table grid.");
            assert(age >= 64*table.Period, "RippleSimulator:LateResponseAge", ...
                "Late-response interpolation requires at least sixty-four reference periods.");
            needed = 8*(4*numel(table.Radii)*65 + 65);
            if needed > obj.ByteLimit
                evaluator = @table.sampleDirect;
                obj.Misses = obj.Misses + 1;
            else
                block = obj.prepare(table, age);
                evaluator = @(map, time) app.internal.numerics.interpolateResponse( ...
                    block.Fields, block.Times, map, time);
            end
            if nargout >= 3
                [elevation, velocity, slope] = evaluator(mapping, age);
            elseif nargout == 2
                [elevation, velocity] = evaluator(mapping, age);
            else
                elevation = evaluator(mapping, age);
            end
        end

        function clear(obj)
        % CLEAR Release retained blocks and restart cache counters.
            arguments
                obj (1, 1) app.internal.responses.LateResponseCache
            end
            obj.Records = cell(1, 0);
            obj.Sequence = 0;
            obj.Hits = 0;
            obj.Misses = 0;
        end

        function value = diagnostics(obj)
        % DIAGNOSTICS Report acceleration storage and reuse without wave state.
            arguments
                obj (1, 1) app.internal.responses.LateResponseCache
            end
            value = struct(MemoryBytes=obj.MemoryBytes, ByteLimit=obj.ByteLimit, ...
                EntryCount=obj.EntryCount, EntryLimit=obj.EntryLimit, Hits=obj.Hits, Misses=obj.Misses);
        end
    end

    methods (Access = private)
        function block = prepare(obj, table, age)
            obj.Sequence = obj.Sequence + 1;
            for index = 1:numel(obj.Records)
                block = obj.Records{index};
                if block.Wavelength == table.Source.Wavelength && block.Mode == table.Source.Mode ...
                        && block.RadialStep == table.RadialStep && block.RadiusCount == numel(table.Radii) ...
                        && age >= block.Times(1) && age <= block.Times(end)
                    block.LastUse = obj.Sequence;
                    obj.Records{index} = block;
                    obj.Hits = obj.Hits + 1;
                    return
                end
            end
            firstPeriod = 4*floor(age/(4*table.Period));
            times = (firstPeriod + (0:64)/16)*table.Period;
            if age < times(1)
                times = (firstPeriod - 4 + (0:64)/16)*table.Period;
            elseif age > times(end)
                times = (firstPeriod + 4 + (0:64)/16)*table.Period;
            end
            fields = app.internal.physics.radialResponse(table.Fluid, table.Source, table.Radii, times);
            block = struct(Wavelength=table.Source.Wavelength, Mode=table.Source.Mode, ...
                RadialStep=table.RadialStep, RadiusCount=numel(table.Radii), Times=times, Fields=fields, ...
                Bytes=8*(numel(fields) + numel(times)), LastUse=obj.Sequence);
            while obj.EntryCount >= obj.EntryLimit || obj.MemoryBytes + block.Bytes > obj.ByteLimit
                ages = cellfun(@(record) record.LastUse, obj.Records);
                [~, oldest] = min(ages);
                obj.Records(oldest) = [];
            end
            obj.Records{end+1} = block;
            obj.Misses = obj.Misses + 1;
        end
    end
end
