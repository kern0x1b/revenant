// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse and manipulate guest Mach port and out-of-line message
// descriptors.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/message.h

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <vector>

namespace shade::mach_transport {

enum class DescriptorKind : std::uint8_t {
    Port,
    OutOfLineMemory,
    OutOfLinePorts,
};

struct Descriptor {
    DescriptorKind kind { DescriptorKind::Port };
    std::uint32_t offset { };
    std::uint32_t address_or_name { };
    std::uint32_t count_or_size { };
    std::uint32_t metadata { };

    [[nodiscard]] bool deallocate() const;
    [[nodiscard]] std::uint32_t disposition() const;
};

// Parses the natural-aligned 32-bit descriptor table used by Darwin 8. An
// empty vector is a valid simple message; nullopt denotes malformed or unknown
// complex descriptor data.
[[nodiscard]] std::optional<std::vector<Descriptor>> parse_descriptors(
    std::span<const std::byte> message);

} // namespace shade::mach_transport
