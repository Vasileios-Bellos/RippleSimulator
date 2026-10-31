# snapshot

Retrieve the wave field data at the current simulation time

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
waveField = snapshot(simulator)
waveField = snapshot(simulator,Derivatives=true)
waveField = simulator.snapshot(Name=Value)
```

## Description

`waveField = simulator.snapshot()` retrieves the wave field data at the current
simulation time. The `Time` field records the last processed simulation time.
Call [`update`](update.md) first when
newly elapsed time must be processed. Display exaggeration and camera settings
do not enter the returned quantities.

---

`waveField = simulator.snapshot(Derivatives=true)` also returns vertical surface velocity
and the horizontal surface-elevation gradients, ∂η/∂x and ∂η/∂y. Velocity includes the derivative of
the finite-duration envelope during the settling interval.

## Examples

<a id="inspect-a-resolved-wave-field"></a>

### Inspect the wave field

Pause an open application before reading a fixed wave state:

```matlab
simulator.Paused = true;
waveField = simulator.snapshot(Derivatives=true);
```

The [wave field inspection example](../guide/examples.md#observe-the-wave-field)
animates the complete time history and describes the `inspectWaveField` options.

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

## Name-Value Arguments

### Derivatives – Include vertical velocity and elevation gradients

`false` (default) or `true`, specified as a logical scalar or numeric 0 or 1.

## Output Arguments

<a id="frame-physical-wave-field"></a>

### waveField – Wave field data

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

## Limitations

Maxima over the grid nodes are not certified continuous-space extrema. Compare finer
grids when small features or slopes matter.

`IsAtRest` describes the represented surface. It does not characterize
residual vorticity throughout the full fluid depth. The finite-duration
envelope makes each source contribution exactly zero at its deadline.

## Algorithms

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

## See Also

[`update`](update.md) · [`describe`](describe.md) · [Physics](../guide/physics.md)
