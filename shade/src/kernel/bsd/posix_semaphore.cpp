// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement guest POSIX named semaphore operations using kernel
// semaphore state.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/posix_sem.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <cstdint>
#include <mutex>
#include <string>

#include "support.hpp"

namespace shade {
namespace {

    constexpr std::size_t maximum_name_bytes = 31;
    constexpr std::int32_t maximum_value = 32767;
    constexpr std::uint32_t too_many_open_files = 24;
    constexpr std::uint32_t name_too_long = 63;
    constexpr std::string_view descriptor_kind { "posix-semaphore" };

} // namespace

void CompatibilityKernel::dispatch_bsd_posix_semaphore(
    Cpu& cpu, std::uint32_t number)
{
    const auto& registers = cpu.registers();
    if (number == darwin::syscall::posix_semaphore_open) {
        const auto name =
            memory_.read_c_string(registers[0], maximum_name_bytes + 1U);
        if (!name) {
            bsd_error(cpu, darwin::error::bad_address);
            return;
        }
        if (name->empty()) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        if (name->size() + 1U > maximum_name_bytes) {
            bsd_error(cpu, name_too_long);
            return;
        }
        const auto flags = registers[1];
        const auto create = (flags & darwin::open_flag::create) != 0U;
        const auto exclusive = (flags & darwin::open_flag::exclusive) != 0U;
        const auto initial_value = static_cast<std::int32_t>(registers[3]);
        if (create && (initial_value < 0 || initial_value > maximum_value)) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        const auto descriptor = allocate_file_descriptor();
        if (!descriptor) {
            bsd_error(cpu, too_many_open_files);
            return;
        }

        std::uint32_t object = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto existing =
                shared_state_->posix_named_semaphore_objects.find(*name);
            if (existing !=
                shared_state_->posix_named_semaphore_objects.end()) {
                if (create && exclusive) {
                    bsd_error(cpu, darwin::error::file_exists);
                    return;
                }
                object = existing->second;
            } else {
                if (!create) {
                    bsd_error(cpu, darwin::error::no_entry);
                    return;
                }
                object = shared_state_->allocate_mach_object();
                shared_state_->mach_semaphores.emplace(object,
                    KernelSharedState::MachSemaphore {
                        initial_value, 0U, { } });
                shared_state_->posix_named_semaphore_objects.emplace(
                    *name, object);
            }
        }
        virtual_descriptors_[*descriptor] = std::string { descriptor_kind };
        file_status_flags_[*descriptor] = flags;
        posix_semaphore_descriptors_[*descriptor] = object;
        output_.write("[posix-semaphore] open pid=" +
                      std::to_string(process_.pid) + " fd=" +
                      std::to_string(*descriptor) + " name=" + *name +
                      " value=" + std::to_string(initial_value) + "\n");
        bsd_success(cpu, *descriptor);
        return;
    }

    if (number == darwin::syscall::posix_semaphore_close) {
        const auto descriptor = registers[0];
        if (!posix_semaphore_descriptors_.contains(descriptor)) {
            bsd_error(cpu, darwin::error::bad_file_descriptor);
            return;
        }
        static_cast<void>(release_file_descriptor(descriptor));
        bsd_success(cpu, 0);
        return;
    }

    if (number == darwin::syscall::posix_semaphore_unlink) {
        const auto name =
            memory_.read_c_string(registers[0], maximum_name_bytes + 1U);
        if (!name) {
            bsd_error(cpu, darwin::error::bad_address);
            return;
        }
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (shared_state_->posix_named_semaphore_objects.erase(*name) == 0U) {
            bsd_error(cpu, darwin::error::no_entry);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }

    // This entry point is a deliberate ENOSYS stub in the matching XNU
    // generation. Preserve that contract independently of its arguments.
    if (number == darwin::syscall::posix_semaphore_get_value) {
        trace_unknown(cpu, "POSIX semaphore syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }

    const auto descriptor = registers[0];
    const auto descriptor_entry =
        posix_semaphore_descriptors_.find(descriptor);
    if (descriptor_entry == posix_semaphore_descriptors_.end()) {
        bsd_error(cpu, darwin::error::bad_file_descriptor);
        return;
    }
    const auto semaphore_object = descriptor_entry->second;

    if (number == darwin::syscall::posix_semaphore_wait) {
        // Darwin represents sem_t as the descriptor returned by sem_open().
        // Reuse the same scheduler-backed Mach semaphore that XNU's psem
        // implementation calls internally so waits block instead of polling.
        wait_on_semaphore_object(cpu, semaphore_object, std::nullopt,
            std::nullopt, true, descriptor);
        return;
    }

    if (number == darwin::syscall::posix_semaphore_try_wait) {
        bool acquired = false;
        bool valid = false;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto semaphore =
                shared_state_->mach_semaphores.find(semaphore_object);
            valid = semaphore != shared_state_->mach_semaphores.end();
            if (valid && semaphore->second.count > 0) {
                --semaphore->second.count;
                acquired = true;
            }
        }
        if (!valid)
            bsd_error(cpu, darwin::error::invalid_argument);
        else if (!acquired)
            bsd_error(cpu, darwin::error::would_block);
        else
            bsd_success(cpu, 0);
        return;
    }

    if (number == darwin::syscall::posix_semaphore_post) {
        std::optional<WokenThread> woken_thread;
        std::uint32_t result = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            result = signal_semaphore_object_locked(
                semaphore_object, false, true, &woken_thread);
        }
        wake_thread_and_maybe_preempt(cpu, woken_thread);
        if (result == 0)
            bsd_success(cpu, 0);
        else
            bsd_error(cpu, darwin::error::invalid_argument);
        return;
    }

    trace_unknown(cpu, "POSIX semaphore syscall", number);
    bsd_error(cpu, bsd_support::not_implemented);
}

} // namespace shade
