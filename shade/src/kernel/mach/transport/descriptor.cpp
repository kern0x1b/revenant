// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Decode guest Mach descriptor kinds, dispositions and memory
// ownership flags.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/message.h

#include "kernel/mach_descriptor_transport.hpp"

#include "mach/mig_wire_abi.hpp"

#include <limits>

namespace shade::mach_transport {
namespace {

    std::uint32_t read_word(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        if (offset + darwin::mig_wire::word_size > bytes.size())
            return 0;
        std::uint32_t result = 0;
        for (std::size_t byte = 0; byte < darwin::mig_wire::word_size; ++byte) {
            result |= std::to_integer<std::uint32_t>(bytes[offset + byte])
                      << (byte * 8U);
        }
        return result;
    }

    std::optional<DescriptorKind> descriptor_kind(std::uint32_t metadata)
    {
        switch (metadata >> darwin::mig_wire::descriptor_type_shift) {
        case darwin::mig_wire::port_descriptor_type:
            return DescriptorKind::Port;
        case darwin::mig_wire::ool_descriptor_type:
            return DescriptorKind::OutOfLineMemory;
        case darwin::mig_wire::ool_ports_descriptor_type:
            return DescriptorKind::OutOfLinePorts;
        default:
            return std::nullopt;
        }
    }

} // namespace

bool Descriptor::deallocate() const
{
    return (metadata & darwin::mig_wire::descriptor_deallocate_mask) != 0;
}

std::uint32_t Descriptor::disposition() const
{
    return (metadata >> darwin::mig_wire::descriptor_disposition_shift) & 0xffU;
}

std::optional<std::vector<Descriptor>> parse_descriptors(
    std::span<const std::byte> message)
{
    if (message.size() < darwin::mig_wire::message_header_size)
        return std::nullopt;
    const auto bits = read_word(message, darwin::mig_wire::header_bits_offset);
    if ((bits & darwin::mig_wire::message_complex_bit) == 0)
        return std::vector<Descriptor> { };
    if (message.size() < darwin::mig_wire::complex_descriptor_base)
        return std::nullopt;

    const auto count =
        read_word(message, darwin::mig_wire::complex_descriptor_count_offset);
    if (count > (std::numeric_limits<std::size_t>::max() -
                    darwin::mig_wire::complex_descriptor_base) /
                    darwin::mig_wire::descriptor_size) {
        return std::nullopt;
    }
    const auto descriptor_end =
        static_cast<std::size_t>(darwin::mig_wire::complex_descriptor_base) +
        static_cast<std::size_t>(count) * darwin::mig_wire::descriptor_size;
    if (descriptor_end > message.size())
        return std::nullopt;

    std::vector<Descriptor> descriptors;
    descriptors.reserve(count);
    for (std::uint32_t index = 0; index < count; ++index) {
        const auto offset = darwin::mig_wire::descriptor_offset(index);
        const auto metadata = read_word(
            message, darwin::mig_wire::descriptor_metadata_offset(index));
        const auto kind = descriptor_kind(metadata);
        if (!kind)
            return std::nullopt;
        descriptors.push_back(
            Descriptor { *kind, offset, read_word(message, offset),
                read_word(message, offset + darwin::mig_wire::word_size),
                metadata });
    }
    return descriptors;
}

} // namespace shade::mach_transport
