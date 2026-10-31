function simulator = sideReflectionExample()
% sideReflectionExample Start a ripple near the right reflecting wall.
%   SIMULATOR = sideReflectionExample() opens a 0.3 m square water domain
%   with ideal reflecting walls in the top view. A source near the right
%   wall generates the ripple. Click the surface to create additional
%   ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp,
%   waveReflectionExample, cornerReflectionExample

    simulator = app.RippleSimulatorApp(Setup="Gravity", ReflectionsEnabled=true);
    simulator.DomainSize = 0.3;
    simulator.setCameraView("Top");
    simulator.addRipple([0.100125, 0]);
end
