// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Host readiness for one probe pass: the host descriptors a pass asks about
// are polled together, so the pass makes one poll(2) call instead of one per
// descriptor.

#include "network/host_readiness.hpp"

namespace emulator {

namespace {

std::uint64_t slot_key(int descriptor, std::int16_t events)
{
    return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(descriptor))
               << 16) |
           static_cast<std::uint16_t>(events);
}

}

void HostReadinessProbe::request_readable(int descriptor)
{
    request(descriptor, POLLIN);
}

void HostReadinessProbe::request_writable(int descriptor)
{
    request(descriptor, POLLOUT);
}

void HostReadinessProbe::request(int descriptor, std::int16_t events)
{
    if (!slots_.try_emplace(slot_key(descriptor, events), requests_.size())
             .second) {
        return;
    }
    requests_.push_back(pollfd { descriptor, events, 0 });
}

void HostReadinessProbe::run()
{
    if (requests_.empty())
        return;
    for (auto& request : requests_)
        request.revents = 0;
    ::poll(requests_.data(), static_cast<nfds_t>(requests_.size()), 0);
}

std::optional<bool> HostReadinessProbe::readable(int descriptor) const
{
    return answer(descriptor, POLLIN);
}

std::optional<bool> HostReadinessProbe::writable(int descriptor) const
{
    return answer(descriptor, POLLOUT);
}

std::optional<bool> HostReadinessProbe::answer(int descriptor,
    std::int16_t events) const
{
    const auto slot = slots_.find(slot_key(descriptor, events));
    if (slot == slots_.end())
        return std::nullopt;
    const auto revents = requests_[slot->second].revents;
    return (revents & (events | POLLHUP | POLLERR)) != 0;
}

}
