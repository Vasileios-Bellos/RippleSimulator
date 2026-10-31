function simulator = waveInterferenceExample()
% waveInterferenceExample Start two simultaneous water ripples.
%   SIMULATOR = waveInterferenceExample() opens the Gravity wave setup
%   and simultaneously applies equal sources at different locations. Their
%   surface elevations are superimposed to form the wave field. Click the
%   surface to create additional ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, rainRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity", Paused=true);
    try
        simulator.addRipple([-0.063375, -0.013]);
        simulator.addRipple([0.063375, 0.013]);
        simulator.Paused = false;
    catch exception
        simulator.close();
        rethrow(exception);
    end
end
