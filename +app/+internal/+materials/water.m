function fluid = water(temperature)
% WATER Return IAPWS properties for water between 0 and 40 degrees Celsius.
%   FLUID = WATER(TEMPERATURE) evaluates liquid density and dynamic viscosity
%   at 0.1 MPa using SR6-08(2011), and liquid-vapor surface tension using
%   R1-76(2014). The default temperature is 20 degrees Celsius.
%
%   References:
%   https://iapws.org/technical-guidance/release/LiquidWater.download
%   https://iapws.org/documents/release/Surf-H2O.download
    arguments
        temperature (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, ...
            mustBeGreaterThanOrEqual(temperature, 0), mustBeLessThanOrEqual(temperature, 40)} = 20
    end
    kelvin = double(temperature) + 273.15;
    density = calculateDensity(kelvin);
    viscosity = calculateViscosity(kelvin);
    reducedTemperature = 1 - kelvin/647.096;
    tension = 0.2358*reducedTemperature^1.256*(1 - 0.625*reducedTemperature);
    reference = "IAPWS SR6-08(2011), 0.1 MPa; IAPWS R1-76(2014), liquid-vapor interface";
    fluid = app.internal.materials.Fluid("Water", temperature, density, viscosity, tension, reference);
end

function density = calculateDensity(temperature)
    alpha = 10/(593-temperature);
    beta = 10/(temperature-232);
    firstCoefficients = [6.74458446e3, -2.22521604e5, 1.00231247e8, -1.63552118e9, 8.32299658e9];
    firstPowers = [4, 5, 7, 8, 9];
    secondCoefficients = [5.78545292e-3, -1.53195665e-2, 3.11337859e-2, ...
        -4.23546241e-2, 3.38713507e-2, -1.19946761e-2];
    secondPowers = 1:6;
    volume = 461.51805*10/1e5*(1.93763157e-2 ...
        + sum(firstCoefficients.*alpha.^firstPowers) + sum(secondCoefficients.*beta.^secondPowers));
    density = 1/volume;
end

function viscosity = calculateViscosity(temperature)
    coefficients = [280.68, 511.45, 61.131, 0.45903];
    powers = [-1.9, -7.7, -19.6, -40];
    viscosity = 1e-6*sum(coefficients.*(temperature/300).^powers);
end
