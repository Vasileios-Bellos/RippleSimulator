classdef (Sealed) TankResponseCacheTest < support.ProjectTestCase
    % TANKRESPONSECACHETEST Verify shared responses and physical source strengths.

    properties (TestParameter)
        Mode = {"Impulse", "Wavemaker"}
    end

    methods (Test, TestTags = {'Integration'})
        function pressureUsesTheSameUnitResponse(testCase, Mode)
            fluid = app.internal.materials.water();
            source = app.internal.input.Source(0.05, 0.01, Mode);
            stronger = app.internal.input.Source(0.05, 0.02, Mode);
            first = app.internal.responses.prepareTankResponse(fluid, 0.1, source, Periods=10);

            second = app.internal.responses.prepareTankResponse(fluid, 0.1, stronger, Periods=10);

            testCase.verifyEqual(first.Source.PressureImpulse, 1, AbsTol=0);
            testCase.verifyEqual(second.Source.PressureImpulse, 1, AbsTol=0);
            testCase.verifyEqual(second, first);
        end

        function wavelengthSelectsItsSpectrum(testCase)
            fluid = app.internal.materials.water();
            original = app.internal.input.Source(0.05, 0.01);
            changed = app.internal.input.Source(0.04, 0.01);
            first = app.internal.responses.prepareTankResponse(fluid, 0.1, original, Periods=10);
            frequency = app.internal.physics.dispersion(changed.Wavenumber, fluid);

            second = app.internal.responses.prepareTankResponse(fluid, 0.1, changed, Periods=10);

            testCase.verifyEqual(second.Source.Wavelength, changed.Wavelength, AbsTol=0);
            testCase.verifyEqual(second.Period, 2*pi/frequency, AbsTol=eps);
            testCase.verifyNotEqual(second.Period, first.Period);
        end

        function wavemakerRetainsItsInitialState(testCase)
            fluid = app.internal.materials.water();
            impulse = app.internal.input.Source(0.05, 0.01, "Impulse");
            wavemaker = app.internal.input.Source(0.05, 0.01, "Wavemaker");
            first = app.internal.responses.prepareTankResponse(fluid, 0.1, impulse, Periods=10);
            [~, impulseVelocity] = first.sample(0);

            second = app.internal.responses.prepareTankResponse(fluid, 0.1, wavemaker, Periods=10);
            [~, initialVelocity] = second.sample(0);

            testCase.verifyEqual(second.Source.Mode, "Wavemaker");
            testCase.verifyGreaterThan(norm(impulseVelocity), 0);
            testCase.verifyEqual(initialVelocity, zeros(size(initialVelocity)), AbsTol=0);
        end

        function cachedResponseRespectsBudget(testCase)
            fluid = app.internal.materials.water();
            source = app.internal.input.Source(0.05, 0.01);
            response = app.internal.responses.prepareTankResponse(fluid, 0.1, source, Periods=10);
            testCase.assertNotEmpty(response.PreparedResponse);

            testCase.verifyError(@() app.internal.responses.prepareTankResponse( ...
                fluid, 0.1, source, Periods=10, ByteLimit=1), "RippleSimulator:CacheMemory");
        end

        function eventsKeepTheirPhysicalStrength(testCase, Mode)
            fluid = app.internal.materials.water();
            source = app.internal.input.Source(0.05, 0.01, Mode);
            changed = app.internal.input.Source(0.05, 0.02, Mode);
            model = app.internal.simulation.ReflectingSimulation(fluid, 0.1, 51, source, SettlingPeriods=10);
            testCase.addTeardown(@() delete(model));
            model.addSource(0, [0, 0]);

            model.commitSource(model.prepareSource(changed));
            model.addSource(0, [0.01, 0]);
            state = model.diagnostics();

            testCase.verifyEqual(model.Source.PressureImpulse, changed.PressureImpulse, AbsTol=0);
            testCase.verifyEqual(state.AcceptedCount, 2);
            testCase.verifyEqual([state.Events.Strength], ...
                [source.PressureImpulse, changed.PressureImpulse], AbsTol=0);
        end
    end
end
