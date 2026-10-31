function table = prepareTankResponse(fluid, domainSize, source, options)
% PREPARETANKRESPONSE Reuse responses per unit pressure strength for ideal reflecting walls.
%   Simulation state, source history, clocks, and graphics are not shared.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        source (1, 1) app.internal.input.Source
        options.Periods (1, 1) double {mustBeReal, mustBePositive} = Inf
        options.ByteLimit (1, 1) double {mustBeReal, mustBeFinite, mustBePositive} = 805306368
    end
    persistent retained
    if isempty(retained)
        retained = cell(1, 0);
    end
    unitSource = app.internal.input.Source(source.Wavelength, 1, source.Mode);
    signature = struct(Fluid=fluid, DomainSize=domainSize, Source=unitSource, ...
        Periods=options.Periods, ByteLimit=options.ByteLimit);
    for index = 1:numel(retained)
        if isequal(signature, retained{index}.Signature)
            table = retained{index}.Table;
            retained = retained([1:index-1, index+1:end, index]);
            return
        end
    end
    table = app.internal.responses.TankResponse(fluid, domainSize, unitSource, ...
        Periods=options.Periods, ByteLimit=options.ByteLimit);
    byteLimit = app.internal.responses.TankResponse.MaximumCacheBytes;
    if table.MemoryBytes > byteLimit
        return
    end
    while ~isempty(retained) && (numel(retained) >= 2 ...
            || sum(cellfun(@(record) record.Table.MemoryBytes, retained))+table.MemoryBytes > byteLimit)
        retained(1) = [];
    end
    retained{end+1} = struct(Signature=signature, Table=table);
end
