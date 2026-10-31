classdef (Sealed) ScheduledLoadingTest < support.ProjectTestCase
    % SCHEDULEDLOADINGTEST Verify rain admission and rejection of concentrated loading.

    properties (TestParameter)
        Boundary = struct(Unbounded=0, Partial=0.5, Ideal=1)
    end

    methods (Test, TestTags = {'Integration'})
        function distributedRainRetainsEveryInput(testCase, Boundary)
            model = makeSimulation(Boundary);
            scheduler = app.internal.input.SourceScheduler(0);
            plan = scheduler.prepareBurst(0, model.DomainSize);
            times = 0.25*plan.ActiveTimes;

            model.reserveInputs(20, Positions=plan.Positions, Times=times);
            acceptReservedSources(model, plan.Positions, times);
            model.advanceTo(0.35);
            state = model.diagnostics();
            field = model.snapshot(Derivatives=true);

            testCase.verifyEqual(state.AcceptedCount, 20);
            testCase.verifyEqual(state.ReservedCount, 0);
            testCase.verifyEqual([state.Events.Time], times', AbsTol=1e-14);
            testCase.verifyLessThanOrEqual(max(hypot(field.GradientX, field.GradientY), [], "all"), 0.1);
            testCase.verifyGreaterThan(max(abs(field.Elevation), [], "all"), 0);
        end

        function rejectedRainRetainsAcceptedState(testCase, Boundary)
            model = makeSimulation(Boundary);
            model.addSource(0, [-0.2, -0.2]);
            before = model.diagnostics();

            testCase.verifyError(@() model.reserveInputs(20, Positions=zeros(20, 2), ...
                Times=zeros(20, 1)), "RippleSimulator:WaveLoading");

            testCase.verifyEqual(model.diagnostics(), before);
            testCase.verifyEqual(model.AcceptedCount, 1);
            testCase.verifyEqual(model.ReservedCount, 0);
        end

        function cachePreservesAcceptedFields(testCase, Boundary)
            cached = makeSimulation(Boundary);
            reference = makeSimulation(Boundary, LoadingCacheBytes=0);
            plan = app.internal.input.SourceScheduler(0).prepareBurst(0, cached.DomainSize);
            times = 0.25*plan.ActiveTimes;

            runRetimedSequence(cached, plan.Positions, times);
            runRetimedSequence(reference, plan.Positions, times);

            testCase.verifyEqual(cached.snapshot(Derivatives=true), reference.snapshot(Derivatives=true));
            state = cached.diagnostics();
            testCase.verifyGreaterThanOrEqual(state.LoadingCache.EntryCount, double(Boundary > 0));
            testCase.verifyLessThanOrEqual(state.LoadingCache.MemoryBytes, state.LoadingCache.ByteLimit);
            testCase.verifyEqual(reference.diagnostics().LoadingCache.MemoryBytes, 0);
        end

        function sourceAndGridInvalidateCache(testCase, Boundary)
            model = makeSimulation(Boundary);
            reserveSeparatedSources(model);
            testCase.assertGreaterThan(model.diagnostics().LoadingCache.EntryCount, 0);
            source = app.internal.input.Source(0.075, 0.005, "Wavemaker");

            model.commitSource(model.prepareSource(source));

            testCase.verifyEqual(model.diagnostics().LoadingCache.EntryCount, 0);
            model.cancelReservation();
            model.clear();
            setup = app.internal.simulation.defaultSetup();
            model.commitSource(model.prepareSource(setup.Source));
            reserveSeparatedSources(model);
            testCase.assertGreaterThan(model.diagnostics().LoadingCache.EntryCount, 0);

            model.commitGrid(model.prepareGrid(151));

            testCase.verifyEqual(model.diagnostics().LoadingCache.EntryCount, 0);
            testCase.verifyEqual(model.ReservedCount, 6);
        end

        function rejectionPreservesPreparedCache(testCase, Boundary)
            model = makeSimulation(Boundary);
            reserveSeparatedSources(model);
            before = model.diagnostics();
            testCase.assertGreaterThan(before.LoadingCache.EntryCount, 0);

            testCase.verifyError(@() model.reserveInputs(20, Positions=zeros(20, 2), ...
                Times=zeros(20, 1)), "RippleSimulator:WaveLoading");

            testCase.verifyEqual(model.diagnostics(), before);
            model.clear();
            testCase.verifyEqual(model.diagnostics().LoadingCache.MemoryBytes, 0);
        end
    end
end

function model = makeSimulation(coefficient, options)
    arguments
        coefficient (1, 1) double
        options.LoadingCacheBytes (1, 1) double = 134217728
    end
    setup = app.internal.simulation.defaultSetup();
    if coefficient == 1
        model = app.internal.simulation.ReflectingSimulation( ...
            setup.Fluid, setup.DomainSize, 101, setup.Source, ...
            SettlingPeriods=10, AccumulateDisplay=false, LoadingCacheBytes=options.LoadingCacheBytes);
    else
        model = app.internal.simulation.Simulation(setup.Fluid, setup.DomainSize, 101, ...
            setup.Source, SettlingPeriods=10, TablePeriods=10, CacheBytes=536870912, ...
            ReflectionCoefficient=coefficient, AccumulateDisplay=false, LoadingCacheBytes=options.LoadingCacheBytes);
    end
end

function runRetimedSequence(model, positions, times)
    model.reserveInputs(20, Positions=positions, Times=times);
    model.retimeReservations(0, 0.5);
    acceptReservedSources(model, positions, 0.5*times);
    model.advanceTo(0.35);
end

function reserveSeparatedSources(model)
    model.reserveInputs(6, Positions=zeros(6, 2), Times=0.5*(0:5)');
end

function acceptReservedSources(model, positions, times)
    for index = 1:numel(times)
        model.addSource(times(index), positions(index, :), Reserved=true);
    end
end
