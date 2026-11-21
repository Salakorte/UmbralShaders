#version 330 compatibility
uniform sampler2D colortex0;
varying vec2 vsUV;
void main() { gl_FragColor = texture2D(colortex0, vsUV); }
