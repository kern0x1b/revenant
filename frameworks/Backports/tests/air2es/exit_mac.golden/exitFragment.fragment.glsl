#version 100
precision mediump float;
varying vec2 uv;
void main() {
    float t0;
    float t1;
    int t2;
    float t3;
    int t4;
    float t6;
    float t7;
    float t8;
    bool t9;
    float t10;
    float t11;
    int t12;
    float t13;
    int t14;
    float t15;
    int t16;
    bool t17;
    int t18;
    float t19;
    float t20;
    int t21;
    vec4 t22;
    float t23;
    float t24;
    vec4 t25;
    vec4 t26;
    vec4 t27;
    t0 = ((uv).y * 0.142857149);
    t3 = 0.0;
    t4 = 1;
    t1 = t3;
    t2 = t4;
    for (int t5 = 1; t5 < 7; t5++) {
        t6 = float(t2);
        t7 = (t0 * t6);
        t8 = (t7 + t1);
        t9 = (t8 > (uv).x);
        if (t9) {
            t10 = (t6 * 0.0714285746);
            t11 = (t8 - t10);
            t14 = t2;
            t15 = t11;
            t12 = t14;
            t13 = t15;
            break;
        } else {
            t16 = (t2 + 1);
            t17 = (t16 == 7);
            if (t17) {
                t18 = 6;
                t19 = t8;
                t12 = t18;
                t13 = t19;
                break;
            } else {
                t20 = t8;
                t21 = t16;
                t1 = t20;
                t2 = t21;
            }
        }
    }
    t22 = vec4(0.0, (uv).y, 0.0, 0.0);
    t23 = float(t12);
    t24 = (t23 * 0.142857149);
    t25 = vec4(0.0, 0.0, 0.0, 1.0);
    t25.x = t13;
    t26 = t25;
    t26.y = t24;
    t27 = vec4((t26).x, (t26).y, (t22).y, (t26).w);
    gl_FragColor = t27;
}
