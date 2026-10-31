classdef FluidPropertiesTest < support.ProjectTestCase
    % FLUIDPROPERTIESTEST Verify property correlations, units, and input ranges.

    properties (TestParameter)
        Grade = struct(Low=struct(Name="5cSt", SpecificGravity=0.915, Viscosity=5e-6), ...
            High=struct(Name="100cSt", SpecificGravity=0.965, Viscosity=100e-6))
    end

    methods (Test, TestTags = {'Unit'})
        function waterMatchesIAPWSValues(testCase)
            % IAPWS SR6-08(2011), verification table at 298.15 K and 0.1 MPa.
            fluid = app.internal.materials.water(25);

            testCase.verifyEqual(fluid.Density, 997.047013, AbsTol=5e-7);
            testCase.verifyEqual(fluid.DynamicViscosity, 889.996774e-6, AbsTol=5e-13);
        end

        function surfaceTensionMatchesIAPWS(testCase)
            % IAPWS R1-76(2014), rounded value at 20 degrees Celsius.
            fluid = app.internal.materials.water(20);

            testCase.verifyEqual(fluid.SurfaceTension, 72.74e-3, AbsTol=5e-6);
        end

        function waterRespondsToTemperature(testCase)
            cool = app.internal.materials.water(20);
            warm = app.internal.materials.water(40);

            testCase.verifyLessThan(warm.Density, cool.Density);
            testCase.verifyLessThan(warm.DynamicViscosity, cool.DynamicViscosity);
            testCase.verifyLessThan(warm.SurfaceTension, cool.SurfaceTension);
        end

        function siliconeMatchesSpecificGravity(testCase, Grade)
            reference = app.internal.materials.water(4);

            fluid = app.internal.materials.silicone(Grade.Name);

            testCase.verifyEqual(fluid.Density, Grade.SpecificGravity*reference.Density, AbsTol=1e-12);
            testCase.verifyEqual(fluid.KinematicViscosity, Grade.Viscosity, AbsTol=1e-19);
            testCase.verifyEqual(fluid.Temperature, 25, AbsTol=eps);
        end

        function customViscosityRetainsSIUnits(testCase)
            fluid = app.internal.materials.Fluid("Reference", 20, 1250, 0.0125, 0.06, "Analytic values");

            testCase.verifyEqual(fluid.KinematicViscosity, 1e-5, AbsTol=1e-20);
        end

        function waterRejectsLowTemperature(testCase)
            testCase.verifyError(@() app.internal.materials.water(-1), ...
                "MATLAB:validators:mustBeGreaterThanOrEqual");
        end

        function waterRejectsHighTemperature(testCase)
            testCase.verifyError(@() app.internal.materials.water(41), ...
                "MATLAB:validators:mustBeLessThanOrEqual");
        end

        function waterRejectsNumericText(testCase)
            testCase.verifyError(@() app.internal.materials.water("20"), "MATLAB:validators:mustBeNumeric");
        end
    end
end
