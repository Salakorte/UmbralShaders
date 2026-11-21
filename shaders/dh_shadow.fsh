#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/shadow_projection.glsl"
#include "/lib/shadow_depth.glsl"
uniform float far;
varying vec3 vsShadowUnwarped;
varying vec3 vsLodPlayerPosition;
varying float vsLodAlpha;
flat in int vsLodOpaque;
/* DRAWBUFFERS:0 */
void main() {
#ifdef DH_CAST_SHADOWS
    float depth = casterDepth(vsShadowUnwarped);
    vec2 offset = abs(vsLodPlayerPosition.xz);
    // The regular terrain already casts higher-detail shadows nearby.
    if (max(offset.x, offset.y) < far || length(offset) > shadowDistance * shadowDistanceRenderMul
        || vsLodOpaque == 0 || vsLodAlpha < 0.99) discard;
    gl_FragDepth = depth;
    gl_FragData[0] = vec4(1.0);
#else
    discard;
#endif
}
