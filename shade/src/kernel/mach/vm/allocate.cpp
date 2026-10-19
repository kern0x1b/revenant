// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest virtual-memory allocation messages and address
// replies.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <array>
#include <cstdint>
#include <string>

#include "../support.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    // XNU publishes the pointer-sized vm_map interface at 3800 and also
    // exposes its mach_vm compatibility subsystem at 4800. On ARM32 the
    // mach_vm_allocate client uses the same 32-bit wire fields as vm_allocate.
    constexpr std::uint32_t mach_vm_allocate_identifier = 4800U;
    constexpr std::uint32_t request_size = 44U;
    constexpr std::uint32_t reply_size = 40U;

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_allocate_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using namespace mach_support;
    using namespace mach_vm_support;
    const auto vm_allocate_identifier =
        mig_message_id(xnu::mig::vm_map::Routine::vm_allocate);
    if (request.identifier != vm_allocate_identifier &&
        request.identifier != mach_vm_allocate_identifier) {
        return false;
    }

    auto& registers = cpu.registers();
    if (registers[2] < request_size || registers[3] < reply_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    const auto& arguments = xnu::mig::vm_map::vm_allocate_arguments;
    const auto requested_address =
        memory_.read32(request.address + arguments[1].request_offset)
            .value_or(0);
    const auto size =
        memory_.read32(request.address + arguments[2].request_offset)
            .value_or(0);
    const auto flags =
        memory_.read32(request.address + arguments[3].request_offset)
            .value_or(0);
    const auto allocation =
        allocate_guest_vm_region(memory_, requested_address, size, flags);

    const std::array<std::uint32_t, reply_size / sizeof(std::uint32_t)> reply {
        darwin::mig_wire::message_bits(
            darwin::mig_wire::disposition_move_send_once),
        reply_size,
        request.local_port,
        0,
        0,
        request.identifier + 100U,
        0,
        1,
        allocation.result,
        allocation.address,
    };
    if (!write_words(memory_, request.address, reply)) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }
    output_.write(
        "[vm] allocate pid=" + std::to_string(process_.pid) + " interface=" +
        (request.identifier == mach_vm_allocate_identifier
                ? std::string { "mach_vm" }
                : std::string { "vm_map" }) +
        " requested=" + std::to_string(requested_address) +
        " address=" + std::to_string(allocation.address) +
        " size=" + std::to_string(size) + " flags=" + std::to_string(flags) +
        " result=" + std::to_string(allocation.result) + "\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
