#version 100
#extension GL_OES_standard_derivatives : enable
precision mediump float;
varying vec2 uv;
varying vec3 color;
void main() {
    vec2 t0;
    vec2 t1;
    vec2 t2;
    vec3 t3;
    float t4;
    vec4 t5;
    vec4 t6;
    vec4 t7;
    t0 = dFdx(uv);
    t1 = (t0 * vec2(16.0, 16.0));
    t2 = (t1 + vec2(0.5, 0.5));
    t3 = fwidth(color);
    t4 = ((t3).x * 32.0);
    t5 = vec4(0.0, 0.0, 0.0, 1.0);
    t5.x = (t2).x;
    t6 = t5;
    t6.y = (t2).y;
    t7 = t6;
    t7.z = t4;
    gl_FragColor = t7;
}
