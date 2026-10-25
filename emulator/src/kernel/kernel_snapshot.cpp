// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel.hpp"

#include "foundation/snapshot_io.hpp"

#include <filesystem>
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
}

}
