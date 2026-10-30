#version 100
precision mediump float;
void main() {
    ivec2 gid;
    bool revenant_written = false;
    vec4 v0;
    bool t1;
    vec4 t2;
    gid = ivec2(floor(gl_FragCoord.xy));
    v0 = vec4(0.0);
    t1 = ((gid).x == 0);
    if (t1) {
        v0 = vec4(1.0, 0.5, 0.25, 1.0);
    } else {
    }
    t2 = v0;
    gl_FragColor = t2;
    revenant_written = true;
    if (!revenant_written) discard;
}
