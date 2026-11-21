uniform int frameCounter;

float lightingPhase() {
    float pixelPhase = fract(52.9829189 * fract(dot(floor(gl_FragCoord.xy), vec2(0.06711056, 0.00583715))));
    return fract(pixelPhase + float(frameCounter % 64) * 0.618034);
}

vec2 lightDisk(int sampleIndex, int sampleCount, float phase) {
    float angle = float(sampleIndex) * 2.399963 + phase * 6.283185;
    float radius = sqrt((float(sampleIndex) + 0.5) / float(sampleCount));
    return radius * vec2(cos(angle), sin(angle));
}
