uniform vec3 cameraPosition;
const int voxelSize = 64;
const int voxelTileSize = 16;
const int voxelTileCount = 4;
const int emitterCapacity = 48;
const uint emitterMarker = 256u;
const int windowCapacity = 24;
const vec3 windowNormal[5] = vec3[5](
    vec3(1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0),
    vec3(0.0, 0.0, -1.0), vec3(0.0, 1.0, 0.0)
);

vec3 voxelPoint(vec3 playerPosition) {
    vec3 gridCenter = floor((cameraPosition + 8.0) / 16.0) * 16.0;
    return playerPosition + (cameraPosition - gridCenter) + vec3(voxelSize * 0.5);
}

int voxelTileRow(ivec3 tile) {
    return tile.x + voxelTileCount * (tile.y + voxelTileCount * tile.z);
}

bool voxelSolid(uint material) {
    return material == 1u || (material >= 32u && material < 48u);
}

bool insideVoxelGrid(ivec3 cell) {
    return all(greaterThanEqual(cell, ivec3(0))) && all(lessThan(cell, ivec3(voxelSize)));
}
