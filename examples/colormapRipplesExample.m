function simulator = colormapRipplesExample()
% colormapRipplesExample Explore ripples colored by surface elevation.
%   SIMULATOR = colormapRipplesExample() opens the Gravity wave setup in
%   the top view. Click the surface to create ripples. The HSV colormap is
%   used to visualize variations in the surface elevation.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, wireframeRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity");
    simulator.SurfaceMode = "Elevation";
    simulator.Colormap = "hsv";
    simulator.setCameraView("Top");
end
