// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest asynchronous file I/O requests and completion
// queries.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_aio.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <algorithm>
#include <bit>
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

#include <sys/stat.h>
#include <unistd.h>

#include "support.hpp"

namespace shade {
namespace {

    enum class AioOperation {
        Synchronize,
        Read,
        Write,
    };

    struct GuestAioControlBlock {
        std::uint32_t descriptor { };
        std::int64_t offset { };
        std::uint32_t buffer { };
        std::uint32_t byte_count { };
        std::uint32_t notification { };
        std::uint32_t signal { };
    };

    std::optional<GuestAioControlBlock> read_aio_control_block(
        const AddressSpace& memory, std::uint32_t address)
    {
        using namespace darwin::aio;
        const auto bytes = memory.read_bytes(address, control_block_size);
        if (!bytes) {
            return std::nullopt;
        }
        const auto read32 = [&](std::size_t offset) {
            std::uint32_t value { };
            for (std::size_t index = 0; index < sizeof(value); ++index) {
                value |=
                    static_cast<std::uint32_t>(
                        std::to_integer<std::uint8_t>((*bytes)[offset + index]))
                    << (index * 8U);
            }
            return value;
        };
        const auto read64 = [&](std::size_t offset) {
            std::uint64_t value { };
            for (std::size_t index = 0; index < sizeof(value); ++index) {
                value |=
                    static_cast<std::uint64_t>(
                        std::to_integer<std::uint8_t>((*bytes)[offset + index]))
                    << (index * 8U);
            }
            return value;
        };
        return GuestAioControlBlock { read32(descriptor_offset),
            std::bit_cast<std::int64_t>(read64(file_offset_offset)),
            read32(buffer_offset), read32(byte_count_offset),
            read32(notification_offset), read32(signal_offset) };
    }

    std::string_view operation_name(AioOperation operation)
    {
        switch (operation) {
        case AioOperation::Synchronize:
            return "fsync";
        case AioOperation::Read:
            return "read";
        case AioOperation::Write:
            return "write";
        }
        return "unknown";
    }

} // namespace

void CompatibilityKernel::dispatch_bsd_aio(Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();

    const auto resolve_descriptor = [&](std::uint32_t descriptor) {
        for (unsigned depth = 0; depth < 256; ++depth) {
            const auto duplicate = duplicated_descriptors_.find(descriptor);
            if (duplicate == duplicated_descriptors_.end())
                break;
            descriptor = duplicate->second;
        }
        return descriptor;
    };

    const auto submit = [&](std::uint32_t control_block_address,
                            AioOperation operation) {
        if (control_block_address == 0 ||
            aio_completions_.contains(control_block_address)) {
            bsd_error(cpu, darwin::error::would_block);
            return;
        }
        if (aio_completions_.size() >=
            darwin::aio::maximum_requests_per_process) {
            bsd_error(cpu, darwin::error::would_block);
            return;
        }
        const auto control_block =
            read_aio_control_block(memory_, control_block_address);
        if (!control_block) {
            // XNU reports an aiocb copyin failure as EAGAIN at queue time.
            bsd_error(cpu, darwin::error::would_block);
            return;
        }
        if (operation != AioOperation::Synchronize &&
            (control_block->offset < 0 || control_block->buffer == 0 ||
                control_block->byte_count >
                    static_cast<std::uint32_t>(bsd_support::maximum_io))) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        if (control_block->notification != darwin::aio::notify_none &&
            (control_block->notification != darwin::aio::notify_signal ||
                control_block->signal == 0 ||
                control_block->signal >= darwin::signal::count ||
                control_block->signal == darwin::signal::kill ||
                control_block->signal == darwin::signal::stop)) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }

        const auto descriptor = resolve_descriptor(control_block->descriptor);
        if (!file_descriptors_.contains(descriptor)) {
            const auto valid_non_file =
                virtual_descriptors_.contains(descriptor) ||
                host_sockets_.contains(descriptor) ||
                virtual_udp_sockets_.contains(descriptor);
            bsd_error(cpu, valid_non_file ? darwin::error::illegal_seek
                                          : darwin::error::bad_file_descriptor);
            return;
        }
        const auto flags = file_status_flags_.contains(descriptor)
                               ? file_status_flags_.at(descriptor)
                               : darwin::open_flag::read_only;
        const auto access = flags & darwin::open_flag::access_mode;
        const auto needs_write = operation != AioOperation::Read;
        if ((needs_write && access == darwin::open_flag::read_only) ||
            (!needs_write && access == darwin::open_flag::write_only)) {
            bsd_error(cpu, darwin::error::bad_file_descriptor);
            return;
        }
        const auto description =
            ensure_regular_file_open_description(descriptor);
        if (!description) {
            bsd_error(cpu, darwin::error::bad_file_descriptor);
            return;
        }

        AioCompletion completion { control_block->descriptor, -1, 0 };
        if (operation == AioOperation::Synchronize) {
            std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
            if (::fsync(description->host_descriptor()) == 0) {
                completion.result = 0;
            } else {
                completion.error = bsd_support::darwin_filesystem_error(
                    std::error_code { errno, std::generic_category() });
            }
        } else if (operation == AioOperation::Write) {
            const auto bytes = memory_.read_bytes(
                control_block->buffer, control_block->byte_count);
            if (!bytes) {
                completion.error = darwin::error::bad_address;
            } else {
                std::lock_guard filesystem_lock {
                    shared_state_->filesystem_mutex
                };
                std::uint64_t position =
                    static_cast<std::uint64_t>(control_block->offset);
                if ((flags & darwin::open_flag::append) != 0) {
                    struct stat status { };
                    if (::fstat(description->host_descriptor(), &status) != 0) {
                        completion.error = bsd_support::darwin_filesystem_error(
                            std::error_code { errno, std::generic_category() });
                    } else {
                        position = static_cast<std::uint64_t>(status.st_size);
                    }
                }
                if (completion.error == 0) {
                    const auto result =
                        ::pwrite(description->host_descriptor(), bytes->data(),
                            bytes->size(), static_cast<off_t>(position));
                    if (result < 0) {
                        completion.error = bsd_support::darwin_filesystem_error(
                            std::error_code { errno, std::generic_category() });
                    } else {
                        completion.result = static_cast<std::int32_t>(result);
                        static_cast<void>(
                            shared_state_->shared_mapping_page_cache
                                ->reflect_descriptor_write(
                                    description->host_descriptor(), position,
                                    std::span<const std::byte> { bytes->data(),
                                        static_cast<std::size_t>(result) }));
                        static_cast<void>(
                            shared_state_->guest_file_generation_registry
                                ->publish_descriptor(
                                    file_descriptors_.at(descriptor),
                                    description->host_descriptor(),
                                    GuestFileMutationKind::Write));
                    }
                }
            }
        } else {
            std::vector<std::byte> bytes(control_block->byte_count);
            const auto result =
                ::pread(description->host_descriptor(), bytes.data(),
                    bytes.size(), static_cast<off_t>(control_block->offset));
            if (result < 0) {
                completion.error = bsd_support::darwin_filesystem_error(
                    std::error_code { errno, std::generic_category() });
            } else {
                bytes.resize(static_cast<std::size_t>(result));
                if (!memory_.copy_in(control_block->buffer, bytes)) {
                    completion.error = darwin::error::bad_address;
                } else {
                    completion.result = static_cast<std::int32_t>(result);
                }
            }
        }

        aio_completions_[control_block_address] = completion;
        if (completion.error != 0) {
            output_.write(
                "[aio] " + std::string { operation_name(operation) } +
                " pid=" + std::to_string(process_.pid) +
                " fd=" + std::to_string(control_block->descriptor) +
                " bytes=" + std::to_string(control_block->byte_count) +
                " error=" + std::to_string(completion.error) + "\n");
        }
        bsd_success(cpu, 0);

        if (control_block->notification == darwin::aio::notify_signal) {
            static_cast<void>(deliver_signal(control_block->signal));
            if (process_.exited) {
                cpu.halt(Umbra::HaltReason::UserDefined1);
            }
        }
    };

    switch (number) {
    case darwin::syscall::aio_synchronize: {
        const auto operation = registers[0];
        if (operation != 0 && operation != darwin::aio::synchronize) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        submit(registers[1], AioOperation::Synchronize);
        return;
    }
    case darwin::syscall::aio_read:
        submit(registers[0], AioOperation::Read);
        return;
    case darwin::syscall::aio_write:
        submit(registers[0], AioOperation::Write);
        return;
    case darwin::syscall::aio_error: {
        const auto completion = aio_completions_.find(registers[0]);
        if (completion == aio_completions_.end()) {
            bsd_error(cpu, darwin::error::invalid_argument);
        } else {
            bsd_success(cpu, completion->second.error);
        }
        return;
    }
    case darwin::syscall::aio_return: {
        const auto completion = aio_completions_.find(registers[0]);
        if (completion == aio_completions_.end()) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        const auto result = completion->second.result;
        aio_completions_.erase(completion);
        bsd_success(cpu, static_cast<std::uint32_t>(result));
        return;
    }
    case darwin::syscall::aio_cancel: {
        const auto requested_descriptor = registers[0];
        const auto requested_control_block = registers[1];
        const auto completion = std::find_if(aio_completions_.begin(),
            aio_completions_.end(), [&](const auto& candidate) {
                return (requested_control_block == 0 ||
                           candidate.first == requested_control_block) &&
                       candidate.second.descriptor == requested_descriptor;
            });
        if (completion == aio_completions_.end()) {
            bsd_error(cpu, darwin::error::bad_file_descriptor);
        } else {
            bsd_success(cpu, darwin::aio::all_done);
        }
        return;
    }
    case darwin::syscall::aio_suspend: {
        const auto list_address = registers[0];
        const auto count = static_cast<std::int32_t>(registers[1]);
        if (count < 1 ||
            count > static_cast<std::int32_t>(
                        darwin::aio::maximum_requests_per_process) ||
            list_address == 0 || aio_completions_.empty()) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        constexpr std::uint32_t guest_pointer_size = sizeof(std::uint32_t);
        for (std::int32_t index = 0; index < count; ++index) {
            const auto control_block = memory_.read32(
                list_address +
                static_cast<std::uint32_t>(index) * guest_pointer_size);
            if (!control_block) {
                bsd_error(cpu, darwin::error::would_block);
                return;
            }
            if (*control_block != 0 &&
                aio_completions_.contains(*control_block)) {
                bsd_success(cpu, 0);
                return;
            }
        }
        // A synchronous backend cannot have a matching request still pending.
        bsd_error(cpu, darwin::error::invalid_argument);
        return;
    }
    default:
        trace_unknown(cpu, "BSD AIO syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }
}

} // namespace shade
