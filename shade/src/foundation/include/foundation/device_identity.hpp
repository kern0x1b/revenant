// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

namespace shade {

// Some legacy activation flows deliberately identify an offline handset as a
// development board.  Keep that identity decision in the device capability
// model; it must not be inferred from a product name or applied to every
// activated retail device.
enum class ActivationHardwareModelPolicy : std::uint8_t {
    Retail,
    DevelopmentBoard,
};

struct DeviceIdentity {
    std::string_view product_type;
    std::string_view board_config;
    // CTL_HW/HW_MODEL identity. Keep this separate from board_config: the
    // latter is the physical IORegistry compatibility string, while an
    // activated simulator may use a development-board model so stock
    // Lockdown can take its firmware-provided no-baseband path.
    // Empty uses the physical board identity; runtime activation can supply
    // an explicit override without duplicating the normal retail identity.
    std::string_view hardware_model_override;
    // Model used by the explicit activated simulator model. This is a
    // capability of the emulated device, not a firmware-version switch.
    std::string_view activation_hardware_model;
    // Retail configuration identifier exposed by the platform device tree.
    // This is distinct from product_type (for example, iPhone1,1) and the
    // hardware board configuration (for example, M68AP).
    std::string_view model_number;
    // Whether the explicit activated model exposes activation_hardware_model
    // through CTL_HW/HW_MODEL. Retail models keep their normal hardware
    // identity even when activation is synthesized by the host.
    ActivationHardwareModelPolicy activation_hardware_model_policy {
        ActivationHardwareModelPolicy::Retail
    };

    [[nodiscard]] constexpr std::string_view hardware_model() const noexcept
    {
        return hardware_model_override.empty() ? board_config
                                               : hardware_model_override;
    }
};

} // namespace shade
