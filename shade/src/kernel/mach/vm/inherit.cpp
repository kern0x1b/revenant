// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Apply guest virtual-memory inheritance policy requests.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <cstdint>
#include <mutex>
#include <optional>
#include <string>

#include "../support.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t request_size =
        xnu::mig::vm_map::vm_inherit_arguments[3].request_offset +
        darwin::mig_wire::word_size;
    constexpr std::uint32_t kern_invalid_argument = 4U;

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_inherit_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using namespace mach_support;
    using namespace mach_vm_support;

    if (request.identifier !=
        mig_message_id(xnu::mig::vm_map::Routine::vm_inherit)) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto fail_transport = [&] {
        registers[0] = mach_receive_invalid_data;
        return true;
    };
    if (registers[2] < request_size || registers[3] < simple_reply_size)
        return fail_transport();

    const auto& arguments = xnu::mig::vm_map::vm_inherit_arguments;
    const auto address =
        memory_.read32(request.address + arguments[1].request_offset);
    const auto size =
        memory_.read32(request.address + arguments[2].request_offset);
    const auto inheritance =
        memory_.read32(request.address + arguments[3].request_offset);
    if (!address || !size || !inheritance)
        return fail_transport();

    std::optional<std::uint32_t> target_pid;
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        target_pid = target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
    }

    std::uint32_t result = kern_success;
    if (!target_pid || *target_pid != process_.pid ||
        *inheritance > static_cast<std::uint32_t>(VmInheritance::None)) {
        result = kern_invalid_argument;
    } else if (!memory_.inherit(*address, *size,
                   static_cast<VmInheritance>(*inheritance))) {
        result = kern_invalid_address;
    }

    if (!write_simple_reply(memory_, request.address, request.local_port,
            request.identifier, result)) {
        return fail_transport();
    }
    output_.write("[vm] inherit caller=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(target_pid.value_or(0U)) +
                  " address=" + std::to_string(*address) +
                  " size=" + std::to_string(*size) +
                  " inheritance=" + std::to_string(*inheritance) +
                  " result=" + std::to_string(result) + "\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
