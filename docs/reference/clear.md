# clear

Clear waves and cancel pending rain

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
clear(simulator)
simulator.clear()
```

## Description

`simulator.clear()` removes active sources and pending rain. The surface elevation,
vertical velocity, and horizontal elevation gradients become exactly zero.
Physical time, settings, camera, pause state, and the state of the private random
number stream are preserved. Use [`reset`](reset.md) to restore the complete default experiment.

## Examples

### Cancel a scheduled burst

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

## See Also

[`reset`](reset.md) · [`rain`](rain.md) · [`snapshot`](snapshot.md)
