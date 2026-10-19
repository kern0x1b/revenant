// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 bootstrap MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/launchd/blob/launchd-257/launchd/src/protocol_jobmgr.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::bootstrap {

inline constexpr std::string_view subsystem_name{"bootstrap"};
inline constexpr std::uint32_t subsystem_base = 400U;

enum class Routine : std::uint32_t {
    create_server = 400U,
    check_in = 402U,
    mig_register = 403U,
    look_up = 404U,
    parent = 406U,
    info = 408U,
    subset = 409U,
    create_service = 410U,
    transfer_subset = 411U,
    getsocket = 412U,
    spawn = 413U,
    wait = 414U,
    uncork_fork = 415U,
    get_self = 416U,
};

inline constexpr std::array<ArgumentInfo, 6> create_server_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__server_cmd", "cmd_t", "", ArgumentDirection::In, WireType::FixedInline, 512U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__server_uid", "natural_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 544U, 4294967295U, 4294967295U, 4294967295U},
    {"__on_demand", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 548U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"__server_port", "mach_port_make_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> check_in_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_name", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_port", "mach_port_move_receive_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mig_register_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_name", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> look_up_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_name", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_port", "mach_port_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> parent_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__parent_port", "mach_port_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> info_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_names", "name_array_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 128U, 4294967295U, 28U, 4294967295U, 60U},
    {"__service_active", "bootstrap_status_array_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 40U, 4294967295U, 64U},
}};

inline constexpr std::array<ArgumentInfo, 3> subset_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__requestor_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"__subset_port", "mach_port_make_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> create_service_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_name", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_port", "mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> transfer_subset_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__bs_reqport", "mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"__bs_rcvright", "mach_port_move_receive_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
    {"__service_names", "name_array_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 128U, 4294967295U, 52U, 4294967295U, 96U},
    {"__service_pids", "pointer_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 64U, 4294967295U, 100U},
    {"__service_ports", "mach_port_array_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 76U, 4294967295U, 104U},
}};

inline constexpr std::array<ArgumentInfo, 2> getsocket_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__sockpath", "name_t", "", ArgumentDirection::Out, WireType::FixedInline, 128U, 0U, 1U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 9> spawn_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"__chars", "_internal_string_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"__argc", "uint32_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"__envc", "uint32_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"__flags", "uint64_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 60U, 4294967295U, 4294967295U, 4294967295U},
    {"__umask", "uint16_t", "", ArgumentDirection::In, WireType::Scalar, 2U, 0U, 0U, 68U, 4294967295U, 4294967295U, 4294967295U},
    {"__pid", "pid_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"__obsvr_port", "mach_port_make_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> wait_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__rport", "mach_port_make_send_once_t", "sreplyport", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 12U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"__waitval", "integer_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> uncork_fork_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> get_self_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__token", "audit_token_t", "ServerAuditToken", ArgumentDirection::In, WireType::FixedInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"__job_port", "mach_port_make_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 14> routines{{
    {Routine::create_server, "create_server", std::span<const ArgumentInfo>{create_server_arguments}},
    {Routine::check_in, "check_in", std::span<const ArgumentInfo>{check_in_arguments}},
    {Routine::mig_register, "register", std::span<const ArgumentInfo>{mig_register_arguments}},
    {Routine::look_up, "look_up", std::span<const ArgumentInfo>{look_up_arguments}},
    {Routine::parent, "parent", std::span<const ArgumentInfo>{parent_arguments}},
    {Routine::info, "info", std::span<const ArgumentInfo>{info_arguments}},
    {Routine::subset, "subset", std::span<const ArgumentInfo>{subset_arguments}},
    {Routine::create_service, "create_service", std::span<const ArgumentInfo>{create_service_arguments}},
    {Routine::transfer_subset, "transfer_subset", std::span<const ArgumentInfo>{transfer_subset_arguments}},
    {Routine::getsocket, "getsocket", std::span<const ArgumentInfo>{getsocket_arguments}},
    {Routine::spawn, "spawn", std::span<const ArgumentInfo>{spawn_arguments}},
    {Routine::wait, "wait", std::span<const ArgumentInfo>{wait_arguments}},
    {Routine::uncork_fork, "uncork_fork", std::span<const ArgumentInfo>{uncork_fork_arguments}},
    {Routine::get_self, "get_self", std::span<const ArgumentInfo>{get_self_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::bootstrap
