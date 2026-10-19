#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
uniform highp vec4 u0_0;
uniform sampler2D t0;
varying highp vec2 vary_generated_5coordDv2_f_;
void main()
{
    vec4 v0 = texture2D(t0, (vary_generated_5coordDv2_f_));
    vec4 v1 = u0_0;
    vec4 v2 = (v0) * (v1);
    bool v3 = ((v2).w) < (0.5);
    vec4 v4 = (v3) ? (v2) : (vec4((v2).z, (v2).y, (v2).x, (v2).w));
    gl_FragColor = v4;
}
