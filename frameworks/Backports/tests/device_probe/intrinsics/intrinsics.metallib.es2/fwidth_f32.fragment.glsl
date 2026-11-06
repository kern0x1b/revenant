#version 100
#extension GL_OES_standard_derivatives : enable
precision mediump float;
uniform highp float revenant_flip;
uniform vec2 revenant_target;
void main() {
    vec4 position;
    float t0;
    float t1;
    float t2;
    float t3;
    float t4;
    vec4 t5;
    position = gl_FragCoord;
    position.y = revenant_flip > 0.0 ? revenant_target.y - gl_FragCoord.y : gl_FragCoord.y;
    t0 = ((position).x * 0.00390625);
    t1 = ((position).y * 0.0078125);
    t2 = (t0 + t1);
    t3 = fwidth(t2);
    t4 = (t3 * 16.0);
    t5 = vec4(0.0, 0.0, 0.0, 1.0);
    t5.x = t4;
    gl_FragColor = t5;
}
