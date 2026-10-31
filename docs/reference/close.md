# close, delete

Close the app and release its owned resources

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
close(simulator)
simulator.close()
delete(simulator)
```

## Description

`simulator.close()` stops and releases the app's timer, controls, and figure,
then invalidates the application handle. `delete(simulator)` performs the same owned
resource cleanup. Closing the application figure also closes its owning app.
Other figures and timers are unaffected.

## Examples

### Close an owned application

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

## See Also

[`rippleSimulator`](rippleSimulator.md) · [`app.RippleSimulatorApp`](RippleSimulatorApp.md)
