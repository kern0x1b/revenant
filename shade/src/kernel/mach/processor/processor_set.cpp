// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest processor-set discovery and processor information
// messages.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/processor_set.defs

#include "kernel/kernel.hpp"

#include "mach/host_priv_mig_ids.hpp"
#include "mach/mach_port_object.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/processor_set_mig_ids.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <optional>
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
    constexpr std::uint32_t complex_port_reply_size = 40;
    constexpr std::uint32_t complex_ool_ports_reply_size = 52;

    bool write_words(AddressSpace& memory, std::uint32_t address,
        std::span<const std::uint32_t> words)
    {
        for (std::size_t index = 0; index < words.size(); ++index) {
            if (!memory.write32(
                    address + static_cast<std::uint32_t>(index * 4U),
                    words[index])) {
                return false;
            }
        }
        return true;
    }

    void ensure_default_processor_set(KernelSharedState& state)
    {
        if (state.default_processor_set_name_object != 0) {
            return;
        }
        state.default_processor_set_name_object = state.allocate_mach_object();
        state.default_processor_set_control_object =
            state.allocate_mach_object();
        static_cast<void>(state.mach_port_objects.create(
            state.default_processor_set_name_object));
        static_cast<void>(state.mach_port_objects.create(
            state.default_processor_set_control_object));
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_processor_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using host_routine = xnu::mig::host_priv::Routine;
    using processor_routine = xnu::mig::processor_set::Routine;

    auto& registers = cpu.registers();
    const auto message_address = request.address;
    const auto message_id = request.identifier;
    const auto local_port = request.local_port;

    if (message_id == mig_message_id(host_routine::host_processor_sets) ||
        message_id == mig_message_id(host_routine::host_processor_set_priv)) {
        // MIG identifiers are local to a destination's subsystem. The host
        // privilege range overlaps launchd's vproc protocol, so a matching
        // number alone must not intercept messages to a user-space server.
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto destination = shared_state_->mach_namespaces.resolve(
            process_.pid, request.remote_port);
        if (destination != mach_task_identity::initial_host_self_name)
            return false;
    }

    if (message_id == mig_message_id(host_routine::host_processor_sets) &&
        registers[3] >= complex_ool_ports_reply_size) {
        std::uint32_t name = 0;
        std::uint32_t result = mach_message_success;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            ensure_default_processor_set(*shared_state_);
            name = shared_state_->mach_namespaces
                       .copyout(process_.pid,
                           shared_state_->default_processor_set_name_object,
                           xnu::ipc::type_mask(xnu::ipc::Right::Send))
                       .value_or(0);
            if (name == 0) {
                result = kernel_resource_shortage;
            }
        }

        std::uint32_t array_address = 0;
        if (result == mach_message_success) {
            const auto region = find_free_guest_region(
                memory_, ool_results_base, AddressSpace::page_size);
            if (!region ||
                !memory_.map(*region, AddressSpace::page_size,
                    MemoryPermission::Read | MemoryPermission::Write) ||
                !memory_.write32(*region, name)) {
                result = kernel_resource_shortage;
            } else {
                array_address = *region;
            }
        }
        const auto count = result == mach_message_success ? 1U : 0U;
        // Complex MIG success replies omit RetCode. The trailing scalar is the
        // array count at the generated reply_count_offset (48).
        const std::array<std::uint32_t, 13> reply {
            complex_move_send_once,
            complex_ool_ports_reply_size,
            local_port,
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
        registers[0] = write_words(memory_, message_address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
        output_.write(
            "[mach] host_processor_sets pid=" + std::to_string(process_.pid) +
            " count=" + std::to_string(count) +
            " result=" + std::to_string(result) + "\n");
        return true;
    }

    if (message_id == mig_message_id(host_routine::host_processor_set_priv) &&
        registers[3] >= complex_port_reply_size) {
        const auto set_name = memory_.read32(
            message_address +
            xnu::mig::host_priv::host_processor_set_priv_arguments[1]
                .request_offset);
        std::uint32_t control_name = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            ensure_default_processor_set(*shared_state_);
            const auto object = set_name
                                    ? shared_state_->mach_namespaces.resolve(
                                          process_.pid, *set_name)
                                    : std::nullopt;
            if (object == shared_state_->default_processor_set_name_object) {
                control_name =
                    shared_state_->mach_namespaces
                        .copyout(process_.pid,
                            shared_state_->default_processor_set_control_object,
                            xnu::ipc::type_mask(xnu::ipc::Right::Send))
                        .value_or(0);
            }
        }
        const std::array<std::uint32_t, 10> reply {
            complex_move_send_once,
            complex_port_reply_size,
            local_port,
            0,
            0,
            message_id + 100,
            1,
            control_name,
            0,
            darwin::mig_wire::port_descriptor_metadata(
                darwin::mig_wire::disposition_move_send),
        };
        registers[0] = write_words(memory_, message_address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
        return true;
    }

    if (message_id == mig_message_id(processor_routine::processor_set_tasks) &&
        registers[3] >= complex_ool_ports_reply_size) {
        std::vector<std::uint32_t> task_names;
        std::uint32_t result = mach_message_success;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            ensure_default_processor_set(*shared_state_);
            const auto destination = shared_state_->mach_namespaces.resolve(
                process_.pid, request.remote_port);
            if (destination !=
                shared_state_->default_processor_set_control_object) {
                result = kernel_invalid_argument;
            } else {
                for (const auto& [pid, process] : shared_state_->processes) {
                    if (process.exited) {
                        continue;
                    }
                    for (const auto& [task_object, owner_pid] :
                        shared_state_->task_port_pids) {
                        if (owner_pid != pid) {
                            continue;
                        }
                        const auto task_name =
                            shared_state_->mach_namespaces.copyout(process_.pid,
                                task_object,
                                xnu::ipc::type_mask(
                                    xnu::ipc::Right::Send));
                        if (!task_name) {
                            result = kernel_resource_shortage;
                            break;
                        }
                        task_names.push_back(*task_name);
                        break;
                    }
                    if (result != mach_message_success) {
                        break;
                    }
                }
            }
        }

        std::uint32_t array_address = 0;
        if (result == mach_message_success && !task_names.empty()) {
            const auto bytes = static_cast<std::uint32_t>(
                task_names.size() * sizeof(std::uint32_t));
            const auto mapped = (bytes + AddressSpace::page_size - 1U) &
                                ~(AddressSpace::page_size - 1U);
            const auto region =
                find_free_guest_region(memory_, ool_results_base, mapped);
            if (!region ||
                !memory_.map(*region, mapped,
                    MemoryPermission::Read | MemoryPermission::Write)) {
                result = kernel_resource_shortage;
            } else {
                array_address = *region;
                for (std::size_t index = 0; index < task_names.size();
                    ++index) {
                    if (!memory_.write32(
                            array_address +
                                static_cast<std::uint32_t>(index * 4U),
                            task_names[index])) {
                        registers[0] = mach_receive_invalid_data;
                        return true;
                    }
                }
            }
        }
        const auto count = result == mach_message_success
                               ? static_cast<std::uint32_t>(task_names.size())
                               : 0U;
        const std::array<std::uint32_t, 13> reply {
            complex_move_send_once,
            complex_ool_ports_reply_size,
            local_port,
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
        registers[0] = write_words(memory_, message_address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
        output_.write(
            "[mach] processor_set_tasks pid=" + std::to_string(process_.pid) +
            " count=" + std::to_string(count) +
            " result=" + std::to_string(result) + "\n");
        return true;
    }

    return false;
}

} // namespace shade
