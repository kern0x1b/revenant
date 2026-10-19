#version 100
uniform highp float charon_flip;
attribute highp float a_vertex_id;
attribute highp vec4 a0_0;
attribute highp vec4 a1_0;
varying highp vec4 vary_generated_5shadeDv4_f_;
void main()
{
    int v0 = int(a_vertex_id);
    vec4 v1 = a0_0;
    vec4 v2 = a1_0;
    gl_Position = v1;
    gl_Position.y *= charon_flip;
    gl_Position.z = gl_Position.z * 2.0 - gl_Position.w;
    vary_generated_5shadeDv4_f_ = v2;
}
