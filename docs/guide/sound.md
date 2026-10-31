# Sound

[Ripple Simulator](../index.md) / Sound

Splash and rain recordings accompany the wave inputs. They provide audible
feedback; they are not an acoustic simulation of the fluid.

## Controls

Use the speaker axes-toolbar button, **M**, or **Playback > Sound**
to enable or mute both recordings. Pause and mute stop any sounds already
playing. Closing the app releases its audio players and clips.

## Recordings and overlap

Manual clicks and Auto-click share sixteen simultaneous splash voices. Each
input starts a free voice without interrupting a sound already playing.
Rain uses a separate recording, played once when a burst begins, with twenty
voices available for overlapping bursts. If all voices in a pool are occupied,
the existing sounds finish and further wave inputs proceed without sound.

The splash recording is normalized once and played at twice its recorded
sample rate. Auto-click applies an amplitude gain of 0.8, approximately
−1.94 dB relative to manual splashes. Manual splashes and rain use unity
playback gain. These gains are independent of the pressure strength used for
the waves.

Rain plays at its recorded sample rate. The recording accompanies the burst
as a whole; its individual audible drops are not synchronized to the twenty
simulated impacts. Neither recording changes speed with the simulation's
playback multiplier.

<a id="prepared-playback"></a>

## Reusable playback

Both recordings are loaded once. Where MATLAB has a compatible Java runtime,
preloaded Java audio clips provide reusable playback without constructing a
player for each click. Opening a clip can leave device initialization until
its first playback. Each clip is therefore started while muted, stopped,
and rewound during app initialization. Its previous mute setting is then
restored. Subsequent inputs reuse the initialized clips and their samples.

Initialized MATLAB `audioplayer` objects provide a fallback when Java audio or
the required device controls are unavailable. The fallback players are
created before interactive input begins. A Java playback failure can switch
to these existing players without constructing another player in the input
callback. See [Optional Java audio](installation.md#optional-java-audio) for
runtime requirements.

Java applies the Auto-click gain to the selected free voice, leaving sounds
already playing unchanged. The MATLAB fallback uses samples scaled during
initialization, with manual and Auto-click players sharing the same sixteen
voice slots. An occupied voice is available again after its recording finishes.
The fixed pools bound the number of simultaneous sounds and keep audio-object
creation outside interactive playback.

The MATLAB pool tracks completion through `StopFcn`. During shutdown,
players remain available to pending completion callbacks until MATLAB has
finished updating their playback state.
