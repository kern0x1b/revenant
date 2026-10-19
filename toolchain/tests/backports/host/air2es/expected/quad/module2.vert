#version 100
uniform highp float charon_flip;
uniform highp float charon_instance;
attribute highp vec2 vin0;
attribute highp vec2 vin1;
attribute highp vec4 vin2;
uniform highp float u1_0;
varying highp vec2 vary_generated_5coordDv2_f_;
varying highp vec4 vary_generated_5shadeDv4_f_;
void main()
{
    float v0 = u1_0;
    float v1 = ((vin0).x) * (v0);
    float v2 = ((vin0).y) * (v0);
    float v3 = float(int(charon_instance));
    float v4 = (v3) * (0.5);
    float v5 = ((vin1).x) + (v4);
    gl_Position = vec4(v1, v2, 0.0, 1.0);
    gl_Position.y *= charon_flip;
    gl_Position.z = gl_Position.z * 2.0 - gl_Position.w;
    vary_generated_5coordDv2_f_ = vec2(v5, (vin1).y);
    vary_generated_5shadeDv4_f_ = vin2;
}
