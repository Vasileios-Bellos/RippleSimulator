# applySetup

Start a new gravity, balanced, or capillary experiment

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
applySetup(simulator,name)
simulator.applySetup(name)
```

## Description

`simulator.applySetup(name)` selects a scaled water experiment and clears
existing waves and pending rain. Each preset uses water at 20 °C. The gravity
setup uses a 50 mm characteristic wavelength in a 650 × 650 mm domain; the balanced
and capillary setups span 6.5 characteristic wavelengths. Gravity and Balanced
start at 0.25x playback; Capillary starts at 0.10x.
The current grid must satisfy the selected source's sampling limits.

The preset restores its pressure strength and height scale. The selected
boundary type, camera, and pause state are preserved.

## Examples

### Select the capillary scale

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

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

### name – Scaled setup

`"Gravity"`, `"Balanced"`, or `"Capillary"`, as a string scalar or character
vector. Both gravity and surface tension contribute to the wave motion in every setup.

## See Also

[`reset`](reset.md) · [Source definitions](../guide/physics.md#source-definitions) · [Physics](../guide/physics.md)
