// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Reply to guest Mach host-information and statistics messages.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_host.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/host_info.h

#include "mach/bootstrap_mig_ids.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/kernel.hpp"
#include "kernel/kernel_clock.hpp"
#include "kernel/kernel_iokit.hpp"
#include "kernel/kernel_mach_ipc.hpp"
#include "kernel/kernel_network.hpp"
#include "kernel/mach_clock_abi.hpp"
#include "kernel/mach_host_statistics_abi.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "kernel/mach_scheduler_abi.hpp"
#include "kernel/mach_thread_policy_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/task_mig_ids.hpp"
#include "mach/thread_act_mig_ids.hpp"
#include "mach/vm_map_mig_ids.hpp"
#include "mach/xnu_mig_adapter.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <span>
#include <sstream>
#include <string_view>
#include <utility>
#include <vector>

#include "support.hpp"

namespace shade {

using namespace mach_support;

namespace {

    using namespace darwin::mach::xnu;

    bool write_message_words(AddressSpace& memory, std::uint32_t address,
        std::span<const std::uint32_t> words)
    {
        for (std::size_t index = 0; index < words.size(); ++index) {
            if (!memory.write32(address + static_cast<std::uint32_t>(
                                            index * sizeof(std::uint32_t)),
                    words[index])) {
                return false;
            }
        }
        return true;
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_host_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    auto& registers = cpu.registers();
    const auto message_address = request.address;
    const std::optional<std::uint32_t> bits { request.bits };
    const std::optional<std::uint32_t> remote_port { request.remote_port };
    const std::optional<std::uint32_t> local_port { request.local_port };
    const std::optional<std::uint32_t> message_id { request.identifier };
    const auto write_result_reply = [&](std::uint32_t result) {
        if (registers[3] < darwin::mig_wire::simple_reply_payload_base) {
            registers[0] = darwin::mach_message::receive_invalid_data;
            return;
        }
        const std::array<std::uint32_t, 9> reply {
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_move_send_once),
            darwin::mig_wire::simple_reply_payload_base,
            *local_port,
            0,
            0,
            *message_id + 100U,
            0,
            1,
            result,
        };
        registers[0] = write_message_words(memory_, message_address, reply)
                           ? darwin::mach::success
                           : darwin::mach_message::receive_invalid_data;
    };
    const auto write_counted_reply = [&](std::uint32_t result,
                                         std::span<const std::uint32_t> data) {
        const auto reply_size = static_cast<std::uint32_t>(
            message::inline_data_reply_offset +
            data.size() * sizeof(std::uint32_t));
        if (registers[3] < reply_size) {
            registers[0] = darwin::mach_message::receive_invalid_data;
            return;
        }
        std::vector<std::uint32_t> reply {
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_move_send_once),
            reply_size,
            *local_port,
            0,
            0,
            *message_id + 100U,
            0,
            1,
            result,
            static_cast<std::uint32_t>(data.size()),
        };
        reply.insert(reply.end(), data.begin(), data.end());
        registers[0] = write_message_words(memory_, message_address, reply)
                           ? darwin::mach::success
                           : darwin::mach_message::receive_invalid_data;
    };
    if (*message_id == routine::host_info) {
        const auto flavor =
            memory_.read32(message_address + message::flavor_offset).value_or(0);
        const auto requested_count =
            memory_.read32(message_address + message::count_inout_request_offset)
                .value_or(0);
        if (flavor == host_info::basic_flavor &&
            requested_count >= host_info::basic_old_word_count) {
            // The host_basic_info ABI accepts the five-word legacy prefix and
            // returns the full structure when it fits.
            const auto configured_memory_size =
                device_model_.memory.usable_ram_bytes != 0
                    ? std::min(device_model_.memory.usable_ram_bytes,
                          shared_state_->device_ram_bytes)
                    : shared_state_->device_ram_bytes;
            const auto memory_size = static_cast<std::uint32_t>(
                std::min<std::uint64_t>(configured_memory_size,
                    std::numeric_limits<std::uint32_t>::max()));
            const auto max_mem = shared_state_->device_ram_bytes;
            const std::array<std::uint32_t, host_info::basic_word_count> info {
                virtual_processor_count_, // max_cpus
                virtual_processor_count_, // avail_cpus
                memory_size,
                shared_state_->device_cpu_type,
                shared_state_->device_cpu_subtype,
                0, // cpu_threadtype
                virtual_processor_count_, // physical_cpu
                virtual_processor_count_, // physical_cpu_max
                virtual_processor_count_, // logical_cpu
                virtual_processor_count_, // logical_cpu_max
                static_cast<std::uint32_t>(max_mem), // max_mem, low 32 bits
                static_cast<std::uint32_t>(max_mem >> 32U), // high 32 bits
            };
            const auto count = requested_count >= info.size()
                                   ? info.size()
                                   : host_info::basic_old_word_count;
            write_counted_reply(0, std::span { info }.first(count));
            return true;
        }
        if (flavor == host_info::priority_flavor &&
            requested_count >= host_info::priority_word_count) {
            const std::array<std::uint32_t, host_info::priority_word_count> info {
                80, // MINPRI_KERNEL
                80, // MINPRI_KERNEL
                64, // MINPRI_RESERVED
                31, // BASEPRI_DEFAULT
                0, // DEPRESSPRI
                0, // IDLEPRI
                0, // MINPRI_USER
                79, // MAXPRI_RESERVED
            };
            write_counted_reply(0, info);
            return true;
        }
        write_result_reply(darwin::mach::failure);
        return true;
    }
    if (*message_id == routine::host_statistics) {
        const auto flavor =
            memory_.read32(message_address + message::flavor_offset).value_or(0);
        const auto requested_count =
            memory_.read32(message_address + message::count_inout_request_offset)
                .value_or(0);
        if (flavor == host_statistics::load_flavor &&
            requested_count >= host_statistics::load_word_count) {
            const std::array<std::uint32_t, host_statistics::load_word_count>
                info { };
            write_counted_reply(0, info);
            return true;
        }
        if (flavor == host_statistics::vm_flavor &&
            requested_count >= host_statistics::vm_rev0_word_count) {
            const auto total_pages = std::min<std::uint64_t>(
                shared_state_->device_ram_bytes / AddressSpace::page_size +
                    (shared_state_->device_ram_bytes % AddressSpace::page_size !=
                            0),
                std::numeric_limits<std::uint32_t>::max());
            const auto resident_pages = std::min<std::uint64_t>(
                memory_.resident_page_count(), total_pages);
            std::array<std::uint32_t, host_statistics::vm_rev2_word_count>
                info { };
            // vm_statistics free count includes speculative pages. The
            // emulator has no separate global VM queues, so project the
            // address space's resident pages into active memory and keep the
            // total-page invariant visible to host consumers.
            info[0] = static_cast<std::uint32_t>(total_pages - resident_pages);
            info[1] = static_cast<std::uint32_t>(resident_pages);
            const auto count = requested_count >= host_statistics::vm_rev2_word_count
                                   ? host_statistics::vm_rev2_word_count
                                   : requested_count >= host_statistics::vm_rev1_word_count
                                   ? host_statistics::vm_rev1_word_count
                                   : host_statistics::vm_rev0_word_count;
            write_counted_reply(0, std::span { info }.first(count));
            return true;
        }
        if (flavor == host_statistics::cpu_load_flavor &&
            requested_count >= host_statistics::cpu_load_word_count) {
            const std::array<std::uint32_t, host_statistics::cpu_load_word_count>
                info { };
            write_counted_reply(0, info);
            return true;
        }
        write_result_reply(darwin::mach::failure);
        return true;
    }
    if (*message_id == routine::host_page_size && registers[3] >= 40) {
        const std::array<std::uint32_t, 10> reply {
            18, // MOVE_SEND_ONCE reply right
            40, // message size
            *local_port, // reply destination
            0,
            0,
            *message_id + 100, // MIG reply ID
            0x00000000U, // NDR bytes 0..3
            0x00000001U, // little-endian NDR, bytes 4..7
            0, // KERN_SUCCESS
            AddressSpace::page_size,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    message_address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                registers[0] = 0x10004008U; // MACH_RCV_INVALID_DATA
                return true;
            }
        }
        registers[0] = 0; // MACH_MSG_SUCCESS
        return true;
    }
    return false;
}

} // namespace shade
