// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 protocol_vproc MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/launchd/blob/launchd-257/launchd/src/protocol_job.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::protocol_vproc {

inline constexpr std::string_view subsystem_name{"protocol_vproc"};
inline constexpr std::uint32_t subsystem_base = 400U;

enum class Routine : std::uint32_t {
    create_server = 400U,
    reboot2 = 401U,
    check_in = 402U,
    register2 = 403U,
    look_up2 = 404U,
    send_signal = 405U,
    parent = 406U,
    post_fork_ping = 407U,
    info = 408U,
    subset = 409U,
    create_service = 410U,
    take_subset = 411U,
    getsocket = 412U,
    spawn = 413U,
    wait = 414U,
    uncork_fork = 415U,
    swap_integer = 416U,
    set_service_policy = 417U,
    log = 418U,
    lookup_per_user_context = 419U,
    move_subset = 420U,
    swap_complex = 421U,
    log_drain = 422U,
    log_forward = 423U,
};

inline constexpr std::array<ArgumentInfo, 5> create_server_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__server_cmd", "cmd_t", "", ArgumentDirection::In, WireType::FixedInline, 512U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__server_uid", "uid_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 544U, 4294967295U, 4294967295U, 4294967295U},
    {"__on_demand", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 548U, 4294967295U, 4294967295U, 4294967295U},
    {"__server_port", "mach_port_make_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> reboot2_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__flags", "uint64_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> check_in_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_name", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_port", "mach_port_move_receive_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> register2_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_name", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"__flags", "uint64_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 176U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> look_up2_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_name", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__service_port", "mach_port_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"__target_pid", "pid_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 160U, 4294967295U, 4294967295U, 4294967295U},
    {"__flags", "uint64_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 164U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> send_signal_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__rport", "mach_port_make_send_once_t", "sreplyport", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 12U, 4294967295U, 4294967295U, 4294967295U},
    {"__label", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__signal", "integer_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 160U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> parent_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__parent_port", "mach_port_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> post_fork_ping_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__task_port", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
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

inline constexpr std::array<ArgumentInfo, 5> take_subset_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__bs_reqport", "mach_port_move_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"__bs_rcvright", "mach_port_move_receive_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
    {"__outdata", "pointer_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 52U, 4294967295U, 84U},
    {"__service_ports", "mach_port_move_send_array_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 64U, 4294967295U, 88U},
}};

inline constexpr std::array<ArgumentInfo, 2> getsocket_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__sockpath", "name_t", "", ArgumentDirection::Out, WireType::FixedInline, 128U, 0U, 1U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> spawn_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__indata", "pointer_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"__pid", "pid_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"__obsvr_port", "mach_port_make_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> wait_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__rport", "mach_port_make_send_once_t", "sreplyport", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 12U, 4294967295U, 4294967295U, 4294967295U},
    {"__waitval", "integer_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> uncork_fork_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> swap_integer_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__inkey", "vproc_gsk_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__outkey", "vproc_gsk_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"__inval", "int64_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
    {"__outval", "int64_t", "", ArgumentDirection::Out, WireType::Scalar, 8U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> set_service_policy_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__target_pid", "pid_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__flags", "uint64_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"__service", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 44U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> log_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__pri", "integer_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__err", "integer_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"__msg", "logmsg_t", "", ArgumentDirection::In, WireType::VariableInline, 2048U, 4U, 1U, 48U, 4294967295U, 44U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> lookup_per_user_context_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__wu", "uid_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"__u_cont", "mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> move_subset_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__target_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"__sessiontype", "name_t", "", ArgumentDirection::In, WireType::FixedInline, 128U, 0U, 1U, 48U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> swap_complex_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__inkey", "vproc_gsk_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"__outkey", "vproc_gsk_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"__inval", "pointer_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 56U, 4294967295U},
    {"__outval", "pointer_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> log_drain_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__rport", "mach_port_make_send_once_t", "sreplyport", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 12U, 4294967295U, 4294967295U, 4294967295U},
    {"__outval", "pointer_t, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 2> log_forward_arguments{{
    {"__bs_port", "job_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"__inval", "pointer_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 24> routines{{
    {Routine::create_server, "create_server", std::span<const ArgumentInfo>{create_server_arguments}},
    {Routine::reboot2, "reboot2", std::span<const ArgumentInfo>{reboot2_arguments}},
    {Routine::check_in, "check_in", std::span<const ArgumentInfo>{check_in_arguments}},
    {Routine::register2, "register2", std::span<const ArgumentInfo>{register2_arguments}},
    {Routine::look_up2, "look_up2", std::span<const ArgumentInfo>{look_up2_arguments}},
    {Routine::send_signal, "send_signal", std::span<const ArgumentInfo>{send_signal_arguments}},
    {Routine::parent, "parent", std::span<const ArgumentInfo>{parent_arguments}},
    {Routine::post_fork_ping, "post_fork_ping", std::span<const ArgumentInfo>{post_fork_ping_arguments}},
    {Routine::info, "info", std::span<const ArgumentInfo>{info_arguments}},
    {Routine::subset, "subset", std::span<const ArgumentInfo>{subset_arguments}},
    {Routine::create_service, "create_service", std::span<const ArgumentInfo>{create_service_arguments}},
    {Routine::take_subset, "take_subset", std::span<const ArgumentInfo>{take_subset_arguments}},
    {Routine::getsocket, "getsocket", std::span<const ArgumentInfo>{getsocket_arguments}},
    {Routine::spawn, "spawn", std::span<const ArgumentInfo>{spawn_arguments}},
    {Routine::wait, "wait", std::span<const ArgumentInfo>{wait_arguments}},
    {Routine::uncork_fork, "uncork_fork", std::span<const ArgumentInfo>{uncork_fork_arguments}},
    {Routine::swap_integer, "swap_integer", std::span<const ArgumentInfo>{swap_integer_arguments}},
    {Routine::set_service_policy, "set_service_policy", std::span<const ArgumentInfo>{set_service_policy_arguments}},
    {Routine::log, "log", std::span<const ArgumentInfo>{log_arguments}},
    {Routine::lookup_per_user_context, "lookup_per_user_context", std::span<const ArgumentInfo>{lookup_per_user_context_arguments}},
    {Routine::move_subset, "move_subset", std::span<const ArgumentInfo>{move_subset_arguments}},
    {Routine::swap_complex, "swap_complex", std::span<const ArgumentInfo>{swap_complex_arguments}},
    {Routine::log_drain, "log_drain", std::span<const ArgumentInfo>{log_drain_arguments}},
    {Routine::log_forward, "log_forward", std::span<const ArgumentInfo>{log_forward_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::protocol_vproc
