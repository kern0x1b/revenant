// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 system_configuration MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/configd/blob/configd-137.3/SystemConfiguration.fproj/config.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::system_configuration {

inline constexpr std::string_view subsystem_name{"config"};
inline constexpr std::uint32_t subsystem_base = 20000U;

enum class Routine : std::uint32_t {
    configopen = 20000U,
    configclose = 20001U,
    configlock = 20002U,
    configunlock = 20003U,
    configlist = 20008U,
    configadd = 20009U,
    configget = 20010U,
    configset = 20011U,
    configremove = 20012U,
    configtouch = 20013U,
    configadd_s = 20014U,
    confignotify = 20015U,
    configget_m = 20016U,
    configset_m = 20017U,
    notifyadd = 20018U,
    notifyremove = 20019U,
    notifychanges = 20020U,
    notifyviaport = 20021U,
    notifyviafd = 20022U,
    notifyviasignal = 20023U,
    notifycancel = 20024U,
    notifyset = 20025U,
    snapshot = 20029U,
};

inline constexpr std::array<ArgumentInfo, 5> configopen_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 60U, 4294967295U},
    {"options", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 64U, 4294967295U},
    {"session", "mach_port_move_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> configclose_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> configlock_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> configunlock_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> configlist_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"xmlData", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"isRegex", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"list", "xmlDataOut, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 52U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> configadd_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 60U, 4294967295U},
    {"data", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 64U, 4294967295U},
    {"newInstance", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> configget_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"data", "xmlDataOut, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
    {"newInstance", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 52U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 56U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> configset_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 60U, 4294967295U},
    {"data", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 64U, 4294967295U},
    {"instance", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 68U, 4294967295U, 4294967295U, 4294967295U},
    {"newInstance", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> configremove_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> configtouch_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> configadd_s_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 60U, 4294967295U},
    {"data", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 64U, 4294967295U},
    {"newInstance", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> confignotify_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> configget_m_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"keys", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 60U, 4294967295U},
    {"patterns", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 64U, 4294967295U},
    {"data", "xmlDataOut, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 52U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> configset_m_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"data", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 72U, 4294967295U},
    {"remove", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 76U, 4294967295U},
    {"notify", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 52U, 4294967295U, 80U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> notifyadd_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"isRegex", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> notifyremove_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"key", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"isRegex", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> notifychanges_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"list", "xmlDataOut, dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 52U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> notifyviaport_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"port", "mach_port_move_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"msgid", "mach_msg_id_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> notifyviafd_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"path", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"identifier", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> notifyviasignal_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"sig", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> notifycancel_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> notifyset_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"keys", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 60U, 4294967295U},
    {"patterns", "xmlData", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 64U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> snapshot_arguments{{
    {"server", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"status", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 23> routines{{
    {Routine::configopen, "configopen", std::span<const ArgumentInfo>{configopen_arguments}},
    {Routine::configclose, "configclose", std::span<const ArgumentInfo>{configclose_arguments}},
    {Routine::configlock, "configlock", std::span<const ArgumentInfo>{configlock_arguments}},
    {Routine::configunlock, "configunlock", std::span<const ArgumentInfo>{configunlock_arguments}},
    {Routine::configlist, "configlist", std::span<const ArgumentInfo>{configlist_arguments}},
    {Routine::configadd, "configadd", std::span<const ArgumentInfo>{configadd_arguments}},
    {Routine::configget, "configget", std::span<const ArgumentInfo>{configget_arguments}},
    {Routine::configset, "configset", std::span<const ArgumentInfo>{configset_arguments}},
    {Routine::configremove, "configremove", std::span<const ArgumentInfo>{configremove_arguments}},
    {Routine::configtouch, "configtouch", std::span<const ArgumentInfo>{configtouch_arguments}},
    {Routine::configadd_s, "configadd_s", std::span<const ArgumentInfo>{configadd_s_arguments}},
    {Routine::confignotify, "confignotify", std::span<const ArgumentInfo>{confignotify_arguments}},
    {Routine::configget_m, "configget_m", std::span<const ArgumentInfo>{configget_m_arguments}},
    {Routine::configset_m, "configset_m", std::span<const ArgumentInfo>{configset_m_arguments}},
    {Routine::notifyadd, "notifyadd", std::span<const ArgumentInfo>{notifyadd_arguments}},
    {Routine::notifyremove, "notifyremove", std::span<const ArgumentInfo>{notifyremove_arguments}},
    {Routine::notifychanges, "notifychanges", std::span<const ArgumentInfo>{notifychanges_arguments}},
    {Routine::notifyviaport, "notifyviaport", std::span<const ArgumentInfo>{notifyviaport_arguments}},
    {Routine::notifyviafd, "notifyviafd", std::span<const ArgumentInfo>{notifyviafd_arguments}},
    {Routine::notifyviasignal, "notifyviasignal", std::span<const ArgumentInfo>{notifyviasignal_arguments}},
    {Routine::notifycancel, "notifycancel", std::span<const ArgumentInfo>{notifycancel_arguments}},
    {Routine::notifyset, "notifyset", std::span<const ArgumentInfo>{notifyset_arguments}},
    {Routine::snapshot, "snapshot", std::span<const ArgumentInfo>{snapshot_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::system_configuration
