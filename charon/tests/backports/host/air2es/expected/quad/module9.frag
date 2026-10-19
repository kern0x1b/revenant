#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
uniform sampler2D t0;
varying highp vec2 vary_generated_5coordDv2_f_;
void main()
{
    float v0 = texture2D(t0, (vary_generated_5coordDv2_f_)).r;
    gl_FragColor = vec4(v0, v0, v0, 1.0);
}
