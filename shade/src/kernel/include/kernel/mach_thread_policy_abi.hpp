// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define Mach thread scheduling policy flavors and request layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_act.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_policy.h

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::darwin::mach::thread_policy {

// XNU osfmk/mach/thread_act.defs and thread_policy.h. The request
// offsets are also verified against iPhone OS 1.0 libSystem.B.dylib's
// _thread_policy_set MIG client stub.
constexpr std::uint32_t subsystem_base = 3600;
constexpr std::uint32_t legacy_policy_message = subsystem_base + 16;
constexpr std::uint32_t policy_set_message = subsystem_base + 17;
constexpr std::uint32_t policy_get_message = subsystem_base + 18;

constexpr std::uint32_t legacy_timeshare_policy = 1;
constexpr std::uint32_t legacy_round_robin_policy = 2;
constexpr std::uint32_t legacy_fifo_policy = 4;

constexpr std::size_t legacy_request_policy_offset = 32;
constexpr std::size_t legacy_request_count_offset = 36;
constexpr std::size_t legacy_request_base_offset = 40;
constexpr std::size_t legacy_request_set_limit_offset = 44;
constexpr std::size_t legacy_minimum_request_size = 48;
constexpr std::size_t legacy_policy_word_count = 1;

constexpr std::uint32_t extended_policy = 1;
constexpr std::uint32_t time_constraint_policy = 2;
constexpr std::uint32_t precedence_policy = 3;

constexpr std::size_t request_flavor_offset = 32;
constexpr std::size_t request_count_offset = 36;
constexpr std::size_t request_policy_offset = 40;
constexpr std::size_t minimum_request_size = 44;
constexpr std::size_t maximum_policy_word_count = 16;

constexpr std::size_t extended_policy_word_count = 1;
constexpr std::size_t time_constraint_policy_word_count = 4;
constexpr std::size_t precedence_policy_word_count = 1;
constexpr std::size_t realtime_period_index = 0;
constexpr std::size_t realtime_computation_index = 1;
constexpr std::size_t realtime_constraint_index = 2;
constexpr std::size_t realtime_preemptible_index = 3;
constexpr std::size_t precedence_importance_index = 0;

constexpr std::uint32_t mig_reply_id_delta = 100;
constexpr std::uint32_t simple_reply_size = 36;
constexpr std::size_t simple_reply_word_count = simple_reply_size / 4;

constexpr std::uint64_t absolute_time_units_per_second = 1'000'000'000ULL;

} // namespace shade::darwin::mach::thread_policy
