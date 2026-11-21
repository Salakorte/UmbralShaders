#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/shadow_projection.glsl"
#include "/lib/shadow_depth.glsl"
uniform sampler2D gtexture;
varying vec2 vsShadowUV;
varying vec3 vsShadowUnwarped;
/* DRAWBUFFERS:0 */
void main() {
    float depth = casterDepth(vsShadowUnwarped);
    // Cutout leaves, fences and vegetation retain their texture silhouette.
    if (texture2D(gtexture, vsShadowUV).a < 0.1) discard;
    gl_FragDepth = depth;
    gl_FragData[0] = vec4(1.0);
}
