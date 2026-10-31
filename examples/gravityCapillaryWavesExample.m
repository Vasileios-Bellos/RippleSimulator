function simulator = gravityCapillaryWavesExample()
% gravityCapillaryWavesExample Explore gravity-capillary balance in water.
%   SIMULATOR = gravityCapillaryWavesExample() opens the Balanced setup at
%   its preset settings. Gravity and surface tension have equal restoring
%   contributions at the characteristic wavelength. Click the surface to
%   create ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp,
%   gravityWavesExample, capillaryWavesExample

    simulator = app.RippleSimulatorApp(Setup="Balanced");
end
