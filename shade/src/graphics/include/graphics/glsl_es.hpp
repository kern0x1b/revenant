// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Compile and run OpenGL ES Shading Language 1.00 shaders on the CPU.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade::glsl {

// The longest shader source the compiler takes, in bytes (what glShaderSource
// hands it is cut at the same length).
inline constexpr std::size_t maximum_source_bytes = 256U * 1024U;

// What one invocation of main may spend (steps are loop iterations and calls),
// and what all the invocations of one draw's shader may spend together.
inline constexpr std::uint64_t maximum_steps = 4'000'000;
inline constexpr std::uint64_t maximum_draw_steps = 200'000'000;

enum class Stage : std::uint8_t {
    Vertex,
    Fragment,
};

enum class TypeId : std::uint8_t {
    Void,
    Bool,
    BVec2,
    BVec3,
    BVec4,
    Int,
    IVec2,
    IVec3,
    IVec4,
    Float,
    Vec2,
    Vec3,
    Vec4,
    Mat2,
    Mat3,
    Mat4,
    Sampler2D,
};

// The number of floats a value of the type occupies (a matrix is stored by
// column, an integer or a boolean as the float of its value, a sampler as the
// number of its texture unit).
[[nodiscard]] std::size_t component_count(TypeId type);
[[nodiscard]] std::string_view type_name(TypeId type);

enum class ScalarKind : std::uint8_t { Bool, Int, Float };

// What the components of a type are: a sampler holds an int (its texture unit).
[[nodiscard]] ScalarKind scalar_kind(TypeId type);
[[nodiscard]] bool is_matrix_type(TypeId type);

struct Value {
    TypeId type { TypeId::Void };
    std::array<float, 16> v { };
};

enum class Storage : std::uint8_t {
    Attribute,
    Uniform,
    Varying,
    Builtin,
};

// A variable the pipeline exchanges with the shader: a vertex attribute, a
// uniform, a varying or a built-in (gl_Position, gl_FragColor, ...).
struct Variable {
    std::string name;
    TypeId type { TypeId::Void };
    // Zero for a variable that is not an array.
    std::uint32_t array_size { };
    Storage storage { Storage::Uniform };
    std::uint32_t slot { };
};

class Module {
public:
    // Compiles one shader. A shader that is not valid GLSL ES 1.00, or uses a
    // part of the language this compiler does not carry, or is longer than
    // maximum_source_bytes, or whose macros expand to more than the compiler
    // will hold, is refused with its reason (and line) appended to log.
    [[nodiscard]] static std::shared_ptr<const Module> compile(
        std::string_view source, Stage stage, std::string& log);

    [[nodiscard]] Stage stage() const;
    [[nodiscard]] std::span<const Variable> variables() const;
    [[nodiscard]] const Variable* find(std::string_view name) const;

    struct Impl;
    explicit Module(std::shared_ptr<const Impl> impl);
    ~Module();

    [[nodiscard]] const Impl& impl() const { return *impl_; }

private:
    std::shared_ptr<const Impl> impl_;
};

// What texture2D reads through.
class TextureAccess {
public:
    virtual ~TextureAccess() = default;
    // The texel colour (red, green, blue, alpha, each in [0, 1]) the sampler
    // bound to the texture unit gives at the coordinate.
    [[nodiscard]] virtual std::array<float, 4> sample(
        std::uint32_t unit, float s, float t) const = 0;
};

// One execution state of a module: its variable values, set before a run and
// read after it.
class Instance {
public:
    explicit Instance(std::shared_ptr<const Module> module);
    ~Instance();
    Instance(Instance&&) noexcept;
    Instance& operator=(Instance&&) noexcept;

    [[nodiscard]] const Module& module() const { return *module_; }

    // Element 0 of a variable that is not an array.
    [[nodiscard]] std::span<Value> values(const Variable& variable);
    [[nodiscard]] std::span<const Value> values(const Variable& variable) const;

    // Runs main. Returns false when the shader ran `discard` (fragment) or
    // could not run; error() then says which.
    [[nodiscard]] bool run(const TextureAccess* textures);
    [[nodiscard]] bool discarded() const { return discarded_; }
    [[nodiscard]] const std::string& error() const { return error_; }

    // The steps (loop iterations and calls) every run of this instance has
    // taken. A draw makes one instance per shader and runs it per vertex or
    // pixel, so this is the draw's total: a run that would take it past
    // maximum_draw_steps stops there and fails, and so does every run after.
    [[nodiscard]] std::uint64_t total_steps() const { return total_steps_; }

private:
    struct State;
    std::shared_ptr<const Module> module_;
    std::unique_ptr<State> state_;
    bool discarded_ { };
    std::uint64_t total_steps_ { };
    std::string error_;
};

} // namespace shade::glsl
