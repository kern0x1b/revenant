// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once

#include "foundation/address_space.hpp"
#include <array>
#include <cstdint>
#include <optional>

namespace shade {

struct KeventValue {
    std::uint64_t ident { };
    std::int16_t filter { };
    std::uint16_t flags { };
    std::uint32_t filter_flags { };
    std::int64_t data { };
    std::uint64_t user_data { };
    std::array<std::uint64_t, 2> extension { };
};

// Both syscall formats share knote state and readiness semantics. Only the
// guest copyin/copyout boundary depends on the event's wire representation.
class KeventWireFormat {
public:
    explicit constexpr KeventWireFormat(bool extended)
        : extended_ { extended }
    {
    }
    constexpr std::uint32_t size() const { return extended_ ? 48U : 20U; }
    std::optional<KeventValue> read(
        const AddressSpace& memory, std::uint32_t address) const
    {
        if (!memory.accessible(address, size(), MemoryPermission::Read))
            return std::nullopt;
        const auto delta = extended_ ? 4U : 0U;
        KeventValue value;
        value.ident =
            extended_ ? *memory.read64(address) : *memory.read32(address);
        value.filter =
            static_cast<std::int16_t>(*memory.read16(address + 4U + delta));
        value.flags = *memory.read16(address + 6U + delta);
        value.filter_flags = *memory.read32(address + 8U + delta);
        value.data =
            extended_
                ? static_cast<std::int64_t>(*memory.read64(address + 16U))
                : static_cast<std::int32_t>(*memory.read32(address + 12U));
        value.user_data = extended_ ? *memory.read64(address + 24U)
                                    : *memory.read32(address + 16U);
        if (extended_) {
            value.extension[0] = *memory.read64(address + 32U);
            value.extension[1] = *memory.read64(address + 40U);
        }
        return value;
    }
    bool write(AddressSpace& memory, std::uint32_t address,
        const KeventValue& value) const
    {
        if (!memory.accessible(address, size(), MemoryPermission::Write))
            return false;
        const auto delta = extended_ ? 4U : 0U;
        if (extended_) {
            if (!memory.write64(address, value.ident) ||
                !memory.write64(
                    address + 16U, static_cast<std::uint64_t>(value.data)) ||
                !memory.write64(address + 24U, value.user_data) ||
                !memory.write64(address + 32U, value.extension[0]) ||
                !memory.write64(address + 40U, value.extension[1]))
                return false;
        } else if (!memory.write32(
                       address, static_cast<std::uint32_t>(value.ident)) ||
                   !memory.write32(
                       address + 12U, static_cast<std::uint32_t>(value.data)) ||
                   !memory.write32(address + 16U,
                       static_cast<std::uint32_t>(value.user_data))) {
            return false;
        }
        return memory.write16(address + 4U + delta,
                   static_cast<std::uint16_t>(value.filter)) &&
               memory.write16(address + 6U + delta, value.flags) &&
               memory.write32(address + 8U + delta, value.filter_flags);
    }

private:
    bool extended_;
};

} // namespace shade
