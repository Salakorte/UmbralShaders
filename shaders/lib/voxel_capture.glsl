#include "/lib/voxel_coordinates.glsl"
in vec4 at_midBlock;
in vec4 mc_Entity;
uniform int renderStage;
uniform mat4 shadowModelViewInverse;
layout(r32ui) uniform uimage3D vsVoxels;

void captureVoxel(vec4 modelVertex) {
    int block = int(mc_Entity.x);
    bool stained = block >= 1101 && block <= 1116;
#ifdef VS_CAPTURE_GLASS
    if (!stained && block != 1003) return;
#else
    bool terrain = renderStage == MC_RENDER_STAGE_TERRAIN_SOLID;
#ifdef MC_RENDER_STAGE_TERRAIN_CUTOUT
    terrain = terrain || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT;
#endif
#ifdef MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
    terrain = terrain || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED;
#endif
    if (!terrain) return;
#endif
    vec3 relativeVertex = (shadowModelViewInverse * gl_ModelViewMatrix * modelVertex).xyz;
    ivec3 cell = ivec3(floor(voxelPoint(relativeVertex + at_midBlock.xyz / 64.0)));
    if (!insideVoxelGrid(cell)) return;

    if (stained || block == 1003) {
#ifdef RT_GLASS_TRANSMISSION
        uint medium = stained ? uint(block - 1098) : 1u;
        imageAtomicMax(vsVoxels, cell, medium);
#endif
        return;
    }
#ifndef VS_CAPTURE_GLASS
    uint level = uint(clamp(at_midBlock.w, 0.0, 15.0));
    if (level == 0u) {
        if (block != 1001 && block != 1002) {
            uint material = block >= 1201 && block <= 1216 ? uint(block - 1169) : 1u;
            imageAtomicMax(vsVoxels, cell, material);
        }
        return;
    }
    uint palette = block >= 1011 && block <= 1019 ? uint(block - 1010) : 0u;
    imageAtomicMax(vsVoxels, cell, emitterMarker | (level << 4u) | palette);
#endif
}
