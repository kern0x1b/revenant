// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest-visible GLES shader, program and uniform state.

#include "graphics/gles_program_state.hpp"

#include "graphics/gles_abi.hpp"
#include "graphics/gles_shaded_rasterizer.hpp"

#include <algorithm>
#include <limits>
#include <utility>

namespace shade {

void GlesProgramState::reset()
{
    shaders_.clear();
    programs_.clear();
    next_shader_ = 1U;
    next_program_ = 1U;
}

std::uint32_t GlesProgramState::create_shader(std::uint32_t type)
{
    const auto name = next_shader_++;
    Shader value;
    value.type = type;
    shaders_.emplace(name, std::move(value));
    return name;
}

GlesProgramState::Shader* GlesProgramState::shader(std::uint32_t name)
{
    const auto found = shaders_.find(name);
    return found == shaders_.end() ? nullptr : &found->second;
}

const GlesProgramState::Shader* GlesProgramState::shader(
    std::uint32_t name) const
{
    const auto found = shaders_.find(name);
    return found == shaders_.end() ? nullptr : &found->second;
}

void GlesProgramState::compile_shader(std::uint32_t name)
{
    auto* value = shader(name);
    if (value == nullptr)
        return;
    value->module.reset();
    value->info_log.clear();
    value->compiled = false;
    if (value->source.empty()) {
        value->info_log = "ERROR: 0:0: the shader has no source\n";
        return;
    }
    const auto stage = value->type == gles_abi::vertex_shader
                           ? glsl::Stage::Vertex
                           : glsl::Stage::Fragment;
    value->module =
        glsl::Module::compile(value->source, stage, value->info_log);
    if (value->module) {
        value->compiled = true;
        return;
    }
    // Compositor shaders were taken on the strength of their main and their
    // conventions alone, and the renderer's adapter still takes them.
    value->compiled =
        GlesProgramInterfaceProfile::recognizes(value->source) &&
        value->source.find("void main") != std::string::npos;
}

void GlesProgramState::delete_shader(std::uint32_t name)
{
    auto* value = shader(name);
    if (value == nullptr)
        return;
    value->delete_pending = true;
    collect_deleted_shaders();
}

std::uint32_t GlesProgramState::create_program()
{
    const auto name = next_program_++;
    programs_.try_emplace(name);
    return name;
}

GlesProgramState::Program* GlesProgramState::program(std::uint32_t name)
{
    const auto found = programs_.find(name);
    return found == programs_.end() ? nullptr : &found->second;
}

const GlesProgramState::Program* GlesProgramState::program(
    std::uint32_t name) const
{
    const auto found = programs_.find(name);
    return found == programs_.end() ? nullptr : &found->second;
}

void GlesProgramState::delete_program(std::uint32_t name)
{
    programs_.erase(name);
    collect_deleted_shaders();
}

bool GlesProgramState::attach_shader(
    std::uint32_t program_name, std::uint32_t shader_name)
{
    auto* program_value = program(program_name);
    if (program_value == nullptr || shader(shader_name) == nullptr)
        return false;
    if (std::find(program_value->shaders.begin(), program_value->shaders.end(),
            shader_name) == program_value->shaders.end()) {
        program_value->shaders.push_back(shader_name);
    }
    program_value->linked = false;
    return true;
}

bool GlesProgramState::bind_attribute(
    std::uint32_t program_name, std::uint32_t index, std::string name)
{
    auto* program_value = program(program_name);
    if (program_value == nullptr || name.empty())
        return false;
    program_value->attributes.insert_or_assign(std::move(name), index);
    return true;
}

bool GlesProgramState::link(std::uint32_t program_name)
{
    auto* program_value = program(program_name);
    if (program_value == nullptr)
        return false;
    const auto compiled_shader = [&](std::uint32_t type) -> const Shader* {
        for (const auto shader_name : program_value->shaders) {
            const auto* value = shader(shader_name);
            if (value != nullptr && value->type == type && value->compiled)
                return value;
        }
        return nullptr;
    };
    const auto* vertex = compiled_shader(gles_abi::vertex_shader);
    const auto* fragment = compiled_shader(gles_abi::fragment_shader);
    program_value->interpreted = false;
    program_value->vertex_module.reset();
    program_value->fragment_module.reset();
    program_value->linked_attributes.clear();
    program_value->uniform_slots.clear();
    program_value->info_log.clear();
    if (vertex == nullptr || fragment == nullptr) {
        program_value->linked = false;
        program_value->info_log =
            "ERROR: a program needs a compiled vertex shader and a compiled "
            "fragment shader\n";
        return false;
    }
    if (vertex->module && fragment->module &&
        !GlesProgramInterfaceProfile::recognizes(vertex->source) &&
        !GlesProgramInterfaceProfile::recognizes(fragment->source)) {
        program_value->linked = link_interpreted(*program_value, *vertex,
            *fragment);
        return program_value->linked;
    }
    program_value->linked = true;
    if (program_value->linked) {
        program_value->interface_profile =
            GlesProgramInterfaceProfile::from_sources(
                shader_source(program_name, gles_abi::vertex_shader),
                shader_source(program_name, gles_abi::fragment_shader));
    }
    return program_value->linked;
}

bool GlesProgramState::link_interpreted(
    Program& program_value, const Shader& vertex, const Shader& fragment)
{
    const auto fail = [&](std::string message) {
        program_value.info_log = "ERROR: " + std::move(message) + "\n";
        return false;
    };
    // Attributes take the location glBindAttribLocation gave their name, and
    // the lowest free one otherwise.
    std::map<std::string, std::uint32_t, std::less<>> attributes;
    std::array<std::string, gles_abi::maximum_vertex_attributes> taken;
    for (const auto& variable : vertex.module->variables()) {
        if (variable.storage != glsl::Storage::Attribute)
            continue;
        const auto bound = program_value.attributes.find(variable.name);
        if (bound == program_value.attributes.end())
            continue;
        if (bound->second >= taken.size())
            return fail("attribute '" + variable.name +
                        "' is bound beyond the attributes there are");
        if (!taken[bound->second].empty())
            return fail("attributes '" + taken[bound->second] + "' and '" +
                        variable.name + "' are bound to one location");
        taken[bound->second] = variable.name;
        attributes[variable.name] = bound->second;
    }
    for (const auto& variable : vertex.module->variables()) {
        if (variable.storage != glsl::Storage::Attribute ||
            attributes.contains(variable.name))
            continue;
        const auto free = std::find_if(taken.begin(), taken.end(),
            [](const std::string& name) { return name.empty(); });
        if (free == taken.end())
            return fail("the vertex shader uses more attributes than the "
                        "device has");
        *free = variable.name;
        attributes[variable.name] = static_cast<std::uint32_t>(
            std::distance(taken.begin(), free));
    }
    // A varying the fragment shader reads must be declared by the vertex
    // shader with the same name, type and array size.
    GlesVaryingLayout layout;
    std::string varying_error;
    if (!layout_varyings(
            *vertex.module, *fragment.module, layout, varying_error))
        return fail(varying_error);
    std::vector<UniformSlot> slots;
    for (const auto* module : { vertex.module.get(), fragment.module.get() }) {
        for (const auto& variable : module->variables()) {
            if (variable.storage != glsl::Storage::Uniform)
                continue;
            const auto known = std::find_if(slots.begin(), slots.end(),
                [&](const UniformSlot& slot) {
                    return slot.variable == variable.name;
                });
            if (known != slots.end()) {
                if (known->type != variable.type ||
                    known->array_size != variable.array_size)
                    return fail("uniform '" + variable.name +
                                "' is declared with different types in the "
                                "two shaders");
                continue;
            }
            const auto elements = std::max(variable.array_size, 1U);
            for (std::uint32_t element = 0; element < elements; ++element) {
                UniformSlot slot;
                slot.variable = variable.name;
                slot.name = variable.array_size == 0U
                                ? variable.name
                                : variable.name + "[" +
                                      std::to_string(element) + "]";
                slot.type = variable.type;
                slot.array_size = variable.array_size;
                slot.element = element;
                slot.value.type = variable.type;
                slots.push_back(std::move(slot));
            }
        }
    }
    program_value.interpreted = true;
    program_value.vertex_module = vertex.module;
    program_value.fragment_module = fragment.module;
    program_value.linked_attributes = std::move(attributes);
    program_value.uniform_slots = std::move(slots);
    return true;
}

std::optional<std::uint32_t> GlesProgramState::attribute(
    std::uint32_t program_name, std::string_view name) const
{
    const auto* program_value = program(program_name);
    if (program_value == nullptr || !program_value->linked)
        return std::nullopt;
    const auto& table = program_value->interpreted
                            ? program_value->linked_attributes
                            : program_value->attributes;
    const auto found = table.find(name);
    return found == table.end()
               ? std::nullopt
               : std::optional<std::uint32_t> { found->second };
}

std::int32_t GlesProgramState::uniform_location(
    std::uint32_t program_name, std::string_view name)
{
    auto* program_value = program(program_name);
    if (program_value == nullptr || !program_value->linked || name.empty())
        return -1;
    if (program_value->interpreted) {
        // An array answers to its own name as well as to name[0].
        const auto& slots = program_value->uniform_slots;
        const auto found = std::find_if(
            slots.begin(), slots.end(), [&](const UniformSlot& slot) {
                return slot.name == name ||
                       (slot.element == 0U && slot.array_size != 0U &&
                           slot.variable == name);
            });
        return found == slots.end()
                   ? -1
                   : static_cast<std::int32_t>(
                         std::distance(slots.begin(), found));
    }
    const auto declared = std::any_of(program_value->shaders.begin(),
        program_value->shaders.end(), [&](std::uint32_t shader_name) {
            const auto* value = shader(shader_name);
            return value != nullptr &&
                   value->source.find(name) != std::string::npos;
        });
    if (!declared)
        return -1;
    if (const auto found = program_value->uniform_locations.find(name);
        found != program_value->uniform_locations.end()) {
        return found->second;
    }
    if (program_value->uniform_locations.size() >=
        static_cast<std::size_t>(std::numeric_limits<std::int32_t>::max())) {
        return -1;
    }
    const auto location =
        static_cast<std::int32_t>(program_value->uniform_locations.size());
    auto owned_name = std::string { name };
    program_value->uniform_locations.emplace(owned_name, location);
    Uniform uniform;
    uniform.name = std::move(owned_name);
    program_value->uniforms.emplace(location, std::move(uniform));
    return location;
}

bool GlesProgramState::set_uniform(std::uint32_t program_name,
    std::int32_t location, std::span<const float> values)
{
    auto* program_value = program(program_name);
    if (program_value == nullptr || !program_value->linked)
        return false;
    const auto found = program_value->uniforms.find(location);
    if (found == program_value->uniforms.end() ||
        values.size() > found->second.values.size()) {
        return false;
    }
    std::copy(values.begin(), values.end(), found->second.values.begin());
    found->second.value_count = values.size();
    found->second.integer.reset();
    return true;
}

bool GlesProgramState::set_uniform(
    std::uint32_t program_name, std::int32_t location, std::int32_t value)
{
    auto* program_value = program(program_name);
    if (program_value == nullptr || !program_value->linked)
        return false;
    const auto found = program_value->uniforms.find(location);
    if (found == program_value->uniforms.end())
        return false;
    found->second.integer = value;
    found->second.value_count = 0U;
    return true;
}

GlesProgramState::UniformResult GlesProgramState::set_uniforms(
    std::uint32_t program_name, std::int32_t location, UniformKind kind,
    std::size_t components, std::size_t count, std::span<const float> values)
{
    auto* program_value = program(program_name);
    if (program_value == nullptr || !program_value->linked ||
        !program_value->interpreted)
        return UniformResult::InvalidOperation;
    auto& slots = program_value->uniform_slots;
    if (location < 0 || static_cast<std::size_t>(location) >= slots.size())
        return UniformResult::InvalidOperation;
    const auto first = static_cast<std::size_t>(location);
    const auto per_element =
        kind == UniformKind::Matrix ? components * components : components;
    if (count == 0U || values.size() < count * per_element)
        return UniformResult::InvalidValue;
    const auto& target = slots[first];
    const bool array = target.array_size != 0U;
    if (count > 1U && !array)
        return UniformResult::InvalidOperation;
    // The type the call writes, by the family of the uniform's type.
    const auto accepts = [&](glsl::TypeId type) {
        if (kind == UniformKind::Matrix) {
            return type == (components == 2U   ? glsl::TypeId::Mat2
                               : components == 3U ? glsl::TypeId::Mat3
                                                  : glsl::TypeId::Mat4);
        }
        if (glsl::component_count(type) != components || glsl::is_matrix_type(type))
            return false;
        if (type == glsl::TypeId::Sampler2D)
            return kind == UniformKind::Integer;
        const auto family = glsl::scalar_kind(type);
        if (family == glsl::ScalarKind::Bool)
            return true;
        return (family == glsl::ScalarKind::Int) ==
               (kind == UniformKind::Integer);
    };
    if (!accepts(target.type))
        return UniformResult::InvalidOperation;
    // Elements past the end of the array are dropped.
    const auto usable = std::min(count,
        static_cast<std::size_t>(std::max(target.array_size, 1U) -
                                 target.element));
    for (std::size_t element = 0; element < usable; ++element) {
        auto& slot = slots[first + element];
        const auto from = values.subspan(element * per_element, per_element);
        const bool boolean =
            glsl::scalar_kind(slot.type) == glsl::ScalarKind::Bool;
        for (std::size_t i = 0; i < per_element; ++i)
            slot.value.v[i] = boolean ? (from[i] != 0.0F ? 1.0F : 0.0F)
                                      : from[i];
    }
    return UniformResult::Set;
}

std::size_t GlesProgramState::active_uniform_count(
    std::uint32_t program_name) const
{
    const auto* program_value = program(program_name);
    if (program_value == nullptr)
        return 0U;
    return static_cast<std::size_t>(
        std::count_if(program_value->uniform_slots.begin(),
            program_value->uniform_slots.end(),
            [](const UniformSlot& slot) { return slot.element == 0U; }));
}

const GlesProgramState::Uniform* GlesProgramState::uniform(
    std::uint32_t program_name, std::string_view name) const
{
    const auto* program_value = program(program_name);
    if (program_value == nullptr)
        return nullptr;
    const auto location = program_value->uniform_locations.find(name);
    if (location == program_value->uniform_locations.end())
        return nullptr;
    const auto value = program_value->uniforms.find(location->second);
    return value == program_value->uniforms.end() ? nullptr : &value->second;
}

std::string_view GlesProgramState::shader_source(
    std::uint32_t program_name, std::uint32_t type) const
{
    const auto* program_value = program(program_name);
    if (program_value == nullptr)
        return { };
    for (const auto shader_name : program_value->shaders) {
        const auto* value = shader(shader_name);
        if (value != nullptr && value->type == type)
            return value->source;
    }
    return { };
}

void GlesProgramState::collect_deleted_shaders()
{
    for (auto candidate = shaders_.begin(); candidate != shaders_.end();) {
        const auto attached = std::any_of(
            programs_.begin(), programs_.end(), [&](const auto& program_entry) {
                return std::find(program_entry.second.shaders.begin(),
                           program_entry.second.shaders.end(),
                           candidate->first) !=
                       program_entry.second.shaders.end();
            });
        if (candidate->second.delete_pending && !attached) {
            candidate = shaders_.erase(candidate);
        } else {
            ++candidate;
        }
    }
}

} // namespace shade
