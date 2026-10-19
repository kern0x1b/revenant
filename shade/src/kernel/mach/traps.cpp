// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Route guest Mach traps for clocks, ports, semaphores and scheduler
// operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/syscall_sw.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/clock.c

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
#include "mach/mach_host_mig_ids.hpp"
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

void CompatibilityKernel::dispatch_mach(Cpu& cpu, std::uint32_t trap)
{
    if (shared_state_->darwin_abi.mach_kernel_rpc !=
            DarwinMachKernelRpcAbi::LegacyMigOnly) {
        if (dispatch_mach_vm_kernel_rpc_trap(cpu, trap) ||
            dispatch_mach_port_kernel_rpc_trap(cpu, trap)) {
            return;
        }
    }
    auto& registers = cpu.registers();
    switch (trap) {
    case 3: // iOS ARM fast trap: mach_absolute_time
    {
        const auto absolute_time = shared_state_->clock.now();
        registers[0] = static_cast<std::uint32_t>(absolute_time);
        registers[1] = static_cast<std::uint32_t>(absolute_time >> 32U);
    }
        return;
    case 33: { // semaphore_signal_trap
        std::optional<CompatibilityKernel::WokenThread> woken_thread;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            registers[0] = signal_semaphore_locked(
                registers[0], false, true, &woken_thread);
        }
        wake_thread_and_maybe_preempt(cpu, woken_thread);
        return;
    }
    case 34: { // semaphore_signal_all_trap
        std::vector<CompatibilityKernel::WokenThread> woken_threads;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            registers[0] = signal_semaphore_locked(
                registers[0], true, false, nullptr, &woken_threads);
        }
        wake_threads_and_maybe_preempt(cpu, woken_threads);
        return;
    }
    case 35: { // semaphore_signal_thread_trap
        std::optional<CompatibilityKernel::WokenThread> woken_thread;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            registers[0] = signal_semaphore_thread_locked(
                registers[0], registers[1], &woken_thread);
        }
        wake_thread_and_maybe_preempt(cpu, woken_thread);
        return;
    }
    case 36: // semaphore_wait_trap
        wait_on_semaphore(cpu, registers[0], 0, std::nullopt, false);
        return;
    case 37: // semaphore_wait_signal_trap
        wait_on_semaphore(cpu, registers[0], registers[1], std::nullopt, false);
        return;
    case 38: // semaphore_timedwait_trap
    case 39: { // semaphore_timedwait_signal_trap
        const auto nsec = trap == 38 ? registers[2] : registers[3];
        if (nsec >= 1'000'000'000U) {
            registers[0] = 4; // KERN_INVALID_ARGUMENT
            return;
        }
        const auto sec = trap == 38 ? registers[1] : registers[2];
        const auto interval =
            static_cast<std::uint64_t>(sec) * 1'000'000'000ULL + nsec;
        wait_on_semaphore(
            cpu, registers[0], trap == 39 ? registers[1] : 0, interval, false);
        return;
    }
    case 31: // mach_msg_trap
        dispatch_mach_message(cpu);
        return;
    case 32: // mach_msg_overwrite_trap: ARM passes argument eight in r8.
        dispatch_mach_message(cpu, registers[8] != 0U
                ? std::optional { registers[8] } : std::nullopt);
        return;
    case 26: { // mach_reply_port
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto port = shared_state_->allocate_mach_object();
        static_cast<void>(
            shared_state_->mach_port_objects.create(port, process_.pid));
        registers[0] =
            shared_state_->mach_namespaces
                .allocate(process_.pid, port,
                    xnu::ipc::type_mask(xnu::ipc::Right::Receive))
                .value_or(0);
        return;
    }
    case 27: // thread_self_trap
        dispatch_mach_thread_self_trap(cpu);
        return;
    case 28: // task_self_trap
        registers[0] = process_.task_port;
        return;
    case 29: // host_self_trap
        registers[0] = process_.host_port;
        return;
    case 44: { // task_name_for_pid(target_task, pid, task_name_out)
        constexpr std::uint32_t kern_failure = 5;
        const auto target_task = registers[0];
        const auto requested_pid = registers[1];
        const auto output_address = registers[2];
        std::uint32_t result_port = 0; // MACH_PORT_NULL on failure
        std::uint32_t result = kern_failure;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto caller_task_object =
                resolve_name_with_right(*shared_state_, process_.pid,
                    target_task, xnu::ipc::Right::Send);
            const auto caller_task =
                caller_task_object
                    ? shared_state_->task_port_pids.find(*caller_task_object)
                    : shared_state_->task_port_pids.end();
            const auto target_process =
                shared_state_->processes.find(requested_pid);
            if (caller_task != shared_state_->task_port_pids.end() &&
                caller_task->second == process_.pid &&
                target_process != shared_state_->processes.end() &&
                !target_process->second.exited &&
                (requested_pid == process_.pid || process_.effective_uid == 0 ||
                    (target_process->second.uid == process_.effective_uid &&
                        target_process->second.effective_uid ==
                            process_.effective_uid))) {
                auto task_name_port =
                    std::find_if(shared_state_->task_name_port_pids.begin(),
                        shared_state_->task_name_port_pids.end(),
                        [requested_pid](const auto& entry) {
                            return entry.second == requested_pid;
                        });
                if (task_name_port ==
                    shared_state_->task_name_port_pids.end()) {
                    const auto object = shared_state_->allocate_mach_object();
                    if (shared_state_->mach_port_objects.create(object)) {
                        task_name_port = shared_state_->task_name_port_pids
                                             .emplace(object, requested_pid)
                                             .first;
                    }
                }
                if (task_name_port !=
                    shared_state_->task_name_port_pids.end()) {
                    result_port =
                        shared_state_->mach_namespaces
                            .copyout(process_.pid, task_name_port->first,
                                xnu::ipc::type_mask(
                                    xnu::ipc::Right::Send))
                            .value_or(0);
                    if (result_port != 0)
                        result = 0; // KERN_SUCCESS
                }
            }
        }
        // XNU deliberately ignores copyout failure for these legacy traps.
        static_cast<void>(memory_.write32(output_address, result_port));
        registers[0] = result;
        return;
    }
    case 45: { // task_for_pid(target_task, pid, task_name_out)
        constexpr std::uint32_t kern_failure = 5;
        const auto target_task = registers[0];
        const auto requested_pid = registers[1];
        const auto output_address = registers[2];
        std::uint32_t result_port = 0; // MACH_PORT_NULL on failure
        std::uint32_t result = kern_failure;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto caller_task_object =
                resolve_name_with_right(*shared_state_, process_.pid,
                    target_task, xnu::ipc::Right::Send);
            const auto caller_task =
                caller_task_object
                    ? shared_state_->task_port_pids.find(*caller_task_object)
                    : shared_state_->task_port_pids.end();
            const auto target_process =
                shared_state_->processes.find(requested_pid);
            if (caller_task != shared_state_->task_port_pids.end() &&
                caller_task->second == process_.pid &&
                target_process != shared_state_->processes.end() &&
                !target_process->second.exited &&
                (requested_pid == process_.pid || process_.effective_uid == 0 ||
                    target_process->second.uid == process_.effective_uid)) {
                const auto task_port =
                    std::find_if(shared_state_->task_port_pids.begin(),
                        shared_state_->task_port_pids.end(),
                        [requested_pid](const auto& entry) {
                            return entry.second == requested_pid;
                        });
                if (task_port != shared_state_->task_port_pids.end()) {
                    result_port = shared_state_->mach_namespaces
                                      .copyout(process_.pid, task_port->first,
                                          xnu::ipc::type_mask(
                                              xnu::ipc::Right::Send))
                                      .value_or(0);
                    if (result_port != 0)
                        result = 0; // KERN_SUCCESS
                }
            }
        }
        // XNU deliberately ignores copyout failure for these legacy traps.
        static_cast<void>(memory_.write32(output_address, result_port));
        registers[0] = result;
        return;
    }
    case 46: { // pid_for_task(task_name, pid_out)
        constexpr std::uint32_t kern_failure = 5;
        const auto task_name = registers[0];
        const auto output_address = registers[1];
        std::uint32_t pid = std::numeric_limits<std::uint32_t>::max();
        std::uint32_t result = kern_failure;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto task_object = resolve_name_with_right(*shared_state_,
                process_.pid, task_name, xnu::ipc::Right::Send);
            if (const auto task =
                    task_object
                        ? shared_state_->task_port_pids.find(*task_object)
                        : shared_state_->task_port_pids.end();
                task != shared_state_->task_port_pids.end() &&
                shared_state_->processes.contains(task->second)) {
                pid = task->second;
                result = 0; // KERN_SUCCESS
            }
        }
        // Darwin 8 writes -1 even when port_name_to_task fails, and ignores a
        // copyout error when selecting the trap's return code.
        static_cast<void>(memory_.write32(output_address, pid));
        registers[0] = result;
        return;
    }
    case 89: { // mach_timebase_info_trap
        // absolute_time_ is expressed directly in nanoseconds.
        const auto address = registers[0];
        if (!memory_.write32(address, 1) || !memory_.write32(address + 4, 1)) {
            registers[0] = 1; // KERN_INVALID_ADDRESS
        } else {
            registers[0] = 0;
        }
        return;
    }
    case 90: { // mach_wait_until_trap
        // XNU passes the absolute deadline as a little-endian 64-bit
        // argument in r0/r1. Suspend only this guest thread; the cooperative
        // scheduler wakes it when virtual monotonic time reaches the deadline.
        const auto deadline = static_cast<std::uint64_t>(registers[0]) |
                              (static_cast<std::uint64_t>(registers[1]) << 32U);
        const auto now = shared_state_->clock.now();
        if (timer_trace_count_ < 8) {
            output_.write(
                "[timer] mach_wait_until pid=" + std::to_string(process_.pid) +
                " cpu=" + std::to_string(cpu.processor_id()) +
                " now=" + std::to_string(now) +
                " deadline=" + std::to_string(deadline) + "\n");
            ++timer_trace_count_;
        }
        registers[0] = 0; // KERN_SUCCESS
        if (deadline > now) {
            std::optional<PendingTimer::BootstrapRetry> bootstrap_retry;
            {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                const auto pending =
                    shared_state_->pending_bootstrap_retries.find(process_.pid);
                if (pending != shared_state_->pending_bootstrap_retries.end()) {
                    bootstrap_retry = std::move(pending->second);
                    shared_state_->pending_bootstrap_retries.erase(pending);
                }
            }
            // A missing service is not ready merely because launchd returned an
            // empty transfer. Keep a small retry floor; the scheduler will
            // still wake this timer early when the service generation advances.
            // Turning every failed lookup into an immediate wake creates a
            // guest-side busy loop for optional services such as
            // com.apple.musicplayer.
            constexpr std::uint64_t bootstrap_retry_backoff =
                100ULL * darwin::mach::scheduler::nanoseconds_per_millisecond;
            const auto effective_deadline =
                bootstrap_retry
                    ? std::max(deadline, now + bootstrap_retry_backoff)
                    : deadline;
            pending_timers_[cpu.processor_id()] =
                PendingTimer { effective_deadline,
                    PendingTimerKind::MachWaitUntil, std::nullopt, false,
                    std::move(bootstrap_retry) };
            process_.waiting_for_events = true;
            cpu.halt(Umbra::HaltReason::UserDefined5);
        }
        return;
    }
    case darwin::mach::scheduler::thread_switch_trap: {
        using namespace darwin::mach::scheduler;
        const auto thread_name = registers[0];
        const auto option = registers[1];
        const auto option_time_ms = registers[2];
        if (option > maximum_switch_option) {
            registers[0] = darwin::mach::invalid_argument;
            return;
        }

        std::optional<XnuThreadId> handoff_thread;
        if (thread_name != xnu::ipc::null_name) {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto object = resolve_name_with_right(*shared_state_,
                process_.pid, thread_name, xnu::ipc::Right::Send);
            const auto owner = object
                                   ? find_thread_owner(*shared_state_, *object)
                                   : std::nullopt;
            if (owner && (owner->first != process_.pid ||
                             owner->second != static_cast<std::uint32_t>(
                                                  cpu.processor_id()))) {
                handoff_thread = XnuThreadId { owner->first, owner->second };
            }
        }
        if (handoff_thread)
            scheduler_handoffs_[cpu.processor_id()] = *handoff_thread;

        registers[0] = darwin::mach::success;
        if (option == switch_option_wait && option_time_ms != 0) {
            const auto deadline = shared_state_->clock.now() +
                                  static_cast<std::uint64_t>(option_time_ms) *
                                      nanoseconds_per_millisecond;
            pending_timers_[cpu.processor_id()] =
                PendingTimer { deadline, PendingTimerKind::ThreadSwitch,
                    std::nullopt, false, std::nullopt };
            process_.waiting_for_events = true;
            cpu.halt(Umbra::HaltReason::UserDefined5);
            return;
        }

        // NONE and DEPRESS remain runnable, but XNU ends the current quantum.
        // UserDefined8 is the scheduler-only yield reason: main.cpp does not
        // move the thread to a wait queue and clears it on the next round.
        scheduler_yields_[cpu.processor_id()] =
            SchedulerYieldRequest { option == switch_option_depress,
                option_time_ms };
        cpu.halt(Umbra::HaltReason::UserDefined8);
        return;
    }
    case darwin::mach::clock::sleep_trap: {
        using namespace darwin::mach::clock;
        const auto clock_name = registers[0];
        const auto sleep_type = registers[1];
        const auto seconds = registers[2];
        const auto nanoseconds = registers[3];
        const auto wakeup_time_address = registers[4];

        bool calendar_clock = false;
        if (clock_name != null_clock_name) {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto object = shared_state_->mach_namespaces.resolve(
                process_.pid, clock_name);
            const auto system_object = shared_state_->mach_namespaces.resolve(
                process_.pid, process_.clock_port);
            const auto calendar_object = shared_state_->mach_namespaces.resolve(
                process_.pid, process_.calendar_clock_port);
            if (!object ||
                (object != system_object && object != calendar_object)) {
                registers[0] = darwin::mach::invalid_argument;
                return;
            }
            calendar_clock = object == calendar_object;
        }
        if (sleep_type > maximum_sleep_type ||
            nanoseconds >= nanoseconds_per_second) {
            registers[0] = darwin::mach::invalid_value;
            return;
        }

        const auto requested =
            static_cast<std::uint64_t>(seconds) * nanoseconds_per_second +
            nanoseconds;
        const auto monotonic_now = shared_state_->clock.now();
        const auto clock_now =
            calendar_clock ? shared_state_->clock.wall_time() : monotonic_now;
        auto alarm_time = requested;
        if (sleep_type == time_relative) {
            alarm_time = requested > std::numeric_limits<std::uint64_t>::max() -
                                         clock_now
                             ? std::numeric_limits<std::uint64_t>::max()
                             : clock_now + requested;
        }
        const auto remaining =
            alarm_time > clock_now ? alarm_time - clock_now : 0;
        const auto deadline =
            remaining >
                    std::numeric_limits<std::uint64_t>::max() - monotonic_now
                ? std::numeric_limits<std::uint64_t>::max()
                : monotonic_now + remaining;

        registers[0] = darwin::mach::success;
        if (alarm_time > clock_now) {
            pending_timers_[cpu.processor_id()] =
                PendingTimer { deadline, PendingTimerKind::ClockSleep,
                    wakeup_time_address, calendar_clock, std::nullopt };
            process_.waiting_for_events = true;
            cpu.halt(Umbra::HaltReason::UserDefined5);
            return;
        }

        const auto current_seconds =
            static_cast<std::uint32_t>(clock_now / nanoseconds_per_second);
        const auto current_nanoseconds =
            static_cast<std::uint32_t>(clock_now % nanoseconds_per_second);
        static_cast<void>(memory_.write32(
            wakeup_time_address + timespec_seconds_offset, current_seconds));
        static_cast<void>(
            memory_.write32(wakeup_time_address + timespec_nanoseconds_offset,
                current_nanoseconds));
        return;
    }
    case 91: { // mk_timer_create_trap
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto object = shared_state_->allocate_mach_object();
        shared_state_->mach_timers.emplace(object,
            KernelSharedState::MachTimer { process_.pid, std::nullopt });
        static_cast<void>(
            shared_state_->mach_port_objects.create(object, process_.pid));
        shared_state_->mach_queues.try_emplace(object);
        const auto name = shared_state_->mach_namespaces.allocate(process_.pid,
            object, xnu::ipc::type_mask(xnu::ipc::Right::Receive));
        if (!name) {
            shared_state_->mach_timers.erase(object);
            remove_port_object_locked(*shared_state_, object);
            registers[0] = xnu::ipc::null_name;
            return;
        }
        registers[0] = *name;
        output_.write("[timer] create pid=" + std::to_string(process_.pid) +
                      " name=" + std::to_string(*name) +
                      " object=" + std::to_string(object) + "\n");
        return;
    }
    case 92: { // mk_timer_destroy_trap
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto name = registers[0];
        const auto object = resolve_name_with_right(
            *shared_state_, process_.pid, name, xnu::ipc::Right::Receive);
        const auto timer = object ? shared_state_->mach_timers.find(*object)
                                  : shared_state_->mach_timers.end();
        if (timer == shared_state_->mach_timers.end()) {
            registers[0] = darwin::mach::invalid_argument;
            return;
        }
        shared_state_->mach_timers.erase(timer);
        // Tear down the task-local receive name through the common ipc_right
        // path. It marks foreign Send names dead and drains queued rights
        // before removing the backing timer port.
        registers[0] =
            destroy_port_name_locked(*shared_state_, process_.pid, name)
                ? darwin::mach::success
                : darwin::mach::invalid_argument;
        return;
    }
    case 93: { // mk_timer_arm_trap
        const auto name = registers[0];
        const auto deadline = static_cast<std::uint64_t>(registers[1]) |
                              (static_cast<std::uint64_t>(registers[2]) << 32U);
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto object = resolve_name_with_right(
            *shared_state_, process_.pid, name, xnu::ipc::Right::Receive);
        const auto timer = object ? shared_state_->mach_timers.find(*object)
                                  : shared_state_->mach_timers.end();
        if (timer == shared_state_->mach_timers.end()) {
            registers[0] = darwin::mach::invalid_argument;
            return;
        }
        timer->second.deadline = deadline;
        registers[0] = darwin::mach::success;
        output_.write("[timer] arm pid=" + std::to_string(process_.pid) +
                      " name=" + std::to_string(name) +
                      " object=" + std::to_string(*object) +
                      " deadline=" + std::to_string(deadline) + "\n");
        return;
    }
    case 94: { // mk_timer_cancel_trap
        const auto name = registers[0];
        const auto result_address = registers[1];
        std::uint64_t armed_time = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto object = resolve_name_with_right(*shared_state_,
                process_.pid, name, xnu::ipc::Right::Receive);
            const auto timer = object ? shared_state_->mach_timers.find(*object)
                                      : shared_state_->mach_timers.end();
            if (timer == shared_state_->mach_timers.end()) {
                registers[0] = darwin::mach::invalid_argument;
                return;
            }
            armed_time = timer->second.deadline.value_or(0);
            timer->second.deadline.reset();
        }
        if (result_address != 0 &&
            (!memory_.write32(
                 result_address, static_cast<std::uint32_t>(armed_time)) ||
                !memory_.write32(result_address + 4,
                    static_cast<std::uint32_t>(armed_time >> 32U)))) {
            registers[0] = darwin::mach::failure;
        } else {
            registers[0] = darwin::mach::success;
        }
        return;
    }
    case 41: // init_process
        registers[0] = 0; // KERN_SUCCESS / boolean false for swtch
        return;
    case darwin::mach::scheduler::swtch_pri_trap: {
        const auto should_yield = scheduler_runnable_query_ &&
                                  scheduler_runnable_query_(cpu.processor_id());
        if (!should_yield) {
            registers[0] = 0;
            return;
        }
        const auto quantum_milliseconds = static_cast<std::uint32_t>(
            xnu::scheduler::milliseconds_per_second /
            xnu::scheduler::default_preemption_rate);
        scheduler_yields_[cpu.processor_id()] =
            SchedulerYieldRequest { true, quantum_milliseconds };
        registers[0] = 1;
        cpu.halt(Umbra::HaltReason::UserDefined8);
        return;
    }
    case darwin::mach::scheduler::swtch_trap: {
        const auto should_yield = scheduler_runnable_query_ &&
                                  scheduler_runnable_query_(cpu.processor_id());
        if (!should_yield) {
            registers[0] = 0;
            return;
        }
        scheduler_yields_[cpu.processor_id()] =
            SchedulerYieldRequest { false, 0 };
        registers[0] = 1;
        cpu.halt(Umbra::HaltReason::UserDefined8);
        return;
    }
    default:
        trace_unknown(cpu, "Mach trap", trap);
        registers[0] = 4; // KERN_INVALID_ARGUMENT
        return;
    }
}

} // namespace shade
