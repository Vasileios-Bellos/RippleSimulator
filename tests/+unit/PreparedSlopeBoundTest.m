classdef (Sealed) PreparedSlopeBoundTest < support.ProjectTestCase
    % PREPAREDSLOPEBOUNDTEST Verify temporal refinement of cell-gradient bounds.

    methods (Test, TestTags = {'Unit'})
        function separatesNonoverlappingPeaks(testCase)
            records = makeRecords();
            records(1).Envelope.Bounds(2) = 0.06;
            records(2).Envelope.Bounds(6) = 0.06;
            allowance = 0.003;

            value = app.internal.numerics.boundPreparedSlopes(records, records, 0, allowance, 0.1);

            expected = double(single(0.06))*(1+64*double(eps("single")))+allowance;
            testCase.verifyEqual(value, expected, AbsTol=1e-12);
            testCase.verifyLessThan(value, 0.1);
        end

        function preservesCoincidentPeakBound(testCase)
            records = makeRecords();
            records(1).Envelope.Bounds(2) = 0.06;
            records(2).Envelope.Bounds(2) = 0.06;

            value = app.internal.numerics.boundPreparedSlopes(records, records, 0, 0, 0.1);

            expected = double(single(0.12))*(1+64*double(eps("single")));
            testCase.verifyEqual(value, expected, AbsTol=1e-12);
            testCase.verifyGreaterThan(value, 0.1);
        end
    end
end

function records = makeRecords()
    envelope = struct(Kind="Radial", Cells=1, Times=linspace(0, 1, 65), TimeScale=1, ...
        Bounds=zeros(1, 64, "single"), Allowance=0);
    records = repmat(struct(Envelope=envelope, Time=0, Strength=1, Duration=1), 1, 2);
end
