// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest file synchronization and persistence requests.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/vfs/vfs_syscalls.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <cerrno>
#include <string>
#include <system_error>

#include <unistd.h>

#include "../support.hpp"

namespace shade {

bool CompatibilityKernel::dispatch_bsd_filesystem_persistence(
    Cpu& cpu, std::uint32_t number)
{
    if (number != darwin::syscall::synchronize_file)
        return false;

    auto fd = cpu.registers()[0];
    if (const auto duplicate = duplicated_descriptors_.find(fd);
        duplicate != duplicated_descriptors_.end()) {
        fd = duplicate->second;
    }
    const auto descriptor = file_descriptors_.find(fd);
    if (descriptor == file_descriptors_.end()) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }

    const auto description = ensure_regular_file_open_description(fd);
    if (!description) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }
    const auto result = ::fsync(description->host_descriptor());
    const auto sync_error = errno;
    if (result != 0) {
        bsd_error(cpu, bsd_support::darwin_filesystem_error(std::error_code {
                           sync_error, std::generic_category() }));
        return true;
    }
    output_.write("[vfs] fsync fd=" + std::to_string(fd) + "\n");
    bsd_success(cpu, 0);
    return true;
}

} // namespace shade
