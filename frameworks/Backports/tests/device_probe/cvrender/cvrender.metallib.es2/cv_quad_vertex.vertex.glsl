#version 100
attribute float a_vertex_id;
uniform highp float revenant_flip;
void main() {
    float t0;
    float t1;
    float t2;
    float t3;
    float t4;
    float t5;
    float t6;
    float t7;
    float t8;
    vec4 t9;
    vec4 t10;
    t0 = float(int(a_vertex_id));
    t1 = (t0 * 0.5);
    t2 = floor(t1);
    t3 = (t0 * 2.0);
    t4 = (t2 * (-4.0));
    t5 = (t3 + (-1.0));
    t6 = (t5 + t4);
    t7 = (t2 * 2.0);
    t8 = (t7 + (-1.0));
    t9 = vec4(0.0, 0.0, 0.0, 1.0);
    t9.x = t6;
    t10 = t9;
    t10.y = t8;
    gl_Position = t10;
    gl_Position.y *= revenant_flip;
}
