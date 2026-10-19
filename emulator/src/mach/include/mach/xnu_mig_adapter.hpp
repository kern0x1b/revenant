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

#pragma once

#include <cstdint>
#include <optional>
#include <span>
#include <string_view>
#include <vector>

namespace emulator::xnu::mig {

enum class Subsystem : std::uint8_t {
    MachPort,
    Task,
    ThreadAct,
    Iokit,
    MachHost,
    VmMap,
    Clock,
    ClockReply,
    Semaphore,
    Bootstrap,
    SystemConfiguration,
};

enum class ArgumentDirection : std::uint8_t {
    In,
    Out,
    InOut,
};

enum class WireType : std::uint8_t {
    Unknown,
    Scalar,
    Port,
    FixedInline,
    VariableInline,
    OutOfLine,
    OutOfLinePorts,
};

inline constexpr std::uint32_t no_wire_offset = 0xffff'ffffU;

struct ArgumentInfo {
    std::string_view name;
    std::string_view type;
    std::string_view attributes;
    ArgumentDirection direction { };
    WireType wire_type { };
    std::uint32_t wire_size { };
    std::uint32_t count_prefix_size { };
    std::uint32_t element_size { };
    std::uint32_t request_offset { no_wire_offset };
    std::uint32_t reply_offset { no_wire_offset };
    std::uint32_t request_count_offset { no_wire_offset };
    std::uint32_t reply_count_offset { no_wire_offset };
};

struct RoutineInfo {
    Subsystem subsystem { };
    std::uint32_t identifier { };
    std::string_view subsystem_name;
    std::string_view routine_name;
    std::span<const ArgumentInfo> arguments;
};

enum class WireLayoutSide : std::uint8_t {
    Request,
    Reply,
};

struct ArgumentWirePosition {
    std::uint32_t offset { no_wire_offset };
    std::uint32_t count_offset { no_wire_offset };
};

[[nodiscard]] std::optional<std::vector<ArgumentWirePosition>>
compute_wire_layout(std::span<const ArgumentInfo> arguments,
    WireLayoutSide side, std::span<const std::uint32_t> element_counts = { });

[[nodiscard]] std::optional<RoutineInfo> lookup_routine(
    std::uint32_t identifier);

}
