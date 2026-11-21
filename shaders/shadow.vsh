#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/shadow_projection.glsl"
#ifdef VS_VOXEL_LIGHTING
#include "/lib/voxel_capture.glsl"
#endif
varying vec2 vsShadowUV;
varying vec3 vsShadowUnwarped;
void main() {
#ifdef VS_VOXEL_LIGHTING
    captureVoxel(gl_Vertex);
#endif
    gl_Position = ftransform();
    vsShadowUnwarped = gl_Position.xyz / gl_Position.w;
    gl_Position.xy = warpShadowXY(vsShadowUnwarped.xy, shadowCenterScale()) * gl_Position.w;
    vsShadowUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
