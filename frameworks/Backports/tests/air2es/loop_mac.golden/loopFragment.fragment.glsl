#version 100
precision mediump float;
uniform vec4 viewport;
varying vec2 uv;
uniform vec4 planes_7;
uniform vec4 planes_6;
uniform vec4 planes_5;
uniform vec4 planes_4;
uniform vec4 planes_3;
uniform vec4 planes_2;
uniform vec4 planes_1;
uniform vec4 planes_0;
void main() {
    int t0;
    bool t1;
    float t2;
    int t3;
    float t4;
    int t5;
    int t6;
    float t7;
    int t8;
    float t9;
    vec4 t11;
    float t12;
    float t13;
    float t14;
    float t15;
    float t16;
    int t17;
    bool t18;
    int t19;
    float t20;
    int t21;
    float t22;
    float t23;
    float t24;
    int t25;
    vec4 t26;
    float t27;
    float t28;
    float t29;
    vec4 t30;
    vec4 t31;
    vec4 t32;
    t0 = int((viewport).z);
    t1 = (t0 == 0);
    if (t1) {
        t4 = 0.5;
        t5 = (-1);
        t2 = t4;
        t3 = t5;
    } else {
        t8 = 0;
        t9 = 0.0;
        t6 = t8;
        t7 = t9;
        for (int t10 = 0; t10 < 8; t10++) {
            t11 = ((t6 == 0) ? planes_0 : ((t6 == 1) ? planes_1 : ((t6 == 2) ? planes_2 : ((t6 == 3) ? planes_3 : ((t6 == 4) ? planes_4 : ((t6 == 5) ? planes_5 : ((t6 == 6) ? planes_6 : planes_7)))))));
            t12 = ((t11).x * (uv).x);
            t13 = ((t11).y * (uv).y);
            t14 = ((t11).z + t7);
            t15 = (t14 + t13);
            t16 = (t15 + t12);
            t17 = (t6 + 1);
            t18 = (t17 == t0);
            if (t18) {
                break;
            } else {
                t19 = t17;
                t20 = t16;
                t6 = t19;
                t7 = t20;
            }
        }
        t21 = (t0 + (-1));
        t22 = (t16 * 0.0500000007);
        t23 = (t22 + 0.5);
        t24 = t23;
        t25 = t21;
        t2 = t24;
        t3 = t25;
    }
    t26 = vec4(0.0, (uv).y, 0.0, 0.0);
    t27 = float(t3);
    t28 = (t27 * 0.100000001);
    t29 = (t28 + 0.5);
    t30 = vec4(0.0, 0.0, 0.0, 1.0);
    t30.x = t2;
    t31 = t30;
    t31.y = t29;
    t32 = vec4((t31).x, (t31).y, (t26).y, (t31).w);
    gl_FragColor = t32;
}
