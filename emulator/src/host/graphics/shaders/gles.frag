// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Shade Vulkan fragments using the emulated GLES texture, color and
// alpha state.

#version 450

const int GL_ADD = 0x0104;
const int GL_BLEND = 0x0be2;
const int GL_SRC_COLOR = 0x0300;
const int GL_ONE_MINUS_SRC_COLOR = 0x0301;
const int GL_SRC_ALPHA = 0x0302;
const int GL_ONE_MINUS_SRC_ALPHA = 0x0303;
const int GL_REPLACE = 0x1e01;
const int GL_MODULATE = 0x2100;
const int GL_DECAL = 0x2101;
const int GL_TEXTURE = 0x1702;
const int GL_COMBINE = 0x8570;
const int GL_COMBINE_RGB = 0x8571;
const int GL_COMBINE_ALPHA = 0x8572;
const int GL_ADD_SIGNED = 0x8574;
const int GL_INTERPOLATE = 0x8575;
const int GL_CONSTANT = 0x8576;
const int GL_PRIMARY_COLOR = 0x8577;
const int GL_PREVIOUS = 0x8578;
const int GL_SUBTRACT = 0x84e7;
const int GL_DOT3_RGB = 0x86ae;
const int GL_DOT3_RGBA = 0x86af;

struct TextureEnvironment {
    ivec4 mode_combine_enabled;
    vec4 color;
    ivec4 rgb_sources;
    ivec4 alpha_sources;
    ivec4 rgb_operands;
    ivec4 alpha_operands;
    vec4 scales_rectangle;
    vec4 clamp_rectangle;
};

layout(std140, binding = 0) uniform FixedFunctionState {
    TextureEnvironment units[4];
    ivec4 target_flags;
} fixed_state;
layout(binding = 1) uniform sampler2D image0;
layout(binding = 2) uniform sampler2D image1;
layout(binding = 3) uniform sampler2D image2;
layout(binding = 4) uniform sampler2D image3;

layout(location = 0) in vec4 primary_color;
layout(location = 1) in vec2 texture0;
layout(location = 2) in vec2 texture1;
layout(location = 3) in vec2 texture2;
layout(location = 4) in vec2 texture3;
layout(location = 0) out vec4 output_color;

vec4 select_source(
    int source, vec4 texture_color, vec4 constant_color,
    vec4 primary, vec4 previous) {
    if (source == GL_TEXTURE) return texture_color;
    if (source == GL_CONSTANT) return constant_color;
    if (source == GL_PRIMARY_COLOR) return primary;
    if (source == GL_PREVIOUS) return previous;
    return vec4(0.0);
}

vec4 apply_rgb_operand(vec4 source, int operand) {
    if (operand == GL_SRC_ALPHA) return vec4(source.a);
    if (operand == GL_ONE_MINUS_SRC_ALPHA) return vec4(1.0 - source.a);
    if (operand == GL_ONE_MINUS_SRC_COLOR) return vec4(1.0) - source;
    return source;
}

float apply_alpha_operand(vec4 source, int operand) {
    return operand == GL_ONE_MINUS_SRC_ALPHA ? 1.0 - source.a : source.a;
}

float combine_component(int mode, float a, float b, float c) {
    if (mode == GL_REPLACE) return a;
    if (mode == GL_MODULATE) return a * b;
    if (mode == GL_ADD) return a + b;
    if (mode == GL_ADD_SIGNED) return a + b - 0.5;
    if (mode == GL_INTERPOLATE) return a * c + b * (1.0 - c);
    if (mode == GL_SUBTRACT) return a - b;
    return 0.0;
}

vec4 sample_image(
    sampler2D image, vec2 coordinate, bool rectangle_coordinates,
    bool clamp_coordinates, vec4 clamp_rectangle) {
    if (!rectangle_coordinates) return texture(image, coordinate);
    if (clamp_coordinates) {
        coordinate = clamp(
            coordinate, clamp_rectangle.xy, clamp_rectangle.zw);
    }
    vec2 size = vec2(textureSize(image, 0));
    vec2 texel = coordinate / size;
    return texture(image, texel);
}

vec4 apply_environment(
    TextureEnvironment environment, vec4 sampled, vec4 primary,
    vec4 previous) {
    int mode = environment.mode_combine_enabled.x;
    if (mode == GL_REPLACE) return sampled;
    if (mode == GL_MODULATE) return previous * sampled;
    if (mode == GL_DECAL) {
        return vec4(
            mix(previous.rgb, sampled.rgb, sampled.a), previous.a);
    }
    if (mode == GL_BLEND) {
        return vec4(
            mix(previous.rgb, environment.color.rgb, sampled.rgb),
            previous.a * sampled.a);
    }
    if (mode == GL_ADD) {
        return vec4(previous.rgb + sampled.rgb, previous.a * sampled.a);
    }
    if (mode != GL_COMBINE) return previous;

    vec4 rgb_arguments[3];
    float alpha_arguments[3];
    for (int argument = 0; argument < 3; ++argument) {
        vec4 rgb_source = select_source(
            environment.rgb_sources[argument], sampled,
            environment.color, primary, previous);
        rgb_arguments[argument] = apply_rgb_operand(
            rgb_source, environment.rgb_operands[argument]);
        vec4 alpha_source = select_source(
            environment.alpha_sources[argument], sampled,
            environment.color, primary, previous);
        alpha_arguments[argument] = apply_alpha_operand(
            alpha_source, environment.alpha_operands[argument]);
    }

    int rgb_mode = environment.mode_combine_enabled.y;
    int alpha_mode = environment.mode_combine_enabled.z;
    vec4 result = previous;
    if (rgb_mode == GL_DOT3_RGB || rgb_mode == GL_DOT3_RGBA) {
        float value = 4.0 * dot(
            rgb_arguments[0].rgb - vec3(0.5),
            rgb_arguments[1].rgb - vec3(0.5));
        result.rgb = vec3(value);
        if (rgb_mode == GL_DOT3_RGBA) result.a = value;
    } else {
        for (int component = 0; component < 3; ++component) {
            result[component] = combine_component(
                rgb_mode, rgb_arguments[0][component],
                rgb_arguments[1][component],
                rgb_arguments[2][component]);
        }
    }
    if (rgb_mode != GL_DOT3_RGBA) {
        result.a = combine_component(
            alpha_mode, alpha_arguments[0], alpha_arguments[1],
            alpha_arguments[2]);
    }
    result.rgb *= environment.scales_rectangle.x;
    result.a *= environment.scales_rectangle.y;
    return result;
}

vec4 apply_unit(int unit, sampler2D image, vec2 coordinate, vec4 previous) {
    TextureEnvironment environment = fixed_state.units[unit];
    if (environment.mode_combine_enabled.w == 0) return previous;
    vec4 sampled = sample_image(image, coordinate,
        environment.scales_rectangle.z != 0.0,
        environment.scales_rectangle.w != 0.0, environment.clamp_rectangle);
    return apply_environment(environment, sampled, primary_color, previous);
}

void main() {
    vec4 result = apply_unit(0, image0, texture0, primary_color);
    result = apply_unit(1, image1, texture1, result);
    result = apply_unit(2, image2, texture2, result);
    result = apply_unit(3, image3, texture3, result);
    if (fixed_state.target_flags.x != 0) result.rgb *= result.a;
    output_color = clamp(result, 0.0, 1.0);
}
