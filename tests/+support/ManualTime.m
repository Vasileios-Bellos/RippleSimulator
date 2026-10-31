classdef (Sealed) ManualTime < handle
    % MANUALTIME Controllable elapsed time for reproducible playback tests.

    properties
        Value (1, 1) double = 0
    end
end
