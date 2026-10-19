// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle descriptor I/O, memory mappings and shared-memory syscall
// operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_descrip.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_mman.c

#include "kernel/kernel.hpp"

#include "kernel/baseband_device.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "device_state/graphics_services_capabilities.hpp"
#include "kernel/kernel_network.hpp"
#include "kernel/null_device.hpp"
#include "kernel/offline_serial_device.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cerrno>
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

#include <sys/stat.h>
#include <unistd.h>

#include "support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t maximum_baseband_io_traces = 64;

} // namespace

void CompatibilityKernel::dispatch_bsd_descriptor_memory(
    Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    switch (number) {
    case darwin::syscall::read: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto size = static_cast<std::size_t>(registers[2]);
        if (size > bsd_support::maximum_io) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto virtual_descriptor = virtual_descriptors_.find(fd);
        const auto offline_serial_descriptor =
            virtual_descriptor != virtual_descriptors_.end() &&
            virtual_descriptor->second ==
                bsd::offline_serial_device::descriptor_kind;
        if (offline_serial_descriptor) {
            if (size == 0) {
                bsd_success(cpu, 0);
                return;
            }
            if (auto bytes = offline_serial_state_.read(size); !bytes.empty()) {
                if (!memory_.copy_in(registers[1], bytes)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
                }
                return;
            }
            if ((file_status_flags_[fd] & darwin::open_flag::non_block) != 0) {
                bsd_error(cpu, bsd_support::would_block);
                return;
            }
            const auto attributes = offline_serial_state_.attributes();
            const auto timeout =
                attributes
                    .control_characters[darwin::tty::timeout_deciseconds_index];
            if (timeout == 0) {
                // Without a read timeout, a disconnected character device
                // reports the carrier failure instead of suspending a process
                // forever.
                bsd_error(cpu, darwin::error::io);
                return;
            }
            constexpr std::uint64_t nanoseconds_per_decisecond = 100'000'000ULL;
            const auto deadline = shared_state_->clock.now() +
                                  static_cast<std::uint64_t>(timeout) *
                                      nanoseconds_per_decisecond;
            pending_socket_reads_[cpu.processor_id()] = PendingSocketRead { fd,
                registers[1], static_cast<std::uint32_t>(size), 0, 0,
                cpu.processor_id(), deadline };
            process_.waiting_for_events = true;
            cpu.halt(Umbra::HaltReason::UserDefined5);
            return;
        }
        const auto baseband_descriptor =
            virtual_descriptor != virtual_descriptors_.end() &&
            virtual_descriptor->second == bsd::baseband_device::descriptor_kind;
        const auto readable_socket =
            host_sockets_.contains(fd) || virtual_udp_sockets_.contains(fd) ||
            bpf_descriptors_.contains(fd) ||
            kernel_control_endpoints_.contains(fd) ||
            socket_pair_endpoints_.contains(fd) || baseband_descriptor ||
            (virtual_descriptor != virtual_descriptors_.end() &&
                (virtual_descriptor->second == "system-event-socket" ||
                    virtual_descriptor->second == "route-socket" ||
                    virtual_descriptor->second ==
                        darwin::network::apple80211_driver::
                            event_descriptor_kind));
        if (readable_socket) {
            if (receive_socket_bytes(
                    cpu, fd, registers[1], static_cast<std::uint32_t>(size))) {
                return;
            }
            if ((file_status_flags_[fd] & darwin::open_flag::non_block) != 0) {
                bsd_error(cpu, bsd_support::would_block);
                return;
            }
            pending_socket_reads_[cpu.processor_id()] = PendingSocketRead { fd,
                registers[1], static_cast<std::uint32_t>(size), 0, 0,
                cpu.processor_id(), std::nullopt };
            process_.waiting_for_events = true;
            output_.write(std::string { baseband_descriptor ? "[baseband]"
                                                            : "[network]" } +
                          " read wait pid=" + std::to_string(process_.pid) +
                          " fd=" + std::to_string(fd) +
                          " bytes=" + std::to_string(size) + "\n");
            cpu.halt(Umbra::HaltReason::UserDefined5);
            return;
        }
        std::vector<std::byte> bytes(size);
        if (const auto device = virtual_descriptors_.find(fd);
            device != virtual_descriptors_.end() &&
            device->second == "random") {
            for (auto& byte : bytes) {
                random_state_ ^= random_state_ << 13U;
                random_state_ ^= random_state_ >> 7U;
                random_state_ ^= random_state_ << 17U;
                byte = static_cast<std::byte>(random_state_ & 0xffU);
            }
        } else if (const auto resolver = virtual_descriptors_.find(fd);
            resolver != virtual_descriptors_.end() &&
            resolver->second == "resolver-config") {
            constexpr std::string_view configuration {
                "nameserver 10.0.2.3\n"
            };
            const auto offset =
                std::min<std::size_t>(file_offsets_[fd], configuration.size());
            const auto count =
                std::min<std::size_t>(size, configuration.size() - offset);
            bytes.resize(count);
            const auto begin =
                configuration.begin() + static_cast<std::ptrdiff_t>(offset);
            std::transform(begin, begin + static_cast<std::ptrdiff_t>(count),
                bytes.begin(),
                [](char value) { return static_cast<std::byte>(value); });
            file_offsets_[fd] = offset + count;
        } else if (const auto console_device = virtual_descriptors_.find(fd);
            console_device != virtual_descriptors_.end() &&
            (console_device->second == "console" ||
                console_device->second == bsd::null_device::descriptor_kind)) {
            bytes.clear();
        } else if (const auto file = file_descriptors_.find(fd);
            file != file_descriptors_.end()) {
            const auto description = ensure_regular_file_open_description(fd);
            if (!description) {
                bsd_error(cpu, darwin::error::bad_file_descriptor);
                return;
            }
            const auto result =
                ::pread(description->host_descriptor(), bytes.data(),
                    bytes.size(), static_cast<off_t>(file_offsets_[fd]));
            if (result < 0) {
                bsd_error(cpu,
                    bsd_support::darwin_filesystem_error(
                        std::error_code { errno, std::generic_category() }));
                return;
            }
            bytes.resize(static_cast<std::size_t>(result));
            file_offsets_[fd] += bytes.size();
        } else if (fd == 0) {
            bytes.clear(); // terminal input currently presents non-blocking EOF
        } else {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (!memory_.copy_in(registers[1], bytes)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
        return;
    }
    case darwin::syscall::write: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto address = registers[1];
        const auto size = static_cast<std::size_t>(registers[2]);
        if (bpf_descriptors_.contains(fd)) {
            static_cast<void>(write_bpf_bytes(
                cpu, fd, address, static_cast<std::uint32_t>(size)));
            return;
        }
        if (kernel_control_endpoints_.contains(fd)) {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            static_cast<void>(write_kernel_control_socket(cpu, fd, *bytes));
            return;
        }
        if (const auto descriptor = virtual_descriptors_.find(fd);
            descriptor != virtual_descriptors_.end() &&
            descriptor->second == "route-socket") {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, darwin::error::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, darwin::error::bad_address);
                return;
            }
            const auto parsed = darwin::route::parse_message(*bytes);
            if (!parsed.message) {
                const auto parse_error =
                    parsed.error ==
                            darwin::route::ParseError::UnsupportedVersion
                        ? darwin::error::protocol_not_supported
                        : (parsed.error ==
                                      darwin::route::ParseError::UnsupportedType
                                  ? darwin::error::operation_not_supported
                                  : darwin::error::invalid_argument);
                bsd_error(cpu, parse_error);
                return;
            }
            auto entry = darwin::route::make_entry(*parsed.message);
            if (!entry) {
                bsd_error(cpu, darwin::error::invalid_argument);
                return;
            }

            const auto query =
                parsed.message->type == darwin::route::message_get ||
                parsed.message->type == darwin::route::message_get_silent;
            std::optional<darwin::route::Entry> queried_entry;
            std::uint32_t route_error =
                !query && process_.effective_uid != 0
                    ? darwin::error::operation_not_permitted
                    : 0U;
            if (query) {
                queried_entry = shared_state_->route_table.lookup(*entry);
                if (!queried_entry) {
                    route_error = darwin::error::no_such_process;
                }
            } else if (route_error == 0) {
                const auto add_or_change =
                    parsed.message->type == darwin::route::message_add ||
                    parsed.message->type == darwin::route::message_change;
                if (add_or_change && entry->interface_name.empty() &&
                    entry->interface_index == 0 &&
                    entry->gateway.size() >= 8U &&
                    std::to_integer<std::uint8_t>(entry->gateway[1]) ==
                        darwin::network::address_family_link) {
                    const auto link_index = static_cast<std::uint16_t>(
                        std::to_integer<std::uint8_t>(entry->gateway[2]) |
                        (static_cast<std::uint16_t>(
                             std::to_integer<std::uint8_t>(entry->gateway[3]))
                            << 8U));
                    const auto name_length = static_cast<std::size_t>(
                        std::to_integer<std::uint8_t>(entry->gateway[5]));
                    if (name_length <= entry->gateway.size() - 8U) {
                        entry->interface_index = link_index;
                        entry->interface_name.assign(
                            reinterpret_cast<const char*>(
                                entry->gateway.data() + 8U),
                            name_length);
                    }
                }

                if (!entry->interface_name.empty() ||
                    entry->interface_index != 0) {
                    std::lock_guard network_lock {
                        shared_state_->network_mutex
                    };
                    if (!entry->interface_name.empty()) {
                        const auto interface =
                            shared_state_->network_interfaces.find(
                                entry->interface_name);
                        if (interface ==
                            shared_state_->network_interfaces.end()) {
                            route_error =
                                darwin::error::no_such_device_or_address;
                        } else if (entry->interface_index != 0 &&
                                   entry->interface_index !=
                                       interface->second.index) {
                            route_error = darwin::error::invalid_argument;
                        } else {
                            entry->interface_index = interface->second.index;
                        }
                    } else {
                        const auto interface = std::find_if(
                            shared_state_->network_interfaces.begin(),
                            shared_state_->network_interfaces.end(),
                            [&](const auto& candidate) {
                                return candidate.second.index ==
                                       entry->interface_index;
                            });
                        if (interface ==
                            shared_state_->network_interfaces.end()) {
                            route_error =
                                darwin::error::no_such_device_or_address;
                        } else {
                            entry->interface_name = interface->first;
                        }
                    }
                }

                const auto gateway_family =
                    entry->gateway.size() >= 2U
                        ? std::to_integer<std::uint8_t>(entry->gateway[1])
                        : darwin::network::address_family_unspecified;
                if (route_error == 0 && add_or_change &&
                    entry->interface_name.empty() &&
                    entry->interface_index == 0 &&
                    (gateway_family == darwin::network::address_family_inet ||
                        gateway_family ==
                            darwin::network::address_family_inet6)) {
                    darwin::route::Entry gateway_query;
                    gateway_query.family =
                        static_cast<std::uint8_t>(gateway_family);
                    gateway_query.destination = entry->gateway;
                    if (const auto route =
                            shared_state_->route_table.lookup_bound_interface(
                                gateway_query)) {
                        entry->interface_name = route->interface_name;
                        entry->interface_index = route->interface_index;
                    }
                }
            }
            if (!query && route_error == 0) {
                switch (shared_state_->route_table.apply(
                    parsed.message->type, *entry)) {
                case darwin::route::ApplyResult::Applied:
                    break;
                case darwin::route::ApplyResult::AlreadyExists:
                    route_error = darwin::error::file_exists;
                    break;
                case darwin::route::ApplyResult::NotFound:
                    route_error = darwin::error::no_such_process;
                    break;
                }
            }

            const auto include_interface =
                (parsed.message->addresses &
                    darwin::route::address_interface) != 0;
            auto response =
                queried_entry
                    ? darwin::route::make_entry_message(*queried_entry,
                          process_.pid, parsed.message->sequence, true,
                          include_interface)
                    : darwin::route::make_response(*bytes, process_.pid,
                          route_error, entry->interface_index);
            if (parsed.message->type == darwin::route::message_get_silent &&
                response.size() >= darwin::route::message_header_size) {
                response[3] =
                    static_cast<std::byte>(darwin::route::message_get);
            }
            const auto silent =
                parsed.message->type == darwin::route::message_get_silent;
            const auto receiver_socket =
                silent && route_socket_states_.contains(fd) &&
                        route_socket_states_.at(fd)
                    ? std::optional<std::uint64_t> { route_socket_states_
                              .at(fd)
                              ->identifier }
                    : std::nullopt;
            post_route_message(
                std::move(response), entry->family, receiver_socket);
            output_.write(
                "[network] route pid=" + std::to_string(process_.pid) +
                " type=" + std::to_string(parsed.message->type) +
                " family=" + std::to_string(entry->family) +
                (entry->interface_name.empty()
                        ? std::string { }
                        : " if=" + entry->interface_name) +
                " error=" + std::to_string(route_error) + "\n");
            if (route_error != 0) {
                bsd_error(cpu, route_error);
            } else {
                bsd_success(cpu, static_cast<std::uint32_t>(bytes->size()));
            }
            return;
        }
        if (const auto host = host_sockets_.find(fd);
            host != host_sockets_.end()) {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto nonblocking =
                (file_status_flags_[fd] & darwin::open_flag::non_block) != 0;
            static_cast<void>(send_host_socket_bytes(
                cpu, fd, std::move(*bytes), { }, nonblocking));
            return;
        }
        if (const auto udp = virtual_udp_sockets_.find(fd);
            udp != virtual_udp_sockets_.end()) {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto sent = udp->second->send(*bytes);
            if (sent != bsd::VirtualUdpStatus::Success) {
                bsd_error(cpu, sent == bsd::VirtualUdpStatus::NotConnected
                                   ? bsd_support::not_connected
                                   : bsd_support::invalid_argument);
            } else {
                bsd_success(cpu, static_cast<std::uint32_t>(bytes->size()));
            }
            return;
        }
        if (const auto endpoint = socket_pair_endpoints_.find(fd);
            endpoint != socket_pair_endpoints_.end()) {
            if (!endpoint->second.local_write_open() ||
                !endpoint->second.peer_read_open()) {
                bsd_error(cpu, darwin::error::broken_pipe);
                return;
            }
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (socket_payload_trace_count_ < 32U) {
                output_.write(
                    "[network] write pid=" + std::to_string(process_.pid) +
                    " fd=" + std::to_string(fd) +
                    " pair=" + std::to_string(endpoint->second.pair) +
                    " bytes=" + std::to_string(bytes->size()) + " hex=" +
                    bsd_support::format_payload_prefix(*bytes) + "\n");
                ++socket_payload_trace_count_;
            }
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            auto& destination =
                shared_state_->socket_pair_buffers[endpoint->second.pair]
                                                  [1U - endpoint->second.side];
            destination.insert(destination.end(), bytes->begin(), bytes->end());
            shared_state_->note_io_event_transition();
            bsd_success(cpu, static_cast<std::uint32_t>(bytes->size()));
            return;
        }
        if (const auto device = virtual_descriptors_.find(fd);
            device != virtual_descriptors_.end() &&
            device->second == bsd::null_device::descriptor_kind) {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            bsd_success(cpu, static_cast<std::uint32_t>(size));
            return;
        }
        if (const auto device = virtual_descriptors_.find(fd);
            device != virtual_descriptors_.end() &&
            device->second == "console") {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            output_.write(std::string_view {
                reinterpret_cast<const char*>(bytes->data()), bytes->size() });
            bsd_success(cpu, static_cast<std::uint32_t>(bytes->size()));
            return;
        }
        if (const auto device = virtual_descriptors_.find(fd);
            device != virtual_descriptors_.end() &&
            device->second == bsd::offline_serial_device::descriptor_kind) {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto written = offline_serial_state_.write(*bytes);
            bsd_success(cpu, static_cast<std::uint32_t>(written));
            return;
        }
        if (const auto device = virtual_descriptors_.find(fd);
            device != virtual_descriptors_.end() &&
            device->second == bsd::baseband_device::descriptor_kind) {
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (size == 0) {
                bsd_success(cpu, 0);
                return;
            }
            auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (baseband_io_trace_count_ < maximum_baseband_io_traces) {
                output_.write(
                    "[baseband] write pid=" + std::to_string(process_.pid) +
                    " fd=" + std::to_string(fd) +
                    " bytes=" + std::to_string(bytes->size()) + " hex=" +
                    bsd_support::format_payload_prefix(*bytes) + "\n");
                ++baseband_io_trace_count_;
            }
            const auto endpoint = baseband_open_description(fd);
            if (!endpoint || !endpoint->writable()) {
                if (endpoint && endpoint->transmit_sink_failed())
                    bsd_error(cpu, darwin::error::io);
                else
                    // A profile without a device node has no event that can
                    // make this queue writable.  Report the unavailable
                    // transport immediately.
                    bsd_error(cpu, darwin::error::no_such_device_or_address);
                return;
            }
            const auto written = endpoint->write(*bytes);
            if (written != bytes->size()) {
                bsd_error(cpu, darwin::error::io);
                return;
            }
            if (endpoint->pending_receive_bytes() != 0U)
                shared_state_->note_io_event_transition();
            bsd_success(cpu, static_cast<std::uint32_t>(written));
            return;
        }
        if (const auto file = file_descriptors_.find(fd);
            file != file_descriptors_.end()) {
            const auto flags = file_status_flags_.contains(fd)
                                   ? file_status_flags_.at(fd)
                                   : darwin::open_flag::read_only;
            if ((flags & darwin::open_flag::access_mode) ==
                darwin::open_flag::read_only) {
                bsd_error(cpu, darwin::error::bad_file_descriptor);
                return;
            }
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, darwin::error::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(address, size);
            if (!bytes) {
                bsd_error(cpu, darwin::error::bad_address);
                return;
            }
            const auto description = ensure_regular_file_open_description(fd);
            if (!description) {
                bsd_error(cpu, darwin::error::bad_file_descriptor);
                return;
            }
            std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
            std::uint64_t position = file_offsets_[fd];
            if ((flags & darwin::open_flag::append) != 0) {
                struct stat status { };
                if (::fstat(description->host_descriptor(), &status) != 0) {
                    bsd_error(cpu,
                        bsd_support::darwin_filesystem_error(std::error_code {
                            errno, std::generic_category() }));
                    return;
                }
                position = static_cast<std::uint64_t>(status.st_size);
            }
            const auto result = ::pwrite(description->host_descriptor(),
                bytes->data(), bytes->size(), static_cast<off_t>(position));
            if (result < 0) {
                bsd_error(cpu,
                    bsd_support::darwin_filesystem_error(
                        std::error_code { errno, std::generic_category() }));
                return;
            }
            static_cast<void>(shared_state_->shared_mapping_page_cache
                    ->reflect_descriptor_write(description->host_descriptor(),
                        position,
                        std::span<const std::byte> {
                            bytes->data(), static_cast<std::size_t>(result) }));
            file_offsets_[fd] = position + static_cast<std::size_t>(result);
            static_cast<void>(shared_state_->guest_file_generation_registry
                    ->publish_descriptor(file->second,
                        description->host_descriptor(),
                        GuestFileMutationKind::Write));
            bsd_success(cpu, static_cast<std::uint32_t>(result));
            return;
        }
        if (fd != 1 && fd != 2) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (size > bsd_support::maximum_io) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto bytes = memory_.read_bytes(address, size);
        if (!bytes) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        output_.write(std::string_view {
            reinterpret_cast<const char*>(bytes->data()), bytes->size() });
        bsd_success(cpu, static_cast<std::uint32_t>(bytes->size()));
        return;
    }
    case 41: { // dup
        const auto source = registers[0];
        if (reject_guarded_descriptor(cpu, source, DarwinFileGuard::duplicate))
            return;
        const bool valid = source <= 2 || file_descriptors_.contains(source) ||
                           virtual_descriptors_.contains(source) ||
                           duplicated_descriptors_.contains(source);
        if (!valid) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto destination = allocate_file_descriptor();
        if (!destination) {
            bsd_error(cpu, 24); // EMFILE
            return;
        }
        const auto allocated = *destination;
        if (const auto file = file_descriptors_.find(source);
            file != file_descriptors_.end()) {
            file_descriptors_.emplace(allocated, file->second);
            file_offsets_[allocated] = file_offsets_[source];
            file_status_flags_[allocated] = file_status_flags_[source];
            if (const auto description =
                    regular_file_open_descriptions_.find(source);
                description != regular_file_open_descriptions_.end()) {
                regular_file_open_descriptions_[allocated] =
                    description->second;
            }
            if (const auto block = virtual_block_descriptors_.find(source);
                block != virtual_block_descriptors_.end()) {
                virtual_block_descriptors_[allocated] = block->second;
            }
        } else if (const auto device = virtual_descriptors_.find(source);
            device != virtual_descriptors_.end()) {
            virtual_descriptors_.emplace(allocated, device->second);
            if (const auto offset = file_offsets_.find(source);
                offset != file_offsets_.end()) {
                file_offsets_[allocated] = offset->second;
            }
            if (const auto host = host_sockets_.find(source);
                host != host_sockets_.end()) {
                host_sockets_[allocated] = host->second;
            }
            if (const auto socket = virtual_udp_sockets_.find(source);
                socket != virtual_udp_sockets_.end()) {
                virtual_udp_sockets_[allocated] = socket->second;
            }
            if (const auto control = kernel_control_endpoints_.find(source);
                control != kernel_control_endpoints_.end()) {
                kernel_control_endpoints_[allocated] = control->second;
            }
            if (const auto flags = file_status_flags_.find(source);
                flags != file_status_flags_.end()) {
                file_status_flags_[allocated] = flags->second;
            }
            if (const auto options = socket_options_.find(source);
                options != socket_options_.end()) {
                socket_options_[allocated] = options->second;
            }
            if (const auto bound = bound_socket_names_.find(source);
                bound != bound_socket_names_.end()) {
                bound_socket_names_[allocated] = bound->second;
            }
            if (listening_sockets_.contains(source)) {
                listening_sockets_.insert(allocated);
            }
            if (const auto endpoint = socket_pair_endpoints_.find(source);
                endpoint != socket_pair_endpoints_.end()) {
                socket_pair_endpoints_[allocated] = endpoint->second;
            }
            if (const auto listener = unix_listener_states_.find(source);
                listener != unix_listener_states_.end()) {
                unix_listener_states_[allocated] = listener->second;
            }
            if (const auto filter = system_event_filters_.find(source);
                filter != system_event_filters_.end()) {
                system_event_filters_[allocated] = filter->second;
            }
            if (const auto cursor = system_event_next_identifiers_.find(source);
                cursor != system_event_next_identifiers_.end()) {
                system_event_next_identifiers_[allocated] = cursor->second;
            }
            if (const auto state = route_socket_states_.find(source);
                state != route_socket_states_.end()) {
                route_socket_states_[allocated] = state->second;
            }
            if (const auto bpf = bpf_descriptors_.find(source);
                bpf != bpf_descriptors_.end()) {
                bpf_descriptors_[allocated] = bpf->second;
            }
        } else {
            const auto original = duplicated_descriptors_.contains(source)
                                      ? duplicated_descriptors_.at(source)
                                      : source;
            duplicated_descriptors_.emplace(allocated, original);
        }
        if (const auto baseband = baseband_open_description(source)) {
            // A dup retains the same open description. Keep a direct descriptor
            // entry as well so poll/select and later descriptor passing do not
            // need to interpret a string kind as a transport session.
            baseband_open_descriptions_[allocated] = baseband;
            virtual_descriptors_[allocated] =
                bsd::baseband_device::descriptor_kind;
            file_status_flags_[allocated] = file_status_flags_.contains(source)
                                                ? file_status_flags_.at(source)
                                                : darwin::open_flag::read_write;
            duplicated_descriptors_.erase(allocated);
        }
        copy_kqueue_descriptor_state(source, allocated);
        bsd_success(cpu, allocated);
        return;
    }
    case 42: { // pipe: Darwin returns the two descriptors in retval[0:1]
        const auto read_fd = allocate_file_descriptor();
        if (!read_fd) {
            bsd_error(cpu, 24); // EMFILE
            return;
        }
        virtual_descriptors_.emplace(*read_fd, "pipe-read");
        file_status_flags_[*read_fd] = darwin::open_flag::read_only;
        descriptor_flags_[*read_fd] = 0;
        const auto write_fd = allocate_file_descriptor();
        if (!write_fd) {
            virtual_descriptors_.erase(*read_fd);
            file_status_flags_.erase(*read_fd);
            descriptor_flags_.erase(*read_fd);
            bsd_error(cpu, 24);
            return;
        }
        virtual_descriptors_.emplace(*write_fd, "pipe-write");
        file_status_flags_[*write_fd] = darwin::open_flag::write_only;
        descriptor_flags_[*write_fd] = 0;
        const auto pair = shared_state_->next_socket_pair++;
        auto endpoints = make_socket_pair_endpoints(pair);
        shared_state_->socket_pair_buffers.emplace(
            pair, std::array<std::deque<std::byte>, 2> { });
        socket_pair_endpoints_[*read_fd] = std::move(endpoints.first);
        socket_pair_endpoints_[*write_fd] = std::move(endpoints.second);
        output_.write("[network] pipe pid=" + std::to_string(process_.pid) +
                      " pair=" + std::to_string(pair) +
                      " fds=" + std::to_string(*read_fd) + "," +
                      std::to_string(*write_fd) + "\n");
        bsd_success(cpu, *read_fd, *write_fd);
        return;
    }
    case darwin::syscall::memory_synchronize: {
        const auto address = registers[0];
        const auto size = registers[1];
        const auto flags = registers[2];
        constexpr auto sync_modes = darwin::memory_sync_flag::asynchronous |
                                    darwin::memory_sync_flag::synchronous;
        if (address % AddressSpace::page_size != 0 || size == 0 ||
            (flags & sync_modes) == sync_modes) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        // Reclamation and invalidation need a pager policy. Report an ordinary
        // unsupported operation until that policy exists, rather than claiming
        // those effects or routing a recognized syscall through nosys/SIGSYS.
        constexpr auto pager_flags = darwin::memory_sync_flag::invalidate |
                                     darwin::memory_sync_flag::kill_pages |
                                     darwin::memory_sync_flag::deactivate;
        if ((flags & pager_flags) != 0) {
            bsd_error(cpu, darwin::error::operation_not_supported);
            return;
        }
        const auto result = memory_.synchronize_file_mappings(address, size,
            (flags & darwin::memory_sync_flag::asynchronous) == 0);
        switch (result) {
        case AddressSpace::FileSyncResult::Success:
            bsd_success(cpu, 0);
            break;
        case AddressSpace::FileSyncResult::Unmapped:
            bsd_error(cpu, darwin::error::no_memory);
            break;
        case AddressSpace::FileSyncResult::IoError:
            bsd_error(cpu, darwin::error::io);
            break;
        }
        return;
    }
    case 73: // munmap
        if (registers[1] == 0 ||
            !unmap_memory(cpu, registers[0], registers[1])) {
            bsd_error(cpu, bsd_support::invalid_argument);
        } else {
            bsd_success(cpu, 0);
        }
        return;
    case darwin::syscall::get_descriptor_table_size:
        bsd_success(cpu, file_descriptor_limit());
        return;
    case darwin::syscall::file_descriptor_path_configuration: {
        const auto fd = registers[0];
        const auto virtual_descriptor = virtual_descriptors_.find(fd);
        const auto valid = fd <= 2 || file_descriptors_.contains(fd) ||
                           virtual_descriptor != virtual_descriptors_.end() ||
                           duplicated_descriptors_.contains(fd);
        if (!valid) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto terminal =
            fd <= 2 ||
            (virtual_descriptor != virtual_descriptors_.end() &&
                (virtual_descriptor->second == "console" ||
                    virtual_descriptor->second ==
                        bsd::baseband_device::descriptor_kind ||
                    virtual_descriptor->second ==
                        bsd::offline_serial_device::descriptor_kind));
        if (terminal &&
            registers[1] ==
                darwin::path_configuration::disabled_control_character) {
            bsd_success(cpu,
                darwin::path_configuration::disabled_control_character_value);
        } else {
            bsd_error(cpu, bsd_support::invalid_argument);
        }
        return;
    }
    case darwin::syscall::duplicate_to: {
        const auto source = registers[0];
        const auto destination = registers[1];
        if (reject_guarded_descriptor(cpu, source, DarwinFileGuard::duplicate) ||
            (source != destination && reject_guarded_descriptor(cpu, destination, DarwinFileGuard::close)))
            return;
        const bool valid = source <= 2 || file_descriptors_.contains(source) ||
                           virtual_descriptors_.contains(source) ||
                           duplicated_descriptors_.contains(source);
        if (!valid || destination >= file_descriptor_limit()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (source == destination) {
            bsd_success(cpu, destination);
            return;
        }
        // XNU attaches descriptor filters to an fd-table entry. Replacing the
        // destination closes that entry and detaches every associated knote.
        static_cast<void>(release_file_descriptor(destination));
        if (const auto file = file_descriptors_.find(source);
            file != file_descriptors_.end()) {
            file_descriptors_[destination] = file->second;
            file_offsets_[destination] = file_offsets_[source];
            file_status_flags_[destination] = file_status_flags_[source];
            if (const auto description =
                    regular_file_open_descriptions_.find(source);
                description != regular_file_open_descriptions_.end()) {
                regular_file_open_descriptions_[destination] =
                    description->second;
            }
            if (const auto block = virtual_block_descriptors_.find(source);
                block != virtual_block_descriptors_.end()) {
                virtual_block_descriptors_[destination] = block->second;
            }
        } else if (const auto device = virtual_descriptors_.find(source);
            device != virtual_descriptors_.end()) {
            virtual_descriptors_[destination] = device->second;
            if (const auto offset = file_offsets_.find(source);
                offset != file_offsets_.end()) {
                file_offsets_[destination] = offset->second;
            }
            if (const auto host = host_sockets_.find(source);
                host != host_sockets_.end()) {
                host_sockets_[destination] = host->second;
            }
            if (const auto socket = virtual_udp_sockets_.find(source);
                socket != virtual_udp_sockets_.end()) {
                virtual_udp_sockets_[destination] = socket->second;
            }
            if (const auto control = kernel_control_endpoints_.find(source);
                control != kernel_control_endpoints_.end()) {
                kernel_control_endpoints_[destination] = control->second;
            }
            if (const auto flags = file_status_flags_.find(source);
                flags != file_status_flags_.end()) {
                file_status_flags_[destination] = flags->second;
            }
            if (const auto options = socket_options_.find(source);
                options != socket_options_.end()) {
                socket_options_[destination] = options->second;
            }
            if (const auto bound = bound_socket_names_.find(source);
                bound != bound_socket_names_.end()) {
                bound_socket_names_[destination] = bound->second;
            }
            if (listening_sockets_.contains(source)) {
                listening_sockets_.insert(destination);
            }
            if (const auto endpoint = socket_pair_endpoints_.find(source);
                endpoint != socket_pair_endpoints_.end()) {
                socket_pair_endpoints_[destination] = endpoint->second;
            }
            if (const auto listener = unix_listener_states_.find(source);
                listener != unix_listener_states_.end()) {
                unix_listener_states_[destination] = listener->second;
            }
            if (const auto filter = system_event_filters_.find(source);
                filter != system_event_filters_.end()) {
                system_event_filters_[destination] = filter->second;
            }
            if (const auto cursor = system_event_next_identifiers_.find(source);
                cursor != system_event_next_identifiers_.end()) {
                system_event_next_identifiers_[destination] = cursor->second;
            }
            if (const auto state = route_socket_states_.find(source);
                state != route_socket_states_.end()) {
                route_socket_states_[destination] = state->second;
            }
            if (const auto bpf = bpf_descriptors_.find(source);
                bpf != bpf_descriptors_.end()) {
                bpf_descriptors_[destination] = bpf->second;
            }
            if (const auto event_stream =
                    wifi_driver_event_streams_.find(source);
                event_stream != wifi_driver_event_streams_.end()) {
                wifi_driver_event_streams_[destination] = event_stream->second;
            }
        } else {
            duplicated_descriptors_[destination] =
                duplicated_descriptors_.contains(source)
                    ? duplicated_descriptors_.at(source)
                    : source;
        }
        if (const auto baseband = baseband_open_description(source)) {
            baseband_open_descriptions_[destination] = baseband;
            virtual_descriptors_[destination] =
                bsd::baseband_device::descriptor_kind;
            file_status_flags_[destination] =
                file_status_flags_.contains(source)
                    ? file_status_flags_.at(source)
                    : darwin::open_flag::read_write;
            duplicated_descriptors_.erase(destination);
        }
        copy_kqueue_descriptor_state(source, destination);
        bsd_success(cpu, destination);
        return;
    }
    case darwin::syscall::fcntl: {
        const auto fd = registers[0];
        const bool valid = fd <= 2 || file_descriptors_.contains(fd) ||
                           virtual_descriptors_.contains(fd) ||
                           duplicated_descriptors_.contains(fd);
        if (!valid) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (dispatch_bsd_record_locking(cpu, registers[1]))
            return;
        switch (registers[1]) {
        case darwin::fcntl_command::get_descriptor_flags:
            bsd_success(cpu, descriptor_flags_[fd]);
            return;
        case darwin::fcntl_command::set_descriptor_flags:
            if ((registers[2] & 1U) == 0U &&
                reject_guarded_descriptor(cpu, fd, DarwinFileGuard::duplicate))
                return;
            descriptor_flags_[fd] = registers[2] & 1U; // FD_CLOEXEC
            bsd_success(cpu, 0);
            return;
        case darwin::fcntl_command::get_status_flags:
            bsd_success(
                cpu, file_status_flags_.contains(fd)
                         ? file_status_flags_.at(fd)
                         : (virtual_descriptors_.contains(fd) ? 2U : 0U));
            return;
        case darwin::fcntl_command::set_status_flags:
            if (file_status_flags_.contains(fd)) {
                constexpr std::uint32_t mutable_status_flags =
                    darwin::open_flag::append | darwin::open_flag::non_block;
                file_status_flags_[fd] =
                    (file_status_flags_[fd] & ~mutable_status_flags) |
                    (registers[2] & mutable_status_flags);
            }
            bsd_success(cpu, 0);
            return;
        case darwin::fcntl_command::get_protection_class:
            // The host-backed volume is not encrypted and does not expose
            // Darwin data-protection metadata. Returning the unprotected
            // class keeps read-only callers, such as NSData's mapped-file
            // path, on the normal mmap flow.
            bsd_success(cpu, 0);
            return;
        case darwin::fcntl_command::set_read_ahead:
        case darwin::fcntl_command::set_no_cache:
            // Host page-cache policy is deliberately not projected into guest
            // semantics. Both commands are advisory and have no visible
            // file-data effect, so accepting the requested Boolean policy is
            // sufficient.
            bsd_success(cpu, 0);
            return;
        case darwin::fcntl_command::add_detached_signatures:
            // F_ADDSIGS lets dyld attach a detached code-signature blob to a
            // vnode before validating mmap'ed pages. Shade does not model
            // AMFI/code-signing enforcement, but the kernel ABI still needs to
            // accept a readable fsignatures_t registration record so dyld can
            // continue loading images.
            if (registers[2] == 0 ||
                !memory_.accessible(registers[2], 16, MemoryPermission::Read)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        case darwin::fcntl_command::add_file_signatures:
            // F_ADDFILESIGS is the corresponding path for a signature stored
            // in the file itself. iOS 4 dyld uses it for the shared cache
            // before issuing shared_region_map_file(). Code-signing
            // enforcement is intentionally outside this compatibility layer;
            // accept the ABI record so the cache can be mapped by the normal
            // shared-region implementation.
            if (registers[2] == 0 ||
                !memory_.accessible(registers[2], 16, MemoryPermission::Read)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        case darwin::fcntl_command::get_path: {
            auto descriptor = fd;
            if (const auto duplicate = duplicated_descriptors_.find(descriptor);
                duplicate != duplicated_descriptors_.end()) {
                descriptor = duplicate->second;
            }
            const auto file = file_descriptors_.find(descriptor);
            if (file == file_descriptors_.end() || rootfs_.empty()) {
                bsd_error(cpu, bsd_support::bad_file_descriptor);
                return;
            }
            const auto root = rootfs_.lexically_normal();
            const auto host = file->second.lexically_normal();
            std::string guest_path;
            if (host == root) {
                guest_path = "/";
            } else {
                const auto relative = host.lexically_relative(root);
                if (relative.empty() || relative == "." ||
                    *relative.begin() == "..") {
                    bsd_error(cpu, darwin::error::no_entry);
                    return;
                }
                guest_path = "/" + relative.generic_string();
            }
            std::vector<std::byte> bytes(guest_path.size() + 1U);
            std::transform(guest_path.begin(), guest_path.end(), bytes.begin(),
                [](char character) {
                    return static_cast<std::byte>(character);
                });
            if (!memory_.copy_in(registers[2], bytes)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, 0);
            return;
        }
        default:
            output_.write(
                "[vfs] unsupported fcntl pid=" + std::to_string(process_.pid) +
                " fd=" + std::to_string(fd) +
                " command=" + std::to_string(registers[1]) + "\n");
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
    }
    case darwin::syscall::memory_protect: { // mprotect
        const auto address = registers[0];
        const auto size = registers[1];
        const auto protection = registers[2];
        if ((address & (AddressSpace::page_size - 1U)) != 0 ||
            (size != 0 &&
                size - 1U >
                    std::numeric_limits<std::uint32_t>::max() - address) ||
            (protection & ~7U) != 0) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        if (size == 0) {
            // XNU passes a zero-length request through mach_vm_protect,
            // which returns KERN_SUCCESS without touching the address space.
            bsd_success(cpu, 0);
            return;
        }
        MemoryPermission permissions = MemoryPermission::None;
        if ((protection & 1U) != 0)
            permissions |= MemoryPermission::Read;
        if ((protection & 2U) != 0)
            permissions |= MemoryPermission::Write;
        if ((protection & 4U) != 0)
            permissions |= MemoryPermission::Execute;
        if (!protect_memory(cpu, address, size, permissions)) {
            bsd_error(cpu, darwin::error::no_memory);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::memory_advise: { // madvise
        const auto address = registers[0];
        const auto size = registers[1];
        const auto advice = registers[2];
        if (advice > darwin::memory_advice::can_reuse) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        if (size != 0 && !memory_.mapped(address, size)) {
            bsd_error(cpu, darwin::error::no_memory);
            return;
        }
        // XNU's madvise contract is advisory. Keeping resident data is a valid
        // conservative implementation for every supported behavior, including
        // MADV_FREE: its contents may be discarded under pressure, but need not
        // be discarded immediately and the mapping must remain intact.
        bsd_success(cpu, 0);
        return;
    }
    case 197: { // mmap
        auto address = registers[0];
        const auto size = registers[1];
        const auto protection = registers[2];
        const auto flags = registers[3];
        const auto fd = registers[4];
        const auto offset = static_cast<std::uint64_t>(registers[5]) |
                            (static_cast<std::uint64_t>(registers[6]) << 32U);
        if (size == 0) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto mapped_size_64 =
            (static_cast<std::uint64_t>(size) + AddressSpace::page_size - 1U) &
            ~(static_cast<std::uint64_t>(AddressSpace::page_size) - 1U);
        if (mapped_size_64 > std::numeric_limits<std::uint32_t>::max()) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto mapped_size = static_cast<std::uint32_t>(mapped_size_64);
        constexpr auto address_space_end = std::uint64_t { 1 } << 32U;
        const auto overlaps = [&](std::uint32_t candidate) {
            const auto end =
                static_cast<std::uint64_t>(candidate) + mapped_size;
            if (end > address_space_end) {
                return true;
            }
            const auto region = memory_.mapping_region_at_or_after(candidate);
            return region && static_cast<std::uint64_t>(region->address) < end;
        };
        if ((flags & darwin::map_flag::fixed) == 0) {
            if (address == 0 || overlaps(address)) {
                std::uint64_t candidate = 0x10000000U;
                bool found = false;
                while (candidate + mapped_size <= address_space_end) {
                    const auto region = memory_.mapping_region_at_or_after(
                        static_cast<std::uint32_t>(candidate));
                    const auto end = candidate + mapped_size;
                    if (!region ||
                        static_cast<std::uint64_t>(region->address) >= end) {
                        address = static_cast<std::uint32_t>(candidate);
                        found = true;
                        break;
                    }
                    candidate =
                        (region->end + AddressSpace::page_size - 1U) &
                        ~(static_cast<std::uint64_t>(AddressSpace::page_size) -
                            1U);
                }
                if (!found) {
                    bsd_error(cpu, darwin::error::no_memory);
                    return;
                }
            }
        } else {
            if (static_cast<std::uint64_t>(address) + mapped_size >
                address_space_end) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            unmap_memory(cpu, address, mapped_size);
        }
        MemoryPermission permissions = MemoryPermission::None;
        if ((protection & 1U) != 0)
            permissions |= MemoryPermission::Read;
        if ((protection & 2U) != 0)
            permissions |= MemoryPermission::Write;
        if ((protection & 4U) != 0)
            permissions |= MemoryPermission::Execute;
        if ((flags & darwin::map_flag::anonymous) == 0) {
            const auto found = file_descriptors_.find(fd);
            if (found == file_descriptors_.end()) {
                bsd_error(cpu, bsd_support::bad_file_descriptor);
                return;
            }
            if ((flags & darwin::map_flag::shared) != 0 &&
                has_permission(permissions, MemoryPermission::Write)) {
                const auto descriptor_flags =
                    file_status_flags_.contains(fd)
                        ? file_status_flags_.at(fd)
                        : darwin::open_flag::read_only;
                if ((descriptor_flags & darwin::open_flag::access_mode) ==
                    darwin::open_flag::read_only) {
                    bsd_error(cpu, darwin::error::permission_denied);
                    return;
                }
            }
            if ((flags & darwin::map_flag::shared) != 0) {
                auto pages =
                    shared_state_->shared_mapping_page_cache->load_pages(
                        found->second, offset, size);
                if (!pages) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                for (const auto& page : *pages)
                    page->materialize();
                AddressSpace::PageMappingMode mapping_mode =
                    AddressSpace::PageMappingMode::SharedFile;
                {
                    const std::lock_guard filesystem_lock {
                        shared_state_->filesystem_mutex
                    };
                    if (shared_state_->volatile_shared_memory_backings.contains(
                            found->second)) {
                        mapping_mode = AddressSpace::PageMappingMode::Shared;
                    }
                }
                if (!memory_.map_page_backings(address, mapped_size,
                        permissions, *pages, mapping_mode)) {
                    bsd_error(cpu, darwin::error::no_memory);
                    return;
                }
            } else {
                // MAP_PRIVATE file pages already have a lazy copy-on-write
                // backing in AddressSpace. Reuse it instead of treating mmap
                // length as a single read(2) buffer; valid mappings may be much
                // larger than maximum_io.
                if (!memory_.map_file(address, mapped_size, permissions,
                        found->second, offset)) {
                    bsd_error(cpu, darwin::error::no_memory);
                    return;
                }
            }
            static_cast<void>(install_mapped_user_image(
                cpu, found->second, address, size, offset));
            if (mapping_trace_count_ < 64U) {
                output_.write("[mmap] pid=" + std::to_string(process_.pid) +
                              " address=" + std::to_string(address) +
                              " size=" + std::to_string(size) +
                              " offset=" + std::to_string(offset) +
                              " prot=" + std::to_string(protection) +
                              " flags=" + std::to_string(flags) +
                              " file=" + found->second.string() + "\n");
                ++mapping_trace_count_;
            }
        } else {
            if (!memory_.map(address, mapped_size, permissions)) {
                bsd_error(cpu, darwin::error::no_memory);
                return;
            }
            if (mapping_trace_count_ < 64U) {
                output_.write(
                    "[mmap] pid=" + std::to_string(process_.pid) + " address=" +
                    std::to_string(address) + " size=" + std::to_string(size) +
                    " offset=" + std::to_string(offset) +
                    " prot=" + std::to_string(protection) +
                    " flags=" + std::to_string(flags) + " anonymous\n");
                ++mapping_trace_count_;
            }
        }
        bsd_success(cpu, address);
        return;
    }
    case 266: { // shm_open
        const auto name = memory_.read_c_string(registers[0], 256);
        if (!name) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        auto object_name = *name;
        if (!object_name.empty() && object_name.front() == '/') {
            object_name.erase(object_name.begin());
        }
        // Darwin 8's own notifyd uses "apple.shm.notification_center"
        // without the POSIX-leading slash, so accept both spellings while
        // still rejecting path traversal and hierarchical names.
        if (object_name.empty() || object_name.find('/') != std::string::npos) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        constexpr std::uint32_t o_creat = 0x0200U;
        constexpr std::uint32_t o_trunc = 0x0400U;
        constexpr std::uint32_t o_excl = 0x0800U;
        const auto seed_capabilities = object_name ==
                graphics_services_capability_object_name &&
            (registers[1] & o_creat) == 0 &&
            !shared_state_->graphics_services_capability_memory.empty();
        std::filesystem::path backing;
        bool created = false;
        {
            std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
            const auto existing =
                shared_state_->shared_memory_objects.find(object_name);
            if (existing != shared_state_->shared_memory_objects.end()) {
                if ((registers[1] & (o_creat | o_excl)) == (o_creat | o_excl)) {
                    bsd_error(cpu, 17); // EEXIST
                    return;
                }
                backing = existing->second;
            } else {
                if (((registers[1] & o_creat) == 0 && !seed_capabilities) ||
                    rootfs_.empty()) {
                    bsd_error(cpu, 2); // ENOENT
                    return;
                }
                const auto directory =
                    rootfs_.parent_path() / "runtime" / "shm";
                std::error_code error;
                std::filesystem::create_directories(directory, error);
                if (error) {
                    bsd_error(
                        cpu, error == std::errc::permission_denied ? 13U : 5U);
                    return;
                }
                backing = directory /
                          (std::to_string(
                               shared_state_->next_shared_memory_object++) +
                              ".shm");
                std::ofstream create { backing,
                    std::ios::binary | std::ios::trunc };
                if (!create ||
                    (seed_capabilities &&
                        !create.write(
                            reinterpret_cast<const char*>(
                                shared_state_->graphics_services_capability_memory
                                    .data()),
                            static_cast<std::streamsize>(
                                shared_state_->graphics_services_capability_memory
                                    .size())))) {
                    bsd_error(cpu, 5); // EIO
                    return;
                }
                shared_state_->shared_memory_objects.emplace(
                    object_name, backing);
                shared_state_->volatile_shared_memory_backings.insert(backing);
                created = true;
            }
        }
        if (!created && (registers[1] & o_trunc) != 0) {
            std::error_code error;
            std::filesystem::resize_file(backing, 0, error);
            if (error) {
                bsd_error(cpu, 5);
                return;
            }
        }
        const auto fd = allocate_file_descriptor();
        if (!fd) {
            bsd_error(cpu, 24); // EMFILE
            return;
        }
        file_descriptors_[*fd] = backing;
        file_offsets_[*fd] = 0;
        file_status_flags_[*fd] = registers[1];
        descriptor_flags_[*fd] = 0;
        static_cast<void>(ensure_regular_file_open_description(*fd));
        output_.write("[vfs] shm_open " + object_name +
                      " fd=" + std::to_string(*fd) + "\n");
        bsd_success(cpu, *fd);
        return;
    }
    case 267: { // shm_unlink
        const auto name = memory_.read_c_string(registers[0], 256);
        if (!name) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        auto object_name = *name;
        if (!object_name.empty() && object_name.front() == '/') {
            object_name.erase(object_name.begin());
        }
        if (object_name.empty() || object_name.find('/') != std::string::npos) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        bool erased = false;
        {
            std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
            erased =
                shared_state_->shared_memory_objects.erase(object_name) != 0;
        }
        if (!erased) {
            bsd_error(cpu, 2); // ENOENT
            return;
        }
        // Keep the backing inode until process teardown so descriptors and
        // mappings opened before unlink remain valid, as POSIX requires.
        output_.write("[vfs] shm_unlink " + object_name + "\n");
        bsd_success(cpu, 0);
        return;
    }
    default:
        trace_unknown(cpu, "BSD syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }
}

} // namespace shade
