// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Associate native framebuffer objects with independent hardware outputs.

#include "kernel/mobile_framebuffer_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/application_display.hpp"
#include "foundation/userland_hle.hpp"
#include "graphics/display.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"

#include <bit>
#include <mutex>
#include <string>

namespace shade {

bool MobileFramebufferHle::is_external_framebuffer(UserlandHleCall& call) const
{
    return external_framebuffers_.contains(call.argument(0));
}

void MobileFramebufferHle::register_device_functions(
    UserlandHleRegistry& registry)
{
    constexpr std::string_view image {
        "/IOMobileFramebuffer.framework/IOMobileFramebuffer"
    };
    // Keep CFRuntime allocation, notification setup and device opening native.
    // Observe the returned handle instead of relying on a firmware's private
    // object layout. Each successful open also replaces any recycled handle.
    registry.register_function(std::string { image },
        "_IOMobileFramebufferOpen", [this](UserlandHleCall& call) {
            const auto service_name = call.argument(0);
            const auto output = call.argument(3);
            bool external = false;
            if (shared_state_) {
                std::lock_guard lock { shared_state_->mach_mutex };
                const auto object =
                    shared_state_->mach_namespaces
                        .resolve(call.process_id(), service_name)
                        .value_or(0);
                external =
                    object != 0 &&
                    object == shared_state_->external_framebuffer_service;
            }
            call.resume_original_persistently(
                [this, output, external](UserlandHleCall& completed) {
                    if (completed.argument(0) != iokit_abi::success)
                        return;
                    const auto handle =
                        completed.memory().read32(output).value_or(0);
                    if (handle == 0)
                        return;
                    if (external)
                        external_framebuffers_.insert(handle);
                    else
                        external_framebuffers_.erase(handle);
                });
        });
    registry.register_function(std::string { image },
        "_IOMobileFramebufferGetID", [this](UserlandHleCall& call) {
            call.set_return(call.write32(call.argument(1),
                                is_external_framebuffer(call) ? 1U : 0U)
                                ? iokit_abi::success
                                : iokit_abi::bad_argument);
        });
    registry.register_function(std::string { image },
        "_IOMobileFramebufferGetDisplaySize", [this](UserlandHleCall& call) {
            auto geometry =
                display_ ? display_->geometry() : default_display_geometry;
            if (shared_state_) {
                std::lock_guard lock { shared_state_->mach_mutex };
                if (is_external_framebuffer(call)) {
                    geometry = shared_state_->external_framebuffer.geometry;
                } else if (const auto process =
                               shared_state_->processes.find(call.process_id());
                    process != shared_state_->processes.end()) {
                    geometry = application_display_geometry(
                        process->second.application_display, geometry);
                }
            }
            const auto output = call.argument(1);
            const auto width = std::bit_cast<std::uint32_t>(
                static_cast<float>(geometry.width));
            const auto height = std::bit_cast<std::uint32_t>(
                static_cast<float>(geometry.height));
            call.set_return(output != 0 && call.write32(output, width) &&
                                    call.write32(output + 4U, height)
                                ? iokit_abi::success
                                : iokit_abi::bad_argument);
        });
}

} // namespace shade
