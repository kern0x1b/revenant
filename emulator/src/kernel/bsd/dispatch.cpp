// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Route Darwin BSD syscall numbers through the selected compatibility
// profile.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/syscalls.master
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1228.15.4/bsd/kern/syscalls.master
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/kern/syscalls.master

#include "kernel/kernel.hpp"
#include "process/resource_monitor.hpp"
#include "process/uuid_policy.hpp"

#include "kernel/darwin_process_policy_abi.hpp"
#include "kernel/darwin_memorystatus_abi.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_proc_info_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/kernel_bsd_interval_timer.hpp"
#include "kernel/kernel_network.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include "support.hpp"

namespace emulator {
namespace {

    std::optional<std::uint32_t> canonical_no_cancel_syscall(
        std::uint32_t number)
    {
        switch (number) {
        case 396:
            return darwin::syscall::read;
        case 397:
            return darwin::syscall::write;
        case 398:
            return darwin::syscall::open;
        case 399:
            return darwin::syscall::close;
        case 400:
            return 7U;
        case 401:
            return darwin::syscall::receive_message;
        case 402:
            return darwin::syscall::send_message;
        case 403:
            return darwin::syscall::receive_from;
        case 404:
            return darwin::syscall::accept;
        case 405:
            return darwin::syscall::memory_synchronize;
        case 406:
            return darwin::syscall::fcntl;
        case 407:
            return darwin::syscall::select;
        case 417:
            return darwin::syscall::poll;
        case 420:
            return darwin::syscall::posix_semaphore_wait;
        case 408:
            return darwin::syscall::synchronize_file;
        case 409:
            return darwin::syscall::connect;
        case 410:
            return 111U;
        case 412:
            return darwin::syscall::write_vector;
        case 413:
            return darwin::syscall::send_to;
        case 414:
            return 153U;
        case 415:
            return 154U;
        case 421:
            return darwin::syscall::aio_suspend;
        case 423:
            return darwin::syscall::semaphore_wait_signal;
        default:
            return std::nullopt;
        }
    }

}

void CompatibilityKernel::dispatch_bsd_nosys(
    Cpu& cpu, std::uint32_t number, bool send_sigsys)
{
    trace_unknown(cpu, "BSD syscall", number);
    bsd_error(cpu, bsd_support::not_implemented);
    if (!send_sigsys)
        return;
    static_cast<void>(deliver_signal(darwin::signal::bad_system_call));
    if (process_.exited)
        cpu.halt(Dynarmic::HaltReason::UserDefined1);
}

void CompatibilityKernel::dispatch_bsd(Cpu& cpu, std::uint32_t number)
{
    if (const auto canonical = canonical_no_cancel_syscall(number)) {
        dispatch_bsd(cpu, *canonical);
        return;
    }
    const auto saved_processor = syscall_processor_;
    syscall_processor_ = cpu.processor_id();
    struct RestoreProcessor {
        std::optional<std::size_t>& slot;
        std::optional<std::size_t> saved;
        ~RestoreProcessor() { slot = saved; }
    } restore_processor { syscall_processor_, saved_processor };
    if (dispatch_bsd_pthread(cpu, number))
        return;
    if (dispatch_bsd_thread_directory(cpu, number))
        return;

    switch (number) {
    case 441:
    case 442:
    case 443:
        dispatch_bsd_guarded_file(cpu, number);
        return;
    case 322: {
        if (!darwin_abi_route_supported(legacy_iopolicysys_route,
                shared_state_->darwin_abi.abi_epoch)) {
            dispatch_bsd_nosys(cpu, number,
                shared_state_->darwin_abi.capabilities.send_sigsys);
            return;
        }

        constexpr std::uint32_t iopol_cmd_get = 1;
        constexpr std::uint32_t iopol_cmd_set = 2;
        constexpr std::uint32_t iopol_type_disk = 0;
        constexpr std::uint32_t iopol_scope_process = 0;
        constexpr std::uint32_t iopol_scope_thread = 1;
        constexpr std::uint32_t iopol_policy_max = 3;
        constexpr std::uint32_t iopol_policy_offset =
            2U * sizeof(std::uint32_t);

        const auto address = cpu.registers()[1];
        if (address >
            std::numeric_limits<std::uint32_t>::max() - iopol_policy_offset) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto scope = memory_.read32(address);
        const auto iotype = memory_.read32(address + sizeof(std::uint32_t));
        const auto policy =
            memory_.read32(address + 2U * sizeof(std::uint32_t));
        if (!scope || !iotype || !policy) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (*iotype != iopol_type_disk ||
            (*scope != iopol_scope_process && *scope != iopol_scope_thread)) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }

        auto* stored_policy = &process_.disk_io_policy;
        if (*scope == iopol_scope_thread) {
            const auto thread_object =
                thread_object_for_processor(cpu.processor_id());
            if (!thread_object) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            stored_policy = &process_.thread_disk_io_policies[*thread_object];
        }
        switch (cpu.registers()[0]) {
        case iopol_cmd_get:
            if (!memory_.write32(
                    address + 2U * sizeof(std::uint32_t), *stored_policy)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, 0);
            return;
        case iopol_cmd_set:
            if (*policy > iopol_policy_max) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            *stored_policy = *policy;
            bsd_success(cpu, 0);
            return;
        default:
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
    }
        return;
    case 365:
        if (shared_state_->darwin_abi.stack_snapshot_abi ==
            DarwinStackSnapshotAbi::Unsupported) {
            dispatch_bsd_nosys(cpu, number,
                shared_state_->darwin_abi.capabilities.send_sigsys);
            return;
        }
        bsd_error(cpu, darwin::error::permission_denied);
        return;
    case 0:
    case 1:
    case 2:
    case 66:
    case 7:
    case 20:
    case darwin::syscall::get_priority:
    case darwin::syscall::set_user_id:
    case 24:
    case 25:
    case 39:
    case 43:
    case 47:
    case 46:
    case 48:
    case darwin::syscall::pthread_sigmask:
    case 49:
    case 50:
    case 55:
    case 60:
    case 59:
    case darwin::syscall::get_process_group:
    case darwin::syscall::get_thread_identity:
    case kernel_bsd::interval_timer::set_syscall:
    case kernel_bsd::interval_timer::get_syscall:
    case 244:
    case 96:
    case 116:
    case darwin::syscall::get_resource_usage:
    case darwin::syscall::set_time_of_day:
    case darwin::syscall::set_real_effective_user_id:
    case darwin::syscall::set_real_effective_group_id:
    case 147:
    case darwin::syscall::set_groups:
    case darwin::syscall::set_group_id:
    case darwin::syscall::set_effective_group_id:
    case darwin::syscall::set_effective_user_id:
    case darwin::syscall::init_groups:
    case darwin::syscall::get_resource_limit:
    case darwin::syscall::set_resource_limit:
    case kernel_bsd::resource_monitor::syscall_number:
    case kernel_bsd::uuid_policy::syscall_number:
    case darwin::syscall::disable_thread_signal:
    case 333:
    case darwin::syscall::semaphore_wait_signal:
    case darwin::syscall::semaphore_wait_signal_timespec:
    case darwin::proc_info::syscall_number:
    case darwin::memorystatus::syscall_number:
    case darwin::process_policy::syscall_number:
    case 327:
    case 355:
    case darwin::syscall::pid_suspend:
    case darwin::syscall::pid_resume:
    case darwin::syscall::pid_hibernate:
        dispatch_bsd_process(cpu, number);
        return;
    case darwin::syscall::pid_shutdown_sockets:
        dispatch_bsd_process_sockets(cpu);
        return;
    case darwin::syscall::posix_semaphore_open:
    case darwin::syscall::posix_semaphore_close:
    case darwin::syscall::posix_semaphore_unlink:
    case darwin::syscall::posix_semaphore_wait:
    case darwin::syscall::posix_semaphore_try_wait:
    case darwin::syscall::posix_semaphore_post:
    case darwin::syscall::posix_semaphore_get_value:
        dispatch_bsd_posix_semaphore(cpu, number);
        return;
    case 111:
    case 53:
    case 184:
    case darwin::syscall::pthread_kill:
    case darwin::syscall::kill:
        dispatch_bsd_signal(cpu, number);
        return;
    case darwin::syscall::get_host_uuid:
        dispatch_bsd_platform(cpu, number);
        return;
    case 9:
    case 10:
    case 5:
    case 6:
    case 12:
    case 13:
    case darwin::syscall::change_mode:
    case darwin::syscall::change_owner:
    case 18:
    case 33:
    case darwin::syscall::change_flags:
    case darwin::syscall::change_flags_fd:
    case darwin::syscall::change_owner_fd:
    case darwin::syscall::change_owner_link:
    case darwin::syscall::change_mode_fd:
    case darwin::syscall::change_mode_extended:
    case darwin::syscall::change_mode_extended_fd:
    case darwin::syscall::flock:
    case darwin::syscall::synchronize_file:
    case 36:
    case darwin::syscall::revoke:
    case 57:
    case 58:
    case 128:
    case 136:
    case 137:
    case darwin::syscall::update_file_times:
    case darwin::syscall::update_file_times_fd:
    case 153:
    case 154:
    case 157:
    case 159:
    case 167:
    case 158:
    case 200:
    case 201:
    case 196:
    case 199:
    case 216:
    case 220:
    case 221:
    case 222:
    case 344:
    case 338:
    case 339:
    case 340:
    case 341:
    case 342:
    case 343:
    case 345:
    case 346:
    case 347:
    case darwin::syscall::get_extended_attribute:
    case darwin::syscall::get_extended_attribute_fd:
    case darwin::syscall::set_extended_attribute:
    case darwin::syscall::set_extended_attribute_fd:
    case darwin::syscall::remove_extended_attribute:
    case darwin::syscall::remove_extended_attribute_fd:
    case darwin::syscall::list_extended_attributes:
    case darwin::syscall::list_extended_attributes_fd:
    case darwin::syscall::filesystem_control:
    case 188:
    case 190:
    case 189:
        dispatch_bsd_filesystem(cpu, number);
        return;
    case darwin::syscall::read:
    case darwin::syscall::write:
    case 41:
    case 42:
    case darwin::syscall::memory_synchronize:
    case 73:
    case darwin::syscall::get_descriptor_table_size:
    case darwin::syscall::duplicate_to:
    case darwin::syscall::fcntl:
    case darwin::syscall::file_descriptor_path_configuration:
    case darwin::syscall::memory_protect:
    case darwin::syscall::memory_advise:
    case 197:
    case 266:
    case 267:
        dispatch_bsd_descriptor_memory(cpu, number);
        return;
    case 294:
    case 295:
        static_cast<void>(dispatch_bsd_shared_region(cpu, number));
        return;
    case 297:
    case 298:
    case 299:
    case 300:
    case 301:
    case 302:
    case 303:
    case 304:
    case 305:
    case 306:
    case 307:
    case 308:
    case 309:
    case 312:
        if (shared_state_->darwin_abi.psynch_abi ==
            DarwinPsynchAbi::Arm32GenerationV1) {
            dispatch_bsd_psynch(cpu, number);
            return;
        }
        if (number == 299U || number == 300U) {
            static_cast<void>(dispatch_bsd_shared_region(cpu, number));
        } else {
            dispatch_bsd_nosys(cpu, number,
                shared_state_->darwin_abi.capabilities.send_sigsys);
        }
        return;
    case 438:
        if (shared_state_->darwin_abi.shared_region_abi !=
            DarwinSharedRegionAbi::FixedMappingsWithSlideInfoV1) {
            dispatch_bsd_nosys(cpu, number,
                shared_state_->darwin_abi.capabilities.send_sigsys);
            return;
        }
        static_cast<void>(dispatch_bsd_shared_region(cpu, number));
        return;
    case darwin::syscall::aio_synchronize:
    case darwin::syscall::aio_return:
    case darwin::syscall::aio_suspend:
    case darwin::syscall::aio_cancel:
    case darwin::syscall::aio_error:
    case darwin::syscall::aio_read:
    case darwin::syscall::aio_write:
        dispatch_bsd_aio(cpu, number);
        return;
    case darwin::syscall::ptrace:
    case 180:
        static_cast<void>(dispatch_bsd_debug(cpu, number));
        return;
    case 27:
    case 28:
    case darwin::syscall::receive_from:
    case darwin::syscall::accept:
    case 31:
    case 32:
    case darwin::syscall::socket:
    case darwin::syscall::connect:
    case darwin::syscall::bind:
    case 105:
    case darwin::syscall::listen:
    case 118:
    case darwin::syscall::write_vector:
    case darwin::syscall::send_to:
    case darwin::syscall::shutdown:
    case darwin::syscall::socket_pair:
        dispatch_bsd_socket(cpu, number);
        return;
    case 54:
    case darwin::syscall::poll:
    case 93:
    case 202:
        dispatch_bsd_events(cpu, number);
        return;
    case 362:
    case 363:
    case 369:
        dispatch_bsd_kqueue(cpu, number);
        return;
    case darwin::syscall::code_signing_operations:
        dispatch_bsd_code_signing(cpu);
        return;
    case darwin::syscall::code_signing_audit_operations:
        dispatch_bsd_code_signing(cpu, true);
        return;
    case darwin::syscall::mac_syscall:
        static_cast<void>(dispatch_bsd_security(cpu, number));
        return;
    case darwin::syscall::get_audit_address:
    case darwin::syscall::audit_session_self:
    case darwin::syscall::audit_session_join:
    case darwin::syscall::audit_session_port:
        dispatch_bsd_audit_session(cpu, number);
        return;
    case darwin::syscall::fileport_makeport:
    case darwin::syscall::fileport_makefd:
        dispatch_bsd_fileport(cpu, number);
        return;
    default:
        dispatch_bsd_nosys(cpu, number,
            shared_state_->darwin_abi.capabilities.send_sigsys);
        return;
    }
}

}
