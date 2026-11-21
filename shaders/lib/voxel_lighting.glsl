#include "/lib/voxel_transmission.glsl"
uniform usampler2D vsEmitterRead;
#include "/lib/lighting_samples.glsl"

vec3 voxelLinear(vec3 color) {
    return pow(clamp(color, 0.0, 1.0), vec3(2.2));
}

const vec3 emitterColor[10] = vec3[10](
    vec3(1.00, 0.78, 0.52), // Unmapped emitters.
    vec3(1.00, 0.65, 0.25), // Glowstone, torches, lanterns.
    vec3(0.16, 0.63, 1.00), // Soul lanterns and soul flame.
    vec3(0.48, 0.86, 1.00), // Sea lanterns, beacons.
    vec3(1.00, 0.09, 0.035), // Redstone torches.
    vec3(0.48, 1.00, 0.24), // Verdant froglight.
    vec3(0.97, 0.45, 0.88), // Pearlescent froglight.
    vec3(1.00, 0.78, 0.27), // Ochre froglight.
    vec3(0.65, 0.26, 1.00), // Crying obsidian.
    vec3(0.87, 0.78, 1.00)  // End rods, amethyst.
);

vec3 lightTangent(vec3 direction) {
    vec3 axis = abs(direction.y) < 0.92 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    return normalize(cross(axis, direction));
}

#ifdef RT_BLOCK_LIGHTS
vec3 areaLightTransmission(vec3 start, vec3 source, vec3 direction, vec3 normal, float radius, float phase) {
    vec3 tangent = lightTangent(direction);
    vec3 across = cross(direction, tangent);
#if GI_QUALITY == 0
    const int samples = 5;
#elif GI_QUALITY == 2
    const int samples = 12;
#else
    const int samples = 8;
#endif
    vec3 energy = vec3(0.0);
    for (int i = 0; i < samples; ++i) {
        vec2 tap = lightDisk(i, samples, phase) * radius;
        vec3 point = source + tangent * tap.x + across * tap.y;
        float facing = max(dot(normalize(point - start), normal), 0.0);
        if (facing > 0.0) energy += traceVoxelTransmission(start, point) * facing;
    }
    return energy / float(samples);
}

void addTileLights(ivec3 tile, vec3 start, vec3 normal, float phase, inout vec3 direct, inout float coverage) {
    vec3 minimum = vec3(tile * voxelTileSize);
    vec3 closest = clamp(start, minimum, minimum + float(voxelTileSize));
    vec3 gap = closest - start;
    if (dot(gap, gap) >= 256.0) return;
    int row = voxelTileRow(tile);
    int count = int(min(texelFetch(vsEmitterRead, ivec2(0, row), 0).r, uint(emitterCapacity)));
    for (int i = 0; i < count; ++i) {
        uint encoded = texelFetch(vsEmitterRead, ivec2(i + 1, row), 0).r;
        vec3 source = vec3(encoded & 63u, (encoded >> 6u) & 63u, (encoded >> 12u) & 63u) + 0.5;
        float level = float((encoded >> 22u) & 15u);
        vec3 delta = source - start;
        float distanceSquared = dot(delta, delta);
        float range = level + 1.0;
        if (distanceSquared >= range * range) continue;
        float distanceToLight = sqrt(distanceSquared);
        coverage = max(coverage, 1.0 - smoothstep(range - 2.0, range, distanceToLight));
        vec3 direction = delta / max(distanceToLight, 0.01);
        float radius = mix(0.20, 0.49, smoothstep(9.0, 15.0, level));
        if (dot(normal, delta) <= -radius) continue;
        vec3 transmission = areaLightTransmission(start, source, direction, normal, radius, phase);
        float attenuation = (1.0 - smoothstep(range * 0.60, range, distanceToLight))
                          / (1.0 + 0.22 * distanceSquared);
        uint palette = (encoded >> 18u) & 15u;
        direct += emitterColor[int(palette)] * transmission * attenuation * (level / 15.0) * 0.74;
    }
}

vec3 voxelBlockIrradiance(vec3 start, vec3 normal, float phase, out float coverage) {
    ivec3 minTile = clamp(ivec3(floor((start - 16.0) / float(voxelTileSize))), ivec3(0), ivec3(voxelTileCount - 1));
    ivec3 maxTile = clamp(ivec3(floor((start + 16.0) / float(voxelTileSize))), ivec3(0), ivec3(voxelTileCount - 1));
    vec3 direct = vec3(0.0);
    coverage = 0.0;
    for (int z = minTile.z; z <= maxTile.z; ++z) {
        for (int y = minTile.y; y <= maxTile.y; ++y) {
            for (int x = minTile.x; x <= maxTile.x; ++x) {
                addTileLights(ivec3(x, y, z), start, normal, phase, direct, coverage);
            }
        }
    }
    return direct;
}
#endif

#ifdef RT_GLASS_TRANSMISSION
#include "/lib/window_lighting.glsl"
#endif
#ifdef RAY_TRACED_GI
#include "/lib/voxel_diffuse.glsl"
#endif

vec3 voxelIrradiance(inout vec3 baseLight, vec3 blockFloor, vec3 skyFloor, vec3 ambientFloor,
                     vec3 playerPosition, vec3 normal) {
    vec3 start = voxelPoint(playerPosition + normal * 0.09);
    vec3 room = min(start, vec3(float(voxelSize)) - start);
    float fade = smoothstep(1.0, 5.0, min(room.x, min(room.y, room.z)))
               * (1.0 - smoothstep(19.0, 31.0, length(playerPosition)));
    ivec3 ownCell = ivec3(floor(start - normal * 0.18));
    if (fade <= 0.0 || !insideVoxelGrid(ownCell)) return vec3(0.0);
    if (texelFetch(vsVoxelRead, ownCell, 0).r >= emitterMarker) return vec3(0.0);

    float phase = lightingPhase();
    vec3 removed = vec3(0.0);
    vec3 incoming = vec3(0.0);
#if defined(RT_GLASS_TRANSMISSION) || defined(RAY_TRACED_GI)
    vec3 sun = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float daylight = smoothstep(-0.05, 0.20, sun.y);
#endif
#ifdef RT_GLASS_TRANSMISSION
    if (daylight > 0.0) {
        float shelter = 1.0 - neutralSkyVisibility(start, normal, phase);
        removed += max(baseLight - blockFloor, vec3(0.0)) * (daylight * shelter);
        if (shelter > 0.0) {
            vec3 filteredSky = windowIrradiance(start, normal, phase) * (0.43 - rainStrength * 0.24);
            vec3 directSun = transmittedSun(start, normal, sun, phase) * (0.58 * (1.0 - rainStrength));
            incoming += (filteredSky + directSun) * daylight * shelter;
        }
    }
#endif
#ifdef RT_BLOCK_LIGHTS
    float coverage;
    incoming += voxelBlockIrradiance(start, normal, phase, coverage);
    removed += max(baseLight - skyFloor, vec3(0.0)) * coverage;
#endif
#ifdef RAY_TRACED_GI
    incoming += voxelDiffuseIrradiance(start, normal, sun, daylight, phase) * GI_INTENSITY;
#endif
    // Preserve chromaticity when the combined luminance approaches display white.
    float peak = max(incoming.r, max(incoming.g, incoming.b));
    // Remove legacy light before storing scene color so the resolve pass only adds energy.
    baseLight -= min(removed * fade, max(baseLight - ambientFloor, vec3(0.0)));
    return (1.0 - baseLight) * incoming * (fade / (1.0 + peak));
}
