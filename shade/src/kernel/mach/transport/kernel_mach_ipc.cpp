// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Normalize Mach headers and apply receive-side pointer fixups.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/message.h

#include "kernel/kernel_mach_ipc.hpp"
#include "mach/mig_wire_abi.hpp"

#include <array>
#include <limits>

namespace shade::mach_ipc {
namespace {

    std::uint32_t read_word(
        const std::vector<std::byte>& bytes, std::size_t offset)
    {
        std::uint32_t value = 0;
        for (std::size_t byte = 0; byte < 4; ++byte) {
            value |= std::to_integer<std::uint32_t>(bytes[offset + byte])
                     << (byte * 8U);
        }
        return value;
    }

    void write_word(
        std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t byte = 0; byte < 4; ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    }

    std::size_t requested_trailer_size(
        std::uint32_t options, DarwinMachVmAddressWidth context_width)
    {
        using namespace darwin::mig_wire;
        const auto elements =
            (options >> trailer_elements_shift) & trailer_elements_mask;
        if (elements == trailer_null)
            return trailer_minimum_size;
        if (elements == trailer_sequence)
            return trailer_sequence_size;
        if (elements == trailer_sender)
            return trailer_sender_size;
        if (elements == 4U) { // MACH_RCV_TRAILER_CTX
            return trailer_audit_size +
                (context_width == DarwinMachVmAddressWidth::Wide64 ? 8U : 4U);
        }
        return trailer_audit_size;
    }

} // namespace

bool normalize_send_header(std::vector<std::byte>& bytes, std::size_t send_size)
{
    if (bytes.size() < darwin::mig_wire::message_header_size ||
        send_size < darwin::mig_wire::message_header_size ||
        send_size != bytes.size() ||
        send_size > std::numeric_limits<std::uint32_t>::max()) {
        return false;
    }
    write_word(bytes, darwin::mig_wire::header_size_offset,
        static_cast<std::uint32_t>(send_size));
    return true;
}

bool apply_receive_pointer_fixups(const KernelSharedState::MachMessage& message,
    std::uint32_t receive_address, std::vector<std::byte>& received_bytes)
{
    for (const auto& fixup : message.receive_pointer_fixups) {
        const auto value_end = static_cast<std::uint64_t>(fixup.value_offset) +
                               sizeof(std::uint32_t);
        const auto target_address =
            static_cast<std::uint64_t>(receive_address) + fixup.target_offset;
        if (value_end > message.bytes.size() ||
            value_end > received_bytes.size() ||
            fixup.target_offset >= message.bytes.size() ||
            target_address > std::numeric_limits<std::uint32_t>::max()) {
            return false;
        }
        write_word(received_bytes, fixup.value_offset,
            static_cast<std::uint32_t>(target_address));
    }
    return true;
}

std::optional<ReceivedMessage> prepare_received_message(
    const KernelSharedState::MachMessage& message,
    std::uint32_t destination_name, std::uint32_t receive_options,
    std::uint32_t sequence_number, std::uint64_t context,
    DarwinMachVmAddressWidth context_width)
{
    if (message.bytes.size() < darwin::mig_wire::message_header_size) {
        return std::nullopt;
    }

    ReceivedMessage result;
    result.message_size = message.bytes.size();
    result.trailer_size = requested_trailer_size(receive_options, context_width);
    result.bytes = message.bytes;
    const auto aligned_size = (result.message_size + 3U) & ~std::size_t { 3U };
    result.bytes.resize(aligned_size + result.trailer_size, std::byte { 0 });

    const auto send_bits =
        read_word(result.bytes, darwin::mig_wire::header_bits_offset);
    const auto remote_disposition = send_bits & 0xffU;
    const auto local_disposition = (send_bits >> 8U) & 0xffU;
    result.caller_header_size =
        read_word(result.bytes, darwin::mig_wire::header_size_offset);
    const auto reply_port =
        read_word(result.bytes, darwin::mig_wire::header_local_port_offset);
    result.message_id =
        read_word(result.bytes, darwin::mig_wire::header_identifier_offset);
    write_word(result.bytes, darwin::mig_wire::header_bits_offset,
        (send_bits & 0xffff0000U) |
            darwin::mig_wire::received_port_disposition(local_disposition) |
            (darwin::mig_wire::received_port_disposition(remote_disposition)
                << 8U));
    write_word(
        result.bytes, darwin::mig_wire::header_remote_port_offset, reply_port);
    write_word(result.bytes, darwin::mig_wire::header_local_port_offset,
        destination_name);

    write_word(result.bytes, aligned_size, 0); // MACH_MSG_TRAILER_FORMAT_0
    write_word(result.bytes, aligned_size + 4U,
        static_cast<std::uint32_t>(result.trailer_size));
    if (result.trailer_size >= 12U) {
        write_word(result.bytes, aligned_size + 8U, sequence_number);
    }
    if (result.trailer_size >= 20U) {
        write_word(result.bytes, aligned_size + 12U, message.sender_uid);
        write_word(result.bytes, aligned_size + 16U, message.sender_gid);
    }
    if (result.trailer_size >= 52U) {
        const std::array<std::uint32_t, 8> audit_token {
            message.sender_uid,
            message.sender_uid,
            message.sender_gid,
            message.sender_uid,
            message.sender_gid,
            message.sender_pid,
            message.sender_pid,
            message.sender_identity_version,
        };
        for (std::size_t index = 0; index < audit_token.size(); ++index) {
            write_word(result.bytes, aligned_size + 20U + index * 4U,
                audit_token[index]);
        }
    }
    if (result.trailer_size >= 56U) {
        write_word(result.bytes, aligned_size + 52U,
            static_cast<std::uint32_t>(context));
        if (result.trailer_size >= 60U)
            write_word(result.bytes, aligned_size + 56U,
                static_cast<std::uint32_t>(context >> 32U));
    }
    return result;
}

} // namespace shade::mach_ipc
