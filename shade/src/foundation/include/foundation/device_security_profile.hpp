// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <array>
#include <cstddef>

namespace shade {

inline constexpr std::array<std::byte, 52>
    default_virtual_effaceable_storage_blob {
        std::byte { 0x01 },
        std::byte { 0x00 },
        std::byte { 0x00 },
        std::byte { 0x00 },
        std::byte { 0x00 },
        std::byte { 0x01 },
        std::byte { 0x02 },
        std::byte { 0x03 },
        std::byte { 0x04 },
        std::byte { 0x05 },
        std::byte { 0x06 },
        std::byte { 0x07 },
        std::byte { 0x08 },
        std::byte { 0x09 },
        std::byte { 0x0a },
        std::byte { 0x0b },
        std::byte { 0x0c },
        std::byte { 0x0d },
        std::byte { 0x0e },
        std::byte { 0x0f },
        std::byte { 0x10 },
        std::byte { 0x11 },
        std::byte { 0x12 },
        std::byte { 0x13 },
        std::byte { 0x14 },
        std::byte { 0x15 },
        std::byte { 0x16 },
        std::byte { 0x17 },
        std::byte { 0x18 },
        std::byte { 0x19 },
        std::byte { 0x1a },
        std::byte { 0x1b },
        std::byte { 0x1c },
        std::byte { 0x1d },
        std::byte { 0x1e },
        std::byte { 0x1f },
        std::byte { 0x20 },
        std::byte { 0x21 },
        std::byte { 0x22 },
        std::byte { 0x23 },
        std::byte { 0x24 },
        std::byte { 0x25 },
        std::byte { 0x26 },
        std::byte { 0x27 },
        std::byte { 0x28 },
        std::byte { 0x29 },
        std::byte { 0x2a },
        std::byte { 0x2b },
        std::byte { 0x2c },
        std::byte { 0x2d },
        std::byte { 0x2e },
        std::byte { 0x2f },
    };

// The early ARMv7 firmware starts keybagd through the AppleKeyStore IOKit
// service. This is a device capability boundary: legacy models without the
// hardware-backed key store keep the service absent, while the virtualized
// ARMv7 models publish the matching guest-visible endpoint.
struct KeyBagCapabilities {
    bool apple_key_store_available { };
    // A virtual data volume has no physical effaceable-storage locker. The
    // firmware's no-effaceable-storage property selects its ordinary plist
    // keybag path, which is the recoverable path used by this simulator.
    bool effaceable_storage_available { true };
    // iOS 4-era keybagd uses AppleEffaceableStorage directly. A virtual
    // endpoint keeps that firmware path intact when the guest has no physical
    // locker; its state is owned by the data-volume bootstrap model.
    bool virtual_effaceable_storage_available { };
    std::array<std::byte, 52> virtual_effaceable_storage_blob {
        default_virtual_effaceable_storage_blob
    };
};

inline constexpr KeyBagCapabilities legacy_keybag_capabilities {
    .apple_key_store_available = false,
};

// Virtual key store with firmware-owned plist keybags and a virtual locker.
// Also used by ARMv6 devices whose supported firmware needs this service.
inline constexpr KeyBagCapabilities virtual_keybag_capabilities {
    .apple_key_store_available = true,
    .effaceable_storage_available = false,
    .virtual_effaceable_storage_available = true,
};

} // namespace shade
