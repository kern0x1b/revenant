#version 100
#extension GL_EXT_shadow_samplers : require
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
uniform highp float u0_0;
uniform sampler2DShadow t0;
varying highp vec2 vary_generated_5coordDv2_f_;
void main()
{
    float v0 = u0_0;
    float v1 = shadow2DEXT(t0, vec3((vary_generated_5coordDv2_f_), (v0)));
    gl_FragColor = vec4(v1, v1, v1, 1.0);
}
