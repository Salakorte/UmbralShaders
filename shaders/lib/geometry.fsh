#include "/lib/settings.glsl"
varying vec2 vsLightUV;
varying vec4 vsColor;
varying vec3 vsViewPosition;
varying vec3 vsFogPosition;
#ifdef VS_TEXTURED
varying vec2 vsUV;
uniform sampler2D gtexture;
#endif
#ifdef VS_DH_TRANSLUCENT
uniform sampler2D depthtex0;
#endif
#ifdef VS_LIT
uniform sampler2D lightmap;
#endif
#ifdef VS_ENTITY
uniform vec4 entityColor;
#endif
#ifdef VS_RECEIVES_SHADOWS
varying vec3 vsPlayerPosition;
varying vec3 vsViewNormal;
#include "/lib/shadows.glsl"
#endif
#if defined(VS_LOCAL_BLOCK_LIGHTS) && defined(VS_VOXEL_LIGHTING)
#include "/lib/voxel_lighting.glsl"
#define VS_LIGHT_BUFFER
#endif
#ifndef VS_NO_FOG
#include "/lib/fog.glsl"
#endif
#if defined(VS_REFLECTIVE_SURFACE) && (defined(RT_WATER_REFLECTIONS) || defined(RT_GLASS_REFLECTIONS))
#include "/lib/specular_reflections.glsl"
#endif
#ifdef VS_LIGHT_BUFFER
/* DRAWBUFFERS:0167 */
#else
/* DRAWBUFFERS:0 */
#endif
#ifdef VS_LIT
vec3 sampleLightmap(vec2 uv) {
#ifdef VS_LIGHT_BUFFER
    // Interpolate the light levels even when the active Iris sampler uses nearest filtering.
    ivec2 size = textureSize(lightmap, 0);
    vec2 position = uv * vec2(size) - 0.5;
    ivec2 low = ivec2(floor(position));
    vec2 fraction = fract(position);
    ivec2 a = clamp(low, ivec2(0), size - 1);
    ivec2 b = clamp(low + 1, ivec2(0), size - 1);
    vec3 lowRow = mix(texelFetch(lightmap, a, 0).rgb,
                      texelFetch(lightmap, ivec2(b.x, a.y), 0).rgb, fraction.x);
    vec3 highRow = mix(texelFetch(lightmap, ivec2(a.x, b.y), 0).rgb,
                       texelFetch(lightmap, b, 0).rgb, fraction.x);
    return mix(lowRow, highRow, fraction.y);
#else
    return texture2D(lightmap, uv).rgb;
#endif
}
#endif
void main() {
#ifdef VS_DH_TRANSLUCENT
    // LOD translucency uses its own depth attachment. Give pixels already
    // covered by the regular scene priority over distant water and glass.
    // Iris exposes cleared vanilla depth as 1 even on reversed-Z backends.
    if (texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r < 1.0) discard;
#endif
    vec4 color = vsColor;
#ifdef VS_TEXTURED
    color *= texture2D(gtexture, vsUV);
#endif
#ifdef VS_ENTITY
    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
#endif
#ifdef VS_LIT
    vec3 light = sampleLightmap(vsLightUV);
#ifdef VS_RECEIVES_SHADOWS
    float occlusion = solarOcclusion(vsPlayerPosition, vsViewNormal);
    // Keep the sampled block-light/ambient floor. Lightmap combines sky, block,
    // brightness and dimension nonlinearly; this difference is an approximation,
    // not a physical decomposition into additive light sources.
    vec3 blockFloor = sampleLightmap(vec2(vsLightUV.x, 0.03125));
    vec3 skyContribution = max(light - blockFloor, vec3(0.0));
    float intensity = SHADOW_INTENSITY;
#if SHADOW_STYLE == 1
    intensity = min(1.9 * intensity, 0.85);
#endif
    float shadow = intensity * occlusion;
    light -= skyContribution * shadow;
#endif
#ifdef VS_LIGHT_BUFFER
    vec3 viewNormal = normalize(vsViewNormal);
    vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
    vec3 baseLight = voxelLinear(light);
    vec3 ambient = sampleLightmap(vec2(0.03125));
    vec3 skyOnly = ambient;
#ifdef RT_BLOCK_LIGHTS
    skyOnly = mix(sampleLightmap(vec2(0.03125, vsLightUV.y)), ambient, shadow);
#endif
    vec3 irradiance = voxelIrradiance(baseLight, voxelLinear(blockFloor), voxelLinear(skyOnly), voxelLinear(ambient),
                                      vsPlayerPosition, worldNormal);
    light = pow(baseLight, vec3(1.0 / 2.2));
    gl_FragData[1] = vec4(color.rgb, 1.0 - vanillaFogAmount(vsFogPosition));
    gl_FragData[2] = vec4(irradiance, 1.0);
    gl_FragData[3] = vec4(viewNormal, -vsViewPosition.z);
#endif
    color.rgb *= light;
#endif
#ifndef VS_NO_FOG
    color.rgb = applyVanillaFog(color.rgb, vsFogPosition);
#endif
#if defined(VS_REFLECTIVE_SURFACE) && (defined(RT_WATER_REFLECTIONS) || defined(RT_GLASS_REFLECTIONS))
    color = applyRayReflection(color);
#endif
    gl_FragData[0] = color;
}
