# setCameraView, restoreCamera

Select a predefined view or restore the original camera

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
setCameraView(simulator,name)
simulator.setCameraView(name)
```

```text
restoreCamera(simulator)
simulator.restoreCamera()
```

## Description

`simulator.setCameraView(name)` selects the close oblique view, a top view, or
a wide view of the surface.

---

`simulator.restoreCamera()` selects the original close view.

---

Camera changes do not affect physical dimensions, waves, or vertical
exaggeration. Use the top or wide view to inspect the boundaries.

## Examples

### Inspect the surface from above

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

### name – Camera preset

`"Close"`, `"Top"`, or `"Wide"`, as a string scalar or character vector.

## See Also

[`capture`](capture.md) · [Controls](../guide/controls.md) · [`app.RippleSimulatorApp`](RippleSimulatorApp.md)
