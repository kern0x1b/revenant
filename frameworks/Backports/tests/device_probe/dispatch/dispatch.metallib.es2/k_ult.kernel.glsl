#version 100
precision mediump float;
void main() {
    ivec2 gid;
    bool revenant_written = false;
    bool t0;
    gid = ivec2(floor(gl_FragCoord.xy));
    t0 = ((((gid).x < 0) != ((gid).y < 0)) ? ((gid).x >= 0) : ((gid).x < (gid).y));
    if (t0) {
        gl_FragColor = vec4(1.0, 0.5, 0.25, 1.0);
        revenant_written = true;
    } else {
    }
    if (!revenant_written) discard;
}
