#version 100
#extension GL_EXT_shader_framebuffer_fetch : require
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
void main()
{
    vec4 v0 = (gl_LastFragData[0]) + (vec4(0.25, 0.0, 0.0, 0.0));
    gl_FragColor = v0;
}
