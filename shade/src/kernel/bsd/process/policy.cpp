// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Validate process-policy requests and preserve task donation eligibility.
// Resource enforcement and Mach importance inheritance require their own
// providers; do not report those operations as applied when none exists.
// https://github.com/apple-oss-distributions/xnu/blob/xnu-2422.1.72/bsd/kern/process_policy.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_process_policy_abi.hpp"

#include <cstdint>
#include <mutex>

namespace shade {

bool CompatibilityKernel::dispatch_bsd_process_policy(
    Cpu& cpu, std::uint32_t number)
{
    using namespace darwin::process_policy;
    if (number != syscall_number)
        return false;

    const auto& registers = cpu.registers();
    const auto scope = registers[0];
    const auto action = registers[1];
    const auto policy = registers[2];
    const auto subtype = registers[3];
    const auto target_pid = static_cast<std::int32_t>(registers[5]);
    if ((scope != scope_process && scope != scope_thread) ||
        !is_action(action)) {
        bsd_error(cpu, darwin::error::invalid_argument);
        return true;
    }

    const auto resolved_pid =
        target_pid == 0 ? process_.pid : static_cast<std::uint32_t>(target_pid);
    std::uint32_t result { };
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto target = shared_state_->processes.find(resolved_pid);
        if (target_pid < 0 || target == shared_state_->processes.end() ||
            target->second.exited) {
            bsd_error(cpu, darwin::error::no_such_process);
            return true;
        }
        auto& record = target->second;
        // Embedded XNU permits the real/effective owner or root to control a
        // process. Credentials belong to the guest, never the host user.
        if (resolved_pid != process_.pid && process_.effective_uid != 0U &&
            process_.uid != 0U &&
            process_.effective_uid != record.effective_uid &&
            process_.uid != record.effective_uid) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return true;
        }

        switch (policy) {
        case policy_apptype:
            if (scope != scope_process ||
                (subtype >= ios_donate_importance &&
                    subtype <= ios_drop_importance &&
                    (action != action_enable || resolved_pid != process_.pid))) {
                result = darwin::error::invalid_argument;
            } else if (subtype == ios_donate_importance) {
                record.importance_donor = true;
            } else if (subtype <= 4U || subtype == ios_hold_importance ||
                       subtype == ios_drop_importance) {
                result = darwin::error::not_supported;
            } else {
                result = darwin::error::invalid_argument;
            }
            break;
        case policy_boost:
            if (scope != scope_process || resolved_pid != process_.pid) {
                result = darwin::error::invalid_argument;
            } else if (subtype == boost_donation && action == action_set) {
                record.importance_donor = true;
            } else if (subtype == boost_important &&
                       (action == action_hold || action == action_drop)) {
                result = darwin::error::not_supported;
            } else {
                result = darwin::error::invalid_argument;
            }
            break;
        case policy_background:
        case policy_hardware_access:
            result = darwin::error::not_supported;
            break;
        case policy_resource_starvation:
            result = subtype <= 1U && action == action_restore
                         ? darwin::error::not_supported
                         : darwin::error::invalid_argument;
            break;
        case policy_resource_usage:
            result = subtype <= 6U
                         ? darwin::error::not_supported
                         : darwin::error::invalid_argument;
            if (subtype == 3U && action != action_get && action != action_set &&
                action != action_apply && action != action_restore)
                result = darwin::error::invalid_argument;
            break;
        case policy_app_lifecycle:
            result = subtype <= 3U
                         ? darwin::error::not_supported
                         : darwin::error::invalid_argument;
            break;
        default:
            result = darwin::error::invalid_argument;
            break;
        }
    }
    output_.write("[process-policy] caller=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(resolved_pid) +
                  " scope=" + std::to_string(scope) +
                  " action=" + std::to_string(action) +
                  " policy=" + std::to_string(policy) +
                  " subtype=" + std::to_string(subtype) +
                  " result=" + std::to_string(result) + "\n");
    if (result != 0U)
        bsd_error(cpu, result);
    else
        bsd_success(cpu, 0);
    return true;
}

} // namespace shade
