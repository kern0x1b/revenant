// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define natural-aligned ARM32 Mach message headers, descriptors and
// reply offsets.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/message.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/ndr.h

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::darwin::mig_wire {

// Darwin 8 uses the 32-bit natural-aligned Mach message ABI on ARMv6.
inline constexpr std::uint32_t message_header_size = 24;
inline constexpr std::uint32_t header_bits_offset = 0;
inline constexpr std::uint32_t header_size_offset = 4;
inline constexpr std::uint32_t header_remote_port_offset = 8;
inline constexpr std::uint32_t header_local_port_offset = 12;
inline constexpr std::uint32_t header_voucher_offset = 16;
inline constexpr std::uint32_t header_identifier_offset = 20;
inline constexpr std::uint32_t complex_descriptor_count_offset = 24;
inline constexpr std::uint32_t complex_body_size = 4;
inline constexpr std::uint32_t descriptor_size = 12;
inline constexpr std::uint32_t descriptor_deallocate_mask = 0xffU;
inline constexpr std::uint32_t descriptor_copy_shift = 8;
inline constexpr std::uint32_t descriptor_disposition_shift = 16;
inline constexpr std::uint32_t descriptor_type_shift = 24;
inline constexpr std::uint32_t port_descriptor_type = 0;
inline constexpr std::uint32_t ool_descriptor_type = 1;
inline constexpr std::uint32_t ool_ports_descriptor_type = 2;
inline constexpr std::uint32_t ndr_record_size = 8;
inline constexpr std::uint32_t return_code_size = 4;
inline constexpr std::uint32_t word_size = 4;
inline constexpr std::uint32_t trailer_elements_shift = 24;
inline constexpr std::uint32_t trailer_elements_mask = 0xf;
inline constexpr std::uint32_t trailer_null = 0;
inline constexpr std::uint32_t trailer_sequence = 1;
inline constexpr std::uint32_t trailer_sender = 2;
inline constexpr std::uint32_t trailer_audit = 3;
inline constexpr std::uint32_t trailer_minimum_size = 8;
inline constexpr std::uint32_t trailer_sequence_size = 12;
inline constexpr std::uint32_t trailer_sender_size = 20;
inline constexpr std::uint32_t trailer_audit_size = 52;

inline constexpr std::uint32_t message_complex_bit = 0x80000000U;
inline constexpr std::uint32_t disposition_move_receive = 16;
inline constexpr std::uint32_t disposition_move_send = 17;
inline constexpr std::uint32_t disposition_move_send_once = 18;
inline constexpr std::uint32_t disposition_copy_send = 19;
inline constexpr std::uint32_t disposition_make_send = 20;
inline constexpr std::uint32_t disposition_make_send_once = 21;
inline constexpr std::uint32_t ool_copy_physical = 0;
inline constexpr std::uint32_t ool_copy_virtual = 1;

constexpr std::uint32_t message_bits(std::uint32_t remote_disposition,
    std::uint32_t local_disposition = 0, bool complex = false)
{
    return remote_disposition | (local_disposition << 8U) |
           (complex ? message_complex_bit : 0U);
}

constexpr std::uint32_t port_descriptor_metadata(std::uint32_t disposition)
{
    return (disposition << descriptor_disposition_shift) |
           (port_descriptor_type << descriptor_type_shift);
}

constexpr std::uint32_t received_port_disposition(
    std::uint32_t send_disposition)
{
    switch (send_disposition) {
    case disposition_move_receive:
        return disposition_move_receive;
    case disposition_move_send:
    case disposition_copy_send:
    case disposition_make_send:
        return disposition_move_send;
    case disposition_move_send_once:
    case disposition_make_send_once:
        return disposition_move_send_once;
    default:
        return send_disposition;
    }
}

constexpr std::uint32_t replace_descriptor_disposition(
    std::uint32_t metadata, std::uint32_t disposition)
{
    constexpr auto mask = 0xffU << descriptor_disposition_shift;
    return (metadata & ~mask) | (disposition << descriptor_disposition_shift);
}

constexpr std::uint32_t ool_descriptor_metadata(
    bool deallocate, std::uint32_t copy = ool_copy_virtual)
{
    return (ool_descriptor_type << descriptor_type_shift) |
           (copy << descriptor_copy_shift) | (deallocate ? 1U : 0U);
}

constexpr std::uint32_t ool_ports_descriptor_metadata(std::uint32_t disposition,
    bool deallocate, std::uint32_t copy = ool_copy_virtual)
{
    return (ool_ports_descriptor_type << descriptor_type_shift) |
           (disposition << descriptor_disposition_shift) |
           (copy << descriptor_copy_shift) | (deallocate ? 1U : 0U);
}

inline constexpr std::uint32_t complex_descriptor_base =
    message_header_size + complex_body_size;
inline constexpr std::uint32_t simple_request_payload_base =
    message_header_size + ndr_record_size;
inline constexpr std::uint32_t simple_reply_payload_base =
    simple_request_payload_base + return_code_size;

constexpr std::uint32_t descriptor_offset(std::size_t index)
{
    return complex_descriptor_base +
           static_cast<std::uint32_t>(index) * descriptor_size;
}

constexpr std::uint32_t descriptor_name_offset(std::size_t index)
{
    return descriptor_offset(index);
}

constexpr std::uint32_t descriptor_metadata_offset(std::size_t index)
{
    return descriptor_offset(index) + 2U * word_size;
}

constexpr std::uint32_t simple_request_word(std::size_t index)
{
    return simple_request_payload_base +
           static_cast<std::uint32_t>(index) * word_size;
}

constexpr std::uint32_t simple_reply_word(std::size_t index)
{
    return simple_reply_payload_base +
           static_cast<std::uint32_t>(index) * word_size;
}

constexpr std::uint32_t complex_ndr_offset(std::size_t descriptor_count)
{
    return descriptor_offset(descriptor_count);
}

constexpr std::uint32_t complex_request_word(
    std::size_t descriptor_count, std::size_t index)
{
    return complex_ndr_offset(descriptor_count) + ndr_record_size +
           static_cast<std::uint32_t>(index) * word_size;
}

constexpr std::uint32_t complex_reply_word(
    std::size_t descriptor_count, std::size_t index)
{
    return complex_ndr_offset(descriptor_count) + ndr_record_size +
           static_cast<std::uint32_t>(index) * word_size;
}

static_assert(descriptor_name_offset(0) == 28);
static_assert(descriptor_metadata_offset(0) == 36);
static_assert(simple_request_word(0) == 32);
static_assert(simple_reply_word(0) == 36);
static_assert(complex_request_word(1, 0) == 48);
static_assert(complex_reply_word(1, 0) == 48);
static_assert(message_bits(disposition_copy_send, disposition_make_send_once,
                  true) == 0x80001513U);
static_assert(port_descriptor_metadata(disposition_move_send) == 0x00110000U);
static_assert(
    received_port_disposition(disposition_copy_send) == disposition_move_send);
static_assert(received_port_disposition(disposition_make_send_once) ==
              disposition_move_send_once);
static_assert(replace_descriptor_disposition(
                  port_descriptor_metadata(disposition_copy_send),
                  disposition_move_send) ==
              port_descriptor_metadata(disposition_move_send));
static_assert(ool_descriptor_metadata(true) == 0x01000101U);
static_assert(
    ool_ports_descriptor_metadata(disposition_move_send, true) == 0x02110101U);

} // namespace shade::darwin::mig_wire
