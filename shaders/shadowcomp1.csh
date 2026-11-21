#version 430
#include "/lib/settings.glsl"
layout(local_size_x = 1) in;
const ivec3 workGroups = ivec3(4, 4, 4);
#if defined(RT_BLOCK_LIGHTS) || defined(RT_GLASS_TRANSMISSION)
#include "/lib/voxel_coordinates.glsl"
uniform usampler3D vsVoxelRead;
#endif
#ifdef RT_BLOCK_LIGHTS
layout(r32ui) uniform writeonly uimage2D vsEmitters;
#endif
#ifdef RT_GLASS_TRANSMISSION
#include "/lib/voxel_ray.glsl"
layout(r32ui) uniform writeonly uimage2D vsWindows;

bool windowProbe(vec3 start, vec3 direction) {
    VoxelRay ray = beginVoxelRay(start, direction);
    for (int i = 0; i < 32; ++i) {
        if (!insideVoxelGrid(ray.cell)) return true;
        if (voxelSolid(texelFetch(vsVoxelRead, ray.cell, 0).r)) return false;
        if (advanceVoxelRay(ray) >= 20.0) return true;
    }
    return false;
}

uint exteriorFaces(vec3 center) {
    uint mask = 0u;
    for (int face = 0; face < 5; ++face) {
        vec3 normal = windowNormal[face];
        vec3 start = center + normal * 0.53;
        vec3 slope = normalize(normal + vec3(0.0, 0.78, 0.0));
        if (windowProbe(start, slope)) mask |= 1u << uint(face);
    }
    return mask;
}
#endif

void main() {
#if defined(RT_BLOCK_LIGHTS) || defined(RT_GLASS_TRANSMISSION)
    ivec3 tile = ivec3(gl_GlobalInvocationID);
    int row = voxelTileRow(tile);
    ivec3 base = tile * voxelTileSize;
#ifdef RT_BLOCK_LIGHTS
    int emitters = 0;
#endif
#ifdef RT_GLASS_TRANSMISSION
    int windows = 0;
#endif
    // Each spatial tile has its own budget and fixed traversal order.
    for (int i = 0; i < voxelTileSize * voxelTileSize * voxelTileSize; ++i) {
#if defined(RT_BLOCK_LIGHTS) && defined(RT_GLASS_TRANSMISSION)
        if (emitters == emitterCapacity && windows == windowCapacity) break;
#elif defined(RT_BLOCK_LIGHTS)
        if (emitters == emitterCapacity) break;
#else
        if (windows == windowCapacity) break;
#endif
        ivec3 cell = base + ivec3(i & 15, (i >> 4) & 15, i >> 8);
        uint material = texelFetch(vsVoxelRead, cell, 0).r;
        uint position = uint(cell.x) | (uint(cell.y) << 6u) | (uint(cell.z) << 12u);
#ifdef RT_BLOCK_LIGHTS
        if (material >= emitterMarker && emitters < emitterCapacity) {
            uint payload = position | ((material & 15u) << 18u) | (((material >> 4u) & 15u) << 22u);
            imageStore(vsEmitters, ivec2(++emitters, row), uvec4(payload));
        }
#endif
#ifdef RT_GLASS_TRANSMISSION
        if (material >= 3u && material <= 18u && windows < windowCapacity) {
            uint mask = exteriorFaces(vec3(cell) + 0.5);
            if (mask != 0u) {
                uint payload = position | ((material - 3u) << 18u) | (mask << 22u);
                imageStore(vsWindows, ivec2(++windows, row), uvec4(payload));
            }
        }
#endif
    }
#ifdef RT_BLOCK_LIGHTS
    imageStore(vsEmitters, ivec2(0, row), uvec4(uint(emitters)));
#endif
#ifdef RT_GLASS_TRANSMISSION
    imageStore(vsWindows, ivec2(0, row), uvec4(uint(windows)));
#endif
#endif
}
