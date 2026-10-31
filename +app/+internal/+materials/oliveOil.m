function fluid = oliveOil()
% OLIVEOIL Return measured room-temperature properties of an extra virgin oil.
%   Sahasrabudhe et al. (2017), Tables 2, 4, and 6, report 908.7 kg/m^3,
%   0.0741 Pa s, and 0.0319 N/m for their olive-oil sample. The nominal
%   temperature is 23 degrees Celsius; density was measured at 22 +/- 1 C.
%   Surface tension uses the KRUSS pendant-drop result. These properties
%   describe the measured sample, not every grade or brand of cooking oil.

    reference = "Sahasrabudhe et al. (2017), International Journal of Food Properties, " ...
        + "Tables 2, 4 (KRUSS), and 6; https://doi.org/10.1080/10942912.2017.1360905. " ...
        + "Extra virgin olive oil, nominal 23 degrees Celsius; density measured at 22 +/- 1 C. " ...
        + "Newtonian behavior was checked over the reported measurement conditions.";
    fluid = app.internal.materials.Fluid("Olive oil", 23, 908.7, 0.0741, 0.0319, reference);
end
