# describe

Read experiment settings and material provenance

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
info = describe(simulator)
info = simulator.describe()
```

## Description

`info = simulator.describe()` returns the experiment configuration from one processed state. It does not advance time.
Fluid properties include SI unit names and source provenance.

Use the record to identify the fluid, source definition, physical dimensions,
playback rate, height scale, source settings, and simulation time.
It is an inspection record, not a serialized app that can be loaded to resume
an experiment.

## Examples

### Inspect the scaled experiment

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

## Output Arguments

### info – Configuration record

Scalar structure. Principal groups are `Fluid`, `Source`, `Display`, `Camera`,
and `Simulation`. Other fields report material, domain width, grid resolution,
playback rate, height scale, pause state, pending rain, rain multiplier, seed, boundary setting,
and application state.

`Display.BackgroundColor` records the viewing area's current RGB background.

The `Simulation.Events` records identify active source positions, start times,
pressure strengths, and source definitions. Use these alongside the material record when
comparing experiments. Physical quantities are returned by `snapshot`.

## See Also

[`snapshot`](snapshot.md) · [Materials](../guide/materials.md) · [Numerical methods](../guide/numerics.md)
