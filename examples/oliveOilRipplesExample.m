function simulator = oliveOilRipplesExample()
% oliveOilRipplesExample Explore ripples in the olive oil preset.
%   SIMULATOR = oliveOilRipplesExample() opens the extra virgin olive-oil
%   preset at a nominal temperature of 23 degrees Celsius. Click the
%   surface to create ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, honeyRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.Material = "Olive oil";
end
