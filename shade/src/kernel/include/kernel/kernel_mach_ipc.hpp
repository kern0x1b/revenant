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

namespace shade::mach_ipc {

struct ReceivedMessage {
    std::vector<std::byte> bytes;
    std::uint32_t caller_header_size { };
    std::uint32_t message_id { };
    std::size_t message_size { };
    std::size_t trailer_size { };
};

// Mirrors ipc_kmsg_get_from_user(): the trap's send_size is trusted over the
// uninitialized msgh_size word produced by several old firmware MIG stubs.
[[nodiscard]] bool normalize_send_header(
    std::vector<std::byte>& bytes, std::size_t send_size);

// Resolves kernel-originated pointers to storage embedded in the receiver's
// Mach message buffer. Old IOKit notifications use this for callback payloads
// whose address cannot be known until mach_msg() supplies its receive address.
[[nodiscard]] bool apply_receive_pointer_fixups(
    const KernelSharedState::MachMessage& message,
    std::uint32_t receive_address, std::vector<std::byte>& received_bytes);

// Converts a sender-form Mach header into receiver form and appends the
// format-0 trailer requested through MACH_RCV_TRAILER_ELEMENTS.
[[nodiscard]] std::optional<ReceivedMessage> prepare_received_message(
    const KernelSharedState::MachMessage& message,
    std::uint32_t destination_name, std::uint32_t receive_options,
    std::uint32_t sequence_number = 0, std::uint64_t context = 0,
    DarwinMachVmAddressWidth context_width = DarwinMachVmAddressWidth::Natural32);

} // namespace shade::mach_ipc
