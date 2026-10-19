#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
uniform highp vec2 charon_target;
uniform sampler2D charon_attachment1;
void main()
{
    gl_FragColor = vec4((texture2D(charon_attachment1, gl_FragCoord.xy / charon_target)).x, 0.0, 0.0, 1.0);
}
