// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain indexed deadlines for scheduler-owned events without
// choosing a clock domain.

#pragma once

#include <functional>
#include <map>
#include <optional>
#include <set>
#include <utility>

namespace shade {

// Indexed deadline storage for scheduler-owned event sources. Updating one
// source removes its previous value in O(log n), while the earliest deadline
// is available in O(1). The queue is deliberately clock-agnostic: Guest
// absolute time and host steady-clock time can use the same structure without
// mixing their units.
template <typename Key, typename Deadline, typename KeyCompare = std::less<Key>>
class DeadlineQueue {
public:
    void upsert(const Key& key, Deadline deadline)
    {
        if (const auto existing = deadlines_.find(key);
            existing != deadlines_.end()) {
            if (existing->second == deadline)
                return;
            erase_from_order(key, existing->second);
            existing->second = deadline;
        } else {
            deadlines_.emplace(key, deadline);
        }
        order_[deadline].insert(key);
    }

    bool erase(const Key& key)
    {
        const auto existing = deadlines_.find(key);
        if (existing == deadlines_.end())
            return false;
        erase_from_order(key, existing->second);
        deadlines_.erase(existing);
        return true;
    }

    void clear()
    {
        deadlines_.clear();
        order_.clear();
    }

    [[nodiscard]] bool contains(const Key& key) const
    {
        return deadlines_.contains(key);
    }

    [[nodiscard]] std::optional<Deadline> next_deadline() const
    {
        if (order_.empty())
            return std::nullopt;
        return order_.begin()->first;
    }

    [[nodiscard]] std::size_t size() const { return deadlines_.size(); }

private:
    using KeyIndex = std::map<Key, Deadline, KeyCompare>;
    using DeadlineIndex = std::map<Deadline, std::set<Key, KeyCompare>>;

    void erase_from_order(const Key& key, const Deadline& deadline)
    {
        const auto deadline_entry = order_.find(deadline);
        if (deadline_entry == order_.end())
            return;
        deadline_entry->second.erase(key);
        if (deadline_entry->second.empty())
            order_.erase(deadline_entry);
    }

    KeyIndex deadlines_;
    DeadlineIndex order_;
};

} // namespace shade
