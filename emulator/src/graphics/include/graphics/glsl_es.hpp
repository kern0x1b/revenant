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

inline constexpr std::size_t maximum_source_bytes = 256U * 1024U;

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

[[nodiscard]] std::size_t component_count(TypeId type);
[[nodiscard]] std::string_view type_name(TypeId type);

enum class ScalarKind : std::uint8_t { Bool, Int, Float };

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

struct Variable {
    std::string name;
    TypeId type { TypeId::Void };
    std::uint32_t array_size { };
    Storage storage { Storage::Uniform };
    std::uint32_t slot { };
};

class Module {
public:
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

class TextureAccess {
public:
    virtual ~TextureAccess() = default;
    [[nodiscard]] virtual std::array<float, 4> sample(
        std::uint32_t unit, float s, float t) const = 0;
};

class Instance {
public:
    explicit Instance(std::shared_ptr<const Module> module);
    ~Instance();
    Instance(Instance&&) noexcept;
    Instance& operator=(Instance&&) noexcept;

    [[nodiscard]] const Module& module() const { return *module_; }

    [[nodiscard]] std::span<Value> values(const Variable& variable);
    [[nodiscard]] std::span<const Value> values(const Variable& variable) const;

    [[nodiscard]] bool run(const TextureAccess* textures);
    [[nodiscard]] bool discarded() const { return discarded_; }
    [[nodiscard]] const std::string& error() const { return error_; }

    [[nodiscard]] std::uint64_t total_steps() const { return total_steps_; }

private:
    struct State;
    std::shared_ptr<const Module> module_;
    std::unique_ptr<State> state_;
    bool discarded_ { };
    std::uint64_t total_steps_ { };
    std::string error_;
};

}
