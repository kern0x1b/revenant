// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement guest Mach clock services and clock-related message
// replies.

#include "kernel/kernel_clock.hpp"

#include <array>
#include <cstddef>
#include <limits>
#include <mutex>
#include <span>
#include <utility>

#include "foundation/address_space.hpp"
#include "mach/clock_mig_ids.hpp"
#include "mach/clock_reply_mig_ids.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "kernel/mach_clock_abi.hpp"
#include "mach/mig_wire_abi.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t mach_rcv_too_large = 0x10004004U;
    constexpr std::uint32_t mach_rcv_invalid_data = 0x10004008U;
    constexpr std::uint32_t mig_reply_id_delta = 100;
    constexpr std::uint32_t move_send_once_bits = 18;
    constexpr std::uint32_t make_send_once_disposition = 21;

    void write_little_word(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        if (offset + sizeof(value) > bytes.size())
            return;
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    }

    template <std::size_t Size>
    std::uint32_t write_reply(AddressSpace& memory, std::uint32_t address,
        const std::array<std::uint32_t, Size>& words,
        std::size_t word_count = Size)
    {
        if (word_count > Size)
            return mach_rcv_invalid_data;
        for (std::size_t index = 0; index < word_count; ++index) {
            if (!memory.write32(address + static_cast<std::uint32_t>(
                                              index * sizeof(std::uint32_t)),
                    words[index])) {
                return mach_rcv_invalid_data;
            }
        }
        return 0;
    }

    std::optional<std::uint32_t> clock_id_locked(const KernelSharedState& state,
        const ProcessContext& process, std::uint32_t remote_port)
    {
        const auto object =
            state.mach_namespaces.resolve(process.pid, remote_port);
        if (!object)
            return std::nullopt;
        if (object ==
            state.mach_namespaces.resolve(process.pid, process.clock_port)) {
            return darwin::mach::clock::system_clock_id;
        }
        if (object == state.mach_namespaces.resolve(
                          process.pid, process.calendar_clock_port)) {
            return darwin::mach::clock::calendar_clock_id;
        }
        return std::nullopt;
    }

    std::optional<std::uint32_t> resolve_receive_locked(
        const KernelSharedState& state, const ProcessContext& process,
        std::uint32_t name)
    {
        const auto entry = state.mach_namespaces.lookup(process.pid, name);
        if (!entry || (entry->type & xnu::ipc::type_mask(
                                         xnu::ipc::Right::Receive)) == 0) {
            return std::nullopt;
        }
        return entry->object;
    }

} // namespace

std::optional<std::uint32_t> handle_clock_mach_request(AddressSpace& memory,
    KernelSharedState& state, ProcessContext& process, std::uint32_t message_id,
    std::uint32_t message_address, std::uint32_t send_size,
    std::uint32_t receive_size, std::uint32_t remote_port,
    std::uint32_t local_port)
{
    using namespace xnu::mig::clock;
    if (message_id != id(Routine::clock_get_time) &&
        message_id != id(Routine::clock_get_attributes) &&
        message_id != id(Routine::clock_alarm)) {
        return std::nullopt;
    }
    {
        std::lock_guard lock { state.mach_mutex };
        // MIG identifiers are local to a service. User-space protocols can
        // reuse the clock subsystem's identifiers on their own receive ports.
        if (!clock_id_locked(state, process, remote_port))
            return std::nullopt;
    }
    if (message_id == id(Routine::clock_get_time)) {
        constexpr const auto& output = clock_get_time_arguments[1];
        constexpr auto success_size = output.reply_offset + output.wire_size;
        constexpr auto error_size = darwin::mig_wire::simple_reply_payload_base;
        if (receive_size < success_size)
            return mach_rcv_too_large;
        std::optional<std::uint32_t> clock_id;
        {
            std::lock_guard lock { state.mach_mutex };
            clock_id = clock_id_locked(state, process, remote_port);
        }
        const auto result =
            clock_id ? darwin::mach::success : darwin::mach::invalid_argument;
        const auto reply_size = clock_id ? success_size : error_size;
        const auto now = clock_id == darwin::mach::clock::calendar_clock_id
                             ? state.clock.wall_time()
                             : state.clock.now();
        const std::array<std::uint32_t, success_size / sizeof(std::uint32_t)>
            reply {
                move_send_once_bits,
                reply_size,
                local_port,
                0,
                0,
                message_id + mig_reply_id_delta,
                0,
                1,
                result,
                clock_id
                    ? static_cast<std::uint32_t>(
                          now / darwin::mach::clock::nanoseconds_per_second)
                    : 0U,
                clock_id
                    ? static_cast<std::uint32_t>(
                          now % darwin::mach::clock::nanoseconds_per_second)
                    : 0U,
            };
        return write_reply(
            memory, message_address, reply, reply_size / sizeof(std::uint32_t));
    }

    if (message_id == id(Routine::clock_get_attributes)) {
        constexpr const auto& arguments = clock_get_attributes_arguments;
        constexpr auto success_size =
            arguments[2].reply_offset + arguments[2].wire_size;
        constexpr auto error_size = darwin::mig_wire::simple_reply_payload_base;
        if (receive_size < success_size)
            return mach_rcv_too_large;
        const auto flavor =
            memory.read32(message_address + arguments[1].request_offset)
                .value_or(0);
        const auto count =
            memory.read32(message_address + arguments[2].request_count_offset)
                .value_or(0);
        bool valid = false;
        {
            std::lock_guard lock { state.mach_mutex };
            valid = clock_id_locked(state, process, remote_port).has_value();
        }
        auto result =
            valid ? darwin::mach::success : darwin::mach::invalid_argument;
        if (result == 0 && count != darwin::mach::clock::attribute_word_count) {
            result = darwin::mach::failure;
        }
        if (result == 0 &&
            flavor != darwin::mach::clock::get_time_resolution_flavor &&
            flavor != darwin::mach::clock::alarm_current_resolution_flavor &&
            flavor != darwin::mach::clock::alarm_minimum_resolution_flavor &&
            flavor != darwin::mach::clock::alarm_maximum_resolution_flavor) {
            result = darwin::mach::invalid_value;
        }
        const auto reply_size = result == 0 ? success_size : error_size;
        const std::array<std::uint32_t, success_size / sizeof(std::uint32_t)>
            reply {
                move_send_once_bits,
                reply_size,
                local_port,
                0,
                0,
                message_id + mig_reply_id_delta,
                0,
                1,
                result,
                result == 0 ? darwin::mach::clock::attribute_word_count : 0U,
                result == 0
                    ? darwin::mach::clock::virtual_resolution_nanoseconds
                    : 0U,
            };
        return write_reply(
            memory, message_address, reply, reply_size / sizeof(std::uint32_t));
    }

    if (message_id != id(Routine::clock_alarm))
        return std::nullopt;
    constexpr const auto& arguments = clock_alarm_arguments;
    constexpr auto request_size =
        arguments[2].request_offset + arguments[2].wire_size;
    constexpr auto reply_size = darwin::mig_wire::simple_reply_payload_base;
    auto result = darwin::mach::success;
    if (send_size < request_size || receive_size < reply_size) {
        result = darwin::mach::invalid_argument;
    } else {
        const auto alarm_type =
            memory.read32(message_address + arguments[1].request_offset)
                .value_or(0xffffffffU);
        const auto seconds =
            memory.read32(message_address + arguments[2].request_offset)
                .value_or(0);
        const auto nanoseconds =
            memory
                .read32(message_address + arguments[2].request_offset +
                        sizeof(std::uint32_t))
                .value_or(0xffffffffU);
        const auto reply_name =
            memory.read32(message_address + arguments[3].request_offset)
                .value_or(0);
        const auto descriptor =
            memory
                .read32(message_address + arguments[3].request_offset +
                        2U * sizeof(std::uint32_t))
                .value_or(0);
        const auto disposition =
            (descriptor >> darwin::mig_wire::descriptor_disposition_shift) &
            0xffU;
        std::lock_guard lock { state.mach_mutex };
        const auto reply_object =
            resolve_receive_locked(state, process, reply_name);
        const auto clock_id = clock_id_locked(state, process, remote_port);
        if (!clock_id) {
            result = darwin::mach::invalid_argument;
        } else if (disposition != make_send_once_disposition || !reply_object) {
            result = darwin::mach::invalid_capability;
        } else {
            const auto monotonic_now = state.clock.now();
            const auto clock_now =
                clock_id == darwin::mach::clock::calendar_clock_id
                    ? state.clock.wall_time()
                    : monotonic_now;
            const auto valid_time =
                alarm_type <= darwin::mach::clock::time_relative &&
                nanoseconds < darwin::mach::clock::nanoseconds_per_second;
            const auto requested =
                static_cast<std::uint64_t>(seconds) *
                    darwin::mach::clock::nanoseconds_per_second +
                nanoseconds;
            auto alarm_time = requested;
            if (valid_time &&
                alarm_type == darwin::mach::clock::time_relative) {
                alarm_time =
                    requested > std::numeric_limits<std::uint64_t>::max() -
                                    clock_now
                        ? std::numeric_limits<std::uint64_t>::max()
                        : clock_now + requested;
            }
            const auto remaining =
                alarm_time > clock_now ? alarm_time - clock_now : 0;
            const auto deadline =
                remaining > std::numeric_limits<std::uint64_t>::max() -
                                monotonic_now
                    ? std::numeric_limits<std::uint64_t>::max()
                    : monotonic_now + remaining;
            if (!valid_time || alarm_time <= clock_now) {
                enqueue_clock_alarm_reply_locked(state, *reply_object,
                    valid_time ? darwin::mach::success
                               : darwin::mach::invalid_value,
                    alarm_type, clock_now);
            } else {
                state.clock_alarms.emplace(state.next_clock_alarm++,
                    KernelSharedState::ClockAlarm {
                        deadline, alarm_time, alarm_type, *reply_object });
            }
        }
    }
    const std::array<std::uint32_t, reply_size / sizeof(std::uint32_t)> reply {
        move_send_once_bits,
        reply_size,
        local_port,
        0,
        0,
        message_id + mig_reply_id_delta,
        0,
        1,
        result,
    };
    return write_reply(memory, message_address, reply);
}

void enqueue_clock_alarm_reply_locked(KernelSharedState& state,
    std::uint32_t reply_object, std::uint32_t code, std::uint32_t alarm_type,
    std::uint64_t alarm_time)
{
    // A clock alarm retains a send-once reply right.  The receiving ipc_space
    // may disappear before the deadline; never use operator[] here, because it
    // would resurrect a queue for a dead port and make a later PID reuse see an
    // unrelated reply.
    if (!state.mach_port_objects.contains(reply_object)) {
        return;
    }
    using namespace xnu::mig::clock_reply;
    constexpr const auto& arguments = clock_alarm_reply_arguments;
    constexpr auto message_size =
        arguments[3].request_offset + arguments[3].wire_size;
    KernelSharedState::MachMessage message;
    message.bytes.resize(message_size);
    write_little_word(message.bytes, darwin::mig_wire::header_bits_offset, 18);
    write_little_word(
        message.bytes, darwin::mig_wire::header_size_offset, message_size);
    write_little_word(message.bytes,
        darwin::mig_wire::header_remote_port_offset, reply_object);
    write_little_word(message.bytes, darwin::mig_wire::header_identifier_offset,
        id(Routine::clock_alarm_reply));
    write_little_word(message.bytes, darwin::mig_wire::message_header_size, 0);
    write_little_word(message.bytes,
        darwin::mig_wire::message_header_size + darwin::mig_wire::word_size, 1);
    write_little_word(message.bytes, arguments[1].request_offset, code);
    write_little_word(message.bytes, arguments[2].request_offset, alarm_type);
    write_little_word(message.bytes, arguments[3].request_offset,
        static_cast<std::uint32_t>(
            alarm_time / darwin::mach::clock::nanoseconds_per_second));
    write_little_word(message.bytes,
        arguments[3].request_offset + sizeof(std::uint32_t),
        static_cast<std::uint32_t>(
            alarm_time % darwin::mach::clock::nanoseconds_per_second));
    message.destination = reply_object;
    state.enqueue_mach_message_locked(reply_object, std::move(message));
}

std::optional<std::uint64_t> next_clock_alarm_deadline_locked(
    const KernelSharedState& state)
{
    std::optional<std::uint64_t> result;
    for (const auto& [identifier, alarm] : state.clock_alarms) {
        static_cast<void>(identifier);
        if (!result || alarm.deadline < *result)
            result = alarm.deadline;
    }
    return result;
}

void deliver_due_clock_alarms_locked(
    KernelSharedState& state, std::uint64_t deadline)
{
    for (auto alarm = state.clock_alarms.begin();
        alarm != state.clock_alarms.end();) {
        if (alarm->second.deadline > deadline) {
            ++alarm;
            continue;
        }
        if (!state.mach_port_objects.contains(alarm->second.reply_object)) {
            alarm = state.clock_alarms.erase(alarm);
            continue;
        }
        enqueue_clock_alarm_reply_locked(state, alarm->second.reply_object,
            darwin::mach::success, alarm->second.alarm_type,
            alarm->second.alarm_time);
        alarm = state.clock_alarms.erase(alarm);
    }
}

} // namespace shade
