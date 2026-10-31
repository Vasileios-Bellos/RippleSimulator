function simulator = siliconeOil5cStRipplesExample()
% siliconeOil5cStRipplesExample Explore ripples in 5 cSt silicone oil.
%   SIMULATOR = siliconeOil5cStRipplesExample() opens the KF-96L-5cs
%   silicone oil preset at 25 degrees Celsius. Click the surface to create
%   ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, siliconeOil100cStRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.Material = "KF-96L-5cs";
end
