classdef (Abstract) WaveExperiment < handle
    % WAVEEXPERIMENT Define the physical-state interface used by the application.

    properties (Constant)
        % SlopeLimit bounds the horizontal gradient used for linear-wave admission.
        SlopeLimit = 0.1
    end

    methods (Abstract)
        value = requiresSourcePreparation(obj, source)
        plan = prepareSource(obj, source)
        commitSource(obj, plan)
        reserveInputs(obj, count)
        cancelReservation(obj)
        retimeReservations(obj, time, factor)
        identifier = addSource(obj, time, position, options)
        advanceTo(obj, time)
        value = snapshot(obj, options)
        plan = prepareGrid(obj, resolution)
        commitGrid(obj, plan)
        clear(obj)
        value = diagnostics(obj)
    end

    methods
        function value = renderSnapshot(obj)
        % RENDERSNAPSHOT Return a physical snapshot for graphics updates.
            value = obj.snapshot();
        end
    end
end
