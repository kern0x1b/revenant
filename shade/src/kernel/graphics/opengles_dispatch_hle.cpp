// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve guest GLES dispatch tables and install call adapters.

#include "opengles_dispatch_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"
#include "graphics/eagl_dispatch_profile.hpp"
#include "graphics/surface_store.hpp"
#include "kernel/opengles_hle.hpp"

#include <algorithm>
#include <array>
#include <limits>
#include <span>
#include <string>
#include <string_view>

namespace shade {
namespace {
    constexpr const char* engine_image = "/GLEngine.bundle/GLEngine";
    constexpr const char* shared_image =
        "/OpenGLES.framework/libGFXShared.dylib";
    constexpr const char* context_ivar = "_OBJC_IVAR_$_EAGLContext._private";
    constexpr std::uint32_t bad_attribute = 10000U;
    constexpr std::uint32_t bad_context = 10004U;
    constexpr std::uint32_t bad_value = 10008U;
    constexpr std::uint32_t bad_address = 10014U;
    constexpr std::uint32_t bad_renderer = 10015U;
    constexpr std::uint32_t host_renderer_id = 0x01020000U;
    using DispatchProfile = EaglContextFirstArm32Profile;
}

OpenGlesDispatchHle::OpenGlesDispatchHle(
    OpenGlesHle& owner, UserlandHleRegistry& registry)
    : owner_ { owner }
{
    registry.register_guest_data_symbol(
        "/OpenGLES.framework/OpenGLES", context_ivar);
    registry.register_function(engine_image, "_gliChoosePixelFormat",
        [this](UserlandHleCall& call) { choose_pixel_format(call); });
    registry.register_function(
        engine_image, "_gliDestroyPixelFormat", [this](UserlandHleCall& call) {
            if (pixel_format_ != 0U && call.argument(0) == pixel_format_)
                call.set_return(0U);
            else
                call.resume_original_persistently();
        });
    for (const auto* name :
        { "_gliCreateContext", "_gliCreateContextWithShared" }) {
        registry.register_function(
            engine_image, name, [this](UserlandHleCall& call) {
                create_context(call, call.symbol() == "_gliCreateContext");
            });
    }
    registry.register_function(
        engine_image, "_gliDestroyContext", [this](UserlandHleCall& call) {
            const auto found = contexts_.find(call.argument(0));
            if (found == contexts_.end()) {
                call.resume_original_persistently();
                return;
            }
            const auto handle = found->second.host_context;
            release_shared(found->second.shared);
            owner_.contexts_.erase(handle);
            std::erase_if(owner_.eagl_contexts_,
                [&](const auto& entry) { return entry.second == handle; });
            contexts_.erase(found);
            call.set_return(0U);
        });
    registry.register_function(
        engine_image, "_gliNoop", [this](UserlandHleCall& call) {
            owner_.set_gl_error(call, gles_abi::invalid_operation);
            call.output().write("[gles] unsupported GLI dispatch entry\n");
            call.set_return(0U);
        });
    registry.register_function(
        engine_image, "_gliSetInteger", [this](UserlandHleCall& call) {
            const auto found = contexts_.find(call.argument(0));
            if (found == contexts_.end()) {
                call.resume_original_persistently();
                return;
            }
            const auto value = call.memory().read32(call.argument(2));
            if (!value) {
                call.set_return(bad_address);
                return;
            }
            const auto parameter = call.argument(1);
            // Driver scheduling/storage hints selected by native EAGL. Host
            // command submission and surface ownership implement these roles.
            switch (parameter) {
            case 0x38eU:
            case 0x399U:
                call.set_return(set_surface_parameter(call,
                    found->second.host_context, parameter, call.argument(2)));
                return;
            case 701U: // client linked-OS compatibility hint
            case 927U: // shared ES3 object semantics
            case 0x3a0U:
            case 0x3a1U:
            case 0x3e3U:
                found->second.parameters[parameter] = *value;
                call.set_return(0U);
                return;
            default:
                call.output().write(
                    "[gles] unsupported GLI integer parameter=" +
                    std::to_string(parameter) + "\n");
                call.set_return(bad_attribute);
            }
        });
    registry.register_function(
        engine_image, "_gliGetInteger", [this](UserlandHleCall& call) {
            const auto parameter = call.argument(1);
            // This query has no context dependency. Let the firmware report
            // its own table extent, including before a host context exists.
            if (parameter == 0xe0U) {
                call.resume_original_persistently();
                return;
            }
            const auto found = contexts_.find(call.argument(0));
            if (found == contexts_.end()) {
                call.resume_original_persistently();
                return;
            }
            const auto value = found->second.parameters.find(parameter);
            if (value != found->second.parameters.end()) {
                call.set_return(call.write32(call.argument(2), value->second)
                                    ? 0U
                                    : bad_address);
                return;
            }
            call.output().write("[gles] unsupported GLI integer query=" +
                                std::to_string(parameter) + "\n");
            call.set_return(bad_attribute);
        });
    registry.register_function(
        shared_image, "_gfxCreateSharedState", [this](UserlandHleCall& call) {
            const auto count = call.argument(1);
            const auto renderer = call.memory().read32(call.argument(0));
            if (pixel_format_ == 0U || count != 1U ||
                renderer != host_renderer_id) {
                call.resume_original_persistently();
                return;
            }
            if (call.argument(2) != 0U) {
                call.set_return(0U);
                return;
            }
            const auto handle = call.allocate_data(4U, 4U);
            if (handle != 0U)
                shared_references_.emplace(handle, 0U);
            call.set_return(handle);
        });
    for (const auto* name :
        { "_gfxRetainSharedStateAndHash", "_gfxReleaseSharedStateAndHash" }) {
        registry.register_function(
            shared_image, name, [this](UserlandHleCall& call) {
                const auto found = shared_references_.find(call.argument(0));
                if (found == shared_references_.end()) {
                    call.resume_original_persistently();
                    return;
                }
                if (call.symbol() == "_gfxRetainSharedStateAndHash")
                    ++found->second;
                else
                    release_shared(found->first);
                call.set_return(0U);
            });
    }
}

void OpenGlesDispatchHle::release_shared(std::uint32_t handle)
{
    const auto found = shared_references_.find(handle);
    if (found == shared_references_.end())
        return;
    if (found->second > 1U)
        --found->second;
    else
        shared_references_.erase(found);
}

void OpenGlesDispatchHle::reset()
{
    contexts_.clear();
    shared_references_.clear();
    dispatch_.clear();
    profile_.reset();
    pixel_format_ = 0U;
}

void OpenGlesDispatchHle::inherit_state(const OpenGlesDispatchHle& parent)
{
    contexts_ = parent.contexts_;
    shared_references_ = parent.shared_references_;
    dispatch_ = parent.dispatch_;
    profile_ = parent.profile_;
    pixel_format_ = parent.pixel_format_;
}

std::optional<std::uint32_t> OpenGlesDispatchHle::context_for_handle(
    std::uint32_t handle) const
{
    const auto found = contexts_.find(handle);
    return found == contexts_.end()
               ? std::nullopt
               : std::optional { found->second.host_context };
}

std::optional<std::uint32_t> OpenGlesDispatchHle::context_for_object(
    UserlandHleCall& call, std::uint32_t object) const
{
    const auto symbol = call.symbol_address(context_ivar);
    const auto offset = symbol ? call.memory().read32(*symbol) : std::nullopt;
    if (!offset || *offset > 4096U ||
        object > std::numeric_limits<std::uint32_t>::max() - *offset)
        return std::nullopt;
    const auto state = call.memory().read32(object + *offset);
    const auto handle =
        state && *state != 0U &&
                *state <= std::numeric_limits<std::uint32_t>::max() -
                              DispatchProfile::context_offset
            ? call.memory().read32(*state + DispatchProfile::context_offset)
            : std::nullopt;
    return handle ? context_for_handle(*handle) : std::nullopt;
}

bool OpenGlesDispatchHle::prepare_dispatch(UserlandHleCall& call)
{
    if (!dispatch_.empty())
        return true;
    if (!profile_)
        return false;
    const auto unsupported = call.callable_handler(engine_image, "_gliNoop", 1U);
    if (!unsupported)
        return false;
    std::vector<std::uint32_t> table(
        profile_->dispatch_bytes() / 4U, *unsupported);
    constexpr std::array<std::string_view, 9> required_functions {
        "_glGetError", "_glGetString", "_glBindTexture", "_glDrawArrays",
        "_glDrawElements", "_glClear", "_glViewport", "_glFlush", "_glFinish"
    };
    std::array<bool, required_functions.size()> required_resolved { };
    std::size_t resolved = 0U;
    for (const auto& symbol : call.installed_functions("_gl")) {
        if (symbol.size() < 4U || symbol[3] < 'A' || symbol[3] > 'Z')
            continue;
        const auto code = call.original_function_code(symbol, 192U);
        const auto slot =
            code ? profile_->dispatch_slot(*code) : std::nullopt;
        if (!slot)
            continue;
        const auto alias = call.callable_alias(symbol, 1U);
        if (!alias)
            return false;
        table[*slot] = *alias;
        const auto required = std::find(
            required_functions.begin(), required_functions.end(), symbol);
        if (required != required_functions.end())
            required_resolved[static_cast<std::size_t>(
                required - required_functions.begin())] = true;
        ++resolved;
    }
    if (!std::all_of(required_resolved.begin(), required_resolved.end(),
            [](bool available) { return available; }))
        return false;
    call.output().write("[gles] context-first dispatch functions=" +
                        std::to_string(resolved) + "\n");
    dispatch_ = std::move(table);
    return true;
}

void OpenGlesDispatchHle::choose_pixel_format(UserlandHleCall& call)
{
    if (!owner_.renderer_->accelerated() ||
        detect_eagl_context_abi(call) !=
            EaglContextAbi::FirmwareMacroDispatch) {
        call.resume_original_persistently();
        return;
    }
    if (!profile_) {
        const auto size_output = call.allocate_data(4U, 4U);
        if (size_output == 0U) {
            call.set_return(bad_renderer);
            return;
        }
        const std::array<std::uint32_t, 4> arguments { call.argument(0),
            call.argument(1), call.argument(2), call.argument(3) };
        if (!call.call_guest_function("_gliGetInteger",
                [this, size_output, arguments](UserlandHleCall& returned) {
                    const auto bytes = returned.memory().read32(size_output);
                    if (returned.argument(0) != 0U || !bytes ||
                        !(profile_ = DispatchProfile::from_dispatch_bytes(*bytes))) {
                        returned.set_return(bad_renderer);
                        return;
                    }
                    std::copy(arguments.begin(), arguments.end(),
                        returned.cpu().registers().begin());
                    choose_pixel_format(returned);
                })) {
            call.set_return(bad_renderer);
            return;
        }
        call.cpu().registers()[0] = 0U;
        call.cpu().registers()[1] = 0xe0U;
        call.cpu().registers()[2] = size_output;
        return;
    }
    const auto output = call.argument(0);
    const auto attributes = call.argument(1);
    if (output == 0U || attributes == 0U ||
        !call.memory().write32(output, 0U)) {
        call.set_return(bad_address);
        return;
    }
    bool terminated = false;
    for (std::uint32_t index = 0U; index < 50U; ++index) {
        if (attributes >
            std::numeric_limits<std::uint32_t>::max() - index * 4U) {
            call.set_return(bad_address);
            return;
        }
        const auto attribute = call.memory().read32(attributes + index * 4U);
        if (!attribute) {
            call.set_return(bad_address);
            return;
        }
        if (*attribute == 0U) {
            terminated = true;
            break;
        }
        switch (*attribute) {
        case 4U: // RGBA
        case 5U: // double buffer
        case 51U: // minimum policy
        case 52U: // maximum policy
        case 73U: // accelerated
        case 74U: // closest policy
            break;
        case 7U: // auxiliary buffers
        case 8U: // color bits
        case 11U: // alpha bits
        case 12U: // depth bits
        case 13U: // stencil bits
        case 14U: // accumulation bits
        {
            if (++index >= 50U) {
                call.set_return(bad_attribute);
                return;
            }
            if (attributes >
                std::numeric_limits<std::uint32_t>::max() - index * 4U) {
                call.set_return(bad_address);
                return;
            }
            const auto value = call.memory().read32(attributes + index * 4U);
            const auto maximum = *attribute == 8U    ? 32U
                                 : *attribute == 12U ? 24U
                                 : (*attribute == 11U || *attribute == 13U)
                                     ? 8U
                                     : 0U;
            if (!value || *value > maximum) {
                call.set_return(value ? 0U : bad_address);
                return;
            }
            break;
        }
        default:
            call.set_return(bad_attribute);
            return;
        }
    }
    if (!terminated || !prepare_dispatch(call)) {
        call.set_return(terminated ? bad_renderer : bad_attribute);
        return;
    }
    if (pixel_format_ == 0U) {
        // GLI's linked format record. EAGL copies this record into its native
        // sharegroup and forwards the renderer identifier to libGFXShared.
        const std::array<std::uint32_t, 13> format { 0U, host_renderer_id,
            0x500U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 1U };
        pixel_format_ = call.allocate_data(sizeof(format), 4U);
        if (pixel_format_ == 0U || !call.memory().copy_in(pixel_format_,
                                       std::as_bytes(std::span { format }))) {
            pixel_format_ = 0U;
            call.set_return(bad_renderer);
            return;
        }
    }
    call.set_return(
        call.memory().write32(output, pixel_format_) ? 0U : bad_address);
}

void OpenGlesDispatchHle::create_context(
    UserlandHleCall& call, bool shared_is_context)
{
    const auto output = call.argument(0);
    const auto format = call.argument(1);
    auto shared = call.argument(2);
    const auto front = call.argument(3);
    const auto back = call.argument(4);
    const auto flags = call.argument(5);
    if (pixel_format_ == 0U || format == 0U ||
        format > std::numeric_limits<std::uint32_t>::max() - 4U ||
        call.memory().read32(format + 4U) != host_renderer_id) {
        call.resume_original_persistently();
        return;
    }
    if (shared_is_context && shared != 0U) {
        const auto found = contexts_.find(shared);
        if (found == contexts_.end()) {
            call.set_return(bad_context);
            return;
        }
        shared = found->second.shared;
    }
    const auto api = profile_ ? profile_->client_api(flags) : std::nullopt;
    if (!api) {
        call.set_return(bad_value);
        return;
    }
    if ((shared != 0U && !shared_references_.contains(shared)) ||
        !prepare_dispatch(call)) {
        call.set_return(bad_context);
        return;
    }
    if (output == 0U || front == 0U || back == 0U ||
        !call.memory().accessible(output, 4U, MemoryPermission::Write) ||
        !call.memory().accessible(
            front, profile_->dispatch_bytes(), MemoryPermission::Write) ||
        !call.memory().accessible(
            back, profile_->dispatch_bytes(), MemoryPermission::Write)) {
        call.set_return(bad_address);
        return;
    }
    const std::vector<std::uint32_t> empty(dispatch_.size(), 0U);
    if (!call.memory().write32(output, 0U) ||
        !call.memory().copy_in(front, std::as_bytes(std::span { dispatch_ })) ||
        !call.memory().copy_in(back, std::as_bytes(std::span { empty }))) {
        call.set_return(bad_address);
        return;
    }
    const auto handle = call.allocate_data(4U, 4U);
    if (handle == 0U) {
        call.set_return(bad_renderer);
        return;
    }
    if (shared == 0U) {
        shared = call.allocate_data(4U, 4U);
        if (shared == 0U) {
            call.set_return(bad_renderer);
            return;
        }
        shared_references_.emplace(shared, 0U);
    }
    const auto host_context = owner_.next_context_++;
    owner_.contexts_.emplace(host_context, owner_.default_context_state());
    contexts_.emplace(handle, Context { host_context, shared, { } });
    ++shared_references_[shared];
    call.output().write(
        "[gles] GLI context created handle=" + std::to_string(handle) +
        " api=" + std::to_string(*api) + "\n");
    call.set_return(call.memory().write32(output, handle) ? 0U : bad_address);
}

std::uint32_t OpenGlesDispatchHle::set_surface_parameter(UserlandHleCall& call,
    std::uint32_t host_context, std::uint32_t parameter, std::uint32_t values)
{
    const auto found = owner_.contexts_.find(host_context);
    if (found == owner_.contexts_.end())
        return bad_context;
    const bool attach = parameter == 0x38eU;
    std::array<std::uint32_t, 9> words { };
    const auto count = attach ? 9U : 2U;
    if (!call.memory().copy_out(
            values, std::as_writable_bytes(std::span { words }.first(count))))
        return bad_address;
    const auto target = words[attach ? 1U : 0U];
    if (attach) {
        const auto backing = owner_.surface_store_->find(words[0]);
        if (!backing || words[3] == 0U || words[4] == 0U ||
            words[3] != backing->width || words[4] != backing->height ||
            words[7] != 0U || words[8] != 0U)
            return bad_value;
    }
    auto& context = found->second;
    auto& unit = context.texture_units[context.active_texture_unit];
    std::uint32_t texture { };
    if (target == gles_abi::texture_2d)
        texture = unit.bound_texture_2d;
    else if (target == gles_abi::texture_rectangle_apple)
        texture = unit.bound_texture_rectangle;
    else if (target == gles_abi::renderbuffer) {
        if (attach && owner_.ensure_renderbuffer_storage(context,
                          context.bound_renderbuffer, words[3], words[4],
                          words[2]) != gles_abi::no_error)
            return bad_value;
        const auto buffer =
            context.renderbuffers.find(context.bound_renderbuffer);
        if (buffer != context.renderbuffers.end())
            texture = buffer->second.color_texture;
    }
    if (texture == 0U)
        return bad_value;
    if (attach) {
        // IOSurface image descriptor: ID, target, internal format, width,
        // height, external format, type, plane and storage flags.
        const auto error = owner_.resources_.import_surface_texture(
            call.memory(), texture, *owner_.surface_store_, words[0], true);
        if (error != gles_abi::no_error)
            return bad_value;
        context.guest_capabilities =
            open_gles_framebuffer_capabilities(context.guest_capabilities);
    } else {
        auto* resource = owner_.resources_.texture(texture);
        if (resource == nullptr || !resource->levels.contains(0U))
            return bad_value;
        resource->levels.at(0U).render_target_inverted_vertical =
            words[1] == 0U;
    }
    return 0U;
}

} // namespace shade
