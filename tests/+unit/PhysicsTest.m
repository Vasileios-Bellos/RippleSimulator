classdef PhysicsTest < support.ProjectTestCase
    % PHYSICSTEST Verify analytic limits, initial conditions, and convergence.

    properties (TestParameter)
        Epsilon = struct(Inviscid=0, Weak=0.001, Intermediate=1.3, Strong=100)
        Mode = {"Impulse", "Wavemaker"}
    end

    methods (Test, TestTags = {'Unit'})
        function gravityGroupVelocityLimit(testCase)
            fluid = app.internal.materials.Fluid("Reference", 20, 1000, 0, 0, "Analytic limit");
            wavenumber = [1, 10, 100];

            [frequency, phaseVelocity, groupVelocity] = app.internal.physics.dispersion(wavenumber, fluid);

            testCase.verifyEqual(frequency.^2, 9.81*wavenumber, AbsTol=2e-13);
            testCase.verifyEqual(groupVelocity, phaseVelocity/2, AbsTol=1e-14);
        end

        function capillaryGroupVelocityLimit(testCase)
            fluid = app.internal.materials.water();
            wavenumber = [1; 10; 100];

            [frequency, phaseVelocity, groupVelocity] = app.internal.physics.dispersion(wavenumber, fluid, 0);

            testCase.verifyEqual(frequency.^2, fluid.SurfaceTension/fluid.Density*wavenumber.^3, ...
                AbsTol=2e-14);
            testCase.verifyEqual(groupVelocity, 1.5*phaseVelocity, AbsTol=1e-14);
        end

        function groupVelocityMatchesDerivative(testCase)
            fluid = app.internal.materials.water();
            wavenumber = [25, 400, 1200];
            increment = 1e-3;
            above = app.internal.physics.dispersion(wavenumber+increment, fluid);
            below = app.internal.physics.dispersion(wavenumber-increment, fluid);

            [~, ~, groupVelocity] = app.internal.physics.dispersion(wavenumber, fluid);

            testCase.verifyEqual(groupVelocity, (above-below)/(2*increment), AbsTol=2e-10);
        end

        function impulseInitialConditions(testCase, Epsilon)
            [elevation, velocity, release] = app.internal.physics.viscousImpulse(Epsilon, 0);

            testCase.verifyEqual(elevation, 0, AbsTol=0);
            testCase.verifyEqual(velocity, 1, AbsTol=0);
            testCase.verifyEqual(release, 1, AbsTol=0);
        end

        function inviscidImpulseIsSinusoidal(testCase)
            times = [0, 0.1, 1, 10, 100];

            [elevation, velocity, release] = app.internal.physics.viscousImpulse(0, times);

            testCase.verifyEqual(elevation, sin(times), AbsTol=eps);
            testCase.verifyEqual(velocity, cos(times), AbsTol=eps);
            testCase.verifyEqual(release, cos(times), AbsTol=eps);
        end

        function velocityMatchesDerivative(testCase, Epsilon)
            times = [1e-4, 0.01, 0.1, 1];
            increment = 1e-7;
            above = app.internal.physics.viscousImpulse(Epsilon, times+increment, 256);
            below = app.internal.physics.viscousImpulse(Epsilon, times-increment, 256);

            [~, velocity] = app.internal.physics.viscousImpulse(Epsilon, times, 256);

            testCase.verifyEqual(velocity, (above-below)/(2*increment), AbsTol=2e-8);
        end

        function viscousQuadratureConverges(testCase, Epsilon)
            times = [0, logspace(-8, 6, 81)];
            [referenceElevation, referenceVelocity] = ...
                app.internal.physics.viscousImpulse(Epsilon, times, 256);

            [elevation, velocity] = app.internal.physics.viscousImpulse(Epsilon, times);

            testCase.verifyEqual(elevation, referenceElevation, AbsTol=1e-11);
            testCase.verifyEqual(velocity, referenceVelocity, AbsTol=3e-9);
        end

        function pressureScalesTheEntireResponse(testCase, Mode)
            fluid = app.internal.materials.water();
            source = app.internal.input.Source(0.05, 0.05, Mode);
            stronger = app.internal.input.Source(0.05, 0.10, Mode);
            radii = [0; 0.005; 0.025; 0.05];
            times = [0, 0.001, 0.02, 0.1];
            reference = app.internal.physics.radialResponse(fluid, source, radii, times);

            actual = app.internal.physics.radialResponse(fluid, stronger, radii, times);

            testCase.verifyEqual(actual, 2*reference, AbsTol=1e-12);
            testCase.verifyEqual(actual(:, 1, 1), zeros(size(radii)), AbsTol=0);
            testCase.verifyLessThan(actual(1, 2, 1), 0);
        end

        function impulseInitialVelocity(testCase)
            fluid = app.internal.materials.water();
            source = app.internal.input.Source(0.05, 0.10);
            expected = -source.PressureImpulse*sqrt(pi/2)/(fluid.Density*source.Width);

            response = app.internal.physics.radialResponse(fluid, source, 0, 0);

            testCase.verifyEqual(response(1, 1, 1), 0, AbsTol=0);
            testCase.verifyEqual(response(1, 1, 2), expected, AbsTol=1e-12);
        end

        function incompatibleModeTimesAreRejected(testCase)
            testCase.verifyError(@() app.internal.physics.viscousImpulse([1; 2], [1, 2]), ...
                "RippleSimulator:ModeTimeShape");
        end
    end
end
