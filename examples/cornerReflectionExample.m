function simulator = cornerReflectionExample()
% cornerReflectionExample Start a ripple near the top-right corner.
%   SIMULATOR = cornerReflectionExample() opens a 0.3 m square water domain
%   with ideal reflecting walls in the top view. A source near the top
%   right corner generates the ripple. Click the surface to create
%   additional ripples.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp,
%   waveReflectionExample, sideReflectionExample

    simulator = app.RippleSimulatorApp(Setup="Gravity", ReflectionsEnabled=true);
    simulator.DomainSize = 0.3;
    simulator.setCameraView("Top");
    simulator.addRipple([0.100125, 0.100125]);
end
