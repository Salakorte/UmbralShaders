# Rendering architecture

## Solar shadows

Iris renders the shadow map from the current sunlight direction. The receiver projects into that map and compares depth at the sampled texel's center. The photorealistic style estimates penumbra width from the distance between blockers and receivers. The shadow map reserves more resolution near the camera at long shadow distances.

## Local lighting

The shadow pass records nearby geometry, stained glass, and light emitters in a camera-local 64³ voxel volume. Compute passes group emitters and sky-facing windows into 16³ tiles. Rays traverse the grid to determine visibility, and each stained-glass cell multiplies the transmitted light by its linear RGB transmittance. Multiple samples across each source approximate area lighting and soften the edges of shadows.

The terrain pass discounts the portion of the lightmap represented by the traced sources. It stores the remaining scene color at 16-bit floating-point precision and the additional irradiance separately from the block texture. The deferred passes combine voxel and screen-space lighting, filter it using surface position and normal, and reproject the previous frame's lighting. Reprojection rejects mismatched surfaces and reduces history weight after a strong lighting change.

## Reflections

The last deferred pass copies the resolved opaque scene into a buffer used by the translucent water and glass programs. Reflection rays sample the visible scene against its depth buffer, with their contribution fading near the edges of the screen.

## References

- [Iris shader pack documentation](https://shaders.properties/current/)
- [Area lights, Physically Based Rendering](https://pbr-book.org/4ed/Light_Sources/Area_Lights)
- [Spatiotemporal Variance-Guided Filtering, Schied et al.](https://research.nvidia.com/publication/2017-07_spatiotemporal-variance-guided-filtering-real-time-reconstruction-path-traced)
