// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Look up MIG routine metadata and compute variable request and reply
// layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/message.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/ndr.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/std_types.defs

#include "mach/xnu_mig_adapter.hpp"

#include <limits>

#include "mach/bootstrap_mig_ids.hpp"
#include "mach/clock_mig_ids.hpp"
#include "mach/clock_reply_mig_ids.hpp"
#include "mach/device_mig_ids.hpp"
#include "mach/mach_host_mig_ids.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/semaphore_mig_ids.hpp"
#include "mach/system_configuration_mig_ids.hpp"
#include "mach/task_mig_ids.hpp"
#include "mach/thread_act_mig_ids.hpp"
#include "mach/vm_map_mig_ids.hpp"

namespace shade::xnu::mig {
namespace {

    template <typename Range>
    std::optional<RoutineInfo> find(std::uint32_t identifier,
        Subsystem subsystem, std::string_view subsystem_name,
        const Range& routines)
    {
        for (const auto& descriptor : routines) {
            if (static_cast<std::uint32_t>(descriptor.routine) == identifier) {
                return RoutineInfo { subsystem, identifier, subsystem_name,
                    descriptor.name, descriptor.arguments };
            }
        }
        return std::nullopt;
    }

    bool descriptor_type(WireType type)
    {
        return type == WireType::Port || type == WireType::OutOfLine ||
               type == WireType::OutOfLinePorts;
    }

    bool participates(const ArgumentInfo& argument, WireLayoutSide side)
    {
        return side == WireLayoutSide::Request
                   ? argument.direction == ArgumentDirection::In ||
                         argument.direction == ArgumentDirection::InOut
                   : argument.direction == ArgumentDirection::Out ||
                         argument.direction == ArgumentDirection::InOut;
    }

    constexpr std::uint32_t align_inline(std::uint32_t offset)
    {
        return (offset + darwin::mig_wire::word_size - 1U) &
               ~(darwin::mig_wire::word_size - 1U);
    }

    bool checked_add(std::uint32_t& value, std::uint32_t increment)
    {
        if (increment > std::numeric_limits<std::uint32_t>::max() - value) {
            return false;
        }
        value += increment;
        return true;
    }

} // namespace

std::optional<std::vector<ArgumentWirePosition>> compute_wire_layout(
    std::span<const ArgumentInfo> arguments, WireLayoutSide side,
    std::span<const std::uint32_t> element_counts)
{
    std::vector<ArgumentWirePosition> result(arguments.size());
    if (arguments.empty())
        return result;

    std::size_t descriptor_count = 0;
    for (std::size_t index = 1; index < arguments.size(); ++index) {
        const auto& argument = arguments[index];
        if (argument.attributes == "ServerAuditToken" ||
            argument.attributes == "sreplyport") {
            continue;
        }
        if (participates(argument, side) &&
            descriptor_type(argument.wire_type)) {
            ++descriptor_count;
        }
    }

    if (side == WireLayoutSide::Request && participates(arguments[0], side)) {
        result[0].offset = darwin::mig_wire::header_remote_port_offset;
    }
    std::uint32_t cursor = 0;
    if (side == WireLayoutSide::Request) {
        cursor = descriptor_count == 0
                     ? darwin::mig_wire::simple_request_payload_base
                     : darwin::mig_wire::complex_ndr_offset(descriptor_count) +
                           darwin::mig_wire::ndr_record_size;
    } else {
        cursor = descriptor_count == 0
                     ? darwin::mig_wire::simple_reply_payload_base
                     : darwin::mig_wire::complex_ndr_offset(descriptor_count) +
                           darwin::mig_wire::ndr_record_size;
    }

    std::size_t descriptor_index = 0;
    for (std::size_t index = 1; index < arguments.size(); ++index) {
        const auto& argument = arguments[index];
        if (argument.attributes == "ServerAuditToken")
            continue;
        if (argument.attributes == "sreplyport") {
            if (side == WireLayoutSide::Request) {
                result[index].offset =
                    darwin::mig_wire::header_local_port_offset;
            }
            continue;
        }
        if (descriptor_type(argument.wire_type)) {
            if (participates(argument, side)) {
                result[index].offset =
                    darwin::mig_wire::descriptor_offset(descriptor_index++);
                if ((argument.wire_type == WireType::OutOfLine ||
                        argument.wire_type == WireType::OutOfLinePorts) &&
                    argument.element_size != 0) {
                    cursor = align_inline(cursor);
                    result[index].count_offset = cursor;
                    if (!checked_add(cursor, darwin::mig_wire::word_size)) {
                        return std::nullopt;
                    }
                }
            }
            continue;
        }

        const auto count_inout =
            argument.type.find("CountInOut") != std::string_view::npos;
        if (side == WireLayoutSide::Request &&
            argument.direction == ArgumentDirection::Out && count_inout) {
            cursor = align_inline(cursor);
            result[index].count_offset = cursor;
            if (!checked_add(cursor, darwin::mig_wire::word_size)) {
                return std::nullopt;
            }
            continue;
        }
        if (!participates(argument, side) ||
            argument.wire_type == WireType::Unknown) {
            continue;
        }

        cursor = align_inline(cursor);
        if (argument.wire_type == WireType::VariableInline) {
            if (argument.element_size == 0 ||
                !checked_add(cursor, argument.count_prefix_size)) {
                return std::nullopt;
            }
            result[index].count_offset = cursor;
            if (!checked_add(cursor, darwin::mig_wire::word_size)) {
                return std::nullopt;
            }
            result[index].offset = cursor;
            const auto count =
                index < element_counts.size() ? element_counts[index] : 0U;
            const auto bytes =
                static_cast<std::uint64_t>(count) * argument.element_size;
            if (bytes > std::numeric_limits<std::uint32_t>::max() ||
                (argument.wire_size != 0 && bytes > argument.wire_size) ||
                !checked_add(cursor, static_cast<std::uint32_t>(bytes))) {
                return std::nullopt;
            }
        } else {
            result[index].offset = cursor;
            if (!checked_add(cursor, argument.wire_size)) {
                return std::nullopt;
            }
        }
    }
    return result;
}

std::optional<RoutineInfo> lookup_routine(std::uint32_t identifier)
{
    if (const auto result = find(identifier, Subsystem::MachPort,
            mach_port::subsystem_name, mach_port::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::Task,
            task::subsystem_name, task::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::ThreadAct,
            thread_act::subsystem_name, thread_act::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::Iokit,
            device::subsystem_name, device::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::MachHost,
            mach_host::subsystem_name, mach_host::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::VmMap,
            vm_map::subsystem_name, vm_map::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::Clock,
            clock::subsystem_name, clock::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::ClockReply,
            clock_reply::subsystem_name, clock_reply::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::Semaphore,
            semaphore::subsystem_name, semaphore::routines)) {
        return result;
    }
    if (const auto result = find(identifier, Subsystem::Bootstrap,
            bootstrap::subsystem_name, bootstrap::routines)) {
        return result;
    }
    return find(identifier, Subsystem::SystemConfiguration,
        system_configuration::subsystem_name, system_configuration::routines);
}

} // namespace shade::xnu::mig
