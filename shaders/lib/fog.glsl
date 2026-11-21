uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;
uniform float far;
uniform int isEyeInWater;
#endif
// Iris exposes the vanilla fog range/color; this is the standard smooth range
// approximation. Newer multi-range fog and special status effects need in-game QA.
float vanillaFogAmount(vec3 viewPosition) {
    float distanceToEye = fogShape == 0 ? length(viewPosition)
        : max(length(viewPosition.xz), abs(viewPosition.y));
    float start = fogStart;
    float end = fogEnd;
#ifdef DISTANT_HORIZONS
    // Use the same clear-air fog on each side of the vanilla/LOD boundary.
    // Preserve short environmental fog and immersion fog.
    if (dhRenderDistance > far && fogEnd >= far * 0.75 && isEyeInWater == 0) {
        end = float(dhRenderDistance);
        start = end * 0.75;
    }
#endif
    return smoothstep(start, max(start + 0.001, end), distanceToEye);
}

vec3 applyVanillaFog(vec3 color, vec3 viewPosition) {
    return mix(color, fogColor, vanillaFogAmount(viewPosition));
}
