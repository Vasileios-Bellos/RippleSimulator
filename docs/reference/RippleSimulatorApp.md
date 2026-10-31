# app.RippleSimulatorApp

Create a Ripple Simulator application object

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
simulator = app.RippleSimulatorApp()
simulator = app.RippleSimulatorApp(Name=Value)
```

```text
simulator.Property = value
```

## Description

`app.RippleSimulatorApp()` constructs the application object and creates its
interface. The object owns its figure, controls, elapsed-time clock, and wave
model. Public properties control the experiment
and its presentation; menu commands use the same property setters. An accepted
change updates the affected components before notifying observers.

---

The model represents linear waves on an infinitely deep, homogeneous Newtonian
fluid with a clean free surface. The unmodified response includes gravity,
surface tension, dispersion, and viscosity. A finite-duration envelope
returns each source to exact stillness. See [Physics](../guide/physics.md) for the
governing equations and the assumptions required for quantitative interpretation.

The class has handle semantics and cannot be subclassed. Its `app.internal`
components are implementation details, not supported public interfaces.

## Examples

### Change presentation without changing the physical field

Freeze the experiment at its initial time, add an impulse, and compare a
physical snapshot before and after changing the rendering.

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
simulator.addRipple([0, 0]);
before = simulator.snapshot(Derivatives=true);
simulator.Wireframe = true;
simulator.HeightScale = 1000;
after = simulator.snapshot(Derivatives=true);
isequal(before, after)
```

```text
ans =
  logical
   1
```

The impulse initially has zero elevation and nonzero vertical velocity. The
unchanged snapshot verifies that display settings do not alter either field.

```matlab
simulator.close();
```

## Name-Value Arguments

| Argument | Description |
| --- | --- |
| `Setup` | `"Gravity"` (default), `"Balanced"`, or `"Capillary"`; select a scaled water experiment. |
| `GridResolution` | Integer from 51 to 801; default 201. Must also satisfy spatial sampling requirements. |
| `Visible` | `"on"` or `"off"`; default `"on"`. |
| `AutomaticUpdates` | Logical scalar; default `true`. Set `false` to call `update` explicitly. |
| `Paused` | Logical scalar; default `false`. Set `true` to start paused at physical time zero. Setting the `Paused` property to `false` resumes time; automatic updates start only if `AutomaticUpdates=true`. |
| `TimeSource` | Optional function handle returning a finite, monotonic scalar time in seconds. The default uses MATLAB's elapsed timer. |
| `ReflectionsEnabled` | Logical scalar; default `false`. Set `true` to start with reflecting boundaries. |
| `ReflectionCoefficient` | Real scalar from 0 to 1; default 1. Reflected amplitude fraction when wave reflections are enabled. |

## Properties


Use these properties to configure the experiment and its presentation.

| Property | Type and units | Effect |
| --- | --- | --- |
| `Wavelength` | Real scalar, 0.005–0.1 m | Characteristic scale of new sources. Existing waves retain their scale. |
| `PressureImpulse` | Nonnegative scalar, Pa s | Pressure strength for new sources, subject to the small-disturbance limit. |
| `SourceMode` | `"Impulse"` or `"Wavemaker"` | Excitation method for new sources. |
| `DomainSize` | Real scalar, 0.005–2.4 m | Domain width; starts a new experiment. Domain and source must satisfy supported extent and sampling limits. |
| `Material` | `"Water"`, `"Olive oil"`, `"KF-96L-5cs"`, `"KF-96-100cs"`, `"Honey"`, `"Chocolate"`, or `"Custom"` | Starts a new experiment with the specified fluid. Honey and molten chocolate use the documented constant-viscosity approximations. Define custom data through `FluidProperties`. |
| `FluidProperties` | Scalar structure | Complete custom record with `Density` (kg/m³), `DynamicViscosity` (Pa s), `SurfaceTension` (N/m), and `Temperature` (°C). |
| `Temperature` | Real scalar, °C | Water accepts 0–40 °C. Other presets retain their specified temperature; custom temperature belongs to the complete property record. |
| `GridResolution` | Integer, 51–801 | Resamples existing waves without changing their time or physical state. |
| `PlaybackRate` | Real scalar, 0.1–2 | Multiplies elapsed real time to determine simulation time; prior elapsed time is unchanged. Gravity and Balanced start at 0.25; Capillary starts at 0.10. |
| `Paused` | Logical scalar | Suspends waves and scheduled input. |
| `RandomSeed` | Integer, 0–4294967295 | Resets the private generator for subsequent rain bursts. |
| `RainStrengthScale` | Nonnegative finite scalar; default `1` | Multiplies pressure strength for newly scheduled rain bursts. |
| `AutoclickStrengthScale` | Nonnegative finite scalar; default `0.2` | Multiplies pressure strength for new Auto-click inputs. Existing waves and the Rain multiplier are unchanged. |
| `Wireframe` | Logical scalar | Displays black mesh edges. Enabling Wireframe turns lighting on, showing lit white faces. Turn lighting off for transparent faces. Disabling Wireframe restores the previous surface mode and its default lighting: on for `"Shaded"` and `"Contrast"`, off for `"Elevation"`. |
| `SurfaceMode` | `"Shaded"`, `"Elevation"`, or `"Contrast"` | Selects solid shading, elevation colors, or high contrast without changing the waves. |
| `Colormap` | Colormap function name, N-by-3 RGB array, or literal RGB matrix text; default `"winter"` | Sets the elevation colors. RGB values must be finite and between 0 and 1. A single RGB triplet defines a constant-color map. |
| `ColormapReversed` | Logical scalar; default `false` | Reverses the selected elevation colormap. |
| `FullScreen` | Logical scalar; default `false` | Shows only the surface, hiding menus, toolbar, and bottom panels. F11 or Escape restores their previous settings. |
| `Appearance` | Named color preset | Selects surface color and lighting independently of the physical material. |
| `SurfaceColor` | MATLAB color name, short name, hexadecimal code, or RGB row in [0, 1] | Selects a custom surface color; reading the property returns its RGB triplet. |
| `BackgroundColor` | MATLAB color name, short name, hexadecimal code, RGB row in [0, 1], or `"Theme"` | Sets the viewing-area background; returns its RGB triplet. Fixed colors persist across theme changes. The default and reset setting is `"Theme"`, which follows the figure theme, with a white fallback on releases without themes. |
| `SurfaceOpacity` | Scalar in [0.1, 1] | Sets filled-surface opacity: 0.1 is 10% opaque and 1 is fully opaque. Wireframe and views without lighting ignore this setting. Named material presets use 1. |
| `SoundEnabled` | Logical scalar | Enables or mutes manual, rain, and Auto-click sounds. |
| `AutoclickEnabled` | Logical scalar; default `false` | Creates inputs as the pointer moves over the surface in Ripple mode, using `AutoclickStrengthScale`. |
| `LightingEnabled` | Logical scalar | Enables or disables surface lighting. Solid surface uses unfilled, colored mesh edges when lighting is off; white surfaces use black edges. |
| `ReflectionsEnabled` | Logical scalar | Switches between open water and reflecting boundaries. Clears waves and pending rain; preserves the camera, source settings, and pause state. |
| `ReflectionCoefficient` | Real scalar, 0–1 | Reflected amplitude fraction; default 1. Changing it with wave reflections enabled starts a new experiment. Intermediate values require a domain 6.5–26 characteristic wavelengths wide. |
| `ControlsVisible` | Logical scalar | Shows the wavelength, pressure strength, and playback controls. |
| `ReadoutVisible` | Logical scalar | Shows the explanatory text and numerical measurements; corresponds to View > Display status. |
| `ShowFPS` | Logical scalar; default `true` | Shows the rolling frame rate at the lower right. |
| `HeightScale` | Real scalar, 1–1,000,000 | Vertical display multiplier; assigning a value disables automatic scaling. |
| `AutomaticHeightScale` | Logical, initially `true` | Match reference-impulse visibility to water when fluid properties or wavelength change. Selecting a named material disables it and applies that material's fixed height scale. |
| `NavigationMode` | `"Ripple"`, `"Rotate"`, `"Pan"`, or `"Zoom"` | Selects pointer behavior. |

Selecting a named material restores its [preset](../guide/materials.md#material-presets)
fluid properties, wavelength, pressure strength, height scale, and appearance.
Reselecting the same material restores those settings as well. Selecting Water
restores its properties at 20 °C. The excitation method is preserved.
Changing water temperature, material, physical domain, or boundary type clears existing waves
and pending rain and establishes a new physical time origin.
Assigning the already accepted domain or fluid properties preserves the experiment.
Reselecting a material also preserves existing waves when its fluid properties
and source settings already match the preset.
Assigning the accepted boundary setting also preserves it. Material, domain,
and scaled-setup changes retain the selected boundary type; `reset` restores
open water.

Read-only properties:

| Property | Description |
| --- | --- |
| `Figure` | Owned MATLAB figure handle. |
| `PhysicalTime` | Last processed physical time, in seconds. |
| `IsAtRest` | True when the represented surface has no active wave contribution. |
| `MeasuredFPS` | Playback updates per real second, averaged over the last ten frame intervals; zero while paused. This is the value displayed by `ShowFPS`. |
| `Status` | Current application state. |


## Methods

| Method | Description |
| --- | --- |
| [`addRipple`](addRipple.md) | Add one localized source |
| [`rain`](rain.md) | Schedule twenty localized inputs |
| [`update`](update.md) | Process elapsed time and update the surface |
| [`snapshot`](snapshot.md) | Retrieve the wave field data at the current simulation time |
| [`describe`](describe.md) | Read experiment settings and material provenance |
| [`applySetup`](applySetup.md) | Select a scaled water experiment |
| [`clear`](clear.md) | Remove waves and pending rain |
| [`reset`](reset.md) | Restore the default experiment and presentation |
| [`setCameraView`, `restoreCamera`](camera.md) | Select or restore the camera |
| [`capture`](capture.md) | Export the application to PNG |
| [`close`, `delete`](close.md) | Release owned resources |

## Events

`SettingsChanged` follows an accepted physical or display change.
`PlaybackChanged` follows a pause or playback-rate change. Reset emits both.
An observer can read the accepted properties, `snapshot`, or `describe`.
Retain listener handles for as long as the subscription is needed.

## See Also

[`rippleSimulator`](rippleSimulator.md) · [Physics](../guide/physics.md) · [Numerical methods](../guide/numerics.md)
