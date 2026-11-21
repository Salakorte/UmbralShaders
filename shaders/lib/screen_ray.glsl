uniform sampler2D VS_RAY_DEPTH;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

vec3 rayViewPosition(vec2 uv, float depth) {
    vec4 view = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return view.xyz / view.w;
}

float rayScreenCoverage(vec2 uv) {
    vec2 edge = min(uv, 1.0 - uv);
    return smoothstep(0.0, 0.07, min(edge.x, edge.y));
}

bool rayDepthAt(vec3 position, out vec2 uv, out vec3 surface) {
    vec4 clip = gbufferProjection * vec4(position, 1.0);
    if (clip.w <= 0.0) return false;
    uv = clip.xy / clip.w * 0.5 + 0.5;
    if (any(lessThanEqual(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return false;
    float depth = textureLod(VS_RAY_DEPTH, uv, 0.0).r;
    if (depth >= 1.0) return false;
    surface = rayViewPosition(uv, depth);
    return true;
}

bool traceScreenRay(vec3 origin, vec3 direction, float reach, int steps,
                    out vec2 hitUV, out vec3 hitSurface, out float hitDistance) {
    float previousDistance = 0.0;
    float previousGap = 0.0;
    for (int i = 1; i <= steps; ++i) {
        float fraction = float(i) / float(steps);
        float travel = 0.08 + reach * fraction * fraction;
        vec3 position = origin + direction * travel;
        if (position.z >= -0.01) break;
        vec2 uv;
        vec3 surface;
        if (!rayDepthAt(position, uv, surface)) {
            previousDistance = travel;
            previousGap = 0.0;
            continue;
        }
        float gap = surface.z - position.z;
        if (previousGap <= 0.0 && gap > 0.0) {
            float low = previousDistance;
            float high = travel;
            for (int refine = 0; refine < 5; ++refine) {
                float middle = (low + high) * 0.5;
                vec3 testPosition = origin + direction * middle;
                vec2 testUV;
                vec3 testSurface;
                if (rayDepthAt(testPosition, testUV, testSurface) && testSurface.z > testPosition.z) {
                    high = middle;
                    uv = testUV;
                    surface = testSurface;
                } else {
                    low = middle;
                }
            }
            float remainingGap = surface.z - (origin.z + direction.z * high);
            float thickness = 0.09 + min(0.27, abs(surface.z) * 0.003);
            if (remainingGap <= thickness && length(surface - origin) > 0.12) {
                hitUV = uv;
                hitSurface = surface;
                hitDistance = high;
                return true;
            }
        }
        previousGap = gap;
        previousDistance = travel;
    }
    return false;
}

vec3 rayNeighbor(vec2 uv, vec3 center) {
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return center;
    float depth = textureLod(VS_RAY_DEPTH, uv, 0.0).r;
    return depth < 1.0 ? rayViewPosition(uv, depth) : center;
}

vec3 nearerSurfaceGradient(vec3 first, vec3 second) {
    if (dot(first, first) == 0.0) return second;
    if (dot(second, second) == 0.0) return first;
    return abs(first.z) < abs(second.z) ? first : second;
}

vec3 raySurfaceNormal(vec2 uv, vec3 center) {
    vec2 pixel = 1.0 / vec2(textureSize(VS_RAY_DEPTH, 0));
    vec2 x = vec2(pixel.x, 0.0);
    vec2 y = vec2(0.0, pixel.y);
    vec3 dx = nearerSurfaceGradient(center - rayNeighbor(uv - x, center), rayNeighbor(uv + x, center) - center);
    vec3 dy = nearerSurfaceGradient(center - rayNeighbor(uv - y, center), rayNeighbor(uv + y, center) - center);
    if (abs(dx.z) > 0.65 || abs(dy.z) > 0.65) return vec3(0.0);
    vec3 face = cross(dx, dy);
    float magnitude = length(face);
    if (magnitude < 0.00000001) return vec3(0.0);
    return (dot(face, center) > 0.0 ? -face : face) / magnitude;
}
