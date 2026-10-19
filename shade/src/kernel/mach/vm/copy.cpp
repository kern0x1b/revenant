// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copy guest virtual-memory ranges with overlapping-range semantics.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/vm/vm_map.c

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <cstdint>
#include <string>

#include "../support.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    // XNU's mach_vm subsystem omits vm_region from the leading routine
    // sequence, so mach_vm_copy is 4807 rather than vm_map's 3808. ARM32 keeps
    // the same source/size/destination request and simple-reply contract used
    // by vm_copy.
    constexpr std::uint32_t mach_vm_copy_identifier = 4807U;
    constexpr std::uint32_t vm_copy_request_size =
        xnu::mig::vm_map::vm_copy_arguments[3].request_offset +
        darwin::mig_wire::word_size;

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_copy_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using xnu::mig::vm_map::Routine;
    using namespace mach_support;
    using namespace mach_vm_support;

    const auto is_mach_vm = request.identifier == mach_vm_copy_identifier;
    if (request.identifier != mig_message_id(Routine::vm_copy) && !is_mach_vm)
        return false;

    auto& registers = cpu.registers();
    const auto fail_transport = [&] {
        registers[0] = mach_receive_invalid_data;
        return true;
    };
    const auto finish = [&](std::uint32_t result) {
        if (!write_simple_reply(memory_, request.address, request.local_port,
                request.identifier, result)) {
            return fail_transport();
        }
        registers[0] = kern_success;
        return true;
    };

    if (registers[2] < vm_copy_request_size ||
        registers[3] < simple_reply_size) {
        return fail_transport();
    }

    const auto& arguments = xnu::mig::vm_map::vm_copy_arguments;
    const auto source =
        memory_.read32(request.address + arguments[1].request_offset);
    const auto size =
        memory_.read32(request.address + arguments[2].request_offset);
    const auto destination =
        memory_.read32(request.address + arguments[3].request_offset);
    if (!source || !size || !destination)
        return fail_transport();

    if (*size > maximum_message_io)
        return finish(kern_resource_shortage);

    const auto bytes = memory_.read_bytes(*source, *size);
    if (!bytes ||
        !memory_.accessible(*destination, *size, MemoryPermission::Write)) {
        return finish(kern_invalid_address);
    }

    // Read into an independent buffer before overwriting the destination.
    // This preserves XNU vm_map_copyin/vm_map_copy_overwrite overlap semantics.
    if (!memory_.copy_in(*destination, *bytes))
        return finish(kern_invalid_address);

    output_.write(
        "[vm] copy pid=" + std::to_string(process_.pid) + " interface=" +
        (is_mach_vm ? std::string { "mach_vm" } : std::string { "vm_map" }) +
        " source=" + std::to_string(*source) +
        " destination=" + std::to_string(*destination) +
        " size=" + std::to_string(*size) + " result=0\n");
    return finish(kern_success);
}

} // namespace shade
