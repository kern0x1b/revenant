// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once

#include <cstdint>

namespace shade {
struct KernelSharedState;
namespace kernel_iokit::audio {

// Call while holding mach_mutex, after publishing the new registry value.
class IOAudio2PropertyNotifications {
public:
    IOAudio2PropertyNotifications(KernelSharedState& state,
        std::uint32_t service_object);
    void publish(std::uint32_t object_id, std::uint32_t selector,
        std::uint32_t scope = 0x676c6f62U, std::uint32_t element = 0) const;

    void control_value_changed(
        std::uint32_t control_id, std::uint32_t value) const;

private:
    void send(std::uint32_t object_id, std::uint32_t kind,
        std::uint32_t value, std::uint32_t scope, std::uint32_t element) const;
    KernelSharedState& state_;
    std::uint32_t service_object_;
};

} // namespace kernel_iokit::audio
} // namespace shade
