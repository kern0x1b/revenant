// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve shared exclusive-monitor addresses across guest address
// spaces.

#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <shared_mutex>

#include <umbra/interface/exclusive_monitor.h>

#include "foundation/address_space.hpp"

namespace shade {

// Maps Umbra's globally unique processor slots back to the AddressSpace
// that owns the Guest virtual address. The resolver is shared by all runtime
// clusters that use one process-wide ExclusiveMonitor.
class GuestExclusiveAddressResolver {
public:
    void bind(std::size_t processor_base, std::size_t processor_count,
        AddressSpace& memory);
    void unbind(std::size_t processor_base, std::size_t processor_count,
        AddressSpace& memory) noexcept;

    [[nodiscard]] Umbra::VAddr resolve(
        std::size_t processor_id, Umbra::VAddr address) const noexcept;

    static Umbra::VAddr resolve_callback(void* context,
        std::size_t processor_id, Umbra::VAddr address) noexcept;

private:
    struct Binding {
        std::size_t end { };
        AddressSpace* memory { };
    };

    mutable std::shared_mutex mutex_;
    std::map<std::size_t, Binding> bindings_;
};

} // namespace shade
