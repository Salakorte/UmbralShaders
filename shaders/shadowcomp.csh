#version 430
layout(local_size_x = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);
// Iris issues the image-access and texture-fetch barriers after this dispatch.
void main() {}
