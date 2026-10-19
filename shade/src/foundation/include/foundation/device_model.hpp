// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include "foundation/device_display_profile.hpp"
#include "foundation/device_identity.hpp"
#include "foundation/device_input_profile.hpp"
#include "foundation/device_memory_profile.hpp"
#include "foundation/device_peripheral_profiles.hpp"
#include "foundation/device_processor_profile.hpp"
#include "foundation/device_security_profile.hpp"
#include <span>
#include <string_view>

namespace shade {

// Guest hardware contract, composed from independent capability profiles.
// Host renderer, windowing and execution resources belong to the session host.
struct DeviceModel {
    DeviceIdentity identity;
    DeviceProcessorProfile processor;
    DeviceMemoryProfile memory;
    DeviceDisplayProfile screen;
    DeviceInputProfile input;
    KeyBagCapabilities keybag;
    BasebandProfile baseband;
    AudioHardwareProfile audio { AudioHardwareProfile::CodecBaseband };
    AmbientLightSensorProfile ambient_light_sensor;

    static const DeviceModel& default_model();
    [[nodiscard]] static std::span<const DeviceModel> available_models();
    [[nodiscard]] static const DeviceModel* find(std::string_view product_type);
};

} // namespace shade
