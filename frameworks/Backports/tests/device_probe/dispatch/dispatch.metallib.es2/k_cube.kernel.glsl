#version 100
precision mediump float;
uniform samplerCube cubemap;
void main() {
    ivec2 gid;
    bool revenant_written = false;
    vec4 t0;
    gid = ivec2(floor(gl_FragCoord.xy));
    t0 = textureCube(cubemap, vec3(0.0, 1.0, 0.0));
    gl_FragColor = t0;
    revenant_written = true;
    if (!revenant_written) discard;
}
