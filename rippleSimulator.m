function simulator = rippleSimulator(options)
% RIPPLESIMULATOR Launch the interactive gravity-capillary ripple simulator.
%   rippleSimulator() opens the gravity-scale water experiment. Click the surface
%   to create ripples, or use the menus and axes toolbar to control rain,
%   playback, physical scale, source settings, and observation resolution.
%
%   APP = rippleSimulator() returns the application object for programmatic
%   control. Name-value arguments are forwarded to app.RippleSimulatorApp.
%
%   Example:
%       app = rippleSimulator(Setup="Gravity");
%       app.addRipple([0 0]);
%
%   See also app.RippleSimulatorApp.

    arguments (Repeating)
        options
    end
    simulator = app.RippleSimulatorApp(options{:});
    if nargout == 0
        clear simulator
    end
end
