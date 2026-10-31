function response = prepareUnitResponse(fluid, source, maximumRadius, periods, separate)
% PREPAREUNITRESPONSE Reuse bounded, immutable physical responses between experiments.
%   Only precomputed unit-source responses are shared. Each experiment retains its
%   own source history, clock, observation maps, and rendering resources.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
        maximumRadius (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        periods (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        separate (1, 1) logical
    end
    persistent retained
    if isempty(retained)
        retained = cell(1, 0);
    end
    unitSource = app.internal.input.Source(source.Wavelength, 1, source.Mode);
    signature = struct(Fluid=fluid, Source=unitSource, MaximumRadius=maximumRadius, ...
        Periods=periods, Separate=separate);
    for index = 1:numel(retained)
        if isequal(signature, retained{index}.Signature)
            response = retained{index};
            retained = retained([1:index-1, index+1:end, index]);
            return
        end
    end
    table = app.internal.responses.ResponseTable(fluid, unitSource, maximumRadius, ...
        Periods=periods, Separate=separate);
    envelope = app.internal.responses.RestEnvelope(fluid, unitSource, maximumRadius);
    globalSlope = app.internal.physics.globalSlopeBound(fluid, unitSource);
    bytes = table.memoryBytes()+8*(numel(envelope.Times)+numel(envelope.Bounds) ...
        + numel(envelope.QuadratureAllowance)+1);
    response = struct(Signature=signature, Table=table, Envelope=envelope, ...
        GlobalSlope=globalSlope, MemoryBytes=bytes);
    byteLimit = 50331648;
    if bytes > byteLimit
        return
    end
    while ~isempty(retained) && (numel(retained) >= 4 ...
            || sum(cellfun(@(record) record.MemoryBytes, retained))+bytes > byteLimit)
        retained(1) = [];
    end
    retained{end+1} = response;
end
