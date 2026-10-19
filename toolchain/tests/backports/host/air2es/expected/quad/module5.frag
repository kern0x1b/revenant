#version 100
#extension GL_EXT_shader_framebuffer_fetch : require
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
uniform highp vec4 u0_0;
void main()
{
    vec4 v0 = u0_0;
    vec4 v1 = (gl_LastFragData[0]) * (0.5);
    vec4 v2 = (v0) * (0.5);
    vec4 v3 = (v1) + (v2);
    gl_FragColor = v3;
}
