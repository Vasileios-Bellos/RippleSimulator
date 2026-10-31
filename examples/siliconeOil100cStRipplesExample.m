function simulator = siliconeOil100cStRipplesExample()
% siliconeOil100cStRipplesExample Explore ripples in 100 cSt silicone oil.
%   SIMULATOR = siliconeOil100cStRipplesExample() opens the KF-96-100cs
%   silicone oil preset at 25 degrees Celsius. Click the surface to create
%   ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, siliconeOil5cStRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.Material = "KF-96-100cs";
end
