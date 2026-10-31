function simulator = waveReflectionExample()
% waveReflectionExample Explore ripples in an ideal reflecting tank.
%   SIMULATOR = waveReflectionExample() opens a 0.3 m square water domain
%   with ideal reflecting walls in the top view. Click near a wall or
%   corner to observe reflected waves and their superposition.
%
%   Close the window or call SIMULATOR.close() when finished.
%
%   See also rippleSimulator, app.RippleSimulatorApp,
%   sideReflectionExample, cornerReflectionExample

    simulator = app.RippleSimulatorApp(Setup="Gravity", ReflectionsEnabled=true);
    simulator.DomainSize = 0.3;
    simulator.setCameraView("Top");
end
