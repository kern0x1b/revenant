// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

namespace shade {

enum class ActivationHardwareModelPolicy : std::uint8_t {
    Retail,
    DevelopmentBoard,
};

struct DeviceIdentity {
    std::string_view product_type;
    std::string_view board_config;
    std::string_view hardware_model_override;
    std::string_view activation_hardware_model;
    std::string_view model_number;
    ActivationHardwareModelPolicy activation_hardware_model_policy {
        ActivationHardwareModelPolicy::Retail
    };

    [[nodiscard]] constexpr std::string_view hardware_model() const noexcept
    {
        return hardware_model_override.empty() ? board_config
                                               : hardware_model_override;
    }
};

}
