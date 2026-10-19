// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Select launchd vproc wire-message profiles for differing routine
// tails.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/launchd/blob/launchd-257/launchd/src/protocol_job.defs

#pragma once

#include "mach/protocol_vproc_mig_ids.hpp"

#include <array>
#include <cstdint>
#include <string_view>

namespace shade::protocol_vproc {

// Apple kept protocol_vproc's public prefix stable while adding and removing
// private routines in the tail.  Describe the wire capability that changes
// the following routine identifiers rather than keying compatibility to an
// OS build or to a particular executable path.
struct Contract {
    std::string_view name;
    std::uint32_t log_message_id;
};

inline constexpr Contract without_service_policy { "without-service-policy",
    xnu::mig::protocol_vproc::id(
        xnu::mig::protocol_vproc::Routine::swap_integer) +
        1U };
inline constexpr Contract with_service_policy { "with-service-policy",
    xnu::mig::protocol_vproc::id(
        xnu::mig::protocol_vproc::Routine::log) };
inline constexpr std::array contracts { without_service_policy,
    with_service_policy };

[[nodiscard]] constexpr const Contract* contract_for_log_message(
    std::uint32_t message_id)
{
    for (const auto& contract : contracts) {
        if (contract.log_message_id == message_id)
            return &contract;
    }
    return nullptr;
}

} // namespace shade::protocol_vproc
