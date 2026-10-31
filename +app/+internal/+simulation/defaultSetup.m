function setup = defaultSetup(name)
% DEFAULTSETUP Define comparable physical scales for three water experiments.
%   The default gravity-scale experiment spans 650 mm with a characteristic
%   wavelength of 50 mm.
%   The smaller presets span 6.5 characteristic wavelengths. Each preset
%   uses a small-disturbance source. Capillary playback starts at 0.10x;
%   the other presets start at 0.25x.

    arguments
        name {mustBeTextScalar, mustBeMember(name, ["Balanced", "Capillary", "Gravity"])} = "Gravity"
    end
    fluid = app.internal.materials.water(20);
    switch string(name)
        case "Balanced"
            wavelength = 2*pi*sqrt(fluid.SurfaceTension/(fluid.Density*9.81));
        case "Capillary"
            wavelength = 0.005;
        case "Gravity"
            wavelength = 0.05;
    end
    domainSize = 6.5*wavelength;
    if string(name) == "Gravity"
        domainSize = 0.65;
    end
    wavenumber = 2*pi/wavelength;
    frequency = app.internal.physics.dispersion(wavenumber, fluid);
    referenceWavelength = 0.05;
    referenceFrequency = app.internal.physics.dispersion(2*pi/referenceWavelength, fluid);
    pressure = 0.1*(wavelength/referenceWavelength)^2*frequency/referenceFrequency;
    if string(name) == "Gravity"
        pressure = 0.1;
    end
    playbackRate = 0.25;
    if string(name) == "Capillary"
        playbackRate = 0.10;
    end
    setup = struct(Name=string(name), Fluid=fluid, DomainSize=domainSize, ...
        Source=app.internal.input.Source(wavelength, pressure), PlaybackRate=playbackRate, ...
        HeightScale=100);
end
