#version 330 compatibility
uniform sampler2D colortex0;
varying vec2 vsScreenUV;
/* DRAWBUFFERS:5 */
void main() {
    gl_FragData[0] = texture2D(colortex0, vsScreenUV);
}
