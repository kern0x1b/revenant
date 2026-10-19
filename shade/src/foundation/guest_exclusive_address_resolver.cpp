// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve shared exclusive-monitor addresses across guest address
// spaces.

#include "foundation/guest_exclusive_address_resolver.hpp"

#include <limits>
#include <mutex>
#include <stdexcept>

namespace shade {

void GuestExclusiveAddressResolver::bind(std::size_t processor_base,
    std::size_t processor_count, AddressSpace& memory)
{
    if (processor_count == 0 ||
        processor_count >
            std::numeric_limits<std::size_t>::max() - processor_base) {
        throw std::invalid_argument {
            "invalid exclusive monitor binding range"
        };
    }
    const auto end = processor_base + processor_count;
    const std::unique_lock lock { mutex_ };
    const auto next = bindings_.lower_bound(processor_base);
    if (next != bindings_.end() && next->first < end) {
        throw std::logic_error { "overlapping exclusive monitor binding" };
    }
    if (next != bindings_.begin()) {
        const auto previous = std::prev(next);
        if (previous->second.end > processor_base) {
            throw std::logic_error { "overlapping exclusive monitor binding" };
        }
    }
    bindings_.emplace(processor_base, Binding { end, &memory });
}

void GuestExclusiveAddressResolver::unbind(std::size_t processor_base,
    std::size_t processor_count, AddressSpace& memory) noexcept
{
    if (processor_count == 0 ||
        processor_count >
            std::numeric_limits<std::size_t>::max() - processor_base) {
        return;
    }
    const auto end = processor_base + processor_count;
    const std::unique_lock lock { mutex_ };
    const auto binding = bindings_.find(processor_base);
    if (binding != bindings_.end() && binding->second.end == end &&
        binding->second.memory == &memory) {
        bindings_.erase(binding);
    }
}

Umbra::VAddr GuestExclusiveAddressResolver::resolve(
    std::size_t processor_id, Umbra::VAddr address) const noexcept
{
    try {
        const std::shared_lock lock { mutex_ };
        const auto next = bindings_.upper_bound(processor_id);
        if (next == bindings_.begin())
            return address;
        const auto binding = std::prev(next);
        if (processor_id >= binding->second.end ||
            binding->second.memory == nullptr)
            return address;
        return binding->second.memory->exclusive_reservation_key(
            static_cast<std::uint32_t>(address));
    } catch (...) {
        return address;
    }
}

Umbra::VAddr GuestExclusiveAddressResolver::resolve_callback(
    void* context, std::size_t processor_id, Umbra::VAddr address) noexcept
{
    if (context == nullptr)
        return address;
    return static_cast<GuestExclusiveAddressResolver*>(context)->resolve(
        processor_id, address);
}

} // namespace shade
