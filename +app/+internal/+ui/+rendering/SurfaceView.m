classdef (Sealed) SurfaceView < handle
    % SURFACEVIEW Own the persistent surface and its figure layout.
    %   Horizontal coordinates are normalized by the declared physical domain.
    %   Vertical exaggeration is a fixed display transformation. Rendering
    %   never rescales a frame by its current amplitude.

    properties (SetAccess = private)
        Figure matlab.ui.Figure
        Axes matlab.graphics.axis.Axes
        Surface matlab.graphics.primitive.Surface
        Layout matlab.ui.container.GridLayout
        ControlPanel matlab.ui.container.Panel
        DescriptionPanel matlab.ui.container.Panel
        ReadoutPanel matlab.ui.container.Panel
        StatusLabel matlab.ui.control.Label
        ScaleLabel matlab.ui.control.Label
        MeasurementText matlab.graphics.primitive.Text
        FrameRateText matlab.graphics.primitive.Text
        DomainSize (1, 1) double = 1
        NavigationMode (1, 1) string = "Ripple"
        AutoclickEnabled (1, 1) logical = false
        BackgroundColorSelection = [1, 1, 1]
        Rain app.internal.ui.rendering.RainStreaks
    end

    properties (Access = private)
        WaterPanel matlab.ui.container.Panel
        ReadoutLayout matlab.ui.container.GridLayout
        FrameRatePanel matlab.ui.container.Panel
        MeasurementPanel matlab.ui.container.Panel
        MeasurementFields (1, 4) string = ["", "", "", ""]
        Command function_handle
        PressPosition (1, :) double = zeros(1, 0)
        LastPointer (1, :) double = zeros(1, 0)
        InputPaused (1, 1) logical = false
        MotionTracking (1, 1) logical = false
        ReferenceCamera (1, 1) struct
        CameraPreset (1, 1) string = "Close"
        Light matlab.graphics.primitive.Light
        ControlHeight (1, 1) double = 80
        SurfaceCoordinates (1, :) double = [-0.5, 0.5]
        Style app.internal.ui.appearance.SurfaceStyle = app.internal.ui.appearance.SurfaceStyle()
        SurfaceMode (1, 1) string = "Shaded"
        ElevationColors (:, 3) double = winter(256)
        Wireframe (1, 1) logical = false
        SurfaceOpacity (1, 1) double = 1
        AppliedThemeName (1, 1) string = ""
    end

    events (NotifyAccess = private)
        ThemeChanged
    end

    methods
        function obj = SurfaceView(command)
        % SURFACEVIEW Create a hidden figure with a single persistent surface.
            arguments
                command (1, 1) function_handle
            end
            obj.Command = command;
            try
                obj.Figure = uifigure(Name="Ripple Simulator", Visible="off", Color="white", ...
                    Position=[100, 100, 1200, 780], WindowState="maximized", ...
                    AutoResizeChildren="off", Tag="RippleSimulator");
                obj.Layout = uigridlayout(obj.Figure, [4, 1], ...
                    RowHeight={"1x", 27, 0, 53}, ColumnWidth={"1x"}, ...
                    Padding=[0, 0, 0, 0], RowSpacing=0, BackgroundColor="white");
                obj.WaterPanel = uipanel(obj.Layout, BorderType="none", BackgroundColor="white", ...
                    AutoResizeChildren="off");
                obj.WaterPanel.Layout.Row = 1;
                obj.ControlPanel = uipanel(obj.Layout, BorderType="none", Visible="off", BackgroundColor="white", ...
                    AutoResizeChildren="off");
                obj.ControlPanel.Layout.Row = 3;
                obj.DescriptionPanel = uipanel(obj.Layout, BorderType="none", BackgroundColor="white");
                obj.DescriptionPanel.Layout.Row = 2;
                description = uigridlayout(obj.DescriptionPanel, [1, 1], ...
                    Padding=[16, 4, 16, 0], BackgroundColor="white");
                obj.ReadoutPanel = uipanel(obj.Layout, BorderType="none", BackgroundColor="white");
                obj.ReadoutPanel.Layout.Row = 4;
                readout = uigridlayout(obj.ReadoutPanel, [2, 2], RowHeight={"1x", "1x"}, ...
                    ColumnWidth={"1x", 72}, Padding=[16, 4, 16, 4], RowSpacing=0, ...
                    ColumnSpacing=8, BackgroundColor="white");
                obj.ReadoutLayout = readout;
                obj.StatusLabel = uilabel(description, Text="Click the surface to generate a ripple. " ...
                    + "Gravity and surface tension restore the displaced surface. " ...
                    + "Viscosity dissipates the wave energy.", ...
                    FontSize=12, FontColor=[0.2, 0.2, 0.2], WordWrap="on", Tag="StatusReadout");
                obj.ScaleLabel = uilabel(readout, Text="", FontSize=11, ...
                    FontColor=[0.35, 0.35, 0.35], WordWrap="on", Tag="ScaleReadout");
                obj.ScaleLabel.Layout.Row = 2;
                obj.ScaleLabel.Layout.Column = 1;
                obj.createDynamicReadouts();
                obj.createSurface();
                obj.Rain = app.internal.ui.rendering.RainStreaks(obj.Axes);
                obj.WaterPanel.SizeChangedFcn = @(~, ~) obj.fitCamera();
                obj.Figure.WindowButtonUpFcn = @(~, ~) obj.releasePointer();
                obj.Figure.WindowScrollWheelFcn = @(~, event) obj.scrollCamera(event);
                obj.Figure.SizeChangedFcn = @(~, ~) obj.resizeReadout();
                obj.setBackgroundColor("Theme");
                obj.applyTheme();
                [~, supportsThemes] = app.internal.ui.appearance.themeColors(obj.Figure);
                if supportsThemes
                    obj.Figure.ThemeChangedFcn = @(~, ~) obj.applyTheme();
                end
            catch exception
                delete(obj);
                rethrow(exception);
            end
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isgraphics(obj.Figure) && obj.Figure.BeingDeleted == "off"
                delete(obj.Figure);
            end
        end

        function render(obj, waveField, verticalScale)
        % RENDER Render the wave field using the existing surface graphics.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                waveField (1, 1) struct
                verticalScale (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
            end
            coordinates = waveField.Coordinates/waveField.DomainSize;
            elevation = double(verticalScale)*waveField.Elevation/waveField.DomainSize;
            assert(isequal(size(elevation), [numel(coordinates), numel(coordinates)]) && ...
                all(isfinite(elevation), "all"), "RippleSimulator:InvalidFrame", ...
                "The wave field must contain a finite square elevation array.");
            if isequal(coordinates, obj.SurfaceCoordinates)
                obj.Surface.ZData = elevation;
            else
                set(obj.Surface, XData=coordinates, YData=coordinates, ZData=elevation);
                obj.SurfaceCoordinates = coordinates;
            end
            obj.DomainSize = waveField.DomainSize;
            if ~obj.Wireframe && ismember(obj.SurfaceMode, ["Elevation", "Contrast"])
                obj.Surface.CData = elevation;
            end
        end

        function setWireframe(obj, enabled)
        % SETWIREFRAME Change surface styling without changing its physical data.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                enabled (1, 1) {mustBeNumericOrLogical, mustBeMember(enabled, [0, 1])}
            end
            obj.Wireframe = logical(enabled);
            obj.applySurfaceMode();
        end

        function setSurfaceMode(obj, mode)
        % SETSURFACEMODE Apply a shaded or elevation-based presentation.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                mode {mustBeTextScalar, mustBeMember(mode, ...
                    ["Shaded", "Elevation", "Contrast"])}
            end
            obj.SurfaceMode = string(mode);
            obj.Wireframe = false;
            obj.applySurfaceMode();
        end

        function setColormap(obj, colors)
        % SETCOLORMAP Retain elevation colors without changing the physical field.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                colors (:, 3) double {mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(colors, 0), mustBeLessThanOrEqual(colors, 1)}
            end
            obj.ElevationColors = colors;
            if obj.SurfaceMode == "Elevation"
                colormap(obj.Axes, colors);
            end
        end

        function setStyle(obj, style, wireframe)
        % SETSTYLE Apply a display appearance while retaining the wave field.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                style (1, 1) app.internal.ui.appearance.SurfaceStyle
                wireframe (1, 1) logical
            end
            obj.Style = style;
            obj.Light.Color = style.LightColor;
            obj.Light.Position = style.LightPosition;
            material(obj.Axes, style.Finish);
            obj.setWireframe(wireframe);
        end

        function setLighting(obj, enabled)
        % SETLIGHTING Enable or disable the original surface light.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                enabled (1, 1) {mustBeNumericOrLogical, mustBeMember(enabled, [0, 1])}
            end
            obj.Light.Visible = logical(enabled);
            obj.applySurfaceMode();
        end

        function setOpacity(obj, opacity)
        % SETOPACITY Set filled-surface opacity without changing the physical field.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                opacity (1, 1) double {mustBeReal, mustBeFinite, ...
                    mustBeGreaterThanOrEqual(opacity, 0.1), mustBeLessThanOrEqual(opacity, 1)}
            end
            obj.SurfaceOpacity = opacity;
            obj.applyOpacity();
        end

        function showControls(obj, enabled)
        % SHOWCONTROLS Show or hide the existing parameter controls.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                enabled (1, 1) {mustBeNumericOrLogical, mustBeMember(enabled, [0, 1])}
            end
            heights = obj.Layout.RowHeight;
            heights{3} = obj.ControlHeight*double(enabled);
            obj.Layout.RowHeight = heights;
            obj.ControlPanel.Visible = logical(enabled);
        end

        function showReadout(obj, enabled)
        % SHOWREADOUT Show or hide the explanation and measurement panels.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                enabled (1, 1) {mustBeNumericOrLogical, mustBeMember(enabled, [0, 1])}
            end
            heights = obj.Layout.RowHeight;
            totalHeight = obj.readoutHeight();
            descriptionHeight = ceil(totalHeight/3);
            heights{2} = descriptionHeight*double(enabled);
            heights{4} = (totalHeight - descriptionHeight)*double(enabled);
            obj.Layout.RowHeight = heights;
            obj.DescriptionPanel.Visible = logical(enabled);
            obj.ReadoutPanel.Visible = logical(enabled);
        end

        function setControlHeight(obj, height)
        % SETCONTROLHEIGHT Fit parameter controls to their responsive layout.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                height (1, 1) double {mustBeFinite, mustBePositive}
            end
            obj.ControlHeight = height;
            obj.showControls(obj.ControlPanel.Visible == "on");
        end

        function showFrameRate(obj, enabled)
        % SHOWFRAMERATE Reserve space for the retained FPS text when enabled.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                enabled (1, 1) logical
            end
            obj.FrameRatePanel.Visible = enabled;
            obj.ReadoutLayout.ColumnWidth = {"1x", 72*double(enabled)};
        end

        function showMeasurements(obj, fields)
        % SHOWMEASUREMENTS Update retained measurement text within the available width.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                fields (1, 4) string
            end
            obj.MeasurementFields = fields;
            obj.fitMeasurementText();
        end

        function setAutoclick(obj, enabled)
        % SETAUTOCLICK Enable pointer-driven source input in ripple mode.
            obj.AutoclickEnabled = enabled;
            obj.updateMotionCallback();
        end

        function setInputPaused(obj, paused)
        % SETINPUTPAUSED Suspend automatic pointer input during a pause.
            obj.InputPaused = paused;
            obj.updateMotionCallback();
        end

        function setNavigation(obj, mode)
        % SETNAVIGATION Make camera gestures distinct from source input.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                mode {mustBeTextScalar, mustBeMember(mode, ["Ripple", "Rotate", "Pan", "Zoom"])}
            end
            obj.Axes.Interactions = [];
            disableDefaultInteractivity(obj.Axes);
            obj.NavigationMode = string(mode);
            obj.PressPosition = zeros(1, 0);
            obj.LastPointer = zeros(1, 0);
            obj.updateMotionCallback();
        end

        function restoreCamera(obj)
        % RESTORECAMERA Restore the original oblique surface view.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
            end
            camera = obj.ReferenceCamera;
            obj.CameraPreset = "Close";
            set(obj.Axes, CameraPosition=camera.Position, CameraTarget=camera.Target, ...
                CameraUpVector=camera.UpVector, CameraViewAngle=camera.ViewAngle, ...
                Position=[-0.04, -0.04, 1.07, 1.07], ...
                XLim=[-0.5, 0.5], YLim=[-0.5, 0.5], ZLim=camera.ZLimits);
            obj.fitCamera();
            obj.updateRainVisibility();
        end

        function setCameraView(obj, name)
        % SETCAMERAVIEW Select a close oblique, overhead, or wide oblique view.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                name {mustBeTextScalar, mustBeMember(name, ["Close", "Top", "Wide"])}
            end
            obj.restoreCamera();
            switch string(name)
                case "Top"
                    obj.CameraPreset = "Top";
                    distance = norm(obj.ReferenceCamera.Position - obj.ReferenceCamera.Target);
                    set(obj.Axes, CameraPosition=[0, 0, distance], CameraTarget=[0, 0, 0], ...
                        CameraUpVector=[0, 1, 0], Position=[0, 0, 1, 1]);
                    obj.fitCamera();
                case "Wide"
                    obj.CameraPreset = "Wide";
                    camva(obj.Axes, 5);
                otherwise
                    % The close view is the restored reference camera.
            end
            obj.updateRainVisibility();
        end

        function value = describeCamera(obj)
        % DESCRIBECAMERA Return the camera in domain-normalized display coordinates.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
            end
            value = struct(Position=obj.Axes.CameraPosition, Target=obj.Axes.CameraTarget, ...
                UpVector=obj.Axes.CameraUpVector, ViewAngleDegrees=obj.Axes.CameraViewAngle, ...
                Projection=string(obj.Axes.Projection), Coordinates="Domain-normalized display coordinates");
        end

        function setBackgroundColor(obj, value)
        % SETBACKGROUNDCOLOR Select a fixed color or the figure theme's background.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
                value
            end
            useTheme = (ischar(value) || isstring(value)) ...
                && isscalar(string(value)) && strcmpi(value, "Theme");
            if useTheme
                [colors, supported] = app.internal.ui.appearance.themeColors(obj.Figure);
                color = colors.Background;
                selection = color;
                if supported
                    selection = "Theme";
                end
            else
                color = validatecolor(value);
                selection = color;
            end
            obj.Axes.Color = color;
            obj.WaterPanel.BackgroundColor = color;
            obj.BackgroundColorSelection = selection;
        end

        function applyTheme(obj)
        % APPLYTHEME Synchronize custom interface colors with the figure theme.
            arguments
                obj (1, 1) app.internal.ui.rendering.SurfaceView
            end
            colors = app.internal.ui.appearance.themeColors(obj.Figure);
            if obj.AppliedThemeName == colors.Name
                return
            end
            obj.Figure.Color = colors.Background;
            if isequal(obj.BackgroundColorSelection, "Theme")
                obj.setBackgroundColor("Theme");
            end
            panels = [obj.ControlPanel, obj.DescriptionPanel, ...
                obj.ReadoutPanel, obj.MeasurementPanel, obj.FrameRatePanel];
            set(panels, BackgroundColor=colors.Background);
            layouts = [obj.Layout, obj.StatusLabel.Parent, obj.ReadoutLayout];
            set(layouts, BackgroundColor=colors.Background);
            obj.StatusLabel.FontColor = colors.Foreground;
            obj.ScaleLabel.FontColor = colors.Secondary;
            obj.MeasurementText.Color = colors.Measurement;
            obj.FrameRateText.Color = colors.Secondary;
            notify(obj, "ThemeChanged");
            obj.AppliedThemeName = colors.Name;
        end
    end

    methods (Access = private)
        function updateRainVisibility(obj)
            direction = obj.Axes.CameraPosition - obj.Axes.CameraTarget;
            obj.Rain.setVisible(norm(direction(1:2)) > 64*eps(norm(direction)));
        end

        function createDynamicReadouts(obj)
            obj.MeasurementPanel = uipanel(obj.ReadoutLayout, BorderType="none", ...
                BackgroundColor="white", AutoResizeChildren="off");
            obj.MeasurementPanel.Layout.Row = 1;
            obj.MeasurementPanel.Layout.Column = [1, 2];
            obj.MeasurementText = obj.createReadoutText(obj.MeasurementPanel, ...
                [0.25, 0.25, 0.25], "MeasurementReadout");
            obj.MeasurementPanel.SizeChangedFcn = @(~, ~) obj.fitMeasurementText();
            obj.FrameRatePanel = uipanel(obj.ReadoutLayout, BorderType="none", ...
                BackgroundColor="white", AutoResizeChildren="off");
            obj.FrameRatePanel.Layout.Row = 2;
            obj.FrameRatePanel.Layout.Column = 2;
            obj.FrameRateText = obj.createReadoutText(obj.FrameRatePanel, ...
                [0.35, 0.35, 0.35], "FrameRateReadout");
            obj.FrameRateText.HorizontalAlignment = "right";
            obj.FrameRateText.Position = [1, 0.5, 0];
            obj.FrameRateText.String = "FPS: 0";
        end

        function textHandle = createReadoutText(obj, parent, color, tag)
            axesHandle = axes(parent, Units="normalized", Position=[0, 0, 1, 1], ...
                Visible="off", XLim=[0, 1], YLim=[0, 1], XLimMode="manual", ...
                YLimMode="manual", Interactions=[], HitTest="off", PickableParts="none");
            axesHandle.Toolbar = [];
            disableDefaultInteractivity(axesHandle);
            textHandle = text(axesHandle, 0, 0.5, "", ...
                FontName=obj.ScaleLabel.FontName, FontUnits="pixels", FontSize=11, ...
                Color=color, Interpreter="none", VerticalAlignment="middle", ...
                HitTest="off", PickableParts="none", Tag=tag);
        end

        function fitMeasurementText(obj)
            if obj.MeasurementPanel.Position(3) < 600
                value = join(obj.MeasurementFields(1:2), "  |  ") + newline ...
                    + join(obj.MeasurementFields(3:4), "  |  ");
            else
                value = join(obj.MeasurementFields, "  |  ");
            end
            lines = splitlines(value);
            if ~isequal(string(obj.MeasurementText.String), lines)
                obj.MeasurementText.String = lines;
            end
        end

        function applySurfaceMode(obj)
            obj.Light.Color = obj.Style.LightColor;
            obj.applyOpacity();
            if obj.Wireframe
                if obj.Light.Visible == "on"
                    set(obj.Surface, FaceColor=[1, 1, 1], PickableParts="visible");
                else
                    set(obj.Surface, FaceColor="none", PickableParts="all");
                end
                set(obj.Surface, EdgeColor=[0, 0, 0], EdgeLighting="none", LineWidth=0.5);
                obj.Light.Color = [1, 1, 1];
                return
            end
            obj.Surface.PickableParts = "visible";
            switch obj.SurfaceMode
                case "Shaded"
                    if obj.Light.Visible == "on"
                        set(obj.Surface, FaceColor=obj.Style.Color, EdgeColor="none");
                    else
                        edgeColor = obj.Style.Color;
                        if all(edgeColor == 1)
                            edgeColor = [0, 0, 0];
                        end
                        set(obj.Surface, FaceColor="none", EdgeColor=edgeColor, ...
                            EdgeLighting="none", LineWidth=0.5, PickableParts="all");
                    end
                case {"Elevation", "Contrast"}
                    set(obj.Surface, FaceColor="interp", EdgeColor="none", CData=obj.Surface.ZData);
                    if obj.SurfaceMode == "Elevation"
                        colormap(obj.Axes, obj.ElevationColors);
                        obj.Axes.CLim = [-1, 1]/22;
                    else
                        colormap(obj.Axes, [zeros(20, 3); ones(236, 3)]);
                        obj.Axes.CLim = [0, 1]/22;
                    end
                otherwise
                    error("RippleSimulator:SurfaceMode", "The surface view is not recognized.");
            end
        end

        function applyOpacity(obj)
            opacity = 1;
            if ~obj.Wireframe && obj.Light.Visible == "on"
                opacity = obj.SurfaceOpacity;
            end
            obj.Surface.FaceAlpha = opacity;
        end

        function fitCamera(obj)
            if ~ismember(obj.CameraPreset, ["Close", "Top"]) || ~isgraphics(obj.Axes)
                return
            end
            bounds = getpixelposition(obj.WaterPanel);
            viewport = getpixelposition(obj.Axes);
            if any(bounds(3:4) <= 0) || viewport(4) <= 0
                return
            end
            center = viewport(1:2) - 1 + viewport(3:4)/2;
            if obj.CameraPreset == "Top"
                available = min(center, bounds(3:4)-center);
                if any(available <= 0)
                    return
                end
                % Fit the complete domain to the available panel width or height.
                span = [diff(obj.Axes.XLim), diff(obj.Axes.YLim)];
                halfHeight = max(span.*viewport(4)./(4*available));
                distance = norm(obj.Axes.CameraPosition-obj.Axes.CameraTarget);
                obj.Axes.CameraViewAngle = 2*atand(halfHeight/distance);
                return
            end
            camera = obj.ReferenceCamera;
            direction = camera.Target - camera.Position;
            distance = norm(direction);
            direction = direction/distance;
            right = cross(direction, camera.UpVector);
            right = right/norm(right);
            up = cross(right, direction);
            corners = [0, 0; bounds(3), 0; bounds(3), bounds(4); 0, bounds(4)];
            screen = 2*(corners - center)/viewport(4);
            offsets = screen(:, 1)*right + screen(:, 2)*up;
            intersections = offsets - offsets(:, 3)/direction(3)*direction;
            % Keep the viewport inside the physical square at equilibrium.
            halfHeight = 0.45/max(abs(intersections(:, 1:2)), [], "all");
            angle = 2*atand(halfHeight/distance);
            obj.Axes.CameraViewAngle = min(camera.ViewAngle, angle);
        end

        function height = readoutHeight(obj)
            width = obj.Figure.Position(3);
            height = 80 + 30*(width < 1200) + 30*(width < 900) + 30*(width < 600);
        end

        function resizeReadout(obj)
            if isgraphics(obj.ReadoutPanel)
                obj.showReadout(obj.ReadoutPanel.Visible == "on");
            end
        end

        function createSurface(obj)
            amplitude = 1/22;
            obj.Axes = axes(obj.WaterPanel, Units="normalized", Position=[-0.04, -0.04, 1.07, 1.07], ...
                ClippingStyle="rectangle", Color="white", ...
                Interactions=[], Tag="SurfaceAxes");
            disableDefaultInteractivity(obj.Axes);
            obj.Surface = surface(obj.Axes, [-0.5, 0.5], [-0.5, 0.5], zeros(2), ...
                EdgeColor="none", FaceColor="blue", FaceAlpha=1, FaceLighting="gouraud", ...
                HitTest="on", PickableParts="visible", Tag="FluidSurface");
            obj.Light = light(obj.Axes, Style="local", Position=[2, 1, 100*amplitude], Color="cyan");
            material(obj.Axes, "shiny");
            xlim(obj.Axes, [-0.5, 0.5]);
            ylim(obj.Axes, [-0.5, 0.5]);
            zlim(obj.Axes, [-2, 20]*amplitude);
            daspect(obj.Axes, [1, 1, 1]);
            pbaspect(obj.Axes, [1, 1, 1]);
            view(obj.Axes, 3);
            camva(obj.Axes, 2);
            camtarget(obj.Axes, [0, 0, 0]);
            obj.Axes.Tag = "SurfaceAxes";
            obj.Axes.Visible = "off";
            obj.Surface.ButtonDownFcn = @(~, event) obj.pressPointer(event);
            obj.ReferenceCamera = struct(Position=obj.Axes.CameraPosition, Target=obj.Axes.CameraTarget, ...
                UpVector=obj.Axes.CameraUpVector, ViewAngle=obj.Axes.CameraViewAngle, ZLimits=obj.Axes.ZLim);
        end

        function pressPointer(obj, event)
            if ~ismember(string(obj.Figure.SelectionType), ["normal", "open"])
                return
            end
            if obj.NavigationMode ~= "Ripple"
                obj.PressPosition = obj.Figure.CurrentPoint;
                obj.LastPointer = obj.PressPosition;
                obj.updateMotionCallback();
                return
            end
            if obj.InputPaused
                return
            end
            position = zeros(1, 0);
            if isprop(event, "IntersectionPoint")
                intersection = event.IntersectionPoint;
                if all(isfinite(intersection)) && all(abs(intersection(1:2)) <= 0.5 + 64*eps)
                    position = max(-0.5, min(0.5, intersection(1:2)))*obj.DomainSize;
                end
            else
                position = app.internal.ui.rendering.intersectSurface(obj.Axes.CurrentPoint, obj.DomainSize);
            end
            if ~isempty(position)
                if obj.AutoclickEnabled
                    obj.Command("autoclickInput", position);
                else
                    obj.Command("click", position);
                end
            end
        end

        function updateMotionCallback(obj)
            enabled = ~isempty(obj.PressPosition) ...
                || (obj.AutoclickEnabled && ~obj.InputPaused && obj.NavigationMode == "Ripple");
            if enabled == obj.MotionTracking
                return
            end
            if enabled
                obj.Figure.WindowButtonMotionFcn = @(~, event) obj.movePointer(event);
            else
                obj.Figure.WindowButtonMotionFcn = [];
            end
            obj.MotionTracking = enabled;
        end

        function movePointer(obj, event)
            if obj.AutoclickEnabled && ~obj.InputPaused && obj.NavigationMode == "Ripple"
                if (isobject(event) && isprop(event, "HitObject") && isprop(event, "IntersectionPoint")) ...
                        || (isstruct(event) && isfield(event, "HitObject") && isfield(event, "IntersectionPoint"))
                    if isequal(event.HitObject, obj.Surface)
                        position = event.IntersectionPoint;
                        if numel(position) == 3 && all(isfinite(position)) ...
                                && all(abs(position(1:2)) <= 0.5)
                            obj.Command("autoclickInput", position(1:2)*obj.DomainSize);
                        end
                    end
                end
            end
            if isempty(obj.PressPosition)
                return
            end
            point = obj.Figure.CurrentPoint;
            delta = point - obj.LastPointer;
            obj.LastPointer = point;
            switch obj.NavigationMode
                case "Rotate"
                    obj.CameraPreset = "";
                    camorbit(obj.Axes, -0.25*delta(1), -0.25*delta(2), "camera");
                    obj.updateRainVisibility();
                case "Pan"
                    obj.panCamera(delta);
                case "Zoom"
                    obj.changeCameraScale(1.01^delta(2));
            end
        end

        function releasePointer(obj)
            if isempty(obj.PressPosition)
                return
            end
            obj.PressPosition = zeros(1, 0);
            obj.LastPointer = zeros(1, 0);
            obj.updateMotionCallback();
        end

        function scrollCamera(obj, event)
            point = obj.Figure.CurrentPoint;
            bounds = getpixelposition(obj.WaterPanel, true);
            if any(point < bounds(1:2)) || any(point > bounds(1:2) + bounds(3:4))
                return
            end
            obj.changeCameraScale(1.1^double(event.VerticalScrollCount));
        end

        function changeCameraScale(obj, factor)
            obj.CameraPreset = "";
            angle = obj.Axes.CameraViewAngle*factor;
            obj.Axes.CameraViewAngle = min(45, max(0.4, angle));
        end

        function panCamera(obj, delta)
            obj.CameraPreset = "";
            direction = obj.Axes.CameraTarget - obj.Axes.CameraPosition;
            distance = norm(direction);
            direction = direction/distance;
            right = cross(direction, obj.Axes.CameraUpVector);
            right = right/norm(right);
            up = cross(right, direction);
            viewport = getpixelposition(obj.Axes);
            scale = 2*distance*tand(obj.Axes.CameraViewAngle/2)/viewport(4);
            shift = -scale*(delta(1)*right + delta(2)*up);
            obj.Axes.CameraPosition = obj.Axes.CameraPosition + shift;
            obj.Axes.CameraTarget = obj.Axes.CameraTarget + shift;
        end
    end
end
