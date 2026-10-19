// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest signal masks, actions, delivery and thread
// interruption.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_sig.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "../../mach/support.hpp"
#include <algorithm>
#include <cstdint>
#include <vector>

#include "../support.hpp"

namespace shade {
namespace {

    bool default_signal_is_ignored(std::uint32_t signal)
    {
        using namespace darwin::signal;
        return signal == urgent || signal == child || signal == io ||
               signal == window_change || signal == information ||
               signal == resume;
    }

    bool default_signal_stops(std::uint32_t signal)
    {
        using namespace darwin::signal;
        return signal == stop || signal == terminal_stop ||
               signal == terminal_input || signal == terminal_output;
    }

} // namespace

std::uint32_t CompatibilityKernel::deliver_signal(std::uint32_t signal)
{
    if (signal == 0 || signal >= darwin::signal::count) {
        return signal == 0 ? 0U : darwin::error::invalid_argument;
    }

    const auto transition_job_control_stop = [this](bool stopped) {
        bool changed = false;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto record = shared_state_->processes.find(process_.pid);
            if (record != shared_state_->processes.end() &&
                !record->second.exited &&
                record->second.signal_stopped != stopped) {
                record->second.signal_stopped = stopped;
                changed = true;
            }
        }
        if (changed && process_runnable_handler_)
            process_runnable_handler_(process_.pid, !stopped);
        return changed;
    };

    // POSIX job control resumes a stopped task even when SIGCONT is ignored,
    // caught, or masked. Handler disposition is evaluated only after the
    // independent scheduler hold has been released.
    if (signal == darwin::signal::resume &&
        transition_job_control_stop(false)) {
        output_.write(
            "[signal] continued pid=" + std::to_string(process_.pid) + "\n");
    }

    const auto handler = signal_actions_[signal][0];
    const bool unmaskable =
        signal == darwin::signal::kill || signal == darwin::signal::stop;
    const auto suspended = std::find_if(pending_signal_suspends_.begin(),
        pending_signal_suspends_.end(), [&](const auto& pending) {
            return unmaskable ||
                   (pending.second.mask & (1U << (signal - 1U))) == 0;
        });
    if (!unmaskable && handler == darwin::signal::ignore_action) {
        output_.write("[signal] ignored pid=" + std::to_string(process_.pid) +
                      " signal=" + std::to_string(signal) + "\n");
        return 0;
    }
    if (!unmaskable && handler != darwin::signal::default_action) {
        // A thread runs the handler on its way back to user mode
        // (deliver_pending_signals).
        pending_signals_ |= 1U << (signal - 1U);
        output_.write(
            "[signal] caught-pending pid=" + std::to_string(process_.pid) +
            " signal=" + std::to_string(signal) + "\n");
        if (suspended != pending_signal_suspends_.end()) {
            suspended->second.interrupted = true;
            shared_state_->note_io_event_transition();
        }
        return 0;
    }
    // A signal sent to the process waits only while every thread blocks it.
    const auto bit = 1U << (signal - 1U);
    const bool blocked_everywhere = !thread_signal_masks_.empty() &&
        std::all_of(thread_signal_masks_.begin(), thread_signal_masks_.end(),
            [bit](const auto& thread) { return (thread.second & bit) != 0U; });
    if (!unmaskable && blocked_everywhere) {
        // Blocked: it waits until a mask lets it through.
        pending_signals_ |= 1U << (signal - 1U);
        output_.write(
            "[signal] masked-pending pid=" + std::to_string(process_.pid) +
            " signal=" + std::to_string(signal) + "\n");
        return 0;
    }
    if (default_signal_is_ignored(signal)) {
        return 0;
    }
    if (default_signal_stops(signal)) {
        const auto changed = transition_job_control_stop(true);
        output_.write("[signal] " +
                      std::string { changed ? "stopped" : "already-stopped" } +
                      " pid=" + std::to_string(process_.pid) +
                      " signal=" + std::to_string(signal) + "\n");
        return 0;
    }

    exit_process(0, signal);
    return 0;
}

void CompatibilityKernel::dispatch_bsd_signal(Cpu& cpu, std::uint32_t number)
{
    if (number == 184U) {
        dispatch_sigreturn(cpu);
        return;
    }
    if (number == 53U) {
        dispatch_sigaltstack(cpu);
        return;
    }
    if (number == 111U) { // sigsuspend
        constexpr std::uint32_t unblockable =
            (1U << (darwin::signal::kill - 1U)) |
            (1U << (darwin::signal::stop - 1U));
        pending_signal_suspends_[cpu.processor_id()] =
            PendingSignalSuspend { cpu.registers()[0] & ~unblockable, false };
        process_.waiting_for_events = true;
        output_.write("[signal] suspend pid=" + std::to_string(process_.pid) +
                      " cpu=" + std::to_string(cpu.processor_id()) + "\n");
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return;
    }
    if (number == darwin::syscall::pthread_kill) {
        const auto thread_name = cpu.registers()[0];
        const auto signal = cpu.registers()[1];
        if (signal >= darwin::signal::count) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        std::optional<std::pair<std::uint32_t, std::uint32_t>> target;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto object = mach_support::resolve_name_with_right(
                *shared_state_, process_.pid, thread_name,
                xnu::ipc::Right::Send);
            if (object)
                target = mach_support::find_thread_owner(*shared_state_, *object);
        }
        // pthread_t is represented by the target thread's send right. POSIX
        // limits pthread_kill to threads in the caller's process; signal zero
        // performs only this liveness check.
        if (!target || target->first != process_.pid) {
            bsd_error(cpu, darwin::error::no_such_process);
            return;
        }
        if (signal != 0) {
            // pthread_kill directs the signal at one thread: only it takes a
            // caught or blocked one; a default action is the process's.
            const auto slot = static_cast<std::size_t>(target->second);
            const auto handler = signal_actions_[signal][0];
            const bool caught = handler != darwin::signal::default_action &&
                                handler != darwin::signal::ignore_action;
            const bool blocked =
                (signal_mask(slot) & (1U << (signal - 1U))) != 0U;
            if ((caught || blocked) && signal != darwin::signal::kill &&
                signal != darwin::signal::stop) {
                thread_pending_signals_[slot] |= 1U << (signal - 1U);
            } else {
                const auto error = deliver_signal(signal);
                if (error != 0) {
                    bsd_error(cpu, error);
                    return;
                }
            }
        }
        bsd_success(cpu, 0);
        if (process_.exited)
            cpu.halt(Umbra::HaltReason::UserDefined1);
        else
            deliver_pending_signals(cpu);
        return;
    }
    if (number != darwin::syscall::kill) {
        trace_unknown(cpu, "BSD signal syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }

    const auto requested_pid = static_cast<std::int32_t>(cpu.registers()[0]);
    const auto signal = cpu.registers()[1];
    if (signal >= darwin::signal::count) {
        bsd_error(cpu, darwin::error::invalid_argument);
        return;
    }

    std::vector<std::uint32_t> targets;
    if (requested_pid > 0) {
        targets.push_back(static_cast<std::uint32_t>(requested_pid));
    } else {
        const auto requested_group =
            requested_pid == 0 ? process_.process_group
                               : static_cast<std::uint32_t>(
                                     -static_cast<std::int64_t>(requested_pid));
        for (const auto& [pid, record] : shared_state_->processes) {
            if (record.exited) {
                continue;
            }
            if (requested_pid == -1) {
                if (pid <= 1 || pid == process_.pid) {
                    continue;
                }
            } else if (record.process_group != requested_group) {
                continue;
            }
            targets.push_back(pid);
        }
    }

    bool found = false;
    bool permitted = false;
    for (const auto target_pid : targets) {
        const auto target = shared_state_->processes.find(target_pid);
        if (target == shared_state_->processes.end()) {
            continue;
        }
        found = true;
        if (target->second.exited) {
            permitted = true;
            continue;
        }
        if (process_.effective_uid != 0 &&
            process_.effective_uid != target->second.uid) {
            continue;
        }
        permitted = true;
        if (signal == 0) {
            continue;
        }
        if (target_pid != process_.pid &&
            (signal == darwin::signal::kill || signal == 15U)) {
            // Which process ended another one is the first thing a failed run
            // asks, and a guest that is killed leaves no other trace.
            output_.write("[signal] sent pid=" +
                std::to_string(process_.pid) + " target=" +
                std::to_string(target_pid) + " signal=" +
                std::to_string(signal) + "\n");
        }
        const auto error = signal_delivery_handler_
                               ? signal_delivery_handler_(target_pid, signal)
                           : target_pid == process_.pid
                               ? deliver_signal(signal)
                               : darwin::error::no_such_process;
        if (error != 0) {
            bsd_error(cpu, error);
            return;
        }
    }

    if (!found) {
        bsd_error(cpu, darwin::error::no_such_process);
        return;
    }
    if (!permitted) {
        bsd_error(cpu, darwin::error::operation_not_permitted);
        return;
    }
    bsd_success(cpu, 0);
    if (process_.exited) {
        cpu.halt(Umbra::HaltReason::UserDefined1);
    } else if (std::find(targets.begin(), targets.end(), process_.pid) !=
               targets.end()) {
        bool signal_stopped = false;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto record = shared_state_->processes.find(process_.pid);
            signal_stopped = record != shared_state_->processes.end() &&
                             record->second.signal_stopped;
        }
        if (signal_stopped)
            cpu.request_guest_preemption();
        else
            deliver_pending_signals(cpu);
    }
}

} // namespace shade
