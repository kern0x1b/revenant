#version 100
precision mediump float;
varying vec2 uv;
void main() {
    float t0;
    bool t1;
    float t2;
    bool t3;
    float t5;
    float t6;
    float t7;
    bool t8;
    float t9;
    float t10;
    float t11;
    float t12;
    bool t13;
    vec4 t14;
    float t15;
    float t16;
    vec4 t17;
    vec4 t18;
    t2 = 0.0;
    t3 = true;
    t0 = t2;
    t1 = t3;
    for (int t4 = 0; t4 < 2; t4++) {
        t5 = t1 ? 0.800000012 : 0.400000006;
        t6 = (t5 * (uv).x);
        t8 = (t6 > 0.300000012);
        t9 = (t6 * 0.300000012);
        t10 = t8 ? t6 : t9;
        t7 = t10;
        t11 = (t7 + t0);
        if (t1) {
            t12 = t11;
            t13 = false;
            t0 = t12;
            t1 = t13;
        } else {
            break;
        }
    }
    t14 = vec4(0.0, (uv).y, 0.0, 0.0);
    t15 = (t11 * 0.5);
    t16 = (t15 + 0.5);
    t17 = vec4(0.0, 0.0, 0.5, 1.0);
    t17.x = t16;
    t18 = vec4((t17).x, (t14).y, (t17).z, (t17).w);
    gl_FragColor = t18;
}
