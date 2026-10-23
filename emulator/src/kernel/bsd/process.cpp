// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest process lifecycle, waiting, accounting and
// compatibility operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_exit.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_time.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_resource.c

#include "kernel/kernel.hpp"
#include "process/resource_monitor.hpp"
#include "process/uuid_policy.hpp"
#include "security/extensions.hpp"

#include "foundation/application_path.hpp"
#include "foundation/guest_image_table.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/graphics_services_input.hpp"
#include "kernel/kernel_bsd_interval_timer.hpp"
#include "kernel/kernel_network.hpp"
#include "foundation/performance.hpp"

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
#include <string_view>
#include <utility>
#include <vector>

#include "../mach/support.hpp"
#include "support.hpp"

namespace emulator {

void CompatibilityKernel::release_process_mach_rights()
{
    scene_coordinator_->retire_process(process_.pid);
    presentation_tracker_->retire_process(
        process_.pid, surface_store_->publication_watermark());
    pending_mach_receives_.clear();
    pending_semaphore_waits_.clear();
    pending_psynch_waits_.clear();
    pending_signal_suspends_.clear();
    shared_state_->psynch_runtime->clear_process(process_.pid);
    process_.waiting_for_events = false;
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    auto entries = shared_state_->mach_namespaces.entries(process_.pid);

    graphics_services_input::release_application_process_locked(
        *shared_state_, process_.pid);

    const auto receive_type =
        xnu::ipc::type_mask(xnu::ipc::Right::Receive);
    std::stable_sort(entries.begin(), entries.end(),
        [receive_type](const auto& left, const auto& right) {
            const auto left_receives = (left.entry.type & receive_type) != 0;
            const auto right_receives = (right.entry.type & receive_type) != 0;
            return !left_receives && right_receives;
        });
    for (const auto& entry : entries) {
        static_cast<void>(mach_support::destroy_port_name_locked(
            *shared_state_, process_.pid, entry.name));
    }
    mach_support::terminate_exited_task_ports_locked(
        *shared_state_, process_.pid);
    mach_support::terminate_exited_semaphores_locked(
        *shared_state_, process_.pid);
    if (const auto registered =
            shared_state_->mach_registered_ports.find(process_.pid);
        registered != shared_state_->mach_registered_ports.end()) {
        for (const auto object : registered->second) {
            if (object != xnu::ipc::null_name)
                mach_support::release_kernel_send_right_locked(
                    *shared_state_, object);
        }
        shared_state_->mach_registered_ports.erase(registered);
    }
    shared_state_->mach_namespaces.destroy_task(process_.pid);
    mach_support::cleanup_exited_process_metadata_locked(
        *shared_state_, process_.pid);
}

void CompatibilityKernel::release_process_descriptors()
{
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (const auto task =
                shared_state_->task_thread_port_objects.find(process_.pid);
            task != shared_state_->task_thread_port_objects.end()) {
            for (const auto& [processor, thread_object] : task->second) {
                static_cast<void>(processor);
                release_thread_directory_locked(thread_object);
            }
        }
    }
    file_descriptors_.clear();
    regular_file_open_descriptions_.clear();
    virtual_block_descriptors_.clear();
    file_offsets_.clear();
    file_status_flags_.clear();
    descriptor_flags_.clear();
    virtual_descriptors_.clear();
    posix_semaphore_descriptors_.clear();
    baseband_open_descriptions_.clear();
    bpf_descriptors_.clear();
    host_sockets_.clear();
    pending_host_writes_.clear();
    pending_baseband_writes_.clear();
    wifi_driver_event_streams_.clear();
    scheduled_wifi_driver_events_.clear();
    virtual_udp_sockets_.clear();
    kernel_control_endpoints_.clear();
    bound_socket_names_.clear();
    listening_sockets_.clear();
    unix_listener_states_.clear();
    socket_options_.clear();
    duplicated_descriptors_.clear();
    system_event_filters_.clear();
    apple80211_scan_delivered_.clear();
    system_event_next_identifiers_.clear();
    route_socket_states_.clear();
    socket_pair_endpoints_.clear();
    kqueues_.clear();
}

void CompatibilityKernel::exit_process(
    std::uint32_t status, std::uint32_t signal)
{
    if (process_.exited)
        return;
    note_timer_deadline_transition();
    hid_event_system_hle_.reset(process_.pid);
    process_.exit_status = status;
    process_.termination_signal = signal;
    std::uint32_t all_image_info_address { };
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (auto record = shared_state_->processes.find(process_.pid);
            record != shared_state_->processes.end()) {
            record->second.exited = true;
            record->second.exit_status = status;
            record->second.termination_signal = signal;
            all_image_info_address = record->second.dyld_all_image_info_address;
        }
        if (shared_state_->sandbox_extensions)
            shared_state_->sandbox_extensions->exit_process(process_.pid);
        auto& events = shared_state_->process_kevent_states[process_.pid];
        ++events.exit_generation;
        if (events.exit_generation == 0U)
            events.exit_generation = 1U;
        events.wait_status =
            signal != 0U ? signal & 0x7fU : (status & 0xffU) << 8U;
        shared_state_->mark_foreground_transition_cancelled_for_process_locked(
            process_.pid);
    }
    if (all_image_info_address != 0U &&
        performance_counters().block_profile_enabled()) {
        performance_counters().block_profile().record_images(
            static_cast<std::uint32_t>(process_.pid),
            read_guest_image_table(memory_, all_image_info_address));
    }
    shared_state_->note_io_event_transition();
    kernel_bsd::interval_timer::retire_process(*shared_state_, process_.pid);
    shared_state_->advisory_file_locks->release_process_record_locks(
        process_.pid);
    apple80211_hle_.reset(process_.pid);
    release_process_descriptors();
    process_.thread_disk_io_policies.clear();
    display_state_->clear_if_owner(process_.pid);
    release_process_mach_rights();
    process_.exited = true;
    if (signal != 0)
        performance_counters().record_abnormal_exit();
    output_.write(
        "[process] exit pid=" + std::to_string(process_.pid) +
        " status=" + std::to_string(status) +
        (signal != 0 ? " signal=" + std::to_string(signal) : std::string { }) +
        "\n");
}

CompatibilityKernel::WaitChildResult CompatibilityKernel::wait_child(
    std::int32_t target_pid, bool reap)
{
    WaitChildResult result;
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    for (auto child = shared_state_->processes.begin();
        child != shared_state_->processes.end(); ++child) {
        const auto child_pid = child->first;
        const auto& record = child->second;
        if (record.parent_pid != process_.pid ||
            (target_pid != -1 &&
                static_cast<std::uint32_t>(target_pid) != child_pid)) {
            continue;
        }
        result.has_child = true;
        if (!record.exited)
            continue;
        result.child_pid = child_pid;
        result.status = record.termination_signal != 0
                            ? record.termination_signal & 0x7fU
                            : (record.exit_status & 0xffU) << 8U;
        if (reap)
            shared_state_->processes.erase(child);
        break;
    }
    return result;
}

void CompatibilityKernel::dispatch_bsd_process(Cpu& cpu, std::uint32_t number)
{
    if (dispatch_bsd_process_credentials(cpu, number))
        return;
    if (dispatch_bsd_process_information(cpu, number))
        return;
    if (dispatch_bsd_memorystatus(cpu, number))
        return;
    if (dispatch_bsd_process_policy(cpu, number))
        return;
    if (dispatch_bsd_process_spawn(cpu, number))
        return;
    if (kernel_bsd::interval_timer::dispatch(
            cpu, memory_, output_, *shared_state_, process_, number)) {
        return;
    }

    auto& registers = cpu.registers();
    switch (number) {
    case kernel_bsd::uuid_policy::syscall_number: {
        const auto error = kernel_bsd::uuid_policy::control(memory_, process_,
            registers[0], registers[1], registers[2]);
        if (error != 0U)
            bsd_error(cpu, error);
        else
            bsd_success(cpu, 0);
        return;
    }
    case kernel_bsd::resource_monitor::syscall_number: {
        const auto error = kernel_bsd::resource_monitor::control(memory_,
            *shared_state_, process_, registers[0], registers[1], registers[2]);
        if (error != 0U)
            bsd_error(cpu, error);
        else
            bsd_success(cpu, 0);
        return;
    }
    case 0: {
        const auto indirect_number = registers[0];
        for (std::size_t index = 0; index < 6; ++index) {
            registers[index] = registers[index + 1];
        }
        registers[6] = 0;
        dispatch_bsd(cpu, indirect_number);
        return;
    }
    case 1:
        exit_process(registers[0]);
        bsd_success(cpu, 0);
        cpu.halt(Dynarmic::HaltReason::UserDefined1);
        return;
    case 2: {
        const auto child = fork_handler_ ? fork_handler_(cpu) : std::nullopt;
        if (!child) {
            bsd_error(cpu, 11);
            return;
        }
        performance_counters().record_fork();
        output_.write("[process] fork parent=" + std::to_string(process_.pid) +
                      " child=" + std::to_string(*child) + " bootstrap=" +
                      std::to_string(process_.bootstrap_port) + "\n");
        bsd_success(cpu, *child);
        if (scheduler_preemption_query_ &&
            scheduler_preemption_query_(cpu.processor_id())) {
            cpu.request_guest_preemption();
        }
        return;
    }
    case 66: {
        const auto child = fork_handler_ ? fork_handler_(cpu) : std::nullopt;
        if (!child) {
            bsd_error(cpu, 11);
            return;
        }
        performance_counters().record_fork();
        output_.write("[process] vfork parent=" + std::to_string(process_.pid) +
                      " child=" + std::to_string(*child) + " bootstrap=" +
                      std::to_string(process_.bootstrap_port) + "\n");
        bsd_success(cpu, *child);
        if (scheduler_preemption_query_ &&
            scheduler_preemption_query_(cpu.processor_id())) {
            cpu.request_guest_preemption();
        }
        return;
    }
    case 7: {
        const auto target_pid = static_cast<std::int32_t>(registers[0]);
        const auto options = registers[2];
        if (target_pid == 0 || target_pid < -1) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (target_pid > 0 &&
            process_image_.ends_with("/SpringBoard.app/SpringBoard")) {
            bool application_child = false;
            {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                const auto child = shared_state_->processes.find(
                    static_cast<std::uint32_t>(target_pid));
                application_child = child != shared_state_->processes.end() &&
                                    !child->second.exited &&
                                    is_application_executable_path(
                                        child->second.executable_path);
            }
            if (application_child) {
                bsd_error(cpu, darwin::error::interrupted);
                return;
            }
        }
        if ((options & 1U) != 0) {
            const auto result = wait_child(target_pid, false);
            if (!result.has_child) {
                bsd_error(cpu, darwin::error::no_child_process);
                return;
            }
            if (!result.child_pid) {
                bsd_success(cpu, 0);
                return;
            }
            if (registers[1] != 0 &&
                !memory_.write32(registers[1], result.status)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            static_cast<void>(
                wait_child(static_cast<std::int32_t>(*result.child_pid), true));
            output_.write(
                "[process] reap-nohang parent=" + std::to_string(process_.pid) +
                " child=" + std::to_string(*result.child_pid) + "\n");
            bsd_success(cpu, *result.child_pid);
            return;
        }
        pending_waits_.insert_or_assign(
            cpu.processor_id(), PendingWait { target_pid, registers[1], options,
                                    cpu.processor_id() });
        output_.write("[process] wait pid=" + std::to_string(process_.pid) +
                      " target=" + std::to_string(target_pid) + "\n");
        process_.waiting_for_events = true;
        bsd_success(cpu, 0);
        cpu.halt(Dynarmic::HaltReason::UserDefined5);
        return;
    }
    case 20:
        bsd_success(cpu, process_.pid);
        return;
    case 24:
        bsd_success(cpu, process_.uid);
        return;
    case 25:
        bsd_success(cpu, process_.effective_uid);
        return;
    case 39:
        bsd_success(cpu, process_.parent_pid);
        return;
    case darwin::syscall::get_thread_identity:
        bsd_error(cpu, darwin::error::no_such_process);
        return;
    case 43:
        bsd_success(cpu, process_.effective_gid);
        return;
    case 47:
        bsd_success(cpu, process_.gid);
        return;
    case darwin::syscall::get_process_group:
        bsd_success(cpu, process_.process_group);
        return;
    case darwin::syscall::get_priority: {
        const auto which = registers[0];
        const auto who = registers[1];
        if (who > 0x7fff'ffffU) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }

        const auto target_is_live = [&](std::uint32_t pid) {
            if (pid == 0 || pid == process_.pid)
                return true;
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = shared_state_->processes.find(pid);
            return target != shared_state_->processes.end() &&
                   !target->second.exited;
        };
        const auto target_priority = [&](std::uint32_t pid) {
            if (pid == 0 || pid == process_.pid)
                return process_.nice_value;
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = shared_state_->processes.find(pid);
            return target == shared_state_->processes.end()
                       ? std::int32_t { }
                       : target->second.nice_value;
        };

        std::optional<std::int32_t> priority;
        switch (which) {
        case darwin::resource::priority_process:
            if (target_is_live(who))
                priority = target_priority(who);
            break;
        case darwin::resource::priority_process_group:
        case darwin::resource::priority_user: {
            const auto selector =
                who == 0 ? (which == darwin::resource::priority_process_group
                                  ? process_.process_group
                                  : process_.uid)
                         : who;
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            for (const auto& [pid, record] : shared_state_->processes) {
                const auto matches =
                    which == darwin::resource::priority_process_group
                        ? record.process_group == selector
                        : record.uid == selector;
                if (record.exited || !matches)
                    continue;
                const auto value = pid == process_.pid
                                       ? process_.nice_value
                                       : record.nice_value;
                if (!priority || value < *priority)
                    priority = value;
            }
            break;
        }
        case darwin::resource::priority_darwin_thread:
            if (who != 0) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            priority = 0;
            break;
        case darwin::resource::priority_darwin_process:
            if (target_is_live(who)) {
                priority = 0;
            }
            break;
        default:
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (!priority) {
            bsd_error(cpu, darwin::error::no_such_process);
            return;
        }
        bsd_success(cpu, static_cast<std::uint32_t>(*priority));
        return;
    }
    case 46: {
        const auto signal = registers[0];
        if (signal == 0 || signal >= signal_actions_.size() || signal == 9 ||
            signal == 17) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        auto& action = signal_actions_[signal];
        if (registers[2] != 0) {
            if (!memory_.write32(registers[2], action[0]) ||
                !memory_.write32(registers[2] + 4, action[2]) ||
                !memory_.write32(registers[2] + 8, action[3])) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
        if (registers[1] != 0) {
            for (std::size_t index = 0; index < action.size(); ++index) {
                const auto value = memory_.read32(
                    registers[1] + static_cast<std::uint32_t>(index * 4U));
                if (!value) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                action[index] = *value;
            }
        }
        bsd_success(cpu, 0);
        return;
    }
    case 48:
    case darwin::syscall::pthread_sigmask: {
        constexpr std::uint32_t unblockable =
            (1U << (9U - 1U)) | (1U << (17U - 1U));
        auto& signal_mask_ = signal_mask(cpu.processor_id());
        if (registers[2] != 0 && !memory_.write32(registers[2], signal_mask_)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (registers[1] != 0) {
            const auto requested = memory_.read32(registers[1]);
            if (!requested) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            switch (registers[0]) {
            case 1:
                signal_mask_ |= *requested;
                break;
            case 2:
                signal_mask_ &= ~*requested;
                break;
            case 3:
                signal_mask_ = *requested;
                break;
            default:
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            signal_mask_ &= ~unblockable;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 49: {
        if (registers[1] == 0 ||
            process_.login_name.size() + 1 > registers[1]) {
            bsd_error(cpu, 34);
            return;
        }
        std::vector<std::byte> bytes(process_.login_name.size() + 1);
        for (std::size_t index = 0; index < process_.login_name.size();
            ++index) {
            bytes[index] = static_cast<std::byte>(process_.login_name[index]);
        }
        if (!memory_.copy_in(registers[0], bytes)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 50: {
        const auto name = memory_.read_c_string(registers[0], 256);
        if (!name) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (name->size() >= 32) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        process_.login_name = *name;
        bsd_success(cpu, 0);
        return;
    }
    case 55:
        output_.write("[kernel] guest reboot request flags=0x" + [&] {
            std::ostringstream value;
            value << std::hex << registers[0];
            return value.str();
        }() + " denied\n");
        bsd_error(
            cpu, 1);
        return;
    case 60: {
        const auto previous = process_.file_creation_mask;
        process_.file_creation_mask = registers[0] & 0777U;
        bsd_success(cpu, previous);
        return;
    }
    case 59: {
        const auto path = memory_.read_c_string(registers[0]);
        const auto read_vector = [&](std::uint32_t address)
            -> std::optional<std::vector<std::string>> {
            std::vector<std::string> values;
            if (address == 0)
                return values;
            for (std::uint32_t index = 0; index < 4096; ++index) {
                const auto pointer = memory_.read32(address + index * 4U);
                if (!pointer)
                    return std::nullopt;
                if (*pointer == 0)
                    return values;
                const auto value = memory_.read_c_string(*pointer, 64U * 1024U);
                if (!value)
                    return std::nullopt;
                values.push_back(*value);
            }
            return std::nullopt;
        };
        const auto arguments = read_vector(registers[1]);
        const auto environment = read_vector(registers[2]);
        if (!path || !arguments || !environment) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::error_code path_error;
        const auto host_path = resolve_guest_path(*path);
        if (!std::filesystem::is_regular_file(host_path, path_error)) {
            bsd_error(cpu, 2);
            return;
        }
        std::ostringstream exec_message;
        exec_message << "[process] exec pid=" << process_.pid << " " << *path
                     << " argv=";
        for (std::size_t index = 0; index < arguments->size(); ++index) {
            if (index != 0)
                exec_message << ',';
            exec_message << '"' << (*arguments)[index] << '"';
        }
        exec_message << '\n';
        output_.write(exec_message.str());
        if (!exec_handler_ ||
            !exec_handler_(cpu, *path, *arguments, *environment)) {
            bsd_error(cpu, 2);
            return;
        }
        performance_counters().record_exec();
        cpu.halt(Dynarmic::HaltReason::UserDefined6);
        return;
    }
    case 96:
        if (registers[0] != 0 ||
            (registers[1] != 0 && registers[1] != process_.pid)) {
            bsd_error(cpu, bsd_support::invalid_argument);
        } else {
            process_.nice_value =
                std::clamp(static_cast<std::int32_t>(registers[2]),
                    darwin::resource::priority_minimum,
                    darwin::resource::priority_maximum);
            process_.thread_base_priority =
                xnu::scheduler::default_base_priority - process_.nice_value;
            {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                if (const auto record =
                        shared_state_->processes.find(process_.pid);
                    record != shared_state_->processes.end()) {
                    record->second.nice_value = process_.nice_value;
                }
            }
            if (task_priority_handler_) {
                task_priority_handler_(process_.thread_base_priority);
                if (scheduler_preemption_query_ &&
                    scheduler_preemption_query_(cpu.processor_id())) {
                    cpu.request_guest_preemption();
                }
            }
            bsd_success(cpu, 0);
        }
        return;
    case 116: {
        const auto wall_time = shared_state_->clock.wall_time();
        bsd_success(cpu,
            static_cast<std::uint32_t>(wall_time / 1'000'000'000ULL),
            static_cast<std::uint32_t>((wall_time / 1'000ULL) % 1'000'000ULL));
        return;
    }
    case darwin::syscall::get_resource_usage: {
        if (registers[0] != darwin::resource::rusage_self &&
            registers[0] != darwin::resource::rusage_children) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (registers[1] > std::numeric_limits<std::uint32_t>::max() -
                               darwin::resource::rusage_arm32_size + 1U) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        for (std::size_t index = 0;
            index < darwin::resource::rusage_arm32_word_count; ++index) {
            const auto address = registers[1] +
                static_cast<std::uint32_t>(index * sizeof(std::uint32_t));
            if (!memory_.write32(address, 0)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::set_time_of_day: {
        if (process_.effective_uid != 0) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return;
        }

        std::optional<std::pair<std::int64_t, std::int64_t>> requested_time;
        if (registers[0] != 0) {
            if (registers[0] > std::numeric_limits<std::uint32_t>::max() -
                                   sizeof(std::uint32_t)) {
                bsd_error(cpu, darwin::error::bad_address);
                return;
            }
            const auto seconds = memory_.read32(registers[0]);
            const auto microseconds =
                memory_.read32(registers[0] + sizeof(std::uint32_t));
            if (!seconds || !microseconds) {
                bsd_error(cpu, darwin::error::bad_address);
                return;
            }
            requested_time.emplace(static_cast<std::int32_t>(*seconds),
                static_cast<std::int32_t>(*microseconds));
        }

        if (registers[1] != 0) {
            if (registers[1] > std::numeric_limits<std::uint32_t>::max() -
                                   sizeof(std::uint32_t) ||
                !memory_.read32(registers[1]) ||
                !memory_.read32(registers[1] + sizeof(std::uint32_t))) {
                bsd_error(cpu, darwin::error::bad_address);
                return;
            }
        }

        if (requested_time) {
            auto [seconds, microseconds] = *requested_time;
            if (microseconds < 0) {
                --seconds;
                microseconds += 1'000'000;
            }
            if (microseconds >= 1'000'000) {
                ++seconds;
                microseconds -= 1'000'000;
            }
            if (seconds < 0 || microseconds < 0 || microseconds >= 1'000'000) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            const auto wall_time =
                static_cast<std::uint64_t>(seconds) *
                    VirtualClock::nanoseconds_per_second +
                static_cast<std::uint64_t>(microseconds) * 1'000ULL;
            shared_state_->clock.set_wall_time(wall_time);
            output_.write(
                "[clock] settimeofday pid=" + std::to_string(process_.pid) +
                " seconds=" + std::to_string(seconds) +
                " microseconds=" + std::to_string(microseconds) + "\n");
        }
        bsd_success(cpu, 0);
        return;
    }
    case 147:
        process_.process_group = process_.pid;
        process_.session_id = process_.pid;
        bsd_success(cpu, process_.pid);
        return;
    case darwin::syscall::get_resource_limit: {
        const auto resource = darwin::resource::selector(registers[0]);
        if (resource >= process_.resource_limits.size()) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (registers[1] > std::numeric_limits<std::uint32_t>::max() -
                               darwin::resource::arm32_limit_size + 1U) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto& limit = process_.resource_limits[resource];
        if (!memory_.write64(registers[1], limit.current) ||
            !memory_.write64(
                registers[1] + sizeof(std::uint64_t), limit.maximum)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::set_resource_limit: {
        const auto raw_resource = registers[0];
        const auto resource = darwin::resource::selector(raw_resource);
        if (resource >= process_.resource_limits.size()) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (registers[1] > std::numeric_limits<std::uint32_t>::max() -
                               darwin::resource::arm32_limit_size + 1U) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto requested_current = memory_.read64(registers[1]);
        const auto requested_maximum =
            memory_.read64(registers[1] + sizeof(std::uint64_t));
        if (!requested_current || !requested_maximum) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (*requested_current > *requested_maximum) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        auto& limit = process_.resource_limits[resource];
        if ((*requested_current > limit.maximum ||
                *requested_maximum > limit.maximum) &&
            process_.effective_uid != 0) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return;
        }
        auto maximum = *requested_maximum;
        auto current = *requested_current;
        if (resource == darwin::resource::open_files) {
            if (current != limit.current &&
                current > darwin::resource::maximum_open_files &&
                darwin::resource::requests_posix_behavior(raw_resource)) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            maximum = std::min(maximum, darwin::resource::maximum_open_files);
            current = std::min(current, maximum);
        }
        limit = darwin::resource::Limit { current, maximum };
        output_.write(
            "[process] setrlimit pid=" + std::to_string(process_.pid) +
            " resource=" + std::to_string(resource) +
            " current=" + std::to_string(current) +
            " maximum=" + std::to_string(maximum) + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::disable_thread_signal:
        disabled_thread_signals_.insert(cpu.processor_id());
        bsd_success(cpu, 0);
        return;
    case 333:
        bsd_success(cpu, 0);
        return;
    case darwin::syscall::semaphore_wait_signal: {
        std::optional<std::uint64_t> timeout_interval;
        if (registers[2] != 0) {
            const bool wide_seconds = shared_state_->darwin_abi.semaphore_wait_abi ==
                DarwinSemaphoreWaitAbi::InlineSeconds64;
            auto seconds = static_cast<std::uint64_t>(registers[4]);
            auto nanoseconds = registers[wide_seconds ? 6U : 5U];
            if (wide_seconds) {
                seconds |= static_cast<std::uint64_t>(registers[5]) << 32U;
                if (seconds > std::numeric_limits<std::uint32_t>::max()) {
                    seconds = std::numeric_limits<std::uint32_t>::max();
                    nanoseconds = 0;
                }
            }
            if (nanoseconds >= 1'000'000'000U) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto requested = seconds * 1'000'000'000ULL + nanoseconds;
            if (registers[3] != 0) {
                timeout_interval = requested;
            } else {
                const auto now = shared_state_->clock.wall_time();
                timeout_interval = requested > now ? requested - now : 0;
            }
        }
        wait_on_semaphore(
            cpu, registers[0], registers[1], timeout_interval, true);
        return;
    }
    case darwin::syscall::semaphore_wait_signal_timespec: {
        std::optional<std::uint64_t> timeout_interval;
        if (registers[2] != 0) {
            const auto seconds = memory_.read32(registers[4]);
            const auto nanoseconds = memory_.read32(registers[4] + 4U);
            if (!seconds || !nanoseconds || *nanoseconds >= 1'000'000'000U) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto requested =
                static_cast<std::uint64_t>(*seconds) * 1'000'000'000ULL +
                *nanoseconds;
            if (registers[3] != 0) {
                timeout_interval = requested;
            } else {
                const auto now = shared_state_->clock.wall_time();
                timeout_interval = requested > now ? requested - now : 0;
            }
        }
        wait_on_semaphore(
            cpu, registers[0], registers[1], timeout_interval, true);
        return;
    }
    case 327:
        bsd_success(cpu, 0);
        return;
    case 355: {
        for (std::uint32_t offset = 0; offset < 24; offset += 4) {
            if (!memory_.write32(
                    registers[0] + offset,
                    offset == 20 ? process_.audit_session_id : 0)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::pid_suspend:
    case darwin::syscall::pid_resume: {
        const auto target_pid = static_cast<std::int32_t>(registers[0]);
        const auto resume = number == darwin::syscall::pid_resume;
        std::vector<std::uint32_t> target_processes;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            if (target_pid == -1) {
                for (auto& [pid, record] : shared_state_->processes) {
                    if (record.exited || (resume && !record.pid_suspended) ||
                        (!resume && record.pid_suspended)) {
                        continue;
                    }
                    record.pid_suspended = !resume;
                    target_processes.push_back(pid);
                }
            } else if (target_pid <= 0) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            } else {
                const auto iterator = shared_state_->processes.find(
                    static_cast<std::uint32_t>(target_pid));
                if (iterator == shared_state_->processes.end() ||
                    iterator->second.exited) {
                    bsd_error(cpu, darwin::error::no_such_process);
                    return;
                }
                if (resume != iterator->second.pid_suspended) {
                    iterator->second.pid_suspended = !resume;
                    target_processes.push_back(
                        static_cast<std::uint32_t>(target_pid));
                }
            }
        }

        if (process_runnable_handler_) {
            for (const auto pid : target_processes)
                process_runnable_handler_(pid, resume);
        }
        output_.write(
            std::string { resume ? "[process] pid-resume" :
                                      "[process] pid-suspend" } +
            " caller=" + std::to_string(process_.pid) +
            " target=" + std::to_string(target_pid) + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::pid_hibernate: {
        const auto target_pid = static_cast<std::int32_t>(registers[0]);
        if (target_pid != -1) {
            bsd_error(cpu, darwin::error::permission_denied);
            return;
        }
        output_.write("[process] pid-hibernate caller=" +
                      std::to_string(process_.pid) + " target=-1\n");
        bsd_success(cpu, 0);
        return;
    }
    default:
        trace_unknown(cpu, "BSD syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }
}

}
