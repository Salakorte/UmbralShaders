float casterDepth(vec3 position) {
    float depth = gl_FragCoord.z;
    if (shadowDistance > 128.0) {
        // Evaluate the original plane at the inverse-warped texel.
        vec3 plane = cross(dFdx(position), dFdy(position));
        if (abs(plane.z) <= length(plane) * 0.0001) discard;
        vec2 warped = gl_FragCoord.xy * (2.0 / float(shadowMapResolution)) - 1.0;
        vec2 unwarped = unwarpShadowXY(warped, shadowCenterScale());
        depth -= 0.5 * dot(plane.xy / plane.z, unwarped - position.xy);
        if (depth < 0.0 || depth >= 1.0) discard;
    }
    return depth;
}
