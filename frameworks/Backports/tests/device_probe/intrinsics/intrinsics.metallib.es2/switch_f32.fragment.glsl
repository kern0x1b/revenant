#version 100
precision highp float;
precision highp int;
uniform highp float revenant_flip;
uniform vec2 revenant_target;
uniform vec2 src_size;
uniform sampler2D src;
void main() {
    vec4 position;
    int t0;
    float t1;
    vec2 t2;
    int t3;
    float t4;
    vec2 t5;
    vec2 t6;
    vec2 t7;
    vec4 t8;
    float t9;
    float t10;
    float t11;
    int t12;
    float t13;
    float t14;
    float t15;
    float t16;
    float t17;
    float t18;
    vec4 t19;
    position = gl_FragCoord;
    position.y = revenant_flip > 0.0 ? revenant_target.y - gl_FragCoord.y : gl_FragCoord.y;
    t0 = int(src_size.x);
    t1 = float(t0);
    t2 = vec2(0.0);
    t2.x = t1;
    t3 = int(src_size.y);
    t4 = float(t3);
    t5 = t2;
    t5.y = t4;
    t6 = vec2((position).x, (position).y);
    t7 = (t6 / t5);
    t8 = texture2D(src, t7);
    t9 = float((t8).x);
    t10 = (t9 * 3.0);
    t11 = (t10 + 0.5);
    t12 = int(t11);
    if (t12 == 0) {
        t13 = float((t8).y);
        t14 = t13;
    } else if (t12 == 1) {
        t15 = float((t8).z);
        t16 = (t15 * 0.5);
        t14 = t16;
    } else if (t12 == 2) {
        t17 = float((t8).w);
        t18 = (1.0 - t17);
        t14 = t18;
    } else {
        t14 = 0.25;
    }
    t19 = vec4(0.0, 0.0, 0.0, 1.0);
    t19.x = t14;
    gl_FragColor = t19;
}
