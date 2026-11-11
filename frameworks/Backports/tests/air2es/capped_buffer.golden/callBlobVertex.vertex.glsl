#version 100
attribute float a_vertex_id;
float revenant_quotient(float a, float b)
{
    float d = max(b, 1.0);
    float q = floor((a + 0.5) / d);
    float r = a - q * d;
    return q + floor((r + 0.5) / d);
}
float revenant_remainder(float a, float b)
{
    float d = max(b, 1.0);
    return a - d * revenant_quotient(a, d);
}
uniform float positions_7;
uniform float positions_6;
uniform float positions_5;
uniform float positions_4;
uniform float positions_3;
uniform float positions_2;
uniform float positions_1;
uniform float positions_0;
uniform highp float revenant_flip;
void main() {
    int t0;
    float t1;
    vec4 t2;
    vec4 t3;
    t0 = int(revenant_remainder(float(int(a_vertex_id)), float(7)));
    t1 = ((t0 == 0) ? positions_0 : ((t0 == 1) ? positions_1 : ((t0 == 2) ? positions_2 : ((t0 == 3) ? positions_3 : ((t0 == 4) ? positions_4 : ((t0 == 5) ? positions_5 : ((t0 == 6) ? positions_6 : positions_7)))))));
    t2 = vec4(0.0, 0.0, 0.0, 1.0);
    t2.x = t1;
    t3 = t2;
    t3.y = positions_2;
    gl_Position = t3;
    gl_Position.y *= revenant_flip;
}
