# reset

Restore the default experiment and presentation

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
reset(simulator)
simulator.reset()
```

## Description

`simulator.reset()` restores the gravity-scale water experiment, 201-node grid,
open boundaries, pressure impulse, original camera, display defaults, playback
rate, and initial private rain seed. Existing waves and scheduled rain are
cleared. Playback resumes from zero simulation time.
The viewing-area background follows the figure theme, or uses white on releases without theme support.


## Examples

### Restore display and physical defaults

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

## See Also

[`clear`](clear.md) · [`applySetup`](applySetup.md) · [`app.RippleSimulatorApp`](RippleSimulatorApp.md)
