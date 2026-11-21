#define VS_RAY_DEPTH depthtex1
#include "/lib/screen_ray.glsl"
// Gbuffers cannot read colortex0-3. Slot 5 is the opaque scene copied by deferred2.
uniform sampler2D colortex5;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform float frameTimeCounter;
flat in int vsMaterial;
varying vec3 vsReflectionNormal;

vec3 waterReflectionNormal(vec3 normal) {
    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;
    if (worldNormal.y < 0.65) return normal;
    vec2 position = vsFogPosition.xz + cameraPosition.xz;
    float along = sin(dot(position, vec2(2.2, 1.4)) + frameTimeCounter * 2.1);
    float across = sin(dot(position, vec2(-1.1, 2.7)) - frameTimeCounter * 1.6);
    worldNormal.xz += 0.038 * vec2(along + across * 0.35, across + along * 0.35);
    return normalize(mat3(gbufferModelView) * worldNormal);
}

vec4 applyRayReflection(vec4 base) {
    bool water = false;
    bool glass = false;
#ifdef RT_WATER_REFLECTIONS
    water = vsMaterial == 1001;
#endif
#ifdef RT_GLASS_REFLECTIONS
    glass = vsMaterial == 1002 || vsMaterial == 1003 || (vsMaterial >= 1101 && vsMaterial <= 1116);
#endif
    if (!water && !glass) return base;

    float surfaceDistance = length(vsViewPosition);
    float distanceFade = 1.0 - smoothstep(55.0, 100.0, surfaceDistance);
    float normalLength = length(vsReflectionNormal);
    if (surfaceDistance < 0.05 || distanceFade <= 0.0 || normalLength < 0.01) return base;
    vec3 view = -vsViewPosition / surfaceDistance;
    vec3 normal = vsReflectionNormal / normalLength;
    if (dot(normal, view) < 0.0) normal = -normal;
    if (water) normal = waterReflectionNormal(normal);

    vec3 direction = reflect(-view, normal);
    vec2 uv;
    vec3 surface;
    float travel;
    float confidence = 0.0;
    vec3 reflected = vec3(0.0);
    if (traceScreenRay(vsViewPosition + normal * 0.07, direction, 38.0, 26, uv, surface, travel)) {
        vec3 hitNormal = raySurfaceNormal(uv, surface);
        float facing = smoothstep(0.08, 0.38, dot(hitNormal, -direction));
        confidence = rayScreenCoverage(uv) * facing * (1.0 - smoothstep(25.0, 38.0, travel));
        reflected = textureLod(colortex5, uv, 0.0).rgb;
    }
    // At screen edges and on misses, outdoor surfaces can still reflect the
    // sky tint. No sky fallback underground where skylight is absent.
    vec3 worldRay = mat3(gbufferModelViewInverse) * direction;
    float sky = smoothstep(0.58, 0.95, vsLightUV.y) * smoothstep(-0.06, 0.28, worldRay.y);
    float available = mix(0.55 * sky, 1.0, confidence);
    if (available <= 0.0) return base;
    vec3 skyReflection = mix(fogColor, skyColor, smoothstep(0.0, 0.60, worldRay.y));
    reflected = mix(skyReflection, reflected, confidence);

    float grazing = 1.0 - clamp(dot(normal, view), 0.0, 1.0);
    float normalReflectance = water ? 0.035 : 0.068;
    float fresnel = normalReflectance + (1.0 - normalReflectance) * pow(grazing, 4.0);
    float cap = glass ? 0.37 : 0.86;
    float reflection = min(fresnel * RT_REFLECTION_STRENGTH, cap) * available * distanceFade;
    float baseWeight = base.a * (1.0 - reflection);
    float alpha = baseWeight + reflection;
    vec3 baseLinear = pow(clamp(base.rgb, 0.0, 1.0), vec3(2.2));
    vec3 reflectionLinear = pow(clamp(reflected, 0.0, 1.0), vec3(2.2));
    vec3 color = (baseLinear * baseWeight + reflectionLinear * reflection) / max(alpha, 0.0001);
    return vec4(pow(color, vec3(1.0 / 2.2)), alpha);
}
