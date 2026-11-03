# Nova visual trials

Isolated visual experiments, rendered with Godot 4.6.1 / OpenGL Compatibility.
The first soft/blur experiments are preserved here for comparison.
The later generated-alpha effect is now integrated into the production spell.
No save files are written by the capture scripts.

- A: original shaders.
- B: wider Gaussian wave/echo, softer Fresnel band fading at the mesh silhouette.
- C: B plus a continuous inward radial tail and three earlier shell samples.
  This approximates motion blur on the spell only; it is not screen-space motion blur.

Run from the repository root:

```powershell
& 'C:\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --path godot --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/nova_visual_trials/capture.gd
python godot/tests/nova_visual_trials/package_previews.py
```

The harness freezes the same actor and camera, samples all variants at 0.22,
0.42 and 0.62 seconds, and renders 30 additional frames per variant for animation.
The exported GIF is slowed down to make the visual differences easier to inspect.
Screenshots are actual engine renders; the contact sheet only crops, scales and labels them.

Validation: all 99 captures rendered successfully with the Compatibility renderer;
no shader compilation errors. The process reports one resource still in use and
an ObjectDB cleanup warning on exit. Performance in the full world is not measured.

The preview pack is under `screenshots/Nova_variantes_20261030` at repository root.

## Generated-alpha follow-up

Run `capture_textured.gd` with the same Godot command to compare the original,
the single textured layer, and the final three-layer rotating effect with aura.
Then run `capture_world.gd` to capture the integrated spell in the actual world.
Package with `python godot/tests/nova_visual_trials/package_textured.py`.
The new pack is in `screenshots/Nova_texture_alpha_20261030`.
Generation prompt and alpha validation: `res://assets/vfx/nova/generation.md`.

Validation: 108 preview frames rendered in Compatibility with no errors;
the existing `test_primordial_nova.gd` gameplay suite reports 0 failures.
That broader world suite reports ObjectDB/resource cleanup messages on exit.

## Vertical layers and filming stage

The production effect now has three separate heights and independent layer
delays/expansion times. See `Nova - tournage.md` at repository root for the
filming scene, launcher and keyboard controls. The stage directly instantiates
the production spell; no scene-specific substitute shader is used.

`capture_showcase.gd` validates tier heights, relative expansion, manual casting,
autoplay and orbit, and exports 1080p screenshots plus 34 animation frames.
`package_showcase.py` packages them under `screenshots/Nova_couches_verticales_20261030`.
The final showcase capture completes with no errors or warnings.
