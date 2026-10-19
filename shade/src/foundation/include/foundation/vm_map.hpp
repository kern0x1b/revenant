// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest virtual-memory intervals, protections and mapping
// operations.

#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <optional>

#include "foundation/memory_permission.hpp"

namespace shade {

enum class VmInheritance : std::uint8_t {
    Share = 0,
    Copy = 1,
    None = 2,
};

// Compact, non-overlapping vm_map-style metadata. Callers retain their own
// synchronization; this class only owns mapping, protection, and fork
// inheritance intervals.
class VmMap {
public:
    struct MappingRegion {
        std::uint32_t address { };
        std::uint64_t end { };
        MemoryPermission permissions { MemoryPermission::None };
        VmInheritance inheritance { VmInheritance::Copy };
    };

    void map_or(std::uint32_t start, std::uint64_t end,
        MemoryPermission permissions,
        VmInheritance inheritance = VmInheritance::Copy);
    void unmap(std::uint32_t start, std::uint64_t end);
    [[nodiscard]] bool protect(
        std::uint32_t start, std::uint64_t end, MemoryPermission permissions);
    [[nodiscard]] bool inherit(std::uint32_t start, std::uint64_t end,
        VmInheritance inheritance);

    [[nodiscard]] bool accessible(
        std::uint32_t start, std::uint64_t end, MemoryPermission access) const;
    [[nodiscard]] bool overlaps(std::uint32_t start, std::uint64_t end) const;
    [[nodiscard]] std::optional<MappingRegion> region_at_or_after(
        std::uint32_t address) const;
    [[nodiscard]] std::size_t page_count(std::uint32_t page_size) const;
    [[nodiscard]] std::size_t region_count() const { return regions_.size(); }
    void clear() { regions_.clear(); }

private:
    struct Region {
        std::uint64_t end { };
        MemoryPermission permissions { MemoryPermission::None };
        VmInheritance inheritance { VmInheritance::Copy };
    };

    void split_at(std::uint64_t point);
    void coalesce();

    std::map<std::uint32_t, Region> regions_;
};

} // namespace shade
