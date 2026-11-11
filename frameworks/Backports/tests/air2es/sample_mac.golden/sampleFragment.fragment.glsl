#version 100
precision highp float;
precision highp int;
varying vec2 uv;
uniform sampler2D tex;
void main() {
    vec4 t0;
    t0 = texture2D(tex, uv);
    gl_FragColor = t0;
}
