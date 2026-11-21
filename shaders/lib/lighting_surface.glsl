#ifdef VS_TERRAIN_IRRADIANCE
uniform sampler2D colortex1;
uniform sampler2D colortex6;
uniform sampler2D colortex7;

bool terrainSurface(ivec2 pixel, vec3 viewPosition, out vec3 normal) {
    vec4 surface = texelFetch(colortex7, pixel, 0);
    normal = surface.xyz;
    // Another opaque draw may have landed in front of the recorded terrain.
    return surface.w > 0.0 && abs(surface.w + viewPosition.z) < max(0.0025, surface.w * 0.0011);
}
#endif

bool lightingSurface(ivec2 pixel, ivec2 size, out vec3 position, out vec3 normal, out bool terrain) {
    float depth = texelFetch(depthtex0, pixel, 0).r;
    terrain = false;
    if (depth >= 1.0) return false;
    vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
    position = rayViewPosition(uv, depth);
#ifdef VS_TERRAIN_IRRADIANCE
    terrain = terrainSurface(pixel, position, normal);
    if (terrain) return true;
#endif
    normal = raySurfaceNormal(uv, position);
    return dot(normal, normal) > 0.5;
}
