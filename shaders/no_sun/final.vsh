#version 330 compatibility
varying vec2 vsUV;
void main() {
    gl_Position = ftransform();
    vsUV = gl_MultiTexCoord0.xy;
}
