classdef WaveDispersionTest < support.ProjectTestCase
    % WAVEDISPERSIONTEST Verify dispersion data and the corresponding curves.

    properties (Access = private)
        Figures
        Timers
    end

    methods (TestMethodSetup)
        function configureHiddenFigures(testCase)
            testCase.Figures = findall(groot, "Type", "figure");
            testCase.Timers = timerfindall();
            visibility = get(groot, "DefaultFigureVisible");
            testCase.addTeardown(@() set(groot, "DefaultFigureVisible", visibility));
            testCase.addTeardown(@() closeOwnedFigures(testCase.Figures));
            set(groot, "DefaultFigureVisible", "off");
        end
    end

    methods (Test, TestTags = {'Integration'})
        function returnsDispersionMeasurements(testCase)
            waveProperties = plotWaveDispersion();
            wavenumber = 2*pi./waveProperties.Wavelength;
            derivative = gradient(waveProperties.AngularFrequency)./gradient(wavenumber);

            testCase.verifySize(waveProperties.Wavelength, [1, 400]);
            testCase.verifyEqual(waveProperties.Wavelength([1, end]), [0.002, 0.2], AbsTol=1e-15);
            testCase.verifyEqual(waveProperties.PhaseVelocity, ...
                waveProperties.AngularFrequency./wavenumber, AbsTol=eps);
            testCase.verifyEqual(waveProperties.GroupVelocity(2:end-1), derivative(2:end-1), RelTol=1e-4);
            testCase.verifyGreaterThan(waveProperties.PhaseVelocity, 0);
            testCase.verifyGreaterThan(waveProperties.GroupVelocity, 0);
            testCase.verifyGreaterThan(waveProperties.CrossoverWavelength, 0.017);
            testCase.verifyLessThan(waveProperties.CrossoverWavelength, 0.018);
            testCase.verifyGreaterThan(waveProperties.GroupVelocity(1), waveProperties.PhaseVelocity(1));
            testCase.verifyLessThan(waveProperties.GroupVelocity(end), waveProperties.PhaseVelocity(end));
            testCase.verifyEqual(timerfindall(), testCase.Timers);
        end

        function plottedCurvesMatchOutput(testCase)
            waveProperties = plotWaveDispersion();
            figures = setdiff(findall(groot, "Type", "figure"), testCase.Figures);
            testCase.assertNumElements(figures, 1);
            axesHandle = findobj(figures, "Type", "axes");
            lines = flipud(findobj(axesHandle, "Type", "line"));
            testCase.assertNumElements(lines, 2);
            testCase.verifyEqual(lines(1).XData, 1000*waveProperties.Wavelength, AbsTol=eps);
            testCase.verifyEqual(lines(2).XData, 1000*waveProperties.Wavelength, AbsTol=eps);
            testCase.verifyEqual(lines(1).YData, waveProperties.PhaseVelocity, AbsTol=eps);
            testCase.verifyEqual(lines(2).YData, waveProperties.GroupVelocity, AbsTol=eps);
        end

        function noOutputCallIsQuiet(testCase)
            output = evalc('plotWaveDispersion()');
            testCase.verifyEmpty(strtrim(output));
            testCase.verifyEqual(timerfindall(), testCase.Timers);
        end
    end
end

function closeOwnedFigures(original)
    owned = setdiff(findall(groot, "Type", "figure"), original);
    for fig = reshape(owned, 1, [])
        close(fig);
    end
end
