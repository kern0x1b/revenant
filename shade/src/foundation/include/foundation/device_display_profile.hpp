// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

#include "foundation/display_geometry.hpp"

namespace shade {

// Guest-visible graphics accelerator family. This describes the firmware
// capability boundary; it does not select the host renderer implementation.
enum class GraphicsAcceleratorKind : std::uint8_t {
    MbxLite,
    Sgx535,
    Sgx543,
};

// An optional external controller remains discoverable without an attached
// monitor. Its native framebuffer object is separate from the built-in panel.
struct ExternalFramebufferProfile {
    std::string_view service_class;
    DisplayGeometry geometry { 0U, 0U };
};

// GraphicsServices publishes this dictionary through the GSCapabilities
// shared-memory object. The base dictionary is firmware-owned; these identity
// values and the multitasking switch describe the emulated device boundary
// used when that object has not been published yet.
struct GraphicsServicesCapabilities {
    std::string_view device_name;
    std::string_view marketing_name;
    bool supports_multitasking { };
    bool supports_cellular_data { };
};

struct DeviceDisplayProfile {
    // Guest-visible panel/framebuffer size.
    DisplayGeometry panel;
    // Native firmware layout and touch coordinate space. Older UIKit builds
    // may keep this fixed even when a different panel geometry is reported.
    DisplayGeometry user_interface { panel };
    GraphicsAcceleratorKind accelerator { GraphicsAcceleratorKind::MbxLite };
    // IORegistry class of the physical LCD/framebuffer service. QuartzCore
    // discovers its native CAWindowServerDisplay through this device class;
    // host presentation remains a separate backend concern.
    std::string_view framebuffer_service_class;
    GraphicsServicesCapabilities graphics_services;
    ExternalFramebufferProfile external_framebuffer;

    // Bundle selected by the firmware's graphics service. Empty means the
    // accelerator exposes only the legacy MBX service and has no private
    // driver bundle to publish through IOAcceleratorES.
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

} // namespace shade
