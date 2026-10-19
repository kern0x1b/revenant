// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Reply to guest Mach port-name and right-type queries.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_port.defs

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "mach/mig_wire_abi.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <vector>

#include "../support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t complex_reply_size = 68;
    constexpr std::uint32_t simple_reply_size = 36;
    constexpr std::uint32_t mach_message_success = 0;
    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;

} // namespace

bool CompatibilityKernel::dispatch_mach_port_query_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using Routine = xnu::mig::mach_port::Routine;
    if (request.identifier !=
        mach_support::mig_message_id(Routine::mach_port_names)) {
        return false;
    }

    auto& registers = cpu.registers();
    if (registers[3] < complex_reply_size) {
        return false;
    }

    std::vector<xnu::ipc::NamedEntry> entries;
    std::uint32_t result = darwin::mach::success;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto target = mach_support::target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
        if (!target) {
            result = darwin::mach::invalid_argument;
        } else {
            entries = shared_state_->mach_namespaces.entries(*target);
        }
    }

    std::uint32_t names_address = 0;
    std::uint32_t types_address = 0;
    std::uint32_t array_bytes = 0;
    if (result == darwin::mach::success) {
        if (entries.size() >
            std::numeric_limits<std::uint32_t>::max() / sizeof(std::uint32_t)) {
            result = 3; // KERN_RESOURCE_SHORTAGE
        } else {
            array_bytes = static_cast<std::uint32_t>(
                entries.size() * sizeof(std::uint32_t));
        }
    }
    if (result == darwin::mach::success && array_bytes != 0) {
        const auto total_bytes = static_cast<std::uint64_t>(array_bytes) * 2U;
        const auto mapped_bytes64 =
            (total_bytes + AddressSpace::page_size - 1U) &
            ~(static_cast<std::uint64_t>(AddressSpace::page_size) - 1U);
        if (mapped_bytes64 > std::numeric_limits<std::uint32_t>::max()) {
            result = 3;
        } else {
            const auto mapped_bytes =
                static_cast<std::uint32_t>(mapped_bytes64);
            const auto base = mach_support::find_free_guest_region(
                memory_, mach_support::ool_results_base, mapped_bytes);
            if (!base ||
                !memory_.map(*base, mapped_bytes,
                    MemoryPermission::Read | MemoryPermission::Write)) {
                result = 3;
            } else {
                names_address = *base;
                types_address = *base + array_bytes;
                for (std::size_t index = 0; index < entries.size(); ++index) {
                    const auto offset = static_cast<std::uint32_t>(
                        index * sizeof(std::uint32_t));
                    if (!memory_.write32(
                            names_address + offset, entries[index].name) ||
                        !memory_.write32(types_address + offset,
                            entries[index].entry.type)) {
                        registers[0] = mach_receive_invalid_data;
                        return true;
                    }
                }
            }
        }
    }

    if (result != darwin::mach::success) {
        const std::array<std::uint32_t, 9> reply {
            darwin::mig_wire::disposition_move_send_once,
            simple_reply_size,
            request.local_port,
            0,
            0,
            request.identifier + 100U,
            0,
            1,
            result,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    request.address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                registers[0] = mach_receive_invalid_data;
                return true;
            }
        }
    } else {
        const auto count = static_cast<std::uint32_t>(entries.size());
        // MIG complex success replies omit RetCode. Generated metadata places
        // the two OOL-array counts immediately after NDR at offsets 60 and 64.
        const std::array<std::uint32_t, 17> reply {
            darwin::mach_message::bits_complex |
                darwin::mig_wire::disposition_move_send_once,
            complex_reply_size,
            request.local_port,
            0,
            0,
            request.identifier + 100U,
            2,
            names_address,
            array_bytes,
            0x01000100U,
            types_address,
            array_bytes,
            0x01000100U,
            0,
            1,
            count,
            count,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    request.address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                registers[0] = mach_receive_invalid_data;
                return true;
            }
        }
    }

    output_.write("[mach] port-names pid=" + std::to_string(process_.pid) +
                  " count=" + std::to_string(entries.size()) +
                  " result=" + std::to_string(result) + "\n");
    registers[0] = mach_message_success;
    return true;
}

} // namespace shade
