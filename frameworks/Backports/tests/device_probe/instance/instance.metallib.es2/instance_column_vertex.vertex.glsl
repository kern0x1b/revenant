#version 100
attribute vec2 a_corners;
uniform float revenant_instance;
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
    int t7;
    float t8;
    float t9;
    vec4 t10;
    t0 = vec4(0.0, (a_corners).y, 0.0, 0.0);
    t1 = float(int(revenant_instance));
    t2 = (t1 + (a_corners).x);
    t3 = (t2 * 0.666666687);
    t4 = (t3 + (-1.0));
    t5 = vec4(0.0, 0.0, 0.0, 1.0);
    t5.x = t4;
    t6 = vec4((t5).x, (t0).y, (t5).z, (t5).w);
    t7 = (int(revenant_instance) + 1);
    t8 = float(t7);
    t9 = (t8 * 0.00392156886);
    t10 = vec4(0.0, 0.0, 0.0, 1.0);
    t10.x = t9;
    gl_Position = t6;
    gl_Position.y *= revenant_flip;
    color = t10;
}
