// Keep the map boundary fixed, while reserving more texels for nearby casters.
// The same warp and its inverse are shared between the depth and shading passes.
float shadowCenterScale() {
    return clamp(128.0 / shadowDistance, 0.125, 1.0);
}

float shadowSquareRadius(vec2 position) {
    return max(abs(position.x), abs(position.y));
}

vec2 warpShadowXY(vec2 position, float centerScale) {
    return position / (centerScale + (1.0 - centerScale) * shadowSquareRadius(position));
}

vec2 unwarpShadowXY(vec2 position, float centerScale) {
    return position * (centerScale / (1.0 - (1.0 - centerScale) * shadowSquareRadius(position)));
}

