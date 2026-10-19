#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
precision highp int;
uniform highp int u0_0;
uniform highp float u0_4;
void main()
{
    bool r1 = false;
    int v0;
    int v1;
    float v2;
    float v3;
    bool r2 = false;
    bool r3 = false;
    bool r4 = false;
    bool r5 = false;
    float v4;
    bool brk0 = false;
    bool cont0 = false;
    int v5;
    float v6;
    float v7;
    int v8;
    bool v9;
    bool v10;
    float v11;
    float v12;
    v5 = u0_0;
    v6 = u0_4;
    r1 = true;
    v0 = 0;
    v2 = 0.0;
    for (int it0 = 0; it0 < 64; it0++) {
        if (r1) {
            v7 = (v2) + (v6);
            v8 = (v0) + (1);
            v9 = (v8) < (v5);
            if (v9) {
                v1 = v8;
                v3 = v7;
                cont0 = true;
            } else {
                brk0 = true;
                r2 = true;
            }
        }
        if (brk0 || !cont0)
            break;
        v0 = v1;
        v2 = v3;
        cont0 = false;
    }
    if (r2) {
        v10 = (v7) > (2.5);
        if (v10) {
            r4 = true;
        } else {
            r3 = true;
        }
    }
    if (r3) {
        v11 = (v7) * (0.200000003);
        r5 = true;
        v4 = v11;
    }
    if (r4) {
        v12 = (v7) * (0.0500000007);
        r5 = true;
        v4 = v12;
    }
    if (r5) {
        gl_FragColor = vec4(v4, v4, v4, 1.0);
    }
}
