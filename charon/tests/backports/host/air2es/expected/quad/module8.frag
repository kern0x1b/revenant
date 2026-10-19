#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
uniform highp int charon_output;
uniform highp vec4 u0_0;
void main()
{
    vec4 v0 = u0_0;
    vec4 v1 = (v0) * (0.5);
    gl_FragColor = (charon_output == 0 ? v0 : v1);
}
