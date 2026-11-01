# Installation and requirements

## MATLAB

Ripple Simulator is a programmatic MATLAB class app. It requires MATLAB R2022a
or later. MATLAB R2026b is recommended. No additional MathWorks toolboxes or
documentation-authoring tools are required. The source code is available in the
[project repository](https://github.com/Vasileios-Bellos/RippleSimulator).
Keep the package folders, launcher, and documentation together when moving
the project.

To use Ripple Simulator, add the project folder to the MATLAB search path and
launch the app:

```matlab
projectFolder = "path/to/RippleSimulator";
addpath(projectFolder);
app = rippleSimulator();
```

Replace the example path with the location on your computer.

## Optional Java audio

Splash and rain playback use preloaded Java clips when MATLAB has a compatible Java
runtime available. Otherwise, the app uses MATLAB audio players. Java is optional;
the wave simulation and controls do not depend on it.

For releases without a bundled Java runtime, follow MathWorks' instructions to
[install and configure OpenJDK](https://www.mathworks.com/help/matlab/matlab_external/configure-your-system-to-use-java.html).
The app does not change MATLAB's Java configuration.

See [Sound](sound.md) for the audio playback options.

## Documentation

The **Help** menu opens the included HTML manual. You can also open
`docs/index.html` directly in a browser. Its styles, equations, and illustrations
are included locally; following an external scientific-reference link requires
an internet connection.

The original Markdown pages are included with the HTML. Running the app and
reading the finished manual do not require documentation-authoring tools.

MATLAB desktop custom Help discovery uses the included `info.xml` and
`helptoc.xml` metadata. To include the manual in **Supplemental Software**,
also add its HTML folder to the path:

```matlab
addpath(fullfile(projectFolder, "docs"));
```

Add the project folder from a different current folder so that MATLAB can read
its documentation metadata. The app's direct Help menu and browser links remain available without
native registration. See the [MathWorks custom-documentation guide](https://www.mathworks.com/help/matlab/matlab_prog/display-custom-documentation.html)
for more details.

## Troubleshooting

### Reduced playback frame rate

A fine grid can lower the playback frame rate. **Experiment > Grid resolution**
controls the number of nodes per side used for the spatial discretization of
the surface. Reducing the number of nodes lowers the sampling and rendering
costs and the spatial resolution while preserving the physical dimensions and
source history. Aim for a good balance between playback performance and spatial
resolution, keeping enough nodes to adequately resolve the sources and wave
features of interest. See
[Spatial sampling](numerics.md#spatial-sampling) for the sampling requirements.

### Playback interruptions during mouse movement

In MATLAB releases preceding R2026a, moving the pointer over the surface can
[interrupt playback due to the axes toolbar's mouse-motion tracking](https://www.mathworks.com/matlabcentral/answers/705683-very-slow-graphics-when-mouse-pointer-moves-around-a-figure).
Playback continues when the pointer stops moving.

To remove the axes toolbar from an application stored in `app`:

```matlab
ax = findall(app.Figure, "Type", "axes", "Tag", "SurfaceAxes");
ax.Toolbar = [];
```

The menus and keyboard shortcuts remain available. This issue is
[resolved](https://www.mathworks.com/matlabcentral/answers/705683-very-slow-graphics-when-mouse-pointer-moves-around-a-figure#answer_1575081) in
[MATLAB R2026a and later](https://blogs.mathworks.com/graphics-and-apps/2026/05/04/an-accessible-modern-axes-toolbar/).

See [Getting started](../index.md) for an introduction to the app,
[Controls](controls.md) for the menus, axes toolbar, and keyboard shortcuts, and
[Functions and Properties](../reference/index.md) for using the app programmatically.
