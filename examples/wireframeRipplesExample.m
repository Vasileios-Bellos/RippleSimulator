function simulator = wireframeRipplesExample()
% wireframeRipplesExample Explore water ripples with wireframe.
%   SIMULATOR = wireframeRipplesExample() opens the Gravity wave setup
%   with a still surface and sets the display to wireframe. Click the
%   surface to create ripples. Adjust the grid's discretization to control
%   the spatial resolution.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp, colormapRipplesExample

    simulator = app.RippleSimulatorApp(Setup="Gravity", GridResolution=201);
    simulator.Wireframe = true;
end
