classdef InspectWaveFieldTest < support.ProjectTestCase
    % INSPECTWAVEFIELDTEST Verify sampled wave fields and owned-resource cleanup.

    properties (Access = private)
        Figures
        Timers
    end

    properties (TestParameter)
        Setup = {"Gravity", "Balanced", "Capillary"}
        Mode = {"Impulse", "Wavemaker"}
    end

    methods (TestMethodSetup)
        function configureHiddenFigures(testCase)
            testCase.Figures = findall(groot, "Type", "figure");
            testCase.Timers = timerfindall;
            visibility = get(groot, "DefaultFigureVisible");
            testCase.addTeardown(@() set(groot, "DefaultFigureVisible", visibility));
            testCase.addTeardown(@() closeOwnedFigures(testCase.Figures));
            set(groot, "DefaultFigureVisible", "off");
        end
    end

    methods (Test, TestTags = {'Integration'})
        function rejectedWavelengthReleasesApp(testCase)
            testCase.verifyError(@() inspectWaveField(Wavelength=0.001), "MATLAB:notGreaterEqual");
            testCase.verifyEqual(timerfindall, testCase.Timers);
            testCase.verifyEqual(findall(groot, "Type", "figure"), testCase.Figures);
        end

        function reachesRestWithPhysicalUnits(testCase)
            waveField = inspectWaveField(Setup="Gravity", SourceMode="Impulse", ...
                Wavelength=0.05, PressureImpulse=0.1, PlaybackRate=20);
            shape = [201, 201, numel(waveField.Time)];
            testCase.verifySize(waveField.Elevation, shape);
            testCase.verifySize(waveField.Velocity, shape);
            testCase.verifySize(waveField.GradientX, shape);
            testCase.verifySize(waveField.GradientY, shape);
            testCase.verifyEqual(waveField.Elevation(:, :, end), zeros(201));
            testCase.verifyEqual(waveField.Velocity(:, :, end), zeros(201));
            testCase.verifyEqual(waveField.GradientX(:, :, end), zeros(201));
            testCase.verifyEqual(waveField.GradientY(:, :, end), zeros(201));
            testCase.verifyEqual(waveField.Coordinates([1, end]), [-0.325, 0.325], AbsTol=eps);
            testCase.verifyGreaterThan(waveField.Time(end), 1.69);
            testCase.verifyLessThan(waveField.Time(end), 1.70);
            testCase.verifyEqual(waveField.Time(1), 0);
            testCase.verifyEqual(diff(waveField.Time), repmat(waveField.Time(2), 1, ...
                numel(waveField.Time)-1), AbsTol=1e-14);
            testCase.verifyEqual(waveField.Elevation(:, :, 1), zeros(201));
            testCase.verifyLessThan(waveField.Velocity(101, 101, 1), 0);
            testCase.verifyLessThan(waveField.Elevation(101, 101, 2), 0);
            testCase.verifyGreaterThan(waveField.Elevation(101, 101, 2), -0.0001);
            testCase.verifyEqual(min(waveField.Elevation, [], "all"), -0.000302, AbsTol=0.000002);
            testCase.verifyEqual(timerfindall, testCase.Timers);
            testCase.verifyEqual(findall(groot, "Type", "figure"), testCase.Figures);
        end

        function noOutputCallIsQuiet(testCase)
            output = evalc('inspectWaveField(PlaybackRate=20)');
            testCase.verifyEmpty(strtrim(output));
            testCase.verifyEqual(timerfindall, testCase.Timers);
        end

        function closesDuringPlayback(testCase)
            closer = timer(ExecutionMode="fixedSpacing", Period=0.05, ...
                TimerFcn=@(~, ~) closeAnimation(testCase.Figures), Name="InspectWaveFieldTest");
            testCase.addTeardown(@() releaseTimer(closer));
            start(closer);
            waveField = inspectWaveField(Setup="Gravity", SourceMode="Impulse", ...
                Wavelength=0.05, PressureImpulse=0.1, SampleInterval=0.01);
            stop(closer);
            testCase.verifyGreaterThan(waveField.Time(end), 1.69);
            testCase.verifyLessThan(waveField.Time(end), 1.70);
            testCase.verifyGreaterThan(max(abs(waveField.Elevation), [], "all"), 0);
            testCase.verifyEqual(numel(findall(groot, "Type", "figure")), numel(testCase.Figures));
            testCase.verifyEqual(numel(timerfindall), numel(testCase.Timers)+1);
        end

        function setupAndSourceOptions(testCase, Setup, Mode)
            waveField = inspectWaveField(Setup=Setup, SourceMode=Mode, ...
                PlaybackRate=20, PlaybackMode="ElapsedTime");
            preset = app.internal.simulation.defaultSetup(Setup);
            testCase.verifyEqual(waveField.DomainSize, preset.DomainSize, AbsTol=eps);
            testCase.verifyEqual(waveField.Elevation(:, :, end), zeros(201));
            testCase.verifyEqual(waveField.Elevation(:, :, 1), zeros(201));
            testCase.verifyLessThan(waveField.Elevation(101, 101, 2), 0);
            testCase.verifyTrue(all(isfinite(waveField.Elevation), "all"));
            testCase.verifyEqual(timerfindall, testCase.Timers);
            testCase.verifyEqual(findall(groot, "Type", "figure"), testCase.Figures);
        end

        function loadingScalesLinearly(testCase)
            weak = inspectWaveField(SourceMode="Impulse", Wavelength=0.075, PressureImpulse=0.05, ...
                PlaybackRate=20, PlaybackMode="ElapsedTime", SampleInterval=0.01);
            strong = inspectWaveField(SourceMode="Impulse", Wavelength=0.075, PressureImpulse=0.10, ...
                PlaybackRate=20, PlaybackMode="ElapsedTime", SampleInterval=0.01);
            testCase.verifyEqual(strong.Time, weak.Time);
            testCase.verifyEqual(strong.Elevation, 2*weak.Elevation, AbsTol=1e-12);
            testCase.verifyEqual(strong.Velocity, 2*weak.Velocity, AbsTol=1e-12);
            testCase.verifyEqual(strong.GradientX, 2*weak.GradientX, AbsTol=1e-12);
            testCase.verifyEqual(strong.GradientY, 2*weak.GradientY, AbsTol=1e-12);
        end

        function samplesAgreeWithSnapshots(testCase)
            waveField = inspectWaveField(Setup="Gravity", SourceMode="Impulse", ...
                PlaybackRate=20, PlaybackMode="ElapsedTime", SampleInterval=0.01);
            clock = support.ManualTime();
            simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, ...
                TimeSource=@() clock.Value, Setup="Gravity");
            testCase.addTeardown(@() simulator.close());
            simulator.SoundEnabled = false;
            simulator.PlaybackRate = 1;
            simulator.addRipple([0, 0]);
            sampleIndex = 12;
            clock.Value = waveField.Time(sampleIndex);
            simulator.update();
            state = simulator.snapshot(Derivatives=true);
            testCase.verifyEqual(state.Time, waveField.Time(sampleIndex), AbsTol=eps);
            testCase.verifyEqual(state.Elevation, waveField.Elevation(:, :, sampleIndex), AbsTol=1e-12);
            testCase.verifyEqual(state.Velocity, waveField.Velocity(:, :, sampleIndex), AbsTol=1e-12);
            testCase.verifyEqual(state.GradientX, waveField.GradientX(:, :, sampleIndex), AbsTol=1e-12);
            testCase.verifyEqual(state.GradientY, waveField.GradientY(:, :, sampleIndex), AbsTol=1e-12);
        end

        function playbackPreservesMeasurements(testCase)
            sampled = inspectWaveField(PlaybackRate=20, SampleInterval=0.002, PlaybackMode="Sampled");
            elapsed = inspectWaveField(PlaybackRate=20, SampleInterval=0.002, PlaybackMode="ElapsedTime");
            testCase.verifyEqual(elapsed, sampled);
        end
    end
end

function releaseTimer(owned)
    stop(owned);
    delete(owned);
end

function closeAnimation(original)
    owned = setdiff(findall(groot, "Type", "figure"), original);
    for fig = reshape(owned, 1, [])
        if string(fig.Name) == "Physical Ripple Elevation"
            labels = findall(fig, Type="text");
            for label = reshape(labels, 1, [])
                value = string(label.String);
                if isscalar(value) && startsWith(value, "Surface elevation at ") ...
                        && value ~= "Surface elevation at 0.000 s"
                    close(fig);
                    return
                end
            end
        end
    end
end

function closeOwnedFigures(original)
    owned = setdiff(findall(groot, "Type", "figure"), original);
    for fig = reshape(owned, 1, [])
        close(fig);
    end
end
