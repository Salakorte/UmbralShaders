#include "/lib/settings.glsl"
uniform sampler2D colortex0;
varying vec2 vsScreenUV;

#define VS_RAY_DEPTH depthtex0
#include "/lib/screen_ray.glsl"
#include "/lib/lighting_surface.glsl"

#ifdef RAY_TRACED_GI
#include "/lib/lighting_samples.glsl"
#if defined(VS_TERRAIN_IRRADIANCE) && defined(RT_GLASS_TRANSMISSION)
#include "/lib/voxel_transmission.glsl"
uniform mat4 gbufferModelViewInverse;
#endif
#if GI_QUALITY == 0
const int giRays = 6;
const int giSteps = 9;
#elif GI_QUALITY == 2
const int giRays = 16;
const int giSteps = 15;
#else
const int giRays = 10;
const int giSteps = 12;
#endif
const float giRange = 7.0;

vec3 giTraceBounce(vec3 origin, vec3 direction) {
    vec2 uv;
    vec3 surface;
    float travel;
    if (!traceScreenRay(origin, direction, giRange, giSteps, uv, surface, travel)) return vec3(0.0);

    vec3 normal;
#ifdef VS_TERRAIN_IRRADIANCE
    ivec2 pixel = ivec2(uv * vec2(textureSize(depthtex0, 0)));
    bool terrain = terrainSurface(pixel, surface, normal);
    if (!terrain) normal = raySurfaceNormal(uv, surface);
#else
    normal = raySurfaceNormal(uv, surface);
#endif
    float facing = max(dot(normal, -direction), 0.0);
    float distanceFalloff = (1.0 - smoothstep(giRange * 0.55, giRange, travel))
                          / (1.0 + 0.45 * travel);
    vec3 radiance = pow(max(textureLod(colortex0, uv, 0.0).rgb, vec3(0.0)), vec3(2.2));
#ifdef VS_TERRAIN_IRRADIANCE
    if (terrain) {
        vec4 material = texelFetch(colortex1, pixel, 0);
        vec3 albedo = pow(material.rgb, vec3(2.2));
        radiance += albedo * texelFetch(colortex6, pixel, 0).rgb * material.a;
#ifdef RT_GLASS_TRANSMISSION
        // The screen depth is opaque. Recheck the segment in the voxel grid so
        // a source behind a pane contributes transmitted light to the bounce.
        vec3 start = voxelPoint((gbufferModelViewInverse * vec4(origin, 1.0)).xyz);
        vec3 end = voxelPoint((gbufferModelViewInverse * vec4(surface, 1.0)).xyz);
        if (insideVoxelGrid(ivec3(floor(start))) && insideVoxelGrid(ivec3(floor(end)))) {
            radiance *= traceVoxelTransmission(start, end);
        }
#endif
    }
#endif
    return radiance * facing * distanceFalloff * rayScreenCoverage(uv);
}

vec3 giIndirect(vec3 center, vec3 normal) {
    vec3 reference = abs(normal.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(reference, normal));
    vec3 bitangent = cross(normal, tangent);
    vec3 bounce = vec3(0.0);
    vec3 origin = center + normal * 0.07;
    float phase = lightingPhase();
    for (int i = 0; i < giRays; ++i) {
        vec2 tap = lightDisk(i, giRays, phase);
        vec3 direction = tangent * tap.x + bitangent * tap.y + normal * sqrt(1.0 - dot(tap, tap));
        bounce += giTraceBounce(origin, direction);
    }
    return bounce / float(giRays);
}
#endif

// These formats are directives read by Iris, so keep them inside the comment.
/*
const int colortex0Format = RGBA16F;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
const bool colortex2Clear = false;
const bool colortex3Clear = false;
*/
/* DRAWBUFFERS:4 */
void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(depthtex0, 0);
    vec3 center;
    vec3 normal;
    bool terrain;
    vec3 light = vec3(0.0);
    if (lightingSurface(pixel, size, center, normal, terrain)) {
#ifdef VS_TERRAIN_IRRADIANCE
        if (terrain) light = texelFetch(colortex6, pixel, 0).rgb;
#endif
#ifdef RAY_TRACED_GI
        float fade = 1.0 - smoothstep(26.0, 54.0, length(center));
        if (fade > 0.0) {
            float screenWeight = terrain ? mix(0.34, 0.85, smoothstep(17.0, 32.0, length(center))) : 0.85;
            light += giIndirect(center, normal) * (1.8 * GI_INTENSITY * fade * screenWeight);
        }
#endif
    }
    gl_FragData[0] = vec4(light, 1.0);
}
