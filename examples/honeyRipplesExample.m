function simulator = honeyRipplesExample()
% honeyRipplesExample Explore the acacia-honey approximation.
%   SIMULATOR = honeyRipplesExample() opens the acacia honey preset at 30
%   degrees Celsius. This Newtonian approximation excludes crystallization
%   and non-Newtonian effects. Click the surface to create disturbances.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, moltenChocolateRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.Material = "Honey";
end
