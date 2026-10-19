// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

#include "foundation/arm_cpu_model.hpp"
#include "foundation/guest_cpu_topology.hpp"

namespace shade {

struct DeviceProcessorProfile {
    std::string_view soc;
    ArmCpuModelKind model;
    std::uint32_t bus_hz;
    // Guest-visible topology. Host execution resources are intentionally not
    // stored here: adding host threads must never change the device contract.
    GuestCpuTopology topology;

    // The boot CPU uses the first guest cluster's clock. Keep one source of
    // truth for timing and topology, including profiles with multiple clusters.
    [[nodiscard]] constexpr std::uint32_t frequency_hz() const noexcept
    {
        return topology.cluster_count != 0U ? topology.clusters[0].frequency_hz
                                            : 0U;
    }

    [[nodiscard]] constexpr std::string_view core_name() const noexcept
    {
        switch (model) {
        case ArmCpuModelKind::Arm1176JzfS:
            return "ARM1176JZF-S";
        case ArmCpuModelKind::CortexA8:
            return "Cortex-A8";
        case ArmCpuModelKind::CortexA9:
            return "Cortex-A9";
        }
        return {};
    }

    [[nodiscard]] constexpr std::string_view instruction_set_name() const noexcept
    {
        switch (arm_architecture_for_model(model)) {
        case ArmArchitectureVersion::Armv6K:
            return "ARMv6KZ + Thumb";
        case ArmArchitectureVersion::Armv7:
            return "ARMv7 + Thumb-2";
        }
        return {};
    }
};

} // namespace shade
