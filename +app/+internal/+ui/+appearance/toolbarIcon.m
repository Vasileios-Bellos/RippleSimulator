function icon = toolbarIcon(name, themeName)
% TOOLBARICON Resolve an application-owned glyph for the axes toolbar.

    arguments
        name {mustBeTextScalar, mustBeMember(name, ...
            ["rain", "rain-disabled", "pause", "play", "clear", "wireframe", "reflections", ...
            "controls", "rotate", "home", "ripple", "fullscreen", "lighting-on", "lighting-off", ...
            "sound-on", "sound-off", "autoclick"])}
        themeName (1, 1) string {mustBeMember(themeName, ["light", "dark"])} = "light"
    end
    folder = fullfile(fileparts(mfilename("fullpath")), "icons", themeName + "Mode");
    icon = fullfile(folder, string(name) + ".png");
    assert(isfile(icon), "RippleSimulator:IconMissing", "The toolbar icon is missing: %s.", icon);
end
