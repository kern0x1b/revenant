// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt EVFILT_MACHPORT's nonblocking receive to the shared Mach copyout path.

#include "kernel/kernel.hpp"
#include "kernel/darwin_abi.hpp"
#include "support.hpp"

#include <cstdint>
#include <mutex>
#include <optional>

namespace shade {

std::optional<CompatibilityKernel::MachReceiveResult>
CompatibilityKernel::receive_kevent_mach_message(
    const KeventRegistration& registration, std::size_t processor,
    bool waking_blocked_receiver)
{
    if (registration.extension[0] > UINT32_MAX ||
        registration.extension[1] > UINT32_MAX)
        return MachReceiveResult { darwin::mach_message::receive_invalid_data };

    const std::lock_guard mach_lock { shared_state_->mach_mutex };
    const auto name = static_cast<std::uint32_t>(registration.ident);
    const auto object = mach_support::resolve_receive_object(
        *shared_state_, process_.pid, name);
    if (!object)
        return MachReceiveResult { darwin::mach_message::receive_invalid_name };

    // XNU permits receive/large/trailer options here, never a send or a wait.
    constexpr std::uint32_t trailer_mask = 0xff00'0000U;
    const auto options = registration.filter_flags &
        (darwin::mach_message::option_receive |
            darwin::mach_message::option_receive_large | trailer_mask);
    PendingMachReceive receive {
        .message_address = static_cast<std::uint32_t>(registration.extension[0]),
        .receive_size = static_cast<std::uint32_t>(registration.extension[1]),
        .receive_name = name,
        .options = options,
        .processor = processor,
        .receive_object = object,
        .receive_is_port_set = shared_state_->mach_port_sets.contains(*object),
    };
    // Leave an older blocked Mach receiver's FIFO position intact. An empty
    // queue returns no kevent; this transient receive never enters the wait map.
    return receive_mach_message_locked(receive, false, waking_blocked_receiver);
}

} // namespace shade
