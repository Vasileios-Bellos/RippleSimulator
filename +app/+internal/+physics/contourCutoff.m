function cutoff = contourCutoff(fluid, source)
% CONTOURCUTOFF Select a pole-contour interval below critical viscous behavior.
%   The dimensionless cutoff q=k*s is at most eight. Its largest modal
%   viscosity ratio is at most 0.08, within the contour's qualified range.
%   Wavenumbers above this cutoff require a separate real-axis contribution.
    arguments
        fluid (1, 1) app.internal.materials.Fluid
        source (1, 1) app.internal.input.Source
    end
    cutoff = 8;
    if ratioAt(cutoff, fluid, source) <= 0.08
        return
    end
    lower = 0;
    upper = cutoff;
    for iteration = 1:48
        middle = (lower + upper)/2;
        if ratioAt(middle, fluid, source) <= 0.08
            lower = middle;
        else
            upper = middle;
        end
    end
    cutoff = lower;
end

function ratio = ratioAt(coordinate, fluid, source)
    wavenumber = coordinate*source.Wavenumber;
    frequency = app.internal.physics.dispersion(wavenumber, fluid);
    ratio = fluid.KinematicViscosity*wavenumber^2/frequency;
end
