#include "/lib/settings.glsl"
#ifndef VS_DH_LOD
varying vec2 vsUV;
#endif
varying vec2 vsLightUV;
varying vec4 vsColor;
varying vec3 vsViewPosition;
uniform mat4 gbufferModelViewInverse;
#if defined(VS_REFLECTIVE_SURFACE) && (defined(RT_WATER_REFLECTIONS) || defined(RT_GLASS_REFLECTIONS))
in vec4 mc_Entity;
flat out int vsMaterial;
varying vec3 vsReflectionNormal;
#endif
varying vec3 vsFogPosition;
#ifdef VS_RECEIVES_SHADOWS
varying vec3 vsPlayerPosition;
varying vec3 vsViewNormal;
#endif
void main() {
    gl_Position = ftransform();
#ifdef VS_DH_LOD
    // Iris already normalizes this attribute for DH.
    vsLightUV = gl_MultiTexCoord2.xy;
#else
    vsUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vsLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
#endif
    vsColor = gl_Color;
    vsViewPosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vsFogPosition = mat3(gbufferModelViewInverse) * vsViewPosition;
#if defined(VS_REFLECTIVE_SURFACE) && (defined(RT_WATER_REFLECTIONS) || defined(RT_GLASS_REFLECTIONS))
    vsMaterial = int(mc_Entity.x);
    vsReflectionNormal = gl_NormalMatrix * gl_Normal;
#endif
#ifdef VS_RECEIVES_SHADOWS
    vsPlayerPosition = (gbufferModelViewInverse * vec4(vsViewPosition, 1.0)).xyz;
    vsViewNormal = gl_NormalMatrix * gl_Normal;
#endif
}
