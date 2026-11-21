# Validation

## v0.12.1

The shader pack ran in Minecraft Java 26.1.2, Fabric, Iris 1.10.9, and Sodium 0.8.12. The same scenes also ran with Distant Horizons 3.0.3-b using its OpenGL renderer.

- **Dark hallway.** A side-by-side comparison reproduced colored bands in v0.12. They were no longer visible in the corresponding v0.12.1 capture.
- **Stained-glass transmission.** A sea lantern lit a quartz wall through a red pane. On the wall, the mean captured RGB changed from (53, 37, 29) in v0.12 to (40, 19, 18) in v0.12.1. Replacing the pane with clear glass yielded (42, 52, 53).
- **Driver checks.** 2,320 graphics program variants and two compute programs compiled and linked on an NVIDIA RTX 3080 with OpenGL 4.6. The automated result is included in the ZIP as `validation.json`.

Earlier in-game tests compared a sea lantern and a multicolored window room. They confirmed that area sampling and the lighting filter softened visible edges under the tested settings. The v0.12.1 tests cover the scenes above. Frame rate and other device configurations remain unmeasured.

Test map reference by Jikali. [Ray Tracing Testing Place](https://www.curseforge.com/minecraft/worlds/ray-tracing-testing-place)
