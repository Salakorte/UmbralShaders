#version 430 compatibility
#include "/lib/settings.glsl"
#ifdef RT_GLASS_TRANSMISSION
#define VS_CAPTURE_GLASS
#include "/lib/voxel_capture.glsl"
#endif
void main() {
#ifdef RT_GLASS_TRANSMISSION
    captureVoxel(gl_Vertex);
#endif
    gl_Position = ftransform();
}
