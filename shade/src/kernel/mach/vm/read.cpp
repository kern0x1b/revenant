// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Read or overwrite guest virtual-memory ranges through Mach
// messages.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <array>
#include <cstdint>
#include <string>

#include "../support.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    // XNU's mach_vm subsystem omits vm_region from the leading routine
    // sequence, so mach_vm_read is 4804 rather than vm_map's 3805. ARM32 keeps
    // the same 32-bit request and OOL reply contract used by vm_read.
    constexpr std::uint32_t mach_vm_read_identifier = 4804U;
    constexpr std::uint32_t vm_read_request_size =
        xnu::mig::vm_map::vm_read_arguments[2].request_offset +
        darwin::mig_wire::word_size;
    constexpr std::uint32_t vm_read_reply_size =
        xnu::mig::vm_map::vm_read_arguments[3].reply_count_offset +
        darwin::mig_wire::word_size;

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_read_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using xnu::mig::vm_map::Routine;
    using namespace mach_support;
    using namespace mach_vm_support;

    const auto is_mach_vm = request.identifier == mach_vm_read_identifier;
    if (request.identifier != mig_message_id(Routine::vm_read) && !is_mach_vm)
        return false;

    auto& registers = cpu.registers();
    const auto fail_transport = [&] {
        registers[0] = mach_receive_invalid_data;
        return true;
    };
    const auto fail_kernel = [&](std::uint32_t result) {
        if (!write_simple_reply(memory_, request.address, request.local_port,
                request.identifier, result)) {
            return fail_transport();
        }
        registers[0] = kern_success;
        return true;
    };

    if (registers[2] < vm_read_request_size ||
        registers[3] < simple_reply_size) {
        return fail_transport();
    }

    const auto& arguments = xnu::mig::vm_map::vm_read_arguments;
    const auto source =
        memory_.read32(request.address + arguments[1].request_offset);
    const auto size =
        memory_.read32(request.address + arguments[2].request_offset);
    if (!source || !size)
        return fail_transport();

    if (*size > maximum_message_io)
        return fail_kernel(kern_resource_shortage);

    const auto bytes = memory_.read_bytes(*source, *size);
    if (!bytes)
        return fail_kernel(kern_invalid_address);

    if (registers[3] < vm_read_reply_size)
        return fail_transport();

    std::uint32_t copied_address = 0;
    if (*size != 0) {
        copied_address =
            find_free_guest_region(memory_, ool_results_base, *size)
                .value_or(0);
        if (copied_address == 0 ||
            !memory_.map(copied_address, *size,
                MemoryPermission::Read | MemoryPermission::Write) ||
            !memory_.copy_in(copied_address, *bytes)) {
            if (copied_address != 0)
                static_cast<void>(memory_.unmap(copied_address, *size));
            return fail_kernel(kern_resource_shortage);
        }
    }

    const std::array reply {
        darwin::mig_wire::message_bits(
            darwin::mig_wire::disposition_move_send_once, 0, true),
        vm_read_reply_size,
        request.local_port,
        0U,
        0U,
        request.identifier + 100U,
        1U,
        copied_address,
        *size,
        darwin::mig_wire::ool_descriptor_metadata(false),
        0U, // NDR migration/character/float representation word
        1U, // NDR little-endian integer representation word
        *size,
    };
    if (!write_words(memory_, request.address, reply)) {
        if (copied_address != 0)
            static_cast<void>(memory_.unmap(copied_address, *size));
        return fail_transport();
    }

    output_.write(
        "[vm] read pid=" + std::to_string(process_.pid) + " interface=" +
        (is_mach_vm ? std::string { "mach_vm" } : std::string { "vm_map" }) +
        " source=" + std::to_string(*source) +
        " size=" + std::to_string(*size) +
        " copy=" + std::to_string(copied_address) + " result=0\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
