classdef (Sealed) RestEnvelope
    % RESTENVELOPE Compute upper bounds on a source's wave response.
    %   Bounds cover the magnitudes of surface elevation, vertical velocity,
    %   and surface slope throughout a circular observation region, from a
    %   specified time onward, normalized to unit pressure strength. The
    %   calculation combines the low-wavenumber contour, a real-axis
    %   pole-pair majorant, a viscous branch inequality, and a spectral-tail
    %   allowance. Zero crossings of the sampled response do not constitute
    %   a rest criterion.

    properties (SetAccess = immutable)
        Times (1, :) double
        Bounds (:, 3) double
        Radius (1, 1) double
        QuadratureAllowance (:, 3) double
    end

    methods
        function obj = RestEnvelope(fluid, source, radius)
        % RESTENVELOPE Prepare a monotone future envelope for a unit source.
            arguments
                fluid (1, 1) app.internal.materials.Fluid
                source (1, 1) app.internal.input.Source
                radius (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
            end
            unitSource = app.internal.input.Source(source.Wavelength, 1, source.Mode);
            cutoff = app.internal.physics.contourCutoff(fluid, unitSource);
            coarse = app.internal.physics.prepareContour(fluid, unitSource, 256, cutoff);
            refined = app.internal.physics.prepareContour(fluid, unitSource, 512, cutoff);
            normalizedRadius = radius/source.Width;
            logWeight = log(2*abs(refined.Coefficient)) ...
                + normalizedRadius*abs(imag(refined.Wavenumber));
            start = max(8*pi, max((logWeight - 500)./(-real(refined.Pole))));
            startPeriods = ceil(start/(2*pi)*2)/2;
            periods = unique([startPeriods, startPeriods:0.5:128, ...
                max(startPeriods, 128):4:512, max(startPeriods, 512):32:4096]);
            ages = periods*2*pi;
            coarseValues = contourBounds(coarse, normalizedRadius, ages) ...
                + app.internal.physics.realPoleEnvelope(fluid, unitSource, ages, cutoff, 256);
            refinedValues = contourBounds(refined, normalizedRadius, ages) ...
                + app.internal.physics.realPoleEnvelope(fluid, unitSource, ages, cutoff, 512);
            allowance = 8*abs(refinedValues - coarseValues) + 1e-12;
            branch = branchBounds(refined.ViscosityRatio, refined.Beta, ages)*refined.ForcingNorm;
            tail = spectralTail(refined.Beta, 8)*refined.ForcingNorm;
            values = refinedValues + branch + tail + allowance;
            values = flipud(cummax(flipud(values), 1));
            scales = refined.ElevationScale*[1, refined.Frequency, 1/refined.Width];
            obj.Times = (ages + refined.TimeOffset)/refined.Frequency;
            obj.Bounds = values.*scales;
            obj.Radius = double(radius);
            obj.QuadratureAllowance = allowance.*scales;
        end

        function value = bound(obj, age)
        % BOUND Return a conservative envelope for the current and all later ages.
            arguments
                obj (1, 1) app.internal.responses.RestEnvelope
                age (1, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
            end
            index = discretize(double(age), [obj.Times, Inf]);
            covered = isfinite(index);
            value = Inf(numel(age), 3);
            value(covered, :) = obj.Bounds(index(covered), :);
        end
    end
end

function values = contourBounds(kernel, radius, ages)
    logWeight = log(2*abs(kernel.Coefficient)) + radius*abs(imag(kernel.Wavenumber));
    exponential = exp(logWeight + real(kernel.Pole)*ages);
    values = [sum(exponential, 1); sum(abs(kernel.Pole).*exponential, 1); ...
        sum(abs(kernel.Wavenumber).*exponential, 1)]';
end

function values = branchBounds(epsilon, beta, ages)
    factor = 2/sqrt(pi)*(epsilon./ages).^1.5/beta^2;
    width = 0.5 + epsilon*ages;
    values = [factor./(2*width.^2); ...
        factor.*(epsilon./width.^3 + 3./(4*ages.*width.^2)); ...
        factor.*3*sqrt(pi)./(8*width.^2.5)]';
end

function value = spectralTail(beta, cutoff)
    powers = [1.5, 2, 2.5];
    shape = (powers + 1)/2;
    integrals = 2.^((powers - 1)/2).*gamma(shape).*gammainc(cutoff^2/2, shape, "upper");
    value = integrals.*[1/sqrt(beta), 1, 1/sqrt(beta)];
end
