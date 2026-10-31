function fluid = customFluid(properties)
% CUSTOMFLUID Validate a complete user-defined Newtonian material record.
%   Required scalar fields are Density (kg/m^3), DynamicViscosity (Pa s),
%   SurfaceTension (N/m), and Temperature (degrees Celsius). No temperature
%   correlation or material-specific rheology is inferred from these values.
    arguments
        properties (1, 1) struct
    end
    required = ["Density", "DynamicViscosity", "SurfaceTension", "Temperature"];
    assert(isequal(sort(string(fieldnames(properties)))', sort(required)), ...
        "RippleSimulator:CustomMaterialFields", ...
        "Specify Density, DynamicViscosity, SurfaceTension, and Temperature in the custom material record.");
    fluid = app.internal.materials.Fluid("Custom", properties.Temperature, properties.Density, ...
        properties.DynamicViscosity, properties.SurfaceTension, "User-defined Newtonian fluid properties.");
    assert(fluid.DynamicViscosity > 0, "RippleSimulator:CustomViscosity", ...
        "Dynamic viscosity must be positive for the viscous response model.");
end
