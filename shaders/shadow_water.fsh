#version 330 compatibility
// Translucent terrain casts no opaque shadow in v0.1. Opaque/cutout depth
// is sampled through shadowtex1, not the water/glass-inclusive shadowtex0.
void main() { discard; }
