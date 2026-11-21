#include "/lib/settings.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

#define VS_RAY_DEPTH depthtex0
#include "/lib/screen_ray.glsl"
#include "/lib/lighting_surface.glsl"

vec3 spatialLight(ivec2 pixel, ivec2 size, vec3 center, vec3 normal, bool terrain) {
    // Sample a footprint in world units, enlarged near camera and capped in pixels.
    float pixelsPerBlock = 0.5 * float(size.y) * gbufferProjection[1][1] / max(-center.z, 0.25);
    int stepSize = int(clamp(0.16 * pixelsPerBlock + 0.5, 1.0, 24.0));
    vec3 sum = texelFetch(colortex4, pixel, 0).rgb;
    float weightSum = 1.0;
    for (int y = -2; y <= 2; ++y) {
        for (int x = -2; x <= 2; ++x) {
            if (x == 0 && y == 0) continue;
            ivec2 tap = pixel + ivec2(x, y) * stepSize;
            if (any(lessThan(tap, ivec2(0))) || any(greaterThanEqual(tap, size))) continue;
            float depth = texelFetch(depthtex0, tap, 0).r;
            if (depth >= 1.0) continue;
            vec2 uv = (vec2(tap) + 0.5) / vec2(size);
            vec3 position = rayViewPosition(uv, depth);
            vec3 delta = position - center;
            float planeWeight = 1.0 - smoothstep(0.025, 0.091, abs(dot(normal, delta)));
            float rangeWeight = 1.0 - smoothstep(0.25, 0.83, length(delta));
            float weight = planeWeight * rangeWeight;
            if (weight <= 0.0) continue;
#ifdef VS_TERRAIN_IRRADIANCE
            vec3 tapNormal;
            bool tapTerrain = terrainSurface(tap, position, tapNormal);
            if (terrain != tapTerrain) continue;
            if (terrain) weight *= smoothstep(0.83, 0.98, dot(normal, tapNormal));
#endif
            weight *= exp(-0.36 * float(x * x + y * y));
            sum += texelFetch(colortex4, tap, 0).rgb * weight;
            weightSum += weight;
        }
    }
    return sum / weightSum;
}

vec3 temporalLight(vec3 current, vec3 center, vec3 worldNormal, ivec2 size) {
    vec3 motion = cameraPosition - previousCameraPosition;
    if (dot(motion, motion) > 9.0) return current;
    vec3 scenePoint = (gbufferModelViewInverse * vec4(center, 1.0)).xyz;
    vec4 previousView = gbufferPreviousModelView * vec4(scenePoint + motion, 1.0);
    vec4 clip = gbufferPreviousProjection * previousView;
    if (clip.w <= 0.0) return current;
    vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return current;

    vec2 samplePosition = uv * vec2(size) - 0.5;
    ivec2 low = ivec2(floor(samplePosition));
    vec2 fraction = fract(samplePosition);
    float tolerance = max(0.023, -previousView.z * 0.005);
    vec3 history = vec3(0.0);
    float confidence = 0.0;
    for (int y = 0; y <= 1; ++y) {
        for (int x = 0; x <= 1; ++x) {
            ivec2 pixel = low + ivec2(x, y);
            if (any(lessThan(pixel, ivec2(0))) || any(greaterThanEqual(pixel, size))) continue;
            vec4 prior = texelFetch(colortex3, pixel, 0);
            if (prior.w <= 0.0 || abs(prior.w + previousView.z) > tolerance) continue;
            if (dot(prior.xyz, worldNormal) < 0.96) continue;
            vec2 axisWeight = mix(1.0 - fraction, fraction, bvec2(x != 0, y != 0));
            float weight = axisWeight.x * axisWeight.y;
            history += texelFetch(colortex2, pixel, 0).rgb * weight;
            confidence += weight;
        }
    }
    if (confidence < 0.25) return current;
    history /= confidence;
    vec3 change = abs(history - current);
    float difference = max(change.r, max(change.g, change.b));
    // React immediately to strong changes when a light or an occluder moves.
    float persistence = 0.76 * confidence * (1.0 - smoothstep(0.025, 0.16, difference));
    return mix(current, history, persistence);
}

/* DRAWBUFFERS:023 */
void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(depthtex0, 0);
    vec4 base = texelFetch(colortex0, pixel, 0);
    gl_FragData[1] = vec4(0.0);
    gl_FragData[2] = vec4(0.0);

    vec3 center;
    vec3 normal;
    bool terrain;
    if (lightingSurface(pixel, size, center, normal, terrain) && length(center) < 55.0) {
        vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * normal);
        vec3 light = spatialLight(pixel, size, center, normal, terrain);
        light = temporalLight(light, center, worldNormal, size);
        vec3 linear = pow(clamp(base.rgb, 0.0, 1.0), vec3(2.2));
        vec3 response = mix(vec3(0.08), linear, 0.65);
#ifdef VS_TERRAIN_IRRADIANCE
        if (terrain) {
            vec4 material = texelFetch(colortex1, pixel, 0);
            response = pow(material.rgb, vec3(2.2)) * material.a;
        }
#endif
        vec3 combined = linear + response * light;
        base.rgb = pow(clamp(combined, 0.0, 1.0), vec3(1.0 / 2.2));
        gl_FragData[1] = vec4(light, 1.0);
        gl_FragData[2] = vec4(worldNormal, -center.z);
    }
    gl_FragData[0] = base;
}
