// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define Darwin terminal ioctl commands, attributes and default
// settings.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/ioccom.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/ttycom.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/ttydefaults.h

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace emulator::darwin::tty {

inline constexpr std::uint32_t ioctl_void = 0x2000'0000U;
inline constexpr std::uint32_t ioctl_output = 0x4000'0000U;
inline constexpr std::uint32_t ioctl_input = 0x8000'0000U;
inline constexpr std::uint32_t parameter_length_mask = 0x1fffU;

constexpr std::uint32_t void_command(char group, std::uint8_t command)
{
    return ioctl_void |
           (static_cast<std::uint32_t>(static_cast<unsigned char>(group))
               << 8U) |
           command;
}

constexpr std::uint32_t sized_command(std::uint32_t direction, char group,
    std::uint8_t command, std::uint32_t size)
{
    return direction | ((size & parameter_length_mask) << 16U) |
           (static_cast<std::uint32_t>(static_cast<unsigned char>(group))
               << 8U) |
           command;
}

constexpr std::uint32_t parameter_length(std::uint32_t command)
{
    return (command >> 16U) & parameter_length_mask;
}

inline constexpr std::size_t control_character_count = 20;
inline constexpr std::size_t minimum_bytes_index = 16;
inline constexpr std::size_t timeout_deciseconds_index = 17;
inline constexpr std::uint32_t arm32_attributes_size = 44;

namespace arm32_attributes_offset {
    inline constexpr std::uint32_t input_flags = 0;
    inline constexpr std::uint32_t output_flags = 4;
    inline constexpr std::uint32_t control_flags = 8;
    inline constexpr std::uint32_t local_flags = 12;
    inline constexpr std::uint32_t control_characters = 16;
    inline constexpr std::uint32_t input_speed = 36;
    inline constexpr std::uint32_t output_speed = 40;
}

struct Arm32Attributes {
    std::uint32_t input_flags { };
    std::uint32_t output_flags { };
    std::uint32_t control_flags { };
    std::uint32_t local_flags { };
    std::array<std::uint8_t, control_character_count> control_characters { };
    std::int32_t input_speed { };
    std::int32_t output_speed { };
};

constexpr Arm32Attributes default_attributes()
{
    return {
        .input_flags = 0x0000'2b02U,
        .output_flags = 0x0000'0003U,
        .control_flags = 0x0000'4b00U,
        .local_flags = 0x0000'05cbU,
        .control_characters = { 4, 255, 255, 127, 23, 21, 18, 255, 3, 28, 26,
            25, 17, 19, 22, 15, 1, 0, 20, 255 },
        .input_speed = 9'600,
        .output_speed = 9'600,
    };
}

inline constexpr std::uint32_t set_exclusive = void_command('t', 13);
inline constexpr std::uint32_t clear_exclusive = void_command('t', 14);
inline constexpr std::uint32_t get_attributes =
    sized_command(ioctl_output, 't', 19, arm32_attributes_size);
inline constexpr std::uint32_t set_attributes =
    sized_command(ioctl_input, 't', 20, arm32_attributes_size);
inline constexpr std::uint32_t set_attributes_after_drain =
    sized_command(ioctl_input, 't', 21, arm32_attributes_size);
inline constexpr std::uint32_t set_attributes_after_drain_and_flush =
    sized_command(ioctl_input, 't', 22, arm32_attributes_size);
inline constexpr std::uint32_t flush_buffers =
    sized_command(ioctl_input, 't', 16, sizeof(std::uint32_t));
inline constexpr std::uint32_t get_modem_control_bits =
    sized_command(ioctl_output, 't', 106, sizeof(std::uint32_t));
inline constexpr std::uint32_t clear_modem_control_bits =
    sized_command(ioctl_input, 't', 107, sizeof(std::uint32_t));
inline constexpr std::uint32_t set_modem_control_bits =
    sized_command(ioctl_input, 't', 108, sizeof(std::uint32_t));
inline constexpr std::uint32_t set_all_modem_control_bits =
    sized_command(ioctl_input, 't', 109, sizeof(std::uint32_t));
inline constexpr std::uint32_t drain_output = void_command('t', 94);
inline constexpr std::uint32_t set_controlling_terminal = void_command('t', 97);

inline constexpr std::uint32_t set_arbitrary_speed =
    sized_command(ioctl_input, 'T', 2, sizeof(std::uint32_t));

inline constexpr std::uint32_t set_h5_transport_mode =
    sized_command(ioctl_input, 'T', 10, sizeof(std::uint32_t));

inline constexpr std::uint32_t set_receive_threshold =
    sized_command(ioctl_input | ioctl_output, 'y', 0x9a, sizeof(std::uint32_t));

inline constexpr std::uint32_t set_mux_speed =
    sized_command(ioctl_input, 'y', 0xa4, sizeof(std::uint32_t));

inline constexpr std::size_t ioaos_status_size = sizeof(std::uint32_t);
inline constexpr std::uint32_t ioaos_status_query =
    sized_command(ioctl_output, 'y', 0x90, ioaos_status_size);
inline constexpr std::size_t ioaos_general_data_size = 0x100U;
inline constexpr std::uint32_t ioaos_general_data_query =
    sized_command(ioctl_output, 'y', 0x91, ioaos_general_data_size);
inline constexpr std::size_t asm_new_dlci_minimum_size = 0x48U;
inline constexpr std::size_t asm_new_dlci_path_offset = 48U;
inline constexpr std::size_t asm_new_dlci_path_capacity = 64U;
inline constexpr std::uint32_t asm_new_dlci =
    sized_command(ioctl_input | ioctl_output, 'x', 0x0a,
        asm_new_dlci_minimum_size);

constexpr bool is_asm_new_dlci(std::uint32_t command)
{
    return (command & (ioctl_input | ioctl_output)) ==
               (ioctl_input | ioctl_output) &&
           ((command >> 8U) & 0xffU) ==
               static_cast<std::uint32_t>(static_cast<unsigned char>('x')) &&
           (command & 0xffU) == 0x0aU &&
           parameter_length(command) >= asm_new_dlci_minimum_size;
}
inline constexpr std::size_t receive_queue_configuration_size = 0x10U;
inline constexpr std::uint32_t ioaos_receive_queue =
    sized_command(ioctl_input, 'x', 0x28, receive_queue_configuration_size);
inline constexpr std::size_t asm_network_interface_size = 0x30U;
inline constexpr std::size_t asm_network_interface_name_offset = 0x10U;
inline constexpr std::size_t asm_network_interface_name_capacity = 0x20U;
inline constexpr std::uint32_t asm_create_network_interface =
    sized_command(ioctl_input, 'x', 0x64, asm_network_interface_size);
inline constexpr std::uint32_t asm_engage = void_command('x', 0x32);

}
