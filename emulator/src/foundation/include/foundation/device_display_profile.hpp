// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

#include "foundation/display_geometry.hpp"

namespace shade {

enum class GraphicsAcceleratorKind : std::uint8_t {
    MbxLite,
    Sgx535,
    Sgx543,
};

struct ExternalFramebufferProfile {
    std::string_view service_class;
    DisplayGeometry geometry { 0U, 0U };
};

struct GraphicsServicesCapabilities {
    std::string_view device_name;
    std::string_view marketing_name;
    bool supports_multitasking { };
    bool supports_cellular_data { };
};

struct DeviceDisplayProfile {
    DisplayGeometry panel;
    DisplayGeometry user_interface { panel };
    GraphicsAcceleratorKind accelerator { GraphicsAcceleratorKind::MbxLite };
    std::string_view framebuffer_service_class;
    GraphicsServicesCapabilities graphics_services;
    ExternalFramebufferProfile external_framebuffer;

    [[nodiscard]] constexpr std::string_view driver_bundle() const noexcept
    {
        switch (accelerator) {
        case GraphicsAcceleratorKind::MbxLite:
            return {};
        case GraphicsAcceleratorKind::Sgx535:
            return "IMGSGX535GLDriver";
        case GraphicsAcceleratorKind::Sgx543:
            return "IMGSGX543GLDriver";
        }
        return {};
    }
};

}
