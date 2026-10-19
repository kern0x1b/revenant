// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

namespace shade {

// The simulator can expose a baseband transport for an explicit replay fixture
// or run with the normal offline/no-modem policy. This is a capability
// model, not a firmware-version or application rule.
enum class BasebandTransport : std::uint8_t {
    Virtual,
    // No physical modem is attached. Registry and control-plane probes stay
    // visible so stock clients settle on the normal Offline state, while no
    // guest input is injected and no host-bound modem output is produced.
    Offline,
};

struct BasebandProfile {
    // Default transport for a normal boot without --baseband-input. An
    // explicit replay input overrides this with Virtual.
    BasebandTransport transport { BasebandTransport::Virtual };
    // Whether the guest has a fixed baseband control endpoint. This is a
    // platform capability used by the transport boundary;
    // it is not a firmware-version or process-name rule. An explicit replay
    // transport always makes the endpoint available at boot.
    bool device_available { true };
};

enum class AudioHardwareProfile : std::uint8_t {
    CodecBaseband,
    CodecBasebandVoiceRouting,
};

// A physical ambient-light controller is discovered by early ThermalMonitor
// builds through the IOKit registry. Keep the service and calibration values in
// the device profile so the registry backend remains independent of a product
// name or firmware build.
struct AmbientLightSensorProfile {
    std::string_view service_class;
    std::uint32_t channel0_gain { };
    std::uint32_t channel1_gain { };
    std::uint32_t integration_cycles { };
};

} // namespace shade
