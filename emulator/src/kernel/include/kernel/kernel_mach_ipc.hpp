// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Normalize Mach messages and maintain pointer and descriptor
// transport metadata.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

#include "kernel/kernel_shared_state.hpp"

namespace emulator::mach_ipc {

struct ReceivedMessage {
    std::vector<std::byte> bytes;
    std::uint32_t caller_header_size { };
    std::uint32_t message_id { };
    std::size_t message_size { };
    std::size_t trailer_size { };
};

[[nodiscard]] bool normalize_send_header(
    std::vector<std::byte>& bytes, std::size_t send_size);

[[nodiscard]] bool apply_receive_pointer_fixups(
    const KernelSharedState::MachMessage& message,
    std::uint32_t receive_address, std::vector<std::byte>& received_bytes);

[[nodiscard]] std::optional<ReceivedMessage> prepare_received_message(
    const KernelSharedState::MachMessage& message,
    std::uint32_t destination_name, std::uint32_t receive_options,
    std::uint32_t sequence_number = 0, std::uint64_t context = 0,
    DarwinMachVmAddressWidth context_width = DarwinMachVmAddressWidth::Natural32);

}
