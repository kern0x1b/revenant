// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel_shared_state.hpp"

#include "foundation/snapshot_io.hpp"

#include <atomic>

namespace emulator {

namespace {

template <typename T>
void load_atomic(snapshot::Reader& in, std::atomic<T>& value)
{
    T loaded { };
    snapshot::load(in, loaded);
    value.store(loaded);
}

}

void KernelSharedState::save_scalar_state(snapshot::Writer& out) const
{
    snapshot::save(out, hostname);
    snapshot::save(out, desired_vnodes);
    snapshot::save(out, next_kernel_event_identifier);
    snapshot::save(out, next_route_message_identifier);
    snapshot::save(out, next_route_socket_identifier);
    snapshot::save(out, next_mach_object);
    snapshot::save(out, next_mach_wait_queue_sequence);
    snapshot::save(out, mach_queue_generation.load());
    snapshot::save(out, kernel_event_generation.load());
    snapshot::save(out, shared_timer_deadline_cache_generation);
    snapshot::save(out, shared_timer_deadline_cache);
    snapshot::save(out, shared_timer_deadline_cache_valid);
    snapshot::save(out, io_event_generation.load());
    snapshot::save(out, next_graphics_input_sequence);
    snapshot::save(out, next_application_launch_token);
    snapshot::save(out, next_process_incarnation);
    snapshot::save(out, next_audit_identity_version);
    snapshot::save(out, next_foreground_transition_generation);
    snapshot::save(out, next_foreground_layer_sequence);
    snapshot::save(out, next_clock_alarm);
    snapshot::save(out, next_keybag_handle);
    snapshot::save(out, wifi_service_available);
    snapshot::save(out, next_socket_pair);
    snapshot::save(out, next_shared_memory_object);
}

void KernelSharedState::load_scalar_state(snapshot::Reader& in)
{
    snapshot::load(in, hostname);
    snapshot::load(in, desired_vnodes);
    snapshot::load(in, next_kernel_event_identifier);
    snapshot::load(in, next_route_message_identifier);
    snapshot::load(in, next_route_socket_identifier);
    snapshot::load(in, next_mach_object);
    snapshot::load(in, next_mach_wait_queue_sequence);
    load_atomic(in, mach_queue_generation);
    load_atomic(in, kernel_event_generation);
    snapshot::load(in, shared_timer_deadline_cache_generation);
    snapshot::load(in, shared_timer_deadline_cache);
    snapshot::load(in, shared_timer_deadline_cache_valid);
    load_atomic(in, io_event_generation);
    snapshot::load(in, next_graphics_input_sequence);
    snapshot::load(in, next_application_launch_token);
    snapshot::load(in, next_process_incarnation);
    snapshot::load(in, next_audit_identity_version);
    snapshot::load(in, next_foreground_transition_generation);
    snapshot::load(in, next_foreground_layer_sequence);
    snapshot::load(in, next_clock_alarm);
    snapshot::load(in, next_keybag_handle);
    snapshot::load(in, wifi_service_available);
    snapshot::load(in, next_socket_pair);
    snapshot::load(in, next_shared_memory_object);
}

}
