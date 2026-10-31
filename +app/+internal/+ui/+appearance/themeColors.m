function [colors, supported] = themeColors(figureHandle)
% THEMECOLORS Resolve application colors with a light-theme compatibility fallback.
%   SUPPORTED is true when the figure exposes a usable theme and its controls.
    colors = struct(Name="light", Background=[1, 1, 1], Foreground=[0.2, 0.2, 0.2], ...
        Secondary=[0.35, 0.35, 0.35], Measurement=[0.25, 0.25, 0.25]);
    supported = ~isMATLABReleaseOlderThan("R2025a") ...
        && isscalar(figureHandle) && isprop(figureHandle, "Theme") ...
        && isprop(figureHandle, "ThemeMode") && isprop(figureHandle, "ThemeChangedFcn");
    if ~supported
        return
    end
    theme = figureHandle.Theme;
    supported = isscalar(theme) && isprop(theme, "BaseColorStyle");
    if ~supported
        return
    end
    style = string(theme.BaseColorStyle);
    supported = isscalar(style) && ismember(style, ["light", "dark"]);
    if supported && style == "dark"
        colors.Name = "dark";
        colors.Background = [33, 33, 33]/255;
        colors.Foreground = [217, 217, 217]/255;
        colors.Secondary = [190, 190, 190]/255;
        colors.Measurement = colors.Foreground;
    end
end
