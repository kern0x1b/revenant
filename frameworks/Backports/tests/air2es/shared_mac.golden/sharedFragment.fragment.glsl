#version 100
precision mediump float;
uniform highp float revenant_flip;
uniform vec2 revenant_target;
uniform vec4 lens_viewport;
uniform vec4 u_viewport;
uniform vec4 u_parameters;
uniform vec4 lens_parameters;
void main() {
    vec4 position;
    vec4 t0;
    vec2 t1;
    vec2 t2;
    vec2 t3;
    float t4;
    vec4 t5;
    float t6;
    vec4 t7;
    vec4 t8;
    vec4 t9;
    position = gl_FragCoord;
    position.y = revenant_flip > 0.0 ? revenant_target.y - gl_FragCoord.y : gl_FragCoord.y;
    t0 = (position - lens_viewport);
    t1 = vec2((t0).x, (t0).y);
    t2 = vec2((lens_viewport).z, (lens_viewport).z);
    t3 = (t1 / t2);
    t4 = ((t3).x * (u_viewport).z);
    t5 = vec4(0.0);
    t5.x = t4;
    t6 = ((t3).y * (lens_viewport).w);
    t7 = t5;
    t7.y = t6;
    t8 = vec4((t7).x, (t7).y, (u_parameters).x, 0.0);
    t9 = vec4((t8).x, (t8).y, (t8).z, (lens_parameters).y);
    gl_FragColor = t9;
}
