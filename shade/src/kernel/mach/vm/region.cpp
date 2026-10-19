// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Return guest virtual-memory region information and object metadata.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include "../support.hpp"
#include "wire_format.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    using namespace mach_support;
    using namespace mach_vm_support;

    constexpr std::uint32_t basic_info_64_flavor = 9U;
    constexpr std::uint32_t basic_info_flavor = 10U;
    constexpr std::uint32_t basic_info_64_word_count = 9U;
    constexpr std::uint32_t basic_info_word_count = 8U;
    constexpr std::uint32_t vm_region_identifier = 3800U;
    constexpr std::uint32_t mach_vm_region_identifier = 4816U;
    constexpr std::uint32_t kern_invalid_argument = 4U;

    [[nodiscard]] std::uint32_t darwin_permissions(MemoryPermission permissions)
    {
        std::uint32_t result = 0;
        if (has_permission(permissions, MemoryPermission::Read))
            result |= 1U;
        if (has_permission(permissions, MemoryPermission::Write))
            result |= 2U;
        if (has_permission(permissions, MemoryPermission::Execute))
            result |= 4U;
        return result;
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_region_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using xnu::mig::vm_map::Routine;
    const auto is_vm_region = request.identifier == vm_region_identifier;
    const auto is_mach_vm = request.identifier == mach_vm_region_identifier;
    if (request.identifier != mig_message_id(Routine::vm_region_64) &&
        !is_vm_region && !is_mach_vm) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto profile = MachVmWireFormat::for_interface(
        is_mach_vm, shared_state_->darwin_abi.mach_vm_address);
    const auto width = profile.address_size();
    constexpr auto payload = darwin::mig_wire::simple_request_payload_base;
    const auto region_request_size = payload + width + 8U;
    const auto region_reply_prefix_size =
        darwin::mig_wire::complex_request_word(1, 0) + 2U * width + 4U;
    if (registers[2] < region_request_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }
    const auto address =
        profile.read_address(memory_, request.address + payload);
    const auto flavor = memory_.read32(request.address + payload + width);
    const auto capacity =
        memory_.read32(request.address + payload + width + 4U);
    if (!address || !flavor || !capacity) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    const auto requested_count =
        *flavor == basic_info_64_flavor
            ? basic_info_64_word_count
            : (*flavor == basic_info_flavor ? basic_info_word_count : 0U);
    std::optional<std::uint32_t> target_pid;
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        target_pid = target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
    }
    const auto fail_kernel = [&](std::uint32_t result) {
        if (!write_simple_reply(memory_, request.address, request.local_port,
                request.identifier, result)) {
            registers[0] = mach_receive_invalid_data;
        } else {
            registers[0] = kern_success;
        }
        output_.write("[vm] region caller=" + std::to_string(process_.pid) +
                      " target=" + std::to_string(target_pid.value_or(0)) +
                      " interface=" +
                      (is_mach_vm        ? std::string { "mach_vm" }
                          : is_vm_region ? std::string { "vm_region" }
                                         : std::string { "vm_map" }) +
                      " address=" + std::to_string(*address) +
                      " flavor=" + std::to_string(*flavor) +
                      " capacity=" + std::to_string(*capacity) +
                      " result=" + std::to_string(result) + "\n");
        return true;
    };
    if (!target_pid || requested_count == 0U || *capacity < requested_count)
        return fail_kernel(kern_invalid_argument);
    if (*address > UINT32_MAX)
        return fail_kernel(kern_invalid_address);

    std::optional<AddressSpace::MappingRegion> region;
    if (*target_pid == process_.pid) {
        region = memory_.mapping_region_at_or_after(
            static_cast<std::uint32_t>(*address));
    } else if (task_memory_region_query_) {
        region = task_memory_region_query_(
            *target_pid, static_cast<std::uint32_t>(*address));
    }
    if (!region || region->end <= region->address ||
        region->end - region->address >
            std::numeric_limits<std::uint32_t>::max()) {
        return fail_kernel(kern_invalid_address);
    }

    const auto reply_size =
        region_reply_prefix_size +
        requested_count * static_cast<std::uint32_t>(sizeof(std::uint32_t));
    if (registers[3] < reply_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    const auto protection = darwin_permissions(region->permissions);
    std::vector<std::uint32_t> info {
        protection,
        protection,
        static_cast<std::uint32_t>(region->inheritance),
        0U,
        0U,
        0U,
    };
    if (*flavor == basic_info_64_flavor)
        info.push_back(0U);
    info.push_back(0U);
    info.push_back(0U);

    std::vector<std::uint32_t> reply {
        darwin::mig_wire::message_bits(
            darwin::mig_wire::disposition_move_send_once, 0, true),
        reply_size,
        request.local_port,
        0U,
        0U,
        request.identifier + 100U,
        1U,
        0U,
        0U,
        darwin::mig_wire::port_descriptor_metadata(
            darwin::mig_wire::disposition_move_send),
        0U,
        1U,
    };
    // A complex MIG success reply has no RetCode between NDR and outputs.
    // Error replies use the ordinary simple NDR/RetCode form instead.
    profile.append_address(reply, region->address);
    profile.append_address(reply, region->end - region->address);
    reply.push_back(requested_count);
    reply.insert(reply.end(), info.begin(), info.end());
    if (!write_words(memory_, request.address, reply)) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    output_.write("[vm] region caller=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(*target_pid) + " interface=" +
                  (is_mach_vm        ? std::string { "mach_vm" }
                      : is_vm_region ? std::string { "vm_region" }
                                     : std::string { "vm_map" }) +
                  " requested=" + std::to_string(*address) +
                  " address=" + std::to_string(region->address) +
                  " size=" + std::to_string(region->end - region->address) +
                  " protection=" + std::to_string(protection) +
                  " flavor=" + std::to_string(*flavor) + " result=0\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
