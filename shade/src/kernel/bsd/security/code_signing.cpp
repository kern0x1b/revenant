// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the loaded executable's entitlement payload through csops(2).
// https://github.com/apple-oss-distributions/xnu/blob/xnu-2050.18.24/bsd/kern/kern_proc.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <array>
#include <limits>
#include <mutex>
#include <vector>

namespace shade {

void CompatibilityKernel::dispatch_bsd_code_signing(Cpu& cpu, bool require_audit_token)
{
    constexpr std::uint32_t entitlements_blob = 7U;
    constexpr std::uint32_t entitlement_magic = 0xfade7171U;
    constexpr std::uint32_t header_size = 8U;
    const auto& registers = cpu.registers();
    const auto target_pid = registers[0] == 0U ? process_.pid : registers[0];
    const auto operation = registers[1];
    const auto address = registers[2];
    const auto capacity = registers[3];
    const auto audit_address = require_audit_token ? registers[4] : 0U;
    if (require_audit_token && audit_address == 0U) {
        bsd_error(cpu, darwin::error::invalid_argument);
        return;
    }
    std::vector<std::byte> payload;
    {
        const std::lock_guard lock { shared_state_->mach_mutex };
        const auto target = shared_state_->processes.find(target_pid);
        if (target == shared_state_->processes.end() || target->second.exited) {
            bsd_error(cpu, darwin::error::no_such_process);
            return;
        }
        if (require_audit_token) {
            constexpr std::uint32_t audit_token_size = 8U * sizeof(std::uint32_t);
            if (!memory_.accessible(audit_address, audit_token_size,
                    MemoryPermission::Read)) {
                bsd_error(cpu, darwin::error::bad_address);
                return;
            }
            const auto token_pid = memory_.read32(audit_address + 20U);
            const auto token_version = memory_.read32(audit_address + 28U);
            if (token_pid != target_pid ||
                token_version != target->second.audit_identity_version) {
                bsd_error(cpu, darwin::error::no_such_process);
                return;
            }
        }
        if (operation != entitlements_blob) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        // Share the Mach-O payload already used by the AMFI user client.
        // Signature enforcement and signature status are not synthesized here.
        payload = target->second.code_signature_entitlements;
    }
    if (capacity < header_size) {
        bsd_error(cpu, darwin::error::result_too_large);
        return;
    }
    if (payload.size() >
        std::numeric_limits<std::uint32_t>::max() - header_size) {
        bsd_error(cpu, darwin::error::value_too_large);
        return;
    }
    const auto size = header_size + static_cast<std::uint32_t>(payload.size());
    const auto short_buffer = capacity < size;
    std::array<std::byte, header_size> header { };
    const auto encode = [&header](std::size_t offset, std::uint32_t value) {
        for (unsigned byte = 0; byte < 4U; ++byte)
            header[offset + byte] =
                static_cast<std::byte>(value >> ((3U - byte) * 8U));
    };
    // XNU returns eight zero bytes when no entitlements exist. A size probe
    // returns a zero magic and the required big-endian blob length with ERANGE.
    if (!payload.empty()) {
        encode(0U, short_buffer ? 0U : entitlement_magic);
        encode(4U, size);
    }
    std::vector<std::byte> blob { header.begin(), header.end() };
    if (!short_buffer)
        blob.insert(blob.end(), payload.begin(), payload.end());
    if (!memory_.copy_in(address, blob)) {
        bsd_error(cpu, darwin::error::bad_address);
        return;
    }
    if (short_buffer) {
        bsd_error(cpu, darwin::error::result_too_large);
        return;
    }
    bsd_success(cpu, 0U);
}

} // namespace shade
