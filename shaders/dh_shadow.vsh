#version 330 compatibility
#include "/lib/settings.glsl"
#include "/lib/shadow_projection.glsl"
uniform mat4 shadowModelViewInverse;
varying vec3 vsShadowUnwarped;
varying vec3 vsLodPlayerPosition;
varying float vsLodAlpha;
flat out int vsLodOpaque;
void main() {
    vec4 lightView = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * lightView;
    vsShadowUnwarped = gl_Position.xyz / gl_Position.w;
    gl_Position.xy = warpShadowXY(vsShadowUnwarped.xy, shadowCenterScale()) * gl_Position.w;
    vsLodPlayerPosition = (shadowModelViewInverse * lightView).xyz;
    vsLodAlpha = gl_Color.a;
#ifdef DISTANT_HORIZONS
    vsLodOpaque = dhMaterialId != DH_BLOCK_WATER ? 1 : 0;
#else
    vsLodOpaque = 1;
#endif
}
