// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest GLES contexts, drawing commands and resources to the
// renderer boundary.

#include "kernel/opengles_hle.hpp"

#include "opengles_dispatch_hle.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <string>
#include <string_view>
#include <utility>

#include "foundation/address_space.hpp"
#include "foundation/application_display.hpp"
#include "foundation/application_path.hpp"
#include "foundation/cpu.hpp"
#include "graphics/display.hpp"
#include "graphics/gles_primitive_assembler.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "foundation/output.hpp"
#include "foundation/scene_coordinator.hpp"
#include "graphics/surface_store.hpp"
#include "graphics/surface_transport_abi.hpp"
#include "foundation/userland_hle.hpp"
#include "surface_transport_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view opengles_image {
        "/OpenGLES.framework/OpenGLES"
    };

    constexpr std::uint32_t egl_false = 0;
    constexpr std::uint32_t egl_true = 1;
    constexpr std::uint32_t egl_default_display = 1;
    constexpr std::uint32_t egl_success = 0x3000;
    constexpr std::uint32_t egl_bad_attribute = 0x3004;
    constexpr std::uint32_t egl_bad_display = 0x3008;
    constexpr std::uint32_t egl_bad_parameter = 0x300c;
    constexpr std::uint32_t egl_bad_surface = 0x300d;
    constexpr std::uint32_t egl_bad_context = 0x3006;

    constexpr std::uint32_t egl_buffer_size = 0x3020;
    constexpr std::uint32_t egl_alpha_size = 0x3021;
    constexpr std::uint32_t egl_blue_size = 0x3022;
    constexpr std::uint32_t egl_green_size = 0x3023;
    constexpr std::uint32_t egl_red_size = 0x3024;
    constexpr std::uint32_t egl_depth_size = 0x3025;
    constexpr std::uint32_t egl_stencil_size = 0x3026;
    constexpr std::uint32_t egl_config_id = 0x3028;
    constexpr std::uint32_t egl_samples = 0x3031;
    constexpr std::uint32_t egl_sample_buffers = 0x3032;
    constexpr std::uint32_t egl_surface_type = 0x3033;
    constexpr std::uint32_t egl_none = 0x3038;
    constexpr std::uint32_t egl_dont_care = 0xffffffffU;
    constexpr std::uint32_t egl_vendor = 0x3053;
    constexpr std::uint32_t egl_version = 0x3054;
    constexpr std::uint32_t egl_extensions = 0x3055;
    constexpr std::uint32_t egl_height = 0x3056;
    constexpr std::uint32_t egl_width = 0x3057;
    constexpr std::uint32_t egl_renderable_type = 0x3040;
    constexpr std::uint32_t egl_context_client_version = 0x3098;

    constexpr std::uint32_t egl_window_bit = 0x0004;
    constexpr std::uint32_t egl_pbuffer_bit = 0x0001;
    constexpr std::uint32_t egl_pixmap_bit = 0x0002;
    constexpr std::uint32_t egl_opengl_es_bit = 0x0001;
    constexpr std::uint64_t texture_render_target_namespace = 1ULL << 32U;
    constexpr std::uint64_t compatibility_surface_namespace = 2ULL << 32U;
    constexpr std::size_t compatibility_surface_ring_size = 4;

    struct EglConfigDescriptor {
        std::uint32_t handle;
        std::uint32_t red;
        std::uint32_t green;
        std::uint32_t blue;
        std::uint32_t alpha;
        std::uint32_t depth;
        std::uint32_t stencil;
    };

    // The device EGL driver exposes the native CoreAnimation color formats plus
    // a depth/stencil variant used by regular GLES applications.
    constexpr std::array egl_configs {
        EglConfigDescriptor { 1, 8, 8, 8, 8, 24, 8 },
        EglConfigDescriptor { 2, 8, 8, 8, 8, 0, 0 },
        EglConfigDescriptor { 3, 5, 6, 5, 0, 0, 0 },
        EglConfigDescriptor { 4, 4, 4, 4, 4, 0, 0 },
    };

    std::optional<ApplicationDisplay> application_display_for_process(
        const std::shared_ptr<KernelSharedState>& shared_state,
        std::uint32_t process_id)
    {
        if (!shared_state)
            return std::nullopt;
        std::lock_guard lock { shared_state->mach_mutex };
        const auto process = shared_state->processes.find(process_id);
        return process == shared_state->processes.end()
                   ? std::nullopt
                   : std::optional<ApplicationDisplay> {
                         process->second.application_display };
    }

    DisplayGeometry display_geometry_for_process(
        const std::shared_ptr<KernelSharedState>& shared_state,
        std::uint32_t process_id, DisplayGeometry output)
    {
        const auto profile =
            application_display_for_process(shared_state, process_id);
        return profile ? application_display_geometry(*profile, output) : output;
    }

    const EglConfigDescriptor* egl_config(std::uint32_t handle)
    {
        const auto found = std::find_if(egl_configs.begin(), egl_configs.end(),
            [handle](const auto& config) { return config.handle == handle; });
        return found == egl_configs.end() ? nullptr : &*found;
    }

    std::optional<std::uint32_t> egl_config_attribute(
        const EglConfigDescriptor& config, std::uint32_t attribute)
    {
        switch (attribute) {
        case egl_buffer_size:
            return config.red + config.green + config.blue + config.alpha;
        case egl_alpha_size:
            return config.alpha;
        case egl_blue_size:
            return config.blue;
        case egl_green_size:
            return config.green;
        case egl_red_size:
            return config.red;
        case egl_depth_size:
            return config.depth;
        case egl_stencil_size:
            return config.stencil;
        case egl_config_id:
            return config.handle;
        case egl_samples:
        case egl_sample_buffers:
            return 0;
        case egl_surface_type:
            return egl_window_bit | egl_pbuffer_bit | egl_pixmap_bit;
        case egl_renderable_type:
            return egl_opengl_es_bit;
        default:
            return std::nullopt;
        }
    }

    constexpr std::uint32_t gl_no_error = gles_abi::no_error;
    constexpr std::uint32_t gl_invalid_value = gles_abi::invalid_value;
    constexpr std::uint32_t gl_vendor = 0x1f00;
    constexpr std::uint32_t gl_renderer = 0x1f01;
    constexpr std::uint32_t gl_version = 0x1f02;
    constexpr std::uint32_t gl_extensions = 0x1f03;
    constexpr std::uint32_t gl_renderbuffer_width = 0x8d42;
    constexpr std::uint32_t gl_renderbuffer_height = 0x8d43;
    constexpr std::uint32_t gl_renderbuffer_internal_format = 0x8d44;
    constexpr std::uint32_t gl_renderbuffer_color_format = 0x8e10;
    constexpr std::uint32_t gl_compressed_rgb_pvrtc_2bpp = 0x8c01;
    constexpr std::uint32_t gl_compressed_rgba_pvrtc_2bpp = 0x8c03;
    constexpr std::uint32_t gl_compressed_rgb_pvrtc_4bpp = 0x8c00;
    constexpr std::uint32_t gl_compressed_rgba_pvrtc_4bpp = 0x8c02;
    constexpr std::size_t maximum_unsupported_traces = 64;

    bool is_valid_display(std::uint32_t display)
    {
        return display == egl_default_display;
    }

} // namespace

OpenGlesHle::OpenGlesHle(UserlandHleRegistry& registry,
    std::shared_ptr<DisplayState> display,
    std::shared_ptr<SurfaceStore> surfaces)
    : display_ { std::move(display) }
    , surface_store_ { surfaces ? std::move(surfaces)
                                : std::make_shared<SurfaceStore>() }
    , renderer_owner_ { allocate_gles_renderer_owner() }
    , renderer_ { shared_gles_renderer() }
    , command_encoder_ { renderer_->create_command_encoder() }
{
    register_eagl(registry);
    register_egl(registry);
    register_gles(registry);
    register_programmable_gles(registry);
    dispatch_hle_ = std::make_unique<OpenGlesDispatchHle>(*this, registry);
}

OpenGlesHle::~OpenGlesHle() { release_renderer_resources(); }

void OpenGlesHle::reset()
{
    release_renderer_resources();
    threads_.clear();
    contexts_.clear();
    eagl_contexts_.clear();
    eagl_context_abi_.reset();
    dispatch_hle_->reset();
    surfaces_.clear();
    compatibility_display_surface_ = { };
    compatibility_display_process_id_ = 0;
    compatibility_surfaces_.clear();
    compatibility_surface_index_ = 0;
    next_compatibility_surface_ = 0;
    scanout_composition_.reset();
    resources_.reset();
    programs_.reset();
    renderer_owner_ = allocate_gles_renderer_owner();
    next_context_ = 0x00010001U;
    next_surface_ = 0x00020001U;
    next_framebuffer_ = 1U;
    next_renderbuffer_ = 1U;
    egl_error_ = egl_success;
    frame_count_ = 0;
    unsupported_trace_count_ = 0;
}

void OpenGlesHle::inherit_state(const OpenGlesHle& parent)
{
    release_renderer_resources();
    threads_ = parent.threads_;
    contexts_ = parent.contexts_;
    eagl_contexts_ = parent.eagl_contexts_;
    eagl_context_abi_ = parent.eagl_context_abi_;
    dispatch_hle_->inherit_state(*parent.dispatch_hle_);
    surfaces_ = parent.surfaces_;
    compatibility_display_surface_ = { };
    compatibility_display_process_id_ = 0;
    compatibility_surfaces_.clear();
    compatibility_surface_index_ = 0;
    next_compatibility_surface_ = 0;
    scanout_composition_.reset();
    resources_.inherit_state(parent.resources_);
    programs_ = parent.programs_;
    renderer_owner_ = allocate_gles_renderer_owner();
    default_guest_capabilities_ = parent.default_guest_capabilities_;
    next_context_ = parent.next_context_;
    next_surface_ = parent.next_surface_;
    next_framebuffer_ = parent.next_framebuffer_;
    next_renderbuffer_ = parent.next_renderbuffer_;
    egl_error_ = parent.egl_error_;
    frame_count_ = parent.frame_count_;
}

void OpenGlesHle::release_renderer_resources()
{
    if (renderer_owner_ != 0)
        renderer_->release_owner(renderer_owner_);
}

void OpenGlesHle::set_display(std::shared_ptr<DisplayState> display)
{
    display_ = std::move(display);
}

void OpenGlesHle::set_guest_capabilities(OpenGlesGuestCapabilitySet profile)
{
    default_guest_capabilities_ = profile;
}

void OpenGlesHle::set_shared_state(
    std::shared_ptr<KernelSharedState> shared_state)
{
    shared_state_ = std::move(shared_state);
}

void OpenGlesHle::set_scene_coordinator(
    std::shared_ptr<SceneCoordinator> scenes)
{
    scene_coordinator_ = std::move(scenes);
}

bool OpenGlesHle::display_write_allowed(UserlandHleCall& call) const
{
    if (!shared_state_)
        return true;
    std::lock_guard lock { shared_state_->mach_mutex };
    const auto process = shared_state_->processes.find(call.process_id());
    if (process == shared_state_->processes.end() ||
        !is_application_executable_path(process->second.executable_path)) {
        return true;
    }
    return active_application_owns_display_locked(*shared_state_,
        call.process_id(),
        scene_coordinator_
            ? std::optional<bool> { scene_coordinator_
                      ->client_scene_presentable(call.process_id()) }
            : std::nullopt);
}

OpenGlesHle::ThreadState& OpenGlesHle::thread(UserlandHleCall& call)
{
    return threads_[call.cpu().processor_id()];
}

OpenGlesHle::ContextState* OpenGlesHle::current_context(UserlandHleCall& call)
{
    const auto prefixed = call.prefix_argument(0U);
    const auto handle = prefixed ? dispatch_hle_->context_for_handle(*prefixed)
                                 : std::optional { thread(call).context };
    if (!handle)
        return nullptr;
    const auto context = contexts_.find(*handle);
    return context == contexts_.end() ? nullptr : &context->second;
}

OpenGlesHle::ContextState OpenGlesHle::default_context_state() const
{
    auto state = ContextState { };
    state.guest_capabilities = default_guest_capabilities_;
    const auto geometry =
        display_ ? display_->geometry() : default_display_geometry;
    state.viewport = { 0, 0, static_cast<std::int32_t>(geometry.width),
        static_cast<std::int32_t>(geometry.height) };
    state.scissor_box = state.viewport;
    return state;
}

OpenGlesHle::ContextState* OpenGlesHle::eagl_context(UserlandHleCall& call)
{
    const auto found = eagl_contexts_.find({ call.process_id(), call.argument(0) });
    const auto handle = found == eagl_contexts_.end()
                            ? dispatch_hle_->context_for_object(call, call.argument(0))
                            : std::optional { found->second };
    if (!handle)
        return current_context(call);
    const auto context = contexts_.find(*handle);
    return context == contexts_.end() ? nullptr : &context->second;
}

void OpenGlesHle::set_gl_error(UserlandHleCall& call, std::uint32_t error)
{
    auto& value = thread(call).gl_error;
    if (value != gles_abi::no_error)
        return;
    value = error;
}

GlesMatrix* OpenGlesHle::current_matrix(ContextState& context)
{
    if (context.matrix_mode == gles_abi::modelview) {
        return &context.modelview_matrix;
    }
    if (context.matrix_mode == gles_abi::projection) {
        return &context.projection_matrix;
    }
    if (context.matrix_mode == gles_abi::texture_matrix) {
        return &context.texture_units[context.active_texture_unit]
                    .texture_matrix;
    }
    return nullptr;
}

std::vector<GlesMatrix>* OpenGlesHle::current_matrix_stack(
    ContextState& context)
{
    if (context.matrix_mode == gles_abi::modelview) {
        return &context.modelview_stack;
    }
    if (context.matrix_mode == gles_abi::projection) {
        return &context.projection_stack;
    }
    if (context.matrix_mode == gles_abi::texture_matrix) {
        return &context.texture_units[context.active_texture_unit]
                    .texture_stack;
    }
    return nullptr;
}

void OpenGlesHle::multiply_current_matrix(
    UserlandHleCall& call, GlesMatrix matrix)
{
    auto* context = current_context(call);
    if (context == nullptr) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    auto* current = current_matrix(*context);
    if (current == nullptr) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    *current = *current * matrix;
}

void OpenGlesHle::set_array_pointer(
    UserlandHleCall& call, std::uint32_t array_name)
{
    auto* context = current_context(call);
    if (context == nullptr) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto size = static_cast<std::int32_t>(call.argument(0));
    const auto type = call.argument(1);
    const auto stride = static_cast<std::int32_t>(call.argument(2));
    const auto valid_common_type = type == gles_abi::float_type ||
                                   type == gles_abi::fixed ||
                                   type == gles_abi::short_type;
    bool valid = stride >= 0;
    if (array_name == gles_abi::vertex_array) {
        valid = valid && size >= 2 && size <= 4 && valid_common_type;
    } else if (array_name == gles_abi::color_array) {
        valid = valid && size == 4 &&
                (valid_common_type || type == gles_abi::unsigned_byte);
    } else {
        valid = valid && size >= 2 && size <= 4 && valid_common_type;
    }
    if (!valid) {
        set_gl_error(call,
            stride < 0 ? gles_abi::invalid_value : gles_abi::invalid_enum);
        return;
    }
    auto* array =
        array_name == gles_abi::vertex_array ? &context->vertex_array
        : array_name == gles_abi::color_array
            ? &context->color_array
            : &context->texture_units[context->client_active_texture_unit]
                   .texture_array;
    const auto enabled = array->enabled;
    *array = ContextState::ArrayPointer { static_cast<std::uint32_t>(size),
        type, static_cast<std::uint32_t>(stride), call.argument(3),
        context->bound_array_buffer, array_name == gles_abi::color_array, enabled };
}

bool OpenGlesHle::read_array(UserlandHleCall& call,
    const ContextState::ArrayPointer& array, std::uint32_t index,
    std::span<float> destination, bool normalized) const
{
    std::uint32_t component_size { };
    if (array.type == gles_abi::float_type || array.type == gles_abi::fixed) {
        component_size = 4;
    } else if (array.type == gles_abi::short_type ||
               array.type == gles_abi::unsigned_short) {
        component_size = 2;
    } else if (array.type == gles_abi::byte ||
               array.type == gles_abi::unsigned_byte) {
        component_size = 1;
    } else {
        return false;
    }
    if (array.size > destination.size())
        return false;
    const auto stride =
        array.stride == 0 ? array.size * component_size : array.stride;
    const auto base_offset = static_cast<std::uint64_t>(array.pointer) +
                             static_cast<std::uint64_t>(index) * stride;
    const auto* buffer =
        array.buffer == 0 ? nullptr : resources_.buffer(array.buffer);
    if (array.buffer != 0 && buffer == nullptr)
        return false;
    for (std::uint32_t component = 0; component < array.size; ++component) {
        const auto offset =
            base_offset +
            static_cast<std::uint64_t>(component) * component_size;
        std::uint32_t raw { };
        if (buffer != nullptr) {
            if (offset > buffer->bytes.size() ||
                component_size > buffer->bytes.size() - offset) {
                return false;
            }
            for (std::uint32_t byte_index = 0; byte_index < component_size;
                ++byte_index) {
                raw |= std::to_integer<std::uint32_t>(
                           buffer->bytes[static_cast<std::size_t>(offset) +
                                         byte_index])
                       << (byte_index * 8U);
            }
        } else {
            if (offset > std::numeric_limits<std::uint32_t>::max())
                return false;
            const auto address = static_cast<std::uint32_t>(offset);
            if (component_size == 4) {
                const auto value = call.memory().read32(address);
                if (!value)
                    return false;
                raw = *value;
            } else if (component_size == 2) {
                const auto value = call.memory().read16(address);
                if (!value)
                    return false;
                raw = *value;
            } else {
                const auto value = call.memory().read8(address);
                if (!value)
                    return false;
                raw = *value;
            }
        }
        float value { };
        if (array.type == gles_abi::float_type) {
            value = std::bit_cast<float>(raw);
        } else if (array.type == gles_abi::fixed) {
            value =
                static_cast<float>(static_cast<std::int32_t>(raw)) / 65'536.0F;
        } else if (array.type == gles_abi::short_type) {
            const auto signed_value = static_cast<std::int16_t>(raw);
            value = normalized
                        ? std::max(-1.0F,
                              static_cast<float>(signed_value) / 32'767.0F)
                        : static_cast<float>(signed_value);
        } else if (array.type == gles_abi::unsigned_short) {
            value = normalized ? static_cast<float>(raw) / 65'535.0F
                               : static_cast<float>(raw);
        } else if (array.type == gles_abi::byte) {
            const auto signed_value = static_cast<std::int8_t>(raw);
            value = normalized ? std::max(-1.0F,
                                     static_cast<float>(signed_value) / 127.0F)
                               : static_cast<float>(signed_value);
        } else {
            value = normalized ? static_cast<float>(raw) / 255.0F
                               : static_cast<float>(raw);
        }
        destination[component] = value;
    }
    return true;
}

std::optional<GlesRasterVertex> OpenGlesHle::read_vertex(UserlandHleCall& call,
    const ContextState& context, std::uint32_t index,
    const ProgrammableDrawState* programmable) const
{
    const auto& position_array =
        programmable ? programmable->position_array : context.vertex_array;
    const auto& color_array =
        programmable ? programmable->color_array : context.color_array;
    if (!position_array.enabled)
        return std::nullopt;
    GlesRasterVertex vertex;
    vertex.color = context.current_color;
    if (!read_array(call, position_array, index, vertex.position,
            position_array.normalized)) {
        return std::nullopt;
    }
    if (color_array.enabled && !read_array(call, color_array, index,
                                   vertex.color, color_array.normalized)) {
        return std::nullopt;
    }
    vertex.position =
        programmable ? programmable->vertex_matrix.transform(vertex.position)
                     : context.projection_matrix.transform(
                           context.modelview_matrix.transform(vertex.position));
    for (std::size_t unit_index = 0; unit_index < context.texture_units.size();
        ++unit_index) {
        const auto& unit = context.texture_units[unit_index];
        const auto& texture_array =
            programmable ? programmable->texture_arrays[unit_index]
                         : unit.texture_array;
        if (texture_array.enabled) {
            std::array<float, 4> texture { };
            if (!read_array(call, texture_array, index, texture,
                    texture_array.normalized)) {
                return std::nullopt;
            }
            vertex.texture[unit_index] = { texture[0], texture[1] };
        }
        if (programmable) {
            const auto& transform =
                programmable->texture_transforms[unit_index];
            vertex.texture[unit_index][0] =
                vertex.texture[unit_index][0] * transform[0] + transform[2];
            vertex.texture[unit_index][1] =
                vertex.texture[unit_index][1] * transform[1] + transform[3];
        } else {
            const auto transformed_texture =
                unit.texture_matrix.transform({ vertex.texture[unit_index][0],
                    vertex.texture[unit_index][1], 0.0F, 1.0F });
            if (transformed_texture[3] == 0.0F)
                continue;
            vertex.texture[unit_index] = { transformed_texture[0] /
                                               transformed_texture[3],
                transformed_texture[1] / transformed_texture[3] };
        }
    }
    return vertex;
}

std::optional<std::uint32_t> OpenGlesHle::core_surface_identifier(
    UserlandHleCall& call, std::uint32_t surface) const
{
    if (surface == 0) {
        return std::nullopt;
    }
    const auto& profile = surface_transport::loaded_client_abi(call);
    if (surface > std::numeric_limits<std::uint32_t>::max() -
                      profile.public_client_pointer_offset)
        return std::nullopt;
    const auto client =
        call.memory().read32(surface + profile.public_client_pointer_offset);
    if (!client || *client == 0 ||
        *client > std::numeric_limits<std::uint32_t>::max() -
                      profile.identifier_offset)
        return std::nullopt;
    const auto identifier =
        call.memory().read32(*client + profile.identifier_offset);
    if (identifier && *identifier != 0 && surface_store_->find(*identifier))
        return *identifier;
    return std::nullopt;
}

OpenGlesHle::SurfaceState* OpenGlesHle::current_pixmap_surface(
    UserlandHleCall& call)
{
    const auto found = surfaces_.find(thread(call).draw_surface);
    return found != surfaces_.end() &&
                   found->second.backing_identifier.has_value()
               ? &found->second
               : nullptr;
}

bool OpenGlesHle::refresh_pixmap_surface(
    UserlandHleCall& call, std::uint32_t surface)
{
    const auto found = surfaces_.find(surface);
    if (found == surfaces_.end() || !found->second.backing_identifier)
        return true;
    auto& state = found->second;
    const auto host_surface =
        surface_store_->host_surface(*state.backing_identifier);
    if (!host_surface)
        return false;
    const auto cpu_generation = host_surface->cpu_generation();
    if (cpu_generation <= state.backing_cpu_generation)
        return true;
    // A newer GPU generation is still the authoritative render target. Do not
    // overwrite its native image with the older guest shadow; record the CPU
    // watermark so a later completed GPU-to-CPU synchronization is observed.
    if (host_surface->gpu_generation() > cpu_generation) {
        state.backing_cpu_generation = cpu_generation;
        return true;
    }
    return reload_surface(call, surface);
}

const GlesResourceStore::TextureLevel* OpenGlesHle::current_framebuffer_level(
    const ContextState& context) const
{
    if (context.bound_framebuffer == 0U)
        return nullptr;
    const auto framebuffer =
        context.framebuffers.find(context.bound_framebuffer);
    if (framebuffer == context.framebuffers.end() ||
        framebuffer->second.color_texture == 0U) {
        return nullptr;
    }
    const auto* texture = resources_.texture(framebuffer->second.color_texture);
    if (texture == nullptr)
        return nullptr;
    const auto level = texture->levels.find(0U);
    return level == texture->levels.end() || level->second.width == 0U ||
                   level->second.height == 0U
               ? nullptr
               : &level->second;
}

std::uint32_t OpenGlesHle::ensure_renderbuffer_storage(ContextState& context,
    std::uint32_t name, std::uint32_t width, std::uint32_t height,
    std::uint32_t internal_format)
{
    auto renderbuffer = context.renderbuffers.find(name);
    if (renderbuffer == context.renderbuffers.end())
        return gles_abi::invalid_operation;
    if (renderbuffer->second.color_texture == 0U) {
        renderbuffer->second.color_texture = resources_.generate_texture();
        resources_.ensure_texture(renderbuffer->second.color_texture);
    }
    const auto error = resources_.allocate_texture_2d(
        renderbuffer->second.color_texture, 0U, internal_format, width, height);
    if (error != gles_abi::no_error)
        return error;
    renderbuffer->second.width = width;
    renderbuffer->second.height = height;
    renderbuffer->second.internal_format = internal_format;
    renderbuffer->second.display_oriented = false;
    for (auto& [framebuffer_name, framebuffer] : context.framebuffers) {
        static_cast<void>(framebuffer_name);
        if (framebuffer.color_renderbuffer == name)
            framebuffer.color_texture = renderbuffer->second.color_texture;
    }
    return gles_abi::no_error;
}

std::optional<OpenGlesHle::RenderTargetBinding>
OpenGlesHle::resolve_render_target(UserlandHleCall& call, ContextState& context)
{
    if (context.bound_framebuffer != 0U) {
        const auto framebuffer =
            context.framebuffers.find(context.bound_framebuffer);
        const auto* level = current_framebuffer_level(context);
        if (framebuffer == context.framebuffers.end() || level == nullptr)
            return std::nullopt;
        const auto texture = framebuffer->second.color_texture;
        if (level->surface_id) {
            const auto backing = surface_store_->find(*level->surface_id);
            const auto host_surface =
                surface_store_->host_surface(*level->surface_id);
            if (!backing || !host_surface)
                return std::nullopt;
            return RenderTargetBinding { RenderTargetKind::Framebuffer,
                { 0, backing->provenance.publication_sequence },
                level->surface_id, nullptr, texture, std::move(host_surface),
                level->render_target_inverted_vertical };
        }
        auto host_surface =
            resources_.ensure_texture_render_target(texture, 0U, *renderer_,
                renderer_owner_, texture_render_target_namespace | texture);
        if (!host_surface)
            return std::nullopt;
        const auto renderbuffer = context.renderbuffers.find(
            framebuffer->second.color_renderbuffer);
        // Texture rows start at the GL lower edge. A drawable's rows are
        // already in panel order, so it uses the display coordinate origin.
        const bool display_oriented = renderbuffer != context.renderbuffers.end() &&
                                      renderbuffer->second.display_oriented;
        return RenderTargetBinding { RenderTargetKind::Framebuffer,
            host_surface->key(), std::nullopt, nullptr, texture,
            std::move(host_surface),
            level->render_target_inverted_vertical && !display_oriented, true };
    }
    if (auto* pixmap = current_pixmap_surface(call)) {
        if (!refresh_pixmap_surface(call, thread(call).draw_surface))
            return std::nullopt;
        pixmap = current_pixmap_surface(call);
        if (pixmap == nullptr || !pixmap->backing_identifier)
            return std::nullopt;
        const auto host_surface =
            surface_store_->host_surface(*pixmap->backing_identifier);
        if (!host_surface)
            return std::nullopt;
        return RenderTargetBinding { RenderTargetKind::Pixmap,
            render_target_key(thread(call).draw_surface),
            pixmap->backing_identifier, pixmap, 0U, host_surface };
    }
    const auto draw_surface = thread(call).draw_surface;
    auto binding = RenderTargetBinding { RenderTargetKind::Display,
        render_target_key(draw_surface), std::nullopt, nullptr, 0U, nullptr };
    const auto profile =
        application_display_for_process(shared_state_, call.process_id());
    if (profile && profile->kind != ApplicationDisplayMode::Native) {
        const auto surface = surfaces_.find(draw_surface);
        if (surface != surfaces_.end() &&
            !surface->second.backing_identifier) {
            binding.display_surface = &surface->second;
        } else {
            const auto geometry = application_display_geometry(
                *profile, display_ ? display_->geometry() : default_display_geometry);
            if (compatibility_display_process_id_ != call.process_id() ||
                compatibility_display_surface_.width != geometry.width ||
                compatibility_display_surface_.height != geometry.height) {
                compatibility_display_surface_ = { };
                compatibility_display_process_id_ = call.process_id();
                compatibility_display_surface_.width = geometry.width;
                compatibility_display_surface_.height = geometry.height;
                compatibility_display_surface_.pixels.assign(
                    geometry.pixel_count(), 0xff000000U);
            }
            binding.display_surface = &compatibility_display_surface_;
        }
    }
    return binding;
}

GlesRenderTargetKey OpenGlesHle::render_target_key(std::uint32_t surface) const
{
    const auto found = surfaces_.find(surface);
    if (found != surfaces_.end() && found->second.backing_identifier) {
        const auto backing =
            surface_store_->find(*found->second.backing_identifier);
        if (backing)
            return { 0, backing->provenance.publication_sequence };
    }
    return { renderer_owner_, surface };
}

bool OpenGlesHle::reload_surface(UserlandHleCall& call, std::uint32_t surface)
{
    const auto found = surfaces_.find(surface);
    if (found == surfaces_.end())
        return false;
    auto& state = found->second;
    if (!state.backing_identifier)
        return true;
    const auto backing = surface_store_->find(*state.backing_identifier);
    const auto host_surface =
        surface_store_->host_surface(*state.backing_identifier);
    if (backing && host_surface &&
        host_surface->gpu_generation() > host_surface->cpu_generation()) {
        state.width = backing->width;
        state.height = backing->height;
        state.backing_cpu_generation = host_surface->cpu_generation();
        state.refreshed_textures.clear();
        state.dirty = false;
        return true;
    }
    const auto pixels =
        surface_store_->read_argb(call.memory(), *state.backing_identifier);
    if (!backing || !pixels)
        return false;
    state.width = backing->width;
    state.height = backing->height;
    state.pixels = std::move(*pixels);
    state.backing_cpu_generation =
        host_surface ? host_surface->cpu_generation() : 0U;
    state.refreshed_textures.clear();
    state.dirty = false;
    renderer_->invalidate(render_target_key(surface));
    return true;
}

bool OpenGlesHle::flush_surface(UserlandHleCall& call, std::uint32_t surface)
{
    const auto found = surfaces_.find(surface);
    if (found == surfaces_.end())
        return false;
    auto& state = found->second;
    const auto profile = application_display_for_process(
        shared_state_, call.process_id());
    const auto compatibility_surface =
        profile && profile->kind != ApplicationDisplayMode::Native &&
        !state.backing_identifier;
    if (compatibility_surface && state.pixels.size() !=
            static_cast<std::size_t>(state.width) * state.height) {
        state.pixels.assign(
            static_cast<std::size_t>(state.width) * state.height,
            0xff000000U);
    }
    auto frame = state.backing_identifier ? DisplayFrame { state.width,
        state.height, 0, state.pixels }
                 : compatibility_surface
                     ? DisplayFrame { state.width, state.height, 0,
                           state.pixels }
                     : display_ ? display_->snapshot() : DisplayFrame { };
    if (frame.width == 0 || frame.height == 0 ||
        !renderer_->synchronize(frame, render_target_key(surface))) {
        return false;
    }
    if (!state.backing_identifier) {
        if (display_ && display_write_allowed(call)) {
            auto pixels = std::move(frame.pixels);
            if (profile &&
                profile->kind != ApplicationDisplayMode::Native) {
                pixels = compose_application_display_pixels(*profile,
                    { frame.width, frame.height }, display_->geometry(), pixels);
                if (pixels.empty())
                    return false;
            }
            display_->replace_pixels(std::move(pixels), call.process_id());
        }
        state.refreshed_textures.clear();
        return true;
    }
    state.pixels = std::move(frame.pixels);
    state.dirty = true;
    if (!surface_store_->write_argb(
            call.memory(), *state.backing_identifier, state.pixels)) {
        return false;
    }
    state.dirty = false;
    if (const auto host_surface =
            surface_store_->host_surface(*state.backing_identifier)) {
        state.backing_cpu_generation = host_surface->cpu_generation();
    }
    state.refreshed_textures.clear();
    return true;
}

std::optional<DisplayFrame> OpenGlesHle::render_target(
    UserlandHleCall& call, const RenderTargetBinding& binding)
{
    static_cast<void>(call);
    if (binding.display_surface != nullptr) {
        auto& surface = *binding.display_surface;
        if (surface.width == 0U || surface.height == 0U)
            return std::nullopt;
        const auto expected =
            static_cast<std::size_t>(surface.width) * surface.height;
        if (surface.pixels.size() != expected)
            surface.pixels.assign(expected, 0xff000000U);
        return DisplayFrame { surface.width, surface.height, 0,
            surface.pixels };
    }
    if (binding.kind == RenderTargetKind::Framebuffer) {
        if (!binding.host_surface)
            return std::nullopt;
        const auto descriptor = binding.host_surface->descriptor();
        if (renderer_->accelerated()) {
            // Native renderers already own the authoritative image after the
            // first upload. Carry the HostSurface across the renderer boundary
            // so it can compare CPU/GPU generations without copying the full
            // CPU shadow for every draw. Software backends retain the owning
            // pixel frame below.
            return DisplayFrame { descriptor.width, descriptor.height, 0, { },
                binding.host_surface };
        }
        auto mapping = binding.host_surface->map_cpu(false);
        const auto& frame = mapping.frame();
        if (frame.width != descriptor.width ||
            frame.height != descriptor.height ||
            frame.pixels.size() != static_cast<std::size_t>(descriptor.width) *
                                       descriptor.height) {
            return std::nullopt;
        }
        return frame;
    }
    if (const auto* surface = binding.pixmap_surface) {
        if (surface->width == 0 || surface->height == 0 ||
            surface->pixels.size() !=
                static_cast<std::size_t>(surface->width) * surface->height) {
            return std::nullopt;
        }
        return DisplayFrame { surface->width, surface->height, 0,
            surface->pixels };
    }
    return display_ ? std::optional<DisplayFrame> { display_->snapshot() }
                    : std::nullopt;
}

bool OpenGlesHle::commit_render_target(UserlandHleCall& call,
    const RenderTargetBinding& binding, DisplayFrame frame)
{
    if (binding.backing_identifier) {
        const auto backing = surface_store_->find(*binding.backing_identifier);
        if (!backing || frame.width != backing->width ||
            frame.height != backing->height ||
            frame.pixels.size() !=
                static_cast<std::size_t>(backing->width) * backing->height ||
            !surface_store_->write_argb(
                call.memory(), *binding.backing_identifier, frame.pixels)) {
            return false;
        }
    } else if (binding.kind == RenderTargetKind::Framebuffer &&
               !resources_.commit_texture_render_target(
                   binding.framebuffer_texture, 0U, frame.pixels)) {
        return false;
    }
    if (auto* surface = binding.pixmap_surface) {
        if (frame.width != surface->width || frame.height != surface->height ||
            frame.pixels.size() !=
                static_cast<std::size_t>(surface->width) * surface->height) {
            return false;
        }
        surface->pixels = std::move(frame.pixels);
        surface->backing_cpu_generation =
            binding.host_surface ? binding.host_surface->cpu_generation() : 0U;
        surface->dirty = false;
        return true;
    }
    if (binding.kind == RenderTargetKind::Framebuffer)
        return binding.host_surface != nullptr;
    if (binding.display_surface != nullptr) {
        auto& surface = *binding.display_surface;
        if (frame.width != surface.width || frame.height != surface.height ||
            frame.pixels.size() !=
                static_cast<std::size_t>(surface.width) * surface.height) {
            return false;
        }
        surface.pixels = std::move(frame.pixels);
        surface.dirty = false;
        if (!display_ || !display_write_allowed(call))
            return true;
        const auto profile = application_display_for_process(
            shared_state_, call.process_id());
        auto pixels = surface.pixels;
        if (profile &&
            profile->kind != ApplicationDisplayMode::Native) {
            pixels = compose_application_display_pixels(*profile,
                { surface.width, surface.height }, display_->geometry(),
                pixels);
            if (pixels.empty())
                return false;
        }
        display_->replace_pixels(std::move(pixels), call.process_id());
        return true;
    }
    if (!display_)
        return false;
    if (display_write_allowed(call)) {
        display_->replace_pixels(std::move(frame.pixels), call.process_id());
    }
    return true;
}

std::shared_ptr<HostSurface> OpenGlesHle::acquire_compatibility_surface(
    HostSurfaceDescriptor descriptor)
{
    const auto matches = [&descriptor](
                             const std::shared_ptr<HostSurface>& surface) {
        if (!surface)
            return false;
        const auto candidate = surface->descriptor();
        return candidate.width == descriptor.width &&
               candidate.height == descriptor.height &&
               candidate.bytes_per_row == descriptor.bytes_per_row &&
               candidate.pixel_format == descriptor.pixel_format &&
               candidate.kind == descriptor.kind;
    };
    while (compatibility_surfaces_.size() < compatibility_surface_ring_size) {
        auto surface = renderer_->create_surface(
            { renderer_owner_, compatibility_surface_namespace |
                  next_compatibility_surface_++ },
            descriptor);
        if (!surface)
            return { };
        compatibility_surfaces_.push_back(std::move(surface));
    }
    for (std::size_t attempt = 0; attempt < compatibility_surfaces_.size();
        ++attempt) {
        const auto index = compatibility_surface_index_ %
                           compatibility_surfaces_.size();
        compatibility_surface_index_ = (index + 1U) %
                                       compatibility_surfaces_.size();
        const auto& candidate = compatibility_surfaces_[index];
        if (matches(candidate) && !candidate->presentation_leased())
            return candidate;
    }
    auto surface = renderer_->create_surface(
        { renderer_owner_, compatibility_surface_namespace |
              next_compatibility_surface_++ },
        descriptor);
    if (surface)
        compatibility_surfaces_.push_back(surface);
    return surface;
}

bool OpenGlesHle::publish_display_surface(
    UserlandHleCall& call, const std::shared_ptr<HostSurface>& surface)
{
    if (!surface || !display_ || !display_write_allowed(call))
        return false;
    const auto descriptor = surface->descriptor();
    const auto output_geometry = display_->geometry();
    const auto profile =
        application_display_for_process(shared_state_, call.process_id());
    const auto logical_geometry = profile
                                      ? application_display_geometry(
                                            *profile, output_geometry)
                                      : output_geometry;
    const auto is_geometry = [&](DisplayGeometry geometry) {
        return descriptor.width == geometry.width &&
               descriptor.height == geometry.height;
    };
    if ((!profile && !is_geometry(output_geometry)) ||
        (profile && !is_geometry(logical_geometry) &&
            !is_geometry(output_geometry))) {
        return false;
    }
    if (profile && profile->kind != ApplicationDisplayMode::Native &&
        (!renderer_->accelerated() || !command_encoder_)) {
        if (!renderer_->map_cpu(
                *surface, true, PerfCpuMapReason::DeferredDisplayRead)) {
            return false;
        }
        const auto mapping =
            surface->map_cpu(false, PerfCpuMapReason::DeferredDisplayRead);
        auto pixels = compose_application_display_pixels(*profile,
            { descriptor.width, descriptor.height }, output_geometry,
            mapping.frame().pixels);
        if (pixels.empty())
            return false;
        display_->replace_pixels(std::move(pixels), call.process_id());
        return true;
    }
    std::shared_ptr<HostSurface> published_surface = surface;
    if (profile && profile->kind != ApplicationDisplayMode::Native) {
        const auto viewport =
            application_display_viewport(*profile, output_geometry);
        const auto source_width = std::min(profile->logical_geometry.width,
            descriptor.width);
        const auto source_height = std::min(profile->logical_geometry.height,
            descriptor.height);
        if (viewport.width == 0U || viewport.height == 0U ||
            source_width == 0U || source_height == 0U || !command_encoder_) {
            return false;
        }
        const auto destination_descriptor = HostSurfaceDescriptor {
            output_geometry.width, output_geometry.height,
            output_geometry.width * static_cast<std::uint32_t>(sizeof(std::uint32_t)),
            surface_pixel_format_bgra, PerfSurfaceKind::Scanout };
        auto compatibility_surface =
            acquire_compatibility_surface(destination_descriptor);
        if (!compatibility_surface ||
            !command_encoder_->fill(compatibility_surface,
                { 0, 0, output_geometry.width, output_geometry.height },
                0xff000000U) ||
            !command_encoder_->copy(surface, compatibility_surface,
                { 0, 0, source_width, source_height },
                { viewport.x, viewport.y, viewport.width, viewport.height },
                HostCompositeMode::Copy, 0xffU, HostFilter::Nearest,
                HostRotation::Identity) ||
            !command_encoder_->submit(PerfSubmitReason::Presentation)) {
            return false;
        }
        published_surface = std::move(compatibility_surface);
    }
    auto renderer = renderer_;
    display_->replace_surface(
        published_surface,
        [renderer = std::move(renderer), published_surface] {
            if (!renderer->map_cpu(
                    *published_surface, true,
                    PerfCpuMapReason::DeferredDisplayRead)) {
                return std::vector<std::uint32_t> { };
            }
            auto mapping =
                published_surface->map_cpu(
                    false, PerfCpuMapReason::DeferredDisplayRead);
            return mapping.frame().pixels;
        },
        call.process_id(),
        [published_surface] {
            return std::max(
                published_surface->cpu_generation(),
                published_surface->gpu_generation());
        });
    return true;
}

std::optional<std::vector<std::uint32_t>> OpenGlesHle::collect_vertex_indices(
    UserlandHleCall& call, const ContextState& context, bool indexed,
    std::int32_t first, std::int32_t count)
{
    const auto index_type = indexed ? call.argument(2) : 0;
    if (indexed && index_type != gles_abi::unsigned_byte &&
        index_type != gles_abi::unsigned_short) {
        set_gl_error(call, gles_abi::invalid_enum);
        return std::nullopt;
    }
    const auto index_size = index_type == gles_abi::unsigned_short ? 2U : 1U;
    const auto index_pointer = indexed ? call.argument(3) : 0;
    const auto* element_buffer =
        indexed && context.bound_element_array_buffer != 0
            ? resources_.buffer(context.bound_element_array_buffer)
            : nullptr;
    std::vector<std::uint32_t> indices;
    indices.reserve(static_cast<std::size_t>(count));
    for (std::uint32_t item = 0; item < static_cast<std::uint32_t>(count);
        ++item) {
        auto vertex_index = static_cast<std::uint32_t>(first) + item;
        if (indexed) {
            const auto offset = static_cast<std::uint64_t>(index_pointer) +
                                static_cast<std::uint64_t>(item) * index_size;
            if (element_buffer != nullptr) {
                if (offset > element_buffer->bytes.size() ||
                    index_size > element_buffer->bytes.size() - offset) {
                    set_gl_error(call, gles_abi::invalid_operation);
                    return std::nullopt;
                }
                vertex_index = std::to_integer<std::uint32_t>(
                    element_buffer->bytes[static_cast<std::size_t>(offset)]);
                if (index_size == 2) {
                    vertex_index |=
                        std::to_integer<std::uint32_t>(element_buffer
                                ->bytes[static_cast<std::size_t>(offset) + 1U])
                        << 8U;
                }
            } else {
                if (offset > std::numeric_limits<std::uint32_t>::max()) {
                    set_gl_error(call, gles_abi::invalid_operation);
                    return std::nullopt;
                }
                if (index_size == 2) {
                    const auto value = call.memory().read16(
                        static_cast<std::uint32_t>(offset));
                    if (!value) {
                        set_gl_error(call, gles_abi::invalid_operation);
                        return std::nullopt;
                    }
                    vertex_index = *value;
                } else {
                    const auto value =
                        call.memory().read8(static_cast<std::uint32_t>(offset));
                    if (!value) {
                        set_gl_error(call, gles_abi::invalid_operation);
                        return std::nullopt;
                    }
                    vertex_index = *value;
                }
            }
        }
        indices.push_back(vertex_index);
    }
    return indices;
}

void OpenGlesHle::draw(UserlandHleCall& call, bool indexed)
{
    auto* context = current_context(call);
    if (context == nullptr) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto mode = call.argument(0);
    if (!GlesPrimitiveAssembler::supports(mode)) {
        set_gl_error(call, gles_abi::invalid_enum);
        return;
    }
    const auto first =
        indexed ? 0 : static_cast<std::int32_t>(call.argument(1));
    const auto count =
        static_cast<std::int32_t>(call.argument(indexed ? 1U : 2U));
    if (first < 0 || count < 0) {
        set_gl_error(call, gles_abi::invalid_value);
        return;
    }
    if (count == 0)
        return;
    if (static_cast<std::uint32_t>(count) > gles_abi::maximum_draw_vertices) {
        set_gl_error(call, gles_abi::out_of_memory);
        return;
    }
    const auto* active_program =
        context->current_program != 0U
            ? programs_.program(context->current_program)
            : nullptr;
    // A draw with a program that did not link is an error.
    if (context->current_program != 0U &&
        (active_program == nullptr || !active_program->linked)) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto interpreted = active_program != nullptr &&
                             active_program->interpreted;
    const auto programmable =
        interpreted ? std::nullopt : programmable_draw_state(*context);
    if (context->current_program != 0U && !interpreted && !programmable) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto indices =
        collect_vertex_indices(call, *context, indexed, first, count);
    if (!indices)
        return;
    std::vector<GlesRasterVertex> vertices;
    std::optional<ShadedDraw> shaded;
    if (interpreted) {
        // Points and lines are not drawn with a shader: say so, rather than
        // draw them without it.
        if (mode != gles_abi::triangles && mode != gles_abi::triangle_strip &&
            mode != gles_abi::triangle_fan) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (indices->size() < 3U)
            return;
        std::string error;
        shaded = shade_vertices(call, *context, *active_program, *indices, error);
        if (!shaded) {
            trace_shader_failure(call, "vertex shader failed: " + error);
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
    } else {
        vertices.reserve(indices->size());
        for (const auto vertex_index : *indices) {
            const auto vertex = read_vertex(call, *context, vertex_index,
                programmable ? &*programmable : nullptr);
            if (!vertex) {
                set_gl_error(call, gles_abi::invalid_operation);
                return;
            }
            vertices.push_back(*vertex);
        }
        if (vertices.size() <
            GlesPrimitiveAssembler::minimum_vertex_count(mode))
            return;
    }
    const auto binding = resolve_render_target(call, *context);
    if (!binding) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    if (binding->backing_identifier && binding->host_surface && display_) {
        scanout_composition_.begin_draw(binding->key, binding->host_surface,
            display_->width(), display_->height());
    }
    auto target = render_target(call, *binding);
    if (!target) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto viewport_width =
        context->viewport[2] > 0
            ? static_cast<std::uint32_t>(context->viewport[2])
            : target->width;
    const auto viewport_height =
        context->viewport[3] > 0
            ? static_cast<std::uint32_t>(context->viewport[3])
            : target->height;
    GlesRasterState state;
    state.resource_owner = renderer_owner_;
    state.viewport_x = context->viewport[0];
    state.viewport_y = context->viewport[1];
    state.viewport_width = viewport_width;
    state.viewport_height = viewport_height;
    state.resources = &resources_;
    state.blend_enabled =
        context->enabled_capabilities.contains(gles_abi::blend);
    state.cull_enabled =
        context->enabled_capabilities.contains(gles_abi::cull_face);
    state.scissor_enabled =
        context->enabled_capabilities.contains(gles_abi::scissor_test);
    state.scissor_box = context->scissor_box;
    state.color_mask = context->color_mask;
    state.blend_source = context->blend_source;
    state.blend_destination = context->blend_destination;
    state.cull_mode = context->cull_mode;
    state.front_face = context->front_face;
    state.line_width = context->line_width;
    state.render_target_inverted_vertical = binding->inverted_vertical;
    state.render_target_premultiplied = binding->premultiplied;
    auto* pixmap_surface = binding->pixmap_surface;
    for (std::size_t unit_index = 0; unit_index < context->texture_units.size();
        ++unit_index) {
        const auto& unit = context->texture_units[unit_index];
        const auto rectangle_enabled =
            programmable ? programmable->rectangle_textures[unit_index]
                         : (!interpreted && unit.texture_rectangle_enabled);
        auto& raster_unit = state.texture_units[unit_index];
        // A sampler reads the 2D texture bound to its unit.
        raster_unit.enabled =
            interpreted ? unit.bound_texture_2d != 0U
            : programmable
                ? programmable->sampled_textures[unit_index]
                : rectangle_enabled || unit.texture_2d_enabled;
        raster_unit.rectangle = rectangle_enabled;
        raster_unit.environment =
            programmable ? programmable->texture_environments[unit_index]
                         : unit.texture_environment;
        raster_unit.texture = rectangle_enabled ? unit.bound_texture_rectangle
                                                : unit.bound_texture_2d;
        if (!raster_unit.enabled)
            continue;
        if (pixmap_surface == nullptr ||
            !pixmap_surface->refreshed_textures.contains(raster_unit.texture)) {
            const auto refresh_error = resources_.refresh_surface_texture(
                call.memory(), raster_unit.texture, *surface_store_);
            if (refresh_error != gles_abi::no_error) {
                set_gl_error(call, refresh_error);
                return;
            }
            if (pixmap_surface != nullptr)
                pixmap_surface->refreshed_textures.insert(raster_unit.texture);
        }
    }
    if (interpreted) {
        if (!rasterize_shaded(call, *binding, *target, state, *shaded, mode))
            set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    bool restored_scanout_background = false;
    if (binding->backing_identifier && binding->host_surface && display_ &&
        command_encoder_ &&
        !scanout_composition_.restore_background(call.process_id(),
            binding->key, binding->host_surface, display_->width(),
            display_->height(), state, resources_, vertices, mode,
            *command_encoder_, restored_scanout_background)) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    if (restored_scanout_background) {
        target = render_target(call, *binding);
        if (!target) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
    }
    const auto capture_scanout_background =
        binding->backing_identifier && binding->host_surface && display_ &&
        scanout_composition_.is_background_draw(binding->host_surface,
            display_->width(), display_->height(), state, vertices);
    const auto textured_background_candidate = std::ranges::any_of(
        state.texture_units, [](const auto& unit) { return unit.enabled; });
    const auto save_scanout_background = [&] {
        return !capture_scanout_background ||
               (command_encoder_ &&
                   scanout_composition_.capture_background(call.process_id(),
                       renderer_owner_, binding->key, binding->host_surface,
                       *renderer_, *command_encoder_,
                       textured_background_candidate));
    };
    const auto target_key = binding->key;
    const auto surface_target = binding->host_surface != nullptr;
    if (!surface_target) {
        renderer_->invalidate(target_key);
    }
    performance_counters().record_draw();
    auto rendered = renderer_->draw(*target, target_key, vertices, mode, state);
    if (rendered && binding->premultiplied && binding->host_surface) {
        scanout_composition_.observe_local_background_draw(
            binding->host_surface, state, resources_, vertices, mode);
    }
    const auto native_rendered =
        rendered && surface_target && renderer_->accelerated() &&
        renderer_->failure_reason() == PerfFallbackReason::None;
    if (native_rendered) {
        static_cast<void>(binding->host_surface->mark_gpu_write());
        if (binding->framebuffer_texture != 0U) {
            resources_.update_texture_render_target_generation(
                binding->framebuffer_texture, 0U);
        }
        if (!save_scanout_background())
            set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    if (rendered && !surface_target) {
        rendered = renderer_->synchronize(*target, target_key);
    }
    if (!rendered ||
        !commit_render_target(call, *binding, std::move(*target)) ||
        !save_scanout_background()) {
        set_gl_error(call, gles_abi::invalid_operation);
    }
}

bool OpenGlesHle::load_target_pixels(
    const RenderTargetBinding& binding, DisplayFrame& frame)
{
    if (binding.host_surface && renderer_->accelerated()) {
        // The newest image lives with the GPU and the frame carries no CPU
        // pixels: bring it back and read the surface's CPU copy, as a texture
        // sampled by a draw is.
        if (!renderer_->map_cpu(
                *binding.host_surface, true, PerfCpuMapReason::SoftwareFallback))
            return false;
        auto mapping = binding.host_surface->map_cpu(
            false, PerfCpuMapReason::SoftwareFallback);
        frame.width = mapping.frame().width;
        frame.height = mapping.frame().height;
        frame.pixels = mapping.frame().pixels;
    } else if (!renderer_->synchronize(frame, binding.key)) {
        return false;
    }
    return frame.pixels.size() ==
           static_cast<std::size_t>(frame.width) * frame.height;
}

void OpenGlesHle::read_pixels(UserlandHleCall& call)
{
    auto* context = current_context(call);
    if (context == nullptr) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto x = static_cast<std::int32_t>(call.argument(0));
    const auto y = static_cast<std::int32_t>(call.argument(1));
    const auto width = static_cast<std::int32_t>(call.argument(2));
    const auto height = static_cast<std::int32_t>(call.argument(3));
    const auto format = call.argument(4);
    const auto type = call.argument(5);
    const auto destination = call.argument(6);
    if (width < 0 || height < 0) {
        set_gl_error(call, gles_abi::invalid_value);
        return;
    }
    // GLES 2 guarantees only this pair; the tests and engines that read
    // pixels back ask for it.
    if (format != gles_abi::rgba || type != gles_abi::unsigned_byte) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    if (width == 0 || height == 0)
        return;
    if (destination == 0U) {
        set_gl_error(call, gles_abi::invalid_value);
        return;
    }
    const auto binding = resolve_render_target(call, *context);
    if (!binding) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    auto frame = render_target(call, *binding);
    if (!frame) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    if (!load_target_pixels(*binding, *frame)) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto alignment = std::max<std::uint32_t>(1U, context->pack_alignment);
    const auto unpadded_row = static_cast<std::uint64_t>(width) * 4U;
    const auto row_bytes = (unpadded_row + alignment - 1U) / alignment *
                           alignment;
    const auto last_byte = static_cast<std::uint64_t>(destination) +
                           row_bytes * static_cast<std::uint64_t>(height - 1) +
                           unpadded_row;
    if (last_byte > std::numeric_limits<std::uint32_t>::max()) {
        set_gl_error(call, gles_abi::invalid_operation);
        return;
    }
    const auto frame_height = static_cast<std::int64_t>(frame->height);
    for (std::int32_t row = 0; row < height; ++row) {
        // GL rows count up from the lower edge. A texture-backed target keeps
        // its first row there; a drawable's rows are in panel order.
        const auto gl_row = static_cast<std::int64_t>(y) + row;
        if (gl_row < 0 || gl_row >= frame_height)
            continue;
        const auto source_row = binding->inverted_vertical
                                    ? gl_row
                                    : frame_height - 1 - gl_row;
        for (std::int32_t column = 0; column < width; ++column) {
            const auto gl_column = static_cast<std::int64_t>(x) + column;
            if (gl_column < 0 ||
                gl_column >= static_cast<std::int64_t>(frame->width))
                continue;
            const auto pixel = frame->pixels[static_cast<std::size_t>(
                source_row * frame->width + gl_column)];
            const auto address = static_cast<std::uint32_t>(destination +
                                 row_bytes * static_cast<std::uint64_t>(row) +
                                 static_cast<std::uint64_t>(column) * 4U);
            const std::array<std::uint8_t, 4> bytes {
                static_cast<std::uint8_t>(pixel >> 16U),
                static_cast<std::uint8_t>(pixel >> 8U),
                static_cast<std::uint8_t>(pixel),
                static_cast<std::uint8_t>(pixel >> 24U) };
            for (std::uint32_t index = 0; index < bytes.size(); ++index) {
                if (!call.memory().write8(address + index, bytes[index])) {
                    set_gl_error(call, gles_abi::invalid_operation);
                    return;
                }
            }
        }
    }
}

void OpenGlesHle::register_eagl(UserlandHleRegistry& registry)
{
    // Resolve the native capability without patching its Objective-C entry.
    registry.register_guest_function(std::string { opengles_image },
        "-[EAGLContext GetMacroContextPrivate]");
    registry.register_guest_function(std::string { opengles_image },
        "_EAGLGetCurrentMacroContextPrivate");
    registry.register_objc_instance_method(std::string { opengles_image },
        "EAGLContext",
        "initWithAPI:properties:", "-[EAGLContext initWithAPI:properties:]",
        [this](UserlandHleCall& call) {
            const auto object = call.argument(0);
            const auto api = call.argument(2);
            if (object == 0U || (api != 1U && api != 2U)) {
                call.set_return(0U);
                return;
            }
            const auto process_id = call.process_id();
            if (!eagl_context_abi_)
                eagl_context_abi_ = detect_eagl_context_abi(call);
            if (*eagl_context_abi_ ==
                EaglContextAbi::HostManagedPublicAbi) {
                const auto key = std::pair { process_id, object };
                if (!eagl_contexts_.contains(key)) {
                    const auto handle = next_context_++;
                    contexts_.emplace(handle, default_context_state());
                    eagl_contexts_.emplace(key, handle);
                }
                call.set_return(object);
                return;
            }
            call.resume_original_persistently([this, process_id](
                                                  UserlandHleCall& completed) {
                const auto initialized_object = completed.argument(0);
                if (initialized_object == 0U)
                    return;
                const auto key = std::pair { process_id, initialized_object };
                if (eagl_contexts_.contains(key))
                    return;
                const auto driver_context = dispatch_hle_->context_for_object(
                    completed, initialized_object);
                const auto handle = driver_context ? *driver_context : next_context_++;
                if (!driver_context)
                    contexts_.emplace(handle, default_context_state());
                eagl_contexts_.emplace(key, handle);
            });
        });
    registry.register_objc_class_method(std::string { opengles_image },
        "EAGLContext",
        "setCurrentContext:", "+[EAGLContext setCurrentContext:]",
        [this](UserlandHleCall& call) {
            const auto process_id = call.process_id();
            const auto object = call.argument(2);
            if (!eagl_context_abi_)
                eagl_context_abi_ = detect_eagl_context_abi(call);
            if (*eagl_context_abi_ ==
                EaglContextAbi::FirmwareMacroDispatch) {
                call.resume_original_persistently(
                    [this, process_id, object](UserlandHleCall& completed) {
                        if (completed.argument(0) == 0U)
                            return;
                        auto& current = thread(completed);
                        if (object == 0U) {
                            current.context = 0U;
                            return;
                        }
                        const auto key = std::pair { process_id, object };
                        auto context = eagl_contexts_.find(key);
                        if (context == eagl_contexts_.end()) {
                            const auto handle = next_context_++;
                            contexts_.emplace(handle, default_context_state());
                            context = eagl_contexts_.emplace(key, handle).first;
                        }
                        current.context = context->second;
                    });
                return;
            }
            auto& current = thread(call);
            const auto key = std::pair { process_id, object };
            const auto hle_context = eagl_contexts_.find(key);
            if (hle_context != eagl_contexts_.end()) {
                current.context = hle_context->second;
                call.set_return(1U);
                return;
            }
            if (object == 0U) {
                const auto current_is_eagl = std::any_of(eagl_contexts_.begin(),
                    eagl_contexts_.end(), [&](const auto& entry) {
                        return entry.first.first == process_id &&
                               entry.second == current.context;
                    });
                if (current_is_eagl) {
                    current.context = 0U;
                    call.set_return(1U);
                    return;
                }
            }
            call.resume_original_persistently([this, process_id, object](
                                                  UserlandHleCall& completed) {
                if (completed.argument(0) == 0U)
                    return;
                auto& completed_thread = thread(completed);
                if (object == 0U) {
                    completed_thread.context = 0U;
                    return;
                }

                // Older engines may reach the public EGL implementation
                // while EAGL switches context. Reuse that firmware-created
                // context when present; only bridge engines whose private
                // current-context path did not establish an HLE context.
                const auto current_is_eagl = std::any_of(eagl_contexts_.begin(),
                    eagl_contexts_.end(), [&](const auto& entry) {
                        return entry.first.first == process_id &&
                               entry.second == completed_thread.context;
                    });
                if (completed_thread.context != 0U && !current_is_eagl)
                    return;

                const auto eagl_key = std::pair { process_id, object };
                auto context = eagl_contexts_.find(eagl_key);
                if (context == eagl_contexts_.end()) {
                    const auto handle = next_context_++;
                    contexts_.emplace(handle, default_context_state());
                    context = eagl_contexts_.emplace(eagl_key, handle).first;
                }
                completed_thread.context = context->second;
            });
        });
    registry.register_objc_class_method(std::string { opengles_image },
        "EAGLContext", "currentContext", "+[EAGLContext currentContext]",
        [this](UserlandHleCall& call) {
            const auto& current_state = thread(call);
            const auto context = std::find_if(eagl_contexts_.begin(),
                eagl_contexts_.end(), [&](const auto& entry) {
                    return entry.first.first == call.process_id() &&
                           entry.second == current_state.context;
                });
            if (context == eagl_contexts_.end()) {
                call.resume_original_persistently();
                return;
            }
            call.set_return(context->first.second);
        });
    const auto register_notification = [this, &registry](std::string selector,
                                           std::string symbol) {
        registry.register_objc_instance_method(std::string { opengles_image },
            "EAGLContext", std::move(selector), std::move(symbol),
            [this](UserlandHleCall& call) {
                const auto context =
                    std::pair { call.process_id(), call.argument(0) };
                if (!eagl_contexts_.contains(context)) {
                    call.resume_original_persistently();
                    return;
                }
                // The host renderer completes synchronously and the
                // IOMobileFramebuffer HLE owns swap ordering, so there is
                // no driver transaction token to forward.
                call.set_return(0U);
            });
    };
    register_notification("swapNotification:forTransaction:onLayer:",
        "-[EAGLContext swapNotification:forTransaction:onLayer:]");
    register_notification("sendNotification:forTransaction:onLayer:",
        "-[EAGLContext sendNotification:forTransaction:onLayer:]");
    registry.register_objc_instance_method(std::string { opengles_image },
        "EAGLContext", "renderbufferStorage:fromDrawable:",
        "-[EAGLContext renderbufferStorage:fromDrawable:]",
        [this](UserlandHleCall& call) {
            auto* context = eagl_context(call);
            if (context == nullptr ||
                call.argument(2) != gles_abi::renderbuffer ||
                context->bound_renderbuffer == 0U) {
                call.set_return(0U);
                return;
            }
            const auto geometry =
                display_geometry_for_process(shared_state_, call.process_id(),
                    display_ ? display_->geometry() : default_display_geometry);
            const auto error = ensure_renderbuffer_storage(*context,
                context->bound_renderbuffer, geometry.width, geometry.height,
                gles_abi::bgra_apple);
            if (error == gles_abi::no_error)
                context->renderbuffers.at(context->bound_renderbuffer)
                    .display_oriented = true;
            call.set_return(error == gles_abi::no_error ? 1U : 0U);
        });
    registry.register_objc_instance_method(std::string { opengles_image },
        "EAGLContext",
        "presentRenderbuffer:", "-[EAGLContext presentRenderbuffer:]",
        [this](UserlandHleCall& call) {
            auto* context = eagl_context(call);
            if (context == nullptr ||
                call.argument(2) != gles_abi::renderbuffer ||
                context->bound_renderbuffer == 0U) {
                call.set_return(0U);
                return;
            }
            auto framebuffer = context->framebuffers.end();
            for (auto candidate = context->framebuffers.begin();
                candidate != context->framebuffers.end(); ++candidate) {
                if (candidate->second.color_renderbuffer ==
                    context->bound_renderbuffer) {
                    framebuffer = candidate;
                    break;
                }
            }
            if (framebuffer == context->framebuffers.end() &&
                context->bound_framebuffer != 0U)
                framebuffer =
                    context->framebuffers.find(context->bound_framebuffer);
            if (framebuffer == context->framebuffers.end()) {
                call.set_return(0U);
                return;
            }
            const auto saved_framebuffer = context->bound_framebuffer;
            context->bound_framebuffer = framebuffer->first;
            const auto binding = resolve_render_target(call, *context);
            context->bound_framebuffer = saved_framebuffer;
            if (!binding ||
                !publish_display_surface(call, binding->host_surface)) {
                call.set_return(0U);
                return;
            }
            display_->present(call.process_id());
            call.set_return(1U);
        });
    registry.register_objc_instance_method(std::string { opengles_image },
        "EAGLContext", "attachImage:toCoreSurface:invertedRender:",
        "-[EAGLContext attachImage:toCoreSurface:invertedRender:]",
        [this](UserlandHleCall& call) {
            auto* context = eagl_context(call);
            const auto target = call.argument(2);
            const auto inverted_render =
                static_cast<std::uint8_t>(call.argument(4)) != 0U;
            const auto identifier =
                core_surface_identifier(call, call.argument(3));
            if (context == nullptr || !identifier) {
                call.set_return(0U);
                return;
            }
            std::uint32_t texture { };
            if (target == gles_abi::texture_rectangle_apple ||
                target == gles_abi::texture_2d) {
                const auto& unit =
                    context->texture_units[context->active_texture_unit];
                texture = target == gles_abi::texture_rectangle_apple
                              ? unit.bound_texture_rectangle
                              : unit.bound_texture_2d;
            } else if (target == gles_abi::renderbuffer &&
                       context->bound_framebuffer != 0U) {
                const auto framebuffer =
                    context->framebuffers.find(context->bound_framebuffer);
                if (framebuffer != context->framebuffers.end())
                    texture = framebuffer->second.color_texture;
            }
            if (texture == 0U) {
                call.set_return(0U);
                return;
            }
            // Guest texture row zero is the GL lower edge while host render
            // targets use top-left row order. A normal EAGL render reverses
            // target Y; invertedRender asks the driver for the opposite.
            const auto requires_vertical_flip = !inverted_render;
            const auto error = resources_.import_surface_texture(call.memory(),
                texture, *surface_store_, *identifier, requires_vertical_flip);
            if (error == gles_abi::no_error) {
                context->guest_capabilities =
                    open_gles_framebuffer_capabilities(context->guest_capabilities);
            }
            call.set_return(error == gles_abi::no_error ? 1U : 0U);
        });
}

void OpenGlesHle::register_egl(UserlandHleRegistry& registry)
{
    const auto add = [&](std::string symbol,
                         UserlandHleRegistry::Handler handler) {
        registry.register_function(std::string { opengles_image },
            std::move(symbol), std::move(handler));
    };
    add("_eglGetDisplay", [this](UserlandHleCall& call) {
        egl_error_ = egl_success;
        call.set_return(egl_default_display);
    });
    add("_eglInitialize", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        if (!call.write32(call.argument(1), 1) ||
            !call.write32(call.argument(2), 1)) {
            egl_error_ = egl_bad_parameter;
            call.set_return(egl_false);
            return;
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    add("_eglTerminate", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    add("_eglGetError", [this](UserlandHleCall& call) {
        call.set_return(egl_error_);
        egl_error_ = egl_success;
    });
    const auto enumerate_configs = [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        const auto choose = call.symbol() == "_eglChooseConfig";
        const auto configs = call.argument(choose ? 2U : 1U);
        const auto capacity = call.argument(choose ? 3U : 2U);
        const auto count = call.argument(choose ? 4U : 3U);
        std::vector<const EglConfigDescriptor*> matches;
        matches.reserve(egl_configs.size());
        for (const auto& config : egl_configs) {
            auto matches_config = true;
            if (choose && call.argument(1) != 0) {
                auto cursor = call.argument(1);
                auto terminated = false;
                for (std::size_t index = 0; index < 64; ++index) {
                    const auto attribute = call.memory().read32(cursor);
                    if (!attribute) {
                        egl_error_ = egl_bad_parameter;
                        call.set_return(egl_false);
                        return;
                    }
                    if (*attribute == egl_none) {
                        terminated = true;
                        break;
                    }
                    const auto requested = call.memory().read32(cursor + 4U);
                    if (!requested) {
                        egl_error_ = egl_bad_parameter;
                        call.set_return(egl_false);
                        return;
                    }
                    if (const auto actual =
                            egl_config_attribute(config, *attribute)) {
                        if (*requested == egl_dont_care) {
                            // EGL_DONT_CARE leaves this attribute unfiltered.
                        } else if (*attribute == egl_config_id) {
                            matches_config &= *actual == *requested;
                        } else if (*attribute == egl_surface_type ||
                                   *attribute == egl_renderable_type) {
                            matches_config &=
                                (*actual & *requested) == *requested;
                        } else {
                            matches_config &= *actual >= *requested;
                        }
                    }
                    cursor += 8U;
                }
                if (!terminated) {
                    egl_error_ = egl_bad_attribute;
                    call.set_return(egl_false);
                    return;
                }
            }
            if (matches_config)
                matches.push_back(&config);
        }
        if (!call.write32(count, static_cast<std::uint32_t>(matches.size()))) {
            egl_error_ = egl_bad_parameter;
            call.set_return(egl_false);
            return;
        }
        const auto written = std::min<std::size_t>(capacity, matches.size());
        for (std::size_t index = 0; configs != 0 && index < written; ++index) {
            if (!call.memory().write32(
                    configs + static_cast<std::uint32_t>(index * 4U),
                    matches[index]->handle)) {
                egl_error_ = egl_bad_parameter;
                call.set_return(egl_false);
                return;
            }
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    };
    add("_eglGetConfigs", enumerate_configs);
    add("_eglChooseConfig", enumerate_configs);
    add("_eglGetConfigAttrib", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        const auto* config = egl_config(call.argument(1));
        if (!config) {
            egl_error_ = egl_bad_parameter;
            call.set_return(egl_false);
            return;
        }
        const auto value = egl_config_attribute(*config, call.argument(2));
        if (!value) {
            egl_error_ = egl_bad_attribute;
            call.set_return(egl_false);
            return;
        }
        if (!call.write32(call.argument(3), *value)) {
            egl_error_ = egl_bad_parameter;
            call.set_return(egl_false);
            return;
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    add("_eglCreateContext", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(0);
            return;
        }
        if (!egl_config(call.argument(1))) {
            egl_error_ = egl_bad_parameter;
            call.set_return(0);
            return;
        }
        const auto context = next_context_++;
        contexts_.emplace(context, default_context_state());
        egl_error_ = egl_success;
        call.set_return(context);
    });
    add("_eglDestroyContext", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        const auto destroyed = call.argument(1);
        if (contexts_.erase(destroyed) == 0) {
            egl_error_ = egl_bad_context;
            call.set_return(egl_false);
            return;
        }
        for (auto& [processor, current] : threads_) {
            static_cast<void>(processor);
            if (current.context == destroyed)
                current = { };
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    const auto create_surface = [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(0);
            return;
        }
        if (!egl_config(call.argument(1))) {
            egl_error_ = egl_bad_parameter;
            call.set_return(0);
            return;
        }
        SurfaceState state;
        const auto geometry = display_geometry_for_process(shared_state_,
            call.process_id(),
            display_ ? display_->geometry() : default_display_geometry);
        state.width = geometry.width;
        state.height = geometry.height;
        if (call.symbol() == "_eglCreatePixmapSurface") {
            const auto identifier =
                core_surface_identifier(call, call.argument(2));
            const auto backing =
                identifier ? surface_store_->find(*identifier) : std::nullopt;
            const auto pixels = identifier ? surface_store_->read_argb(
                                                 call.memory(), *identifier)
                                           : std::nullopt;
            if (!identifier || !backing || !pixels) {
                egl_error_ = egl_bad_parameter;
                call.set_return(0);
                return;
            }
            state.backing_identifier = *identifier;
            state.width = backing->width;
            state.height = backing->height;
            state.pixels = std::move(*pixels);
            if (const auto host_surface =
                    surface_store_->host_surface(*identifier)) {
                state.backing_cpu_generation = host_surface->cpu_generation();
            }
        }
        const auto surface = next_surface_++;
        surfaces_.emplace(surface, std::move(state));
        egl_error_ = egl_success;
        call.set_return(surface);
    };
    add("_eglCreateWindowSurface", create_surface);
    add("_eglCreatePbufferSurface", create_surface);
    add("_eglCreatePixmapSurface", create_surface);
    add("_eglDestroySurface", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        const auto surface = call.argument(1);
        if (!surfaces_.contains(surface)) {
            egl_error_ = egl_bad_surface;
            call.set_return(egl_false);
            return;
        }
        const auto& state = surfaces_.at(surface);
        const auto committed =
            state.backing_identifier
                ? renderer_->flush(render_target_key(surface))
                : flush_surface(call, surface);
        if (!committed) {
            egl_error_ = egl_bad_surface;
            call.set_return(egl_false);
            return;
        }
        if (!surfaces_.at(surface).backing_identifier) {
            const auto target = render_target_key(surface);
            renderer_->release(std::span { &target, 1U });
        }
        surfaces_.erase(surface);
        for (auto& [processor, current] : threads_) {
            static_cast<void>(processor);
            if (current.draw_surface == surface)
                current.draw_surface = 0;
            if (current.read_surface == surface)
                current.read_surface = 0;
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    add("_eglMakeCurrent", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        const auto draw = call.argument(1);
        const auto read = call.argument(2);
        const auto context = call.argument(3);
        if ((context != 0 && !contexts_.contains(context)) ||
            (draw != 0 && !surfaces_.contains(draw)) ||
            (read != 0 && !surfaces_.contains(read))) {
            egl_error_ = context != 0 && !contexts_.contains(context)
                             ? egl_bad_context
                             : egl_bad_surface;
            call.set_return(egl_false);
            return;
        }
        auto& current = thread(call);
        if (current.draw_surface != 0 && current.draw_surface != draw) {
            const auto previous = surfaces_.find(current.draw_surface);
            const auto committed =
                previous != surfaces_.end() &&
                        previous->second.backing_identifier
                    ? renderer_->flush(render_target_key(current.draw_surface))
                    : flush_surface(call, current.draw_surface);
            if (!committed) {
                egl_error_ = egl_bad_surface;
                call.set_return(egl_false);
                return;
            }
        }
        if (draw != 0 && current.draw_surface != draw &&
            !reload_surface(call, draw)) {
            egl_error_ = egl_bad_surface;
            call.set_return(egl_false);
            return;
        }
        current.display = context == 0 ? 0 : egl_default_display;
        current.draw_surface = draw;
        current.read_surface = read;
        current.context = context;
        if (context != 0 && draw != 0 &&
            surfaces_.at(draw).backing_identifier) {
            auto& profile = contexts_.at(context).guest_capabilities;
            profile = open_gles_framebuffer_capabilities(profile);
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    add("_eglGetCurrentContext", [this](UserlandHleCall& call) {
        call.set_return(thread(call).context);
    });
    add("_eglGetCurrentDisplay", [this](UserlandHleCall& call) {
        call.set_return(thread(call).display);
    });
    add("_eglGetCurrentSurface", [this](UserlandHleCall& call) {
        const auto& current = thread(call);
        call.set_return(call.argument(0) == 0x305aU ? current.read_surface
                                                    : current.draw_surface);
    });
    add("_eglSwapBuffers", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0)) ||
            !surfaces_.contains(call.argument(1))) {
            egl_error_ = !is_valid_display(call.argument(0)) ? egl_bad_display
                                                             : egl_bad_surface;
            call.set_return(egl_false);
            return;
        }
        const auto surface = call.argument(1);
        const auto& state = surfaces_.at(surface);
        const auto committed =
            state.backing_identifier
                ? renderer_->flush(render_target_key(surface))
                : flush_surface(call, surface);
        if (!committed) {
            egl_error_ = egl_bad_surface;
            call.set_return(egl_false);
            return;
        }
        ++frame_count_;
        const auto found = surfaces_.find(surface);
        if (found != surfaces_.end() && !found->second.backing_identifier &&
            display_ && display_write_allowed(call)) {
            display_->present(call.process_id());
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    add("_eglSwapInterval", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    });
    add("_eglQueryString", [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(0);
            return;
        }
        std::string_view value;
        switch (call.argument(1)) {
        case egl_vendor:
            value = "Shade";
            break;
        case egl_version:
            value = "1.1 Shade userland HLE";
            break;
        case egl_extensions:
            value = "";
            break;
        default:
            egl_error_ = egl_bad_parameter;
            call.set_return(0);
            return;
        }
        egl_error_ = egl_success;
        call.set_return(call.intern_string(value));
    });
    const auto query_object = [this](UserlandHleCall& call) {
        if (!is_valid_display(call.argument(0))) {
            egl_error_ = egl_bad_display;
            call.set_return(egl_false);
            return;
        }
        std::uint32_t value = 0;
        if (call.symbol() == "_eglQuerySurface") {
            const auto surface = surfaces_.find(call.argument(1));
            if (surface == surfaces_.end()) {
                egl_error_ = egl_bad_surface;
                call.set_return(egl_false);
                return;
            }
            if (call.argument(2) == egl_width) {
                value = surface->second.width;
            }
            if (call.argument(2) == egl_height) {
                value = surface->second.height;
            }
        } else {
            if (!contexts_.contains(call.argument(1))) {
                egl_error_ = egl_bad_context;
                call.set_return(egl_false);
                return;
            }
            if (call.argument(2) == egl_context_client_version)
                value = 1;
        }
        if (!call.write32(call.argument(3), value)) {
            egl_error_ = egl_bad_parameter;
            call.set_return(egl_false);
            return;
        }
        egl_error_ = egl_success;
        call.set_return(egl_true);
    };
    add("_eglQuerySurface", query_object);
    add("_eglQueryContext", query_object);
    add("_eglGetProcAddress", [](UserlandHleCall& call) {
        const auto name = call.string_argument(0, 256);
        call.set_return(
            name ? call.symbol_address("_" + *name).value_or(0) : 0);
    });
    const auto success = [this](UserlandHleCall& call) {
        egl_error_ = egl_success;
        call.set_return(egl_true);
    };
    add("_eglWaitGL", success);
    add("_eglWaitNative", success);
    add("_eglCopyBuffers", success);
    add("_eglBindTexImage", success);
    add("_eglReleaseTexImage", success);
    add("_eglSurfaceAttrib", success);
    add("_eglSwapNotification", success);
    registry.register_prefix(std::string { opengles_image }, "_egl",
        [this](UserlandHleCall& call) { unsupported(call); });
}

void OpenGlesHle::register_gles(UserlandHleRegistry& registry)
{
    const auto add = [&](std::string symbol,
                         UserlandHleRegistry::Handler handler) {
        registry.register_function(std::string { opengles_image },
            std::move(symbol), std::move(handler));
    };
    add("_glGetError", [this](UserlandHleCall& call) {
        auto& current = thread(call);
        call.set_return(current.gl_error);
        current.gl_error = gl_no_error;
    });
    add("_glGetString", [this](UserlandHleCall& call) {
        const auto* context = current_context(call);
        const auto& profile = open_gles_guest_capabilities(
            context ? context->guest_capabilities
                    : OpenGlesGuestCapabilitySet::MbxLiteLegacy);
        std::string_view value;
        switch (call.argument(0)) {
        case gl_vendor:
            value = profile.vendor;
            break;
        case gl_renderer:
            value = profile.renderer;
            break;
        case gl_version:
            value = profile.version;
            break;
        case gl_extensions:
            value = profile.extensions;
            break;
        default:
            call.set_return(0);
            return;
        }
        call.set_return(call.intern_string(value));
    });
    add("_glActiveTexture", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto texture = call.argument(0);
        const auto index = texture >= gles_abi::texture0
                               ? texture - gles_abi::texture0
                               : std::numeric_limits<std::uint32_t>::max();
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (index >= open_gles_guest_capabilities(context->guest_capabilities)
                                .texture_units) {
            set_gl_error(call, gles_abi::invalid_enum);
        } else {
            context->active_texture_unit = index;
        }
    });
    add("_glClientActiveTexture", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto texture = call.argument(0);
        const auto index = texture >= gles_abi::texture0
                               ? texture - gles_abi::texture0
                               : std::numeric_limits<std::uint32_t>::max();
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (index >= open_gles_guest_capabilities(context->guest_capabilities)
                                .texture_units) {
            set_gl_error(call, gles_abi::invalid_enum);
        } else {
            context->client_active_texture_unit = index;
        }
    });
    add("_glColor4f", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        for (std::size_t component = 0;
            component < context->current_color.size(); ++component) {
            context->current_color[component] =
                std::bit_cast<float>(call.argument(component));
        }
    });
    add("_glColor4ub", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        for (std::size_t component = 0;
            component < context->current_color.size(); ++component) {
            context->current_color[component] =
                static_cast<float>(call.argument(component) & 0xffU) / 255.0F;
        }
    });
    add("_glLineWidth", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto width = std::bit_cast<float>(call.argument(0));
        if (!std::isfinite(width) || width <= 0.0F) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        context->line_width = width;
    });
    add("_glGetIntegerv", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto output = call.argument(1);
        if (context == nullptr || output == 0) {
            set_gl_error(call, context == nullptr ? gles_abi::invalid_operation
                                                  : gles_abi::invalid_value);
            return;
        }
        std::array<std::uint32_t, 4> values { };
        std::size_t count = 1;
        switch (call.argument(0)) {
        case gles_abi::pack_alignment:
            values[0] = context->pack_alignment;
            break;
        case gles_abi::unpack_alignment:
            values[0] = context->unpack.alignment;
            break;
        case gles_abi::unpack_row_length:
            values[0] = context->unpack.row_length;
            break;
        case gles_abi::unpack_skip_rows:
            values[0] = context->unpack.skip_rows;
            break;
        case gles_abi::unpack_skip_pixels:
            values[0] = context->unpack.skip_pixels;
            break;
        case gles_abi::unpack_row_bytes_apple:
            values[0] = context->unpack.row_bytes;
            break;
        case gles_abi::unpack_client_storage_apple:
            values[0] = context->unpack_client_storage ? 1U : 0U;
            break;
        case gles_abi::viewport_query:
            count = context->viewport.size();
            for (std::size_t index = 0; index < count; ++index) {
                values[index] =
                    static_cast<std::uint32_t>(context->viewport[index]);
            }
            break;
        case gles_abi::scissor_box:
            count = context->scissor_box.size();
            for (std::size_t index = 0; index < count; ++index) {
                values[index] =
                    static_cast<std::uint32_t>(context->scissor_box[index]);
            }
            break;
        case gles_abi::color_write_mask:
            count = context->color_mask.size();
            for (std::size_t index = 0; index < count; ++index) {
                values[index] = context->color_mask[index] ? 1U : 0U;
            }
            break;
        case gles_abi::matrix_mode_query:
            values[0] = context->matrix_mode;
            break;
        case gles_abi::framebuffer_binding:
            values[0] = context->bound_framebuffer;
            break;
        case gles_abi::renderbuffer_binding:
            values[0] = context->bound_renderbuffer;
            break;
        case gles_abi::texture_binding_2d:
            values[0] = context->texture_units[context->active_texture_unit]
                            .bound_texture_2d;
            break;
        case gles_abi::texture_binding_rectangle_apple:
            values[0] = context->texture_units[context->active_texture_unit]
                            .bound_texture_rectangle;
            break;
        case gles_abi::active_texture:
            values[0] = gles_abi::texture0 + static_cast<std::uint32_t>(
                                                 context->active_texture_unit);
            break;
        case gles_abi::client_active_texture:
            values[0] =
                gles_abi::texture0 +
                static_cast<std::uint32_t>(context->client_active_texture_unit);
            break;
        case gles_abi::maximum_texture_units:
        case gles_abi::maximum_texture_image_units:
            values[0] = open_gles_guest_capabilities(context->guest_capabilities)
                            .texture_units;
            break;
        case gles_abi::maximum_texture_size:
            values[0] = open_gles_guest_capabilities(context->guest_capabilities)
                            .maximum_texture_dimension;
            break;
        case gles_abi::maximum_viewport_dimensions:
            count = 2;
            values[0] = open_gles_guest_capabilities(context->guest_capabilities)
                            .maximum_viewport_dimension;
            values[1] = values[0];
            break;
        case gles_abi::maximum_rectangle_texture_size_apple:
            values[0] = open_gles_guest_capabilities(context->guest_capabilities)
                            .maximum_texture_dimension;
            break;
        case gles_abi::front_face_query:
            values[0] = context->front_face;
            break;
        case gles_abi::cull_face_mode:
            values[0] = context->cull_mode;
            break;
        case gles_abi::depth_write_mask:
            values[0] = context->depth_mask ? 1U : 0U;
            break;
        case gles_abi::stencil_write_mask:
            values[0] = context->stencil_mask;
            break;
        default:
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        for (std::size_t index = 0; index < count; ++index) {
            if (!call.memory().write32(
                    output + static_cast<std::uint32_t>(index * 4U),
                    values[index])) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
        }
    });
    add("_glGetFloatv", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto output = call.argument(1);
        if (context == nullptr || output == 0) {
            set_gl_error(call, context == nullptr ? gles_abi::invalid_operation
                                                  : gles_abi::invalid_value);
            return;
        }
        const std::array<float, 16>* values { };
        std::array<float, 16> current { };
        std::size_t count { };
        if (call.argument(0) == gles_abi::current_color) {
            std::copy(context->current_color.begin(),
                context->current_color.end(), current.begin());
            values = &current;
            count = context->current_color.size();
        } else if (call.argument(0) == gles_abi::line_width_query) {
            current[0] = context->line_width;
            values = &current;
            count = 1U;
        } else if (call.argument(0) == gles_abi::modelview_matrix_query) {
            values = &context->modelview_matrix.values();
            count = values->size();
        } else if (call.argument(0) == gles_abi::projection_matrix_query) {
            values = &context->projection_matrix.values();
            count = values->size();
        } else if (call.argument(0) == gles_abi::texture_matrix_query) {
            values = &context->texture_units[context->active_texture_unit]
                          .texture_matrix.values();
            count = values->size();
        } else {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        for (std::size_t index = 0; index < count; ++index) {
            if (!call.memory().write32(
                    output + static_cast<std::uint32_t>(index * 4U),
                    std::bit_cast<std::uint32_t>((*values)[index]))) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
        }
    });
    add("_glMatrixMode", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto mode = call.argument(0);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (mode != gles_abi::modelview &&
                   mode != gles_abi::projection &&
                   mode != gles_abi::texture_matrix) {
            set_gl_error(call, gles_abi::invalid_enum);
        } else {
            context->matrix_mode = mode;
        }
    });
    add("_glLoadIdentity", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        auto* matrix = context == nullptr ? nullptr : current_matrix(*context);
        if (matrix == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else {
            *matrix = GlesMatrix { };
        }
    });
    const auto matrix_data = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        auto* current = context == nullptr ? nullptr : current_matrix(*context);
        const auto address = call.argument(0);
        if (current == nullptr || address == 0) {
            set_gl_error(call, current == nullptr ? gles_abi::invalid_operation
                                                  : gles_abi::invalid_value);
            return;
        }
        const auto fixed = call.symbol() == "_glLoadMatrixx" ||
                           call.symbol() == "_glMultMatrixx";
        std::array<float, 16> values { };
        for (std::size_t index = 0; index < values.size(); ++index) {
            const auto raw = call.memory().read32(
                address + static_cast<std::uint32_t>(index * 4U));
            if (!raw) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
            values[index] =
                fixed ? static_cast<float>(static_cast<std::int32_t>(*raw)) /
                            65'536.0F
                      : std::bit_cast<float>(*raw);
        }
        const GlesMatrix matrix { values };
        if (call.symbol() == "_glLoadMatrixf" ||
            call.symbol() == "_glLoadMatrixx") {
            *current = matrix;
        } else {
            *current = *current * matrix;
        }
    };
    add("_glLoadMatrixf", matrix_data);
    add("_glLoadMatrixx", matrix_data);
    add("_glMultMatrixf", matrix_data);
    add("_glMultMatrixx", matrix_data);
    const auto transform = [this](UserlandHleCall& call) {
        const auto fixed = call.symbol() == "_glTranslatex" ||
                           call.symbol() == "_glScalex" ||
                           call.symbol() == "_glRotatex";
        const auto value = [&](std::size_t index) {
            const auto raw = call.argument(index);
            return fixed ? static_cast<float>(static_cast<std::int32_t>(raw)) /
                               65'536.0F
                         : std::bit_cast<float>(raw);
        };
        if (call.symbol() == "_glTranslatef" ||
            call.symbol() == "_glTranslatex") {
            multiply_current_matrix(
                call, GlesMatrix::translation(value(0), value(1), value(2)));
        } else if (call.symbol() == "_glScalef" ||
                   call.symbol() == "_glScalex") {
            multiply_current_matrix(
                call, GlesMatrix::scale(value(0), value(1), value(2)));
        } else {
            multiply_current_matrix(call,
                GlesMatrix::rotation(value(0), value(1), value(2), value(3)));
        }
    };
    add("_glTranslatef", transform);
    add("_glTranslatex", transform);
    add("_glScalef", transform);
    add("_glScalex", transform);
    add("_glRotatef", transform);
    add("_glRotatex", transform);
    const auto projection = [this](UserlandHleCall& call) {
        const auto fixed =
            call.symbol() == "_glOrthox" || call.symbol() == "_glFrustumx";
        const auto value = [&](std::size_t index) {
            const auto raw = call.argument(index);
            return fixed ? static_cast<float>(static_cast<std::int32_t>(raw)) /
                               65'536.0F
                         : std::bit_cast<float>(raw);
        };
        const auto left = value(0);
        const auto right = value(1);
        const auto bottom = value(2);
        const auto top = value(3);
        const auto near_value = value(4);
        const auto far_value = value(5);
        const auto frustum =
            call.symbol() == "_glFrustumf" || call.symbol() == "_glFrustumx";
        if (left == right || bottom == top || near_value == far_value ||
            (frustum && (near_value <= 0.0F || far_value <= 0.0F))) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        multiply_current_matrix(
            call, frustum ? GlesMatrix::frustum(
                                left, right, bottom, top, near_value, far_value)
                          : GlesMatrix::orthographic(left, right, bottom, top,
                                near_value, far_value));
    };
    add("_glOrthof", projection);
    add("_glOrthox", projection);
    add("_glFrustumf", projection);
    add("_glFrustumx", projection);
    add("_glPushMatrix", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        auto* matrix = context == nullptr ? nullptr : current_matrix(*context);
        auto* stack =
            context == nullptr ? nullptr : current_matrix_stack(*context);
        if (matrix == nullptr || stack == nullptr ||
            stack->size() >= gles_abi::maximum_matrix_stack_depth) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        stack->push_back(*matrix);
    });
    add("_glPopMatrix", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        auto* matrix = context == nullptr ? nullptr : current_matrix(*context);
        auto* stack =
            context == nullptr ? nullptr : current_matrix_stack(*context);
        if (matrix == nullptr || stack == nullptr || stack->empty()) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        *matrix = stack->back();
        stack->pop_back();
    });
    add("_glClearColor", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        for (std::size_t index = 0; index < 4; ++index) {
            context->clear_color[index] = call.argument(index);
        }
        const auto channel = [](std::uint32_t bits) {
            const auto value =
                std::clamp(std::bit_cast<float>(bits), 0.0F, 1.0F);
            return static_cast<std::uint32_t>(std::lround(value * 255.0F));
        };
        const auto red = channel(context->clear_color[0]);
        const auto green = channel(context->clear_color[1]);
        const auto blue = channel(context->clear_color[2]);
        const auto alpha = channel(context->clear_color[3]);
        context->clear_argb =
            (alpha << 24U) | (red << 16U) | (green << 8U) | blue;
    });
    add("_glClearColorx", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        for (std::size_t index = 0; index < 4; ++index) {
            context->clear_color[index] = call.argument(index);
        }
        const auto channel = [](std::uint32_t fixed) {
            const auto signed_value = static_cast<std::int32_t>(fixed);
            return static_cast<std::uint32_t>(
                std::clamp(signed_value, 0, 65'536) * 255 / 65'536);
        };
        const auto red = channel(context->clear_color[0]);
        const auto green = channel(context->clear_color[1]);
        const auto blue = channel(context->clear_color[2]);
        const auto alpha = channel(context->clear_color[3]);
        context->clear_argb =
            (alpha << 24U) | (red << 16U) | (green << 8U) | blue;
    });
    add("_glClear", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        constexpr auto supported_bits = gles_abi::color_buffer_bit |
                                        gles_abi::depth_buffer_bit |
                                        gles_abi::stencil_buffer_bit;
        const auto mask = call.argument(0);
        if ((mask & ~supported_bits) != 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        if ((mask & gles_abi::color_buffer_bit) == 0)
            return;
        const auto binding = resolve_render_target(call, *context);
        if (!binding) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        auto frame = render_target(call, *binding);
        if (!frame) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (binding->premultiplied)
            scanout_composition_.invalidate_local_background(
                binding->host_surface);
        const auto target = binding->key;
        const auto clear_argb = binding->premultiplied
                                    ? premultiply_argb(context->clear_argb)
                                    : context->clear_argb;
        const auto all_channels = std::all_of(context->color_mask.begin(),
            context->color_mask.end(), [](bool enabled) { return enabled; });
        const auto scissor_enabled =
            context->enabled_capabilities.contains(gles_abi::scissor_test);
        if (all_channels && renderer_->accelerated() && command_encoder_) {
            const auto& surface = binding->host_surface;
            if (surface) {
                const auto width = static_cast<std::int64_t>(frame->width);
                const auto height = static_cast<std::int64_t>(frame->height);
                std::int64_t left { };
                std::int64_t top { };
                auto right = width;
                auto bottom = height;
                if (scissor_enabled) {
                    const auto requested_left =
                        static_cast<std::int64_t>(context->scissor_box[0]);
                    const auto requested_bottom =
                        static_cast<std::int64_t>(context->scissor_box[1]);
                    const auto requested_right =
                        requested_left +
                        std::max<std::int64_t>(0, context->scissor_box[2]);
                    const auto requested_top =
                        requested_bottom +
                        std::max<std::int64_t>(0, context->scissor_box[3]);
                    left =
                        std::clamp(requested_left, std::int64_t { 0 }, width);
                    right =
                        std::clamp(requested_right, std::int64_t { 0 }, width);
                    if (binding->inverted_vertical) {
                        top = std::clamp(
                            requested_bottom, std::int64_t { 0 }, height);
                        bottom = std::clamp(
                            requested_top, std::int64_t { 0 }, height);
                    } else {
                        top = height - std::clamp(requested_top,
                                           std::int64_t { 0 }, height);
                        bottom = height - std::clamp(requested_bottom,
                                              std::int64_t { 0 }, height);
                    }
                }
                if (right <= left || bottom <= top)
                    return;
                if (command_encoder_->fill(surface,
                        { static_cast<std::int32_t>(left),
                            static_cast<std::int32_t>(top),
                            static_cast<std::uint32_t>(right - left),
                            static_cast<std::uint32_t>(bottom - top) },
                        clear_argb)) {
                    if (binding->framebuffer_texture != 0U) {
                        resources_.update_texture_render_target_generation(
                            binding->framebuffer_texture, 0U);
                    }
                    return;
                }
            }
        }
        if (!renderer_->synchronize(*frame, target)) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (all_channels && !scissor_enabled) {
            std::fill(frame->pixels.begin(), frame->pixels.end(), clear_argb);
            if (!commit_render_target(call, *binding, std::move(*frame))) {
                set_gl_error(call, gles_abi::invalid_operation);
            } else {
                renderer_->invalidate(target);
            }
            return;
        }
        constexpr std::array<std::uint32_t, 4> channel_masks { 0x00ff0000U,
            0x0000ff00U, 0x000000ffU, 0xff000000U };
        for (std::uint32_t y = 0; y < frame->height; ++y) {
            const auto host_y = static_cast<float>(y) + 0.5F;
            const auto guest_y =
                binding->inverted_vertical
                    ? host_y
                    : static_cast<float>(frame->height) - host_y;
            for (std::uint32_t x = 0; x < frame->width; ++x) {
                const auto guest_x = static_cast<float>(x) + 0.5F;
                if (scissor_enabled &&
                    (guest_x < static_cast<float>(context->scissor_box[0]) ||
                        guest_x >=
                            static_cast<float>(context->scissor_box[0]) +
                                static_cast<float>(context->scissor_box[2]) ||
                        guest_y < static_cast<float>(context->scissor_box[1]) ||
                        guest_y >=
                            static_cast<float>(context->scissor_box[1]) +
                                static_cast<float>(context->scissor_box[3]))) {
                    continue;
                }
                const auto offset =
                    static_cast<std::size_t>(y) * frame->width + x;
                auto pixel = frame->pixels[offset];
                for (std::size_t component = 0;
                    component < context->color_mask.size(); ++component) {
                    if (!context->color_mask[component])
                        continue;
                    pixel = (pixel & ~channel_masks[component]) |
                            (clear_argb & channel_masks[component]);
                }
                frame->pixels[offset] = pixel;
            }
        }
        if (!commit_render_target(call, *binding, std::move(*frame))) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else {
            renderer_->invalidate(target);
        }
    });
    add("_glViewport", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto width = static_cast<std::int32_t>(call.argument(2));
        const auto height = static_cast<std::int32_t>(call.argument(3));
        if (width < 0 || height < 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        context->viewport = { static_cast<std::int32_t>(call.argument(0)),
            static_cast<std::int32_t>(call.argument(1)), width, height };
    });
    add("_glScissor", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto width = static_cast<std::int32_t>(call.argument(2));
        const auto height = static_cast<std::int32_t>(call.argument(3));
        if (width < 0 || height < 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        context->scissor_box = { static_cast<std::int32_t>(call.argument(0)),
            static_cast<std::int32_t>(call.argument(1)), width, height };
    });
    add("_glColorMask", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        for (std::size_t component = 0; component < context->color_mask.size();
            ++component) {
            context->color_mask[component] = call.argument(component) != 0;
        }
    });
    add("_glDepthMask", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else {
            context->depth_mask = call.argument(0) != 0;
        }
    });
    add("_glStencilMask", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else {
            context->stencil_mask = call.argument(0);
        }
    });
    add("_glFrontFace", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (call.argument(0) != gles_abi::clockwise &&
                   call.argument(0) != gles_abi::counter_clockwise) {
            set_gl_error(call, gles_abi::invalid_enum);
        } else {
            context->front_face = call.argument(0);
        }
    });
    add("_glCullFace", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
        } else if (call.argument(0) != gles_abi::front &&
                   call.argument(0) != gles_abi::back &&
                   call.argument(0) != gles_abi::front_and_back) {
            set_gl_error(call, gles_abi::invalid_enum);
        } else {
            context->cull_mode = call.argument(0);
        }
    });
    add("_glEnable", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        auto& unit = context->texture_units[context->active_texture_unit];
        if (call.argument(0) == gles_abi::texture_2d) {
            unit.texture_2d_enabled = true;
        } else if (call.argument(0) == gles_abi::texture_rectangle_apple) {
            unit.texture_rectangle_enabled = true;
        } else {
            context->enabled_capabilities.insert(call.argument(0));
        }
    });
    add("_glDisable", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        auto& unit = context->texture_units[context->active_texture_unit];
        if (call.argument(0) == gles_abi::texture_2d) {
            unit.texture_2d_enabled = false;
        } else if (call.argument(0) == gles_abi::texture_rectangle_apple) {
            unit.texture_rectangle_enabled = false;
        } else {
            context->enabled_capabilities.erase(call.argument(0));
        }
    });
    add("_glIsEnabled", [this](UserlandHleCall& call) {
        const auto* context = current_context(call);
        if (context == nullptr) {
            call.set_return(0);
            return;
        }
        const auto& unit = context->texture_units[context->active_texture_unit];
        const auto enabled =
            call.argument(0) == gles_abi::texture_2d ? unit.texture_2d_enabled
            : call.argument(0) == gles_abi::texture_rectangle_apple
                ? unit.texture_rectangle_enabled
                : context->enabled_capabilities.contains(call.argument(0));
        call.set_return(enabled ? 1U : 0U);
    });
    const auto generate_names = [this](UserlandHleCall& call) {
        const auto signed_count = static_cast<std::int32_t>(call.argument(0));
        const auto output = call.argument(1);
        if (current_context(call) == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (signed_count < 0 || (signed_count != 0 && output == 0)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto texture_names = call.symbol() == "_glGenTextures";
        const auto count = static_cast<std::uint32_t>(signed_count);
        for (std::uint32_t index = 0; index < count; ++index) {
            const auto name = texture_names ? resources_.generate_texture()
                                            : resources_.generate_buffer();
            if (!call.memory().write32(output + index * 4U, name)) {
                set_gl_error(call, gl_invalid_value);
                break;
            }
        }
    };
    add("_glGenTextures", generate_names);
    add("_glGenBuffers", generate_names);
    add("_glIsTexture", [this](UserlandHleCall& call) {
        call.set_return(resources_.has_texture(call.argument(0)) ? 1U : 0U);
    });
    add("_glIsBuffer", [this](UserlandHleCall& call) {
        call.set_return(resources_.has_buffer(call.argument(0)) ? 1U : 0U);
    });
    const auto generate_framebuffers = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto count = static_cast<std::int32_t>(call.argument(0));
        const auto output = call.argument(1);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (count < 0 || (count != 0 && output == 0U)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        for (std::int32_t index = 0; index < count; ++index) {
            const auto name = next_framebuffer_++;
            context->framebuffers.try_emplace(name);
            if (!call.memory().write32(
                    output + static_cast<std::uint32_t>(index) * 4U, name)) {
                context->framebuffers.erase(name);
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
        }
    };
    add("_glGenFramebuffers", generate_framebuffers);
    add("_glGenFramebuffersOES", generate_framebuffers);
    const auto is_framebuffer = [this](UserlandHleCall& call) {
        const auto* context = current_context(call);
        call.set_return(context != nullptr &&
                                context->framebuffers.contains(call.argument(0))
                            ? 1U
                            : 0U);
    };
    add("_glIsFramebuffer", is_framebuffer);
    add("_glIsFramebufferOES", is_framebuffer);
    const auto bind_framebuffer = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (call.argument(0) != gles_abi::framebuffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto name = call.argument(1);
        if (name != 0U)
            context->framebuffers.try_emplace(name);
        context->bound_framebuffer = name;
    };
    add("_glBindFramebuffer", bind_framebuffer);
    add("_glBindFramebufferOES", bind_framebuffer);
    const auto framebuffer_texture_2d = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        const auto attachment = call.argument(1);
        const auto texture_target = call.argument(2);
        const auto texture = call.argument(3);
        const auto level = call.argument(4);
        if (target != gles_abi::framebuffer ||
            attachment != gles_abi::color_attachment0 ||
            (texture_target != gles_abi::texture_2d &&
                texture_target != gles_abi::texture_rectangle_apple)) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (context->bound_framebuffer == 0U || level != 0U ||
            (texture != 0U && !resources_.has_texture(texture))) {
            set_gl_error(call, level != 0U ? gles_abi::invalid_value
                                           : gles_abi::invalid_operation);
            return;
        }
        auto& framebuffer = context->framebuffers[context->bound_framebuffer];
        framebuffer.color_texture_target = texture_target;
        framebuffer.color_texture = texture;
        framebuffer.color_renderbuffer = 0U;
    };
    add("_glFramebufferTexture2D", framebuffer_texture_2d);
    add("_glFramebufferTexture2DOES", framebuffer_texture_2d);
    const auto check_framebuffer_status = [this](UserlandHleCall& call) {
        const auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            call.set_return(0U);
            return;
        }
        if (call.argument(0) != gles_abi::framebuffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            call.set_return(0U);
            return;
        }
        if (context->bound_framebuffer == 0U) {
            call.set_return(gles_abi::framebuffer_complete);
            return;
        }
        const auto complete = current_framebuffer_level(*context) != nullptr;
        call.set_return(complete ? gles_abi::framebuffer_complete
                                 : gles_abi::framebuffer_incomplete_attachment);
    };
    add("_glCheckFramebufferStatus", check_framebuffer_status);
    add("_glCheckFramebufferStatusOES", check_framebuffer_status);
    const auto delete_framebuffers = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto count = static_cast<std::int32_t>(call.argument(0));
        const auto input = call.argument(1);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (count < 0 || (count != 0 && input == 0U)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        for (std::int32_t index = 0; index < count; ++index) {
            const auto name = call.memory().read32(
                input + static_cast<std::uint32_t>(index) * 4U);
            if (!name) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
            context->framebuffers.erase(*name);
            if (context->bound_framebuffer == *name)
                context->bound_framebuffer = 0U;
        }
    };
    add("_glDeleteFramebuffers", delete_framebuffers);
    add("_glDeleteFramebuffersOES", delete_framebuffers);
    const auto generate_renderbuffers = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto count = static_cast<std::int32_t>(call.argument(0));
        const auto output = call.argument(1);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (count < 0 || (count != 0 && output == 0U)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        for (std::int32_t index = 0; index < count; ++index) {
            const auto name = next_renderbuffer_++;
            context->renderbuffers.try_emplace(name);
            if (!call.memory().write32(
                    output + static_cast<std::uint32_t>(index) * 4U, name)) {
                context->renderbuffers.erase(name);
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
        }
    };
    add("_glGenRenderbuffers", generate_renderbuffers);
    add("_glGenRenderbuffersOES", generate_renderbuffers);
    const auto is_renderbuffer = [this](UserlandHleCall& call) {
        const auto* context = current_context(call);
        call.set_return(context != nullptr && context->renderbuffers.contains(
                                                  call.argument(0))
                            ? 1U
                            : 0U);
    };
    add("_glIsRenderbuffer", is_renderbuffer);
    add("_glIsRenderbufferOES", is_renderbuffer);
    const auto bind_renderbuffer = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (call.argument(0) != gles_abi::renderbuffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto name = call.argument(1);
        if (name != 0U && !context->renderbuffers.contains(name)) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        context->bound_renderbuffer = name;
    };
    add("_glBindRenderbuffer", bind_renderbuffer);
    add("_glBindRenderbufferOES", bind_renderbuffer);
    const auto renderbuffer_storage = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto width = call.argument(2);
        const auto height = call.argument(3);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (call.argument(0) != gles_abi::renderbuffer ||
            context->bound_renderbuffer == 0U) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto error = ensure_renderbuffer_storage(*context,
            context->bound_renderbuffer, width, height, call.argument(1));
        if (error != gles_abi::no_error)
            set_gl_error(call, error);
    };
    add("_glRenderbufferStorage", renderbuffer_storage);
    add("_glRenderbufferStorageOES", renderbuffer_storage);
    const auto framebuffer_renderbuffer = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        const auto attachment = call.argument(1);
        const auto renderbuffer_target = call.argument(2);
        const auto name = call.argument(3);
        if (target != gles_abi::framebuffer ||
            attachment != gles_abi::color_attachment0 ||
            renderbuffer_target != gles_abi::renderbuffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (context->bound_framebuffer == 0U) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        auto framebuffer =
            context->framebuffers.find(context->bound_framebuffer);
        if (framebuffer == context->framebuffers.end()) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (name == 0U) {
            framebuffer->second.color_renderbuffer = 0U;
            framebuffer->second.color_texture = 0U;
            framebuffer->second.color_texture_target = 0U;
            return;
        }
        const auto renderbuffer = context->renderbuffers.find(name);
        if (renderbuffer == context->renderbuffers.end()) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        framebuffer->second.color_renderbuffer = name;
        framebuffer->second.color_texture =
            context->renderbuffers.at(name).color_texture;
        framebuffer->second.color_texture_target = gles_abi::renderbuffer;
    };
    add("_glFramebufferRenderbuffer", framebuffer_renderbuffer);
    add("_glFramebufferRenderbufferOES", framebuffer_renderbuffer);
    const auto get_renderbuffer_parameter = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        const auto parameter = call.argument(1);
        const auto output = call.argument(2);
        const auto renderbuffer =
            context->renderbuffers.find(context->bound_renderbuffer);
        if (target != gles_abi::renderbuffer ||
            renderbuffer == context->renderbuffers.end() || output == 0U) {
            set_gl_error(call, target != gles_abi::renderbuffer
                                   ? gles_abi::invalid_enum
                                   : gles_abi::invalid_operation);
            return;
        }
        std::uint32_t value { };
        switch (parameter) {
        case gl_renderbuffer_width:
            value = renderbuffer->second.width;
            break;
        case gl_renderbuffer_height:
            value = renderbuffer->second.height;
            break;
        case gl_renderbuffer_internal_format:
        case gl_renderbuffer_color_format:
            value = renderbuffer->second.internal_format;
            break;
        default:
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (!call.memory().write32(output, value))
            set_gl_error(call, gles_abi::invalid_value);
    };
    add("_glGetRenderbufferParameteriv", get_renderbuffer_parameter);
    add("_glGetRenderbufferParameterivOES", get_renderbuffer_parameter);
    const auto delete_renderbuffers = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto count = static_cast<std::int32_t>(call.argument(0));
        const auto input = call.argument(1);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (count < 0 || (count != 0 && input == 0U)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        for (std::int32_t index = 0; index < count; ++index) {
            const auto name = call.memory().read32(
                input + static_cast<std::uint32_t>(index) * 4U);
            if (!name) {
                set_gl_error(call, gles_abi::invalid_value);
                return;
            }
            const auto renderbuffer = context->renderbuffers.find(*name);
            if (renderbuffer == context->renderbuffers.end())
                continue;
            for (auto& [framebuffer_name, framebuffer] :
                context->framebuffers) {
                static_cast<void>(framebuffer_name);
                if (framebuffer.color_renderbuffer == *name) {
                    framebuffer.color_renderbuffer = 0U;
                    framebuffer.color_texture = 0U;
                    framebuffer.color_texture_target = 0U;
                }
            }
            if (context->bound_renderbuffer == *name)
                context->bound_renderbuffer = 0U;
            if (renderbuffer->second.color_texture != 0U)
                resources_.erase_texture(renderbuffer->second.color_texture);
            context->renderbuffers.erase(renderbuffer);
        }
    };
    add("_glDeleteRenderbuffers", delete_renderbuffers);
    add("_glDeleteRenderbuffersOES", delete_renderbuffers);
    add("_glBindTexture", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::texture_2d &&
            target != gles_abi::texture_rectangle_apple) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        resources_.ensure_texture(call.argument(1));
        auto& unit = context->texture_units[context->active_texture_unit];
        auto& binding = target == gles_abi::texture_rectangle_apple
                            ? unit.bound_texture_rectangle
                            : unit.bound_texture_2d;
        binding = call.argument(1);
    });
    add("_glBindBuffer", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::array_buffer &&
            target != gles_abi::element_array_buffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        resources_.ensure_buffer(call.argument(1));
        auto& binding = target == gles_abi::array_buffer
                            ? context->bound_array_buffer
                            : context->bound_element_array_buffer;
        binding = call.argument(1);
    });
    const auto delete_names = [this](UserlandHleCall& call) {
        const auto signed_count = static_cast<std::int32_t>(call.argument(0));
        const auto input = call.argument(1);
        if (current_context(call) == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (signed_count < 0 || (signed_count != 0 && input == 0)) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto texture_names = call.symbol() == "_glDeleteTextures";
        const auto count = static_cast<std::uint32_t>(signed_count);
        for (std::uint32_t index = 0; index < count; ++index) {
            const auto name = call.memory().read32(input + index * 4U);
            if (!name) {
                set_gl_error(call, gl_invalid_value);
                break;
            }
            if (texture_names) {
                std::vector<GlesRenderTargetKey> render_targets;
                if (const auto* texture = resources_.texture(*name)) {
                    for (const auto& [level_index, level] : texture->levels) {
                        static_cast<void>(level_index);
                        if (!level.surface_id && level.host_surface &&
                            level.host_surface->key().owner ==
                                renderer_owner_) {
                            render_targets.push_back(level.host_surface->key());
                        }
                    }
                }
                if (!render_targets.empty())
                    renderer_->release(render_targets);
                resources_.erase_texture(*name);
                for (auto& [context_name, context] : contexts_) {
                    static_cast<void>(context_name);
                    for (auto& unit : context.texture_units) {
                        if (unit.bound_texture_2d == *name) {
                            unit.bound_texture_2d = 0;
                        }
                        if (unit.bound_texture_rectangle == *name) {
                            unit.bound_texture_rectangle = 0;
                        }
                    }
                    for (auto& [framebuffer_name, framebuffer] :
                        context.framebuffers) {
                        static_cast<void>(framebuffer_name);
                        if (framebuffer.color_texture == *name)
                            framebuffer.color_texture = 0U;
                    }
                }
            } else {
                resources_.erase_buffer(*name);
                for (auto& [context_name, context] : contexts_) {
                    static_cast<void>(context_name);
                    if (context.bound_array_buffer == *name) {
                        context.bound_array_buffer = 0;
                    }
                    if (context.bound_element_array_buffer == *name) {
                        context.bound_element_array_buffer = 0;
                    }
                }
            }
        }
    };
    add("_glDeleteTextures", delete_names);
    add("_glDeleteBuffers", delete_names);
    add("_glPixelStorei", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto parameter = call.argument(0);
        const auto value = call.argument(1);
        std::uint32_t* destination = nullptr;
        switch (parameter) {
        case gles_abi::unpack_alignment:
            destination = &context->unpack.alignment;
            break;
        case gles_abi::pack_alignment:
            destination = &context->pack_alignment;
            break;
        case gles_abi::unpack_row_length:
            destination = &context->unpack.row_length;
            break;
        case gles_abi::unpack_skip_rows:
            destination = &context->unpack.skip_rows;
            break;
        case gles_abi::unpack_skip_pixels:
            destination = &context->unpack.skip_pixels;
            break;
        case gles_abi::unpack_row_bytes_apple:
            destination = &context->unpack.row_bytes;
            break;
        case gles_abi::unpack_client_storage_apple:
            // Decoding client formats into host ARGB requires conversion, so
            // retain the extension's copy/decode fallback rather than an alias
            // to guest memory. The hint does not alter pixel layout.
            context->unpack_client_storage = value != 0U;
            return;
        default:
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto alignment = parameter == gles_abi::unpack_alignment ||
                               parameter == gles_abi::pack_alignment;
        if ((alignment && value != 1U && value != 2U && value != 4U &&
                value != 8U) ||
            (!alignment &&
                value > static_cast<std::uint32_t>(
                            std::numeric_limits<std::int32_t>::max()))) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        *destination = value;
    });
    add("_glTexImage2D", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto level = static_cast<std::int32_t>(call.argument(1));
        const auto width = static_cast<std::int32_t>(call.argument(3));
        const auto height = static_cast<std::int32_t>(call.argument(4));
        const auto border = static_cast<std::int32_t>(call.argument(5));
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::texture_2d &&
            target != gles_abi::texture_rectangle_apple) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (level < 0 || width < 0 || height < 0 || border != 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto& unit = context->texture_units[context->active_texture_unit];
        const auto binding = target == gles_abi::texture_rectangle_apple
                                 ? unit.bound_texture_rectangle
                                 : unit.bound_texture_2d;
        std::optional<GlesRenderTargetKey> previous_render_target;
        if (const auto* texture = resources_.texture(binding)) {
            const auto previous =
                texture->levels.find(static_cast<std::uint32_t>(level));
            if (previous != texture->levels.end() &&
                !previous->second.surface_id && previous->second.host_surface &&
                previous->second.host_surface->key().owner == renderer_owner_) {
                previous_render_target = previous->second.host_surface->key();
            }
        }
        const auto error = resources_.upload_texture_2d(call.memory(), binding,
            static_cast<std::uint32_t>(level), call.argument(2),
            static_cast<std::uint32_t>(width),
            static_cast<std::uint32_t>(height), call.argument(6),
            call.argument(7), call.argument(8), context->unpack);
        if (error != gles_abi::no_error) {
            set_gl_error(call, error);
        } else if (previous_render_target) {
            renderer_->release(
                std::span { &*previous_render_target, std::size_t { 1 } });
        }
    });
    add("_glCompressedTexImage2D", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto level = static_cast<std::int32_t>(call.argument(1));
        const auto width = static_cast<std::int32_t>(call.argument(3));
        const auto height = static_cast<std::int32_t>(call.argument(4));
        const auto border = static_cast<std::int32_t>(call.argument(5));
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        const auto format = call.argument(2);
        if (target != gles_abi::texture_2d &&
            target != gles_abi::texture_rectangle_apple) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (format != gl_compressed_rgb_pvrtc_2bpp &&
            format != gl_compressed_rgba_pvrtc_2bpp &&
            format != gl_compressed_rgb_pvrtc_4bpp &&
            format != gl_compressed_rgba_pvrtc_4bpp) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (level < 0 || width <= 0 || height <= 0 || border != 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto& unit = context->texture_units[context->active_texture_unit];
        const auto binding = target == gles_abi::texture_rectangle_apple
                                 ? unit.bound_texture_rectangle
                                 : unit.bound_texture_2d;
        std::optional<GlesRenderTargetKey> previous_render_target;
        if (const auto* texture = resources_.texture(binding)) {
            const auto previous =
                texture->levels.find(static_cast<std::uint32_t>(level));
            if (previous != texture->levels.end() &&
                !previous->second.surface_id && previous->second.host_surface &&
                previous->second.host_surface->key().owner == renderer_owner_) {
                previous_render_target = previous->second.host_surface->key();
            }
        }
        const auto error = resources_.upload_compressed_texture_2d(
            call.memory(), binding, static_cast<std::uint32_t>(level), format,
            static_cast<std::uint32_t>(width),
            static_cast<std::uint32_t>(height), call.argument(6),
            call.argument(7));
        if (error != gles_abi::no_error) {
            set_gl_error(call, error);
            return;
        }
        if (previous_render_target)
            renderer_->release(
                std::span { &*previous_render_target, std::size_t { 1 } });
    });
    add("_glTexSubImage2D", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto level = static_cast<std::int32_t>(call.argument(1));
        const auto x = static_cast<std::int32_t>(call.argument(2));
        const auto y = static_cast<std::int32_t>(call.argument(3));
        const auto width = static_cast<std::int32_t>(call.argument(4));
        const auto height = static_cast<std::int32_t>(call.argument(5));
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::texture_2d &&
            target != gles_abi::texture_rectangle_apple) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (level < 0 || x < 0 || y < 0 || width < 0 || height < 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto& unit = context->texture_units[context->active_texture_unit];
        const auto binding = target == gles_abi::texture_rectangle_apple
                                 ? unit.bound_texture_rectangle
                                 : unit.bound_texture_2d;
        const auto error = resources_.update_texture_2d(call.memory(), binding,
            static_cast<std::uint32_t>(level), static_cast<std::uint32_t>(x),
            static_cast<std::uint32_t>(y), static_cast<std::uint32_t>(width),
            static_cast<std::uint32_t>(height), call.argument(6),
            call.argument(7), call.argument(8), context->unpack);
        if (error != gles_abi::no_error)
            set_gl_error(call, error);
    });
    const auto set_texture_parameter = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::texture_2d &&
            target != gles_abi::texture_rectangle_apple) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto& unit = context->texture_units[context->active_texture_unit];
        const auto binding = target == gles_abi::texture_rectangle_apple
                                 ? unit.bound_texture_rectangle
                                 : unit.bound_texture_2d;
        const auto error = resources_.set_texture_parameter(
            binding, call.argument(1), call.argument(2));
        if (error != gles_abi::no_error)
            set_gl_error(call, error);
    };
    add("_glTexParameteri", set_texture_parameter);
    add("_glTexParameterf", set_texture_parameter);
    add("_glTexParameterx", set_texture_parameter);
    const auto set_texture_environment = [this](UserlandHleCall& call,
                                             float parameter) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return false;
        }
        if (call.argument(0) != gles_abi::texture_environment ||
            !std::isfinite(parameter) || parameter < 0.0F ||
            parameter >
                static_cast<float>(std::numeric_limits<std::uint32_t>::max())) {
            set_gl_error(call, gles_abi::invalid_enum);
            return false;
        }
        auto& environment = context->texture_units[context->active_texture_unit]
                                .texture_environment;
        const auto name = call.argument(1);
        const auto value = static_cast<std::uint32_t>(std::lround(parameter));
        const auto is_one_of = [](std::uint32_t candidate, auto... values) {
            return ((candidate == values) || ...);
        };
        if (name == gles_abi::texture_environment_mode) {
            if (!is_one_of(value, gles_abi::replace, gles_abi::modulate,
                    gles_abi::decal, gles_abi::blend, gles_abi::add,
                    gles_abi::combine)) {
                set_gl_error(call, gles_abi::invalid_enum);
                return false;
            }
            environment.mode = value;
            return true;
        }
        if (name == gles_abi::combine_rgb) {
            if (!is_one_of(value, gles_abi::replace, gles_abi::modulate,
                    gles_abi::add, gles_abi::add_signed, gles_abi::interpolate,
                    gles_abi::subtract, gles_abi::dot3_rgb,
                    gles_abi::dot3_rgba)) {
                set_gl_error(call, gles_abi::invalid_enum);
                return false;
            }
            environment.combine_rgb = value;
            return true;
        }
        if (name == gles_abi::combine_alpha) {
            if (!is_one_of(value, gles_abi::replace, gles_abi::modulate,
                    gles_abi::add, gles_abi::add_signed, gles_abi::interpolate,
                    gles_abi::subtract)) {
                set_gl_error(call, gles_abi::invalid_enum);
                return false;
            }
            environment.combine_alpha = value;
            return true;
        }
        const auto source_index =
            name >= gles_abi::source0_rgb && name <= gles_abi::source2_rgb
                ? std::optional<std::size_t> { name - gles_abi::source0_rgb }
                : std::nullopt;
        const auto alpha_source_index =
            name >= gles_abi::source0_alpha && name <= gles_abi::source2_alpha
                ? std::optional<std::size_t> { name - gles_abi::source0_alpha }
                : std::nullopt;
        if (source_index || alpha_source_index) {
            if (!is_one_of(value, gles_abi::texture_source, gles_abi::constant,
                    gles_abi::primary_color, gles_abi::previous)) {
                set_gl_error(call, gles_abi::invalid_enum);
                return false;
            }
            if (source_index) {
                environment.rgb_sources[*source_index] = value;
            } else {
                environment.alpha_sources[*alpha_source_index] = value;
            }
            return true;
        }
        const auto operand_index =
            name >= gles_abi::operand0_rgb && name <= gles_abi::operand2_rgb
                ? std::optional<std::size_t> { name - gles_abi::operand0_rgb }
                : std::nullopt;
        const auto alpha_operand_index =
            name >= gles_abi::operand0_alpha && name <= gles_abi::operand2_alpha
                ? std::optional<std::size_t> { name - gles_abi::operand0_alpha }
                : std::nullopt;
        if (operand_index) {
            if (!is_one_of(value, gles_abi::source_color,
                    gles_abi::one_minus_source_color, gles_abi::source_alpha,
                    gles_abi::one_minus_source_alpha)) {
                set_gl_error(call, gles_abi::invalid_enum);
                return false;
            }
            environment.rgb_operands[*operand_index] = value;
            return true;
        }
        if (alpha_operand_index) {
            if (!is_one_of(value, gles_abi::source_alpha,
                    gles_abi::one_minus_source_alpha)) {
                set_gl_error(call, gles_abi::invalid_enum);
                return false;
            }
            environment.alpha_operands[*alpha_operand_index] = value;
            return true;
        }
        if (name == gles_abi::rgb_scale || name == gles_abi::alpha_scale) {
            if (parameter != 1.0F && parameter != 2.0F && parameter != 4.0F) {
                set_gl_error(call, gles_abi::invalid_value);
                return false;
            }
            if (name == gles_abi::rgb_scale) {
                environment.rgb_scale = parameter;
            } else {
                environment.alpha_scale = parameter;
            }
            return true;
        }
        set_gl_error(call, gles_abi::invalid_enum);
        return false;
    };
    add("_glTexEnvi", [set_texture_environment](UserlandHleCall& call) {
        set_texture_environment(call, static_cast<float>(call.argument(2)));
    });
    add("_glTexEnvfv", [this, set_texture_environment](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto values = call.argument(2);
        if (context == nullptr || values == 0) {
            set_gl_error(call, context == nullptr ? gles_abi::invalid_operation
                                                  : gles_abi::invalid_value);
            return;
        }
        if (call.argument(0) != gles_abi::texture_environment) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        auto& environment = context->texture_units[context->active_texture_unit]
                                .texture_environment;
        if (call.argument(1) == gles_abi::texture_environment_color) {
            for (std::size_t component = 0;
                component < environment.color.size(); ++component) {
                const auto raw = call.memory().read32(
                    values + static_cast<std::uint32_t>(component * 4U));
                if (!raw) {
                    set_gl_error(call, gles_abi::invalid_value);
                    return;
                }
                const auto value = std::bit_cast<float>(*raw);
                if (!std::isfinite(value)) {
                    set_gl_error(call, gles_abi::invalid_value);
                    return;
                }
                environment.color[component] = std::clamp(value, 0.0F, 1.0F);
            }
            return;
        }
        const auto raw = call.memory().read32(values);
        if (!raw) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        set_texture_environment(call, std::bit_cast<float>(*raw));
    });
    add("_glTexImageCoreSurfaceAPPLE", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::texture_2d &&
            target != gles_abi::texture_rectangle_apple) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto identifier = core_surface_identifier(call, call.argument(1));
        if (!identifier) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto& unit = context->texture_units[context->active_texture_unit];
        const auto binding = target == gles_abi::texture_rectangle_apple
                                 ? unit.bound_texture_rectangle
                                 : unit.bound_texture_2d;
        const auto error = resources_.import_surface_texture(
            call.memory(), binding, *surface_store_, *identifier, false);
        if (error != gles_abi::no_error)
            set_gl_error(call, error);
    });
    add("_glFinishTextureAPPLE", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::texture_2d &&
            target != gles_abi::texture_rectangle_apple) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto& unit = context->texture_units[context->active_texture_unit];
        const auto binding = target == gles_abi::texture_rectangle_apple
                                 ? unit.bound_texture_rectangle
                                 : unit.bound_texture_2d;
        const auto error = resources_.refresh_surface_texture(
            call.memory(), binding, *surface_store_);
        if (error != gles_abi::no_error)
            set_gl_error(call, error);
    });
    add("_glBufferData", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto size = static_cast<std::int32_t>(call.argument(1));
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::array_buffer &&
            target != gles_abi::element_array_buffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (size < 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        if (call.argument(3) != gles_abi::static_draw &&
            call.argument(3) != gles_abi::dynamic_draw) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto binding = target == gles_abi::array_buffer
                                 ? context->bound_array_buffer
                                 : context->bound_element_array_buffer;
        const auto error = resources_.upload_buffer(call.memory(), binding,
            static_cast<std::uint32_t>(size), call.argument(2),
            call.argument(3));
        if (error != gles_abi::no_error)
            set_gl_error(call, error);
    });
    add("_glBufferSubData", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto offset = static_cast<std::int32_t>(call.argument(1));
        const auto size = static_cast<std::int32_t>(call.argument(2));
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::array_buffer &&
            target != gles_abi::element_array_buffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (offset < 0 || size < 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        const auto binding = target == gles_abi::array_buffer
                                 ? context->bound_array_buffer
                                 : context->bound_element_array_buffer;
        const auto error = resources_.update_buffer(call.memory(), binding,
            static_cast<std::uint32_t>(offset),
            static_cast<std::uint32_t>(size), call.argument(3));
        if (error != gles_abi::no_error)
            set_gl_error(call, error);
    });
    add("_glGetBufferParameteriv", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        const auto target = call.argument(0);
        if (target != gles_abi::array_buffer &&
            target != gles_abi::element_array_buffer) {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        const auto binding = target == gles_abi::array_buffer
                                 ? context->bound_array_buffer
                                 : context->bound_element_array_buffer;
        const auto* buffer = resources_.buffer(binding);
        if (buffer == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        if (call.argument(2) == 0) {
            set_gl_error(call, gles_abi::invalid_value);
            return;
        }
        std::uint32_t value { };
        if (call.argument(1) == gles_abi::buffer_size) {
            value = static_cast<std::uint32_t>(buffer->bytes.size());
        } else if (call.argument(1) == gles_abi::buffer_usage) {
            value = buffer->usage;
        } else {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        if (!call.write32(call.argument(2), value)) {
            set_gl_error(call, gles_abi::invalid_value);
        }
    });
    add("_glVertexPointer", [this](UserlandHleCall& call) {
        set_array_pointer(call, gles_abi::vertex_array);
    });
    add("_glColorPointer", [this](UserlandHleCall& call) {
        set_array_pointer(call, gles_abi::color_array);
    });
    add("_glTexCoordPointer", [this](UserlandHleCall& call) {
        set_array_pointer(call, gles_abi::texture_coord_array);
    });
    const auto set_client_array = [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        ContextState::ArrayPointer* array { };
        if (call.argument(0) == gles_abi::vertex_array) {
            array = &context->vertex_array;
        } else if (call.argument(0) == gles_abi::color_array) {
            array = &context->color_array;
        } else if (call.argument(0) == gles_abi::texture_coord_array) {
            array = &context->texture_units[context->client_active_texture_unit]
                         .texture_array;
        } else {
            set_gl_error(call, gles_abi::invalid_enum);
            return;
        }
        array->enabled = call.symbol() == "_glEnableClientState";
    };
    add("_glEnableClientState", set_client_array);
    add("_glDisableClientState", set_client_array);
    add("_glBlendFunc", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        if (context == nullptr) {
            set_gl_error(call, gles_abi::invalid_operation);
            return;
        }
        context->blend_source = call.argument(0);
        context->blend_destination = call.argument(1);
    });
    add("_glDrawArrays", [this](UserlandHleCall& call) { draw(call, false); });
    add("_glDrawElements", [this](UserlandHleCall& call) { draw(call, true); });
    add("_glReadPixels",
        [this](UserlandHleCall& call) { read_pixels(call); });
    add("_glFlush", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto binding = context != nullptr
                                 ? resolve_render_target(call, *context)
                                 : std::nullopt;
        if (!binding || !renderer_->flush(binding->key)) {
            set_gl_error(call, gles_abi::invalid_operation);
        }
    });
    add("_glFinish", [this](UserlandHleCall& call) {
        auto* context = current_context(call);
        const auto binding = context != nullptr
                                 ? resolve_render_target(call, *context)
                                 : std::nullopt;
        if (!binding || !renderer_->finish(binding->key)) {
            set_gl_error(call, gles_abi::invalid_operation);
        }
    });
    registry.register_prefix(std::string { opengles_image }, "_gl",
        [this](UserlandHleCall& call) { unsupported(call); });
}

void OpenGlesHle::unsupported(UserlandHleCall& call)
{
    // Most GLES 1.1 state setters are safe to defer until the renderer consumes
    // them. The public prefix hook is still essential: it prevents any call
    // from falling through into the PowerVR command-stream implementation.
    if (unsupported_trace_count_ < maximum_unsupported_traces) {
        call.output().write(
            "[opengles] deferred symbol=" + std::string { call.symbol() } +
            " pid=" + std::to_string(call.process_id()) + "\n");
        ++unsupported_trace_count_;
    }
    call.set_return(0);
}

} // namespace shade
