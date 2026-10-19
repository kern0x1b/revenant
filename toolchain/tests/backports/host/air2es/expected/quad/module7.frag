#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
varying highp vec4 vary_generated_5shadeDv4_f_;
void main()
{
    gl_FragColor = vary_generated_5shadeDv4_f_;
}
