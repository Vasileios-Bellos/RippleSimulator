function pixels = captureFigure(figureHandle, options)
% CAPTUREFIGURE Capture a UI figure and its controls as an RGB image.
%   Method="auto" uses getframe from R2025a onward and exportapp on earlier
%   releases. Method="frame" or Method="export" selects the capture method.

    arguments
        figureHandle (1, 1) matlab.ui.Figure
        options.Method (1, 1) string {mustBeMember(options.Method, ["auto", "frame", "export"])} = "auto"
    end
    useFrame = options.Method == "frame" ...
        || (options.Method == "auto" && ~isMATLABReleaseOlderThan("R2025a"));
    if useFrame
        frame = getframe(figureHandle);
        pixels = frame.cdata;
    else
        filename = string(tempname()) + ".png";
        guard = onCleanup(@() removeCapture(filename));
        exportapp(figureHandle, filename);
        pixels = imread(filename);
    end
end

function removeCapture(filename)
    if isfile(filename)
        delete(filename);
    end
end
