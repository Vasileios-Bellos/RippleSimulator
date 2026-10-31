classdef (Sealed) Fluid
    % FLUID Immutable properties of a homogeneous Newtonian fluid.
    %   Density is in kg/m^3, dynamic viscosity in Pa s, surface tension in
    %   N/m, and temperature in degrees Celsius. Kinematic viscosity is
    %   derived from the stored density and dynamic viscosity.

    properties (SetAccess = immutable)
        Name (1, 1) string
        Temperature (1, 1) double
        Density (1, 1) double
        DynamicViscosity (1, 1) double
        SurfaceTension (1, 1) double
        Reference (1, 1) string
    end

    properties (Dependent, SetAccess = private)
        KinematicViscosity (1, 1) double
    end

    methods
        function obj = Fluid(name, temperature, density, viscosity, tension, reference)
        % FLUID Construct a fluid from a consistent property record.
            arguments
                name {mustBeTextScalar}
                temperature (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite}
                density (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
                viscosity (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                tension (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                reference {mustBeTextScalar}
            end
            obj.Name = string(name);
            obj.Temperature = double(temperature);
            obj.Density = double(density);
            obj.DynamicViscosity = double(viscosity);
            obj.SurfaceTension = double(tension);
            obj.Reference = string(reference);
        end

        function value = get.KinematicViscosity(obj)
            value = obj.DynamicViscosity/obj.Density;
        end

        function record = describe(obj)
        % DESCRIBE Return property values, SI units, and reference metadata.
            arguments
                obj (1, 1) app.internal.materials.Fluid
            end
            record = struct(Name=obj.Name, TemperatureCelsius=obj.Temperature, ...
                DensityKgPerM3=obj.Density, DynamicViscosityPaS=obj.DynamicViscosity, ...
                KinematicViscosityM2PerS=obj.KinematicViscosity, ...
                SurfaceTensionNPerM=obj.SurfaceTension, Reference=obj.Reference);
        end
    end
end
