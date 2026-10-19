// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Update guest filesystem timestamps using Darwin time layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/vfs/vfs_syscalls.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <array>
#include <bit>
#include <cerrno>
#include <cstdint>
#include <filesystem>
#include <mutex>
#include <optional>
#include <string>
#include <system_error>

#include <sys/time.h>

#include "../support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t timeval_seconds_offset = 0;
    constexpr std::uint32_t timeval_microseconds_offset = 4;
    constexpr std::uint32_t timeval_size = 8;
    constexpr std::int32_t microseconds_per_second = 1'000'000;
    constexpr std::int32_t nanoseconds_per_microsecond = 1'000;

    struct TimevalReadResult {
        std::optional<hfs::Timestamp> value;
        std::uint32_t error { };
    };

    TimevalReadResult read_timeval(
        const AddressSpace& memory, std::uint32_t address)
    {
        const auto seconds = memory.read32(address + timeval_seconds_offset);
        const auto microseconds =
            memory.read32(address + timeval_microseconds_offset);
        if (!seconds || !microseconds)
            return { .value = std::nullopt,
                .error = darwin::error::bad_address };

        const auto signed_microseconds =
            std::bit_cast<std::int32_t>(*microseconds);
        if (signed_microseconds < 0 ||
            signed_microseconds >= microseconds_per_second) {
            return { .value = std::nullopt,
                .error = darwin::error::invalid_argument };
        }
        return {
            .value =
                hfs::Timestamp {
                    std::bit_cast<std::int32_t>(*seconds),
                    signed_microseconds * nanoseconds_per_microsecond,
                },
        };
    }

    timeval host_timeval(const hfs::Timestamp& timestamp)
    {
        return timeval {
            .tv_sec = timestamp.seconds,
            .tv_usec = timestamp.nanoseconds / nanoseconds_per_microsecond,
        };
    }

} // namespace

bool CompatibilityKernel::dispatch_bsd_filesystem_timestamps(
    Cpu& cpu, std::uint32_t number)
{
    if (number != darwin::syscall::update_file_times &&
        number != darwin::syscall::update_file_times_fd)
        return false;

    const auto& registers = cpu.registers();
    std::filesystem::path host;
    std::string target;
    if (number == darwin::syscall::update_file_times) {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        host = resolve_guest_path(*path);
        target = *path;
    }

    hfs::Timestamp access_time;
    hfs::Timestamp modification_time;
    if (registers[1] == 0) {
        access_time =
            bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        modification_time = access_time;
    } else {
        const auto access = read_timeval(memory_, registers[1]);
        const auto modification =
            read_timeval(memory_, registers[1] + timeval_size);
        if (!access.value || !modification.value) {
            bsd_error(
                cpu, access.error != 0 ? access.error : modification.error);
            return true;
        }
        access_time = *access.value;
        modification_time = *modification.value;
    }

    if (number == darwin::syscall::update_file_times_fd) {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto descriptor = file_descriptors_.find(fd);
        if (descriptor == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return true;
        }
        host = descriptor->second;
        target = "fd=" + std::to_string(fd);
    }
    const auto metadata = query_hfs_metadata(host, true);
    if (!metadata) {
        bsd_error(cpu, darwin::error::no_entry);
        return true;
    }

    const std::array host_times {
        host_timeval(access_time),
        host_timeval(modification_time),
    };
    if (::utimes(host.c_str(), host_times.data()) != 0) {
        bsd_error(cpu, bsd_support::darwin_filesystem_error(
                           std::error_code { errno, std::generic_category() }));
        return true;
    }

    const auto change_time =
        bsd_support::guest_filesystem_timestamp(shared_state_->clock);
    {
        const std::lock_guard filesystem_lock {
            shared_state_->filesystem_mutex
        };
        auto& override =
            shared_state_->hfs_metadata_overrides[metadata->permanent_id];
        override.access_time = access_time;
        override.modification_time = modification_time;
        override.change_time = change_time;
    }

    output_.write("[vfs] " +
                  std::string { number == darwin::syscall::update_file_times
                                    ? "utimes "
                                    : "futimes " } +
                  target +
                  " mtime=" + std::to_string(modification_time.seconds) + "." +
                  std::to_string(modification_time.nanoseconds) + "\n");
    bsd_success(cpu, 0);
    return true;
}

} // namespace shade
