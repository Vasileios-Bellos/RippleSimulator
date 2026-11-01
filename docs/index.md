# Ripple Simulator

Ripple Simulator is an interactive MATLAB app for visualizing surface gravity
waves and capillary wave ripples. Explore how gravity, surface tension and
viscosity shape waves on a fluid's surface. Click the surface to create ripples,
and watch a localized disturbance separate into waves of different wavelengths
and speeds. Overlap multiple sources or trigger a burst of rain to produce wave
interference patterns, and vary the fluid and wave properties to investigate
wave propagation, dispersion, reflection, and viscous dissipation.

<p>
  <a href="assets/centered-ripple.gif" rel="noopener noreferrer" target="_blank">
    <img src="assets/centered-ripple.gif"
         width="80%"
         alt="A centered disturbance develops into expanding, dispersive rings on a blue water surface and returns to stillness.">
  </a>
</p>

*Water at 20 °C; 50 mm characteristic wavelength in a 650 × 650 mm domain;
801×801 nodes, 100x height scale, and 0.25x playback, exported at 50 frames per second.*

## Quick start

Add the project folder to the MATLAB search path, then run:

```matlab
app = rippleSimulator();
```

Click the surface to create a ripple. Press **P** to pause or resume, **R** for a burst
of rain, or **C** to clear. The menus and axes toolbar provide the same actions.
The wavelength, pressure strength, and playback controls are visible initially; **View > Parameter
controls** shows or hides them.

The bottom panel reports the domain size, fluid, temperature,
grid resolution, playback rate, and selected height scale. Contextual
explanations describe the physical or visual effects of each selection.
Live measurements of crest elevation, trough depth, and wave height support
comparisons between experiments.

## Learning objectives

The [guided experiments](guide/experiments.md) help you interpret the observed wave motion. After working
through them, you should be able to:

| Experiment | Learning objective |
| --- | --- |
| [Observe the wave field](guide/examples.md#observe-the-wave-field) by creating a ripple. | Examine how the surface elevation changes as the ripple propagates. |
| [Compare physical scales](guide/examples.md#compare-physical-scales) by examining the relative contributions of the restoring forces of gravity and surface tension. | Identify the gravity and capillary wave regimes. |
| [Compare phase and group velocities](guide/examples.md#compare-phase-and-group-velocities) by using the gravity–capillary wave dispersion relation. | Explain why individual wave crests can move differently from the wave-packet envelope. |
| [Investigate wave interference](guide/examples.md#investigate-wave-interference) by creating overlapping ripples. | Visualize constructive and destructive interference through linear superposition. |
| [Investigate wave reflection](guide/examples.md#investigate-wave-reflection) by varying the reflection coefficient. | Quantify how the wave amplitude and energy change after successive reflections. |
| [Compare different fluids](guide/examples.md#compare-different-fluids) by applying identical pressure impulses. | Assess the combined effects of the viscosity, density, and surface tension on the propagation and amplitude of the waves. |
| [Isolate the effect of viscosity](guide/examples.md#isolate-the-effect-of-viscosity) by varying it while keeping the other fluid properties and source settings constant. | Observe how viscous dissipation reduces the wave amplitude and determine why shorter-wavelength components decay more rapidly. |

Make a prediction before changing a setting. Compare the resulting field with
that prediction, using the physical measurements and the explanations on the
bottom panel. The [scientific guide](guide/physics.md) supplies the equations and their
assumptions.

<a id="explore-three-questions"></a>

## Explore

Freely explore additional concepts. Create ripples using a pressure impulse or a four-cycle wavemaker. Combine
sources at different positions, vary their characteristic wavelength
and pressure strength, or use rain to produce overlapping waves. Try to answer the following questions:

1. **Why do wave rings separate?** Select the gravity water setup, create a ripple and [follow its expanding pattern](guide/examples.md#observe-the-wave-field). Compare the motion of individual crests with the outward motion of the wave packet. Different spectral components travel at different [phase and group velocities](guide/examples.md#compare-phase-and-group-velocities). Changing the characteristic wavelength changes the [wave spectrum](guide/physics.md#characteristic-wavelength).
2. **What changes at smaller scales?** Compare the [gravity and capillary wave setups](guide/examples.md#compare-physical-scales). Each setup represents a different wave regime. Gravity is the dominant restoring force for the long waves, while [surface tension](guide/physics.md#gravity-and-surface-tension) becomes more important at shorter wavelengths.
3. **What is the role of viscosity?** Compare water at 25 °C with the specified [silicone oils](guide/materials.md#silicone-oils) while keeping the source settings constant. Observe how [viscous dissipation](guide/examples.md#isolate-the-effect-of-viscosity) acts to reduce the wave amplitude and suppress oscillations in [strongly damped wave components](guide/physics.md#viscosity-and-transient-motion).
4. **What happens when it rains?** Generate a [rain burst](guide/examples.md#reproduce-rain) of twenty ripples at random positions. Observe how the [overlapping sources](guide/physics.md#overlapping-sources-and-rain) produce constructive and destructive interference. Repeat with [different random seeds](guide/controls.md#source) to compare the resulting [interference patterns](guide/examples.md#investigate-wave-interference).
5. **What happens when waves reach a boundary?** Enable [wave reflection](guide/examples.md#investigate-wave-reflection) and create a ripple near a boundary. Use the top view to observe the reflected waves and their interference with the outgoing waves. Compare reflection coefficients of 100% and 50% to examine how successive boundary encounters affect a wave component’s [amplitude and energy](guide/physics.md#wave-reflection).
6. **How do the waves differ between fluids?** [Compare](guide/examples.md#compare-different-fluids) water, olive oil, two silicone oil grades, and Newtonian approximations for honey and molten compound chocolate by applying identical pressure impulses. Keep the domain and height scale constant, and examine the wave propagation and amplitude at the same elapsed time. Use a [custom fluid](guide/materials.md#custom-fluids) to vary one property at a time.
7.  **How does the excitation method affect the wave field?** Apply a [pressure impulse](guide/physics.md#pressure-impulse), [observe the wave field](guide/examples.md#observe-the-wave-field), and then repeat with a [four-cycle wavemaker](guide/physics.md#four-cycle-wavemaker) at the same position. Keep the fluid properties, characteristic wavelength, and pressure strength constant. Observe the differences in the formation and propagation of the resulting wave packets.
8.  **How does spatial resolution affect the sampled physical quantities?** Pause playback, then refine the [observation grid](guide/numerics.md#spatial-sampling) while preserving the existing wave state. Use the wireframe view to visualize the effect of [spatial resolution](guide/examples.md#examine-the-effect-of-spatial-resolution) on the sampled physical quantities.

## User guide

- [Installation and requirements](guide/installation.md)
- [Controls, menus, and keyboard shortcuts](guide/controls.md)
- [Sound](guide/sound.md)
- [Numerical experiments and interpretation](guide/experiments.md)
- [Guided and reproducible examples](guide/examples.md)

## Scientific guide

- [Governing physics and assumptions](guide/physics.md)
- [Pressure impulses and wavemakers](guide/physics.md#source-definitions)
- [Numerical methods and exact numerical rest](guide/numerics.md)
- [Material properties and provenance](guide/materials.md)
- [Glossary](guide/physics.md#glossary) and [scientific references](guide/references.md)

## Programming and documentation

- [Functions and Properties](reference/index.md)
- [Third-party notices](guide/notices.md)

Ripple Simulator models gravity–capillary waves on a homogeneous, incompressible
Newtonian fluid of infinite depth based on small-amplitude wave theory. The full
viscous response is obtained by solving the linearized Navier–Stokes and continuity
equations subject to the linearized kinematic and dynamic free-surface boundary
conditions.
The source code is available in the [project
repository](https://github.com/Vasileios-Bellos/RippleSimulator). See [Installation and requirements](guide/installation.md) for
prerequisites, setup instructions, and troubleshooting.
