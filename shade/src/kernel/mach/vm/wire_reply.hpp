// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode shared Mach VM reply forms and output words.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#pragma once

#include "foundation/address_space.hpp"
#include "mach/mig_wire_abi.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>

namespace shade::mach_vm_support {

inline constexpr std::uint32_t kern_success = 0;
inline constexpr std::uint32_t kern_invalid_address = 1;
inline constexpr std::uint32_t kern_resource_shortage = 6;
inline constexpr std::uint32_t mach_receive_invalid_data = 0x1000'4008U;
inline constexpr std::uint32_t simple_reply_size =
    darwin::mig_wire::simple_reply_payload_base;

inline bool write_words(AddressSpace& memory, std::uint32_t address,
    std::span<const std::uint32_t> words)
{
    for (std::size_t index = 0; index < words.size(); ++index) {
        if (!memory.write32(address + static_cast<std::uint32_t>(index) *
                                          darwin::mig_wire::word_size,
                words[index])) {
            return false;
        }
    }
    return true;
}

inline bool write_simple_reply(AddressSpace& memory, std::uint32_t address,
    std::uint32_t reply_port, std::uint32_t identifier, std::uint32_t result)
{
    const std::array reply {
        darwin::mig_wire::message_bits(
            darwin::mig_wire::disposition_move_send_once),
        simple_reply_size,
        reply_port,
        0U,
        0U,
        identifier + 100U,
        0U, // NDR migration/character/float representation word
        1U, // NDR little-endian integer representation word
        result,
    };
    return write_words(memory, address, reply);
}

} // namespace shade::mach_vm_support
