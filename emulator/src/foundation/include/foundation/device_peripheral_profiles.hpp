// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

namespace emulator {

enum class BasebandTransport : std::uint8_t {
    Virtual,
    Offline,
};

struct BasebandProfile {
    BasebandTransport transport { BasebandTransport::Virtual };
    bool device_available { true };
};

enum class AudioHardwareProfile : std::uint8_t {
    CodecBaseband,
    CodecBasebandVoiceRouting,
};

struct AmbientLightSensorProfile {
    std::string_view service_class;
    std::uint32_t channel0_gain { };
    std::uint32_t channel1_gain { };
    std::uint32_t integration_cycles { };
};

}
