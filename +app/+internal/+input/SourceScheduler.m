classdef (Sealed) SourceScheduler < handle
    % SOURCESCHEDULER Schedule reproducible bursts of manual-equivalent clicks.
    %   A burst contains twenty positions sampled uniformly over the physical
    %   domain, spaced by 0.05 real seconds while playback runs. Each burst
    %   retains its pressure multiplier. Other source properties are captured
    %   by the app when each scheduled click is accepted.

    properties (SetAccess = private)
        Seed (1, 1) double
    end

    properties (Dependent, SetAccess = private)
        PendingCount (1, 1) double
    end

    properties (Access = private)
        Stream (1, 1) RandStream = RandStream("mt19937ar", Seed=20261021)
        ScheduledTimes (:, 1) double = zeros(0, 1)
        Positions (:, 2) double = zeros(0, 2)
        StrengthScales (:, 1) double = zeros(0, 1)
    end

    methods
        function obj = SourceScheduler(seed)
        % SOURCESCHEDULER Construct a scheduler with a private MT19937 stream.
            arguments
                seed (1, 1) {mustBeNumeric, mustBeInteger, mustBeNonnegative, ...
                    mustBeLessThanOrEqual(seed, 4294967295)} = 20261021
            end
            obj.setSeed(seed);
        end

        function value = get.PendingCount(obj)
            value = numel(obj.ScheduledTimes);
        end

        function start(obj, activeTime, domainSize)
        % START Prepare twenty positions without replacing an active burst.
            arguments
                obj (1, 1) app.internal.input.SourceScheduler
                activeTime (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                domainSize (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
            end
            obj.commitBurst(obj.prepareBurst(activeTime, domainSize));
        end

        function plan = prepareBurst(obj, activeTime, domainSize, options)
        % PREPAREBURST Generate candidate positions without advancing the stream.
            arguments
                obj (1, 1) app.internal.input.SourceScheduler
                activeTime (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
                domainSize (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
                options.StrengthScale (1, 1) double {mustBeReal, mustBeFinite, mustBeNonnegative} = 1
            end
            candidate = RandStream("mt19937ar", Seed=obj.Seed);
            candidate.State = obj.Stream.State;
            positions = (rand(candidate, 20, 2) - 0.5)*domainSize;
            plan = struct(Owner=obj, InitialState=obj.Stream.State, FinalState=candidate.State, ...
                Positions=positions, ActiveTimes=activeTime + (0:19)'*0.05, ...
                StrengthScales=repmat(options.StrengthScale, 20, 1), InitialTimes=obj.ScheduledTimes);
        end

        function commitBurst(obj, plan)
        % COMMITBURST Accept a prepared burst after physical input admission.
            assert(isequal(plan.Owner, obj), "RippleSimulator:ForeignPreparation", ...
                "The prepared rain burst belongs to a different scheduler.");
            assert(isequal(obj.ScheduledTimes, plan.InitialTimes) && isequal(obj.Stream.State, plan.InitialState), ...
                "RippleSimulator:StalePreparation", "The rain schedule changed after preparation.");
            [times, order] = sort([obj.ScheduledTimes; plan.ActiveTimes]);
            positions = [obj.Positions; plan.Positions];
            scales = [obj.StrengthScales; plan.StrengthScales];
            obj.Positions = positions(order, :);
            obj.StrengthScales = scales(order);
            obj.ScheduledTimes = times;
            obj.Stream.State = plan.FinalState;
        end

        function pending = due(obj, activeTime)
        % DUE Return due input without removing it from the accepted schedule.
            arguments
                obj (1, 1) app.internal.input.SourceScheduler
                activeTime (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            selected = obj.ScheduledTimes <= activeTime;
            pending = struct(ActiveTimes=obj.ScheduledTimes(selected), Positions=obj.Positions(selected, :), ...
                StrengthScales=obj.StrengthScales(selected));
        end

        function consume(obj, count)
        % CONSUME Remove input only after the simulation has accepted it.
            arguments
                obj (1, 1) app.internal.input.SourceScheduler
                count (1, 1) {mustBeNumeric, mustBeInteger, mustBeNonnegative}
            end
            assert(count <= obj.PendingCount, "RippleSimulator:RainConsumption", ...
                "The consumed count cannot exceed the remaining scheduled clicks.");
            obj.ScheduledTimes(1:count) = [];
            obj.Positions(1:count, :) = [];
            obj.StrengthScales(1:count) = [];
        end

        function cancel(obj)
        % CANCEL Clear pending input while retaining random-stream progression.
            arguments
                obj (1, 1) app.internal.input.SourceScheduler
            end
            obj.ScheduledTimes = zeros(0, 1);
            obj.Positions = zeros(0, 2);
            obj.StrengthScales = zeros(0, 1);
        end

        function setSeed(obj, seed)
        % SETSEED Reset the random stream for subsequent bursts without changing pending positions.
            arguments
                obj (1, 1) app.internal.input.SourceScheduler
                seed (1, 1) {mustBeNumeric, mustBeInteger, mustBeNonnegative, ...
                    mustBeLessThanOrEqual(seed, 4294967295)}
            end
            stream = RandStream("mt19937ar", Seed=double(seed));
            obj.Stream = stream;
            obj.Seed = double(seed);
        end
    end
end
