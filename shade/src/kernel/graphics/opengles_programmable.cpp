// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement guest GLES shader, program, uniform and attribute call
// adapters.

#include "kernel/opengles_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/userland_hle.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade {
namespace {

    constexpr std::string_view opengles_image {
        "/OpenGLES.framework/OpenGLES"
    };
    constexpr std::size_t maximum_shader_strings = 64U;
    constexpr std::size_t maximum_uniform_floats = 4096U;

    // Writes as much of an info log as capacity holds, and its length.
    bool write_log(UserlandHleCall& call, std::string_view text,
        std::uint32_t capacity, std::uint32_t length, std::uint32_t output)
    {
        const auto count =
            capacity == 0U ? std::size_t { }
                           : std::min<std::size_t>(text.size(), capacity - 1U);
        if (length != 0U &&
            !call.memory().write32(length, static_cast<std::uint32_t>(count)))
            return false;
        if (capacity == 0U || output == 0U)
            return true;
        for (std::size_t index = 0; index < count; ++index) {
            if (!call.memory().write8(output + static_cast<std::uint32_t>(index),
                    static_cast<std::uint8_t>(text[index])))
                return false;
        }
        return call.memory().write8(
            output + static_cast<std::uint32_t>(count), 0U);
    }

    // What glGet*iv answers for INFO_LOG_LENGTH: the log and its terminator.
    std::uint32_t log_length(std::string_view text)
    {
        return static_cast<std::uint32_t>(text.size() + 1U);
    }

    std::optional<std::vector<float>> read_floats(
        UserlandHleCall& call, std::uint32_t address, std::size_t count)
    {
        if (address == 0U || count > 16U)
            return std::nullopt;
        std::vector<float> values(count);
        for (std::size_t index = 0; index < count; ++index) {
            const auto word = call.memory().read32(
                address + static_cast<std::uint32_t>(index * 4U));
            if (!word)
                return std::nullopt;
            values[index] = std::bit_cast<float>(*word);
        }
        return values;
    }

    void set_previous_times_texture_alpha(
        GlesTextureEnvironment& environment, bool inverted)
    {
        environment.mode = gles_abi::combine;
        environment.combine_rgb = gles_abi::modulate;
        environment.combine_alpha = gles_abi::modulate;
        environment.rgb_sources[0] = gles_abi::previous;
        environment.rgb_sources[1] = gles_abi::texture_source;
        environment.rgb_operands[0] = gles_abi::source_color;
        environment.rgb_operands[1] = inverted
                                          ? gles_abi::one_minus_source_alpha
                                          : gles_abi::source_alpha;
        environment.alpha_sources[0] = gles_abi::previous;
        environment.alpha_sources[1] = gles_abi::texture_source;
        environment.alpha_operands[0] = gles_abi::source_alpha;
        environment.alpha_operands[1] = inverted
                                            ? gles_abi::one_minus_source_alpha
                                            : gles_abi::source_alpha;
    }

    void set_interpolation(GlesTextureEnvironment& environment,
        bool previous_is_first, float factor)
    {
        environment.mode = gles_abi::combine;
        environment.combine_rgb = gles_abi::interpolate;
        environment.combine_alpha = gles_abi::interpolate;
        environment.color = { factor, factor, factor, factor };
        environment.rgb_sources[0] =
            previous_is_first ? gles_abi::previous : gles_abi::texture_source;
        environment.rgb_sources[1] =
            previous_is_first ? gles_abi::texture_source : gles_abi::previous;
        environment.rgb_sources[2] = gles_abi::constant;
        environment.alpha_sources[0] = environment.rgb_sources[0];
        environment.alpha_sources[1] = environment.rgb_sources[1];
        environment.alpha_sources[2] = gles_abi::constant;
    }

    float scalar_uniform(const GlesProgramState& programs,
        std::uint32_t program, std::string_view name, float fallback)
    {
        const auto* uniform = programs.uniform(program, name);
        return uniform != nullptr && uniform->value_count != 0U
                   ? uniform->values[0]
                   : fallback;
    }

} // namespace

std::optional<OpenGlesHle::ProgrammableDrawState>
OpenGlesHle::programmable_draw_state(const ContextState& context) const
{
    if (context.current_program == 0U)
        return std::nullopt;
    const auto* program = programs_.program(context.current_program);
    if (program == nullptr || !program->linked)
        return std::nullopt;

    ProgrammableDrawState result;
    const auto array_for =
        [&](std::string_view semantic) -> const ContextState::ArrayPointer* {
        const auto location =
            programs_.attribute(context.current_program, semantic);
        if (!location)
            return nullptr;
        const auto array = context.generic_arrays.find(*location);
        return array == context.generic_arrays.end() ? nullptr : &array->second;
    };
    const auto* position = array_for("vertex_position");
    if (position == nullptr || !position->enabled)
        return std::nullopt;
    result.position_array = *position;
    if (const auto* color = array_for(program->interface_profile.color_attribute))
        result.color_array = *color;
    for (std::size_t unit = 0; unit < result.texture_arrays.size(); ++unit) {
        const auto suffix = std::to_string(unit);
        if (const auto* texture =
                array_for(std::string { "vertex_texcoord" } + suffix)) {
            result.texture_arrays[unit] = *texture;
        }
        if (const auto* transform = programs_.uniform(
                context.current_program, std::string { "texmat" } + suffix);
            transform != nullptr && transform->value_count >= 4U) {
            result.texture_transforms[unit] = { transform->values[0],
                transform->values[1], transform->values[2],
                transform->values[3] };
        } else if (const auto* scale = programs_.uniform(context.current_program,
                       std::string { "texscale" } + suffix);
                   scale != nullptr && scale->value_count >= 2U) {
            result.texture_transforms[unit][0] = scale->values[0];
            result.texture_transforms[unit][1] = scale->values[1];
        }
    }
    if (const auto* matrix =
            programs_.uniform(context.current_program, "vertex_matrix");
        matrix != nullptr && matrix->value_count == 16U) {
        result.vertex_matrix = GlesMatrix { matrix->values };
    }

    const auto fragment = programs_.shader_source(
        context.current_program, gles_abi::fragment_shader);
    for (std::size_t unit = 0; unit < result.sampled_textures.size(); ++unit) {
        const auto suffix = std::to_string(unit);
        const auto sampler = std::string { "texture" } + suffix;
        result.sampled_textures[unit] =
            fragment.find(std::string { "sampler2D " } + sampler) !=
                std::string_view::npos ||
            fragment.find(std::string { "sampler2DRect " } + sampler) !=
                std::string_view::npos;
        result.rectangle_textures[unit] =
            fragment.find(std::string { "sampler2DRect " } + sampler) !=
            std::string_view::npos;
    }

    const auto output = fragment.find(program->interface_profile.fragment_output);
    const auto expression = output == std::string_view::npos
                                ? std::string_view { }
                                : fragment.substr(output);
    auto& unit0 = result.texture_environments[0];
    auto& unit1 = result.texture_environments[1];
    const auto color = std::string { program->interface_profile.color_varying };
    if (expression.find("mix (s1, s0, function_arg)") !=
        std::string_view::npos) {
        unit0.mode = gles_abi::replace;
        set_interpolation(unit1, true,
            scalar_uniform(
                programs_, context.current_program, "function_arg", 0.0F));
    } else if (expression.find("mix (" + color + ", s0, function_arg)") !=
               std::string_view::npos) {
        set_interpolation(unit0, false,
            scalar_uniform(
                programs_, context.current_program, "function_arg", 0.0F));
    } else if (expression.find(color + " * s0 * (1.0 - s1.a)") !=
               std::string_view::npos) {
        set_previous_times_texture_alpha(unit1, true);
    } else if (expression.find(color + " * s0 * s1.a") != std::string_view::npos) {
        set_previous_times_texture_alpha(unit1, false);
    } else if (expression.find(color + " * s0.a") != std::string_view::npos) {
        set_previous_times_texture_alpha(unit0, false);
    } else if (expression.find("= s0") != std::string_view::npos) {
        unit0.mode = gles_abi::replace;
    }
    return result;
}

void OpenGlesHle::register_programmable_gles(UserlandHleRegistry& registry)
{
    const auto add = [&](std::string symbol,
                         UserlandHleRegistry::Handler handler) {
        registry.register_function(std::string { opengles_image },
            std::move(symbol), std::move(handler));
    };

    add("_glCreateShader", [this](UserlandHleCall& call) {
        const auto type = call.argument(0);
        if (type != gles_abi::vertex_shader &&
            type != gles_abi::fragment_shader) {
            set_gl_error(call, gles_abi::invalid_enum);
            call.set_return(0U);
            return;
        }
        call.set_return(programs_.create_shader(type));
    });
    add("_glShaderSource", [this](UserlandHleCall& call) {
        auto* shader = programs_.shader(call.argument(0));
        const auto count = static_cast<std::int32_t>(call.argument(1));
        const auto strings = call.argument(2);
        const auto lengths = call.argument(3);
        if (shader == nullptr) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        if (count < 0 ||
            static_cast<std::size_t>(count) > maximum_shader_strings ||
            (count != 0 && strings == 0U)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        std::string source;
        for (std::int32_t index = 0; index < count; ++index) {
            const auto address = call.memory().read32(
                strings + static_cast<std::uint32_t>(index) * 4U);
            if (!address || *address == 0U) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
            std::optional<std::string> part;
            if (lengths != 0U) {
                const auto raw_length = call.memory().read32(
                    lengths + static_cast<std::uint32_t>(index) * 4U);
                if (!raw_length) {
                    set_gl_error(call, gles_abi::invalid_value);
                    return;
                }
                const auto length = static_cast<std::int32_t>(*raw_length);
                if (length >= 0) {
                    if (static_cast<std::size_t>(length) >
                        glsl::maximum_source_bytes) {
                        set_gl_error(call, gles_abi::invalid_value);
                        return;
                    }
                    const auto bytes = call.memory().read_bytes(
                        *address, static_cast<std::size_t>(length));
                    if (bytes) {
                        part = std::string { reinterpret_cast<const char*>(
                                                 bytes->data()),
                            bytes->size() };
                    }
                }
            }
            if (!part) {
                part = call.memory().read_c_string(
                    *address, glsl::maximum_source_bytes);
            }
            if (!part || source.size() > glsl::maximum_source_bytes -
                                             part->size()) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
            source += *part;
        }
        shader->source = std::move(source);
        shader->compiled = false;
    });
    add("_glCompileShader", [this](UserlandHleCall& call) {
        auto* shader = programs_.shader(call.argument(0));
        if (shader == nullptr) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        programs_.compile_shader(call.argument(0));
    });
    add("_glDeleteShader", [this](UserlandHleCall& call) {
        if (call.argument(0) != 0U &&
            programs_.shader(call.argument(0)) == nullptr) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        programs_.delete_shader(call.argument(0));
    });
    add("_glCreateProgram", [this](UserlandHleCall& call) {
        call.set_return(programs_.create_program());
    });
    add("_glAttachShader", [this](UserlandHleCall& call) {
        if (!programs_.attach_shader(call.argument(0), call.argument(1)))
            set_gl_error(call, gles_abi::invalid_value);
    });
    add("_glBindAttribLocation", [this](UserlandHleCall& call) {
        const auto name = call.string_argument(2, 256U);
        if (!name || call.argument(1) >= gles_abi::maximum_vertex_attributes ||
            !programs_.bind_attribute(
                call.argument(0), call.argument(1), *name)) {
            set_gl_error(call, gles_abi::invalid_value);
        }
    });
    add("_glLinkProgram", [this](UserlandHleCall& call) {
        if (programs_.program(call.argument(0)) == nullptr) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        static_cast<void>(programs_.link(call.argument(0)));
    });
    add("_glUseProgram", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto name = call.argument(0);
        const auto* program = programs_.program(name);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (name != 0U && (program == nullptr || !program->linked)) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else {
            context->current_program = name;
        }
    });
    add("_glDeleteProgram", [this](UserlandHleCall& call) {
        const auto name = call.argument(0);
        if (name != 0U && programs_.program(name) == nullptr) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        for (auto& [context_name, context] : contexts_) {
            static_cast<void>(context_name);
            if (context.current_program == name)
                context.current_program = 0U;
        }
        programs_.delete_program(name);
    });
    add("_glGetUniformLocation", [this](UserlandHleCall& call) {
        const auto name = call.string_argument(1, 256U);
        if (!name) {
            set_gl_error(call, gles_abi::invalid_value);
            call.set_return(std::numeric_limits<std::uint32_t>::max());
            return;
        }
        call.set_return(static_cast<std::uint32_t>(
            programs_.uniform_location(call.argument(0), *name)));
    });
    add("_glGetAttribLocation", [this](UserlandHleCall& call) {
        const auto name = call.string_argument(1, 256U);
        const auto location =
            name ? programs_.attribute(call.argument(0), *name) : std::nullopt;
        call.set_return(
            location ? *location : std::numeric_limits<std::uint32_t>::max());
    });
    add("_glVertexAttribPointer", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto index = call.argument(0);
        const auto size = static_cast<std::int32_t>(call.argument(1));
        const auto type = call.argument(2);
        const auto normalized = call.argument(3) != 0U;
        const auto stride = static_cast<std::int32_t>(call.argument(4));
        const auto valid_type =
            type == gles_abi::byte || type == gles_abi::unsigned_byte ||
            type == gles_abi::short_type || type == gles_abi::unsigned_short ||
            type == gles_abi::fixed || type == gles_abi::float_type;
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (index >= gles_abi::maximum_vertex_attributes || size < 1 ||
                   size > 4 || stride < 0 || !valid_type) {
            set_gl_error(call,
                !valid_type ? gles_abi::invalid_enum : gles_abi::invalid_value);
        } else {
            const auto enabled = context->generic_arrays[index].enabled;
            context->generic_arrays[index] =
                ContextState::ArrayPointer { static_cast<std::uint32_t>(size),
                    type, static_cast<std::uint32_t>(stride), call.argument(5),
                    context->bound_array_buffer, normalized, enabled };
        }
    });
    const auto set_attribute_enabled = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (call.argument(0) >= gles_abi::maximum_vertex_attributes) {
            set_gl_error(call, gles_abi::invalid_value);
        } else {
            context->generic_arrays[call.argument(0)].enabled =
                call.symbol() == "_glEnableVertexAttribArray";
        }
    };
    add("_glEnableVertexAttribArray", set_attribute_enabled);
    add("_glDisableVertexAttribArray", set_attribute_enabled);

    // The glUniform calls come in three shapes: the values as arguments, as a
    // vector of them, or as matrices.
    enum class UniformForm { Scalars, Vector, Matrix };
    const auto interpreted_program = [this](UserlandHleCall& call) {
        const auto* context = current_context(call);
        const auto* program = context != nullptr && context->current_program != 0U
                                  ? programs_.program(context->current_program)
                                  : nullptr;
        return program != nullptr && program->interpreted;
    };
    const auto typed_uniform = [this](UserlandHleCall& call,
                                   GlesProgramState::UniformKind kind,
                                   std::size_t components, UniformForm form) {
        auto* context = current_context(call);
        const auto location = static_cast<std::int32_t>(call.argument(0));
        if (location == -1)
            return;
        const auto per_element =
            kind == GlesProgramState::UniformKind::Matrix
                ? components * components
                : components;
        std::size_t count = 1U;
        std::uint32_t pointer { };
        if (form != UniformForm::Scalars) {
            const auto requested = static_cast<std::int32_t>(call.argument(1));
            if (requested < 0) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
            if (requested == 0)
                return;
            count = static_cast<std::size_t>(requested);
            if (form == UniformForm::Matrix) {
                if (call.argument(2) != 0U) {
                    set_gl_error(call, gles_abi::invalid_value);
                    return;
                }
                pointer = call.argument(3);
            } else {
                pointer = call.argument(2);
            }
        }
        if (count > maximum_uniform_floats / per_element ||
            (form != UniformForm::Scalars && pointer == 0U)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        std::vector<float> values(count * per_element);
        for (std::size_t index = 0; index < values.size(); ++index) {
            std::optional<std::uint32_t> word;
            if (form == UniformForm::Scalars) {
                word = call.argument(static_cast<std::uint32_t>(1U + index));
            } else {
                word = call.memory().read32(
                    pointer + static_cast<std::uint32_t>(index * 4U));
            }
            if (!word) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
            values[index] =
                kind == GlesProgramState::UniformKind::Integer
                    ? static_cast<float>(static_cast<std::int32_t>(*word))
                    : std::bit_cast<float>(*word);
        }
        switch (programs_.set_uniforms(context->current_program, location, kind,
            components, count, values)) {
        case GlesProgramState::UniformResult::Set:
            break;
        case GlesProgramState::UniformResult::InvalidValue:
            set_gl_error(call, gles_abi::invalid_value);
            break;
        case GlesProgramState::UniformResult::InvalidOperation:
            set_gl_error(call, gles_abi::invalid_operation);
            break;
        }
    };
    // A program that runs in the interpreter takes every form; the others keep
    // the few calls their adapter used, and the rest stay no-ops.
    const auto add_uniform = [&](std::string symbol,
                                 GlesProgramState::UniformKind kind,
                                 std::size_t components, UniformForm form,
                                 UserlandHleRegistry::Handler legacy) {
        add(std::move(symbol), [=](UserlandHleCall& call) {
            if (interpreted_program(call))
                typed_uniform(call, kind, components, form);
            else if (legacy)
                legacy(call);
        });
    };
    const auto set_float_uniform = [this](UserlandHleCall& call,
                                       std::size_t components) {
        auto* context = current_context(call);
        const auto location = static_cast<std::int32_t>(call.argument(0));
        const auto count = static_cast<std::int32_t>(call.argument(1));
        if (context == nullptr || context->current_program == 0U) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (location == -1)
            return;
        if (count < 0 || count > 1) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        if (count == 0)
            return;
        const auto values = read_floats(call, call.argument(2), components);
        if (!values || !programs_.set_uniform(
                           context->current_program, location, *values)) {
            set_gl_error(call, gles_abi::invalid_operation);
        }
    };
    add_uniform("_glUniform2fv", GlesProgramState::UniformKind::Float, 2U,
        UniformForm::Vector, [set_float_uniform](UserlandHleCall& call) {
            set_float_uniform(call, 2U);
        });
    add_uniform("_glUniform4fv", GlesProgramState::UniformKind::Float, 4U,
        UniformForm::Vector, [set_float_uniform](UserlandHleCall& call) {
            set_float_uniform(call, 4U);
        });
    add_uniform("_glUniform1f", GlesProgramState::UniformKind::Float, 1U,
        UniformForm::Scalars, [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto location = static_cast<std::int32_t>(call.argument(0));
        const std::array value { std::bit_cast<float>(call.argument(1)) };
        if (location == -1)
            return;
        if (context == nullptr || context->current_program == 0U ||
            !programs_.set_uniform(context->current_program, location, value)) {
            set_gl_error(call, gles_abi::invalid_operation);
        }
    });
    add_uniform("_glUniform1i", GlesProgramState::UniformKind::Integer, 1U,
        UniformForm::Scalars, [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto location = static_cast<std::int32_t>(call.argument(0));
        if (location == -1)
            return;
        if (context == nullptr || context->current_program == 0U ||
            !programs_.set_uniform(context->current_program, location,
                static_cast<std::int32_t>(call.argument(1)))) {
            set_gl_error(call, gles_abi::invalid_operation);
        }
    });
    add_uniform("_glUniformMatrix4fv", GlesProgramState::UniformKind::Matrix,
        4U, UniformForm::Matrix, [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto location = static_cast<std::int32_t>(call.argument(0));
        const auto count = static_cast<std::int32_t>(call.argument(1));
        if (context == nullptr || context->current_program == 0U) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (location == -1)
            return;
        if (count == 0)
            return;
        if (count != 1 || call.argument(2) != 0U) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto values = read_floats(call, call.argument(3), 16U);
        if (!values || !programs_.set_uniform(
                           context->current_program, location, *values)) {
            set_gl_error(call, gles_abi::invalid_operation);
        }
    });

    for (std::size_t width = 1U; width <= 4U; ++width) {
        const auto digit = std::to_string(width);
        if (width != 1U) {
            add_uniform("_glUniform" + digit + "f",
                GlesProgramState::UniformKind::Float, width,
                UniformForm::Scalars, nullptr);
            add_uniform("_glUniform" + digit + "i",
                GlesProgramState::UniformKind::Integer, width,
                UniformForm::Scalars, nullptr);
        }
        if (width != 2U && width != 4U) {
            add_uniform("_glUniform" + digit + "fv",
                GlesProgramState::UniformKind::Float, width,
                UniformForm::Vector, nullptr);
        }
        add_uniform("_glUniform" + digit + "iv",
            GlesProgramState::UniformKind::Integer, width, UniformForm::Vector,
            nullptr);
    }
    for (std::size_t order = 2U; order <= 3U; ++order) {
        add_uniform("_glUniformMatrix" + std::to_string(order) + "fv",
            GlesProgramState::UniformKind::Matrix, order, UniformForm::Matrix,
            nullptr);
    }

    add("_glGetShaderiv", [this](UserlandHleCall& call) {
        const auto* shader = programs_.shader(call.argument(0));
        const auto output = call.argument(2);
        if (shader == nullptr || output == 0U) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        std::uint32_t value { };
        switch (call.argument(1)) {
        case gles_abi::shader_type:
            value = shader->type;
            break;
        case gles_abi::compile_status:
            value = shader->compiled ? 1U : 0U;
            break;
        case gles_abi::delete_status:
            value = shader->delete_pending ? 1U : 0U;
            break;
        case gles_abi::info_log_length:
            value = log_length(shader->info_log);
            break;
        case gles_abi::shader_source_length:
            value = static_cast<std::uint32_t>(shader->source.size() + 1U);
            break;
        default:
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (!call.memory().write32(output, value))
            set_gl_error(call, gles_abi::invalid_value);
    });
    add("_glGetProgramiv", [this](UserlandHleCall& call) {
        const auto* program = programs_.program(call.argument(0));
        const auto output = call.argument(2);
        if (program == nullptr || output == 0U) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        std::uint32_t value { };
        switch (call.argument(1)) {
        case gles_abi::link_status:
        case gles_abi::validate_status:
            value = program->linked ? 1U : 0U;
            break;
        case gles_abi::delete_status:
            value = program->delete_pending ? 1U : 0U;
            break;
        case gles_abi::info_log_length:
            value = log_length(program->info_log);
            break;
        case gles_abi::attached_shaders:
            value = static_cast<std::uint32_t>(program->shaders.size());
            break;
        case gles_abi::active_uniforms:
            value = static_cast<std::uint32_t>(
                program->interpreted
                    ? programs_.active_uniform_count(call.argument(0))
                    : program->uniforms.size());
            break;
        case gles_abi::active_attributes:
            value = static_cast<std::uint32_t>(
                program->interpreted ? program->linked_attributes.size()
                                     : program->attributes.size());
            break;
        default:
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (!call.memory().write32(output, value))
            set_gl_error(call, gles_abi::invalid_value);
    });
    const auto get_info_log = [this](UserlandHleCall& call) {
        const auto* shader = call.symbol() == "_glGetShaderInfoLog"
                                 ? programs_.shader(call.argument(0))
                                 : nullptr;
        const auto* program = call.symbol() == "_glGetShaderInfoLog"
                                  ? nullptr
                                  : programs_.program(call.argument(0));
        if (shader == nullptr && program == nullptr) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        if (!write_log(call,
                shader != nullptr ? std::string_view { shader->info_log }
                                  : std::string_view { program->info_log },
                call.argument(1), call.argument(2), call.argument(3))) {
            set_gl_error(call, gles_abi::invalid_value);
        }
    };
    add("_glGetShaderInfoLog", get_info_log);
    add("_glGetProgramInfoLog", get_info_log);
    add("_glValidateProgram", [this](UserlandHleCall& call) {
        if (programs_.program(call.argument(0)) == nullptr)
            set_gl_error(call, gles_abi::invalid_value);
    });
}

} // namespace shade
