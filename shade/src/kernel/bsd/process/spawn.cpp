// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Decode guest posix_spawn attributes and schedule child process
// creation.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1228.15.4/bsd/kern/kern_exec.c

#include "kernel/graphics_services_input.hpp"
#include "kernel/kernel.hpp"
#include "foundation/performance.hpp"

#include <cstdint>
#include <filesystem>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

#include "../support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t posix_spawn_syscall = 244U;
    constexpr std::uint16_t posix_spawn_setexec = 0x0040U;
    constexpr std::uint16_t posix_spawn_start_suspended = 0x0080U;
    constexpr std::uint32_t maximum_vector_entries = 4096U;
    constexpr std::uint32_t maximum_string_size = 64U * 1024U;

    struct PosixSpawnAttributes {
        bool setexec { };
        bool start_suspended { };
    };

    std::optional<std::vector<std::string>> read_string_vector(
        const AddressSpace& memory, std::uint32_t address)
    {
        std::vector<std::string> values;
        if (address == 0)
            return values;
        for (std::uint32_t index = 0; index < maximum_vector_entries; ++index) {
            const auto pointer = memory.read32(address + index * 4U);
            if (!pointer)
                return std::nullopt;
            if (*pointer == 0)
                return values;
            const auto value =
                memory.read_c_string(*pointer, maximum_string_size);
            if (!value)
                return std::nullopt;
            values.push_back(*value);
        }
        return std::nullopt;
    }

    std::optional<PosixSpawnAttributes> read_spawn_attributes(
        const AddressSpace& memory, std::uint32_t address)
    {
        PosixSpawnAttributes result;
        if (address == 0)
            return result;

        const auto attribute_size = memory.read32(address);
        const auto attribute_address = memory.read32(address + 4U);
        if (!attribute_size || !attribute_address) {
            return std::nullopt;
        }
        if (*attribute_size >= sizeof(std::uint16_t) &&
            *attribute_address != 0) {
            const auto flags = memory.read16(*attribute_address);
            if (!flags)
                return std::nullopt;
            result.setexec = (*flags & posix_spawn_setexec) != 0;
            result.start_suspended =
                (*flags & posix_spawn_start_suspended) != 0;
        }
        return result;
    }

} // namespace

bool CompatibilityKernel::dispatch_bsd_process_spawn(
    Cpu& cpu, std::uint32_t number)
{
    if (number != posix_spawn_syscall)
        return false;

    PerformanceLatencyScope total_latency { PerfLatencyKind::PosixSpawnTotal };
    auto& registers = cpu.registers();
    const auto pid_address = registers[0];
    std::optional<std::string> path;
    std::optional<std::vector<std::string>> arguments;
    std::optional<std::vector<std::string>> environment;
    std::optional<PosixSpawnAttributes> attributes;
    {
        PerformanceLatencyScope decode_latency {
            PerfLatencyKind::PosixSpawnDecode
        };
        path = memory_.read_c_string(registers[1]);
        arguments = read_string_vector(memory_, registers[3]);
        environment = read_string_vector(memory_, registers[4]);
        attributes = read_spawn_attributes(memory_, registers[2]);
    }
    if (!path || !arguments || !environment || !attributes ||
        (pid_address == 0 && !attributes->setexec)) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }

    // `--suspended` is an application argument used by first-generation
    // SpringBoard's prewarm protocol, not a kernel spawn attribute. The child
    // must run through dyld and suspend itself in userspace. Only the actual
    // POSIX_SPAWN_START_SUSPENDED flag places the initial thread on hold.

    std::error_code path_error;
    if (!std::filesystem::is_regular_file(
            resolve_guest_path(*path), path_error)) {
        bsd_error(cpu, 2); // ENOENT
        return true;
    }

    if (attributes->setexec) {
        if (!exec_handler_ ||
            !exec_handler_(cpu, *path, *arguments, *environment)) {
            bsd_error(cpu, 8); // ENOEXEC
            return true;
        }
        // SpringBoard's older launch path forks a helper and asks that child to
        // SETEXEC the application. There is no separate child-return path
        // below, so observe the successful PID-bound spawn here after exec has
        // assigned the new process identity.
        graphics_services_input::record_application_spawn(*shared_state_,
            process_.parent_pid, process_.pid, *path, *arguments,
            scene_coordinator_.get(), true);
        performance_counters().record_exec();
        std::ostringstream message;
        message << "[process] spawn-setexec pid=" << process_.pid
                << " parent=" << process_.parent_pid
                << " suspended=" << attributes->start_suspended << " " << *path
                << " argv=";
        for (std::size_t index = 0; index < arguments->size(); ++index) {
            if (index != 0)
                message << ',';
            message << '"' << (*arguments)[index] << '"';
        }
        message << '\n';
        output_.write(message.str());
        cpu.halt(Umbra::HaltReason::UserDefined6);
        return true;
    }

    std::optional<std::uint32_t> child;
    if (spawn_create_handler_) {
        PerformanceLatencyScope create_latency {
            PerfLatencyKind::PosixSpawnCreate
        };
        child = spawn_create_handler_(cpu);
    } else {
        PerformanceLatencyScope fork_latency {
            PerfLatencyKind::PosixSpawnFork
        };
        child = fork_handler_ ? fork_handler_(cpu) : std::nullopt;
    }
    if (!child) {
        bsd_error(cpu, 11); // EAGAIN
        return true;
    }
    performance_counters().record_fork();
    if (!spawn_exec_handler_ ||
        !spawn_exec_handler_(*child, *path, *arguments, *environment,
            attributes->start_suspended)) {
        bsd_error(cpu, 8); // ENOEXEC
        return true;
    }
    if (scheduler_preemption_query_ &&
        scheduler_preemption_query_(cpu.processor_id())) {
        // A successful non-suspended spawn leaves a new runnable child visible
        // to the scheduler before the parent returns to Guest code. A suspended
        // child is already blocked by spawn_exec_handler_ and therefore does
        // not trigger this query unless another runnable candidate wins
        // ordering.
        cpu.request_guest_preemption();
    }
    graphics_services_input::record_application_spawn(*shared_state_,
        process_.pid, *child, *path, *arguments, scene_coordinator_.get());
    performance_counters().record_exec();
    if (!memory_.write32(pid_address, *child)) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }

    std::ostringstream message;
    message << "[process] spawn parent=" << process_.pid << " child=" << *child
            << " suspended=" << attributes->start_suspended << " " << *path
            << " argv=";
    for (std::size_t index = 0; index < arguments->size(); ++index) {
        if (index != 0)
            message << ',';
        message << '"' << (*arguments)[index] << '"';
    }
    message << '\n';
    output_.write(message.str());
    bsd_success(cpu, 0);
    return true;
}

} // namespace shade
