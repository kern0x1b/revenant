// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest filesystem-control commands and extension-ordering
// state.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/vfs/vfs_syscalls.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <mutex>
#include <string>
#include <vector>

#include "../support.hpp"

namespace shade {
namespace {

    [[nodiscard]] bool package_extension_order(
        const std::string& left, const std::string& right)
    {
        // Match XNU's extension_cmp ordering. The order is not observable to
        // callers, but retaining it keeps later HFS package lookups faithful.
        return left.size() < right.size();
    }

} // namespace

bool CompatibilityKernel::dispatch_bsd_filesystem_control(
    Cpu& cpu, std::uint32_t number)
{
    if (number != darwin::syscall::filesystem_control) {
        return false;
    }

    const auto& registers = cpu.registers();
    const auto path = memory_.read_c_string(registers[0]);
    if (!path) {
        bsd_error(cpu, darwin::error::bad_address);
        return true;
    }

    const auto follow_final_symlink =
        (registers[3] & darwin::filesystem_control::option_no_follow) == 0U;
    const auto host_path = resolve_guest_path(*path, follow_final_symlink);
    std::error_code path_error;
    const auto path_status = follow_final_symlink
        ? std::filesystem::status(host_path, path_error)
        : std::filesystem::symlink_status(host_path, path_error);
    if (path_error ||
        path_status.type() == std::filesystem::file_type::not_found) {
        bsd_error(cpu,
            bsd_support::darwin_filesystem_error(
                path_error, darwin::error::no_entry));
        return true;
    }

    if (registers[1] !=
        darwin::filesystem_control::set_package_extensions) {
        bsd_error(cpu, darwin::error::inappropriate_ioctl);
        return true;
    }

    const auto info_address = registers[2];
    if (!memory_.accessible(info_address,
            darwin::filesystem_control::package_info_size,
            MemoryPermission::Read)) {
        bsd_error(cpu, darwin::error::bad_address);
        return true;
    }
    const auto strings_address = memory_.read32(
        info_address +
        darwin::filesystem_control::package_strings_offset);
    const auto entry_count = memory_.read32(
        info_address +
        darwin::filesystem_control::package_entry_count_offset);
    const auto maximum_width = memory_.read32(
        info_address +
        darwin::filesystem_control::package_maximum_width_offset);
    if (!strings_address || !entry_count || !maximum_width) {
        bsd_error(cpu, darwin::error::bad_address);
        return true;
    }
    if (*entry_count == 0U ||
        *entry_count >
            darwin::filesystem_control::maximum_package_entries ||
        *maximum_width == 0U ||
        *maximum_width >
            darwin::filesystem_control::maximum_package_width) {
        bsd_error(cpu, darwin::error::invalid_argument);
        return true;
    }

    const auto byte_count = static_cast<std::size_t>(*entry_count) *
                            static_cast<std::size_t>(*maximum_width);
    const auto bytes = memory_.read_bytes(*strings_address, byte_count);
    if (!bytes) {
        bsd_error(cpu, darwin::error::bad_address);
        return true;
    }

    std::vector<std::string> extensions;
    extensions.reserve(*entry_count);
    for (std::uint32_t index = 0; index < *entry_count; ++index) {
        const auto begin = bytes->begin() +
                           static_cast<std::ptrdiff_t>(index * *maximum_width);
        const auto end = begin + static_cast<std::ptrdiff_t>(*maximum_width);
        const auto terminator = std::find(begin, end, std::byte { });
        if (terminator == end) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return true;
        }
        extensions.emplace_back(reinterpret_cast<const char*>(&*begin),
            static_cast<std::size_t>(terminator - begin));
    }
    std::stable_sort(
        extensions.begin(), extensions.end(), package_extension_order);

    {
        const std::lock_guard filesystem_lock {
            shared_state_->filesystem_mutex
        };
        shared_state_->package_extensions = std::move(extensions);
    }
    output_.write("[vfs] fsctl set-package-extensions path=" + *path +
                  " entries=" + std::to_string(*entry_count) +
                  " width=" + std::to_string(*maximum_width) + "\n");
    bsd_success(cpu, 0);
    return true;
}

} // namespace shade
