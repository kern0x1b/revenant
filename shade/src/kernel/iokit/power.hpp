// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Declare the virtual root power-domain service and notification
// boundary.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/iokit/Kernel/IOPMrootDomain.cpp

#pragma once

#include <cstdint>
#include <optional>

namespace shade {

class AddressSpace;
class Output;
struct KernelSharedState;
struct ProcessContext;

namespace kernel_iokit {

    // Implements the root power-domain subset used by
    // IORegisterForSystemPower. Requests for other IOKit services are left to
    // the general device dispatcher.
    [[nodiscard]] std::optional<std::uint32_t> handle_power_mach_request(
        AddressSpace& memory, Output& output, KernelSharedState& shared_state,
        ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t receive_size,
        std::uint32_t remote_object, std::uint32_t local_port);

} // namespace kernel_iokit
} // namespace shade
