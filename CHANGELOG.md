# Changelog

## 0.12.1

- First GitHub release under the name Umbral Shaders.
- Fixed colored banding in dark interiors by keeping scene color at higher precision and adding indirect irradiance separately from the base light.
- Reduced the white light leaking around stained-glass transmission. The screen-space bounce also tests its light path against the local voxel geometry.

## 0.12

- Added the Photorealistic lighting preset and softer area lighting for block emitters, windows, and the sun.
- Added spatial and temporal filtering guided by surface depth and normals so overlapping colors blend more smoothly.

## 0.10–0.11

- Added voxel-based color bounce from painted blocks and indirect skylight from stained glass.
- Grouped nearby light sources into world-aligned tiles for stable selection.

## 0.7–0.9.1

- Added diffuse global illumination, colored block lights, and water and glass reflections.
- Corrected reflection sampling and fixed an Iris shader compilation error.

## 0.1–0.6.1

- Added solar shadows and selectable filtering, with distance control up to 2,048 blocks.
- Added optional Distant Horizons terrain and water support and fixed distant water rendering in front of nearby geometry.
