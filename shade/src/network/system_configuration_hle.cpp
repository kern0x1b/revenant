// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest network configuration APIs to virtual interfaces and
// notifications.

#include "network/system_configuration_hle.hpp"

#include <string>
#include <string_view>

#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view system_configuration_image {
        "/System/Library/Frameworks/SystemConfiguration.framework/"
        "SystemConfiguration"
    };
    constexpr std::string_view interface_discovery_helper {
        "___SCNetworkInterfaceCopyAll_IONetworkInterface"
    };

} // namespace

SystemConfigurationHle::SystemConfigurationHle(UserlandHleRegistry& registry)
{
    registry.register_guest_function(std::string { system_configuration_image },
        std::string { interface_discovery_helper });
    registry.register_function(std::string { system_configuration_image },
        "_SCNetworkInterfaceCopyAll",
        [this](UserlandHleCall& call) { begin_interface_discovery(call); });
}

void SystemConfigurationHle::begin_interface_discovery(UserlandHleCall& call)
{
    if (!call.call_guest_function(
            interface_discovery_helper, [](UserlandHleCall&) { })) {
        // Older SystemConfiguration images may not expose the split-out helper;
        // preserve their original implementation when the native fast path is
        // unavailable.
        call.resume_original_persistently();
    }
}

} // namespace shade
