// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe ARM32 Mach VM message widths and profile-dependent field
// offsets.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#pragma once

#include "foundation/address_space.hpp"
#include "device_state/darwin_abi.hpp"

#include <cstdint>
#include <optional>
#include <vector>

namespace shade::mach_vm_support {

// Later ARM32 mach_vm clients widened addresses and sizes within Darwin 11.
// The vm_map subsystem retains natural-sized fields. Both use four-byte MIG
// alignment, including for an eight-byte address following a scalar word.
class MachVmWireFormat {
public:
    [[nodiscard]] static constexpr MachVmWireFormat for_interface(
        bool mach_vm, DarwinMachVmAddressWidth address_width)
    {
        const auto wide =
            mach_vm && address_width == DarwinMachVmAddressWidth::Wide64;
        return MachVmWireFormat { wide ? 8U : 4U };
    }

    [[nodiscard]] constexpr std::uint32_t address_size() const { return size_; }

    [[nodiscard]] std::optional<std::uint64_t> read_address(
        const AddressSpace& memory, std::uint32_t address) const
    {
        if (size_ == 8U)
            return memory.read64(address);
        if (const auto value = memory.read32(address))
            return *value;
        return std::nullopt;
    }

    void append_address(
        std::vector<std::uint32_t>& words, std::uint64_t address) const
    {
        words.push_back(static_cast<std::uint32_t>(address));
        if (size_ == 8U)
            words.push_back(static_cast<std::uint32_t>(address >> 32U));
    }

private:
    explicit constexpr MachVmWireFormat(std::uint32_t size)
        : size_ { size }
    {
    }
    std::uint32_t size_;
};

} // namespace shade::mach_vm_support
