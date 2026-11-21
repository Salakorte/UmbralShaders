const vec3 diffuseAlbedo[16] = vec3[16](
    vec3(0.82,0.82,0.82), vec3(0.85,0.28,0.04), vec3(0.65,0.09,0.55), vec3(0.10,0.45,0.83),
    vec3(0.82,0.68,0.04), vec3(0.38,0.73,0.06), vec3(0.85,0.30,0.53), vec3(0.14,0.16,0.18),
    vec3(0.45,0.47,0.49), vec3(0.04,0.46,0.54), vec3(0.36,0.07,0.59), vec3(0.04,0.13,0.78),
    vec3(0.37,0.18,0.07), vec3(0.07,0.45,0.10), vec3(0.78,0.045,0.025), vec3(0.032,0.032,0.036)
);

vec3 diffuseSunAt(vec3 point, vec3 normal, vec3 sun, float phase) {
    vec2 sunTap = lightDisk(0, 1, phase) * 0.055;
    vec3 sunTangent = lightTangent(sun);
    vec3 solarRay = normalize(sun + sunTangent * sunTap.x + cross(sun, sunTangent) * sunTap.y);
    float cosine = max(dot(normal, solarRay), 0.0);
    vec3 light = vec3(0.0);
    if (cosine > 0.0) light += traceVoxelTransmission(point, point + solarRay * 24.0) * cosine;
    for (int i = 0; i < 3; ++i) {
        vec2 tap = lightDisk(i, 3, phase);
        vec3 direction = vec3(tap.x, sqrt(1.0 - dot(tap, tap)), tap.y);
        float facing = max(dot(normal, direction), 0.0);
        if (facing > 0.0) {
            light += traceVoxelTransmission(point, point + direction * 20.0) * facing * 0.27;
        }
    }
    return light;
}

vec3 traceDiffuseWorld(vec3 start, vec3 direction, vec3 sun, float daylight, float phase) {
    VoxelRay ray = beginVoxelRay(start, direction);
    vec3 throughput = vec3(1.0);
    for (int i = 0; i < 16; ++i) {
        float travel = advanceVoxelRay(ray);
        if (travel > 8.5 || !insideVoxelGrid(ray.cell)) break;
        uint material = texelFetch(vsVoxelRead, ray.cell, 0).r;
#ifdef RT_GLASS_TRANSMISSION
        if (material >= 3u && material <= 18u) throughput *= glassTransmission[int(material - 3u)];
#endif
        float falloff = (1.0 - smoothstep(5.0, 8.5, travel)) / (1.0 + travel * 0.25);
        if (material >= emitterMarker) {
            float level = float((material >> 4u) & 15u) / 15.0;
            return emitterColor[int(material & 15u)] * throughput * falloff * level * 0.48;
        }
        if (voxelSolid(material)) {
            if (travel < 0.12 || daylight <= 0.0) break;
            vec3 point = start + direction * travel + ray.hitNormal * 0.07;
            vec3 albedo = material >= 32u ? diffuseAlbedo[int(material - 32u)] : vec3(0.43);
            vec3 incoming = diffuseSunAt(point, ray.hitNormal, sun, phase);
            return incoming * albedo * throughput * daylight * falloff;
        }
    }
    return vec3(0.0);
}

vec3 voxelDiffuseIrradiance(vec3 start, vec3 normal, vec3 sun, float daylight, float phase) {
    vec3 tangent = lightTangent(normal);
    vec3 bitangent = cross(normal, tangent);
    vec3 bounce = vec3(0.0);
#if GI_QUALITY == 0
    const int rayCount = 6;
#elif GI_QUALITY == 2
    const int rayCount = 14;
#else
    const int rayCount = 10;
#endif
    for (int i = 0; i < rayCount; ++i) {
        vec2 tap = lightDisk(i, rayCount, phase);
        vec3 direction = normal * sqrt(1.0 - dot(tap, tap)) + tangent * tap.x + bitangent * tap.y;
        bounce += traceDiffuseWorld(start, direction, sun, daylight * (1.0 - 0.64 * rainStrength),
                                    fract(phase + float(i) * 0.381966));
    }
    return bounce * (1.18 / float(rayCount));
}
