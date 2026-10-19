// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest interval-timer syscalls and expired timer signals.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_time.c

#include "kernel/kernel_bsd_interval_timer.hpp"

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "foundation/output.hpp"
#include "foundation/virtual_clock.hpp"

#include "../support.hpp"

#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <string>

namespace shade::kernel_bsd::interval_timer {
namespace {

    constexpr std::uint32_t real_timer = 0;
    constexpr std::uint32_t seconds_offset = 0;
    constexpr std::uint32_t microseconds_offset = 4;
    constexpr std::uint32_t time_value_size = 8;
    constexpr std::uint32_t interval_offset = 0;
    constexpr std::uint32_t value_offset = time_value_size;
    constexpr std::uint32_t timer_value_size = 2U * time_value_size;
    constexpr std::uint64_t nanoseconds_per_microsecond = 1'000ULL;
    constexpr std::uint64_t microseconds_per_second = 1'000'000ULL;

    struct TimerValue {
        std::uint64_t interval { };
        std::uint64_t value { };
    };

    void set_success(Cpu& cpu)
    {
        cpu.registers()[0] = 0U;
        cpu.registers()[1] = 0U;
        cpu.set_cpsr(cpu.cpsr() & ~bsd_support::carry_flag);
    }

    void set_error(Cpu& cpu, std::uint32_t error)
    {
        cpu.registers()[0] = error;
        cpu.set_cpsr(cpu.cpsr() | bsd_support::carry_flag);
    }

    std::optional<std::uint64_t> read_time_value(
        const AddressSpace& memory, std::uint32_t address)
    {
        if (address >
            std::numeric_limits<std::uint32_t>::max() - time_value_size + 1U) {
            return std::nullopt;
        }
        const auto raw_seconds = memory.read32(address + seconds_offset);
        const auto raw_microseconds =
            memory.read32(address + microseconds_offset);
        if (!raw_seconds || !raw_microseconds)
            return std::nullopt;
        const auto seconds = static_cast<std::int32_t>(*raw_seconds);
        const auto microseconds = static_cast<std::int32_t>(*raw_microseconds);
        if (seconds < 0 || microseconds < 0 ||
            microseconds >=
                static_cast<std::int32_t>(microseconds_per_second)) {
            return std::nullopt;
        }
        return static_cast<std::uint64_t>(seconds) *
                   VirtualClock::nanoseconds_per_second +
               static_cast<std::uint64_t>(microseconds) *
                   nanoseconds_per_microsecond;
    }

    std::optional<TimerValue> read_timer_value(
        const AddressSpace& memory, std::uint32_t address)
    {
        if (address == 0U ||
            address > std::numeric_limits<std::uint32_t>::max() -
                          timer_value_size + 1U) {
            return std::nullopt;
        }
        const auto interval =
            read_time_value(memory, address + interval_offset);
        const auto value = read_time_value(memory, address + value_offset);
        if (!interval || !value)
            return std::nullopt;
        return TimerValue { *interval, *value };
    }

    bool write_time_value(
        AddressSpace& memory, std::uint32_t address, std::uint64_t nanoseconds)
    {
        const auto seconds = nanoseconds / VirtualClock::nanoseconds_per_second;
        const auto microseconds =
            (nanoseconds % VirtualClock::nanoseconds_per_second) /
            nanoseconds_per_microsecond;
        if (seconds > static_cast<std::uint64_t>(
                          std::numeric_limits<std::int32_t>::max())) {
            return false;
        }
        return memory.write32(address + seconds_offset,
                   static_cast<std::uint32_t>(seconds)) &&
               memory.write32(address + microseconds_offset,
                   static_cast<std::uint32_t>(microseconds));
    }

    bool write_timer_value(
        AddressSpace& memory, std::uint32_t address, const TimerValue& timer)
    {
        if (address == 0U ||
            address > std::numeric_limits<std::uint32_t>::max() -
                          timer_value_size + 1U) {
            return false;
        }
        return write_time_value(
                   memory, address + interval_offset, timer.interval) &&
               write_time_value(memory, address + value_offset, timer.value);
    }

    TimerValue current_value(
        const KernelSharedState::ProcessIntervalTimer& timer, std::uint64_t now)
    {
        return TimerValue { timer.interval,
            timer.deadline && *timer.deadline > now ? *timer.deadline - now
                                                    : 0U };
    }

    std::optional<std::uint64_t> deadline_after(
        std::uint64_t now, std::uint64_t duration)
    {
        if (duration == 0U)
            return std::nullopt;
        if (duration > std::numeric_limits<std::uint64_t>::max() - now)
            return std::numeric_limits<std::uint64_t>::max();
        return now + duration;
    }

} // namespace

bool dispatch(Cpu& cpu, AddressSpace& memory, Output& output,
    KernelSharedState& state, const ProcessContext& process,
    std::uint32_t syscall_number)
{
    if (syscall_number != set_syscall && syscall_number != get_syscall)
        return false;

    const auto& registers = cpu.registers();
    if (registers[0] != real_timer) {
        set_error(cpu, darwin::error::invalid_argument);
        return true;
    }
    const auto now = state.clock.now();

    if (syscall_number == get_syscall) {
        std::lock_guard lock { state.mach_mutex };
        const auto timer = state.process_interval_timers.find(process.pid);
        const auto value = timer == state.process_interval_timers.end()
                               ? TimerValue { }
                               : current_value(timer->second, now);
        if (!write_timer_value(memory, registers[1], value)) {
            set_error(cpu, darwin::error::bad_address);
            return true;
        }
        set_success(cpu);
        return true;
    }

    const auto requested = read_timer_value(memory, registers[1]);
    if (!requested) {
        set_error(cpu, registers[1] == 0U ? darwin::error::bad_address
                                          : darwin::error::invalid_argument);
        return true;
    }
    {
        std::lock_guard lock { state.mach_mutex };
        auto& timer = state.process_interval_timers[process.pid];
        if (registers[2] != 0U && !write_timer_value(memory, registers[2],
                                      current_value(timer, now))) {
            set_error(cpu, darwin::error::bad_address);
            return true;
        }
        timer.interval = requested->interval;
        timer.deadline = deadline_after(now, requested->value);
    }
    output.write("[interval-timer] set pid=" + std::to_string(process.pid) +
                 " value-ns=" + std::to_string(requested->value) +
                 " interval-ns=" + std::to_string(requested->interval) + "\n");
    set_success(cpu);
    return true;
}

std::optional<std::uint64_t> next_deadline(
    KernelSharedState& state, std::uint32_t process_id)
{
    std::lock_guard lock { state.mach_mutex };
    const auto timer = state.process_interval_timers.find(process_id);
    return timer == state.process_interval_timers.end()
               ? std::nullopt
               : timer->second.deadline;
}

bool service_due(KernelSharedState& state, std::uint32_t process_id,
    std::uint64_t serviced_deadline)
{
    std::lock_guard lock { state.mach_mutex };
    const auto timer = state.process_interval_timers.find(process_id);
    if (timer == state.process_interval_timers.end() ||
        !timer->second.deadline ||
        *timer->second.deadline > serviced_deadline) {
        return false;
    }

    if (timer->second.interval == 0U) {
        timer->second.deadline.reset();
        return true;
    }

    const auto current = *timer->second.deadline;
    const auto elapsed = serviced_deadline - current;
    const auto periods = elapsed / timer->second.interval + 1U;
    if (periods > (std::numeric_limits<std::uint64_t>::max() - current) /
                      timer->second.interval) {
        timer->second.deadline = std::numeric_limits<std::uint64_t>::max();
    } else {
        timer->second.deadline = current + periods * timer->second.interval;
    }
    return true;
}

void retire_process(KernelSharedState& state, std::uint32_t process_id)
{
    std::lock_guard lock { state.mach_mutex };
    state.process_interval_timers.erase(process_id);
}

} // namespace shade::kernel_bsd::interval_timer
