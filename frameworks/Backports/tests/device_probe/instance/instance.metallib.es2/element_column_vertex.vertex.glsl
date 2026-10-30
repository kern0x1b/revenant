#version 100
attribute vec2 a_corners;
uniform float revenant_instance;
uniform vec4 quads_tint;
uniform int pick;
uniform vec4 frame_gain_2;
uniform vec4 frame_gain_1;
uniform vec4 frame_gain_0;
uniform float revenant_flip;
varying vec4 color;
void main() {
    vec4 t0;
    float t1;
    float t2;
    float t3;
    float t4;
    vec4 t5;
    vec4 t6;
    vec4 t7;
    vec4 t8;
    vec4 t9;
    vec4 t10;
    t0 = vec4(0.0, (a_corners).y, 0.0, 0.0);
    t1 = float(int(revenant_instance));
    t2 = (t1 + (a_corners).x);
    t3 = (t2 * 0.666666687);
    t4 = (t3 + (-1.0));
    t5 = vec4(0.0, 0.0, 0.0, 1.0);
    t5.x = t4;
    t6 = vec4((t5).x, (t0).y, (t5).z, (t5).w);
    t7 = ((pick == 0) ? frame_gain_0 : ((pick == 1) ? frame_gain_1 : frame_gain_2));
    t8 = quads_tint;
    t8.w = 1.0;
    t9 = vec4((t8).x, (t7).y, 0.0, (t8).w);
    t10 = vec4((t9).x, (t9).y, (quads_tint).z, (t9).w);
    gl_Position = t6;
    gl_Position.y *= revenant_flip;
    color = t10;
}
