classdef MaterialPresetsTest < support.ProjectTestCase
    % MATERIALPRESETSTEST Verify fluid selection and source defaults.

    properties (TestParameter)
        Preset = struct( ...
            Water=struct(Name="Water", Wavelength=0.050, Pressure=0.100, Scale=100, Temperature=20), ...
            Olive=struct(Name="Olive oil", Wavelength=0.050, Pressure=0.100, Scale=100, Temperature=23), ...
            Silicone5=struct(Name="KF-96L-5cs", Wavelength=0.050, Pressure=0.100, Scale=100, Temperature=25), ...
            Silicone100=struct(Name="KF-96-100cs", Wavelength=0.050, Pressure=0.100, Scale=100, Temperature=25), ...
            Honey=struct(Name="Honey", Wavelength=0.100, Pressure=0.150, Scale=200, Temperature=30), ...
            Chocolate=struct(Name="Chocolate", Wavelength=0.075, Pressure=0.200, Scale=200, Temperature=60))
    end

    methods (Test, TestTags = {'Integration'})
        function selectionRestoresSourceDefaults(testCase, Preset)
            simulator = rippleSimulator(Visible="off", AutomaticUpdates=false, TimeSource=@() 0, GridResolution=101);
            testCase.addTeardown(@() simulator.close());
            simulator.SoundEnabled = false;
            simulator.Wavelength = 0.075;
            simulator.PressureImpulse = 0.025;
            simulator.HeightScale = 75;
            simulator.LightingEnabled = false;

            simulator.Material = Preset.Name;

            testCase.verifyEqual(simulator.Wavelength, Preset.Wavelength, AbsTol=eps);
            testCase.verifyEqual(simulator.PressureImpulse, Preset.Pressure, AbsTol=eps);
            testCase.verifyEqual(simulator.HeightScale, Preset.Scale, AbsTol=eps);
            testCase.verifyEqual(simulator.Temperature, Preset.Temperature, AbsTol=eps);
            testCase.verifyFalse(simulator.AutomaticHeightScale);
            testCase.verifyTrue(simulator.LightingEnabled);
        end

        function waterReselectionRestoresDefaults(testCase)
            simulator = rippleSimulator(Visible="off", AutomaticUpdates=false, TimeSource=@() 0, GridResolution=101);
            testCase.addTeardown(@() simulator.close());
            simulator.Temperature = 30;
            warmDensity = simulator.FluidProperties.Density;

            simulator.Material = "Water";

            testCase.verifyEqual(simulator.Temperature, 20, AbsTol=eps);
            testCase.verifyGreaterThan(simulator.FluidProperties.Density, warmDensity);
            testCase.verifyEqual(simulator.Wavelength, 0.05, AbsTol=eps);
        end

        function automaticScalingPreservesField(testCase)
            time = support.ManualTime();
            simulator = rippleSimulator(Visible="off", AutomaticUpdates=false, ...
                TimeSource=@() time.Value, GridResolution=101);
            testCase.addTeardown(@() simulator.close());
            simulator.SoundEnabled = false;
            simulator.Material = "Honey";
            simulator.addRipple([0, 0]);
            time.Value = 0.12;
            simulator.update();
            physical = simulator.snapshot(Derivatives=true);

            simulator.AutomaticHeightScale = true;

            testCase.verifyTrue(simulator.AutomaticHeightScale);
            testCase.verifyGreaterThan(simulator.HeightScale, 0);
            testCase.verifyEqual(simulator.snapshot(Derivatives=true), physical);
        end
    end
end
