function fluid = silicone(grade)
% SILICONE Return typical properties of a specified KF-96 fluid at 25 C.
%   FLUID = SILICONE("5cSt") uses KF-96L-5cs; "100cSt" uses KF-96-100cs.
%   The source gives typical kinematic viscosity, specific gravity relative
%   to water at 4 C, and surface tension. These are nominal product values,
%   not a batch certificate or a temperature-dependent material correlation.
%   The simulator treats these low-viscosity grades as Newtonian fluids.
    arguments
        grade {mustBeTextScalar, mustBeMember(grade, ["5cSt", "100cSt"])}
    end
    switch string(grade)
        case "5cSt"
            name = "Silicone oil (KF-96L-5cs)";
            viscosity = 5e-6;
            specificGravity = 0.915;
            tension = 0.0197;
        case "100cSt"
            name = "Silicone oil (KF-96-100cs)";
            viscosity = 100e-6;
            specificGravity = 0.965;
            tension = 0.0209;
    end
    referenceWater = app.internal.materials.water(4);
    density = specificGravity*referenceWater.Density;
    reference = "https://www.shinetsusilicone-global.com/catalog/pdf/kf96_e.pdf";
    fluid = app.internal.materials.Fluid(name, 25, density, density*viscosity, tension, reference);
end
