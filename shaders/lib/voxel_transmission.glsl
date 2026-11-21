#include "/lib/voxel_coordinates.glsl"
#include "/lib/voxel_ray.glsl"
uniform usampler3D vsVoxelRead;

#ifdef RT_GLASS_TRANSMISSION
// RGB transmittance in linear light, in Minecraft's dye order.
const vec3 glassTransmission[16] = vec3[16](
    vec3(0.840,0.840,0.840), vec3(0.871,0.169,0.015), vec3(0.664,0.039,0.582), vec3(0.070,0.479,0.887),
    vec3(0.935,0.678,0.019), vec3(0.373,0.856,0.030), vec3(0.919,0.248,0.529), vec3(0.161,0.185,0.211),
    vec3(0.442,0.467,0.491), vec3(0.022,0.504,0.595), vec3(0.340,0.049,0.706), vec3(0.022,0.108,0.871),
    vec3(0.373,0.145,0.044), vec3(0.039,0.467,0.076), vec3(0.871,0.022,0.015), vec3(0.030,0.030,0.039)
);
#endif

vec3 traceVoxelTransmission(vec3 start, vec3 end) {
    VoxelRay ray = beginVoxelRay(start, end - start);
    ivec3 target = ivec3(floor(end));
    vec3 filterColor = vec3(1.0);
    for (int i = 0; i < 64; ++i) {
        if (all(equal(ray.cell, target))) return filterColor;
        if (!insideVoxelGrid(ray.cell)) return filterColor;
        uint medium = texelFetch(vsVoxelRead, ray.cell, 0).r;
        if (i > 0 && voxelSolid(medium)) return vec3(0.0);
#ifdef RT_GLASS_TRANSMISSION
        if (medium >= 3u && medium <= 18u) filterColor *= glassTransmission[int(medium - 3u)];
#endif
        advanceVoxelRay(ray);
    }
    return vec3(0.0);
}
