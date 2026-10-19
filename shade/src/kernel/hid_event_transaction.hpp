// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage one native HID object's construction, delivery and release.

#pragma once

#include "foundation/display_geometry.hpp"
#include "kernel/hid_event_queue.hpp"

#include <functional>

namespace shade {

class UserlandHleRegistry;
enum class DarwinHidDigitizerAbi : std::uint8_t;

class HidEventTransaction {
public:
    [[nodiscard]] static bool enqueue(UserlandHleRegistry& registry,
        const HidEventQueue::Consumer& consumer, HidEventQueue::Event event,
        DisplayGeometry geometry, DarwinHidDigitizerAbi digitizer_abi,
        std::function<void()> completion);
};

} // namespace shade
