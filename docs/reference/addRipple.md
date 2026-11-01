# addRipple

Apply one localized source at physical coordinates

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
identifier = addRipple(simulator,position)
identifier = simulator.addRipple(position)
```

## Description

`identifier = simulator.addRipple(position)` applies the current source at
`position = [x, y]`, measured in meters from the domain's center. The input
retains its physical start time, wavelength, pressure strength, and excitation method.
Changing these settings later affects subsequent inputs only.

The position must lie within the observation domain. Sources use the stated
small-disturbance model. A pressure impulse starts with zero
elevation and a velocity disturbance; its elevation develops during playback.

## Examples

### Create simultaneous disturbances

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

### position – Source center

Finite, real, numeric 1-by-2 row vector in meters. Each coordinate must lie
between `-simulator.DomainSize/2` and `simulator.DomainSize/2`, including the endpoints.

## Output Arguments

### identifier – Accepted input number

Positive scalar integer stored as `double`. Numbers increase within the
current experiment; a new physical experiment starts a new input sequence.

## Algorithms

A pressure impulse has a Gaussian spatial profile with width
*s* = *λ*/(2π). Its time-integrated pressure is

<!-- equation: pressure-impulse | The pressure impulse at distance r is J times the exponential of minus r squared divided by twice s squared. -->

$$
\int p_{\mathrm{ext}}(r,t)\thinspace dt=J\exp\negthinspace \left(-\frac{r^2}{2s^2}\right)
$$

*J* is the `PressureImpulse` scale in Pa s; positive applied pressure acts
downward. The four-cycle mode instead applies a finite pressure history.
See [Source definitions](../guide/physics.md#source-definitions) for the forcing equations and
[Physics](../guide/physics.md#model-assumptions-and-numerical-approximations) for the
source-age envelope applied to both direct and reflected contributions.

## See Also

[`rain`](rain.md) · [`snapshot`](snapshot.md) · [Source definitions](../guide/physics.md#source-definitions)
