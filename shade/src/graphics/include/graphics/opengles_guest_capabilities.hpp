// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve guest GPU capabilities without exposing host renderer
// identity.

#pragma once

#include <cstdint>
#include <string_view>

namespace shade {

class UserlandHleCall;

enum class EaglContextAbi {
    HostManagedPublicAbi,
    FirmwareMacroDispatch,
};

[[nodiscard]] EaglContextAbi detect_eagl_context_abi(
    const UserlandHleCall& call);

enum class OpenGlesGuestCapabilitySet {
    MbxLiteLegacy,
    MbxLiteFramebufferObjects,
    Sgx535,
    Sgx535FramebufferObjects,
    Sgx543,
};

// Guest-visible capabilities of the firmware GPU driver. Host renderer names
// and limits never cross this boundary: UIKit and QuartzCore use these values
// to select paths supported by the emulated device.
struct OpenGlesGuestCapabilities {
    std::string_view name;
    std::string_view vendor;
    std::string_view renderer;
    std::string_view version;
    std::string_view extensions;
    std::uint32_t maximum_texture_dimension;
    std::uint32_t maximum_viewport_dimension;
    std::uint32_t texture_units { 2 };
};

[[nodiscard]] const OpenGlesGuestCapabilities& open_gles_guest_capabilities(
    OpenGlesGuestCapabilitySet kind);

[[nodiscard]] OpenGlesGuestCapabilitySet open_gles_framebuffer_capabilities(
    OpenGlesGuestCapabilitySet kind);

} // namespace shade
