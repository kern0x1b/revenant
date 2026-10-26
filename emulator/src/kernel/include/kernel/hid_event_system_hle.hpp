// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest IOHIDEventSystem calls to emulator input services.

#pragma once

#include "foundation/snapshot_io.hpp"
#include "kernel/hid_accelerometer.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>

namespace emulator {

class Cpu;
class UserlandHleCall;
class UserlandHleRegistry;
struct KernelSharedState;

class HidEventSystemHle {
    friend struct CompatibilityKernelSnapshot;

public:
    explicit HidEventSystemHle(UserlandHleRegistry& registry);
    void set_shared_state(std::shared_ptr<KernelSharedState> state);
    void reset(std::uint32_t process);
    [[nodiscard]] std::optional<std::uint64_t> next_sample_deadline() const
    {
        return delivering_ ? std::nullopt : accelerometer_.next_deadline();
    }
    [[nodiscard]] bool prepare_pending_event(
        Cpu& cpu, std::uint32_t process, std::uint32_t svc_immediate);
    void save(snapshot::Writer& out) const;
    void load(snapshot::Reader& in);

private:
    UserlandHleRegistry& registry_;
    std::shared_ptr<KernelSharedState> state_;
    std::uint32_t consumer_process_ { };
    std::size_t consumer_processor_ { };
    bool delivering_ { };
    HidAccelerometer accelerometer_;
};

}
