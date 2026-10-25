// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel.hpp"

#include "foundation/snapshot_io.hpp"

#include <filesystem>
#include <map>
#include <string>

namespace emulator {

namespace {

template <typename Container>
void refuse_if_populated(const char* member, const Container& container)
{
    if (!container.empty())
        throw snapshot::RefusedError { member };
}

template <typename Container>
void reject_if_populated(const char* member, const Container& container)
{
    if (!container.empty())
        throw snapshot::FormatError {
            std::string { member } + " is populated in the restored kernel"
        };
}

void save_pthread_registration(snapshot::Writer& out,
    const std::optional<DarwinPthreadRegistration>& registration)
{
    snapshot::save(out, registration.has_value());
    if (!registration)
        return;
    snapshot::save(out, registration->thread_start);
    snapshot::save(out, registration->workqueue_thread_start);
    snapshot::save(out, registration->pthread_size);
    snapshot::save(out, registration->reserved);
    snapshot::save(out, registration->target_concurrency);
    snapshot::save(out, registration->dispatch_queue_offset);
}

std::optional<DarwinPthreadRegistration> load_pthread_registration(
    snapshot::Reader& in)
{
    bool present { };
    snapshot::load(in, present);
    if (!present)
        return std::nullopt;
    DarwinPthreadRegistration registration;
    snapshot::load(in, registration.thread_start);
    snapshot::load(in, registration.workqueue_thread_start);
    snapshot::load(in, registration.pthread_size);
    snapshot::load(in, registration.reserved);
    snapshot::load(in, registration.target_concurrency);
    snapshot::load(in, registration.dispatch_queue_offset);
    return registration;
}

void save_process_context(snapshot::Writer& out, const ProcessContext& process)
{
    snapshot::save(out, process.pid);
    snapshot::save(out, process.parent_pid);
    snapshot::save(out, process.process_group);
    snapshot::save(out, process.session_id);
    snapshot::save(out, process.audit_session_id);
    snapshot::save(out, process.uid);
    snapshot::save(out, process.effective_uid);
    snapshot::save(out, process.gid);
    snapshot::save(out, process.effective_gid);
    snapshot::save(out, process.file_creation_mask);
    for (const auto& limit : process.resource_limits) {
        snapshot::save(out, limit.current);
        snapshot::save(out, limit.maximum);
    }
    snapshot::save(out, process.login_name);
    snapshot::save(out, process.task_port);
    snapshot::save(out, process.thread_port);
    snapshot::save(out, process.host_port);
    snapshot::save(out, process.bootstrap_port);
    snapshot::save(out, process.clock_port);
    snapshot::save(out, process.calendar_clock_port);
    snapshot::save(out, process.io_master_port);
    snapshot::save(out, process.io_registry_options_port);
    snapshot::save(out, process.thread_base_priority);
    snapshot::save(out, process.nice_value);
    snapshot::save(out, process.disk_io_policy);
    snapshot::save(out, process.thread_disk_io_policies);
    snapshot::save(out, process.exited);
    snapshot::save(out, process.waiting_for_events);
    snapshot::save(out, process.exit_status);
    snapshot::save(out, process.termination_signal);
}

void load_process_context(snapshot::Reader& in, ProcessContext& process)
{
    snapshot::load(in, process.pid);
    snapshot::load(in, process.parent_pid);
    snapshot::load(in, process.process_group);
    snapshot::load(in, process.session_id);
    snapshot::load(in, process.audit_session_id);
    snapshot::load(in, process.uid);
    snapshot::load(in, process.effective_uid);
    snapshot::load(in, process.gid);
    snapshot::load(in, process.effective_gid);
    snapshot::load(in, process.file_creation_mask);
    for (auto& limit : process.resource_limits) {
        snapshot::load(in, limit.current);
        snapshot::load(in, limit.maximum);
    }
    snapshot::load(in, process.login_name);
    snapshot::load(in, process.task_port);
    snapshot::load(in, process.thread_port);
    snapshot::load(in, process.host_port);
    snapshot::load(in, process.bootstrap_port);
    snapshot::load(in, process.clock_port);
    snapshot::load(in, process.calendar_clock_port);
    snapshot::load(in, process.io_master_port);
    snapshot::load(in, process.io_registry_options_port);
    snapshot::load(in, process.thread_base_priority);
    snapshot::load(in, process.nice_value);
    snapshot::load(in, process.disk_io_policy);
    snapshot::load(in, process.thread_disk_io_policies);
    snapshot::load(in, process.exited);
    snapshot::load(in, process.waiting_for_events);
    snapshot::load(in, process.exit_status);
    snapshot::load(in, process.termination_signal);
}

}

void CompatibilityKernel::save_kernel_bookkeeping(snapshot::Writer& out) const
{
    refuse_if_populated("ck.aio_completions_", aio_completions_);
    refuse_if_populated("ck.host_sockets_", host_sockets_);
    refuse_if_populated("ck.pending_baseband_writes_", pending_baseband_writes_);
    refuse_if_populated("ck.pending_flocks_", pending_flocks_);
    refuse_if_populated("ck.pending_host_accepts_", pending_host_accepts_);
    refuse_if_populated("ck.pending_host_connects_", pending_host_connects_);
    refuse_if_populated("ck.pending_host_writes_", pending_host_writes_);
    refuse_if_populated("ck.pending_io_poll_cache_", pending_io_poll_cache_);
    refuse_if_populated("ck.pending_kevents_", pending_kevents_);
    refuse_if_populated("ck.pending_mach_receives_", pending_mach_receives_);
    refuse_if_populated("ck.pending_polls_", pending_polls_);
    refuse_if_populated("ck.pending_psynch_waits_", pending_psynch_waits_);
    refuse_if_populated("ck.pending_record_locks_", pending_record_locks_);
    refuse_if_populated("ck.pending_recvmsgs_", pending_recvmsgs_);
    refuse_if_populated("ck.pending_selects_", pending_selects_);
    refuse_if_populated("ck.pending_semaphore_waits_", pending_semaphore_waits_);
    refuse_if_populated("ck.pending_signal_suspends_", pending_signal_suspends_);
    refuse_if_populated("ck.pending_socket_reads_", pending_socket_reads_);
    refuse_if_populated("ck.pending_timers_", pending_timers_);
    refuse_if_populated("ck.pending_unix_accepts_", pending_unix_accepts_);
    refuse_if_populated("ck.pending_waits_", pending_waits_);
    refuse_if_populated("ck.scheduler_handoffs_", scheduler_handoffs_);
    refuse_if_populated("ck.scheduler_yields_", scheduler_yields_);
    refuse_if_populated("ck.regular_file_open_descriptions_", regular_file_open_descriptions_);
    refuse_if_populated("ck.baseband_open_descriptions_", baseband_open_descriptions_);
    refuse_if_populated("ck.kqueues_", kqueues_);
    refuse_if_populated("ck.socket_pair_endpoints_", socket_pair_endpoints_);
    snapshot::save(out, guest_working_directory_.string());
    snapshot::save(out, process_image_);
    snapshot::save(out, thread_ports_);
    snapshot::save(out, thread_signal_masks_);
    snapshot::save(out, thread_pending_signals_);
    snapshot::save(out, random_state_);
    snapshot::save(out, virtual_processor_count_);
    snapshot::save(out, next_load_average_sample_);
    snapshot::save(out, pending_event_processors_);
    snapshot::save(out, pending_event_topology_generation_);
    snapshot::save(out, pending_event_poll_topology_generation_);
    snapshot::save(out, pending_event_poll_io_generation_);
    snapshot::save(out, pending_event_poll_mach_generation_);
    snapshot::save(out, pending_event_poll_deadline_);
    snapshot::save(out, pending_event_poll_observed_);
    snapshot::save(out, local_timer_deadline_cache_);
    snapshot::save(out, local_timer_deadline_cache_valid_);
    snapshot::save(out, dyld_shared_cache_path_.string());
    snapshot::save(out, dyld_shared_cache_attempted_);
    snapshot::save(out, timer_trace_count_);
    snapshot::save(out, port_status_trace_count_);
    snapshot::save(out, thread_trace_count_);
    snapshot::save(out, mapping_trace_count_);
    snapshot::save(out, socket_payload_trace_count_);
    snapshot::save(out, semaphore_wait_trace_count_);
    snapshot::save(out, psynch_trace_count_);
    snapshot::save(out, baseband_io_trace_count_);
    snapshot::save(out, signal_actions_);
    snapshot::save(out, disabled_thread_signals_);
    snapshot::save(out, static_cast<std::uint64_t>(alternate_signal_stacks_.size()));
    for (const auto& [key, stack] : alternate_signal_stacks_) {
        snapshot::save(out, key);
        snapshot::save(out, stack.base);
        snapshot::save(out, stack.size);
        snapshot::save(out, stack.disabled);
        snapshot::save(out, stack.active);
    }
    snapshot::save(out, pending_signals_);
    snapshot::save(out, last_delivered_graphics_inputs_);
    snapshot::save(out, next_display_scanout_deadline_);
    snapshot::save(out, vm_purgable_states_);
    snapshot::save(out, apple80211_scan_delivered_);
    std::map<std::uint32_t, std::string> file_paths;
    for (const auto& [fd, path] : file_descriptors_)
        file_paths.emplace(fd, path.string());
    snapshot::save(out, file_paths);
    snapshot::save(out, file_offsets_);
    snapshot::save(out, file_status_flags_);
    snapshot::save(out, descriptor_flags_);
    snapshot::save(out, duplicated_descriptors_);
    snapshot::save(out, posix_semaphore_descriptors_);
    const std::map<std::uint32_t, std::string> virtual_names {
        virtual_descriptors_.begin(), virtual_descriptors_.end()
    };
    snapshot::save(out, virtual_names);
    snapshot::save(out, static_cast<std::uint64_t>(descriptor_guards_.size()));
    for (const auto& [fd, guard] : descriptor_guards_) {
        snapshot::save(out, fd);
        snapshot::save(out, guard.identifier);
        snapshot::save(out, guard.flags);
    }
    snapshot::save(out, bound_socket_names_);
    snapshot::save(out, listening_sockets_);
    snapshot::save(out, virtual_block_descriptors_);
    snapshot::save(out, system_event_filters_);
    snapshot::save(out, system_event_next_identifiers_);
    snapshot::save(out, static_cast<std::uint64_t>(scheduled_wifi_driver_events_.size()));
    for (const auto& [deadline, event] : scheduled_wifi_driver_events_) {
        snapshot::save(out, deadline);
        snapshot::save(out, event);
    }
    snapshot::save(out, load_average_.ldavg);
    snapshot::save(out, load_average_.fscale);
    save_process_context(out, process_);
    offline_serial_state_.save(out);
    save_pthread_registration(out, pthread_runtime_.registration());
}

void CompatibilityKernel::load_kernel_bookkeeping(snapshot::Reader& in)
{
    reject_if_populated("ck.aio_completions_", aio_completions_);
    reject_if_populated("ck.host_sockets_", host_sockets_);
    reject_if_populated("ck.pending_baseband_writes_", pending_baseband_writes_);
    reject_if_populated("ck.pending_flocks_", pending_flocks_);
    reject_if_populated("ck.pending_host_accepts_", pending_host_accepts_);
    reject_if_populated("ck.pending_host_connects_", pending_host_connects_);
    reject_if_populated("ck.pending_host_writes_", pending_host_writes_);
    reject_if_populated("ck.pending_io_poll_cache_", pending_io_poll_cache_);
    reject_if_populated("ck.pending_kevents_", pending_kevents_);
    reject_if_populated("ck.pending_mach_receives_", pending_mach_receives_);
    reject_if_populated("ck.pending_polls_", pending_polls_);
    reject_if_populated("ck.pending_psynch_waits_", pending_psynch_waits_);
    reject_if_populated("ck.pending_record_locks_", pending_record_locks_);
    reject_if_populated("ck.pending_recvmsgs_", pending_recvmsgs_);
    reject_if_populated("ck.pending_selects_", pending_selects_);
    reject_if_populated("ck.pending_semaphore_waits_", pending_semaphore_waits_);
    reject_if_populated("ck.pending_signal_suspends_", pending_signal_suspends_);
    reject_if_populated("ck.pending_socket_reads_", pending_socket_reads_);
    reject_if_populated("ck.pending_timers_", pending_timers_);
    reject_if_populated("ck.pending_unix_accepts_", pending_unix_accepts_);
    reject_if_populated("ck.pending_waits_", pending_waits_);
    reject_if_populated("ck.scheduler_handoffs_", scheduler_handoffs_);
    reject_if_populated("ck.scheduler_yields_", scheduler_yields_);
    reject_if_populated("ck.regular_file_open_descriptions_", regular_file_open_descriptions_);
    reject_if_populated("ck.baseband_open_descriptions_", baseband_open_descriptions_);
    reject_if_populated("ck.kqueues_", kqueues_);
    reject_if_populated("ck.socket_pair_endpoints_", socket_pair_endpoints_);
    std::string guest_working_directory;
    snapshot::load(in, guest_working_directory);
    guest_working_directory_ = std::filesystem::path { guest_working_directory };
    snapshot::load(in, process_image_);
    snapshot::load(in, thread_ports_);
    snapshot::load(in, thread_signal_masks_);
    snapshot::load(in, thread_pending_signals_);
    snapshot::load(in, random_state_);
    snapshot::load(in, virtual_processor_count_);
    snapshot::load(in, next_load_average_sample_);
    snapshot::load(in, pending_event_processors_);
    snapshot::load(in, pending_event_topology_generation_);
    snapshot::load(in, pending_event_poll_topology_generation_);
    snapshot::load(in, pending_event_poll_io_generation_);
    snapshot::load(in, pending_event_poll_mach_generation_);
    snapshot::load(in, pending_event_poll_deadline_);
    snapshot::load(in, pending_event_poll_observed_);
    snapshot::load(in, local_timer_deadline_cache_);
    snapshot::load(in, local_timer_deadline_cache_valid_);
    std::string dyld_shared_cache_path;
    snapshot::load(in, dyld_shared_cache_path);
    dyld_shared_cache_path_ = std::filesystem::path { dyld_shared_cache_path };
    snapshot::load(in, dyld_shared_cache_attempted_);
    snapshot::load(in, timer_trace_count_);
    snapshot::load(in, port_status_trace_count_);
    snapshot::load(in, thread_trace_count_);
    snapshot::load(in, mapping_trace_count_);
    snapshot::load(in, socket_payload_trace_count_);
    snapshot::load(in, semaphore_wait_trace_count_);
    snapshot::load(in, psynch_trace_count_);
    snapshot::load(in, baseband_io_trace_count_);
    snapshot::load(in, signal_actions_);
    snapshot::load(in, disabled_thread_signals_);
    alternate_signal_stacks_.clear();
    std::uint64_t alternate_signal_stack_count { };
    snapshot::load(in, alternate_signal_stack_count);
    for (std::uint64_t index = 0; index < alternate_signal_stack_count; ++index) {
        std::size_t key { };
        AlternateSignalStack stack;
        snapshot::load(in, key);
        snapshot::load(in, stack.base);
        snapshot::load(in, stack.size);
        snapshot::load(in, stack.disabled);
        snapshot::load(in, stack.active);
        alternate_signal_stacks_.emplace(key, stack);
    }
    snapshot::load(in, pending_signals_);
    snapshot::load(in, last_delivered_graphics_inputs_);
    snapshot::load(in, next_display_scanout_deadline_);
    snapshot::load(in, vm_purgable_states_);
    snapshot::load(in, apple80211_scan_delivered_);
    std::map<std::uint32_t, std::string> file_paths;
    snapshot::load(in, file_paths);
    file_descriptors_.clear();
    for (const auto& [fd, path] : file_paths)
        file_descriptors_.emplace(fd, std::filesystem::path { path });
    snapshot::load(in, file_offsets_);
    snapshot::load(in, file_status_flags_);
    snapshot::load(in, descriptor_flags_);
    snapshot::load(in, duplicated_descriptors_);
    snapshot::load(in, posix_semaphore_descriptors_);
    std::map<std::uint32_t, std::string> virtual_names;
    snapshot::load(in, virtual_names);
    virtual_descriptors_.clear();
    virtual_descriptors_.insert(virtual_names.begin(), virtual_names.end());
    descriptor_guards_.clear();
    std::uint64_t guard_count { };
    snapshot::load(in, guard_count);
    for (std::uint64_t index = 0; index < guard_count; ++index) {
        std::uint32_t fd { };
        DarwinFileGuard guard { };
        snapshot::load(in, fd);
        snapshot::load(in, guard.identifier);
        snapshot::load(in, guard.flags);
        descriptor_guards_.emplace(fd, guard);
    }
    snapshot::load(in, bound_socket_names_);
    snapshot::load(in, listening_sockets_);
    snapshot::load(in, virtual_block_descriptors_);
    snapshot::load(in, system_event_filters_);
    snapshot::load(in, system_event_next_identifiers_);
    scheduled_wifi_driver_events_.clear();
    std::uint64_t scheduled_event_count { };
    snapshot::load(in, scheduled_event_count);
    for (std::uint64_t index = 0; index < scheduled_event_count; ++index) {
        std::uint64_t deadline { };
        std::uint32_t event { };
        snapshot::load(in, deadline);
        snapshot::load(in, event);
        scheduled_wifi_driver_events_.emplace(deadline, event);
    }
    snapshot::load(in, load_average_.ldavg);
    snapshot::load(in, load_average_.fscale);
    load_process_context(in, process_);
    offline_serial_state_.load(in);
    pthread_runtime_.restore_registration(load_pthread_registration(in));
}

void CompatibilityKernel::save_snapshot(snapshot::Writer& out) const
{
    save_kernel_bookkeeping(out);
    shared_state_->save_scalar_state(out);
    shared_state_->clock.save(out);
    shared_state_->save_port_and_event_tables(out);
    shared_state_->save_process_table(out);
    shared_state_->save_key_store_identity(out);
    shared_state_->save_service_tables(out);
    display_state_->save(out);
    surface_store_->save(out);
    wifi_state_->save(out);
    darwin_notify_state_hle_.save(out);
    hid_event_system_hle_.save(out);
    userland_hle_.save(out);
    mobile_framebuffer_hle_.save(out);
    mbx2d_hle_.save(out);
    opengles_hle_.save(out);
    core_audio_hle_.save(out);
    snapshot::save(out, shared_state_->launchd_job_catalog.has_value());
}

void CompatibilityKernel::load_snapshot(snapshot::Reader& in)
{
    load_kernel_bookkeeping(in);
    shared_state_->load_scalar_state(in);
    shared_state_->clock.load(in);
    shared_state_->load_port_and_event_tables(in);
    shared_state_->load_process_table(in);
    shared_state_->load_key_store_identity(in);
    shared_state_->load_service_tables(in);
    display_state_->load(in);
    surface_store_->load(in);
    wifi_state_->load(in);
    darwin_notify_state_hle_.load(in);
    hid_event_system_hle_.load(in);
    userland_hle_.load(in);
    mobile_framebuffer_hle_.load(in);
    mbx2d_hle_.load(in);
    opengles_hle_.load(in);
    core_audio_hle_.load(in);
    bool launchd_job_catalog_loaded { };
    snapshot::load(in, launchd_job_catalog_loaded);
    if (dyld_shared_cache_attempted_)
        static_cast<void>(dyld_shared_cache_for(dyld_shared_cache_path_));
    if (launchd_job_catalog_loaded) {
        std::call_once(shared_state_->launchd_job_catalog_once, [this] {
            shared_state_->launchd_job_catalog =
                LaunchdJobCatalog::load(rootfs_);
        });
    }
}

}
