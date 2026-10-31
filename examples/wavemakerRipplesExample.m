function simulator = wavemakerRipplesExample()
% wavemakerRipplesExample Explore ripples created using a four-cycle localized wavemaker.
%   SIMULATOR = wavemakerRipplesExample() opens the Gravity wave setup
%   with the four-cycle wavemaker excitation method enabled. Click the
%   surface to create ripples. Each click drives an individual four-cycle
%   localized wavemaker.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp,
%   gravityWavesExample, inspectWaveField

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.SourceMode = "Wavemaker";
end
