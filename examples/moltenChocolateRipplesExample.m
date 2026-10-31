function simulator = moltenChocolateRipplesExample()
% moltenChocolateRipplesExample Explore the molten chocolate approximation.
%   SIMULATOR = moltenChocolateRipplesExample() opens the molten compound
%   chocolate preset at 60 degrees Celsius. This Newtonian approximation
%   excludes yield stress, shear thinning, and crystallization. Click the
%   surface to create disturbances.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, honeyRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.Material = "Chocolate";
end
