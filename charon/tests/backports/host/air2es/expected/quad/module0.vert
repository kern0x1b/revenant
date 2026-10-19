#version 100
uniform highp float charon_flip;
attribute highp float a_vertex_id;
attribute highp vec2 a0_0;
attribute highp vec2 a0_8;
uniform highp float u1_0;
varying highp vec2 vary_generated_5coordDv2_f_;
void main()
{
    int v0 = int(a_vertex_id);
    vec2 v1 = a0_0;
    float v2 = u1_0;
    float v3 = ((v1).x) * (v2);
    float v4 = ((v1).y) * (v2);
    vec2 v5 = a0_8;
    gl_Position = vec4(v3, v4, 0.0, 1.0);
    gl_Position.y *= charon_flip;
    gl_Position.z = gl_Position.z * 2.0 - gl_Position.w;
    vary_generated_5coordDv2_f_ = v5;
}
