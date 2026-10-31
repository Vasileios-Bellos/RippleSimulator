function fields = radialLateResponse(kernel, radii, times)
% RADIALLATERESPONSE Evaluate a late response without real-axis time aliasing.
%   FIELDS has elevation, vertical velocity, radial slope, and mixed derivative
%   in its third dimension. KERNEL comes from PREPARECONTOUR; radii and times
%   are physical meters and seconds. The method rejects ages at which contour
%   phase growth would make cancellation unreliable.
    arguments
        kernel (1, 1) struct
        radii (:, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
        times (1, :) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
    end
    radius = double(radii)/kernel.Width;
    age = kernel.Frequency*double(times) - kernel.TimeOffset;
    assert(all(age > 0), "RippleSimulator:ContourSourceActive", ...
        "The late response requires a completed source excitation.");
    growth = real(kernel.Pole)*age + max(radius)*abs(imag(kernel.Wavenumber));
    assert(max(growth, [], "all") <= 0, "RippleSimulator:ContourPhaseGrowth", ...
        "The requested ages require real-axis evaluation because contour phase growth is positive.");
    elevation = kernel.Coefficient.*exp(kernel.Pole*age);
    velocity = kernel.Pole.*elevation;
    basis = besselj(0, radius*kernel.Wavenumber.');
    derivativeBasis = -besselj(1, radius*kernel.Wavenumber.');
    fields = 2*real(cat(3, basis*elevation, basis*velocity, ...
        derivativeBasis*(kernel.Wavenumber.*elevation), derivativeBasis*(kernel.Wavenumber.*velocity)));
    fields = fields - evaluateBranch(kernel, radius, age);
    scales = kernel.ElevationScale*[1, kernel.Frequency, 1/kernel.Width, kernel.Frequency/kernel.Width];
    fields = fields.*reshape(scales, 1, 1, 4);
    if kernel.Cutoff < 8
        fields = fields + app.internal.physics.radialHighResponse( ...
            kernel.Fluid, kernel.Source, radii, times, kernel.Cutoff);
    end
end

function fields = evaluateBranch(kernel, radii, ages)
    [nodes, weights] = app.internal.numerics.gaussLegendre(512);
    q = kernel.Cutoff*(nodes + 1)/2;
    measure = kernel.Cutoff*weights/2;
    frequency = sqrt(kernel.Beta*q + (1 - kernel.Beta)*q.^3);
    parameters = kernel.ViscosityRatio*q.^2./frequency;
    [branchNodes, branchWeights] = app.internal.numerics.gaussLegendre(128);
    angle = (branchNodes + 1)*pi/4;
    values = zeros(numel(q), numel(ages));
    derivatives = values;
    for index = 1:numel(q)
        parameter = parameters(index);
        variable = sqrt(max(parameter, 1))*tan(angle);
        jacobian = sqrt(max(parameter, 1))./cos(angle).^2*pi/4;
        density = 8*parameter^1.5*variable.^2 ...
            ./(pi*(((parameter - variable.^2).^2 + 1).^2 + 16*parameter^3*variable.^2));
        rate = -frequency(index)*(parameter + variable.^2);
        weighted = branchWeights.*jacobian.*density/frequency(index);
        if kernel.Mode == "Wavemaker"
            weighted = weighted.*app.internal.physics.completedForcing(rate);
        end
        decay = exp(rate*ages);
        values(index, :) = weighted'*decay;
        derivatives(index, :) = (weighted.*rate)'*decay;
    end
    spectrum = -q.^2.*exp(-q.^2/2).*measure;
    elevation = spectrum.*values;
    velocity = spectrum.*derivatives;
    basis = besselj(0, radii*q');
    derivativeBasis = -besselj(1, radii*q');
    fields = cat(3, basis*elevation, basis*velocity, derivativeBasis*(q.*elevation), derivativeBasis*(q.*velocity));
end
