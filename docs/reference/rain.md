# rain

Schedule twenty localized sources

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
rain(simulator)
simulator.rain()
```

## Description

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

## Examples

### Repeat a burst's positions

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

## See Also

[`addRipple`](addRipple.md) · [`clear`](clear.md) · [`update`](update.md)
