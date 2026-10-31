# Functions and Properties

`rippleSimulator` launches the interactive gravity-capillary ripple simulator application.
`app.RippleSimulatorApp` provides the class-based interface.
Use the following functions and properties to set up experiments, create sources,
read physical quantities, and control the presentation from MATLAB code.

## Function and class reference

| Reference | Description |
| --- | --- |
| [`rippleSimulator`](#ripplesimulator) | Launch the application |
| [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) | Create the application object |
| [`addRipple`](#addripple) | Apply a localized source |
| [`rain`](#rain) | Schedule twenty manual-equivalent inputs |
| [`snapshot`](#snapshot) | Retrieve the wave field data at the current simulation time |
| [`describe`](#describe) | Read configuration and material provenance |
| [`update`](#update) | Process elapsed time |
| [`applySetup`](#applysetup) | Select a physical scale |
| [`clear`](#clear) | Clear waves and scheduled input |
| [`reset`](#reset) | Restore the defaults |
| [`setCameraView`, `restoreCamera`](#setcameraview-restorecamera) | Select or restore the camera |
| [`capture`](#capture) | Export a PNG image |
| [`close`, `delete`](#close-delete) | Release the application |

<a id="ripplesimulator"></a>

## rippleSimulator

Launch the application

<a id="ripplesimulator-syntax"></a>

### Syntax

```text
rippleSimulator()
app = rippleSimulator()
app = rippleSimulator(Name=Value)
```

<a id="ripplesimulator-description"></a>

### Description

`rippleSimulator()` opens the default gravity-scale water experiment. Click
the surface to create a ripple, or choose commands from the menus and axes
toolbar. Closing the figure releases the app's resources.

---

`app = rippleSimulator()` also returns the owning [`app.RippleSimulatorApp`](#app-ripplesimulatorapp)
handle. Use it to change properties, create sources, and inspect physical data.

---

`app = rippleSimulator(Name=Value)` forwards name-value arguments to the
class constructor.

---

The only required MathWorks product is MATLAB R2022a or later. No additional
toolboxes are required. See
[Installation and requirements](../guide/installation.md) for setup instructions and troubleshooting.

<a id="ripplesimulator-examples"></a>

### Examples

<a id="ripplesimulator-explore-a-capillary-scale-disturbance"></a>

#### Explore a capillary-scale disturbance

Create a localized disturbance in the Capillary water experiment.

```matlab
app = rippleSimulator(Setup="Capillary");
app.addRipple([0, 0]);
```

Surface tension dominates over gravity at the Capillary setup's characteristic wavelength.
The Gaussian pressure impulse excites a spectrum of wavelengths, producing a dispersive
wave packet with concentric rings.

![Full application showing a single capillary-scale ring from a central impulse.](../assets/example-capillary.png)

*Water at 20 °C, 8.72 ms after a central impulse; 5 mm characteristic wavelength,
32.5 × 32.5 mm domain, 201 × 201 grid, and 100x height scale.*

Close the app when finished:

```matlab
app.close();
```

<a id="ripplesimulator-name-value-arguments"></a>

### Name-Value Arguments

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

<a id="ripplesimulator-output-arguments"></a>

### Output Arguments

<a id="ripplesimulator-app-owning-application"></a>

#### app – Owning application

Scalar `app.RippleSimulatorApp` handle. The handle becomes invalid when the application closes.

> **Caution:** An output variable named `app` shadows the `app` namespace.
> This does not affect calls to object methods, such as `app.addRipple`.
> Use a different variable name when calling `app.RippleSimulatorApp(...)`
> directly. If `app` already exists in the Command Window workspace, close
> the application and run `clear app` before accessing the namespace.

<a id="ripplesimulator-see-also"></a>

### See Also

[`app.RippleSimulatorApp`](#app-ripplesimulatorapp) · [Examples](../guide/examples.md) · [Controls](../guide/controls.md)

<a id="app-ripplesimulatorapp"></a>

## app.RippleSimulatorApp

Create a Ripple Simulator application object

<a id="app-ripplesimulatorapp-syntax"></a>

### Syntax

```text
simulator = app.RippleSimulatorApp()
simulator = app.RippleSimulatorApp(Name=Value)
```

```text
simulator.Property = value
```

<a id="app-ripplesimulatorapp-description"></a>

### Description

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

<a id="app-ripplesimulatorapp-examples"></a>

### Examples

<a id="app-ripplesimulatorapp-change-presentation-without-changing-the-physical-field"></a>

#### Change presentation without changing the physical field

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

<a id="app-ripplesimulatorapp-name-value-arguments"></a>

### Name-Value Arguments

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

<a id="app-ripplesimulatorapp-properties"></a>

### Properties


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


<a id="app-ripplesimulatorapp-methods"></a>

### Methods

| Method | Description |
| --- | --- |
| [`addRipple`](#addripple) | Add one localized source |
| [`rain`](#rain) | Schedule twenty localized inputs |
| [`update`](#update) | Process elapsed time and update the surface |
| [`snapshot`](#snapshot) | Retrieve the wave field data at the current simulation time |
| [`describe`](#describe) | Read experiment settings and material provenance |
| [`applySetup`](#applysetup) | Select a scaled water experiment |
| [`clear`](#clear) | Remove waves and pending rain |
| [`reset`](#reset) | Restore the default experiment and presentation |
| [`setCameraView`, `restoreCamera`](#setcameraview-restorecamera) | Select or restore the camera |
| [`capture`](#capture) | Export the application to PNG |
| [`close`, `delete`](#close-delete) | Release owned resources |

<a id="app-ripplesimulatorapp-events"></a>

### Events

`SettingsChanged` follows an accepted physical or display change.
`PlaybackChanged` follows a pause or playback-rate change. Reset emits both.
An observer can read the accepted properties, `snapshot`, or `describe`.
Retain listener handles for as long as the subscription is needed.

<a id="app-ripplesimulatorapp-see-also"></a>

### See Also

[`rippleSimulator`](#ripplesimulator) · [Physics](../guide/physics.md) · [Numerical methods](../guide/numerics.md)

<a id="addripple"></a>

## addRipple

Apply one localized source at physical coordinates

<a id="addripple-syntax"></a>

### Syntax

```text
identifier = addRipple(simulator,position)
identifier = simulator.addRipple(position)
```

<a id="addripple-description"></a>

### Description

`identifier = simulator.addRipple(position)` applies the current source at
`position = [x, y]`, measured in meters from the domain's center. The input
retains its physical start time, wavelength, pressure strength, and excitation method.
Changing these settings later affects subsequent inputs only.

The position must lie within the observation domain. Sources use the stated
small-disturbance model. A pressure impulse starts with zero
elevation and a velocity disturbance; its elevation develops during playback.

<a id="addripple-examples"></a>

### Examples

<a id="addripple-create-simultaneous-disturbances"></a>

#### Create simultaneous disturbances

Use a fixed time source for exactly simultaneous inputs without relying on
the speed of sequential commands.

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
first = simulator.addRipple([-0.1, 0]);
second = simulator.addRipple([0.1, 0]);
info = simulator.describe();
[first, second; info.Simulation.Events.Time]
```

```text
ans =
     1     2
     0     0
```

The two sources have equal pressure strength and start time. Their wave fields
are superimposed linearly. For an interactive experiment, pause before adding both
sources, then resume playback.

```matlab
simulator.close();
```

<a id="addripple-input-arguments"></a>

### Input Arguments

<a id="addripple-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="addripple-position-source-center"></a>

#### position – Source center

Finite, real, numeric 1-by-2 row vector in meters. Each coordinate must lie
between `-simulator.DomainSize/2` and `simulator.DomainSize/2`, including the endpoints.

<a id="addripple-output-arguments"></a>

### Output Arguments

<a id="addripple-identifier-accepted-input-number"></a>

#### identifier – Accepted input number

Positive scalar integer stored as `double`. Numbers increase within the
current experiment; a new physical experiment starts a new input sequence.

<a id="addripple-algorithms"></a>

### Algorithms

A pressure impulse has a Gaussian spatial profile with width
*s* = *λ*/(2π). Its time-integrated pressure is

<!-- equation: pressure-impulse | The pressure impulse at distance r is J times the exponential of minus r squared divided by twice s squared. -->

$$
\int p_{\mathrm{ext}}(r,t)\,dt=J\exp\!\left(-\frac{r^2}{2s^2}\right)
$$

*J* is the `PressureImpulse` scale in Pa s; positive applied pressure acts
downward. The four-cycle mode instead applies a finite pressure history.
See [Source definitions](../guide/physics.md#source-definitions) for the forcing equations and
[Physics](../guide/physics.md#model-assumptions-and-numerical-approximations) for the
source-age envelope applied to both direct and reflected contributions.

<a id="addripple-see-also"></a>

### See Also

[`rain`](#rain) · [`snapshot`](#snapshot) · [Source definitions](../guide/physics.md#source-definitions)

<a id="rain"></a>

## rain

Schedule twenty localized sources

<a id="rain-syntax"></a>

### Syntax

```text
rain(simulator)
simulator.rain()
```

<a id="rain-description"></a>

### Description

`simulator.rain()` schedules twenty inputs at positions drawn uniformly from
the observation domain and placed at the nearest grid nodes. The first is issued immediately, followed by nineteen
inputs spaced by 0.05 seconds of elapsed real time while playback runs. Each event uses
the same source operation as a manual click. By default, its pressure strength is also
the same. `RainStrengthScale` multiplies the selected pressure strength for rain.
Each burst retains the multiplier selected when it was scheduled; wavelength,
excitation method, and pressure strength follow their settings at each input time.

The [source definition](../guide/physics.md#pressure-impulse) gives the applied pressure
impulse and its physical units. Rain demonstrates the superposition of
localized gravity-capillary waves. The source idealization represents wave
excitation without resolving drop deformation, impact cavities, or splashing.
[Measured ring-wave scales](../guide/physics.md#wave-dispersion) provide experimental
context for the resulting elevations and propagation speeds.

Pausing suspends the remaining schedule. Rain requests are ignored while paused.
A delayed update processes overdue
inputs at their intended timestamps. Additional bursts retain the pending drops
and overlap their schedules. `clear` cancels unissued inputs.
`RandomSeed` controls a private random number stream. Rain generation does not
change the state of MATLAB's global random number stream.

When sound is enabled during playback, each burst plays one recording of rain
striking water. Mute or pause stops the recording. Repeated bursts can overlap
their recordings as well as their wave fields.

<a id="rain-examples"></a>

### Examples

<a id="rain-repeat-a-burst-s-positions"></a>

#### Repeat a burst's positions

Reinitialize the private seed to repeat the positions. Clearing alone retains
the stream's progression.

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
simulator.RandomSeed = 42;
simulator.rain();
first = simulator.describe();
simulator.clear();
simulator.RandomSeed = 42;
simulator.rain();
second = simulator.describe();
isequal(first.Simulation.Events.Position, second.Simulation.Events.Position)
```

```text
ans =
  logical
   1
```

Only the first source is due at this fixed time. The remaining nineteen
positions are reserved for later playback.

```matlab
simulator.close();
```

<a id="rain-input-arguments"></a>

### Input Arguments

<a id="rain-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="rain-see-also"></a>

### See Also

[`addRipple`](#addripple) · [`clear`](#clear) · [`update`](#update)

<a id="snapshot"></a>

## snapshot

Retrieve the wave field data at the current simulation time

<a id="snapshot-syntax"></a>

### Syntax

```text
waveField = snapshot(simulator)
waveField = snapshot(simulator,Derivatives=true)
waveField = simulator.snapshot(Name=Value)
```

<a id="snapshot-description"></a>

### Description

`waveField = simulator.snapshot()` retrieves the wave field data at the current
simulation time. The `Time` field records the last processed simulation time.
Call [`update`](#update) first when
newly elapsed time must be processed. Display exaggeration and camera settings
do not enter the returned quantities.

---

`waveField = simulator.snapshot(Derivatives=true)` also returns vertical surface velocity
and the horizontal surface-elevation gradients, ∂η/∂x and ∂η/∂y. Velocity includes the derivative of
the finite-duration envelope during the settling interval.

<a id="snapshot-examples"></a>

### Examples

<a id="snapshot-inspect-a-resolved-wave-field"></a>

<a id="snapshot-inspect-the-wave-field"></a>

#### Inspect the wave field

Pause an open application before reading a fixed wave state:

```matlab
simulator.Paused = true;
waveField = simulator.snapshot(Derivatives=true);
```

The [wave field inspection example](../guide/examples.md#observe-the-wave-field)
animates the complete time history and describes the `inspectWaveField` options.

<a id="snapshot-input-arguments"></a>

### Input Arguments

<a id="snapshot-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="snapshot-name-value-arguments"></a>

### Name-Value Arguments

<a id="snapshot-derivatives-include-vertical-velocity-and-elevation-gradients"></a>

#### Derivatives – Include vertical velocity and elevation gradients

`false` (default) or `true`, specified as a logical scalar or numeric 0 or 1.

<a id="snapshot-output-arguments"></a>

### Output Arguments

<a id="snapshot-frame-physical-wave-field"></a>

<a id="snapshot-wavefield-wave-field-data"></a>

#### waveField – Wave field data

Scalar structure with the following fields. *N* is `simulator.GridResolution`.

| Field | Size and description | Units |
| --- | --- | --- |
| `Elevation` | *N*-by-*N* surface elevation | m |
| `Velocity` | *N*-by-*N* vertical surface velocity when requested; otherwise empty | m/s |
| `GradientX`, `GradientY` | *N*-by-*N* horizontal derivatives when requested; otherwise empty | Dimensionless |
| `Coordinates` | 1-by-*N* x and y node coordinates | m |
| `DomainSize` | Physical domain width | m |
| `Time` | Last processed simulation time | s |
| `IsAtRest` | True when the represented surface has no active wave contribution | – |
| `GeometryRevision` | Observation grid revision identifier | – |

<a id="snapshot-limitations"></a>

### Limitations

Maxima over the grid nodes are not certified continuous-space extrema. Compare finer
grids when small features or slopes matter.

`IsAtRest` describes the represented surface. It does not characterize
residual vorticity throughout the full fluid depth. The finite-duration
envelope makes each source contribution exactly zero at its deadline.

<a id="snapshot-algorithms"></a>

### Algorithms

For a pressure impulse in open water, the unmodified elevation is

<!-- equation: hankel-response | The radial elevation is minus J s squared over density times the integral of k squared times the Gaussian spectrum, Bessel J zero, and h epsilon over omega zero. -->

$$
\eta_{\mathrm{v}}(r,a)=-\frac{Js^2}{\rho}\int_0^\infty\frac{k^2}{\omega_0(k)}e^{-s^2k^2/2}J_0(kr)h_\epsilon(\omega_0(k)a)\,dk
$$

Here *a* is source age, *s* its Gaussian width, *J* the pressure impulse,
*ρ* density, *J*₀ the order-zero Bessel function, and *h*ε the inverse Laplace
transform of the full viscous transfer function. The source contributions are superimposed. Ideal
reflecting walls use a cosine expansion with the same viscous modal response.

During finite settling, the reported elevation and velocity are

<!-- equation: settling-fields | Elevation is E times the viscous elevation; vertical velocity is E times viscous velocity plus E prime times viscous elevation. -->

$$
\eta=E\eta_{\mathrm{v}},\qquad\partial_t\eta=E\partial_t\eta_{\mathrm{v}}+E'\eta_{\mathrm{v}},\qquad\nabla_h\eta=E\nabla_h\eta_{\mathrm{v}}
$$

The [Physics](../guide/physics.md) and [Numerical methods](../guide/numerics.md) pages define
the equations, interpolation, omission bounds, and finite-duration approximation.

<a id="snapshot-see-also"></a>

### See Also

[`update`](#update) · [`describe`](#describe) · [Physics](../guide/physics.md)

<a id="describe"></a>

## describe

Read experiment settings and material provenance

<a id="describe-syntax"></a>

### Syntax

```text
info = describe(simulator)
info = simulator.describe()
```

<a id="describe-description"></a>

### Description

`info = simulator.describe()` returns the experiment configuration from one processed state. It does not advance time.
Fluid properties include SI unit names and source provenance.

Use the record to identify the fluid, source definition, physical dimensions,
playback rate, height scale, source settings, and simulation time.
It is an inspection record, not a serialized app that can be loaded to resume
an experiment.

<a id="describe-examples"></a>

### Examples

<a id="describe-inspect-the-scaled-experiment"></a>

#### Inspect the scaled experiment

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
info = simulator.describe();
fprintf("Domain: %.2f m\nGrid: %d nodes per side\nHeight scale: %gx\n", ...
    info.DomainSizeMeters, info.GridResolution, info.HeightScale);
```

```text
Domain: 0.65 m
Grid: 201 nodes per side
Height scale: 100x
```

The domain spans 0.65 × 0.65 m. The rendering uses 201 nodes per side and a height
multiplier of 100; the multiplier is absent from `snapshot` values.

```matlab
simulator.close();
```

<a id="describe-input-arguments"></a>

### Input Arguments

<a id="describe-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="describe-output-arguments"></a>

### Output Arguments

<a id="describe-info-configuration-record"></a>

#### info – Configuration record

Scalar structure. Principal groups are `Fluid`, `Source`, `Display`, `Camera`,
and `Simulation`. Other fields report material, domain width, grid resolution,
playback rate, height scale, pause state, pending rain, rain multiplier, seed, boundary setting,
and application state.

`Display.BackgroundColor` records the viewing area's current RGB background.

The `Simulation.Events` records identify active source positions, start times,
pressure strengths, and source definitions. Use these alongside the material record when
comparing experiments. Physical quantities are returned by `snapshot`.

<a id="describe-see-also"></a>

### See Also

[`snapshot`](#snapshot) · [Materials](../guide/materials.md) · [Numerical methods](../guide/numerics.md)

<a id="update"></a>

## update

Process elapsed time and update the existing surface

<a id="update-syntax"></a>

### Syntax

```text
update(simulator)
simulator.update()
```

<a id="update-description"></a>

### Description

`simulator.update()` samples the monotonic time source, processes due rain
events at their scheduled timestamps, and renders the current wave state.
Use it for an app created with `AutomaticUpdates=false`. Automatic playback
calls the same update route.

An update is an observation of elapsed time, not a fixed physical integration
step. Fewer rendered frames do not slow the waves. Pausing stops the simulation
and rain schedule; time spent preparing a configuration is excluded from playback.

<a id="update-examples"></a>

### Examples

<a id="update-update-without-advancing-the-clock"></a>

#### Update without advancing the clock

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
simulator.addRipple([0, 0]);
before = simulator.snapshot(Derivatives=true);
simulator.update();
after = simulator.snapshot(Derivatives=true);
isequal(before, after)
```

```text
ans =
  logical
   1
```

With no elapsed time, another update does not advance the physical state.
The [wave field inspection example](../guide/examples.md#observe-the-wave-field) uses
a controllable clock to sample the wave field at uniformly spaced times.

```matlab
simulator.close();
```

<a id="update-input-arguments"></a>

### Input Arguments

<a id="update-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="update-algorithms"></a>

### Algorithms

Within a running interval of fixed playback rate *b*, a real elapsed
increment Δ*t* advances simulation time by

<!-- equation: playback-time | The change in simulation time equals playback rate times elapsed real time. -->

$$
\Delta t_{\mathrm{sim}}=b\,\Delta t_{\mathrm{real}}
$$

The clock accounts for pause intervals and changes in rate. A rate change
affects subsequent playback and does not rescale elapsed simulation time.
Source responses are sampled at their physical ages.

<a id="update-see-also"></a>

### See Also

[`snapshot`](#snapshot) · [`rain`](#rain) · [`app.RippleSimulatorApp`](#app-ripplesimulatorapp)

<a id="applysetup"></a>

## applySetup

Start a new gravity, balanced, or capillary experiment

<a id="applysetup-syntax"></a>

### Syntax

```text
applySetup(simulator,name)
simulator.applySetup(name)
```

<a id="applysetup-description"></a>

### Description

`simulator.applySetup(name)` selects a scaled water experiment and clears
existing waves and pending rain. Each preset uses water at 20 °C. The gravity
setup uses a 50 mm characteristic wavelength in a 650 × 650 mm domain; the balanced
and capillary setups span 6.5 characteristic wavelengths. Gravity and Balanced
start at 0.25x playback; Capillary starts at 0.10x.
The current grid must satisfy the selected source's sampling limits.

The preset restores its pressure strength and height scale. The selected
boundary type, camera, and pause state are preserved.

<a id="applysetup-examples"></a>

### Examples

<a id="applysetup-select-the-capillary-scale"></a>

#### Select the capillary scale

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
simulator.applySetup("Capillary");
simulator.DomainSize/simulator.Wavelength
```

```text
ans =
    6.5000
```

The physical dimensions change together. The visible framing stays comparable
while the bottom panel reports the new domain size. Changing `Wavelength` alone instead
retains the domain and affects only new sources.

```matlab
simulator.close();
```

<a id="applysetup-input-arguments"></a>

### Input Arguments

<a id="applysetup-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="applysetup-name-scaled-setup"></a>

#### name – Scaled setup

`"Gravity"`, `"Balanced"`, or `"Capillary"`, as a string scalar or character
vector. Both gravity and surface tension contribute to the wave motion in every setup.

<a id="applysetup-see-also"></a>

### See Also

[`reset`](#reset) · [Source definitions](../guide/physics.md#source-definitions) · [Physics](../guide/physics.md)

<a id="clear"></a>

## clear

Clear waves and cancel pending rain

<a id="clear-syntax"></a>

### Syntax

```text
clear(simulator)
simulator.clear()
```

<a id="clear-description"></a>

### Description

`simulator.clear()` removes active sources and pending rain. The surface elevation,
vertical velocity, and horizontal elevation gradients become exactly zero.
Physical time, settings, camera, pause state, and the state of the private random
number stream are preserved. Use [`reset`](#reset) to restore the complete default experiment.

<a id="clear-examples"></a>

### Examples

<a id="clear-cancel-a-scheduled-burst"></a>

#### Cancel a scheduled burst

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
simulator.rain();
simulator.clear();
info = simulator.describe();
[simulator.IsAtRest, info.PendingRain]
```

```text
ans =
     1     0
```

```matlab
simulator.close();
```

<a id="clear-input-arguments"></a>

### Input Arguments

<a id="clear-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="clear-see-also"></a>

### See Also

[`reset`](#reset) · [`rain`](#rain) · [`snapshot`](#snapshot)

<a id="reset"></a>

## reset

Restore the default experiment and presentation

<a id="reset-syntax"></a>

### Syntax

```text
reset(simulator)
simulator.reset()
```

<a id="reset-description"></a>

### Description

`simulator.reset()` restores the gravity-scale water experiment, 201-node grid,
open boundaries, pressure impulse, original camera, display defaults, playback
rate, and initial private rain seed. Existing waves and scheduled rain are
cleared. Playback resumes from zero simulation time.
The viewing-area background follows the figure theme, or uses white on releases without theme support.


<a id="reset-examples"></a>

### Examples

<a id="reset-restore-display-and-physical-defaults"></a>

#### Restore display and physical defaults

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false, TimeSource=@() 0);
simulator.Wireframe = true;
simulator.Paused = true;
simulator.reset();
[simulator.Wireframe, simulator.Paused, simulator.ReflectionsEnabled]
```

```text
ans =
  1x3 logical array
   0   0   0
```

```matlab
simulator.close();
```

<a id="reset-input-arguments"></a>

### Input Arguments

<a id="reset-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="reset-see-also"></a>

### See Also

[`clear`](#clear) · [`applySetup`](#applysetup) · [`app.RippleSimulatorApp`](#app-ripplesimulatorapp)

<a id="setcameraview-restorecamera"></a>

## setCameraView, restoreCamera

Select a predefined view or restore the original camera

<a id="setcameraview-restorecamera-syntax"></a>

### Syntax

```text
setCameraView(simulator,name)
simulator.setCameraView(name)
```

```text
restoreCamera(simulator)
simulator.restoreCamera()
```

<a id="setcameraview-restorecamera-description"></a>

### Description

`simulator.setCameraView(name)` selects the close oblique view, a top view, or
a wide view of the surface.

---

`simulator.restoreCamera()` selects the original close view.

---

Camera changes do not affect physical dimensions, waves, or vertical
exaggeration. Use the top or wide view to inspect the boundaries.

<a id="setcameraview-restorecamera-examples"></a>

### Examples

<a id="setcameraview-restorecamera-inspect-the-surface-from-above"></a>

#### Inspect the surface from above

```matlab
simulator = app.RippleSimulatorApp();
simulator.setCameraView("Top");
simulator.addRipple([0.2, -0.1]);
```

Return to the close view after inspecting the disturbance:

```matlab
simulator.restoreCamera();
simulator.close();
```

<a id="setcameraview-restorecamera-input-arguments"></a>

### Input Arguments

<a id="setcameraview-restorecamera-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="setcameraview-restorecamera-name-camera-preset"></a>

#### name – Camera preset

`"Close"`, `"Top"`, or `"Wide"`, as a string scalar or character vector.

<a id="setcameraview-restorecamera-see-also"></a>

### See Also

[`capture`](#capture) · [Controls](../guide/controls.md) · [`app.RippleSimulatorApp`](#app-ripplesimulatorapp)

<a id="capture"></a>

## capture

Export the application view to a PNG image

<a id="capture-syntax"></a>

### Syntax

```text
capture(simulator,filename)
simulator.capture(filename)
simulator.capture()
```

<a id="capture-description"></a>

### Description

`simulator.capture(filename)` saves the currently displayed application frame.

---

`simulator.capture()` opens a filename dialog after copying the displayed pixels.
The saved image therefore represents the view when capture was requested,
regardless of time spent choosing the filename.

---

Visible controls and panels are included; the native menu bar and window border
are not. The filename
must end in `.png`. Existing files can be overwritten; use a distinct filename
to preserve previous captures.

Choose **View > Save Screenshot...** or press **Ctrl+S** (**Command+S** on
macOS) to capture the current view. The shortcut also works in full screen.

<a id="capture-examples"></a>

### Examples

<a id="capture-capture-an-experiment"></a>

#### Capture an experiment

Create a ripple and pause at a frame of interest. Then choose an output path:

```matlab
simulator = app.RippleSimulatorApp();
simulator.addRipple([0, 0]);
```

```matlab
simulator.Paused = true;
simulator.capture("ripples.png");
```

When visible, the bottom panel identifies the domain, display
height scale, and playback rate used for the view. Full-screen capture contains
only the surface.

```matlab
simulator.close();
```

<a id="capture-input-arguments"></a>

### Input Arguments

<a id="capture-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="capture-filename-png-destination"></a>

#### filename – PNG destination

String scalar or character vector with a `.png` extension. Relative paths
are interpreted from MATLAB's current folder.

<a id="capture-see-also"></a>

### See Also

[`setCameraView`](#setcameraview-restorecamera) · [`snapshot`](#snapshot) · [MATLAB getframe](https://www.mathworks.com/help/matlab/ref/getframe.html)

<a id="close-delete"></a>

## close, delete

Close the app and release its owned resources

<a id="close-delete-syntax"></a>

### Syntax

```text
close(simulator)
simulator.close()
delete(simulator)
```

<a id="close-delete-description"></a>

### Description

`simulator.close()` stops and releases the app's timer, controls, and figure,
then invalidates the application handle. `delete(simulator)` performs the same owned
resource cleanup. Closing the application figure also closes its owning app.
Other figures and timers are unaffected.

<a id="close-delete-examples"></a>

### Examples

<a id="close-delete-close-an-owned-application"></a>

#### Close an owned application

```matlab
simulator = app.RippleSimulatorApp(Visible="off", AutomaticUpdates=false);
simulator.close();
isvalid(simulator)
```

```text
ans =
  logical
   0
```

In a function, use `onCleanup(@() simulator.close())` when the application should
close on both normal completion and an error. Keep the cleanup object alive
for the required lifetime.

<a id="close-delete-input-arguments"></a>

### Input Arguments

<a id="close-delete-simulator-application"></a>

#### simulator – Application

Scalar [`app.RippleSimulatorApp`](#app-ripplesimulatorapp) handle.

<a id="close-delete-see-also"></a>

### See Also

[`rippleSimulator`](#ripplesimulator) · [`app.RippleSimulatorApp`](#app-ripplesimulatorapp)

## Customization

Custom fluid properties can be supplied through `FluidProperties` or
**Experiment > Material > Custom > Define properties...**. Additional named
presets are implemented in the source code. See
[Custom fluids](../guide/materials.md#custom-fluids) for the property inputs and
[Constitutive model and rheology](../guide/physics.md#constitutive-model-and-rheology)
for the material assumptions.

### Add a fluid preset

1. **Define the material properties.** Add a function in
   `+app/+internal/+materials/` that returns an `app.internal.materials.Fluid`
   object. The existing `oliveOil.m` definition provides a compact template.
   The constructor accepts the material name, temperature in degrees Celsius,
   density in kg/m³, dynamic viscosity in Pa·s, surface tension in N/m, and a
   reference string, in that order. The reference identifies the property
   sources and measurement conditions. Kinematic viscosity is calculated from
   the dynamic viscosity and density.

2. **Integrate the preset into the application.** In
   `+app/RippleSimulatorApp.m`, extend the accepted values and selection branch
   in `set.Material`. The branch calls the new material function and specifies
   the characteristic wavelength, pressure strength, and height scale.
   `get.Material` maps the fluid's `Name` to the same preset identifier. The
   local `materialStyle` function supplies its surface appearance. These
   settings are applied whenever the material is selected, including when it
   is selected again. Wavelength is specified in meters and `PressureImpulse`
   in Pa·s; the controls display millimeters and mPa·s.

3. **Add the menu entry.** In `createMenus` in
   `+app/+internal/+ui/Controls.m`, add a material choice using the same preset
   identifier. The existing choices pass the `material` action and the
   `Material` property to `obj.choice`. This routes menu selections through
   the property setter and synchronizes the checkmark with the selected
   material.

Preset properties apply at their specified temperature. A temperature-dependent
preset also requires a property correlation and corresponding support in
`set.Temperature` and the temperature menu; a single-temperature property record
does not define that dependence. The material assumptions and supporting data
are described in [Materials](../guide/materials.md).

`tests/+unit/FluidPropertiesTest.m` checks property values, units, correlations,
and input ranges. `tests/+integration/MaterialPresetsTest.m` checks material
selection and restoration of experiment settings. Additional presets require
corresponding cases for their property values and selection behavior.

## Tests

After modifying the source code, run the test suite from the project folder:

```matlab
results = runtests("tests", IncludeSubfolders=true);
assertSuccess(results);
```

The suite uses `matlab.unittest.TestCase` classes. `runtests` returns the
individual test results; `assertSuccess` raises an error if any test fails, so
an automated run can report the failure to its caller. See the
[MathWorks documentation](https://www.mathworks.com/help/matlab/ref/matlab.unittest.testresult.assertsuccess.html)
for more details.

| Test group | Coverage |
| --- | --- |
| Unit | Physical limits, fluid properties, elapsed-time behavior, and packaged audio |
| Integration | Source superposition, boundary conditions, material selection, graphics retention, timer cleanup, and the examples' wave-field histories and dispersion data |

Run a test group by specifying its tag:

```matlab
results = runtests("tests", IncludeSubfolders=true, Tag="Unit");
assertSuccess(results);
```

Use `Tag="Integration"` to select the integration tests. An individual test
class can also be run by its file path:

```matlab
results = runtests("tests/+integration/MaterialPresetsTest.m");
assertSuccess(results);
```

Application tests create hidden figures and release their figures and timers.
The `support` namespace in `tests/+support/` contains the shared test base class
and a controllable clock for reproducible timing checks.

## Native MATLAB help

The code includes class, property, and method help for MATLAB's native routes:

```text
help rippleSimulator
help app.RippleSimulatorApp.addRipple
doc app.RippleSimulatorApp
doc app.RippleSimulatorApp.snapshot
```

MATLAB generates the class reference from its metadata and source comments.
The HTML manual is generated with DocMaker and registered
under **Supplemental Software**. Both documentation routes describe the same
public API; the custom manual adds worked figures, equations, and topic guides.
See [Installation and requirements](../guide/installation.md) for additional details.

## Related Topics

[Governing physics](../guide/physics.md) · [Source definitions](../guide/physics.md#source-definitions) ·
[Material properties](../guide/materials.md) · [Numerical methods](../guide/numerics.md)
