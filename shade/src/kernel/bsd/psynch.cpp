// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Decode Darwin pthread synchronization syscalls and block or wake
// guest threads.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/kern/pthread_support.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_psynch_runtime.hpp"
#include "kernel/mach_clock_abi.hpp"

#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "../mach/support.hpp"
#include "support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t maximum_psynch_traces = 512U;
    constexpr std::uint32_t mutex_object_flag = 0x2000U;

    std::uint64_t joined_words(std::uint32_t low, std::uint32_t high)
    {
        return low | (static_cast<std::uint64_t>(high) << 32U);
    }

    // ARM32's generated syscall veneer loads argument words four through six
    // into r4-r6 after preserving those registers plus r8. Remaining words
    // stay in the original caller stack, 16 bytes above the veneer stack.
    std::optional<std::uint32_t> arm32_overflow_argument(
        AddressSpace& memory, const Cpu& cpu, std::uint32_t argument_index)
    {
        if (argument_index < 7U)
            return std::nullopt;
        constexpr std::uint32_t saved_register_bytes = 4U * 4U;
        const auto offset64 =
            static_cast<std::uint64_t>(saved_register_bytes) +
            static_cast<std::uint64_t>(argument_index - 4U) * 4U;
        const auto stack = cpu.registers()[13];
        if (offset64 > std::numeric_limits<std::uint32_t>::max() - stack)
            return std::nullopt;
        return memory.read32(stack + static_cast<std::uint32_t>(offset64));
    }

    std::string psynch_kind_name(DarwinPsynchWaitKind kind)
    {
        switch (kind) {
        case DarwinPsynchWaitKind::Mutex:
            return "mutex";
        case DarwinPsynchWaitKind::Condition:
            return "condition";
        case DarwinPsynchWaitKind::ReadLock:
            return "rw-read";
        case DarwinPsynchWaitKind::WriteLock:
            return "rw-write";
        }
        return "unknown";
    }

} // namespace

void CompatibilityKernel::dispatch_bsd_psynch(Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    const DarwinPsynchThread current_thread { process_.pid,
        static_cast<std::uint32_t>(cpu.processor_id()) };
    const auto wake_threads = [&](std::span<const DarwinPsynchThread> threads) {
        std::vector<WokenThread> scheduler_threads;
        scheduler_threads.reserve(threads.size());
        for (const auto& thread : threads) {
            scheduler_threads.emplace_back(
                thread.process_id, thread.processor);
        }
        wake_threads_and_maybe_preempt(cpu, scheduler_threads);
    };
    const auto begin_wait = [&](DarwinPsynchRuntime::WaitOutcome outcome,
                                std::uint32_t address,
                                DarwinPsynchWaitKind kind,
                                std::optional<std::uint64_t> deadline =
                                    std::nullopt) {
        wake_threads(outcome.woken_threads);
        if (!outcome.blocked) {
            bsd_success(cpu, outcome.result);
            return;
        }
        pending_psynch_waits_.insert_or_assign(cpu.processor_id(),
            PendingPsynchWait { address, kind, cpu.processor_id(), deadline });
        process_.waiting_for_events = true;
        if (psynch_trace_count_ < maximum_psynch_traces) {
            output_.write("[psynch] wait pid=" +
                          std::to_string(process_.pid) + " slot=" +
                          std::to_string(cpu.processor_id()) + " kind=" +
                          psynch_kind_name(kind) + " address=" +
                          std::to_string(address) + "\n");
            ++psynch_trace_count_;
        }
        cpu.halt(Umbra::HaltReason::UserDefined5);
    };
    const auto trace_rw = [&](std::string_view phase,
                              std::span<const DarwinPsynchThread> woken = { },
                              std::uint32_t result = 0U) {
        if (psynch_trace_count_ >= maximum_psynch_traces)
            return;
        const auto word0 = memory_.read32(registers[0]).value_or(0U);
        const auto word1 = memory_.read32(registers[0] + 4U).value_or(0U);
        const auto word2 = memory_.read32(registers[0] + 8U).value_or(0U);
        output_.line("[psynch-rw-diag] phase=" + std::string { phase } +
                     " call=" + std::to_string(number) + " pid=" +
                     std::to_string(process_.pid) + " slot=" +
                     std::to_string(cpu.processor_id()) + " address=" +
                     std::to_string(registers[0]) + " lgen=" +
                     std::to_string(registers[1]) + " ugen=" +
                     std::to_string(registers[2]) + " rw_wc=" +
                     std::to_string(registers[3]) + " flags=" +
                     std::to_string(registers[4]) + " words=" +
                     std::to_string(word0) + "," +
                     std::to_string(word1) + "," +
                     std::to_string(word2) + " result=" +
                     std::to_string(result) + " woken=" +
                     std::to_string(woken.size()));
        ++psynch_trace_count_;
    };
    switch (number) {
    case 297: // psynch_rw_longrdlock
    case 306: { // psynch_rw_rdlock
        trace_rw("wait-enter");
        auto outcome = shared_state_->psynch_runtime->wait_rwlock(current_thread,
            registers[0], registers[1], registers[2], registers[3], registers[4],
            DarwinPsynchWaitKind::ReadLock);
        begin_wait(std::move(outcome),
            registers[0], DarwinPsynchWaitKind::ReadLock);
        return;
    }
    case 298: // psynch_rw_yieldwrlock
    case 300: // psynch_rw_upgrade
    case 307: { // psynch_rw_wrlock
        trace_rw("wait-enter");
        auto outcome = shared_state_->psynch_runtime->wait_rwlock(current_thread,
            registers[0], registers[1], registers[2], registers[3], registers[4],
            DarwinPsynchWaitKind::WriteLock);
        begin_wait(std::move(outcome),
            registers[0], DarwinPsynchWaitKind::WriteLock);
        return;
    }
    case 299: { // psynch_rw_downgrade
        trace_rw("unlock-enter");
        auto outcome = shared_state_->psynch_runtime->unlock_rwlock(
            process_.pid, registers[0], registers[1], registers[2],
            registers[3], registers[4]);
        trace_rw("unlock-return", outcome.woken_threads, outcome.result);
        wake_threads(outcome.woken_threads);
        bsd_success(cpu, outcome.result);
        return;
    }
    case 301: { // psynch_mutexwait
        const auto outcome = shared_state_->psynch_runtime->wait_mutex(
            current_thread, registers[0], registers[1], registers[2],
            registers[5]);
        if (outcome.blocked && process_image_.ends_with("/assetsd")) {
            const auto word0 = memory_.read32(registers[0]).value_or(0U);
            const auto word1 = memory_.read32(registers[0] + 4U).value_or(0U);
            const auto word2 = memory_.read32(registers[0] + 8U).value_or(0U);
            const auto word3 = memory_.read32(registers[0] + 12U).value_or(0U);
            output_.line("[perf] assetsd psynch_mutexwait pid=" +
                         std::to_string(process_.pid) + " slot=" +
                         std::to_string(cpu.processor_id()) + " address=" +
                         std::to_string(registers[0]) + " mgen=" +
                         std::to_string(registers[1]) + " ugen=" +
                         std::to_string(registers[2]) + " flags=" +
                         std::to_string(registers[5]) + " words=" +
                         std::to_string(word0) + "," +
                         std::to_string(word1) + "," +
                         std::to_string(word2) + "," +
                         std::to_string(word3));
        }
        begin_wait(std::move(outcome),
            registers[0], DarwinPsynchWaitKind::Mutex);
        return;
    }
    case 302: { // psynch_mutexdrop
        auto outcome = shared_state_->psynch_runtime->drop_mutex(process_.pid,
            registers[0], registers[1], registers[2], registers[5]);
        wake_threads(outcome.woken_threads);
        bsd_success(cpu, outcome.result);
        return;
    }
    case 303: { // psynch_cvbroad
        auto outcome = shared_state_->psynch_runtime->broadcast_condition(
            process_.pid, registers[0], joined_words(registers[1], registers[2]),
            joined_words(registers[3], registers[4]), registers[5]);
        wake_threads(outcome.woken_threads);
        bsd_success(cpu, outcome.result);
        return;
    }
    case 304: { // psynch_cvsignal
        const auto flags = arm32_overflow_argument(memory_, cpu, 10U);
        if (!flags) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::optional<DarwinPsynchThread> target;
        if (registers[4] != 0U) {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            if (const auto object = mach_support::resolve_name_with_right(
                    *shared_state_, process_.pid, registers[4],
                    xnu::ipc::Right::Send)) {
                if (const auto owner =
                        mach_support::find_thread_owner(*shared_state_, *object)) {
                    target = DarwinPsynchThread { owner->first, owner->second };
                }
            }
            if (!target) {
                bsd_error(cpu, darwin::error::no_such_process);
                return;
            }
        }
        auto outcome = shared_state_->psynch_runtime->signal_condition(
            process_.pid, registers[0], joined_words(registers[1], registers[2]),
            registers[3], *flags, target);
        wake_threads(outcome.woken_threads);
        bsd_success(cpu, outcome.result);
        return;
    }
    case 305: { // psynch_cvwait
        const auto flags = arm32_overflow_argument(memory_, cpu, 7U);
        const auto seconds_low = arm32_overflow_argument(memory_, cpu, 8U);
        const auto seconds_high = arm32_overflow_argument(memory_, cpu, 9U);
        const auto nanoseconds = arm32_overflow_argument(memory_, cpu, 10U);
        if (!flags || !seconds_low || !seconds_high || !nanoseconds) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto seconds = static_cast<std::int64_t>(
            joined_words(*seconds_low, *seconds_high));
        if (seconds < 0 ||
            *nanoseconds >= darwin::mach::clock::nanoseconds_per_second) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        std::optional<std::uint64_t> deadline;
        if (seconds != 0 || *nanoseconds != 0U) {
            constexpr auto nanoseconds_per_second =
                darwin::mach::clock::nanoseconds_per_second;
            const auto seconds64 = static_cast<std::uint64_t>(seconds);
            const auto maximum_interval =
                std::numeric_limits<std::uint64_t>::max() - *nanoseconds;
            const auto interval =
                seconds64 > maximum_interval / nanoseconds_per_second
                    ? std::numeric_limits<std::uint64_t>::max()
                    : seconds64 * nanoseconds_per_second + *nanoseconds;
            const auto now = shared_state_->clock.now();
            deadline = interval > std::numeric_limits<std::uint64_t>::max() - now
                           ? std::numeric_limits<std::uint64_t>::max()
                           : now + interval;
        }
        const auto mutex_drop = registers[4] == 0U
                                    ? std::optional<
                                          DarwinPsynchRuntime::MutexDrop> { }
                                    : DarwinPsynchRuntime::MutexDrop {
                                          registers[4], registers[5],
                                          registers[6] };
        begin_wait(shared_state_->psynch_runtime->wait_condition(current_thread,
                       registers[0], joined_words(registers[1], registers[2]),
                       registers[3], mutex_drop, *flags),
            registers[0], DarwinPsynchWaitKind::Condition, deadline);
        return;
    }
    case 308: // psynch_rw_unlock
    case 309: { // psynch_rw_unlock2
        trace_rw("unlock-enter");
        auto outcome = shared_state_->psynch_runtime->unlock_rwlock(
            process_.pid, registers[0], registers[1], registers[2],
            registers[3], registers[4]);
        trace_rw("unlock-return", outcome.woken_threads, outcome.result);
        wake_threads(outcome.woken_threads);
        bsd_success(cpu, outcome.result);
        return;
    }
    case 312: { // psynch_cvclrprepost
        const auto flags = registers[6];
        shared_state_->psynch_runtime->clear_preposts(process_.pid,
            registers[0], flags, (flags & mutex_object_flag) != 0U);
        bsd_success(cpu, 0);
        return;
    }
    default:
        bsd_error(cpu, bsd_support::invalid_argument);
        return;
    }
}

} // namespace shade
