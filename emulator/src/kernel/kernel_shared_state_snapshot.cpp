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

void save_kernel_event(
    snapshot::Writer& out, const KernelSharedState::KernelEvent& event)
{
    snapshot::save(out, event.identifier);
    snapshot::save(out, event.vendor);
    snapshot::save(out, event.event_class);
    snapshot::save(out, event.event_subclass);
    snapshot::save(out, event.event_code);
    snapshot::save(out, event.bytes);
}

KernelSharedState::KernelEvent load_kernel_event(snapshot::Reader& in)
{
    KernelSharedState::KernelEvent event;
    snapshot::load(in, event.identifier);
    snapshot::load(in, event.vendor);
    snapshot::load(in, event.event_class);
    snapshot::load(in, event.event_subclass);
    snapshot::load(in, event.event_code);
    snapshot::load(in, event.bytes);
    return event;
}

void save_kevent_state(
    snapshot::Writer& out, const KernelSharedState::ProcessKeventState& state)
{
    snapshot::save(out, state.exec_generation);
    snapshot::save(out, state.exit_generation);
    snapshot::save(out, state.wait_status);
}

KernelSharedState::ProcessKeventState load_kevent_state(snapshot::Reader& in)
{
    KernelSharedState::ProcessKeventState state;
    snapshot::load(in, state.exec_generation);
    snapshot::load(in, state.exit_generation);
    snapshot::load(in, state.wait_status);
    return state;
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

void KernelSharedState::save_port_and_event_tables(snapshot::Writer& out) const
{
    snapshot::save(out, mach_kernel_send_rights);
    snapshot::save(out, task_port_pids);
    snapshot::save(out, static_cast<std::uint64_t>(kernel_events.size()));
    for (const auto& event : kernel_events)
        save_kernel_event(out, event);
    snapshot::save(
        out, static_cast<std::uint64_t>(process_kevent_states.size()));
    for (const auto& [pid, state] : process_kevent_states) {
        snapshot::save(out, pid);
        save_kevent_state(out, state);
    }
}

void KernelSharedState::load_port_and_event_tables(snapshot::Reader& in)
{
    snapshot::load(in, mach_kernel_send_rights);
    snapshot::load(in, task_port_pids);
    std::uint64_t event_count { };
    snapshot::load(in, event_count);
    kernel_events.clear();
    for (std::uint64_t index = 0; index < event_count; ++index)
        kernel_events.push_back(load_kernel_event(in));
    std::uint64_t kevent_count { };
    snapshot::load(in, kevent_count);
    process_kevent_states.clear();
    for (std::uint64_t index = 0; index < kevent_count; ++index) {
        std::uint32_t pid { };
        snapshot::load(in, pid);
        if (!process_kevent_states.emplace(pid, load_kevent_state(in)).second)
            throw snapshot::FormatError { "snapshot repeats a kevent state" };
    }
}

}
