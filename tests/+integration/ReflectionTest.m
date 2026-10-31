classdef (Sealed) ReflectionTest < support.ProjectTestCase
    % REFLECTIONTEST Verify wall symmetry and precomputed image-source fields.

    properties (TestParameter)
        Position = struct(Side=[0.26, 0], Corner=[0.26, 0.26])
        Periods = struct(Early=2.317, Late=7.137)
    end

    properties
        Response
    end

    methods (TestClassSetup)
        function prepareImageResponse(testCase)
            setup = app.internal.simulation.defaultSetup();
            testCase.Response = app.internal.responses.ImageResponse( ...
                setup.Fluid, setup.Source, setup.DomainSize, 0.75, 10, 101);
        end
    end

    methods (Test, TestTags = {'Integration'})
        function preparedImagesMatchDirectSum(testCase, Position, Periods)
            response = testCase.Response;
            coordinates = linspace(-response.DomainSize/2, response.DomainSize/2, 101);
            age = Periods*response.Period;
            mapping = response.mapPosition(coordinates, Position, 536870912);
            expected = directImageSum(response, coordinates, Position, age);
            displacementScale = response.Period/(2*pi*response.Fluid.Density*response.Source.Width);

            actual = response.sample(mapping, age);

            testCase.verifyEqual(actual, expected, AbsTol=2e-4*displacementScale);
        end

        function idealWallsHaveZeroNormalSlope(testCase, Position, Periods)
            setup = app.internal.simulation.defaultSetup();
            source = app.internal.input.Source(setup.Source.Wavelength, 0.01);
            simulation = app.internal.simulation.ReflectingSimulation( ...
                setup.Fluid, setup.DomainSize, 101, source, SettlingPeriods=10);
            simulation.addSource(0, Position);

            simulation.advanceTo(Periods*testCase.Response.Period);
            field = simulation.snapshot(Derivatives=true);

            testCase.verifyEqual(field.GradientX(:, [1, end]), zeros(101, 2), AbsTol=1e-12);
            testCase.verifyEqual(field.GradientY([1, end], :), zeros(2, 101), AbsTol=1e-12);
        end

        function reflectedMotionSettlesExactly(testCase)
            setup = app.internal.simulation.defaultSetup();
            source = app.internal.input.Source(setup.Source.Wavelength, 0.01);
            simulation = app.internal.simulation.ReflectingSimulation( ...
                setup.Fluid, setup.DomainSize, 101, source, SettlingPeriods=10);
            simulation.addSource(0, [0.26, 0.26]);

            simulation.advanceTo(11*testCase.Response.TimeScale);
            field = simulation.snapshot(Derivatives=true);

            testCase.verifyTrue(field.IsAtRest);
            testCase.verifyEqual(field.Elevation, zeros(101), AbsTol=0);
            testCase.verifyEqual(field.Velocity, zeros(101), AbsTol=0);
        end
    end
end

function field = directImageSum(response, coordinates, position, age)
    [x, y] = meshgrid(coordinates);
    field = zeros(size(x));
    orders = -response.ImageOrder:response.ImageOrder;
    for horizontal = orders
        for vertical = orders
            image = response.DomainSize*[horizontal, vertical]+(-1).^[horizontal, vertical].*position;
            radii = hypot(x-image(1), y-image(2));
            mapping = response.Radial.mapRadii(radii);
            amplitude = response.ReflectionCoefficient^(abs(horizontal)+abs(vertical));
            field = field + amplitude*response.Radial.sample(mapping, age);
        end
    end
end
