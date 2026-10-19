// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Model virtual serial-device attributes, buffered data and offline
// controller replies.

#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <span>
#include <string_view>
#include <vector>

#include "kernel/darwin_tty_abi.hpp"

namespace shade::bsd::offline_serial_device {

// A controller may be absent while its firmware-defined serial node remains
// discoverable. The descriptor implements ordinary TTY setup and a minimal
// H4 transport that rejects complete HCI commands with Hardware Failure.
inline constexpr std::string_view descriptor_kind { "offline-serial" };
inline constexpr std::string_view directory_name { "cu.bluetooth" };
inline constexpr unsigned device_minor = 4;

class State {
public:
    [[nodiscard]] darwin::tty::Arm32Attributes attributes() const;
    void set_attributes(const darwin::tty::Arm32Attributes& attributes);
    void inherit_configuration(const State& parent);

    [[nodiscard]] std::size_t write(std::span<const std::byte> bytes);
    [[nodiscard]] std::vector<std::byte> read(std::size_t maximum);
    [[nodiscard]] std::size_t pending_bytes() const;

private:
    void consume_h4_byte(std::byte value);

    mutable std::mutex mutex_;
    darwin::tty::Arm32Attributes attributes_ {
        darwin::tty::default_attributes()
    };
    std::vector<std::byte> command_;
    std::deque<std::byte> receive_queue_;
};

[[nodiscard]] bool is_path(std::string_view candidate);

} // namespace shade::bsd::offline_serial_device
