function simulator = gravityWavesExample()
% gravityWavesExample Explore gravity-scale ripples in water.
%   SIMULATOR = gravityWavesExample() opens the Gravity wave setup at its
%   preset settings. Click the surface to create ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, gravityCapillaryWavesExample,
%   capillaryWavesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
end
