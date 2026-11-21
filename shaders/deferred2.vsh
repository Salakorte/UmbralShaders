#version 330 compatibility
varying vec2 vsScreenUV;
void main() {
    gl_Position = ftransform();
    vsScreenUV = gl_MultiTexCoord0.xy;
}
