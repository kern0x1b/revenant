// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel.hpp"

#include "foundation/snapshot_io.hpp"

#include <filesystem>
#include <string>

namespace emulator {

void CompatibilityKernel::save_kernel_bookkeeping(snapshot::Writer& out) const
{
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
}

void CompatibilityKernel::load_kernel_bookkeeping(snapshot::Reader& in)
{
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
}

}
