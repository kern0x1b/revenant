// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Bookkeeping for a surface's attribute values and use count: the list of
// retained key and value objects that IOSurfaceSetValue and friends keep, and
// the counter that IOSurfaceIncrementUseCount and friends move.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

namespace emulator {

class SurfaceAttributes {
public:
    struct Entry {
        std::uint32_t key { };
        std::uint32_t value { };
    };

    [[nodiscard]] std::size_t size() const noexcept { return entries_.size(); }

    [[nodiscard]] const Entry& at(std::size_t index) const
    {
        return entries_.at(index);
    }

    void append(std::uint32_t key, std::uint32_t value)
    {
        entries_.push_back(Entry { key, value });
    }

    // Callers may hold an index across a re-entrant guest call, so an index that
    // no longer exists is ignored rather than trusted.
    void replace(std::size_t index, std::uint32_t key, std::uint32_t value)
    {
        if (index < entries_.size())
            entries_[index] = Entry { key, value };
    }

    void erase(std::size_t index)
    {
        if (index < entries_.size())
            entries_.erase(entries_.begin() + static_cast<std::ptrdiff_t>(index));
    }

    [[nodiscard]] std::optional<std::size_t> find_key(std::uint32_t key) const
    {
        for (std::size_t index = 0; index < entries_.size(); ++index) {
            if (entries_[index].key == key)
                return index;
        }
        return std::nullopt;
    }

private:
    std::vector<Entry> entries_;
};

class SurfaceUseCount {
public:
    void increment() noexcept { ++count_; }

    void decrement() noexcept
    {
        if (count_ != 0)
            --count_;
    }

    [[nodiscard]] std::uint32_t count() const noexcept { return count_; }

    [[nodiscard]] bool in_use() const noexcept { return count_ != 0; }

private:
    std::uint32_t count_ { };
};

}
