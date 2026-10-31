function response = prepareImageResponse(fluid, source, maximumRadius, coefficient, periods, resolution)
% PREPAREIMAGERESPONSE Cache responses for partial wave reflection.
%   Shared records contain immutable responses and bounds per unit pressure strength.
%   Source histories, input maps, clocks, and graphics remain independently owned.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
        maximumRadius (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        coefficient (1, 1) double {mustBeReal, mustBeFinite, ...
            mustBeGreaterThan(coefficient, 0), mustBeLessThan(coefficient, 1)}
        periods (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
        resolution (1, 1) double {mustBeInteger, mustBeGreaterThanOrEqual(resolution, 51)}
    end
    persistent retained
    if isempty(retained)
        retained = cell(1, 0);
    end
    unitSource = app.internal.input.Source(source.Wavelength, 1, source.Mode);
    signature = struct(Fluid=fluid, Source=unitSource, MaximumRadius=maximumRadius, ...
        Coefficient=coefficient, Periods=periods, Resolution=resolution);
    for index = 1:numel(retained)
        if isequal(signature, retained{index}.Signature)
            response = retained{index};
            retained = retained([1:index-1, index+1:end, index]);
            return
        end
    end
    table = app.internal.responses.ImageResponse(fluid, unitSource, maximumRadius/sqrt(2), ...
        coefficient, periods, resolution);
    envelope = app.internal.responses.RestEnvelope(fluid, unitSource, maximumRadius);
    globalSlope = app.internal.physics.globalSlopeBound(fluid, unitSource);
    bytes = table.memoryBytes()+8*(numel(envelope.Times)+numel(envelope.Bounds) ...
        + numel(envelope.QuadratureAllowance)+1);
    response = struct(Signature=signature, Table=table, Envelope=envelope, ...
        GlobalSlope=globalSlope, MemoryBytes=bytes);
    byteLimit = 536870912;
    if bytes > byteLimit
        return
    end
    while ~isempty(retained) && (numel(retained) >= 2 ...
            || sum(cellfun(@(record) record.MemoryBytes, retained))+bytes > byteLimit)
        retained(1) = [];
    end
    retained{end+1} = response;
end
