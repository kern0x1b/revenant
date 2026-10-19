// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest audit-session identity queries and updates.

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include "../mach/support.hpp"
#include "support.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <optional>
#include <span>

namespace shade {
namespace {

    constexpr auto send_right =
        xnu::ipc::type_mask(xnu::ipc::Right::Send);

    std::optional<std::uint32_t> copyout_audit_session_port_locked(
        KernelSharedState& state, std::uint32_t process_id,
        std::uint32_t session_id)
    {
        auto session = state.audit_session_port_objects.find(session_id);
        if (session == state.audit_session_port_objects.end()) {
            const auto object = state.allocate_mach_object();
            if (!state.mach_port_objects.create(object))
                return std::nullopt;
            session = state.audit_session_port_objects
                          .emplace(session_id, object)
                          .first;
        }
        const auto name = state.mach_namespaces.copyout(
            process_id, session->second, send_right);
        if (name) {
            static_cast<void>(state.mach_port_objects.increment_make_send_count(
                session->second));
        }
        return name;
    }

} // namespace

void CompatibilityKernel::dispatch_bsd_audit_session(
    Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    if (number == darwin::syscall::get_audit_address) {
        // ARM32 auditinfo_addr: auid, mask[2], terminal port/type/address[4],
        // session ID, then the naturally aligned 64-bit session flags.
        std::array<std::byte, 48U> audit_info { };
        mach_support::write_little_word(
            audit_info, 36U, process_.audit_session_id);
        const auto size =
            std::min<std::size_t>(registers[1], audit_info.size());
        if (size != 0U &&
            !memory_.copy_in(registers[0],
                std::span<const std::byte> { audit_info }.first(size))) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0U);
        return;
    }

    std::lock_guard mach_lock { shared_state_->mach_mutex };

    if (number == darwin::syscall::audit_session_self) {
        const auto name = copyout_audit_session_port_locked(*shared_state_,
            process_.pid, process_.audit_session_id);
        if (!name) {
            bsd_error(cpu, darwin::error::no_memory);
            return;
        }
        bsd_success(cpu, *name);
        return;
    }

    if (number == darwin::syscall::audit_session_join) {
        const auto object = mach_support::resolve_name_with_right(
            *shared_state_, process_.pid, registers[0],
            xnu::ipc::Right::Send);
        auto session_id = std::optional<std::uint32_t> { };
        if (object) {
            for (const auto& [candidate, session_object] :
                shared_state_->audit_session_port_objects) {
                if (session_object == *object) {
                    session_id = candidate;
                    break;
                }
            }
        }
        if (!session_id) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        process_.audit_session_id = *session_id;
        bsd_success(cpu, *session_id);
        return;
    }

    const auto requested = static_cast<std::int32_t>(registers[0]);
    const auto session_id = requested == -1
                                ? process_.audit_session_id
                                : static_cast<std::uint32_t>(requested);
    if (requested < -1 ||
        !shared_state_->audit_session_port_objects.contains(session_id)) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return;
    }
    const auto name = copyout_audit_session_port_locked(
        *shared_state_, process_.pid, session_id);
    if (!name) {
        bsd_error(cpu, darwin::error::no_memory);
        return;
    }
    if (!memory_.write32(registers[1], *name)) {
        static_cast<void>(mach_support::modify_port_references_locked(
            *shared_state_, process_.pid, *name, xnu::ipc::Right::Send, -1));
        bsd_error(cpu, bsd_support::bad_address);
        return;
    }
    bsd_success(cpu, 0U);
}

} // namespace shade
