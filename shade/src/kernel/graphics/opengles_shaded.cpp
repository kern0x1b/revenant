// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Run guest GLSL ES vertex shaders and draw their triangles with the guest's
// fragment shader.

#include "kernel/opengles_hle.hpp"

#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"
#include "graphics/gles_shaded_rasterizer.hpp"
#include "graphics/glsl_es.hpp"

#include <algorithm>
#include <array>
#include <string>

namespace shade {
namespace {

    constexpr std::size_t maximum_shader_traces = 16U;

} // namespace

std::optional<OpenGlesHle::ShadedDraw> OpenGlesHle::shade_vertices(
    UserlandHleCall& call, const ContextState& context,
    const GlesProgramState::Program& program,
    std::span<const std::uint32_t> indices, std::string& error) const
{
    ShadedDraw result;
    glsl::Instance vertex { program.vertex_module };
    result.fragment = std::make_unique<glsl::Instance>(program.fragment_module);
    for (const auto& slot : program.uniform_slots) {
        for (auto* instance : { &vertex, result.fragment.get() }) {
            const auto* variable = instance->module().find(slot.variable);
            if (variable == nullptr ||
                variable->storage != glsl::Storage::Uniform ||
                variable->type != slot.type)
                continue;
            const auto values = instance->values(*variable);
            if (slot.element < values.size())
                values[slot.element] = slot.value;
        }
    }

    struct Attribute {
        const glsl::Variable* variable { };
        std::uint32_t location { };
    };
    std::vector<Attribute> attributes;
    for (const auto& variable : vertex.module().variables()) {
        if (variable.storage != glsl::Storage::Attribute)
            continue;
        const auto location = program.linked_attributes.find(variable.name);
        if (location != program.linked_attributes.end())
            attributes.push_back({ &variable, location->second });
    }

    GlesVaryingLayout layout;
    if (!layout_varyings(vertex.module(), result.fragment->module(), layout,
            error))
        return std::nullopt;
    result.varyings = layout.fragment;

    const auto* position = vertex.module().find("gl_Position");
    if (position == nullptr) {
        error = "the vertex shader has no gl_Position";
        return std::nullopt;
    }
    result.vertices.reserve(indices.size());
    for (const auto index : indices) {
        for (const auto& attribute : attributes) {
            // An attribute no array supplies reads (0, 0, 0, 1).
            std::array<float, 4> raw { 0.0F, 0.0F, 0.0F, 1.0F };
            const auto array = context.generic_arrays.find(attribute.location);
            if (array != context.generic_arrays.end() && array->second.enabled &&
                !read_array(call, array->second, index, raw,
                    array->second.normalized)) {
                error = "attribute '" + attribute.variable->name +
                        "' could not be read";
                return std::nullopt;
            }
            auto& value = vertex.values(*attribute.variable)[0];
            const auto width = glsl::component_count(attribute.variable->type);
            for (std::size_t k = 0; k < std::min<std::size_t>(width, 4U); ++k)
                value.v[k] = raw[k];
        }
        if (!vertex.run(nullptr)) {
            error = vertex.error();
            return std::nullopt;
        }
        GlesShadedVertex out;
        const auto& clip = vertex.values(*position)[0];
        std::copy_n(clip.v.begin(), 4, out.position.begin());
        if (!collect_varyings(vertex, layout, out.varyings, error))
            return std::nullopt;
        result.vertices.push_back(std::move(out));
    }
    return result;
}

void OpenGlesHle::trace_shader_failure(
    UserlandHleCall& call, const std::string& reason)
{
    if (shader_trace_count_ >= maximum_shader_traces)
        return;
    call.output().write("[opengles] " + reason +
                        " pid=" + std::to_string(call.process_id()) + "\n");
    ++shader_trace_count_;
}

bool OpenGlesHle::rasterize_shaded(UserlandHleCall& call,
    const RenderTargetBinding& binding, DisplayFrame& target,
    const GlesRasterState& state, ShadedDraw& shaded, std::uint32_t mode)
{
    const auto trace = [&](const std::string& reason) {
        trace_shader_failure(call, "shader draw failed: " + reason);
    };
    // The shaders read the textures' CPU images and the target's current
    // pixels, so work the GPU still holds is brought back first.
    for (const auto& unit : state.texture_units) {
        if (unit.enabled &&
            !resources_.synchronize_texture_to_cpu(unit.texture, 0U, *renderer_)) {
            trace("a sampled texture could not be read back");
            return false;
        }
    }
    if (!load_target_pixels(binding, target)) {
        trace("the render target could not be read back");
        return false;
    }
    std::string error;
    if (!GlesShadedRasterizer::draw(target, shaded.vertices, mode, state,
            *shaded.fragment, shaded.varyings, error)) {
        trace(error);
        return false;
    }
    if (!commit_render_target(call, binding, std::move(target))) {
        trace("the render target could not be written");
        return false;
    }
    renderer_->invalidate(binding.key);
    return true;
}

} // namespace shade
