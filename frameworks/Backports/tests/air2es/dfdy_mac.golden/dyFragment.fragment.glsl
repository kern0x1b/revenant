#version 100
#extension GL_OES_standard_derivatives : enable
precision mediump float;
varying vec2 uv;
void main() {
    vec2 t0;
    vec2 t1;
    vec2 t2;
    vec4 t3;
    vec4 t4;
    t0 = -dFdy(uv);
    t1 = (t0 * vec2(32.0, 32.0));
    t2 = (t1 + vec2(0.5, 0.5));
    t3 = vec4((t2).x, (t2).y, 0.0, 0.0);
    t4 = vec4((t3).x, (t3).y, (vec4(0.0, 0.0, 0.0, 1.0)).z, (vec4(0.0, 0.0, 0.0, 1.0)).w);
    gl_FragColor = t4;
}
