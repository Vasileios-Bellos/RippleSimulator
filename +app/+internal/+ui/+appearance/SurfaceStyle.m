classdef (Sealed) SurfaceStyle
    % SURFACESTYLE Define surface color and lighting properties.

    properties (SetAccess = immutable)
        Name (1, 1) string
        Color (1, 3) double
        LightColor (1, 3) double
        LightPosition (1, 3) double
        Finish (1, 1) string
    end

    methods
        function obj = SurfaceStyle(name, color)
        % SURFACESTYLE Select a named color or an explicit RGB triplet.
            arguments
                name (1, 1) string {mustBeMember(name, ["Red", "Green", "Blue", "Cyan", "Magenta", ...
                    "Yellow", "Black", "White", "Dark brown", "Brown", "Ivory", "Amber", "Caramel", ...
                    "Sand", "Golden", "Custom"])} = "Blue"
                color = [0, 0, 1]
            end
            color = validatecolor(color);
            position = [4, 4, 200/22];
            finish = "shiny";
            lightColor = [];
            switch name
                case "Blue"
                    color = validatecolor("blue");
                    lightColor = [0, 1, 1];
                    position = [2, 1, 100/22];
                case {"Red", "Green", "Cyan", "Magenta", "Yellow", "White"}
                    color = validatecolor(lower(name));
                case "Black"
                    color = validatecolor("black");
                    lightColor = [1, 1, 1];
                case "Dark brown"
                    lightColor = [123, 63, 0]/255;
                    color = 0.8*lightColor;
                case "Brown"
                    color = [128, 83, 45]/255;
                case "Ivory"
                    color = [237, 230, 214]/255;
                case "Amber"
                    color = [255, 170, 48]/255;
                    position = [1, 1, 200/22];
                case "Caramel"
                    color = [255, 213, 154]/255;
                case "Golden"
                    color = [218, 186, 67]/255;
                    lightColor = [1, 1, 0.85];
                case "Sand"
                    color = [237, 230, 214]/255;
                    position = [-4, -4, 200/22];
                    finish = "dull";
                otherwise
                    lightColor = [1, 1, 1];
                    position = [2, 1, 100/22];
            end
            if isempty(lightColor)
                lightColor = color;
            end
            obj.Name = name;
            obj.Color = color;
            obj.LightColor = lightColor;
            obj.LightPosition = position;
            obj.Finish = finish;
        end
    end
end
