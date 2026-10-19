// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest-visible GLES shader, program and uniform state.

#pragma once

#include "graphics/gles_program_interface_profile.hpp"
#include "graphics/glsl_es.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade {

// Owns the API-visible GLES2 shader/program objects. A shader that is valid
// GLSL ES 1.00 is compiled to a glsl::Module and its program runs in the
// interpreter. Compositor shaders the legacy adapter recognises, and shaders
// it can express in fixed-function state, keep their source only: the renderer
// executes those, and this store preserves the declarations and values needed
// to adapt their conventional programmable inputs to that pipeline.
class GlesProgramState {
public:
    struct Shader {
        std::uint32_t type { };
        std::string source;
        bool compiled { };
        bool delete_pending { };
        std::shared_ptr<const glsl::Module> module;
        std::string info_log;
    };

    struct Uniform {
        std::string name;
        std::array<float, 16> values { };
        std::size_t value_count { };
        std::optional<std::int32_t> integer;
    };

    // One location of an interpreted program: a uniform, or one element of an
    // array uniform.
    struct UniformSlot {
        std::string name;
        std::string variable;
        glsl::TypeId type { glsl::TypeId::Float };
        std::uint32_t array_size { };
        std::uint32_t element { };
        glsl::Value value;
    };

    struct Program {
        std::vector<std::uint32_t> shaders;
        std::map<std::string, std::uint32_t, std::less<>> attributes;
        std::map<std::string, std::int32_t, std::less<>> uniform_locations;
        std::map<std::int32_t, Uniform> uniforms;
        GlesProgramInterfaceProfile interface_profile;
        bool linked { };
        bool delete_pending { };
        // Set at link when both shaders are valid GLSL ES and neither is a
        // compositor shader: the program then runs in the interpreter.
        bool interpreted { };
        std::shared_ptr<const glsl::Module> vertex_module;
        std::shared_ptr<const glsl::Module> fragment_module;
        std::map<std::string, std::uint32_t, std::less<>> linked_attributes;
        std::vector<UniformSlot> uniform_slots;
        std::string info_log;
    };

    // The shape of a glUniform call.
    enum class UniformKind : std::uint8_t { Float, Integer, Matrix };
    enum class UniformResult : std::uint8_t {
        Set,
        InvalidOperation,
        InvalidValue,
    };

    void reset();

    [[nodiscard]] std::uint32_t create_shader(std::uint32_t type);
    [[nodiscard]] Shader* shader(std::uint32_t name);
    [[nodiscard]] const Shader* shader(std::uint32_t name) const;
    void delete_shader(std::uint32_t name);
    // Compiles the source of a shader. A shader that is not valid GLSL ES 1.00
    // does not compile, with the compiler's reason in its info log, unless it
    // is a shader the legacy adapter takes (compositor conventions in its
    // source), which compiles as it always did.
    void compile_shader(std::uint32_t name);

    [[nodiscard]] std::uint32_t create_program();
    [[nodiscard]] Program* program(std::uint32_t name);
    [[nodiscard]] const Program* program(std::uint32_t name) const;
    void delete_program(std::uint32_t name);

    [[nodiscard]] bool attach_shader(
        std::uint32_t program, std::uint32_t shader);
    [[nodiscard]] bool bind_attribute(
        std::uint32_t program, std::uint32_t index, std::string name);
    [[nodiscard]] bool link(std::uint32_t program);
    [[nodiscard]] std::optional<std::uint32_t> attribute(
        std::uint32_t program, std::string_view name) const;
    [[nodiscard]] std::int32_t uniform_location(
        std::uint32_t program, std::string_view name);
    [[nodiscard]] bool set_uniform(std::uint32_t program, std::int32_t location,
        std::span<const float> values);
    [[nodiscard]] bool set_uniform(
        std::uint32_t program, std::int32_t location, std::int32_t value);
    // Stores count elements of components floats (or integers, or matrices of
    // that order), starting at the location, in an interpreted program.
    [[nodiscard]] UniformResult set_uniforms(std::uint32_t program,
        std::int32_t location, UniformKind kind, std::size_t components,
        std::size_t count, std::span<const float> values);
    [[nodiscard]] const Uniform* uniform(
        std::uint32_t program, std::string_view name) const;
    [[nodiscard]] std::string_view shader_source(
        std::uint32_t program, std::uint32_t type) const;
    // The number of distinct uniform variables an interpreted program has.
    [[nodiscard]] std::size_t active_uniform_count(std::uint32_t program) const;

private:
    void collect_deleted_shaders();
    [[nodiscard]] bool link_interpreted(Program& program,
        const Shader& vertex, const Shader& fragment);

    std::map<std::uint32_t, Shader> shaders_;
    std::map<std::uint32_t, Program> programs_;
    std::uint32_t next_shader_ { 1U };
    std::uint32_t next_program_ { 1U };
};

} // namespace shade
