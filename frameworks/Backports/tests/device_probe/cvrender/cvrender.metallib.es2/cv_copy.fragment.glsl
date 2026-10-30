#version 100
precision highp float;
precision highp int;
uniform highp float revenant_flip;
uniform vec2 revenant_target;
uniform vec2 upperLeft;
uniform vec2 upperRight;
uniform vec2 lowerLeft;
uniform vec2 lowerRight;
uniform sampler2D src;
void main() {
    vec4 position;
    vec2 t0;
    vec2 t1;
    vec2 t2;
    vec2 t3;
    vec2 t4;
    vec2 t5;
    vec2 t6;
    vec4 t7;
    vec4 t8;
    position = gl_FragCoord;
    position.y = revenant_flip > 0.0 ? revenant_target.y - gl_FragCoord.y : gl_FragCoord.y;
    t0 = vec2((position).x, (position).y);
    t1 = (t0 * vec2(0.015625, 0.015625));
    t2 = vec2((t1).x, (t1).x);
    t3 = mix(upperLeft, upperRight, t2);
    t4 = mix(lowerLeft, lowerRight, t2);
    t5 = vec2((t1).y, (t1).y);
    t6 = mix(t3, t4, t5);
    t7 = texture2D(src, t6);
    t8 = vec4(t7);
    gl_FragColor = t8;
}
