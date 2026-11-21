struct VoxelRay {
    ivec3 cell;
    ivec3 stepCell;
    vec3 stride;
    vec3 nextFace;
    vec3 hitNormal;
};

VoxelRay beginVoxelRay(vec3 start, vec3 direction) {
    VoxelRay ray;
    ray.cell = ivec3(floor(start));
    ray.stepCell = ivec3(sign(direction));
    ray.stride = 1.0 / max(abs(direction), vec3(0.000001));
    ray.nextFace = mix(fract(start), 1.0 - fract(start), greaterThan(direction, vec3(0.0))) * ray.stride;
    ray.nextFace = mix(ray.nextFace, vec3(1e6), equal(ray.stepCell, ivec3(0)));
    ray.hitNormal = vec3(0.0);
    return ray;
}

float advanceVoxelRay(inout VoxelRay ray) {
    float entry = min(ray.nextFace.x, min(ray.nextFace.y, ray.nextFace.z));
    bvec3 crossed = lessThanEqual(ray.nextFace, vec3(entry + 0.000001));
    ivec3 movement = ivec3(crossed) * ray.stepCell;
    // Cells touched for zero distance at a corner are skipped.
    ray.cell += movement;
    ray.nextFace += mix(vec3(0.0), ray.stride, crossed);
    ray.hitNormal = normalize(vec3(-movement));
    return entry;
}
