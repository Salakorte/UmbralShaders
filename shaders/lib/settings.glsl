#ifndef VS_SETTINGS
#define VS_SETTINGS

#define SHADOWS_ENABLED // Solar shadows. Applying settings reloads the pack.
//#define DH_CAST_SHADOWS // Let Distant Horizons LODs cast distant shadows.
//#define RAY_TRACED_GI // Trace diffuse light using nearby voxels and the camera depth buffer.
#define GI_QUALITY 1 // [0 1 2]
#define GI_INTENSITY 1.50 // [0.25 0.50 0.75 1.00 1.50 2.00 3.00]
//#define RT_WATER_REFLECTIONS // Trace specular reflections on water.
//#define RT_GLASS_REFLECTIONS // Trace specular reflections on glass.
//#define RT_BLOCK_LIGHTS // Trace colored block lights through a local voxel grid.
//#define RT_GLASS_TRANSMISSION // Filter light passing through stained glass.
#define RT_REFLECTION_STRENGTH 1.50 // [0.50 1.00 1.50 2.00]
#if defined(RT_BLOCK_LIGHTS) || defined(RT_GLASS_TRANSMISSION) || defined(RAY_TRACED_GI)
#define VS_VOXEL_LIGHTING
#endif
#if defined(VS_WORLD_DIFFUSE) && defined(VS_VOXEL_LIGHTING)
#define VS_TERRAIN_IRRADIANCE
#endif
const float voxelDistance = 32.0;
#define SHADOW_STYLE 0 // [0 1]
#define SHADOW_INTENSITY 0.35 // [0.0 0.15 0.25 0.35 0.45 0.50]
#define SHADOW_SOFTNESS 1 // [0 1 2] 0: one tap, 1: 3x3 PCF, 2: wider 3x3 PCF.
// Use Iris-recognized literal constants: these configure the actual renderer,
// not merely a sampling radius in our GLSL. Labels expose the requested names.
const float shadowDistance = 96.0; // [1.0 2.0 4.0 8.0 12.0 16.0 24.0 32.0 48.0 64.0 80.0 96.0 112.0 128.0 160.0 192.0 224.0 256.0 320.0 384.0 512.0 640.0 768.0 1024.0 1280.0 1536.0 1792.0 2048.0]
// Leave room for offscreen casters and for the sun's depth axis at low angles.
const float shadowDistanceRenderMul = 2.0;
const float shadowNearPlane = -2304.0;
const float shadowFarPlane = 2304.0;
const int shadowMapResolution = 2048; // [1024 2048 4096]
const float shadowIntervalSize = 2.0;
const bool shadowHardwareFiltering = false;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
#endif
