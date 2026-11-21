# Compatibility

| Configuration | Status |
| --- | --- |
| Minecraft Java 26.1.2, Fabric, Iris 1.10.9, Sodium 0.8.12 | Tested in the Overworld |
| Distant Horizons 3.0.3-b with the OpenGL renderer on that setup | Tested in the lighting scenes |
| Minecraft Java 26.3 with Iris 1.11.7 | Original compatibility target; runtime testing pending for this release |

The pack uses Iris's GLSL compatibility path. The local lighting features additionally require compute shaders and custom images. Global illumination and block-light performance depend on the GPU, resolution, scene, and selected quality.

The Overworld runs solar shadows and voxel lighting. Nether and End use a separate program set without solar shadows. Distant Horizons terrain can receive shadows within the set shadow distance. Casting shadows from distant terrain is experimental and disabled by default.

The voxel grid approximates partial blocks and has a limited radius. Water and glass reflections rely on visible geometry. Testing at the maximum shadow distance and with other rendering mods remains pending.

[Iris compatibility profiles](https://shaders.properties/current/how-to/compatibility_vs_core/) · [Distant Horizons integration in Iris](https://shaders.properties/current/reference/mod-support/distant_horizons/)
