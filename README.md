# Umbral Shaders

Umbral Shaders is a shader pack for Minecraft Java Edition and Iris. It adds soft solar shadows, colored light from blocks and stained glass, and diffuse lighting that carries color around a room. The project was previously called Vanilla Shadows.

[Download Umbral Shaders v0.12.1](https://github.com/Salakorte/UmbralShaders/releases/tag/v0.12.1)

## Features

- Solar shadows with adjustable distance, resolution, and edge softness.
- Colored block lights and stained-glass transmission. A soul lantern casts blue light, and stained glass filters sunlight and light from nearby emitters.
- Diffuse global illumination using nearby voxel geometry and the visible scene. Temporal filtering smooths the lighting as the camera moves.
- Optional screen-space reflections on water and glass.
- Optional Distant Horizons integration for distant terrain and water.

## Installation

1. Install Iris for your version of Minecraft Java Edition. The tested setup for this release uses **Minecraft 26.1.2, Fabric, Iris 1.10.9, and Sodium 0.8.12**. [Iris downloads](https://irisshaders.dev/download/)
2. In Minecraft, open **Video Settings → Shader Packs → Open Shader Pack Folder**.
3. Place `UmbralShaders-v0.12.1.zip` in that folder without extracting it. Pick the file under **Assets** on the release page.
4. Select the pack and choose **Photorealistic lighting** in its shader pack settings to enable global illumination, shadowed block lights, and stained-glass transmission. Reflections are separate options under **Lighting**.

To uninstall, disable the pack in Iris and remove its ZIP from the shader pack folder.

## Compatibility and troubleshooting

The advanced lighting options use compute shaders and custom images in Iris and can increase GPU cost. If frame rate drops, reduce **Ray tracing quality** or disable effects individually. For shader-loading errors, check the game's `logs/latest.log` and include the error along with your Minecraft, Iris, Sodium, and GPU versions when reporting it.

The release was also tested with **Distant Horizons 3.0.3-b** using its **OpenGL** renderer. The local voxel lighting runs in the Overworld, and screen-space reflections depend on what the camera can see. See the [compatibility notes](docs/COMPATIBILITY.md) and [validation results](docs/VALIDATION.md).

## Development

Use Python 3.10 or later to validate and package a checkout:

```sh
python tools/validate.py
python tools/package.py
```

Driver compilation uses a Windows OpenGL context. `python tools/validate.py --static-only` checks the shader files and includes when an OpenGL validation context is unavailable. The packager writes the installable ZIP and its SHA-256 checksum to `dist/`. [Rendering architecture](docs/ARCHITECTURE.md) · [Changelog](CHANGELOG.md)

## Credits

Umbral Shaders uses the Iris shader pack API. The lighting draws on published work on area lights and temporal filtering, and on the architecture of Sonic Ether's SEUS PTGI as a reference. [Iris](https://irisshaders.dev/) · [PBRT](https://pbr-book.org/4ed/Light_Sources/Area_Lights) · [SVGF](https://research.nvidia.com/publication/2017-07_spatiotemporal-variance-guided-filtering-real-time-reconstruction-path-traced) · [SEUS](https://www.sonicether.com/seus/)

Released under the [MIT License](LICENSE).
