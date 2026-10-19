// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage task-local Mach names, rights and user-reference counts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_entry.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_space.h

#include "mach/mach_namespace.hpp"

#include <algorithm>
#include <limits>

namespace shade::xnu::ipc {
namespace {

    constexpr std::size_t right_count = 5;
    constexpr MachTypeMask reference_counted_types =
        type_mask(Right::Send) | type_mask(Right::DeadName);

    constexpr std::size_t right_index(Right right)
    {
        return static_cast<std::size_t>(right);
    }

    NameEntry make_entry(
        MachObject object, MachTypeMask type, std::uint32_t references)
    {
        NameEntry entry;
        entry.object = object;
        entry.type = type;
        for (std::size_t index = 0; index < right_count; ++index) {
            const auto right = static_cast<Right>(index);
            if ((type & type_mask(right)) != 0) {
                entry.user_references[index] = std::max(1U, references);
            }
        }
        return entry;
    }

    void add_types(NameEntry& entry, MachTypeMask type,
        std::uint32_t references, bool copyout)
    {
        for (std::size_t index = 0; index < right_count; ++index) {
            const auto right = static_cast<Right>(index);
            const auto mask = type_mask(right);
            if ((type & mask) == 0)
                continue;
            if ((entry.type & mask) == 0) {
                entry.user_references[index] = std::max(1U, references);
            } else if ((mask & reference_counted_types) != 0 && copyout &&
                       entry.user_references[index] <
                           std::numeric_limits<std::uint32_t>::max()) {
                ++entry.user_references[index];
            } else {
                entry.user_references[index] =
                    std::max(entry.user_references[index], references);
            }
        }
        entry.type |= type;
    }

} // namespace

void MachNamespaceTable::create_task(TaskId task) { spaces_.try_emplace(task); }

void MachNamespaceTable::destroy_task(TaskId task) { spaces_.erase(task); }

void MachNamespaceTable::index_name(
    Space& space, MachObject object, MachName name)
{
    auto& names = space.names_by_object[object];
    const auto position = std::lower_bound(names.begin(), names.end(), name);
    if (position == names.end() || *position != name)
        names.insert(position, name);
}

void MachNamespaceTable::unindex_name(
    Space& space, MachObject object, MachName name)
{
    const auto object_names = space.names_by_object.find(object);
    if (object_names == space.names_by_object.end())
        return;
    auto& names = object_names->second;
    const auto position = std::lower_bound(names.begin(), names.end(), name);
    if (position != names.end() && *position == name)
        names.erase(position);
    if (names.empty())
        space.names_by_object.erase(object_names);
}

const std::vector<MachName>* MachNamespaceTable::indexed_names(
    const Space& space, MachObject object)
{
    const auto names = space.names_by_object.find(object);
    return names == space.names_by_object.end() ? nullptr : &names->second;
}

bool MachNamespaceTable::install(TaskId task, MachName name, MachObject object,
    MachTypeMask type, std::uint32_t user_references)
{
    if (!valid_name(name) || object == null_name || type == 0)
        return false;
    auto& space = spaces_[task];
    const auto existing = space.entries.find(name);
    if (existing != space.entries.end()) {
        if (existing->second.object != object)
            return false;
        add_types(existing->second, type, user_references, true);
        return true;
    }
    space.entries.emplace(name, make_entry(object, type, user_references));
    index_name(space, object, name);
    return true;
}

std::optional<MachName> MachNamespaceTable::allocate(
    TaskId task, MachObject object, MachTypeMask type)
{
    if (object == null_name || type == 0)
        return std::nullopt;
    auto& space = spaces_[task];
    auto candidate = space.next_name;
    while (!valid_name(candidate) || space.entries.contains(candidate)) {
        if (candidate >
            std::numeric_limits<MachName>::max() - name_index_stride) {
            return std::nullopt;
        }
        candidate += name_index_stride;
    }
    space.entries.emplace(candidate, make_entry(object, type, 1));
    index_name(space, object, candidate);
    if (candidate <= std::numeric_limits<MachName>::max() - name_index_stride) {
        space.next_name = candidate + name_index_stride;
    }
    return candidate;
}

std::optional<MachName> MachNamespaceTable::copyout(
    TaskId task, MachObject object, MachTypeMask type)
{
    auto& space = spaces_[task];
    // Unlike ordinary Send rights, SendOnce rights never coalesce in an
    // ipc_space and always have exactly one user reference. Distinct
    // outstanding RPC reply rights to the same receive object therefore need
    // distinct task-local names.
    if ((type & type_mask(Right::SendOnce)) != 0)
        return allocate(task, object, type);
    if (const auto names = indexed_names(space, object);
        names && !names->empty()) {
        const auto name = names->front();
        add_types(space.entries.at(name), type, 1, true);
        return name;
    }
    return allocate(task, object, type);
}

std::optional<MachName> MachNamespaceTable::copyout_at_name(
    TaskId task, MachObject object, MachTypeMask type, MachName preferred_name)
{
    auto& space = spaces_[task];
    if ((type & type_mask(Right::SendOnce)) != 0) {
        if (object != null_name && type != 0 && valid_name(preferred_name) &&
            !space.entries.contains(preferred_name)) {
            space.entries.emplace(preferred_name, make_entry(object, type, 1));
            index_name(space, object, preferred_name);
            return preferred_name;
        }
        return allocate(task, object, type);
    }
    if (const auto names = indexed_names(space, object);
        names && !names->empty()) {
        const auto name = names->front();
        add_types(space.entries.at(name), type, 1, true);
        return name;
    }
    if (object == null_name || type == 0 || !valid_name(preferred_name) ||
        space.entries.contains(preferred_name)) {
        return allocate(task, object, type);
    }
    space.entries.emplace(preferred_name, make_entry(object, type, 1));
    index_name(space, object, preferred_name);
    return preferred_name;
}

std::optional<NameEntry> MachNamespaceTable::lookup(
    TaskId task, MachName name) const
{
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return std::nullopt;
    const auto entry = space->second.entries.find(name);
    if (entry == space->second.entries.end())
        return std::nullopt;
    return entry->second;
}

std::optional<MachObject> MachNamespaceTable::resolve(
    TaskId task, MachName name) const
{
    const auto entry = lookup(task, name);
    return entry ? std::optional { entry->object } : std::nullopt;
}

std::optional<MachName> MachNamespaceTable::name_for(
    TaskId task, MachObject object) const
{
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return std::nullopt;
    const auto names = indexed_names(space->second, object);
    return names && !names->empty() ? std::optional { names->front() }
                                    : std::nullopt;
}

std::optional<MachTypeMask> MachNamespaceTable::type(
    TaskId task, MachName name) const
{
    if (name == dead_name)
        return type_mask(Right::DeadName);
    const auto entry = lookup(task, name);
    return entry ? std::optional { entry->type } : std::nullopt;
}

bool MachNamespaceTable::owns_right(
    TaskId task, MachObject object, Right right) const
{
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return false;
    const auto names = indexed_names(space->second, object);
    if (names == nullptr)
        return false;
    const auto mask = type_mask(right);
    return std::any_of(names->begin(), names->end(), [&](MachName name) {
        const auto entry = space->second.entries.find(name);
        return entry != space->second.entries.end() &&
               (entry->second.type & mask) != 0U;
    });
}

std::vector<NamedEntry> MachNamespaceTable::entries(TaskId task) const
{
    std::vector<NamedEntry> result;
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return result;
    result.reserve(space->second.entries.size());
    for (const auto& [name, entry] : space->second.entries) {
        result.push_back(NamedEntry { task, name, entry });
    }
    return result;
}

bool MachNamespaceTable::contains_task(TaskId task) const
{
    return spaces_.contains(task);
}

bool MachNamespaceTable::contains(TaskId task, MachName name) const
{
    return lookup(task, name).has_value();
}

std::size_t MachNamespaceTable::right_reference_count(
    MachObject object, Right right) const
{
    const auto mask = type_mask(right);
    std::size_t count = 0;
    for (const auto& [task, space] : spaces_) {
        static_cast<void>(task);
        const auto names = indexed_names(space, object);
        if (!names)
            continue;
        for (const auto name : *names) {
            const auto& entry = space.entries.at(name);
            if ((entry.type & mask) != 0) {
                count += entry.user_references[right_index(right)];
            }
        }
    }
    return count;
}

std::optional<std::uint32_t> MachNamespaceTable::user_references(
    TaskId task, MachName name, Right right) const
{
    const auto entry = lookup(task, name);
    if (!entry || (entry->type & type_mask(right)) == 0) {
        return std::nullopt;
    }
    return entry->user_references[right_index(right)];
}

bool MachNamespaceTable::rename(
    TaskId task, MachName old_name, MachName new_name)
{
    if (!valid_name(old_name) || !valid_name(new_name))
        return false;
    const auto space = spaces_.find(task);
    if (space == spaces_.end() || space->second.entries.contains(new_name)) {
        return false;
    }
    const auto old_entry = space->second.entries.find(old_name);
    if (old_entry == space->second.entries.end())
        return false;
    auto entry = old_entry->second;
    const auto object = entry.object;
    space->second.entries.erase(old_entry);
    space->second.entries.emplace(new_name, std::move(entry));
    unindex_name(space->second, object, old_name);
    index_name(space->second, object, new_name);
    return true;
}

bool MachNamespaceTable::modify_references(
    TaskId task, MachName name, Right right, std::int32_t delta)
{
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return false;
    const auto entry = space->second.entries.find(name);
    const auto mask = type_mask(right);
    if (entry == space->second.entries.end() ||
        (entry->second.type & mask) == 0) {
        return false;
    }
    if (delta > 0 && right != Right::Send && right != Right::DeadName) {
        return false;
    }
    auto& references = entry->second.user_references[right_index(right)];
    if (delta > 0) {
        const auto amount = static_cast<std::uint32_t>(delta);
        const auto maximum = right == Right::Send ? maximum_send_user_references
                                                  : maximum_user_references;
        if (references > maximum || amount > maximum - references) {
            return false;
        }
        references += amount;
        return true;
    }
    const auto magnitude =
        static_cast<std::uint64_t>(-static_cast<std::int64_t>(delta));
    if (magnitude > references)
        return false;
    references -= static_cast<std::uint32_t>(magnitude);
    if (references == 0) {
        entry->second.type &= ~mask;
        if (entry->second.type == 0) {
            unindex_name(space->second, entry->second.object, name);
            space->second.entries.erase(entry);
        }
    }
    return true;
}

std::optional<NameEntry> MachNamespaceTable::destroy_name(
    TaskId task, MachName name)
{
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return std::nullopt;
    const auto entry = space->second.entries.find(name);
    if (entry == space->second.entries.end())
        return std::nullopt;
    auto removed = entry->second;
    unindex_name(space->second, removed.object, name);
    space->second.entries.erase(entry);
    return removed;
}

std::vector<NamedEntry> MachNamespaceTable::mark_object_dead(MachObject object)
{
    std::vector<NamedEntry> affected;
    const auto send_index = right_index(Right::Send);
    const auto send_once_index = right_index(Right::SendOnce);
    const auto dead_index = right_index(Right::DeadName);
    for (auto& [task, space] : spaces_) {
        const auto names = indexed_names(space, object);
        if (!names)
            continue;
        for (const auto name : *names) {
            auto& entry = space.entries.at(name);
            if ((entry.type & (type_mask(Right::Send) |
                                  type_mask(Right::SendOnce))) == 0) {
                continue;
            }
            affected.push_back(NamedEntry { task, name, entry });
            const auto combined =
                static_cast<std::uint64_t>(entry.user_references[send_index]) +
                entry.user_references[send_once_index];
            const auto references =
                static_cast<std::uint32_t>(std::clamp<std::uint64_t>(
                    combined, 1, std::numeric_limits<std::uint32_t>::max()));
            entry.type &=
                ~(type_mask(Right::Send) | type_mask(Right::SendOnce));
            entry.type |= type_mask(Right::DeadName);
            entry.user_references[send_index] = 0;
            entry.user_references[send_once_index] = 0;
            entry.user_references[dead_index] = references;
        }
    }
    return affected;
}

bool MachNamespaceTable::remove_type(
    TaskId task, MachName name, MachTypeMask type)
{
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return false;
    const auto entry = space->second.entries.find(name);
    if (entry == space->second.entries.end() ||
        (entry->second.type & type) == 0) {
        return false;
    }
    entry->second.type &= ~type;
    for (std::size_t index = 0; index < right_count; ++index) {
        const auto right = static_cast<Right>(index);
        if ((type & type_mask(right)) != 0) {
            entry->second.user_references[index] = 0;
        }
    }
    if (entry->second.type == 0) {
        unindex_name(space->second, entry->second.object, name);
        space->second.entries.erase(entry);
    }
    return true;
}

bool MachNamespaceTable::deallocate(TaskId task, MachName name)
{
    const auto space = spaces_.find(task);
    if (space == spaces_.end())
        return false;
    const auto entry = space->second.entries.find(name);
    if (entry == space->second.entries.end())
        return false;
    constexpr auto releasable = type_mask(Right::Send) |
                                type_mask(Right::SendOnce) |
                                type_mask(Right::DeadName);
    const auto available = entry->second.type & releasable;
    if (available == 0)
        return false;
    const auto released =
        (available & type_mask(Right::Send)) != 0       ? Right::Send
        : (available & type_mask(Right::SendOnce)) != 0 ? Right::SendOnce
                                                        : Right::DeadName;
    auto& references = entry->second.user_references[right_index(released)];
    if (references > 1) {
        --references;
        return true;
    }
    references = 0;
    entry->second.type &= ~type_mask(released);
    if (entry->second.type == 0) {
        unindex_name(space->second, entry->second.object, name);
        space->second.entries.erase(entry);
    }
    return true;
}

bool MachNamespaceTable::valid_name(MachName name)
{
    return name != null_name && name != dead_name;
}

} // namespace shade::xnu::ipc
