// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Apply guest virtual-memory protection changes.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <cstdint>

#include "../support.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t mach_vm_protect_identifier = 4802U;
    constexpr std::uint32_t request_size =
        xnu::mig::vm_map::vm_protect_arguments[4].request_offset +
        darwin::mig_wire::word_size;

    MemoryPermission memory_permissions(std::uint32_t protection)
    {
        MemoryPermission result = MemoryPermission::None;
        if ((protection & 1U) != 0)
            result |= MemoryPermission::Read;
        if ((protection & 2U) != 0)
            result |= MemoryPermission::Write;
        if ((protection & 4U) != 0)
            result |= MemoryPermission::Execute;
        return result;
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_protect_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using namespace mach_support;
    using namespace mach_vm_support;

    const auto vm_protect_identifier =
        mig_message_id(xnu::mig::vm_map::Routine::vm_protect);
    if (request.identifier != vm_protect_identifier &&
        request.identifier != mach_vm_protect_identifier) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto fail_transport = [&] {
        registers[0] = mach_receive_invalid_data;
        return true;
    };
    if (registers[2] < request_size || registers[3] < simple_reply_size)
        return fail_transport();

    const auto& arguments = xnu::mig::vm_map::vm_protect_arguments;
    const auto address =
        memory_.read32(request.address + arguments[1].request_offset);
    const auto size =
        memory_.read32(request.address + arguments[2].request_offset);
    const auto protection =
        memory_.read32(request.address + arguments[4].request_offset);
    if (!address || !size || !protection)
        return fail_transport();

    const auto result =
        protect_memory(cpu, *address, *size, memory_permissions(*protection))
            ? kern_success
            : kern_invalid_address;
    if (!write_simple_reply(memory_, request.address, request.local_port,
            request.identifier, result)) {
        return fail_transport();
    }
    registers[0] = kern_success;
    return true;
}

} // namespace shade
