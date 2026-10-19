// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage task-local Mach names, rights and user-reference counts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_entry.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_space.h

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <map>
#include <optional>
#include <unordered_map>
#include <vector>

namespace shade::xnu::ipc {

using TaskId = std::uint32_t;
using MachName = std::uint32_t;
using MachObject = std::uint32_t;
using MachTypeMask = std::uint32_t;

inline constexpr MachName null_name = 0;
inline constexpr MachName dead_name = 0xffff'ffffU;
inline constexpr MachName first_dynamic_name = 0x0001'0000U;
inline constexpr MachName name_index_stride = 0x100U;
// XNU stores ipc_entry user references in a 16-bit field. A live send
// right reserves the all-ones value for dead-name conversion.
inline constexpr std::uint32_t maximum_user_references = 0xffffU;
inline constexpr std::uint32_t maximum_send_user_references =
    maximum_user_references - 1U;

enum class Right : std::uint32_t {
    Send = 0,
    Receive = 1,
    SendOnce = 2,
    PortSet = 3,
    DeadName = 4,
};

[[nodiscard]] constexpr MachTypeMask type_mask(Right right)
{
    return 1U << (static_cast<std::uint32_t>(right) + 16U);
}

struct NameEntry {
    MachObject object { };
    MachTypeMask type { };
    std::array<std::uint32_t, 5> user_references { };
};

struct NamedEntry {
    TaskId task { };
    MachName name { };
    NameEntry entry;
};

// Models the ipc_space/ipc_entry boundary from XNU. A Mach name is only
// meaningful in one task; queues and receive ownership use the separate port
// object identifier. Callers serialize access with
// KernelSharedState::mach_mutex.
class MachNamespaceTable {
public:
    void create_task(TaskId task);
    void destroy_task(TaskId task);

    bool install(TaskId task, MachName name, MachObject object,
        MachTypeMask type, std::uint32_t user_references = 1);
    [[nodiscard]] std::optional<MachName> allocate(
        TaskId task, MachObject object, MachTypeMask type);
    [[nodiscard]] std::optional<MachName> copyout(
        TaskId task, MachObject object, MachTypeMask type);
    // Used only when an ABI explicitly restores a task-local name, such as a
    // forked task inheriting the userspace bootstrap_port variable. Generic
    // right copyout must never use a global MachObject as a preferred name.
    [[nodiscard]] std::optional<MachName> copyout_at_name(TaskId task,
        MachObject object, MachTypeMask type, MachName preferred_name);

    [[nodiscard]] std::optional<NameEntry> lookup(
        TaskId task, MachName name) const;
    [[nodiscard]] std::optional<MachObject> resolve(
        TaskId task, MachName name) const;
    [[nodiscard]] std::optional<MachName> name_for(
        TaskId task, MachObject object) const;
    [[nodiscard]] std::optional<MachTypeMask> type(
        TaskId task, MachName name) const;
    [[nodiscard]] bool owns_right(
        TaskId task, MachObject object, Right right) const;
    [[nodiscard]] std::vector<NamedEntry> entries(TaskId task) const;
    [[nodiscard]] bool contains_task(TaskId task) const;
    [[nodiscard]] bool contains(TaskId task, MachName name) const;
    [[nodiscard]] std::size_t right_reference_count(
        MachObject object, Right right) const;
    [[nodiscard]] std::optional<std::uint32_t> user_references(
        TaskId task, MachName name, Right right) const;
    bool rename(TaskId task, MachName old_name, MachName new_name);
    bool modify_references(
        TaskId task, MachName name, Right right, std::int32_t delta);
    [[nodiscard]] std::optional<NameEntry> destroy_name(
        TaskId task, MachName name);
    [[nodiscard]] std::vector<NamedEntry> mark_object_dead(MachObject object);
    bool remove_type(TaskId task, MachName name, MachTypeMask type);
    bool deallocate(TaskId task, MachName name);

private:
    struct Space {
        MachName next_name { first_dynamic_name };
        std::map<MachName, NameEntry> entries;
        // Most ipc objects have one name in a task, but aliases are legal. Keep
        // the names sorted so name_for/copyout preserve the same lowest-name
        // result as the authoritative ipc_entry map without scanning that map.
        std::unordered_map<MachObject, std::vector<MachName>> names_by_object;
    };

    static void index_name(Space& space, MachObject object, MachName name);
    static void unindex_name(Space& space, MachObject object, MachName name);
    [[nodiscard]] static const std::vector<MachName>* indexed_names(
        const Space& space, MachObject object);
    [[nodiscard]] static bool valid_name(MachName name);
    std::map<TaskId, Space> spaces_;
};

} // namespace shade::xnu::ipc
