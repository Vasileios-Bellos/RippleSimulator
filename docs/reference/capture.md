# capture

Export the application view to a PNG image

[Ripple Simulator](../index.md) / [Functions and Properties](index.md)

## Syntax

```text
capture(simulator,filename)
simulator.capture(filename)
simulator.capture()
```

## Description

`simulator.capture(filename)` saves the currently displayed application frame.

---

`simulator.capture()` opens a filename dialog after copying the displayed pixels.
The saved image therefore represents the view when capture was requested,
regardless of time spent choosing the filename.

---

Visible controls and panels are included; the native menu bar and window border
are not. The filename
must end in `.png`. Existing files can be overwritten; use a distinct filename
to preserve previous captures.

Choose **View > Save Screenshot...** or press **Ctrl+S** (**Command+S** on
macOS) to capture the current view. The shortcut also works in full screen.

## Examples

### Capture an experiment

Create a ripple and pause at a frame of interest. Then choose an output path:

```matlab
simulator = app.RippleSimulatorApp();
simulator.addRipple([0, 0]);
```

```matlab
simulator.Paused = true;
simulator.capture("ripples.png");
```

When visible, the bottom panel identifies the domain, display
height scale, and playback rate used for the view. Full-screen capture contains
only the surface.

```matlab
simulator.close();
```

## Input Arguments

### simulator – Application

Scalar [`app.RippleSimulatorApp`](RippleSimulatorApp.md) handle.

### filename – PNG destination

String scalar or character vector with a `.png` extension. Relative paths
are interpreted from MATLAB's current folder.

## See Also

[`setCameraView`](camera.md) · [`snapshot`](snapshot.md) · [MATLAB getframe](https://www.mathworks.com/help/matlab/ref/getframe.html)
