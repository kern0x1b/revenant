// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <string_view>

namespace shade {

void CompatibilityKernel::install_commpage()
{
    // ARM cpu_capabilities.h: capabilities at +0x20, configured CPU count
    // at +0x22, and active/physical/logical counts at +0x34/35/36.
    // Keep the older user ABI address available for legacy library clients.
    std::array<std::byte, AddressSpace::page_size> page { };
    constexpr std::string_view signature { "commpage 32-bit" };
    for (std::size_t index = 0; index < signature.size(); ++index)
        page[index] = static_cast<std::byte>(signature[index]);
    page[0x1e] = std::byte { 1 };
    const auto count = std::clamp(virtual_processor_count_, 1U, 255U);
    // kUP is bit 15; kNumCPUs occupies bits 16..23. Do not advertise CPU
    // features or user-accessible timers that the kernel does not implement.
    page[0x21] = count == 1U ? std::byte { 0x80 } : std::byte { 0 };
    page[0x22] = static_cast<std::byte>(count);
    page[0x34] = static_cast<std::byte>(count);
    page[0x35] = static_cast<std::byte>(count);
    page[0x36] = static_cast<std::byte>(count);
    const auto install = [&](std::uint32_t address) {
        if (!memory_.mapped(address))
            static_cast<void>(memory_.map(
                address, AddressSpace::page_size, MemoryPermission::Read));
        static_cast<void>(memory_.copy_in(address, page));
    };
    install(0x40000000U);
    if (shared_state_->darwin_abi.arm_commpage ==
        DarwinArmCommpageAbi::HighAddress)
        install(0xffff1000U);
    if (shared_state_->darwin_abi.arm_commpage ==
        DarwinArmCommpageAbi::HighDataAddress)
        install(0xffff4000U);
}

} // namespace shade
