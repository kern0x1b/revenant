// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Enumerate guest tasks, threads and registered task ports.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/task.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/task_mig_ids.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <span>
#include <vector>

#include "../support.hpp"

namespace shade {
namespace {

    using namespace mach_support;

    constexpr std::uint32_t mach_message_success = 0;
    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t kernel_invalid_argument = 4;
    constexpr std::uint32_t kernel_resource_shortage = 3;
    constexpr std::uint32_t complex_move_send_once = 0x80000012U;
    constexpr std::uint32_t complex_ool_ports_reply_size = 52;
    constexpr std::uint32_t simple_reply_size = 36;

    bool write_words(AddressSpace& memory, std::uint32_t address,
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

bool CompatibilityKernel::dispatch_mach_task_enumeration_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    const auto message_id = request.identifier;
    if (message_id !=
        mig_message_id(xnu::mig::task::Routine::task_threads)) {
        return false;
    }

    auto& registers = cpu.registers();
    if (registers[3] < simple_reply_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    std::vector<std::uint32_t> thread_names;
    std::uint32_t result = mach_message_success;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto target_pid = target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
        const auto target_threads =
            target_pid
                ? shared_state_->task_thread_port_objects.find(*target_pid)
                : shared_state_->task_thread_port_objects.end();
        if (!target_pid ||
            target_threads == shared_state_->task_thread_port_objects.end()) {
            result = kernel_invalid_argument;
        } else {
            thread_names.reserve(target_threads->second.size());
            for (const auto& [slot, object] : target_threads->second) {
                static_cast<void>(slot);
                const auto name =
                    shared_state_->mach_namespaces.copyout(process_.pid, object,
                        xnu::ipc::type_mask(xnu::ipc::Right::Send));
                if (!name) {
                    result = kernel_resource_shortage;
                    thread_names.clear();
                    break;
                }
                thread_names.push_back(*name);
            }
        }
    }

    if (result != mach_message_success ||
        registers[3] < complex_ool_ports_reply_size) {
        const std::array<std::uint32_t,
            simple_reply_size / sizeof(std::uint32_t)>
            reply {
                darwin::mig_wire::message_bits(
                    darwin::mig_wire::disposition_move_send_once),
                simple_reply_size,
                request.local_port,
                0,
                0,
                message_id + 100,
                0,
                1,
                result != mach_message_success ? result
                                               : kernel_resource_shortage,
            };
        registers[0] = write_words(memory_, request.address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
        return true;
    }

    std::uint32_t array_address = 0;
    if (!thread_names.empty()) {
        const auto byte_count = static_cast<std::uint32_t>(
            thread_names.size() * sizeof(std::uint32_t));
        const auto mapped_size = (byte_count + AddressSpace::page_size - 1U) &
                                 ~(AddressSpace::page_size - 1U);
        const auto region =
            find_free_guest_region(memory_, ool_results_base, mapped_size);
        if (!region || !memory_.map(*region, mapped_size,
                           MemoryPermission::Read | MemoryPermission::Write)) {
            registers[0] = mach_receive_invalid_data;
            return true;
        }
        array_address = *region;
        for (std::size_t index = 0; index < thread_names.size(); ++index) {
            if (!memory_.write32(
                    array_address + static_cast<std::uint32_t>(
                                        index * sizeof(std::uint32_t)),
                    thread_names[index])) {
                registers[0] = mach_receive_invalid_data;
                return true;
            }
        }
    }

    const auto count = static_cast<std::uint32_t>(thread_names.size());
    const std::array<std::uint32_t,
        complex_ool_ports_reply_size / sizeof(std::uint32_t)>
        reply {
            complex_move_send_once,
            complex_ool_ports_reply_size,
            request.local_port,
            0,
            0,
            message_id + 100,
            1,
            array_address,
            count,
            darwin::mig_wire::ool_ports_descriptor_metadata(
                darwin::mig_wire::disposition_move_send, true),
            0,
            1,
            count,
        };
    registers[0] = write_words(memory_, request.address, reply)
                       ? mach_message_success
                       : mach_receive_invalid_data;
    output_.write("[mach] task_threads caller=" + std::to_string(process_.pid) +
                  " count=" + std::to_string(count) + "\n");
    return true;
}

} // namespace shade
