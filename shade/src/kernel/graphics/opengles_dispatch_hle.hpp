// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Declare guest GLES dispatch-table adapters and capability
// resolution.

#pragma once

#include "graphics/eagl_dispatch_profile.hpp"

#include <cstdint>
#include <map>
#include <optional>
#include <vector>

namespace shade {

class OpenGlesHle;
class UserlandHleCall;
class UserlandHleRegistry;

// GLI is the C driver boundary beneath the firmware's EAGL object lifecycle.
// This adapter binds its context-first table to the existing GLES state model.
class OpenGlesDispatchHle {
public:
    OpenGlesDispatchHle(OpenGlesHle& owner, UserlandHleRegistry& registry);
    void reset();
    void inherit_state(const OpenGlesDispatchHle& parent);
    [[nodiscard]] std::optional<std::uint32_t> context_for_handle(
        std::uint32_t handle) const;
    [[nodiscard]] std::optional<std::uint32_t> context_for_object(
        UserlandHleCall& call, std::uint32_t object) const;

private:
    struct Context {
        std::uint32_t host_context { };
        std::uint32_t shared { };
        std::map<std::uint32_t, std::uint32_t> parameters;
    };
    void choose_pixel_format(UserlandHleCall& call);
    void create_context(UserlandHleCall& call, bool shared_is_context);
    void release_shared(std::uint32_t handle);
    [[nodiscard]] bool prepare_dispatch(UserlandHleCall& call);
    [[nodiscard]] std::uint32_t set_surface_parameter(UserlandHleCall& call,
        std::uint32_t host_context, std::uint32_t parameter,
        std::uint32_t values);

    OpenGlesHle& owner_;
    std::map<std::uint32_t, Context> contexts_;
    std::map<std::uint32_t, std::uint32_t> shared_references_;
    std::vector<std::uint32_t> dispatch_;
    std::optional<EaglContextFirstArm32Profile> profile_;
    std::uint32_t pixel_format_ { };
};

} // namespace shade
