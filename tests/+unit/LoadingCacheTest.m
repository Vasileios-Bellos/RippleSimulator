classdef (Sealed) LoadingCacheTest < support.ProjectTestCase
    % LOADINGCACHETEST Verify storage, reuse, and expiration of loading envelopes.

    methods (Test, TestTags = {'Unit'})
        function reusesPositionsAcrossAges(testCase)
            records = makeRecords();
            original = app.internal.simulation.LoadingCache();
            [cache, first] = original.bound(records, 0.65, 0, 0, 0.1);
            records.Time = 0.2;
            records.Strength = 2;
            [reused, second] = cache.bound(records, 0.65, 0.2, 0, 0.1);

            testCase.verifyEqual(original.EntryCount, 0);
            testCase.verifyEqual(reused.diagnostics(), cache.diagnostics());
            testCase.verifyEqual(second, 2*first, AbsTol=1e-12);
        end

        function budgetFallsBackToFullBound(testCase)
            records = makeRecords();
            reference = app.internal.numerics.boundScheduledSlopes(records, 0.65, 0, 0, 0.1);
            cache = app.internal.simulation.LoadingCache(ByteLimit=1);

            [cache, value] = cache.bound(records, 0.65, 0, 0, 0.1);

            testCase.verifyEqual(value, reference);
            testCase.verifyEqual(cache.MemoryBytes, 0);
        end

        function retiresUnusedPositions(testCase)
            records = repmat(makeRecords(), 1, 2);
            records(2).Position = [0.1, 0.1];
            cache = app.internal.simulation.LoadingCache();
            [cache, ~] = cache.bound(records, 0.65, 0, 0, 0.1);
            [cache, value] = cache.bound(records(2), 0.65, 0, 0, 0.1);
            reference = app.internal.simulation.LoadingCache();
            [reference, expected] = reference.bound(records(2), 0.65, 0, 0, 0.1);

            testCase.verifyEqual(cache.EntryCount, 1);
            testCase.verifyEqual(cache.MemoryBytes, reference.MemoryBytes);
            testCase.verifyEqual(value, expected);
        end

        function expiryReleasesStoredEnvelopes(testCase)
            records = makeRecords();
            cache = app.internal.simulation.LoadingCache();
            [cache, ~] = cache.bound(records, 0.65, 0, 0, 0.1);

            [cache, value] = cache.bound(records, 0.65, 1, 1e-6, 0.1);

            testCase.verifyEqual(cache.EntryCount, 0);
            testCase.verifyEqual(value, 1e-6);
        end

        function separatesResponseTables(testCase)
            records = repmat(makeRecords(), 1, 2);
            records(2).TableIndex = 2;
            records(2).Envelope.Bounds = 2*records(2).Envelope.Bounds;
            cache = app.internal.simulation.LoadingCache();

            [cache, value] = cache.bound(records, 0.65, 0, 0, 0.1);
            reference = app.internal.numerics.boundScheduledSlopes(records, 0.65, 0, 0, 0.1);

            testCase.verifyEqual(cache.EntryCount, 2);
            testCase.verifyEqual(value, reference, AbsTol=1e-8);
        end

        function clearPreservesStorageBudget(testCase)
            cache = app.internal.simulation.LoadingCache(ByteLimit=1024);
            [cache, ~] = cache.bound(makeRecords(), 0.65, 0, 0, 0.1);

            cache = cache.clear();

            testCase.verifyEqual(cache.MemoryBytes, 0);
            testCase.verifyEqual(cache.ByteLimit, 1024);
        end

        function preservesDuplicateSources(testCase)
            records = repmat(makeRecords(), 1, 2);
            cache = app.internal.simulation.LoadingCache();
            [cache, first] = cache.bound(records(1), 0.65, 0, 0, 0.1);

            [cache, combined] = cache.bound(records, 0.65, 0, 0, 0.1);
            [cache, remaining] = cache.bound(records(1), 0.65, 0, 0, 0.1);

            testCase.verifyGreaterThanOrEqual(combined, 0.04);
            testCase.verifyGreaterThan(combined, first);
            testCase.verifyEqual(remaining, first);
            testCase.verifyEqual(cache.EntryCount, 1);
        end

        function includesIncreasedAllowance(testCase)
            records = makeRecords();
            cache = app.internal.simulation.LoadingCache();
            [cache, first] = cache.bound(records, 0.65, 0, 0.001, 0.1);

            [~, value] = cache.bound(records, 0.65, 0.2, 0.004, 0.1);

            testCase.verifyGreaterThanOrEqual(value, first+0.003);
            testCase.verifyLessThan(value, 0.1);
        end

        function retainedHistoryRespectsBudget(testCase)
            records = makeRecords();
            cache = app.internal.simulation.LoadingCache(ByteLimit=150);

            [cache, value] = cache.bound(records, 0.65, 0, 0, 0.1);
            [cache, repeated] = cache.bound(records, 0.65, 0.1, 0, 0.1);

            testCase.verifyEqual(cache.EntryCount, 1);
            testCase.verifyLessThanOrEqual(cache.MemoryBytes, cache.ByteLimit);
            testCase.verifyEqual(repeated, value);
        end

        function recalculatesEarlierQueries(testCase)
            records = makeRecords();
            cache = app.internal.simulation.LoadingCache();
            [cache, late] = cache.bound(records, 0.65, 0.95, 0, 0.1);

            [~, earlier] = cache.bound(records, 0.65, 0, 0, 0.1);

            testCase.verifyGreaterThan(earlier, late);
            testCase.verifyGreaterThanOrEqual(earlier, 0.02);
        end

        function retimingRestoresTheCompletePeak(testCase)
            records = makeRecords();
            cache = app.internal.simulation.LoadingCache();
            [cache, late] = cache.bound(records, 0.65, 0.95, 0, 0.1);
            records.Time = 0.9;

            [~, value] = cache.bound(records, 0.65, 0.95, 0, 0.1);

            testCase.verifyGreaterThan(value, late);
            testCase.verifyGreaterThanOrEqual(value, 0.02);
        end

        function requiresCompleteLifetimeCoverage(testCase)
            records = makeRecords();
            cache = app.internal.simulation.LoadingCache();
            [cache, ~] = cache.bound(records, 0.65, 0, 0, 0.1);
            records.Duration = 1.5;

            [~, value] = cache.bound(records, 0.65, 0, 0, 0.1);

            testCase.verifyEqual(value, Inf);
        end
    end
end

function record = makeRecords()
    envelope = struct(Kind="Radial", Cells=2, Times=[0, 0.5, 1], TimeScale=0.1, ...
        Bounds=0.02*ones(64, 2, 7, "single"), SpatialStep=0.1, Allowance=1e-6);
    record = struct(Envelope=envelope, Time=0, Position=[0, 0], Strength=1, Duration=1, TableIndex=1);
end
