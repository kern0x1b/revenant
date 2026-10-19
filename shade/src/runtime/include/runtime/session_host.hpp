// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the display, audio, control and resource services supplied
// by a frontend.

#pragma once

#include <memory>
#include <string>

#include "foundation/host_memory.hpp"

namespace shade {

class AudioDecoder;
class AudioSink;
class ControlChannel;
class DisplayPresenter;
struct DeviceModel;

struct SessionAudio {
    std::shared_ptr<AudioSink> sink;
    std::shared_ptr<AudioDecoder> decoder;
    std::string backend_name { "none" };
    std::string decoder_name { "pcm-caf-only" };
};

// Host services are supplied by the embedding frontend. No native window,
// audio, terminal descriptor or operating-system SDK crosses this boundary.
class SessionHost {
public:
    virtual ~SessionHost() = default;
    virtual void initialize_graphics() = 0;
    [[nodiscard]] virtual std::unique_ptr<DisplayPresenter> create_display(
        const DeviceModel& device) = 0;
    [[nodiscard]] virtual std::unique_ptr<ControlChannel> create_control(
        const DeviceModel& device) = 0;
    [[nodiscard]] virtual SessionAudio create_audio() = 0;
    [[nodiscard]] virtual HostMemorySnapshot memory_snapshot() const = 0;
    [[nodiscard]] virtual HostMemoryBudgetSnapshot
    memory_budget_snapshot() const = 0;
};

} // namespace shade
