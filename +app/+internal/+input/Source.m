classdef (Sealed) Source
    % SOURCE Immutable spatial scale and pressure strength of a click.
    %   An impulse applies J*exp(-r^2/(2*s^2)) in Pa s, with s=lambda/(2*pi).
    %   The wavemaker applies J*omega0 times the same spatial profile and a
    %   four-cycle sinusoid with a smooth envelope. Both modes use the same
    %   clean-interface gravity-capillary response. Auto-click and rain scale J
    %   by their pressure multipliers.

    properties (Constant)
        MaximumDomainRatio = 26
    end

    properties (SetAccess = immutable)
        Wavelength (1, 1) double
        PressureImpulse (1, 1) double
        Mode (1, 1) string
    end

    properties (Dependent, SetAccess = private)
        Wavenumber (1, 1) double
        Width (1, 1) double
    end

    methods
        function obj = Source(wavelength, pressureImpulse, mode)
        % SOURCE Construct a Gaussian excitation in meters and pascal seconds.
            arguments
                wavelength (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBePositive}
                pressureImpulse (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite, mustBeNonnegative}
                mode {mustBeTextScalar, mustBeMember(mode, ["Impulse", "Wavemaker"])} = "Impulse"
            end
            obj.Wavelength = double(wavelength);
            obj.PressureImpulse = double(pressureImpulse);
            obj.Mode = string(mode);
        end

        function value = get.Wavenumber(obj)
            value = 2*pi/obj.Wavelength;
        end

        function value = get.Width(obj)
            value = obj.Wavelength/(2*pi);
        end

        function record = describe(obj)
        % DESCRIBE Return the captured source definition and SI units.
            arguments
                obj (1, 1) app.internal.input.Source
            end
            record = struct(Mode=obj.Mode, WavelengthMeters=obj.Wavelength, ...
                GaussianWidthMeters=obj.Width, PressureImpulsePaS=obj.PressureImpulse);
        end
    end
end
