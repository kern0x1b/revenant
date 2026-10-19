// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

namespace emulator {

struct NormalizedDragGesture {
    float start_x_fraction { };
    float start_y_fraction { };
    float end_x_fraction { };
    float end_y_fraction { };
    std::uint32_t duration_ms { };
    std::size_t steps { };
    std::uint32_t release_delay_ms { };
    std::uint32_t wake_settle_delay_ms { };
};

struct SystemGestures {
    std::string_view name;
    NormalizedDragGesture unlock;
};

inline constexpr SystemGestures classic_compact_system_gestures {
    "classic-compact-slider",
    { 0.15625F, 0.8958333333F, 0.9375F, 0.8958333333F, 300U, 12U, 16U, 300U },
};

inline constexpr SystemGestures classic_centered_tablet_system_gestures {
    "classic-centered-tablet-slider",
    { 0.3776041667F, 0.9375F, 0.8463541667F, 0.9375F, 1'400U, 7U, 200U,
        1'500U },
};

struct DeviceInputProfile {
    SystemGestures system_gestures { classic_compact_system_gestures };
    bool native_hid_touch_events { true };
};

}
