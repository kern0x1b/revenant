// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Represent Mach port objects, queue limits and right lifetimes.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/port.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1228.15.4/osfmk/mach/port.h

#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <optional>

namespace shade::xnu::ipc {

using PortObjectId = std::uint32_t;
using TaskIdentity = std::uint32_t;
inline constexpr std::uint32_t basic_queue_limit = 5;
inline constexpr std::uint32_t small_queue_limit = 16;
inline constexpr std::uint32_t framework_queue_limit = 64;
inline constexpr std::uint32_t large_queue_limit = 1024;
inline constexpr std::uint32_t default_queue_limit = basic_queue_limit;
// Public xnu defines 16 as MACH_PORT_QLIMIT_MAX, but the iPhone OS 1.0
// firmware's unmodified CoreFoundation/configd clients request 64 and 1024
// during normal startup. This matches the later Apple BASIC/SMALL/LARGE split
// and is an observable target-device kernel ABI difference.
inline constexpr std::uint32_t maximum_queue_limit = large_queue_limit;

struct PortObject {
    // Zero denotes the kernel ipc_space or an active port whose receive right
    // is temporarily in transit. This is never a task-local Mach name.
    TaskIdentity receive_owner { };
    // Preserve the receiver's identity across MOVE_RECEIVE. A user port in
    // transit also has a zero receive_owner, but it must remain routable to its
    // eventual user-space server; only ports created in the kernel ipc_space
    // are kernel objects serviced by the in-kernel MIG demux.
    bool kernel_owned { };
    std::uint32_t make_send_count { };
    std::uint32_t sequence_number { };
    std::uint32_t queue_limit { default_queue_limit };
    // Receive rights prepared for transfer do not attribute queued-message
    // importance to their temporary holder.
    bool temporary_owner { };
    std::optional<std::uint64_t> guard { };
    bool strict_guard { };
};

class PortObjectTable {
public:
    [[nodiscard]] bool create(
        PortObjectId object, TaskIdentity receive_owner = 0)
    {
        if (object == 0 || object == 0xffff'ffffU)
            return false;
        return objects_
            .emplace(object, PortObject { receive_owner, receive_owner == 0 })
            .second;
    }

    [[nodiscard]] bool contains(PortObjectId object) const
    {
        return objects_.contains(object);
    }

    [[nodiscard]] std::optional<PortObject> lookup(PortObjectId object) const
    {
        const auto found = objects_.find(object);
        return found == objects_.end() ? std::nullopt
                                       : std::optional { found->second };
    }

    [[nodiscard]] bool set_receive_owner(
        PortObjectId object, TaskIdentity receive_owner)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end())
            return false;
        found->second.receive_owner = receive_owner;
        if (receive_owner != 0)
            found->second.temporary_owner = false;
        return true;
    }

    [[nodiscard]] bool set_temporary_owner(PortObjectId object)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end() || found->second.kernel_owned)
            return false;
        found->second.temporary_owner = true;
        return true;
    }

    [[nodiscard]] bool clear_receiver(PortObjectId object)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end())
            return false;
        auto& port = found->second;
        port.receive_owner = 0;
        port.make_send_count = 0;
        port.sequence_number = 0;
        port.guard.reset();
        port.strict_guard = false;
        return true;
    }

    [[nodiscard]] bool set_make_send_count(
        PortObjectId object, std::uint32_t count)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end())
            return false;
        found->second.make_send_count = count;
        return true;
    }

    [[nodiscard]] bool set_guard(PortObjectId object,
        std::optional<std::uint64_t> guard, bool strict = false)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end())
            return false;
        found->second.guard = guard;
        found->second.strict_guard = guard.has_value() && strict;
        return true;
    }

    [[nodiscard]] bool increment_make_send_count(PortObjectId object)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end())
            return false;
        ++found->second.make_send_count;
        return true;
    }

    [[nodiscard]] std::optional<std::uint32_t> sequence_number(
        PortObjectId object) const
    {
        const auto found = objects_.find(object);
        if (found == objects_.end())
            return std::nullopt;
        return found->second.sequence_number;
    }

    [[nodiscard]] bool increment_sequence_number(PortObjectId object)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end())
            return false;
        ++found->second.sequence_number;
        return true;
    }

    [[nodiscard]] bool set_queue_limit(
        PortObjectId object, std::uint32_t queue_limit)
    {
        const auto found = objects_.find(object);
        if (found == objects_.end() || queue_limit > maximum_queue_limit)
            return false;
        found->second.queue_limit = queue_limit;
        return true;
    }

    [[nodiscard]] bool erase(PortObjectId object)
    {
        return objects_.erase(object) != 0;
    }

    [[nodiscard]] std::size_t size() const { return objects_.size(); }

private:
    std::map<PortObjectId, PortObject> objects_;
};

} // namespace shade::xnu::ipc
