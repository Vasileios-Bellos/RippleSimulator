# update

Process elapsed time and update the existing surface

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
update(simulator)
simulator.update()
```

## Description

`simulator.update()` samples the monotonic time source, processes due rain
events at their scheduled timestamps, and renders the current wave state.
Use it for an app created with `AutomaticUpdates=false`. Automatic playback
calls the same update route.

An update is an observation of elapsed time, not a fixed physical integration
step. Fewer rendered frames do not slow the waves. Pausing stops the simulation
and rain schedule; time spent preparing a configuration is excluded from playback.

## Examples

### Update without advancing the clock

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

## Algorithms

Within a running interval of fixed playback rate *b*, a real elapsed
increment Δ*t* advances simulation time by

<!-- equation: playback-time | The change in simulation time equals playback rate times elapsed real time. -->

$$
\Delta t_{\mathrm{sim}}=b\,\Delta t_{\mathrm{real}}
$$

The clock accounts for pause intervals and changes in rate. A rate change
affects subsequent playback and does not rescale elapsed simulation time.
Source responses are sampled at their physical ages.

## See Also

[`snapshot`](snapshot.md) · [`rain`](rain.md) · [`app.RippleSimulatorApp`](RippleSimulatorApp.md)
