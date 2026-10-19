// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Release guest file descriptors and close-on-exec resources.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_descrip.c

#include "kernel/kernel.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace shade {

bool CompatibilityKernel::release_file_descriptor(std::uint32_t descriptor)
{
    release_record_locks_for_descriptor(descriptor);
    const auto erased = file_descriptors_.erase(descriptor) +
                        virtual_descriptors_.erase(descriptor) +
                        baseband_open_descriptions_.erase(descriptor) +
                        duplicated_descriptors_.erase(descriptor);
    posix_semaphore_descriptors_.erase(descriptor);
    if (erased != 0)
        detach_kevents_for_descriptor(descriptor);
    file_offsets_.erase(descriptor);
    regular_file_open_descriptions_.erase(descriptor);
    file_status_flags_.erase(descriptor);
    virtual_block_descriptors_.erase(descriptor);
    bpf_descriptors_.erase(descriptor);
    descriptor_flags_.erase(descriptor);
    descriptor_guards_.erase(descriptor);
    host_sockets_.erase(descriptor);
    wifi_driver_event_streams_.erase(descriptor);
    virtual_udp_sockets_.erase(descriptor);
    kernel_control_endpoints_.erase(descriptor);
    system_event_filters_.erase(descriptor);
    apple80211_scan_delivered_.erase(descriptor);
    system_event_next_identifiers_.erase(descriptor);
    route_socket_states_.erase(descriptor);
    // This may destroy the final listening open description. Its queued
    // endpoints then close and clients observe the resulting stream state.
    unix_listener_states_.erase(descriptor);
    socket_pair_endpoints_.erase(descriptor);
    kqueues_.erase(descriptor);
    bound_socket_names_.erase(descriptor);
    listening_sockets_.erase(descriptor);
    socket_options_.erase(descriptor);
    if (erased != 0)
        shared_state_->note_io_event_transition();
    return erased != 0;
}

void CompatibilityKernel::release_close_on_exec_descriptors()
{
    std::vector<std::uint32_t> descriptors;
    descriptors.reserve(descriptor_flags_.size());
    for (const auto& [descriptor, flags] : descriptor_flags_) {
        if ((flags & 1U) != 0U)
            descriptors.push_back(descriptor);
    }
    for (const auto descriptor : descriptors)
        static_cast<void>(release_file_descriptor(descriptor));
    if (!descriptors.empty()) {
        output_.write(
            "[process] exec close-on-exec pid=" + std::to_string(process_.pid) +
            " count=" + std::to_string(descriptors.size()) + "\n");
    }
}

} // namespace shade
