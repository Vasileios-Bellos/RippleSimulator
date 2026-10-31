function simulator = capillaryWavesExample()
% capillaryWavesExample Explore capillary-scale ripples in water.
%   SIMULATOR = capillaryWavesExample() opens the Capillary wave setup at
%   its preset settings. Click the surface to create ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, gravityWavesExample,
%   gravityCapillaryWavesExample

    simulator = app.RippleSimulatorApp(Setup="Capillary");
end
