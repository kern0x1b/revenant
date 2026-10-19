// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe firmware-dependent GraphicsServices event records and
// coordinate encoding.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string_view>

#include "kernel/kernel_shared_state.hpp"
#include "foundation/system_button_input.hpp"
#include "foundation/touch_input.hpp"

namespace shade {

class MachOImage;

// Describes the firmware-owned structures appended to GSEventRecord. The
// profile is selected from the implementation of GraphicsServices' exported
// accessors, so it follows the ABI actually loaded by a process rather than a
// product version or build identifier.
struct GraphicsServicesInputAbi {
    struct SystemEvents {
        std::array<std::uint32_t, 2> home { };
        std::array<std::uint32_t, 2> lock { };
        std::array<std::uint32_t, 2> volume_up { };
        std::array<std::uint32_t, 2> volume_down { };
        // Indexed by the physical switch state: off, then on.
        std::array<std::uint32_t, 2> ringer_switch { };
    };

    std::string_view name;
    std::size_t event_record_size { };
    std::size_t record_timestamp_offset { };
    std::size_t record_info_size_offset { };
    std::size_t hand_info_size { };
    std::size_t path_info_size { };
    std::size_t hand_path_count_offset { };
    std::size_t path_location_offset { };
    std::array<std::uint8_t, 4> hand_phase_types { };
    // PathInfo byte 1 is ABI-defined. Early UIKit keeps a stable identity
    // there, while later keyboard layouts consume per-event touch stages.
    std::array<std::uint8_t, 4> path_phase_types { };
    // The profile's native idle-reset event keeps SpringBoard's idle timer in
    // sync when input is consumed by an application or system event port.
    std::uint32_t idle_duration_reset_event_type { };
    // Number of bytes appended after the record for the native idle-reset
    // event.  Darwin 11 sends no info payload, while older profiles carry the
    // legacy eight-byte field.
    std::size_t idle_duration_reset_info_size { };
    SystemEvents system_events { };
    struct ApplicationEvents {
        std::uint32_t resume { 2003U };
        std::uint32_t background_complete { 2003U };
    };
    ApplicationEvents application_events { };

    [[nodiscard]] std::uint8_t hand_type(TouchPhase phase) const;
    [[nodiscard]] std::uint8_t path_type(TouchPhase phase) const;
    [[nodiscard]] std::uint32_t system_button_type(
        const SystemButtonInput& input) const;
    [[nodiscard]] std::uint32_t ringer_switch_type(bool active) const;

    [[nodiscard]] static const GraphicsServicesInputAbi& for_abi(
        KernelSharedState::GraphicsInputAbi abi);

    [[nodiscard]] static std::optional<KernelSharedState::GraphicsInputAbi>
    detect(const MachOImage& image);
};

} // namespace shade
