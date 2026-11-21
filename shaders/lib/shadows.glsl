uniform sampler2D shadowtex1;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;

#ifdef SHADOWS_ENABLED
#include "/lib/shadow_projection.glsl"

// Compare at the center of the actual depth texel, including when a filter
// sample lands off center. On a sunlit plane, neighboring texels often store
// different depths for the same surface.
float blockerDepthGap(vec3 coord, vec2 slope, vec2 offset, float bias) {
    ivec2 pixel = ivec2(floor(coord.xy * float(shadowMapResolution) + offset));
    vec2 sampleUV = (vec2(pixel) + 0.5) / float(shadowMapResolution);
    vec2 unwarpedSample = unwarpShadowXY(sampleUV * 2.0 - 1.0, shadowCenterScale());
    float receiverDepth = coord.z + dot(slope, unwarpedSample * 0.5 + 0.5);
    if (receiverDepth <= 0.0 || receiverDepth >= 1.0) return 0.0;
    return receiverDepth - texelFetch(shadowtex1, pixel, 0).r - bias;
}

#if SHADOW_STYLE == 1
const float photoMaxRadius = 12.0;
const vec2 penumbraDisk[16] = vec2[16](
    vec2(0.18, 0.00), vec2(-0.23, 0.21), vec2(0.03, -0.39), vec2(0.28, 0.37),
    vec2(-0.52, -0.09), vec2(0.49, -0.32), vec2(-0.16, 0.62), vec2(-0.32, -0.60),
    vec2(0.68, 0.25), vec2(-0.71, 0.29), vec2(0.34, -0.74), vec2(0.25, 0.81),
    vec2(-0.76, -0.44), vec2(0.90, -0.20), vec2(-0.54, 0.79), vec2(-0.13, -0.98)
);

float softOcclusion(vec3 coord, vec2 slope, float bias, float depthPerBlock) {
    float blockerGap = 0.0;
    float blockers = 0.0;
    // A small, fixed blocker search keeps the pattern stable as the camera moves.
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            float gap = blockerDepthGap(coord, slope, 3.0 * vec2(x, y), bias);
            blockerGap += max(gap, 0.0);
            blockers += gap > 0.0 ? 1.0 : 0.0;
        }
    }
    // Check farther out so the penumbra extends onto the lit side of the edge.
    for (int i = 8; i < 16; ++i) {
        float gap = blockerDepthGap(coord, slope, photoMaxRadius * penumbraDisk[i], bias);
        blockerGap += max(gap, 0.0);
        blockers += gap > 0.0 ? 1.0 : 0.0;
    }
    if (blockers == 0.0) return 0.0;

    // Orthographic sunlight: penumbra width grows with caster/receiver separation.
    float separation = blockerGap / (blockers * depthPerBlock);
    float centerScale = shadowCenterScale();
    float inverseScale = 1.0 - (1.0 - centerScale) * shadowSquareRadius(coord.xy * 2.0 - 1.0);
    float warpRate = inverseScale * inverseScale / centerScale;
    float texelsPerBlock = warpRate * 0.5 * float(shadowMapResolution) * abs(shadowProjection[0][0]);
    // An intentionally larger apparent sun makes soft shadows visible at
    // Minecraft's scale, including around builds just a few blocks high.
    float lightRadius = 0.035 + 0.025 * float(SHADOW_SOFTNESS);
    float radius = clamp(separation * lightRadius * texelsPerBlock, 1.5, photoMaxRadius);
    float occluded = 0.0;
    const mat2 rotate = mat2(0.92388, 0.38268, -0.38268, 0.92388);
    for (int i = 0; i < 16; ++i) {
        vec2 offset = radius * penumbraDisk[i];
        occluded += blockerDepthGap(coord, slope, offset, bias) > 0.0 ? 1.0 : 0.0;
        occluded += blockerDepthGap(coord, slope, rotate * offset, bias) > 0.0 ? 1.0 : 0.0;
    }
    return occluded / 32.0;
}
#endif
#endif

float solarOcclusion(vec3 playerPosition, vec3 viewNormal) {
#ifdef SHADOWS_ENABLED
    vec4 clip = shadowProjection * shadowModelView * vec4(playerPosition, 1.0);
    vec3 unwarped = clip.xyz / clip.w * 0.5 + 0.5;
    // Derive the actual receiver plane before fragment-dependent exits.
    // Lighting normals on grass and other cutouts need not match their geometry.
    vec3 plane = cross(dFdx(unwarped), dFdy(unwarped));
    if (abs(plane.z) <= length(plane) * 0.0001) return 0.0;
    vec2 slope = -plane.xy / plane.z;
    vec3 coord = unwarped;
    coord.xy = warpShadowXY(unwarped.xy * 2.0 - 1.0, shadowCenterScale()) * 0.5 + 0.5;
    coord.z -= dot(slope, unwarped.xy);

    vec3 sunInView = normalize(sunPosition);
    vec3 sunDirection = mat3(gbufferModelViewInverse) * sunInView;
    float daylight = smoothstep(0.04, 0.20, sunDirection.y);
    float distanceFade = 1.0 - smoothstep(shadowDistance * 0.75,
                                         shadowDistance, length(playerPosition));
    float facing = max(dot(normalize(viewNormal), sunInView), 0.0);
    float strength = daylight * distanceFade * (1.0 - rainStrength)
                   * smoothstep(0.0, 0.15, facing);
    if (strength <= 0.0 || unwarped.z <= 0.0 || unwarped.z >= 1.0) return 0.0;

    float border = min(min(coord.x, coord.y), min(1.0 - coord.x, 1.0 - coord.y));
#if SHADOW_STYLE == 1
    float margin = (photoMaxRadius + 1.0) / float(shadowMapResolution);
#else
    float margin = 2.0 / float(shadowMapResolution);
#endif
    if (border <= margin) return 0.0;
    float coverage = smoothstep(margin, 0.04, border)
                   * smoothstep(0.0, 0.025, min(unwarped.z, 1.0 - unwarped.z));
    float depthPerBlock = 0.5 * abs(shadowProjection[2][2]);
    float bias = depthPerBlock * mix(0.075, 0.025, facing) + 0.000002;

#if SHADOW_STYLE == 1
    float occluded = softOcclusion(coord, slope, bias, depthPerBlock);
#elif SHADOW_SOFTNESS == 0
    float occluded = blockerDepthGap(coord, slope, vec2(0.0), bias) > 0.0 ? 1.0 : 0.0;
#else
    float radius = SHADOW_SOFTNESS == 2 ? 1.25 : 0.75;
    float occluded = 0.0;
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            occluded += blockerDepthGap(coord, slope, radius * vec2(x, y), bias) > 0.0 ? 1.0 : 0.0;
        }
    }
    occluded /= 9.0;
#endif
    return occluded * strength * coverage;
#else
    return 0.0;
#endif
}
