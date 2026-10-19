// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest thread suspend, resume, terminate and scheduling-
// policy messages.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_act.defs

#include "kernel/darwin_abi.hpp"
#include "kernel/kernel.hpp"
#include "mach/thread_act_mig_ids.hpp"

#include <array>
#include <cstdint>
#include <optional>

#include "../support.hpp"

namespace shade {

using namespace mach_support;

bool CompatibilityKernel::dispatch_mach_thread_lifecycle_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    const auto terminates =
        request.identifier ==
        mig_message_id(xnu::mig::thread_act::Routine::thread_terminate);
    const auto suspends =
        request.identifier ==
        mig_message_id(xnu::mig::thread_act::Routine::thread_suspend);
    const auto resumes =
        request.identifier ==
        mig_message_id(xnu::mig::thread_act::Routine::thread_resume);
    if (!terminates && !suspends && !resumes) {
        return false;
    }

    std::optional<std::uint32_t> target_object;
    std::optional<std::pair<std::uint32_t, std::uint32_t>> target;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        target_object = resolve_name_with_right(*shared_state_, process_.pid,
            request.remote_port, xnu::ipc::Right::Send);
        if (target_object)
            target = find_thread_owner(*shared_state_, *target_object);
    }

    std::uint32_t kernel_result = darwin::mach::invalid_argument;
    if ((suspends || resumes) && target && thread_runnable_handler_ &&
        thread_runnable_handler_(target->first, target->second, resumes)) {
        kernel_result = darwin::mach::success;
        if (resumes && scheduler_preemption_query_ &&
            scheduler_preemption_query_(cpu.processor_id())) {
            // A resume can make a higher-priority thread runnable while the
            // caller is still executing in this CPU's HLE dispatch. Request the
            // same AST boundary as thread creation/policy changes; the current
            // quantum is preserved when the scheduler requeues the caller.
            cpu.request_guest_preemption();
        }
    }
    if (!terminates) {
        output_.write("[thread] " +
                      std::string(resumes ? "resume" : "suspend") +
                      " caller=" + std::to_string(process_.pid) +
                      " target=" + std::to_string(target ? target->first : 0U) +
                      ":" + std::to_string(target ? target->second : 0U) +
                      " result=" + std::to_string(kernel_result) + "\n");
        const std::array<std::uint32_t, 9> reply {
            18,
            36,
            request.local_port,
            0,
            0,
            request.identifier + 100U,
            0,
            1,
            kernel_result,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    request.address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                cpu.registers()[0] = darwin::mach_message::receive_invalid_data;
                return true;
            }
        }
        cpu.registers()[0] = darwin::mach::success;
        return true;
    }

    if (target) {
        const auto accepted =
            !thread_terminate_handler_ ||
            thread_terminate_handler_(target->first, target->second);
        if (accepted) {
            shared_state_->psynch_runtime->cancel_wait(
                DarwinPsynchThread { target->first, target->second });
            if (target->first == process_.pid) {
                process_.thread_disk_io_policies.erase(*target_object);
                pending_psynch_waits_.erase(target->second);
                thread_ports_.erase(target->second);
                end_thread_signals(target->second);
            }
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            auto task =
                shared_state_->task_thread_port_objects.find(target->first);
            if (task != shared_state_->task_thread_port_objects.end()) {
                task->second.erase(target->second);
                if (task->second.empty())
                    shared_state_->task_thread_port_objects.erase(task);
            }
            terminate_receive_object_locked(*shared_state_, *target_object);
            kernel_result = darwin::mach::success;
        }
    }

    const auto self_termination =
        kernel_result == darwin::mach::success && target &&
        target->first == process_.pid &&
        target->second == static_cast<std::uint32_t>(cpu.processor_id());
    output_.write("[thread] terminate caller=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(target ? target->first : 0U) +
                  ":" + std::to_string(target ? target->second : 0U) +
                  " result=" + std::to_string(kernel_result) + "\n");
    if (self_termination) {
        thread_ports_.erase(cpu.processor_id());
        end_thread_signals(cpu.processor_id());
        pending_mach_receives_.erase(cpu.processor_id());
        pending_psynch_waits_.erase(cpu.processor_id());
        cpu.registers()[0] = darwin::mach::success;
        cpu.halt(Umbra::HaltReason::UserDefined1);
        return true;
    }

    if (request.local_port == xnu::ipc::null_name) {
        cpu.registers()[0] = darwin::mach::success;
        return true;
    }
    const std::array<std::uint32_t, 9> reply {
        18,
        36,
        request.local_port,
        0,
        0,
        request.identifier + 100U,
        0,
        1,
        kernel_result,
    };
    for (std::size_t index = 0; index < reply.size(); ++index) {
        if (!memory_.write32(
                request.address + static_cast<std::uint32_t>(index * 4U),
                reply[index])) {
            cpu.registers()[0] = darwin::mach_message::receive_invalid_data;
            return true;
        }
    }
    cpu.registers()[0] = darwin::mach::success;
    return true;
}

} // namespace shade
