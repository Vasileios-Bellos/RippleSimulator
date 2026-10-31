function value = parseColormapInput(text)
% PARSECOLORMAPINPUT Read a function name or a literal matrix of RGB triplets.
    arguments
        text {mustBeTextScalar}
    end
    text = strtrim(string(text));
    parts = split(text, ".");
    if all(arrayfun(@(part) isvarname(part), parts))
        value = text;
        return
    end

    message = "Enter a colormap function name or an N-by-3 RGB matrix with values from 0 to 1.";
    hasOpening = startsWith(text, "[");
    hasClosing = endsWith(text, "]");
    assert(hasOpening == hasClosing, "RippleSimulator:ColormapInput", message);
    if hasOpening
        assert(strlength(text) > 2, "RippleSimulator:ColormapInput", message);
        text = strtrim(extractBetween(text, 2, strlength(text)-1));
    end
    assert(isscalar(text) && strlength(text) > 0, "RippleSimulator:ColormapInput", message);
    rows = regexp(char(text), '[;\r\n]+', 'split');
    number = '([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)';
    separator = '(?:[ \t]+|[ \t]*,[ \t]*)';
    pattern = ['^\s*', number, separator, number, separator, number, '\s*$'];
    value = zeros(numel(rows), 3);
    for index = 1:numel(rows)
        tokens = regexp(rows{index}, pattern, 'tokens', 'once');
        assert(numel(tokens) == 3, "RippleSimulator:ColormapInput", message);
        value(index, :) = str2double(tokens);
    end
    assert(all(isfinite(value) & value >= 0 & value <= 1, "all"), ...
        "RippleSimulator:ColormapInput", message);
end
