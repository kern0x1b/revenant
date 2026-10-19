// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>

namespace shade::darwin::process_policy {

// bsd/sys/process_policy.h and bsd/kern/process_policy.c in XNU.
inline constexpr std::uint32_t syscall_number = 323;
inline constexpr std::uint32_t scope_process = 1;
inline constexpr std::uint32_t scope_thread = 2;
inline constexpr std::uint32_t action_apply = 1;
inline constexpr std::uint32_t action_restore = 2;
inline constexpr std::uint32_t action_deny_inherit = 3;
inline constexpr std::uint32_t action_deny_self_set = 4;
inline constexpr std::uint32_t action_enable = 5;
inline constexpr std::uint32_t action_disable = 6;
inline constexpr std::uint32_t action_set = 10;
inline constexpr std::uint32_t action_get = 11;
inline constexpr std::uint32_t action_add = 12;
inline constexpr std::uint32_t action_remove = 13;
inline constexpr std::uint32_t action_hold = 14;
inline constexpr std::uint32_t action_drop = 15;

inline constexpr std::uint32_t policy_background = 1;
inline constexpr std::uint32_t policy_hardware_access = 2;
inline constexpr std::uint32_t policy_resource_starvation = 3;
inline constexpr std::uint32_t policy_resource_usage = 4;
inline constexpr std::uint32_t policy_app_lifecycle = 5;
inline constexpr std::uint32_t policy_apptype = 6;
inline constexpr std::uint32_t policy_boost = 7;
inline constexpr std::uint32_t ios_donate_importance = 6;
inline constexpr std::uint32_t ios_hold_importance = 7;
inline constexpr std::uint32_t ios_drop_importance = 8;
inline constexpr std::uint32_t boost_important = 1;
inline constexpr std::uint32_t boost_donation = 3;

[[nodiscard]] constexpr bool is_action(std::uint32_t action)
{
    switch (action) {
    case action_apply:
    case action_restore:
    case action_deny_inherit:
    case action_deny_self_set:
    case action_enable:
    case action_disable:
    case action_set:
    case action_get:
    case action_add:
    case action_remove:
    case action_hold:
    case action_drop:
        return true;
    default:
        return false;
    }
}

} // namespace shade::darwin::process_policy
