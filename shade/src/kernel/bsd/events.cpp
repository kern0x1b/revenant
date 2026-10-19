// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest event, polling, ioctl and sysctl operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_event.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/sys_generic.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_sysctl.c

#include "kernel/kernel.hpp"

#include "kernel/baseband_device.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/darwin_sysctl.hpp"
#include "kernel/kernel_network.hpp"
#include "kernel/mach_scheduler_abi.hpp"
#include "kernel/offline_serial_device.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "support.hpp"

namespace {

constexpr auto wifi_scan_completion_delay =
    10U * shade::darwin::mach::scheduler::nanoseconds_per_millisecond;

[[nodiscard]] bool is_printable_ascii(std::byte value)
{
    const auto character = std::to_integer<unsigned char>(value);
    return character >= 0x20U && character <= 0x7eU;
}

[[nodiscard]] std::optional<std::string> extract_inline_ascii_string(
    std::span<const std::byte> bytes)
{
    for (std::size_t start = 0; start < bytes.size(); ++start) {
        if (!is_printable_ascii(bytes[start])) {
            continue;
        }
        std::string candidate;
        for (std::size_t index = start; index < bytes.size(); ++index) {
            const auto character = std::to_integer<unsigned char>(bytes[index]);
            if (character == 0U) {
                break;
            }
            if (character < 0x20U || character > 0x7eU) {
                candidate.clear();
                break;
            }
            candidate.push_back(static_cast<char>(character));
        }
        if (candidate.size() >= 3U) {
            return candidate;
        }
    }
    return std::nullopt;
}

[[nodiscard]] bool is_printable_ascii_string(std::string_view value)
{
    return !value.empty() &&
           std::all_of(value.begin(), value.end(), [](unsigned char character) {
               return character >= 0x20U && character <= 0x7eU;
           });
}

[[nodiscard]] std::optional<std::string> extract_mux_channel_name(
    const shade::AddressSpace& memory, std::uint32_t base_address,
    std::span<const std::byte> bytes)
{
    if (const auto inline_name = extract_inline_ascii_string(bytes);
        inline_name && is_printable_ascii_string(*inline_name)) {
        return inline_name;
    }
    for (std::size_t offset = 0; offset + sizeof(std::uint32_t) <= bytes.size();
        offset += sizeof(std::uint32_t)) {
        const auto pointer =
            memory.read32(base_address + static_cast<std::uint32_t>(offset));
        if (!pointer || *pointer == 0U) {
            continue;
        }
        const auto candidate = memory.read_c_string(*pointer);
        if (!candidate || !is_printable_ascii_string(*candidate) ||
            candidate->size() < 3U || candidate->size() > 63U) {
            continue;
        }
        return candidate;
    }
    return std::nullopt;
}

} // namespace

namespace shade {

void CompatibilityKernel::dispatch_bsd_events(Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    switch (number) {
    case 54: { // ioctl
        const auto fd = registers[0];
        if (const auto block = virtual_block_descriptors_.find(fd);
            block != virtual_block_descriptors_.end()) {
            switch (registers[1]) {
            case 0x40046418U: // DKIOCGETBLOCKSIZE / legacy DKIOCBLKSIZE
                if (!memory_.write32(registers[2], 512)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            case 0x40086419U: { // DKIOCGETBLOCKCOUNT
                std::error_code size_error;
                const auto size = std::filesystem::file_size(
                    file_descriptors_.at(fd), size_error);
                if (size_error || !memory_.write64(registers[2], size / 512U)) {
                    bsd_error(cpu, size_error ? 5U : bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            }
            case 0x40046419U: { // DKIOCGETBLOCKCOUNT32
                std::error_code size_error;
                const auto size = std::filesystem::file_size(
                    file_descriptors_.at(fd), size_error);
                if (size_error ||
                    !memory_.write32(registers[2],
                        static_cast<std::uint32_t>(size / 512U))) {
                    bsd_error(cpu, size_error ? 5U : bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            }
            case 0x40046417U: // DKIOCISFORMATTED
            case 0x4004641dU: // DKIOCISWRITABLE
                if (!memory_.write32(registers[2], 1)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            case 0x20006416U: // DKIOCSYNCHRONIZECACHE
                bsd_success(cpu, 0);
                return;
            default: {
                std::ostringstream message;
                message << "[disk] unsupported ioctl 0x" << std::hex
                        << registers[1] << " minor=" << std::dec
                        << block->second.first << '\n';
                output_.write(message.str());
                bsd_error(cpu, 25);
                return;
            }
            }
        }
        const auto device = virtual_descriptors_.find(fd);
        if (device == virtual_descriptors_.end()) {
            bsd_error(cpu, 25); // ENOTTY
            return;
        }
        if (registers[1] == darwin::socket::ioctl_non_block) {
            const auto enabled = memory_.read32(registers[2]);
            if (!enabled) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            auto& flags = file_status_flags_[fd];
            if (*enabled != 0)
                flags |= darwin::open_flag::non_block;
            else
                flags &= ~darwin::open_flag::non_block;
            bsd_success(cpu, 0);
            return;
        }
        if (ioctl_bpf_device(cpu, fd))
            return;
        if (ioctl_kernel_control_socket(cpu))
            return;
        // Keep FIONREAD on the common descriptor path. In particular, do not
        // let the baseband/serial tty branches turn a readiness query into an
        // unrelated private-ioctl success or ENOTTY.
        if (registers[1] == darwin::socket::ioctl_pending_bytes) {
            std::uint32_t pending_error = 0;
            const auto pending_count =
                socket_pending_byte_count(fd, pending_error);
            if (!pending_count) {
                bsd_error(cpu, pending_error);
                return;
            }
            if (!memory_.write32(registers[2], *pending_count)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        const auto tty_descriptor =
            device->second == "console" ||
            device->second == bsd::baseband_device::descriptor_kind ||
            device->second == bsd::offline_serial_device::descriptor_kind;
        if (tty_descriptor &&
            registers[1] == darwin::tty::set_controlling_terminal) {
            output_.write("[tty] controlling-terminal pid=" +
                          std::to_string(process_.pid) +
                          " fd=" + std::to_string(fd) + "\n");
            bsd_success(cpu, 0);
            return;
        }
        if (tty_descriptor &&
            registers[1] == darwin::tty::set_arbitrary_speed) {
            const auto speed = memory_.read32(registers[2]);
            if (!speed) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (device->second == bsd::baseband_device::descriptor_kind) {
                auto attributes =
                    shared_state_->baseband_device_state.attributes();
                attributes.input_speed = static_cast<std::int32_t>(*speed);
                attributes.output_speed = static_cast<std::int32_t>(*speed);
                shared_state_->baseband_device_state.set_attributes(attributes);
            } else {
                auto attributes = offline_serial_state_.attributes();
                attributes.input_speed = static_cast<std::int32_t>(*speed);
                attributes.output_speed = static_cast<std::int32_t>(*speed);
                offline_serial_state_.set_attributes(attributes);
            }
            bsd_success(cpu, 0);
            return;
        }
        if (tty_descriptor && registers[1] == darwin::tty::drain_output) {
            // Both virtual serial implementations consume output synchronously.
            bsd_success(cpu, 0);
            return;
        }
        if (device->second == bsd::offline_serial_device::descriptor_kind) {
            const auto request = registers[1];
            const auto argument = registers[2];
            if (request == darwin::tty::get_attributes) {
                const auto attributes = offline_serial_state_.attributes();
                const auto control_characters =
                    std::as_bytes(std::span { attributes.control_characters });
                if (!memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::input_flags,
                        attributes.input_flags) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::output_flags,
                        attributes.output_flags) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::control_flags,
                        attributes.control_flags) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::local_flags,
                        attributes.local_flags) ||
                    !memory_.copy_in(argument +
                                         darwin::tty::arm32_attributes_offset::
                                             control_characters,
                        control_characters) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::input_speed,
                        static_cast<std::uint32_t>(attributes.input_speed)) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::output_speed,
                        static_cast<std::uint32_t>(attributes.output_speed))) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::set_attributes ||
                request == darwin::tty::set_attributes_after_drain ||
                request == darwin::tty::set_attributes_after_drain_and_flush) {
                const auto input_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::input_flags);
                const auto output_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::output_flags);
                const auto control_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::control_flags);
                const auto local_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::local_flags);
                const auto control_characters = memory_.read_bytes(
                    argument + darwin::tty::arm32_attributes_offset::
                                   control_characters,
                    darwin::tty::control_character_count);
                const auto input_speed = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::input_speed);
                const auto output_speed = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::output_speed);
                if (!input_flags || !output_flags || !control_flags ||
                    !local_flags || !control_characters || !input_speed ||
                    !output_speed) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                darwin::tty::Arm32Attributes attributes {
                    .input_flags = *input_flags,
                    .output_flags = *output_flags,
                    .control_flags = *control_flags,
                    .local_flags = *local_flags,
                    .input_speed = static_cast<std::int32_t>(*input_speed),
                    .output_speed = static_cast<std::int32_t>(*output_speed),
                };
                std::transform(control_characters->begin(),
                    control_characters->end(),
                    attributes.control_characters.begin(), [](std::byte value) {
                        return std::to_integer<std::uint8_t>(value);
                    });
                offline_serial_state_.set_attributes(attributes);
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::set_exclusive ||
                request == darwin::tty::clear_exclusive) {
                bsd_success(cpu, 0);
                return;
            }
            std::ostringstream message;
            message << "[serial] unsupported offline ioctl pid=" << process_.pid
                    << " request=0x" << std::hex << request << '\n';
            output_.write(message.str());
            bsd_error(cpu, darwin::error::inappropriate_ioctl);
            return;
        }
        if (device->second == bsd::baseband_device::descriptor_kind) {
            const auto request = registers[1];
            const auto argument = registers[2];
            if (request == darwin::tty::get_attributes) {
                const auto attributes =
                    shared_state_->baseband_device_state.attributes();
                const auto control_characters =
                    std::as_bytes(std::span { attributes.control_characters });
                if (!memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::input_flags,
                        attributes.input_flags) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::output_flags,
                        attributes.output_flags) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::control_flags,
                        attributes.control_flags) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::local_flags,
                        attributes.local_flags) ||
                    !memory_.copy_in(argument +
                                         darwin::tty::arm32_attributes_offset::
                                             control_characters,
                        control_characters) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::input_speed,
                        static_cast<std::uint32_t>(attributes.input_speed)) ||
                    !memory_.write32(
                        argument +
                            darwin::tty::arm32_attributes_offset::output_speed,
                        static_cast<std::uint32_t>(attributes.output_speed))) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                output_.write("[baseband] ioctl pid=" +
                              std::to_string(process_.pid) + " TIOCGETA\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::set_attributes ||
                request == darwin::tty::set_attributes_after_drain ||
                request == darwin::tty::set_attributes_after_drain_and_flush) {
                const auto input_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::input_flags);
                const auto output_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::output_flags);
                const auto control_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::control_flags);
                const auto local_flags = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::local_flags);
                const auto control_characters = memory_.read_bytes(
                    argument + darwin::tty::arm32_attributes_offset::
                                   control_characters,
                    darwin::tty::control_character_count);
                const auto input_speed = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::input_speed);
                const auto output_speed = memory_.read32(
                    argument +
                    darwin::tty::arm32_attributes_offset::output_speed);
                if (!input_flags || !output_flags || !control_flags ||
                    !local_flags || !control_characters || !input_speed ||
                    !output_speed) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                darwin::tty::Arm32Attributes attributes {
                    .input_flags = *input_flags,
                    .output_flags = *output_flags,
                    .control_flags = *control_flags,
                    .local_flags = *local_flags,
                    .input_speed = static_cast<std::int32_t>(*input_speed),
                    .output_speed = static_cast<std::int32_t>(*output_speed),
                };
                std::transform(control_characters->begin(),
                    control_characters->end(),
                    attributes.control_characters.begin(), [](std::byte value) {
                        return std::to_integer<std::uint8_t>(value);
                    });
                shared_state_->baseband_device_state.set_attributes(attributes);
                std::ostringstream message;
                message << "[baseband] ioctl pid=" << process_.pid
                        << " TIOCSETA request=0x" << std::hex << request
                        << std::dec << " ispeed=" << attributes.input_speed
                        << " ospeed=" << attributes.output_speed << '\n';
                output_.write(message.str());
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::set_h5_transport_mode) {
                const auto enabled = memory_.read32(argument);
                if (!enabled) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                shared_state_->baseband_device_state.set_h5_transport_mode(
                    *enabled != 0);
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " IOAOSH5 enabled=" + std::to_string(*enabled != 0) + "\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::set_mux_speed) {
                const auto speed = memory_.read32(argument);
                if (!speed) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                auto attributes =
                    shared_state_->baseband_device_state.attributes();
                attributes.input_speed = static_cast<std::int32_t>(*speed);
                attributes.output_speed = static_cast<std::int32_t>(*speed);
                shared_state_->baseband_device_state.set_attributes(attributes);
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " IOAOSSPEED speed=" + std::to_string(*speed) + "\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::ioaos_status_query) {
                std::array<std::byte, darwin::tty::ioaos_status_size>
                    status { };
                if (!memory_.copy_in(argument, status)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " IOAOSSTATUS pending=0\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::ioaos_general_data_query) {
                std::array<std::byte, darwin::tty::ioaos_general_data_size>
                    data { };
                if (!memory_.copy_in(argument, data)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " IOAOSGENDATA available=0\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::get_modem_control_bits) {
                const auto bits =
                    shared_state_->baseband_device_state.modem_control_bits();
                if (!memory_.write32(argument, bits)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " TIOCMGET bits=" + std::to_string(bits) + "\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::clear_modem_control_bits ||
                request == darwin::tty::set_modem_control_bits ||
                request == darwin::tty::set_all_modem_control_bits) {
                const auto bits = memory_.read32(argument);
                if (!bits) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (request == darwin::tty::set_all_modem_control_bits) {
                    shared_state_->baseband_device_state.set_modem_control_bits(
                        *bits);
                } else {
                    shared_state_->baseband_device_state
                        .update_modem_control_bits(*bits,
                            request == darwin::tty::set_modem_control_bits);
                }
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " TIOCMUPDATE bits=" + std::to_string(*bits) + "\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::flush_buffers) {
                const auto what = memory_.read32(argument);
                if (!what) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (const auto endpoint = baseband_open_description(fd))
                    endpoint->flush_buffers(*what);
                else
                    shared_state_->baseband_device_state.flush_buffers(*what);
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " TIOCFLUSH what=" + std::to_string(*what) + "\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::ioaos_receive_queue) {
                const auto payload_size =
                    darwin::tty::parameter_length(request);
                const auto payload = memory_.read_bytes(argument, payload_size);
                if (!payload) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (!shared_state_->baseband_device_state
                        .configure_receive_queue(*payload)) {
                    bsd_error(cpu, darwin::error::invalid_argument);
                    return;
                }
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " IOAOSRECEIVEQUEUE configured=1\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::asm_create_network_interface) {
                const auto payload = memory_.read_bytes(
                    argument, darwin::tty::asm_network_interface_size);
                if (!payload) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                const auto unit = memory_.read32(argument);
                const auto name_begin =
                    payload->begin() +
                    static_cast<std::ptrdiff_t>(
                        darwin::tty::asm_network_interface_name_offset);
                const auto name_end =
                    std::find(name_begin, payload->end(), std::byte { });
                const std::string name(
                    reinterpret_cast<const char*>(&*name_begin),
                    static_cast<std::size_t>(name_end - name_begin));
                if (!unit ||
                    !shared_state_->baseband_device_state
                        .configure_mux_network_interface(*unit, name)) {
                    bsd_error(cpu, darwin::error::invalid_argument);
                    return;
                }
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " ASMIOCCREATENETWORKINTERFACE unit=" +
                    std::to_string(*unit) + " name=" + name + "\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::asm_engage) {
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " ASMIOCENGAGE configured=1\n");
                bsd_success(cpu, 0);
                return;
            }
            if (request == darwin::tty::set_receive_threshold) {
                const auto threshold = memory_.read32(argument);
                if (!threshold) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                shared_state_->baseband_device_state.set_minimum_receive_bytes(
                    *threshold);
                if (!memory_.write32(argument, *threshold)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                output_.write(
                    "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                    " IOAOSMIN minimum=" + std::to_string(*threshold) + "\n");
                bsd_success(cpu, 0);
                return;
            }
            if (darwin::tty::is_asm_new_dlci(request)) {
                const auto payload_size =
                    darwin::tty::parameter_length(request);
                const auto payload = memory_.read_bytes(argument, payload_size);
                if (!payload) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                const auto channel_name =
                    extract_mux_channel_name(memory_, argument, *payload);
                const auto requested_unit = memory_.read32(
                    argument + sizeof(std::uint32_t));
                if (!shared_state_->baseband_device_state
                        .dynamic_channels_available()) {
                    output_.write(
                        "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                        " ASMIOCNEWDLCI unavailable\n");
                    bsd_error(cpu, darwin::error::no_such_device_or_address);
                    return;
                }
                const auto channel_unit =
                    shared_state_->baseband_device_state.register_mux_channel(
                        channel_name ? *channel_name : std::string { },
                        requested_unit);
                if (channel_unit == 0) {
                    output_.write(
                        "[baseband] ioctl pid=" + std::to_string(process_.pid) +
                        " ASMIOCNEWDLCI capacity-exhausted\n");
                    bsd_error(cpu, darwin::error::no_space_on_device);
                    return;
                }
                const auto channel_path =
                    shared_state_->baseband_device_state
                        .mux_channel_device_path(channel_unit);
                const auto carries_channel_path =
                    payload_size >= darwin::tty::asm_new_dlci_path_offset +
                                        darwin::tty::asm_new_dlci_path_capacity;
                if (carries_channel_path &&
                    channel_path.size() >=
                        darwin::tty::asm_new_dlci_path_capacity) {
                    bsd_error(cpu, darwin::error::invalid_argument);
                    return;
                }
                if (!memory_.copy_in(argument, *payload) ||
                    !memory_.write32(argument, 0U) ||
                    !memory_.write32(
                        argument + sizeof(std::uint32_t), channel_unit)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (carries_channel_path &&
                    (!memory_.copy_in(
                         argument + static_cast<std::uint32_t>(
                                        darwin::tty::asm_new_dlci_path_offset),
                         std::as_bytes(std::span {
                             channel_path.data(), channel_path.size() })) ||
                        !memory_.write8(
                            argument +
                                static_cast<std::uint32_t>(
                                    darwin::tty::asm_new_dlci_path_offset +
                                    channel_path.size()),
                            0U))) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                std::ostringstream message;
                message << "[baseband] ioctl pid=" << process_.pid
                        << " ASMIOCNEWDLCI unit=" << channel_unit;
                if (carries_channel_path)
                    message << " path=" << channel_path;
                if (channel_name) {
                    message << " name=" << *channel_name;
                }
                message << '\n';
                output_.write(message.str());
                bsd_success(cpu, 0);
                return;
            }
            const auto endpoint = baseband_open_description(fd);
            const auto ioctl_result =
                endpoint
                    ? endpoint->ioctl(registers[1])
                    : shared_state_->baseband_device_state.ioctl(registers[1]);
            if (ioctl_result == bsd::baseband_device::IoctlResult::success) {
                std::ostringstream message;
                message << "[baseband] ioctl pid=" << process_.pid
                        << " request=0x" << std::hex << registers[1] << std::dec
                        << " exclusive="
                        << shared_state_->baseband_device_state.exclusive()
                        << '\n';
                output_.write(message.str());
                bsd_success(cpu, 0);
                return;
            }
            if (ioctl_result ==
                bsd::baseband_device::IoctlResult::permission_denied) {
                bsd_error(cpu, darwin::error::permission_denied);
                return;
            }
            std::ostringstream message;
            message << "[baseband] unsupported ioctl pid=" << process_.pid
                    << " request=0x" << std::hex << registers[1];
            constexpr std::uint32_t maximum_traced_ioctl_payload = 64;
            const auto payload_size =
                darwin::tty::parameter_length(registers[1]);
            if ((registers[1] & darwin::tty::ioctl_input) != 0 &&
                payload_size != 0 &&
                payload_size <= maximum_traced_ioctl_payload) {
                if (const auto payload =
                        memory_.read_bytes(registers[2], payload_size)) {
                    message << " input="
                            << bsd_support::format_payload_prefix(*payload);
                }
            }
            message << '\n';
            output_.write(message.str());
            bsd_error(cpu, darwin::error::inappropriate_ioctl);
            return;
        }
        if (device->second == "inet-dgram" || device->second == "inet6-dgram") {
            const auto name_bytes = memory_.read_bytes(registers[2], 16);
            if (!name_bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            std::string name;
            for (const auto byte : *name_bytes) {
                const auto value = static_cast<char>(byte);
                if (value == '\0')
                    break;
                name.push_back(value);
            }
            namespace wifi_driver = darwin::network::apple80211_driver;
            if (registers[1] == wifi_driver::set_request ||
                registers[1] == wifi_driver::get_request) {
                const auto command =
                    memory_.read32(registers[2] + wifi_driver::command_offset);
                const auto data_length = memory_.read32(
                    registers[2] + wifi_driver::data_length_offset);
                const auto data_address = memory_.read32(
                    registers[2] + wifi_driver::data_address_offset);
                if (!command || !data_length || !data_address) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                bool service_available = false;
                {
                    std::lock_guard mach_lock { shared_state_->mach_mutex };
                    service_available = shared_state_->wifi_service_available;
                }
                if (name != "en0" || !service_available) {
                    output_.write("[wifi-driver] reject pid=" +
                                  std::to_string(process_.pid) +
                                  " fd=" + std::to_string(fd) +
                                  " interface=" + name + "\n");
                    bsd_error(cpu, 6); // ENXIO
                    return;
                }
                if (registers[1] == wifi_driver::set_request &&
                    *command == wifi_driver::command_scan) {
                    apple80211_scan_delivered_.erase(fd);
                    static_cast<void>(wifi_state_->scan());
                    const auto now = shared_state_->clock.now();
                    const auto deadline =
                        wifi_scan_completion_delay >
                                std::numeric_limits<std::uint64_t>::max() - now
                            ? std::numeric_limits<std::uint64_t>::max()
                            : now + wifi_scan_completion_delay;
                    scheduled_wifi_driver_events_.emplace(
                        deadline, wifi_driver::event_scan_completed);
                    output_.write("[wifi-driver] scan-start pid=" +
                                  std::to_string(process_.pid) +
                                  " fd=" + std::to_string(fd) + "\n");
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::set_request &&
                    *command == wifi_driver::command_power) {
                    if (*data_address == 0 ||
                        *data_length < wifi_driver::power_state_size) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    const auto count = memory_.read32(
                        *data_address + wifi_driver::power_state_count_offset);
                    const auto power = memory_.read32(
                        *data_address +
                        wifi_driver::power_state_first_value_offset);
                    if (!count || !power || *count == 0) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    const auto before = wifi_state_->snapshot();
                    static_cast<void>(wifi_state_->set_power(*power != 0));
                    const auto after = wifi_state_->snapshot();
                    apply_wifi_transition(before, after);
                    apple80211_hle_.publish_state_change(before, after);
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_interface_probe) {
                    output_.write("[wifi-driver] probe pid=" +
                                  std::to_string(process_.pid) + " fd=" +
                                  std::to_string(fd) + " interface=en0\n");
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_capability_probe &&
                    *data_length == 0U) {
                    output_.write("[wifi-driver] capability-probe pid=" +
                                  std::to_string(process_.pid) + " fd=" +
                                  std::to_string(fd) + "\\n");
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_power) {
                    if (*data_address == 0 ||
                        *data_length < wifi_driver::power_state_size ||
                        !memory_.write32(
                            *data_address +
                                wifi_driver::power_state_count_offset,
                            1) ||
                        !memory_.write32(
                            *data_address +
                                wifi_driver::power_state_first_value_offset,
                            wifi_state_->snapshot().powered ? 1U : 0U)) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_state) {
                    if (!memory_.write32(
                            registers[2] +
                                wifi_driver::inline_scalar_value_offset,
                            wifi_state_->snapshot().associated_access_point
                                ? 1U
                                : 0U)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_association_result) {
                    if (!wifi_state_->snapshot().associated_access_point) {
                        bsd_error(cpu, 57); // ENOTCONN
                        return;
                    }
                    if (!memory_.write32(
                            registers[2] +
                                wifi_driver::inline_scalar_value_offset,
                            wifi_driver::association_result_success)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_rate) {
                    const auto associated =
                        wifi_state_->snapshot().associated_access_point;
                    if (!associated) {
                        bsd_error(cpu, 57); // ENOTCONN
                        return;
                    }
                    if (!memory_.write32(
                            registers[2] +
                                wifi_driver::inline_scalar_value_offset,
                            associated->link_rate_mbps)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_current_ssid) {
                    if (*data_address == 0 ||
                        *data_length < wifi_driver::current_ssid_size) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    const auto associated =
                        wifi_state_->snapshot().associated_access_point;
                    if (!associated) {
                        // A successful command means that an association
                        // exists. Returning an empty successful payload makes
                        // legacy Apple80211 clients construct a non-null
                        // "current network" object from a scan result.
                        bsd_error(cpu, 57); // ENOTCONN
                        return;
                    }
                    const auto copied =
                        std::min<std::size_t>(associated->ssid.size(),
                            wifi_driver::current_ssid_size);
                    std::array<std::byte, wifi_driver::current_ssid_size>
                        ssid { };
                    std::transform(associated->ssid.begin(),
                        associated->ssid.begin() + copied, ssid.begin(),
                        [](char value) {
                            return static_cast<std::byte>(
                                static_cast<unsigned char>(value));
                        });
                    if (!memory_.copy_in(
                            *data_address, std::span { ssid.data(), copied }) ||
                        !memory_.write32(
                            registers[2] + wifi_driver::data_length_offset,
                            static_cast<std::uint32_t>(copied))) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_current_bssid) {
                    if (*data_address == 0 ||
                        *data_length < wifi_driver::current_bssid_size) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    const auto associated =
                        wifi_state_->snapshot().associated_access_point;
                    if (!associated) {
                        bsd_error(cpu, 57); // ENOTCONN
                        return;
                    }
                    if (!memory_.copy_in(
                            *data_address, std::span { associated->bssid.data(),
                                               associated->bssid.size() })) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_channel) {
                    if (*data_address == 0 ||
                        *data_length < wifi_driver::channel_state_size) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    const auto associated =
                        wifi_state_->snapshot().associated_access_point;
                    if (!associated) {
                        bsd_error(cpu, 57); // ENOTCONN
                        return;
                    }
                    if (!memory_.write32(
                            *data_address +
                                wifi_driver::channel_state_channel_offset,
                            associated->channel) ||
                        !memory_.write32(
                            *data_address +
                                wifi_driver::channel_state_flags_offset,
                            0)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    (*command == wifi_driver::command_rssi ||
                        *command == wifi_driver::command_noise)) {
                    if (*data_address == 0 ||
                        *data_length < wifi_driver::signal_state_size) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    const auto associated =
                        wifi_state_->snapshot().associated_access_point;
                    if (!associated) {
                        bsd_error(cpu, 57); // ENOTCONN
                        return;
                    }
                    const auto signal = static_cast<std::uint32_t>(
                        *command == wifi_driver::command_rssi ? associated->rssi
                                                              : -90);
                    if (!memory_.write32(
                            *data_address +
                                wifi_driver::signal_state_count_offset,
                            1) ||
                        !memory_.write32(
                            *data_address +
                                wifi_driver::signal_state_unit_offset,
                            0) ||
                        !memory_.write32(
                            *data_address +
                                wifi_driver::
                                    signal_state_control_average_offset,
                            signal) ||
                        !memory_.write32(
                            *data_address +
                                wifi_driver::
                                    signal_state_extension_average_offset,
                            signal) ||
                        !memory_.write32(
                            *data_address +
                                wifi_driver::signal_state_last_offset,
                            signal)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_driver_name) {
                    if (*data_address == 0 || *data_length == 0) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    constexpr auto driver_name = wifi_driver::event_device_name;
                    std::vector<std::byte> name_buffer(
                        std::min<std::size_t>(
                            *data_length, driver_name.size() + 1),
                        std::byte { 0 });
                    std::transform(driver_name.begin(),
                        driver_name.begin() + std::min(driver_name.size(),
                                                  name_buffer.size() - 1),
                        name_buffer.begin(), [](char value) {
                            return static_cast<std::byte>(
                                static_cast<unsigned char>(value));
                        });
                    if (!memory_.copy_in(*data_address, name_buffer)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_scan_result) {
                    if (apple80211_scan_delivered_.contains(fd)) {
                        output_.write("[wifi-driver] scan-end pid=" +
                                      std::to_string(process_.pid) +
                                      " fd=" + std::to_string(fd) + "\n");
                        bsd_error(cpu,
                            5); // EIO terminates the firmware scan iterator.
                        return;
                    }
                    const auto access_points = wifi_state_->scan();
                    if (access_points.empty()) {
                        bsd_error(cpu, 5);
                        return;
                    }
                    const auto& access_point = access_points.front();
                    if (*data_address == 0 ||
                        *data_length < wifi_driver::scan_result_size ||
                        access_point.ssid.size() > 32) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    const auto ie_scratch = memory_.read32(
                        *data_address + wifi_driver::scan_ie_pointer_offset);
                    if (!ie_scratch) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    // Preserve only the firmware-owned IE scratch pointer.
                    // Copying the entire input record would leak uninitialized
                    // caller flags into the native parser and can make a
                    // discovered AP appear associated.
                    const auto result =
                        wifi_driver::make_network_record(&access_point,
                            wifi_driver::aligned_network_record_layout, 0,
                            *ie_scratch);
                    if (!result || !memory_.copy_in(*data_address, *result)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    apple80211_scan_delivered_.insert(fd);
                    output_.write("[wifi-driver] scan-result pid=" +
                                  std::to_string(process_.pid) +
                                  " fd=" + std::to_string(fd) +
                                  " ssid=" + access_point.ssid + "\n");
                    bsd_success(cpu, 0);
                    return;
                }
                if (registers[1] == wifi_driver::get_request &&
                    *command == wifi_driver::command_current_network) {
                    const auto layout =
                        shared_state_->darwin_abi
                                    .apple80211_ioctl ==
                                DarwinApple80211IoctlAbi::
                                    CompactCurrentNetworkRecord
                            ? wifi_driver::compact_network_record_layout
                            : wifi_driver::aligned_network_record_layout;
                    if (*data_address == 0 || *data_length < layout.size) {
                        bsd_error(cpu, *data_address == 0
                                           ? bsd_support::bad_address
                                           : bsd_support::invalid_argument);
                        return;
                    }
                    const auto ie_length =
                        memory_.read16(*data_address + layout.ie_length_offset);
                    const auto ie_pointer = memory_.read32(
                        *data_address + layout.ie_pointer_offset);
                    if (!ie_length || !ie_pointer ||
                        (*ie_length != 0 && *ie_pointer == 0)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    const auto associated =
                        wifi_state_->snapshot().associated_access_point;
                    const auto record = wifi_driver::make_network_record(
                        associated ? &*associated : nullptr, layout, *ie_length,
                        *ie_pointer);
                    if (!record || !memory_.copy_in(*data_address, *record)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                    output_.write("[wifi-driver] current-network pid=" +
                                  std::to_string(process_.pid) +
                                  " fd=" + std::to_string(fd) + " layout=" +
                                  std::to_string(layout.size) + " associated=" +
                                  std::to_string(associated.has_value()) +
                                  "\n");
                    bsd_success(cpu, 0);
                    return;
                }
                output_.write(
                    "[wifi-driver] unsupported pid=" +
                    std::to_string(process_.pid) + " fd=" + std::to_string(fd) +
                    " operation=" +
                    (registers[1] == wifi_driver::get_request ? "get" : "set") +
                    " command=" + std::to_string(*command) +
                    " length=" + std::to_string(*data_length) + "\n");
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            std::unique_lock network_lock { shared_state_->network_mutex };
            const auto interface = shared_state_->network_interfaces.find(name);
            if (interface == shared_state_->network_interfaces.end()) {
                bsd_error(cpu, 6); // ENXIO
                return;
            }
            const auto ioctl_identity =
                darwin::network::ioctl_identity(registers[1]);
            if (ioctl_identity == darwin::network::ioctl_get_interface_media) {
                const auto ethernet = interface->second.type ==
                                      darwin::network::interface_type_ethernet;
                const auto active =
                    (interface->second.flags &
                        (darwin::network::interface_flag_up |
                            darwin::network::interface_flag_running)) ==
                    (darwin::network::interface_flag_up |
                        darwin::network::interface_flag_running);
                const auto automatic_media =
                    darwin::network::media_type_ethernet |
                    darwin::network::media_subtype_auto;
                const auto active_media =
                    darwin::network::media_type_ethernet |
                    darwin::network::media_subtype_100_tx |
                    darwin::network::media_option_full_duplex;
                const std::array<std::uint32_t, 2> available_media {
                    automatic_media, active_media
                };
                const auto requested_count = memory_.read32(
                    registers[2] +
                    darwin::network::interface_media_count_offset);
                const auto list_address = memory_.read32(
                    registers[2] +
                    darwin::network::interface_media_list_offset);
                if (!requested_count || !list_address) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (ethernet && *list_address != 0) {
                    const auto copied = std::min<std::size_t>(
                        *requested_count, available_media.size());
                    for (std::size_t index = 0; index < copied; ++index) {
                        if (!memory_.write32(
                                *list_address +
                                    static_cast<std::uint32_t>(
                                        index * sizeof(std::uint32_t)),
                                available_media[index])) {
                            bsd_error(cpu, bsd_support::bad_address);
                            return;
                        }
                    }
                }
                const auto media_status =
                    ethernet
                        ? darwin::network::media_status_valid |
                              (active ? darwin::network::media_status_active
                                      : 0U)
                        : 0U;
                if (!memory_.write32(
                        registers[2] +
                            darwin::network::interface_media_current_offset,
                        ethernet ? active_media : 0U) ||
                    !memory_.write32(
                        registers[2] +
                            darwin::network::interface_media_mask_offset,
                        0) ||
                    !memory_.write32(
                        registers[2] +
                            darwin::network::interface_media_status_offset,
                        media_status) ||
                    !memory_.write32(
                        registers[2] +
                            darwin::network::interface_media_active_offset,
                        ethernet ? active_media : 0U) ||
                    !memory_.write32(
                        registers[2] +
                            darwin::network::interface_media_count_offset,
                        ethernet
                            ? static_cast<std::uint32_t>(available_media.size())
                            : 0U)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                bsd_success(cpu, 0);
                return;
            }
            if (ioctl_identity == darwin::network::ioctl_set_interface_media) {
                const auto media = memory_.read32(
                    registers[2] +
                    darwin::network::interface_request_value_offset);
                if (!media) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (interface->second.type !=
                        darwin::network::interface_type_ethernet ||
                    (*media & darwin::network::media_type_mask) !=
                        darwin::network::media_type_ethernet) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                bsd_success(cpu, 0);
                return;
            }
            if (ioctl_identity == darwin::network::ioctl_get_interface_mtu) {
                if (!memory_.write32(
                        registers[2] +
                            darwin::network::interface_request_value_offset,
                        interface->second.mtu)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            }
            if (ioctl_identity == darwin::network::ioctl_set_interface_mtu) {
                const auto mtu = memory_.read32(
                    registers[2] +
                    darwin::network::interface_request_value_offset);
                if (!mtu) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else if (*mtu < 68U || *mtu > 65'535U) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                } else {
                    interface->second.mtu = *mtu;
                    bsd_success(cpu, 0);
                }
                return;
            }
            if (ioctl_identity ==
                darwin::network::ioctl_get_ipv6_address_flags) {
                if (!memory_.write32(
                        registers[2] +
                            darwin::network::interface_request_value_offset,
                        0)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            }
            if (ioctl_identity == 0x80006919U) { // SIOCDIFADDR[_IN6]
                const auto ipv6 = device->second == "inet6-dgram";
                const auto family = static_cast<std::uint8_t>(
                    ipv6 ? darwin::network::address_family_inet6
                         : darwin::network::address_family_inet);
                const auto address_size = ipv6 ? 28U : 16U;
                const auto requested =
                    memory_.read_bytes(registers[2] + 16, address_size);
                if (!requested) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                const auto configured = ipv6 ? interface->second.has_ipv6
                                             : interface->second.has_ipv4;
                const auto address_matches =
                    ipv6 ? std::equal(requested->begin(), requested->end(),
                               interface->second.ipv6_address.begin())
                         : std::equal(requested->begin(), requested->end(),
                               interface->second.ipv4_address.begin());
                if (!configured || !address_matches) {
                    bsd_error(cpu, darwin::error::address_not_available);
                    return;
                }
                const auto deleted_address_snapshot =
                    kernel_network::make_interface_snapshot(
                        name, interface->second);
                if (ipv6) {
                    interface->second.has_ipv6 = false;
                    interface->second.ipv6_address = { };
                    interface->second.ipv6_netmask = { };
                } else {
                    interface->second.has_ipv4 = false;
                    interface->second.ipv4_address = { };
                    interface->second.ipv4_netmask = { };
                    interface->second.ipv4_broadcast = { };
                    interface->second.ipv4_gateway = { };
                }
                network_lock.unlock();
                synchronize_interface_routes(name, family);
                post_network_event(name,
                    ipv6 ? darwin::network::kernel_event_inet6_subclass
                         : darwin::network::kernel_event_inet_subclass,
                    ipv6 ? darwin::network::kernel_event_inet6_address_deleted
                         : darwin::network::kernel_event_inet_address_deleted,
                    deleted_address_snapshot);
                bsd_success(cpu, 0);
                return;
            }
            switch (registers[1]) {
            case 0xc0206911U: // SIOCGIFFLAGS
                if (!memory_.write16(
                        registers[2] + 16, interface->second.flags)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                bsd_success(cpu, 0);
                return;
            case 0x80206910U: { // SIOCSIFFLAGS
                const auto flags = memory_.read16(registers[2] + 16);
                if (!flags) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                const auto kernel_managed =
                    darwin::network::interface_flags_kernel_managed;
                interface->second.flags = static_cast<std::uint16_t>(
                    (interface->second.flags & kernel_managed) |
                    (*flags & static_cast<std::uint16_t>(~kernel_managed)));
                network_lock.unlock();
                post_data_link_event(name,
                    darwin::network::kernel_event_interface_flags_changed);
                bsd_success(cpu, 0);
                return;
            }
            case 0x8040691aU: { // SIOCAIFADDR, struct ifaliasreq
                const auto previously_configured = interface->second.has_ipv4;
                const auto address = memory_.read_bytes(registers[2] + 16, 16);
                const auto broadcast =
                    memory_.read_bytes(registers[2] + 32, 16);
                const auto netmask = memory_.read_bytes(registers[2] + 48, 16);
                if (!address || !broadcast || !netmask) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (std::to_integer<std::uint8_t>((*address)[0]) != 16 ||
                    std::to_integer<std::uint8_t>((*address)[1]) !=
                        darwin::network::address_family_inet) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                std::copy(address->begin(), address->end(),
                    interface->second.ipv4_address.begin());
                std::copy(netmask->begin(), netmask->end(),
                    interface->second.ipv4_netmask.begin());
                std::copy(broadcast->begin(), broadcast->end(),
                    interface->second.ipv4_broadcast.begin());
                interface->second.has_ipv4 = true;
                network_lock.unlock();
                synchronize_interface_routes(
                    name, darwin::network::address_family_inet);
                post_network_event(name,
                    darwin::network::kernel_event_inet_subclass,
                    previously_configured
                        ? darwin::network::kernel_event_inet_address_changed
                        : darwin::network::kernel_event_inet_new_address);
                bsd_success(cpu, 0);
                return;
            }
            case 0x8078691aU: { // SIOCAIFADDR_IN6, struct in6_aliasreq
                const auto address = memory_.read_bytes(registers[2] + 16, 28);
                const auto netmask = memory_.read_bytes(registers[2] + 72, 28);
                if (!address || !netmask) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (std::to_integer<std::uint8_t>((*address)[0]) != 28 ||
                    std::to_integer<std::uint8_t>((*address)[1]) !=
                        darwin::network::address_family_inet6) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                std::copy(address->begin(), address->end(),
                    interface->second.ipv6_address.begin());
                std::copy(netmask->begin(), netmask->end(),
                    interface->second.ipv6_netmask.begin());
                interface->second.has_ipv6 = true;
                network_lock.unlock();
                synchronize_interface_routes(
                    name, darwin::network::address_family_inet6);
                post_network_event(name,
                    darwin::network::kernel_event_inet6_subclass,
                    darwin::network::kernel_event_inet6_new_user_address);
                bsd_success(cpu, 0);
                return;
            }
            default: {
                std::ostringstream message;
                message << "[network] unsupported ioctl 0x" << std::hex
                        << registers[1] << " on " << name << '\n';
                output_.write(message.str());
                bsd_error(cpu, 25);
                return;
            }
            }
        }
        if (device->second != "system-event-socket") {
            bsd_error(cpu, 25);
            return;
        }
        if (registers[1] == 0x800c6502U) { // SIOCSKEVFILT
            std::array<std::uint32_t, 3> filter { };
            for (std::size_t index = 0; index < filter.size(); ++index) {
                const auto value = memory_.read32(
                    registers[2] + static_cast<std::uint32_t>(index * 4U));
                if (!value) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                filter[index] = *value;
            }
            system_event_filters_[fd] = filter;
            bsd_success(cpu, 0);
            return;
        }
        if (registers[1] == 0x400c6503U) { // SIOCGKEVFILT
            const auto filter = system_event_filters_[fd];
            for (std::size_t index = 0; index < filter.size(); ++index) {
                if (!memory_.write32(
                        registers[2] + static_cast<std::uint32_t>(index * 4U),
                        filter[index])) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (registers[1] == 0x40046501U) { // SIOCGKEVID
            std::uint32_t last_identifier = 0;
            {
                std::lock_guard socket_lock { shared_state_->socket_mutex };
                last_identifier =
                    shared_state_->next_kernel_event_identifier - 1U;
            }
            if (!memory_.write32(registers[2], last_identifier)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, 0);
            return;
        }
        bsd_error(cpu, 25); // ENOTTY
        return;
    }
    case darwin::syscall::poll: { // poll
        constexpr std::uint32_t maximum_poll_descriptors = 1024;
        constexpr std::uint64_t nanoseconds_per_millisecond = 1'000'000ULL;
        const auto descriptor_count = registers[1];
        if (descriptor_count > maximum_poll_descriptors) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }

        std::vector<PendingPollEntry> entries;
        entries.reserve(descriptor_count);
        std::vector<std::uint16_t> revents;
        revents.reserve(descriptor_count);
        for (std::uint32_t index = 0; index < descriptor_count; ++index) {
            const auto address =
                registers[0] + index * darwin::poll::pollfd_size;
            const auto fd = memory_.read32(address + darwin::poll::fd_offset);
            const auto events =
                memory_.read16(address + darwin::poll::events_offset);
            if (!fd || !events) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto entry =
                PendingPollEntry { static_cast<std::int32_t>(*fd), *events };
            entries.push_back(entry);
            revents.push_back(descriptor_poll_revents(entry.fd, entry.events));
        }

        std::uint32_t ready_count = 0;
        for (const auto value : revents) {
            if (value != 0)
                ++ready_count;
        }
        for (std::size_t index = 0; index < revents.size(); ++index) {
            const auto address =
                registers[0] +
                static_cast<std::uint32_t>(index * darwin::poll::pollfd_size +
                                           darwin::poll::revents_offset);
            if (!memory_.write16(address, revents[index])) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }

        const auto timeout = static_cast<std::int32_t>(registers[2]);
        if (ready_count != 0 || timeout == 0) {
            bsd_success(cpu, ready_count);
            return;
        }

        std::optional<std::uint64_t> timeout_deadline;
        if (timeout > 0) {
            const auto duration = static_cast<std::uint64_t>(timeout) *
                                  nanoseconds_per_millisecond;
            const auto now = shared_state_->clock.now();
            timeout_deadline =
                duration > std::numeric_limits<std::uint64_t>::max() - now
                    ? std::numeric_limits<std::uint64_t>::max()
                    : now + duration;
        }
        // A negative timeout blocks indefinitely, while zero returned above
        // without registering a wait. This is the same state transition used by
        // select/kevent, so Offline baseband readiness wakes consistently.
        process_.waiting_for_events = true;
        pending_polls_[cpu.processor_id()] = PendingPoll { registers[0],
            std::move(entries), cpu.processor_id(), timeout_deadline };
        output_.write(
            "[network] poll wait pid=" + std::to_string(process_.pid) +
            " nfds=" + std::to_string(descriptor_count) + "\n");
        bsd_success(cpu, 0);
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return;
    }
    case 93: { // select
        constexpr std::uint64_t microseconds_per_second = 1'000'000ULL;
        constexpr std::uint64_t nanoseconds_per_microsecond = 1'000ULL;
        const auto descriptor_count = registers[0];
        if (descriptor_count > 1024) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto words = (descriptor_count + 31U) / 32U;
        std::uint32_t ready_count = 0;
        std::vector<std::uint32_t> requested_read_words(words);
        std::vector<std::uint32_t> requested_write_words(words);
        for (std::uint32_t word_index = 0; word_index < words; ++word_index) {
            std::uint32_t ready_read_word = 0;
            std::uint32_t ready_write_word = 0;
            if (registers[1] != 0) {
                const auto requested =
                    memory_.read32(registers[1] + word_index * 4U);
                if (!requested) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                requested_read_words[word_index] = *requested;
                for (std::uint32_t bit = 0; bit < 32; ++bit) {
                    const auto fd = word_index * 32U + bit;
                    if (fd >= descriptor_count ||
                        (*requested & (1U << bit)) == 0)
                        continue;
                    if (descriptor_readable(fd)) {
                        ready_read_word |= 1U << bit;
                        ++ready_count;
                    }
                }
                if (!memory_.write32(
                        registers[1] + word_index * 4U, ready_read_word)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            if (registers[2] != 0) {
                const auto requested =
                    memory_.read32(registers[2] + word_index * 4U);
                if (!requested) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                requested_write_words[word_index] = *requested;
                for (std::uint32_t bit = 0; bit < 32; ++bit) {
                    const auto fd = word_index * 32U + bit;
                    if (fd >= descriptor_count ||
                        (*requested & (1U << bit)) == 0) {
                        continue;
                    }
                    if (descriptor_writable(fd)) {
                        ready_write_word |= 1U << bit;
                        ++ready_count;
                    }
                }
                if (!memory_.write32(
                        registers[2] + word_index * 4U, ready_write_word)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            if (registers[3] != 0 &&
                !memory_.write32(registers[3] + word_index * 4U, 0)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
        // Unlike poll(2), select(2) has no per-entry revents field. XNU reports
        // EBADF when any requested descriptor is invalid instead of silently
        // treating it as not ready. Validate both sets before writing filtered
        // results back to the guest so an error cannot leave a partially
        // updated fd_set behind.
        for (std::uint32_t word_index = 0; word_index < words; ++word_index) {
            for (std::uint32_t bit = 0; bit < 32; ++bit) {
                const auto fd = word_index * 32U + bit;
                if (fd >= descriptor_count) {
                    continue;
                }
                const auto requested = ((requested_read_words[word_index] |
                                            requested_write_words[word_index]) &
                                           (1U << bit)) != 0;
                if (requested && !descriptor_valid(fd)) {
                    bsd_error(cpu, bsd_support::bad_file_descriptor);
                    return;
                }
            }
        }
        if (ready_count != 0) {
            bsd_success(cpu, ready_count);
            return;
        }
        std::optional<std::uint64_t> timeout_deadline;
        if (registers[4] != 0) {
            const auto seconds_word = memory_.read32(registers[4]);
            const auto microseconds_word = memory_.read32(registers[4] + 4);
            if (!seconds_word || !microseconds_word) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto seconds = static_cast<std::int32_t>(*seconds_word);
            const auto microseconds =
                static_cast<std::int32_t>(*microseconds_word);
            if (seconds < 0 || microseconds < 0 ||
                static_cast<std::uint64_t>(microseconds) >=
                    microseconds_per_second) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto duration =
                (static_cast<std::uint64_t>(seconds) * microseconds_per_second +
                    static_cast<std::uint64_t>(microseconds)) *
                nanoseconds_per_microsecond;
            if (duration == 0) {
                bsd_success(cpu, 0);
                return;
            }
            // select(2)'s timeout applies to every descriptor provider,
            // including a disconnected character device with no host poll
            // source.
            const auto now = shared_state_->clock.now();
            timeout_deadline =
                duration > std::numeric_limits<std::uint64_t>::max() - now
                    ? std::numeric_limits<std::uint64_t>::max()
                    : now + duration;
        }
        process_.waiting_for_events = true;
        pending_selects_[cpu.processor_id()] = PendingSelect { descriptor_count,
            registers[1], registers[2], registers[3],
            std::move(requested_read_words), std::move(requested_write_words),
            cpu.processor_id(), timeout_deadline };
        output_.write(
            "[network] select wait pid=" + std::to_string(process_.pid) +
            " nfds=" + std::to_string(descriptor_count) + "\n");
        bsd_success(cpu, 0);
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return;
    }
    case 202: { // __sysctl
        const auto mib0 = memory_.read32(registers[0]);
        const auto mib1 =
            registers[1] >= 2 ? memory_.read32(registers[0] + 4) : std::nullopt;
        const auto mib2 =
            registers[1] >= 3 ? memory_.read32(registers[0] + 8) : std::nullopt;
        const auto mib3 =
            registers[1] >= 4 ? memory_.read32(registers[0] + 12) : std::nullopt;
        const auto old_size = registers[3] != 0
                                  ? memory_.read32(registers[3])
                                  : std::optional<std::uint32_t> { 0 };
        if (!mib0 || !mib1 || !old_size ||
            (registers[1] >= 3 && !mib2) ||
            (registers[1] >= 4 && !mib3)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto write_read_only_bytes = [&](std::span<const std::byte> bytes) {
            const auto required = static_cast<std::uint32_t>(bytes.size());
            if (registers[4] != 0) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            if (registers[3] == 0 || !memory_.write32(registers[3], required)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < required) {
                    bsd_error(cpu, darwin::error::no_memory);
                    return;
                }
                if (!memory_.copy_in(registers[2], bytes)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
        };
        const auto write_read_only_string = [&](std::string_view value) {
            std::vector<std::byte> bytes(value.size() + 1U);
            std::transform(value.begin(), value.end(), bytes.begin(),
                [](char character) { return static_cast<std::byte>(character); });
            write_read_only_bytes(bytes);
        };
        if (*mib0 == darwin::sysctl::control_unspecified &&
            (*mib1 == darwin::sysctl::operation_oid_to_name ||
                *mib1 == darwin::sysctl::operation_oid_format)) {
            const auto metadata = registers[1] == 4
                                      ? darwin::sysctl::describe_object(*mib2, *mib3)
                                      : std::nullopt;
            if (!metadata)
                bsd_error(cpu, darwin::error::no_entry);
            else if (*mib1 == darwin::sysctl::operation_oid_to_name)
                write_read_only_string(metadata->name);
            else
                write_read_only_bytes(darwin::sysctl::encode_object_format(*metadata));
            return;
        }
        if (*mib0 == darwin::sysctl::control_unspecified &&
            *mib1 == darwin::sysctl::operation_name_to_oid &&
            registers[1] == 2) {
            // XNU's sysctl.name2oid consumes an un-terminated name through the
            // new value and returns the integer MIB through the old value.
            constexpr std::uint32_t maximum_name_length = 1024;
            if (registers[4] == 0 || registers[5] == 0 ||
                registers[5] >= maximum_name_length) {
                bsd_error(cpu, registers[5] >= maximum_name_length
                                   ? darwin::error::argument_list_too_long
                                   : darwin::error::no_entry);
                return;
            }
            const auto name_bytes =
                memory_.read_bytes(registers[4], registers[5]);
            if (!name_bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            std::string_view name { reinterpret_cast<const char*>(
                                        name_bytes->data()),
                name_bytes->size() };
            if (const auto terminator = name.find('\0');
                terminator != std::string_view::npos) {
                name = name.substr(0, terminator);
            }
            const auto identifier = darwin::sysctl::resolve_name(name);
            if (!identifier) {
                bsd_error(cpu, darwin::error::no_entry);
                return;
            }
            const auto required = static_cast<std::uint32_t>(
                identifier->size * sizeof(std::uint32_t));
            if (registers[3] == 0 || !memory_.write32(registers[3], required)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < required) {
                    bsd_error(cpu, darwin::error::no_memory);
                    return;
                }
                for (std::size_t index = 0; index < identifier->size; ++index) {
                    if (!memory_.write32(
                            registers[2] +
                                static_cast<std::uint32_t>(index * 4U),
                            identifier->components[index])) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == darwin::sysctl::control_vfs &&
            *mib1 == darwin::sysctl::vfs_generic &&
            registers[1] == 3 && mib2 &&
            *mib2 == darwin::sysctl::vfs_max_type_number) {
            constexpr std::uint32_t value_size = sizeof(std::uint32_t);
            if (registers[4] != 0) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            if (registers[3] == 0 || !memory_.write32(registers[3], value_size)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < value_size ||
                    !memory_.write32(registers[2],
                        darwin::sysctl::vfs_max_type_number_value)) {
                    bsd_error(cpu, *old_size < value_size
                                   ? darwin::error::no_memory
                                   : bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == darwin::sysctl::control_vfs &&
            *mib1 == darwin::sysctl::vfs_generic &&
            registers[1] >= 4 && mib2 &&
            *mib2 == darwin::sysctl::vfs_conf) {
            // vfs.generic.conf.<type> is a sparse table keyed by the
            // historical filesystem type number. An unregistered type is a
            // normal ENOTSUP result in XNU, not an unimplemented syscall.
            if (!memory_.read32(registers[0] + 12U)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_error(cpu, darwin::error::not_supported);
            return;
        }
        const auto route_operation = registers[1] == 6
                                         ? memory_.read32(registers[0] + 16)
                                         : std::nullopt;
        if (*mib0 == 4 && *mib1 == darwin::route::protocol_family &&
            route_operation &&
            (*route_operation == darwin::route::sysctl_dump ||
                *route_operation == darwin::route::sysctl_flags ||
                *route_operation == darwin::route::sysctl_dump2)) {
            // CTL_NET/PF_ROUTE/NET_RT_DUMP, NET_RT_FLAGS, or NET_RT_DUMP2.
            // rt_msghdr and ARM32 rt_msghdr2 are both 92 bytes; offsets 16,
            // 20, and 24 become refcnt/parentflags/reserved for RTM_GET2.
            const auto address_family = memory_.read32(registers[0] + 12);
            const auto flags = memory_.read32(registers[0] + 20);
            if (!address_family || !flags || registers[3] == 0) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[4] != 0) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            const auto routes = shared_state_->route_table.snapshot();
            const auto records = darwin::route::make_table_dump(routes,
                *address_family,
                *route_operation == darwin::route::sysctl_flags ? *flags : 0U,
                *route_operation == darwin::route::sysctl_dump2
                    ? darwin::route::message_get2
                    : darwin::route::message_get);
            const auto required = static_cast<std::uint32_t>(records.size());
            if (!memory_.write32(registers[3], required)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < required) {
                    bsd_error(cpu, darwin::error::no_memory);
                    return;
                }
                if (!memory_.copy_in(registers[2], records)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == 4 && *mib1 == darwin::route::protocol_family &&
            registers[1] == 6 &&
            memory_.read32(registers[0] + 16).value_or(0) ==
                darwin::route::sysctl_interface_list) {
            // CTL_NET/PF_ROUTE/NET_RT_IFLIST. XNU returns a sequence of
            // variable-length if_msghdr/ifa_msghdr records, not host ifaddrs.
            const auto address_family = memory_.read32(registers[0] + 12);
            const auto interface_index = memory_.read32(registers[0] + 20);
            if (!address_family || !interface_index || registers[3] == 0) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[4] != 0) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            std::vector<darwin::network::InterfaceSnapshot> interfaces;
            {
                std::lock_guard network_lock { shared_state_->network_mutex };
                interfaces.reserve(shared_state_->network_interfaces.size());
                for (const auto& [name, interface] :
                    shared_state_->network_interfaces) {
                    interfaces.push_back(
                        kernel_network::make_interface_snapshot(
                            name, interface));
                }
            }
            std::sort(interfaces.begin(), interfaces.end(),
                [](const auto& left, const auto& right) {
                    return left.index < right.index;
                });
            const auto records = darwin::network::make_route_interface_list(
                interfaces, *address_family, *interface_index);
            const auto required = static_cast<std::uint32_t>(records.size());
            if (!memory_.write32(registers[3], required)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < required) {
                    bsd_error(cpu, 12); // ENOMEM
                    return;
                }
                if (!memory_.copy_in(registers[2], records)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == darwin::sysctl::control_kernel &&
            (*mib1 == darwin::sysctl::kernel_process_arguments ||
                *mib1 == darwin::sysctl::kernel_process_arguments2) &&
            registers[1] == 3) { // KERN_PROCARGS[2] / pid
            const auto requested_pid = memory_.read32(registers[0] + 8U);
            if (!requested_pid || registers[3] == 0) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[4] != 0) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            const auto process = shared_state_->processes.find(*requested_pid);
            if (process == shared_state_->processes.end()) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto& record = process->second;
            const auto path = record.executable_path.empty()
                                  ? std::string { "/" } + record.command
                                  : record.executable_path;
            const auto bytes =
                *mib1 == darwin::sysctl::kernel_process_arguments2
                    ? darwin::sysctl::encode_process_arguments2(
                          path, record.arguments, record.environment)
                    : darwin::sysctl::encode_process_arguments(
                          path, record.arguments, record.environment);
            const auto required = static_cast<std::uint32_t>(bytes.size());
            if (registers[2] == 0) {
                if (!memory_.write32(registers[3], required)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            }
            const auto copied = std::min(*old_size, required);
            if (copied == 0 ||
                !memory_.copy_in(registers[2],
                    std::span<const std::byte> { bytes }.first(copied)) ||
                !memory_.write32(registers[3], copied)) {
                bsd_error(cpu, copied == 0 ? bsd_support::invalid_argument
                                           : bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, 0);
            return;
        }
        const auto encode_process_info =
            [this](std::uint32_t pid,
                const KernelSharedState::ProcessRecord& record) {
                // The 32-bit kinfo_proc layout is 492 bytes
                // (extern_proc=196, eproc=296).
                std::vector<std::byte> bytes(
                    darwin::sysctl::arm32_kernel_process_info_size);
                const auto put16 = [&](std::size_t offset,
                                       std::uint16_t value) {
                    bytes[offset] = static_cast<std::byte>(value);
                    bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
                };
                const auto put32 = [&](std::size_t offset,
                                       std::uint32_t value) {
                    for (std::size_t byte = 0; byte < 4; ++byte) {
                        bytes[offset + byte] =
                            static_cast<std::byte>(value >> (byte * 8U));
                    }
                };
                const auto process_status = record.exited           ? 5U
                                            : record.signal_stopped ? 4U
                                                                    : 2U;
                bytes[20] = static_cast<std::byte>(process_status);
                put32(24, pid);
                if (const auto state =
                        shared_state_->process_kevent_states.find(pid);
                    state != shared_state_->process_kevent_states.end() &&
                    state->second.exec_generation != 0U) {
                    // extern_proc.p_flag. P_EXEC is the level state paired with
                    // the edge-triggered NOTE_EXEC notification: clients attach
                    // their knote first, then inspect this bit to close the
                    // exec race.
                    put32(16, darwin::sysctl::process_flag_exec);
                }
                bytes[162] = static_cast<std::byte>(
                    pid == process_.pid ? process_.nice_value : 0);
                for (std::size_t index = 0;
                    index < std::min<std::size_t>(16, record.command.size());
                    ++index) {
                    bytes[163 + index] =
                        static_cast<std::byte>(record.command[index]);
                }
                put16(188, static_cast<std::uint16_t>(record.exit_status));
                put32(280, record.uid); // e_pcred.p_ruid
                put32(284, record.uid); // e_pcred.p_svuid
                put32(288, record.gid); // e_pcred.p_rgid
                put32(292, record.gid); // e_pcred.p_svgid
                put32(304, record.effective_uid); // e_ucred.cr_uid
                put16(308, 1); // e_ucred.cr_ngroups
                put32(312, record.effective_gid); // e_ucred.cr_groups[0]
                put32(416, record.parent_pid);
                put32(420, record.process_group);
                return bytes;
            };
        const auto process_table_request =
            *mib0 == darwin::sysctl::control_kernel &&
            *mib1 == darwin::sysctl::kernel_process && mib2 &&
            (registers[1] == 3 || registers[1] == 4);
        if (process_table_request) {
            const auto selector = *mib2;
            const auto selector_argument = mib3;
            const auto is_all_request =
                selector == darwin::sysctl::kernel_process_all &&
                (registers[1] == 3 ||
                    (registers[1] == 4 && selector_argument &&
                        *selector_argument == 0));
            const auto is_filtered_request =
                selector != darwin::sysctl::kernel_process_all &&
                registers[1] == 4 && selector_argument;
            if (!is_all_request && !is_filtered_request) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            switch (selector) {
            case darwin::sysctl::kernel_process_all:
            case darwin::sysctl::kernel_process_id:
            case darwin::sysctl::kernel_process_pgrp:
            case darwin::sysctl::kernel_process_session:
            case darwin::sysctl::kernel_process_tty:
            case darwin::sysctl::kernel_process_uid:
            case darwin::sysctl::kernel_process_ruid:
            case darwin::sysctl::kernel_process_lcid:
                break;
            default:
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (registers[3] == 0) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[4] != 0) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }

            using ProcessMatch =
                std::pair<std::uint32_t,
                    const KernelSharedState::ProcessRecord*>;
            std::vector<ProcessMatch> matching_processes;
            matching_processes.reserve(shared_state_->processes.size());
            for (const auto& [pid, record] : shared_state_->processes) {
                bool matches = false;
                switch (selector) {
                case darwin::sysctl::kernel_process_all:
                    matches = true;
                    break;
                case darwin::sysctl::kernel_process_id:
                    matches = pid == *selector_argument;
                    break;
                case darwin::sysctl::kernel_process_pgrp:
                    matches = record.process_group == *selector_argument;
                    break;
                case darwin::sysctl::kernel_process_uid:
                    matches = record.effective_uid == *selector_argument;
                    break;
                case darwin::sysctl::kernel_process_ruid:
                    matches = record.uid == *selector_argument;
                    break;
                case darwin::sysctl::kernel_process_session:
                case darwin::sysctl::kernel_process_tty:
                case darwin::sysctl::kernel_process_lcid:
                    // These attributes are not represented by the shared
                    // process record, so an unsupported attribute cannot
                    // accidentally match every process.
                    matches = false;
                    break;
                default:
                    break;
                }
                if (matches)
                    matching_processes.emplace_back(pid, &record);
            }

            const auto record_size =
                darwin::sysctl::arm32_kernel_process_info_size;
            const auto bytes_for_records = [record_size](std::size_t count)
                -> std::optional<std::uint32_t> {
                if (count > std::numeric_limits<std::uint32_t>::max() /
                                record_size)
                    return std::nullopt;
                return static_cast<std::uint32_t>(count * record_size);
            };
            if (matching_processes.size() >
                std::numeric_limits<std::size_t>::max() - 5U) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto estimated = bytes_for_records(
                matching_processes.size() + 5U);
            const auto required = bytes_for_records(matching_processes.size());
            if (!estimated || !required) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (registers[2] == 0) {
                if (!memory_.write32(registers[3], *estimated))
                    bsd_error(cpu, bsd_support::bad_address);
                else
                    bsd_success(cpu, 0);
                return;
            }

            const auto record_count = std::min<std::size_t>(
                matching_processes.size(), *old_size / record_size);
            auto destination = registers[2];
            for (std::size_t index = 0; index < record_count; ++index) {
                const auto [pid, record] = matching_processes[index];
                const auto bytes = encode_process_info(pid, *record);
                if (!memory_.copy_in(destination, bytes)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                destination += record_size;
            }
            const auto copied = static_cast<std::uint32_t>(
                record_count * record_size);
            if (!memory_.write32(registers[3], copied)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (copied < *required) {
                bsd_error(cpu, darwin::error::no_memory);
                return;
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == darwin::sysctl::control_kernel && registers[1] == 2) {
            const auto& identity = shared_state_->darwin_kernel_identity;
            switch (*mib1) {
            case darwin::sysctl::kernel_operating_system_type:
                write_read_only_string(identity.operating_system_type);
                return;
            case darwin::sysctl::kernel_operating_system_release:
                write_read_only_string(identity.operating_system_release);
                return;
            case darwin::sysctl::kernel_operating_system_revision: {
                constexpr auto value_size = sizeof(std::uint32_t);
                if (registers[4] != 0) {
                    bsd_error(cpu, darwin::error::operation_not_permitted);
                } else if (registers[3] == 0 ||
                           !memory_.write32(registers[3], value_size)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else if (registers[2] != 0 && *old_size < value_size) {
                    bsd_error(cpu, darwin::error::no_memory);
                } else if (registers[2] != 0 &&
                           !memory_.write32(registers[2],
                               identity.operating_system_revision)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
                return;
            }
            case darwin::sysctl::kernel_version:
                write_read_only_string(identity.version);
                return;
            case darwin::sysctl::kernel_build_version:
                write_read_only_string(identity.build_version);
                return;
            case darwin::sysctl::kernel_boot_time: {
                const auto boot = shared_state_->clock.boot_time();
                const std::array<std::uint32_t, 2> timeval {
                    static_cast<std::uint32_t>(
                        boot / VirtualClock::nanoseconds_per_second),
                    static_cast<std::uint32_t>(
                        (boot % VirtualClock::nanoseconds_per_second) / 1000U)
                };
                std::array<std::byte, 8> bytes { };
                for (std::size_t index = 0; index < timeval.size(); ++index) {
                    for (std::size_t byte = 0; byte < sizeof(std::uint32_t);
                        ++byte) {
                        bytes[index * sizeof(std::uint32_t) + byte] =
                            static_cast<std::byte>(timeval[index] >> (byte * 8U));
                    }
                }
                write_read_only_bytes(bytes);
                return;
            }
            case darwin::sysctl::kernel_clock_rate: {
                // Darwin 11 exposes struct clockinfo for KERN_CLOCKRATE:
                // hz, tick, tickadj, stathz and profhz. These are stable
                // kernel timing values, independent of host scheduling.
                constexpr std::array<std::uint32_t, 5> clock_info {
                    100U, 10'000U, 0U, 100U, 100U };
                std::array<std::byte, clock_info.size() * sizeof(std::uint32_t)>
                    bytes { };
                for (std::size_t index = 0; index < clock_info.size();
                    ++index) {
                    const auto value = clock_info[index];
                    for (std::size_t byte = 0; byte < sizeof(value); ++byte)
                        bytes[index * sizeof(value) + byte] =
                            static_cast<std::byte>(value >> (byte * 8U));
                }
                write_read_only_bytes(bytes);
                return;
            }
            default:
                break;
            }
        }
        if (*mib0 == 1 && *mib1 == 61 && registers[1] == 3) { // KERN_TFP
            const auto selector = memory_.read32(registers[0] + 8);
            if (!selector || (*selector != 2 && *selector != 3) ||
                registers[4] == 0 || registers[5] != 4) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto group = memory_.read32(registers[4]);
            if (!group) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            shared_state_->task_for_pid_groups[*selector - 2] = *group;
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == darwin::sysctl::control_kernel &&
            *mib1 == darwin::sysctl::kernel_security_level &&
            registers[1] == 2) { // KERN_SECURELVL
            const auto previous =
                shared_state_->security_level.load(std::memory_order_relaxed);
            std::optional<std::int32_t> requested_level;
            if (registers[4] != 0) {
                if (registers[5] != sizeof(std::int32_t)) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                const auto requested = memory_.read32(registers[4]);
                if (!requested) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                const auto level = static_cast<std::int32_t>(*requested);
                if (level < previous && process_.pid != 1) {
                    bsd_error(cpu, darwin::error::operation_not_permitted);
                    return;
                }
                requested_level = level;
            }
            if (registers[3] != 0) {
                constexpr std::uint32_t value_size = sizeof(std::int32_t);
                if (!memory_.write32(registers[3], value_size)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (registers[2] != 0) {
                    if (*old_size < value_size) {
                        bsd_error(cpu, darwin::error::no_memory);
                        return;
                    }
                    if (!memory_.write32(registers[2],
                            static_cast<std::uint32_t>(previous))) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                }
            }
            if (requested_level) {
                shared_state_->security_level.store(
                    *requested_level, std::memory_order_relaxed);
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == 1 && *mib1 == 5) { // KERN_MAXVNODES (read/write)
            const auto previous = shared_state_->desired_vnodes;
            if (registers[4] != 0) {
                if (registers[5] != 4) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                const auto requested = memory_.read32(registers[4]);
                if (!requested) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                shared_state_->desired_vnodes = *requested;
            }
            if (registers[3] != 0) {
                if (!memory_.write32(registers[3], 4) ||
                    (registers[2] != 0 &&
                        (*old_size < 4 ||
                            !memory_.write32(registers[2], previous)))) {
                    bsd_error(
                        cpu, *old_size < 4 ? 12 : bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == 1 && *mib1 == 10) { // KERN_HOSTNAME (read/write)
            const auto previous = shared_state_->hostname;
            if (registers[4] != 0) {
                if (registers[5] == 0 || registers[5] > 256) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                const auto bytes =
                    memory_.read_bytes(registers[4], registers[5]);
                if (!bytes) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                shared_state_->hostname.assign(
                    reinterpret_cast<const char*>(bytes->data()),
                    bytes->size());
                if (!shared_state_->hostname.empty() &&
                    shared_state_->hostname.back() == '\0') {
                    shared_state_->hostname.pop_back();
                }
            }
            if (registers[3] != 0) {
                const auto required =
                    static_cast<std::uint32_t>(previous.size() + 1);
                if (!memory_.write32(registers[3], required)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (registers[2] != 0) {
                    if (*old_size < required) {
                        bsd_error(cpu, 12);
                        return;
                    }
                    std::vector<std::byte> bytes(required);
                    std::transform(previous.begin(), previous.end(),
                        bytes.begin(), [](char value) {
                            return static_cast<std::byte>(value);
                        });
                    if (!memory_.copy_in(registers[2], bytes)) {
                        bsd_error(cpu, bsd_support::bad_address);
                        return;
                    }
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (*mib0 == 6 && *mib1 == 24) { // HW_MEMSIZE
            if (registers[3] == 0 || !memory_.write32(registers[3], 8)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < 8) {
                    bsd_error(cpu, 12);
                    return;
                }
                if (!memory_.write64(
                        registers[2], shared_state_->device_ram_bytes)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if (const auto hardware_string =
                *mib0 == darwin::sysctl::control_hardware
                    ? darwin::sysctl::hardware_string(*mib1,
                          shared_state_->device_product_type,
                          shared_state_->device_hardware_model)
                    : std::nullopt) {
            const auto required =
                static_cast<std::uint32_t>(hardware_string->size() + 1);
            if (registers[4] != 0) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            if (registers[3] == 0 || !memory_.write32(registers[3], required)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < required) {
                    bsd_error(cpu, darwin::error::no_memory);
                    return;
                }
                std::vector<std::byte> bytes(required);
                std::transform(hardware_string->begin(), hardware_string->end(),
                    bytes.begin(),
                    [](char value) { return static_cast<std::byte>(value); });
                if (!memory_.copy_in(registers[2], bytes)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        if ((*mib0 == darwin::sysctl::control_kernel &&
                (*mib1 == 6 || *mib1 == 7 || *mib1 == 8 ||
                    *mib1 == darwin::sysctl::kernel_maximum_files_per_process ||
                    *mib1 == 35 || *mib1 == 40 || *mib1 == 54 ||
                    *mib1 == 66)) ||
            (*mib0 == darwin::sysctl::control_hardware &&
                (*mib1 == darwin::sysctl::hardware_cpu_count ||
                    *mib1 == darwin::sysctl::hardware_byte_order ||
                    *mib1 == darwin::sysctl::hardware_physical_memory ||
                    *mib1 == darwin::sysctl::hardware_user_memory ||
                    *mib1 == darwin::sysctl::hardware_page_size ||
                    *mib1 == 11 || *mib1 == 13 ||
                    *mib1 == darwin::sysctl::hardware_cache_line ||
                    *mib1 == darwin::sysctl::hardware_l1_i_cache_size ||
                    *mib1 == darwin::sysctl::hardware_l1_d_cache_size ||
                    *mib1 == darwin::sysctl::hardware_l2_settings ||
                    *mib1 == darwin::sysctl::hardware_l2_cache_size ||
                    *mib1 == darwin::sysctl::hardware_l3_settings ||
                    *mib1 == darwin::sysctl::hardware_l3_cache_size ||
                    *mib1 == darwin::sysctl::hardware_available_cpu ||
                    *mib1 == darwin::sysctl::hardware_bus_frequency ||
                    *mib1 == darwin::sysctl::hardware_cpu_frequency ||
                    *mib1 == darwin::sysctl::hardware_physical_cpu ||
                    *mib1 == darwin::sysctl::hardware_physical_cpu_max ||
                    *mib1 == darwin::sysctl::hardware_logical_cpu ||
                    *mib1 == darwin::sysctl::hardware_logical_cpu_max ||
                    *mib1 == darwin::sysctl::hardware_cpu_frequency_max ||
                    *mib1 == darwin::sysctl::hardware_bus_frequency_max))) {
            // Common read-only capacity/boot values plus HW_NCPU.
            if (registers[4] != 0) {
                bsd_error(cpu, 1); // EPERM: read-only MIB
                return;
            }
            if (!memory_.write32(registers[3], 4)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (registers[2] != 0) {
                if (*old_size < 4) {
                    bsd_error(cpu, 12); // ENOMEM
                    return;
                }
                std::uint32_t value = 1;
                if (*mib0 == 1) {
                    switch (*mib1) {
                    case 5:
                        value = 65'536;
                        break; // KERN_MAXVNODES
                    case 6:
                        value = 2'048;
                        break; // KERN_MAXPROC
                    case 7:
                        value = 12'288;
                        break; // KERN_MAXFILES
                    case 8:
                        value = 262'144;
                        break; // KERN_ARGMAX
                    case darwin::sysctl::kernel_maximum_files_per_process:
                        value = static_cast<std::uint32_t>(
                            darwin::resource::maximum_open_files);
                        break;
                    case 35:
                        value = darwin_address_bounds(
                            shared_state_->darwin_abi.address_layout).stack_top;
                        break; // KERN_USRSTACK32
                    case 40: // KERN_NETBOOT
                    case 66:
                        value = 0;
                        break; // KERN_SAFEBOOT
                    default:
                        value = 1;
                        break;
                    }
                } else {
                    const auto configured_memory_size =
                        device_model_.memory.usable_ram_bytes != 0
                            ? std::min(device_model_.memory.usable_ram_bytes,
                                  shared_state_->device_ram_bytes)
                            : shared_state_->device_ram_bytes;
                    switch (*mib1) {
                    case darwin::sysctl::hardware_byte_order:
                        value = 1234;
                        break; // HW_BYTEORDER
                    case darwin::sysctl::hardware_physical_memory:
                        value =
                            static_cast<std::uint32_t>(std::min<std::uint64_t>(
                                configured_memory_size,
                                std::numeric_limits<std::uint32_t>::max()));
                        break; // HW_PHYSMEM
                    case darwin::sysctl::hardware_user_memory:
                        value =
                            static_cast<std::uint32_t>(std::min<std::uint64_t>(
                                shared_state_->device_ram_bytes > 0x01000000U
                                    ? shared_state_->device_ram_bytes -
                                          0x01000000U
                                    : shared_state_->device_ram_bytes,
                                std::numeric_limits<std::uint32_t>::max()));
                        break; // HW_USERMEM
                    case darwin::sysctl::hardware_page_size:
                        value = 4096;
                        break; // HW_PAGESIZE
                    case 11:
                        value = 1;
                        break; // HW_FLOATINGPT
                    case 13:
                        value = 0;
                        break; // HW_VECTORUNIT
                    case darwin::sysctl::hardware_cache_line:
                        value = 64;
                        break; // HW_CACHELINE
                    case darwin::sysctl::hardware_l1_i_cache_size:
                    case darwin::sysctl::hardware_l1_d_cache_size:
                        value = 32U * 1024U;
                        break; // HW_L1{I,D}CACHESIZE
                    case darwin::sysctl::hardware_l2_settings:
                        value = 0;
                        break; // HW_L2SETTINGS
                    case darwin::sysctl::hardware_l2_cache_size:
                        value = 1024U * 1024U;
                        break; // HW_L2CACHESIZE
                    case darwin::sysctl::hardware_l3_settings:
                    case darwin::sysctl::hardware_l3_cache_size:
                        value = 0;
                        break; // HW_L3{SETTINGS,CACHESIZE}
                    case darwin::sysctl::hardware_bus_frequency:
                    case darwin::sysctl::hardware_bus_frequency_max:
                        value = device_model_.processor.bus_hz;
                        break; // HW_BUS_FREQ
                    case darwin::sysctl::hardware_cpu_frequency:
                    case darwin::sysctl::hardware_cpu_frequency_max:
                        value = device_model_.processor.frequency_hz();
                        break; // HW_CPU_FREQ
                    case darwin::sysctl::hardware_physical_cpu:
                    case darwin::sysctl::hardware_physical_cpu_max:
                        value = std::min<std::uint32_t>(
                            device_model_.processor.topology.physical_core_count,
                            virtual_processor_count_);
                        break; // hw.physicalcpu
                    default:
                        value = virtual_processor_count_;
                        break; // HW_NCPU, HW_AVAILCPU, hw.logicalcpu
                    }
                }
                if (!memory_.write32(registers[2], value)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
            }
            bsd_success(cpu, 0);
            return;
        }
        std::ostringstream message;
        message << "[sysctl] unsupported mib";
        for (std::uint32_t index = 0; index < registers[1] && index < 8;
            ++index) {
            message << ' '
                    << memory_.read32(registers[0] + index * 4U)
                           .value_or(0xffffffffU);
        }
        message << '\n';
        output_.write(message.str());
        trace_unknown(cpu, "BSD syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }
    default:
        trace_unknown(cpu, "BSD syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }
}

} // namespace shade
