uniform usampler2D vsWindowRead;

float windowFacing(vec3 toWindow, uint mask) {
    float facing = 0.0;
    for (int side = 0; side < 5; ++side) {
        if ((mask & (1u << uint(side))) != 0u) {
            facing = max(facing, dot(toWindow, windowNormal[side]));
        }
    }
    return facing;
}

vec3 lightFromWindowTile(ivec3 tile, vec3 start, vec3 normal, float phase) {
    vec3 minimum = vec3(tile * voxelTileSize);
    vec3 closest = clamp(start, minimum, minimum + float(voxelTileSize));
    if (length(start - closest) >= 12.0) return vec3(0.0);
    int row = voxelTileRow(tile);
    int count = int(min(texelFetch(vsWindowRead, ivec2(0, row), 0).r, uint(windowCapacity)));
    vec3 result = vec3(0.0);
    for (int i = 0; i < count; ++i) {
        uint data = texelFetch(vsWindowRead, ivec2(i + 1, row), 0).r;
        vec3 center = vec3(data & 63u, (data >> 6u) & 63u, (data >> 12u) & 63u) + 0.5;
        vec3 delta = center - start;
        float distanceSquared = dot(delta, delta);
        if (distanceSquared >= 144.0 || distanceSquared < 0.0001) continue;
        float distanceToWindow = sqrt(distanceSquared);
        vec3 direction = delta / distanceToWindow;
        const float radius = 0.46;
        if (dot(delta, normal) <= -radius) continue;
        vec3 tangent = lightTangent(direction);
        vec3 across = cross(direction, tangent);
        vec3 energy = vec3(0.0);
#if GI_QUALITY == 0
        const int samples = 3;
#elif GI_QUALITY == 2
        const int samples = 8;
#else
        const int samples = 5;
#endif
        for (int j = 0; j < samples; ++j) {
            vec2 tap = lightDisk(j, samples, phase) * radius;
            vec3 point = center + tangent * tap.x + across * tap.y;
            vec3 incident = normalize(point - start);
            float weight = windowFacing(incident, data >> 22u) * max(dot(incident, normal), 0.0);
            if (weight > 0.0) energy += traceVoxelTransmission(start, point) * weight;
        }
        vec3 glass = glassTransmission[int((data >> 18u) & 15u)];
        float falloff = (1.0 - smoothstep(7.5, 12.0, distanceToWindow)) / (1.2 + 0.22 * distanceSquared);
        result += glass * energy * (falloff / float(samples));
    }
    return result;
}

vec3 windowIrradiance(vec3 start, vec3 normal, float phase) {
    ivec3 low = clamp(ivec3(floor((start - 12.0) / float(voxelTileSize))), ivec3(0), ivec3(voxelTileCount - 1));
    ivec3 high = clamp(ivec3(floor((start + 12.0) / float(voxelTileSize))), ivec3(0), ivec3(voxelTileCount - 1));
    vec3 light = vec3(0.0);
    for (int z = low.z; z <= high.z; ++z) {
        for (int y = low.y; y <= high.y; ++y) {
            for (int x = low.x; x <= high.x; ++x) {
                light += lightFromWindowTile(ivec3(x, y, z), start, normal, phase);
            }
        }
    }
    return light;
}

float neutralSkyVisibility(vec3 start, vec3 normal, float phase) {
    const int samples = 8;
    float sum = 0.0;
    float totalWeight = 0.0;
    for (int i = 0; i < samples; ++i) {
        vec2 disk = lightDisk(i, samples, phase);
        vec3 direction = vec3(disk.x, sqrt(1.0 - dot(disk, disk)), disk.y);
        float weight = 0.16 + max(dot(normal, direction), 0.0);
        vec3 filterColor = traceVoxelTransmission(start, start + direction * 20.0);
        sum += weight * smoothstep(0.68, 1.0, min(filterColor.r, min(filterColor.g, filterColor.b)));
        totalWeight += weight;
    }
    return sum / totalWeight;
}

vec3 transmittedSun(vec3 start, vec3 normal, vec3 sun, float phase) {
    if (dot(normal, sun) < -0.1) return vec3(0.0);
    vec3 tangent = lightTangent(sun);
    vec3 across = cross(sun, tangent);
    const int samples = 8;
    float radius = 0.040 + 0.013 * float(SHADOW_SOFTNESS);
    vec3 sum = vec3(0.0);
    for (int i = 0; i < samples; ++i) {
        vec2 tap = lightDisk(i, samples, phase) * radius;
        vec3 direction = normalize(sun + tangent * tap.x + across * tap.y);
        float cosine = max(dot(normal, direction), 0.0);
        if (cosine > 0.0) sum += traceVoxelTransmission(start, start + direction * 24.0) * cosine;
    }
    return sum / float(samples);
}
