function simulator = rainRipplesExample()
% rainRipplesExample Start a reproducible burst of rain-driven ripples.
%   SIMULATOR = rainRipplesExample() opens the Gravity wave setup and
%   schedules twenty localized sources with the default rain seed.
%   Click the surface or use Rain to generate additional ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, waveInterferenceExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.rain();
end
