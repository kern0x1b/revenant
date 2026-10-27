// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest filesystem access, path and directory operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/vfs/vfs_syscalls.c

#include "kernel/kernel.hpp"

#include "kernel/baseband_device.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_bpf_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
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

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include "support.hpp"

namespace emulator {
namespace {

    constexpr std::uint32_t random_device_minor = 0;
    constexpr std::uint32_t console_device_minor = 1;
    constexpr std::uint32_t wifi_event_device_minor = 2;

    [[nodiscard]] std::optional<std::uint32_t> virtual_character_device_minor(
        std::string_view descriptor_kind)
    {
        if (descriptor_kind == "random") {
            return random_device_minor;
        }
        if (descriptor_kind == "console") {
            return console_device_minor;
        }
        if (descriptor_kind == bsd::null_device::descriptor_kind) {
            return bsd::null_device::device_minor;
        }
        if (descriptor_kind ==
            darwin::network::apple80211_driver::event_descriptor_kind) {
            return wifi_event_device_minor;
        }
        if (descriptor_kind == bsd::baseband_device::descriptor_kind) {
            return bsd::baseband_device::device_minor;
        }
        if (descriptor_kind == bsd::offline_serial_device::descriptor_kind) {
            return bsd::offline_serial_device::device_minor;
        }
        return std::nullopt;
    }

    [[nodiscard]] std::optional<std::uint32_t> virtual_character_path_minor(
        std::string_view path)
    {
        if (path == "/dev/random" || path == "/dev/urandom" ||
            path == "/dev/srandom") {
            return random_device_minor;
        }
        if (path == "/dev/console") {
            return console_device_minor;
        }
        if (bsd::null_device::is_path(path)) {
            return bsd::null_device::device_minor;
        }
        if (path == darwin::network::apple80211_driver::event_device_path) {
            return wifi_event_device_minor;
        }
        if (bsd::baseband_device::is_path(path)) {
            return bsd::baseband_device::device_minor;
        }
        if (bsd::offline_serial_device::is_path(path)) {
            return bsd::offline_serial_device::device_minor;
        }
        return std::nullopt;
    }

}

std::optional<std::filesystem::path>
CompatibilityKernel::guest_directory_of_descriptor(
    std::uint32_t descriptor, std::uint32_t& error) const
{
    if (const auto duplicate = duplicated_descriptors_.find(descriptor);
        duplicate != duplicated_descriptors_.end()) {
        descriptor = duplicate->second;
    }
    const auto found = file_descriptors_.find(descriptor);
    if (found == file_descriptors_.end()) {
        error = bsd_support::bad_file_descriptor;
        return std::nullopt;
    }
    std::error_code failure;
    if (!std::filesystem::is_directory(found->second, failure)) {
        error = failure ? 2U : 20U;
        return std::nullopt;
    }
    const auto relative = found->second.lexically_relative(rootfs_);
    if (relative.empty() &&
        found->second.lexically_normal() != rootfs_.lexically_normal()) {
        error = 2;
        return std::nullopt;
    }
    return (std::filesystem::path { "/" } / relative).lexically_normal();
}

bool CompatibilityKernel::dispatch_bsd_thread_directory(
    Cpu& cpu, std::uint32_t number)
{
    if (number != 348 && number != 349)
        return false;
    auto& registers = cpu.registers();
    const auto thread = current_thread_object();
    const bool clears = number == 349 ? static_cast<std::int32_t>(registers[0]) == -1
                                      : registers[0] == 0;
    if (clears) {
        bool cleared = false;
        if (thread) {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            if (const auto found =
                    shared_state_->thread_working_directories.find(*thread);
                found != shared_state_->thread_working_directories.end()) {
                if (found->second.host_descriptor >= 0)
                    close(found->second.host_descriptor);
                shared_state_->thread_working_directories.erase(found);
                cleared = true;
            }
        }
        if (cleared) {
            bsd_success(cpu, 0);
        } else {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
        }
        return true;
    }

    std::filesystem::path guest;
    std::filesystem::path host;
    if (number == 348) {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        host = resolve_guest_path(*path);
        std::error_code failure;
        if (!std::filesystem::exists(host, failure)) {
            bsd_error(cpu, 2);
            return true;
        }
        if (!std::filesystem::is_directory(host, failure)) {
            bsd_error(cpu, 20);
            return true;
        }
        const std::filesystem::path given { *path };
        guest = (given.is_absolute() ? given : working_directory() / given)
                    .lexically_normal();
    } else {
        std::uint32_t error = 0;
        const auto directory =
            guest_directory_of_descriptor(registers[0], error);
        if (!directory) {
            bsd_error(cpu, error);
            return true;
        }
        guest = *directory;
        host = resolve_guest_path(guest.string());
    }
    if (!thread) {
        bsd_error(cpu, 2);
        return true;
    }
    const int descriptor = open(host.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (descriptor == -1) {
        bsd_error(cpu, 2);
        return true;
    }
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        auto& pinned = shared_state_->thread_working_directories[*thread];
        if (pinned.host_descriptor >= 0)
            close(pinned.host_descriptor);
        pinned = {guest, descriptor};
    }
    bsd_success(cpu, 0);
    return true;
}

void CompatibilityKernel::append_directory_entries(
    const std::filesystem::path& directory,
    std::vector<DirectoryEntry>& entries,
    std::error_code& directory_error) const
{
    for (std::filesystem::directory_iterator iterator { directory,
             directory_error },
        end;
        !directory_error && iterator != end;
        iterator.increment(directory_error)) {
        if (hfs::MetadataProvider::is_resource_sidecar(iterator->path())) {
            continue;
        }
        const auto status = iterator->symlink_status(directory_error);
        if (directory_error)
            break;
        const auto metadata = query_hfs_metadata(iterator->path(), false, false);
        if (!metadata) {
            directory_error = std::make_error_code(std::errc::io_error);
            break;
        }
        std::uint8_t type = 0;
        if (std::filesystem::is_directory(status))
            type = 4;
        else if (std::filesystem::is_regular_file(status))
            type = 8;
        else if (std::filesystem::is_symlink(status))
            type = 10;
        entries.push_back({ iterator->path().filename().string(), type,
            metadata->catalog_id });
    }
}

void CompatibilityKernel::dispatch_bsd_filesystem(
    Cpu& cpu, std::uint32_t number)
{
    if (dispatch_bsd_filesystem_control(cpu, number)) {
        return;
    }
    if (dispatch_bsd_filesystem_persistence(cpu, number)) {
        return;
    }
    if (dispatch_bsd_filesystem_timestamps(cpu, number)) {
        return;
    }
    if (dispatch_bsd_filesystem_locking(cpu, number)) {
        return;
    }
    if (dispatch_bsd_filesystem_ownership(cpu, number)) {
        return;
    }
    auto& registers = cpu.registers();
    const auto volume_for_descriptor_path =
        [&](const auto& host_path) -> const hfs::VolumeMetadata& {
        const auto relative = host_path.lexically_normal().lexically_relative(
            rootfs_.lexically_normal());
        if (relative.empty() &&
            host_path.lexically_normal() != rootfs_.lexically_normal()) {
            return hfs_volumes_.for_guest_path("/");
        }
        return hfs_volumes_.for_guest_path(
            (std::filesystem::path { "/" } / relative).generic_string());
    };
    const auto reject_unavailable_baseband = [&](std::string_view path) {
        if (!bsd::baseband_device::is_path(path) ||
            shared_state_->baseband_device_state.available()) {
            return false;
        }
        bsd_error(cpu, darwin::error::no_such_device_or_address);
        return true;
    };
    switch (number) {
    case 9: {
        const auto source_path = memory_.read_c_string(registers[0]);
        const auto destination_path = memory_.read_c_string(registers[1]);
        if (!source_path || !destination_path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto source = resolve_guest_path(*source_path, true);
        const auto destination = resolve_guest_path(*destination_path, false);
        std::error_code error;
        const auto status = std::filesystem::status(source, error);
        if (error || status.type() == std::filesystem::file_type::not_found) {
            bsd_error(cpu, bsd_support::darwin_filesystem_error(error, 2U));
            return;
        }
        if (std::filesystem::is_directory(status)) {
            bsd_error(cpu, 1U);
            return;
        }
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            std::filesystem::create_hard_link(source, destination, error);
            if (!error) {
                const auto source_resource =
                    hfs::MetadataProvider::resource_sidecar(source);
                const auto destination_resource =
                    hfs::MetadataProvider::resource_sidecar(destination);
                std::error_code resource_error;
                if (std::filesystem::is_regular_file(
                        source_resource, resource_error)) {
                    std::filesystem::create_hard_link(
                        source_resource, destination_resource, resource_error);
                    if (resource_error) {
                        std::filesystem::remove(destination, error);
                        error = resource_error;
                    }
                }
            }
        }
        hfs_metadata_.invalidate_xattrs();
        if (error) {
            bsd_error(cpu, bsd_support::darwin_filesystem_error(error));
            return;
        }
        output_.write(
            "[vfs] link " + *source_path + " -> " + *destination_path + "\n");
        directory_entries_cache_.clear();
        bsd_success(cpu, 0);
        return;
    }
    case 10: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        {
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            if (shared_state_->unix_socket_nodes.erase(*path) != 0) {
                shared_state_->unix_listeners.erase(*path);
                output_.write("[network] unlink " + *path + "\n");
                bsd_success(cpu, 0);
                return;
            }
        }
        std::error_code error;
        const auto host = resolve_guest_path(*path, false);
        const auto status = std::filesystem::symlink_status(host, error);
        if (error || status.type() == std::filesystem::file_type::not_found) {
            bsd_error(cpu, 2);
            return;
        }
        if (std::filesystem::is_directory(status)) {
            bsd_error(cpu, 21);
            return;
        }
        const auto metadata = query_hfs_metadata(host, false);
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            if (!hfs_metadata_.remove_name(host, error)) {
                bsd_error(cpu, bsd_support::darwin_filesystem_error(error, 2U));
                return;
            }
            std::error_code resource_error;
            static_cast<void>(hfs_metadata_.remove_name(
                hfs::MetadataProvider::resource_sidecar(host), resource_error));
            if (metadata && metadata->link_count <= 1U) {
                shared_state_->hfs_metadata_overrides.erase(
                    metadata->permanent_id);
                shared_state_->hfs_named_attribute_overrides.erase(
                    metadata->permanent_id);
            }
        }
        static_cast<void>(
            shared_state_->guest_file_generation_registry->publish(
                host, GuestFileMutationKind::Unlink));
        directory_entries_cache_.clear();
        output_.write("[vfs] unlink " + *path + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 5:
    case 216: {
        const auto flags = registers[1];
        const auto mode = number == 216U ? registers[4] : registers[2];
        constexpr std::uint32_t raw_encrypted = 1U;
        if (number == 216U && (registers[3] & raw_encrypted) != 0U &&
            (flags & darwin::open_flag::access_mode) !=
                darwin::open_flag::read_only) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (path->empty()) {
            bsd_error(cpu, darwin::error::no_entry);
            return;
        }
        if (rootfs_.empty()) {
            bsd_error(cpu, 2);
            return;
        }
        const auto host = resolve_guest_path(*path);
        std::shared_ptr<bsd::baseband_device::OpenDescription>
            baseband_description;
        output_.write("[vfs] open " + *path + "\n");
        if (reject_unavailable_baseband(*path)) {
            return;
        }
        if (bsd::baseband_device::is_mux_channel_path(*path) &&
            !shared_state_->baseband_device_state.mux_channel_path_available(
                *path)) {
            constexpr auto error = darwin::error::no_such_device_or_address;
            bsd_error(cpu, error);
            return;
        }
        if (host_network_policy_ == HostNetworkPolicy::Host &&
            (*path == "/etc/resolv.conf" || *path == "/var/run/resolv.conf")) {
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24);
                return;
            }
            virtual_descriptors_.emplace(*fd, "resolver-config");
            file_offsets_.emplace(*fd, 0);
            file_status_flags_[*fd] = flags;
            descriptor_flags_[*fd] = 0;
            bsd_success(cpu, *fd);
            return;
        }
        if (bsd::baseband_device::is_path(*path)) {
            if (!shared_state_->baseband_device_state.available()) {
                bsd_error(cpu, darwin::error::no_such_device_or_address);
                return;
            }
            baseband_description =
                shared_state_->baseband_device_state.open_description(
                    *path, process_.pid);
            if (!baseband_description) {
                bsd_error(cpu, darwin::error::device_busy);
                return;
            }
        }
        if (const auto minor = darwin::bpf::device_minor(*path)) {
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24);
                return;
            }
            virtual_descriptors_.emplace(*fd, darwin::bpf::descriptor_kind);
            auto state = std::make_shared<darwin::bpf::DescriptorState>();
            state->minor = *minor;
            bpf_descriptors_.emplace(*fd, std::move(state));
            file_status_flags_[*fd] = flags;
            descriptor_flags_[*fd] = 0;
            bsd_success(cpu, *fd);
            return;
        }
        if (*path == darwin::network::apple80211_driver::event_device_path) {
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24);
                return;
            }
            virtual_descriptors_.emplace(
                *fd, darwin::network::apple80211_driver::event_descriptor_kind);
            wifi_driver_event_streams_.emplace(
                *fd, std::make_shared<
                         darwin::network::apple80211_driver::EventStream>());
            file_status_flags_[*fd] = flags;
            descriptor_flags_[*fd] = 0;
            bsd_success(cpu, *fd);
            return;
        }
        if (*path == "/dev/random" || *path == "/dev/urandom" ||
            *path == "/dev/srandom" || *path == "/dev/console" ||
            bsd::null_device::is_path(*path) ||
            (bsd::baseband_device::is_path(*path) &&
                shared_state_->baseband_device_state.available()) ||
            bsd::offline_serial_device::is_path(*path)) {
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24);
                return;
            }
            const auto kind = *path == "/dev/console"
                                  ? std::string_view { "console" }
                              : bsd::null_device::is_path(*path)
                                  ? bsd::null_device::descriptor_kind
                              : bsd::baseband_device::is_path(*path)
                                  ? bsd::baseband_device::descriptor_kind
                              : bsd::offline_serial_device::is_path(*path)
                                  ? bsd::offline_serial_device::descriptor_kind
                                  : std::string_view { "random" };
            virtual_descriptors_.emplace(*fd, kind);
            if (baseband_description)
                baseband_open_descriptions_[*fd] =
                    std::move(baseband_description);
            file_status_flags_[*fd] = flags;
            bsd_success(cpu, *fd);
            return;
        }
        if (*path == "/dev/disk0s1" || *path == "/dev/disk0s2" ||
            *path == "/dev/rdisk0s1" || *path == "/dev/rdisk0s2") {
            const auto backing =
                rootfs_.parent_path() / "firmware" / "iphoneos-1.0-hfsx.img";
            std::error_code backing_error;
            if (!std::filesystem::is_regular_file(backing, backing_error)) {
                bsd_error(cpu, 2);
                return;
            }
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24);
                return;
            }
            file_descriptors_.emplace(*fd, backing);
            file_offsets_.emplace(*fd, 0);
            file_status_flags_[*fd] = flags;
            static_cast<void>(ensure_regular_file_open_description(*fd));
            const auto minor = path->ends_with("s1") ? 1U : 2U;
            virtual_block_descriptors_.emplace(
                *fd, std::pair { minor, path->starts_with("/dev/rdisk") });
            bsd_success(cpu, *fd);
            return;
        }
        std::error_code error;
        bool exists = false;
        bool created = false;
        {
            std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
            exists = std::filesystem::exists(host, error);
            if (error && error != std::errc::no_such_file_or_directory) {
                bsd_error(cpu, error == std::errc::permission_denied
                                   ? darwin::error::permission_denied
                                   : darwin::error::io);
                return;
            }
            error.clear();
            if (exists && (flags & (darwin::open_flag::create |
                                       darwin::open_flag::exclusive)) ==
                              (darwin::open_flag::create |
                                  darwin::open_flag::exclusive)) {
                bsd_error(cpu, darwin::error::file_exists);
                return;
            }
            if (!exists) {
                if ((flags & darwin::open_flag::create) == 0) {
                    bsd_error(cpu, darwin::error::no_entry);
                    return;
                }
                if (!std::filesystem::is_directory(host.parent_path(), error)) {
                    bsd_error(cpu, darwin::error::no_entry);
                    return;
                }
                std::ofstream create { host,
                    std::ios::binary | std::ios::trunc };
                hfs_metadata_.invalidate_xattrs();
                if (!create) {
                    bsd_error(cpu, darwin::error::io);
                    return;
                }
                exists = true;
                created = true;
                static_cast<void>(
                    shared_state_->guest_file_generation_registry->publish(
                        host, GuestFileMutationKind::InstallReplace));
                output_.write("[vfs] create " + *path + " mode=" +
                              std::to_string(mode & 07777U) + "\n");
            }
            const auto status = std::filesystem::status(host, error);
            if (error || (!std::filesystem::is_regular_file(status) &&
                             !std::filesystem::is_directory(status))) {
                bsd_error(cpu, error == std::errc::permission_denied
                                   ? darwin::error::permission_denied
                                   : darwin::error::no_entry);
                return;
            }
            const auto access = flags & darwin::open_flag::access_mode;
            if (std::filesystem::is_directory(status) &&
                access != darwin::open_flag::read_only) {
                bsd_error(cpu, darwin::error::is_directory);
                return;
            }
            if (std::filesystem::is_regular_file(status) &&
                (flags & darwin::open_flag::truncate) != 0 &&
                access != darwin::open_flag::read_only) {
                std::filesystem::resize_file(host, 0, error);
                if (error) {
                    bsd_error(cpu, darwin::error::io);
                    return;
                }
                static_cast<void>(
                    shared_state_->guest_file_generation_registry->publish(
                        host, GuestFileMutationKind::Truncate));
            }
        }
        if (created) {
            const auto timestamp =
                bsd_support::guest_filesystem_timestamp(shared_state_->clock);
            const auto metadata = hfs_metadata_.query(host, true);
            if (!metadata) {
                bsd_error(cpu, darwin::error::io);
                return;
            }
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            auto& metadata_override =
                shared_state_->hfs_metadata_overrides[metadata->permanent_id];
            metadata_override.mode =
                0100000U |
                (mode & ~process_.file_creation_mask & 07777U);
            metadata_override.owner = process_.effective_uid;
            metadata_override.group = process_.effective_gid;
            metadata_override.creation_time = timestamp;
            metadata_override.modification_time = timestamp;
            metadata_override.change_time = timestamp;
        }
        if (created)
            directory_entries_cache_.clear();
        const auto fd = allocate_file_descriptor();
        if (!fd) {
            bsd_error(cpu, 24);
            return;
        }
        file_descriptors_.emplace(*fd, host);
        file_offsets_.emplace(*fd, 0);
        file_status_flags_[*fd] = flags;
        descriptor_flags_[*fd] = 0;
        static_cast<void>(ensure_regular_file_open_description(*fd));
        bsd_success(cpu, *fd);
        return;
    }
    case 6: {
        const auto fd = registers[0];
        if (reject_guarded_descriptor(cpu, fd, DarwinFileGuard::close))
            return;
        if (!release_file_descriptor(fd)) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
        } else {
            bsd_success(cpu, 0);
        }
        return;
    }
    case 12: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto host = resolve_guest_path(*path);
        std::error_code error;
        if (!std::filesystem::is_directory(host, error)) {
            bsd_error(cpu, error ? 2U : 20U);
            return;
        }
        std::filesystem::path guest { *path };
        guest = guest.is_absolute()
                    ? guest.lexically_normal()
                    : (working_directory() / guest).lexically_normal();
        guest_working_directory_ =
            guest.empty() ? std::filesystem::path { "/" } : guest;
        output_.write(
            "[vfs] chdir " + guest_working_directory_.string() + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 13: {
        std::uint32_t error = 0;
        const auto directory = guest_directory_of_descriptor(registers[0], error);
        if (!directory) {
            bsd_error(cpu, error);
            return;
        }
        guest_working_directory_ = *directory;
        output_.write(
            "[vfs] fchdir " + guest_working_directory_.string() + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 18: {
        const auto mount_count =
            static_cast<std::uint32_t>(shared_state_->mounts.size());
        if (registers[0] == 0) {
            bsd_success(cpu, mount_count);
            return;
        }
        constexpr std::uint32_t guest_statfs_size = 272;
        const auto capacity = registers[1] / guest_statfs_size;
        const auto count = std::min(capacity, mount_count);
        for (std::uint32_t index = 0; index < count; ++index) {
            const auto& volume =
                hfs_volumes_.for_guest_path(shared_state_->mounts[index].path);
            if (!write_guest_statfs(
                    registers[0] + index * guest_statfs_size, volume)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
        bsd_success(cpu, count);
        return;
    }
    case 33: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        output_.write("[vfs] access " + *path + "\n");
        if (reject_unavailable_baseband(*path)) {
            return;
        }
        if (bsd::baseband_device::is_mux_channel_path(*path) &&
            !shared_state_->baseband_device_state.mux_channel_path_available(
                *path)) {
            bsd_error(cpu, darwin::error::no_such_device_or_address);
            return;
        }
        if (*path == "/dev/console" || *path == "/dev/random" ||
            *path == "/dev/urandom" || *path == "/dev/srandom" ||
            bsd::null_device::is_path(*path) || *path == "/dev/disk0s1" ||
            *path == "/dev/disk0s2" || *path == "/dev/rdisk0s1" ||
            *path == "/dev/rdisk0s2" ||
            *path == darwin::network::apple80211_driver::event_device_path ||
            (bsd::baseband_device::is_path(*path) &&
                shared_state_->baseband_device_state.available()) ||
            bsd::offline_serial_device::is_path(*path)) {
            bsd_success(cpu, 0);
            return;
        }
        if (darwin::bpf::device_minor(*path)) {
            bsd_success(cpu, 0);
            return;
        }
        std::error_code error;
        if (!std::filesystem::exists(resolve_guest_path(*path), error)) {
            bsd_error(cpu, 2);
        } else {
            bsd_success(cpu, 0);
        }
        return;
    }
    case 36:
        bsd_success(cpu, 0);
        return;
    case darwin::syscall::revoke: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto host = resolve_guest_path(*path);
        std::error_code error;
        const auto status = std::filesystem::status(host, error);
        const auto virtual_console = *path == "/dev/console";
        if (error && !virtual_console) {
            bsd_error(cpu, bsd_support::darwin_filesystem_error(error));
            return;
        }
        if (!virtual_console && !std::filesystem::is_character_file(status) &&
            !std::filesystem::is_block_file(status)) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        if (process_.effective_uid != 0) {
            const auto metadata = query_hfs_metadata(host, true);
            if (!metadata || metadata->owner != process_.effective_uid) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
        }
        output_.write("[vfs] revoke " + *path + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 57: {
        const auto target = memory_.read_c_string(registers[0]);
        const auto link_path = memory_.read_c_string(registers[1]);
        if (!target || !link_path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (target->size() >= 4096U) {
            bsd_error(cpu, 63U);
            return;
        }
        const auto host = resolve_guest_path(*link_path, false);
        std::error_code error;
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            std::filesystem::create_symlink(*target, host, error);
            hfs_metadata_.invalidate_xattrs();
        }
        if (error) {
            bsd_error(cpu, bsd_support::darwin_filesystem_error(error));
            return;
        }
        const auto metadata = hfs_metadata_.query(host, false);
        if (!metadata) {
            bsd_error(cpu, 5U);
            return;
        }
        const auto timestamp =
            bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            auto& metadata_override =
                shared_state_->hfs_metadata_overrides[metadata->permanent_id];
            metadata_override.mode =
                0120000U | (0777U & ~process_.file_creation_mask);
            metadata_override.owner = process_.effective_uid;
            metadata_override.group = process_.effective_gid;
            metadata_override.creation_time = timestamp;
            metadata_override.modification_time = timestamp;
            metadata_override.change_time = timestamp;
        }
        output_.write("[vfs] symlink " + *link_path + " -> " + *target + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 58: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (registers[2] > bsd_support::maximum_io) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto host = resolve_guest_path(*path, false);
        std::error_code error;
        if (!std::filesystem::is_symlink(host, error)) {
            bsd_error(cpu, error ? bsd_support::darwin_filesystem_error(error)
                                 : bsd_support::invalid_argument);
            return;
        }
        const auto target = std::filesystem::read_symlink(host, error).string();
        if (error) {
            bsd_error(cpu, bsd_support::darwin_filesystem_error(error));
            return;
        }
        const auto count = std::min<std::size_t>(target.size(), registers[2]);
        std::vector<std::byte> bytes(count);
        std::transform(target.begin(),
            target.begin() + static_cast<std::ptrdiff_t>(count), bytes.begin(),
            [](char character) { return static_cast<std::byte>(character); });
        if (!memory_.copy_in(registers[1], bytes)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, static_cast<std::uint32_t>(count));
        return;
    }
    case 128: {
        const auto source_path = memory_.read_c_string(registers[0]);
        const auto destination_path = memory_.read_c_string(registers[1]);
        if (!source_path || !destination_path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto source = resolve_guest_path(*source_path, false);
        const auto destination = resolve_guest_path(*destination_path, false);
        if (source.lexically_normal() == rootfs_.lexically_normal()) {
            bsd_error(cpu, 16U);
            return;
        }
        std::error_code source_status_error;
        const auto source_status =
            std::filesystem::symlink_status(source, source_status_error);
        const bool source_is_directory =
            !source_status_error &&
            std::filesystem::is_directory(source_status);
        const auto source_metadata = query_hfs_metadata(source, false);
        const auto replaced_metadata = query_hfs_metadata(destination, false);
        if (source_metadata && replaced_metadata &&
            source_metadata->permanent_id == replaced_metadata->permanent_id) {
            bsd_success(cpu, 0);
            return;
        }
        std::error_code error;
        bool renamed = false;
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            const auto replaced_identity =
                hfs_metadata_.last_link_identity(destination);
            std::filesystem::rename(source, destination, error);
            if (!error) {
                renamed = true;
                const auto source_resource =
                    hfs::MetadataProvider::resource_sidecar(source);
                const auto destination_resource =
                    hfs::MetadataProvider::resource_sidecar(destination);
                std::error_code resource_error;
                if (std::filesystem::is_regular_file(
                        source_resource, resource_error)) {
                    resource_error.clear();
                    static_cast<void>(hfs_metadata_.remove_name(
                        destination_resource, resource_error));
                    resource_error.clear();
                    std::filesystem::rename(
                        source_resource, destination_resource, resource_error);
                } else {
                    resource_error.clear();
                    static_cast<void>(hfs_metadata_.remove_name(
                        destination_resource, resource_error));
                    resource_error.clear();
                }
                if (resource_error)
                    error = resource_error;
                if (replaced_identity)
                    hfs_metadata_.forget(*replaced_identity);
                if (replaced_metadata) {
                    shared_state_->hfs_metadata_overrides.erase(
                        replaced_metadata->permanent_id);
                    shared_state_->hfs_named_attribute_overrides.erase(
                        replaced_metadata->permanent_id);
                }
            }
        }
        if (renamed) {
            hfs_metadata_.invalidate_xattrs();
            if (source_is_directory) {
                shared_state_->guest_file_generation_registry
                    ->publish_subtree_rename(source, destination);
            } else {
                shared_state_->guest_file_generation_registry->publish_rename(
                    source, destination);
            }
            directory_entries_cache_.clear();
        }
        if (error) {
            bsd_error(cpu, bsd_support::darwin_filesystem_error(error));
            return;
        }
        const auto remap_open_path = [&](std::filesystem::path& open_path) {
            const auto normalized = open_path.lexically_normal();
            if (normalized == source.lexically_normal()) {
                open_path = destination;
                return;
            }
            const auto relative = normalized.lexically_relative(source);
            if (relative.empty() || relative == ".")
                return;
            const auto first = *relative.begin();
            if (first != "..")
                open_path = destination / relative;
        };
        for (auto& [descriptor, open_path] : file_descriptors_) {
            static_cast<void>(descriptor);
            remap_open_path(open_path);
        }
        output_.write(
            "[vfs] rename " + *source_path + " -> " + *destination_path + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 136: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto host = resolve_guest_path(*path);
        std::error_code error;
        {
            std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
            if (std::filesystem::exists(host, error)) {
                bsd_error(cpu, 17);
                return;
            }
            error.clear();
            if (!std::filesystem::is_directory(host.parent_path(), error)) {
                bsd_error(cpu, 2);
                return;
            }
            error.clear();
            const auto created = std::filesystem::create_directory(host, error);
            hfs_metadata_.invalidate_xattrs();
            if (!created) {
                bsd_error(
                    cpu, error == std::errc::permission_denied ? 13U : 5U);
                return;
            }
        }
        {
            const auto timestamp =
                bsd_support::guest_filesystem_timestamp(shared_state_->clock);
            const auto metadata = hfs_metadata_.query(host, true);
            if (!metadata) {
                bsd_error(cpu, 5);
                return;
            }
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            auto& metadata_override =
                shared_state_->hfs_metadata_overrides[metadata->permanent_id];
            metadata_override.mode =
                0040000U |
                (registers[1] & ~process_.file_creation_mask & 07777U);
            metadata_override.owner = process_.effective_uid;
            metadata_override.group = process_.effective_gid;
            metadata_override.creation_time = timestamp;
            metadata_override.modification_time = timestamp;
            metadata_override.change_time = timestamp;
        }
        shared_state_->guest_file_generation_registry->publish_subtree_create(
            host);
        directory_entries_cache_.clear();
        output_.write("[vfs] mkdir " + *path +
                      " mode=" + std::to_string(registers[1] & 07777U) + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 137: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::error_code error;
        const auto host = resolve_guest_path(*path, false);
        const auto status = std::filesystem::symlink_status(host, error);
        if (error || status.type() == std::filesystem::file_type::not_found) {
            bsd_error(cpu, 2);
        } else if (!std::filesystem::is_directory(status)) {
            bsd_error(cpu, 20);
        } else if (host.lexically_normal() == rootfs_.lexically_normal()) {
            bsd_error(cpu, 16U);
        } else {
            const auto metadata = query_hfs_metadata(host, false);
            {
                const std::lock_guard filesystem_lock {
                    shared_state_->filesystem_mutex
                };
                if (!hfs_metadata_.remove_name(host, error)) {
                    bsd_error(
                        cpu, bsd_support::darwin_filesystem_error(error, 66U));
                    return;
                }
                if (metadata) {
                    shared_state_->hfs_metadata_overrides.erase(
                        metadata->permanent_id);
                    shared_state_->hfs_named_attribute_overrides.erase(
                        metadata->permanent_id);
                }
            }
            shared_state_->guest_file_generation_registry
                ->publish_subtree_remove(host);
            directory_entries_cache_.clear();
            output_.write("[vfs] rmdir " + *path + "\n");
            bsd_success(cpu, 0);
        }
        return;
    }
    case 153: {
        if (const auto device = virtual_descriptors_.find(registers[0]);
            device != virtual_descriptors_.end() &&
            device->second == "random") {
            const auto size = static_cast<std::size_t>(registers[2]);
            if (size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            std::vector<std::byte> bytes(size);
            for (auto& byte : bytes) {
                random_state_ ^= random_state_ << 13U;
                random_state_ ^= random_state_ >> 7U;
                random_state_ ^= random_state_ << 17U;
                byte = static_cast<std::byte>(random_state_ & 0xffU);
            }
            if (!memory_.copy_in(registers[1], bytes)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
            return;
        }
        const auto found = file_descriptors_.find(registers[0]);
        if (found == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto size = static_cast<std::size_t>(registers[2]);
        if (size > bsd_support::maximum_io) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto offset = static_cast<std::uint64_t>(registers[3]) |
                            (static_cast<std::uint64_t>(registers[4]) << 32U);
        const auto description =
            ensure_regular_file_open_description(registers[0]);
        if (!description) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        std::vector<std::byte> bytes(size);
        const auto result = ::pread(description->host_descriptor(),
            bytes.data(), bytes.size(), static_cast<off_t>(offset));
        if (result < 0) {
            bsd_error(
                cpu, bsd_support::darwin_filesystem_error(
                         std::error_code { errno, std::generic_category() }));
            return;
        }
        bytes.resize(static_cast<std::size_t>(result));
        if (!memory_.copy_in(registers[1], bytes)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
        return;
    }
    case 154: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto file = file_descriptors_.find(fd);
        if (file == file_descriptors_.end()) {
            bsd_error(cpu, darwin::error::bad_file_descriptor);
            return;
        }
        const auto flags = file_status_flags_.contains(fd)
                               ? file_status_flags_.at(fd)
                               : darwin::open_flag::read_only;
        if ((flags & darwin::open_flag::access_mode) ==
            darwin::open_flag::read_only) {
            bsd_error(cpu, darwin::error::bad_file_descriptor);
            return;
        }
        const auto size = static_cast<std::size_t>(registers[2]);
        if (size > bsd_support::maximum_io) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        const auto bytes = memory_.read_bytes(registers[1], size);
        if (!bytes) {
            bsd_error(cpu, darwin::error::bad_address);
            return;
        }
        const auto offset = static_cast<std::uint64_t>(registers[3]) |
                            (static_cast<std::uint64_t>(registers[4]) << 32U);
        const auto description = ensure_regular_file_open_description(fd);
        if (!description) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
        const auto result = ::pwrite(description->host_descriptor(),
            bytes->data(), bytes->size(), static_cast<off_t>(offset));
        if (result < 0) {
            bsd_error(
                cpu, bsd_support::darwin_filesystem_error(
                         std::error_code { errno, std::generic_category() }));
            return;
        }
        static_cast<void>(
            shared_state_->shared_mapping_page_cache->reflect_descriptor_write(
                description->host_descriptor(), offset,
                std::span<const std::byte> {
                    bytes->data(), static_cast<std::size_t>(result) }));
        static_cast<void>(
            shared_state_->guest_file_generation_registry->publish_descriptor(
                file->second, description->host_descriptor(),
                GuestFileMutationKind::Write));
        bsd_success(cpu, static_cast<std::uint32_t>(result));
        return;
    }
    case 157: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::error_code error;
        if (!std::filesystem::exists(resolve_guest_path(*path), error)) {
            bsd_error(cpu, 2);
            return;
        }
        const auto& volume = hfs_volumes_.for_guest_path(*path);
        if (!write_guest_statfs(registers[1], volume)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 345: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto& volume = hfs_volumes_.for_guest_path(*path);
        output_.write(
            "[vfs] statfs64 " + *path + " volume=" + volume.mount_point +
            " free-blocks=" + std::to_string(volume.free_blocks) + "\n");
        std::error_code error;
        const auto virtual_path =
            virtual_character_path_minor(*path) ||
            darwin::bpf::device_minor(*path) || *path == "/dev/disk0s1" ||
            *path == "/dev/disk0s2" || *path == "/dev/rdisk0s1" ||
            *path == "/dev/rdisk0s2";
        if (!virtual_path &&
            !std::filesystem::exists(resolve_guest_path(*path), error)) {
            bsd_error(cpu, darwin::error::no_entry);
            return;
        }
        if (!write_guest_statfs64(registers[1], volume)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 159: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto found = std::find_if(shared_state_->mounts.begin(),
            shared_state_->mounts.end(),
            [&](const KernelSharedState::MountEntry& mount) {
                return mount.path == *path;
            });
        if (found == shared_state_->mounts.end() || found->path == "/") {
            bsd_error(cpu, found == shared_state_->mounts.end() ? 22U : 16U);
            return;
        }
        shared_state_->mounts.erase(found);
        bsd_success(cpu, 0);
        return;
    }
    case 167: {
        const auto type = memory_.read_c_string(registers[0], 32);
        const auto path = memory_.read_c_string(registers[1]);
        if (!type || !path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::error_code path_error;
        if (!std::filesystem::is_directory(
                resolve_guest_path(*path), path_error)) {
            bsd_error(cpu, path_error ? 2U : 20U);
            return;
        }
        std::string source;
        if (registers[3] != 0) {
            if (const auto source_pointer = memory_.read32(registers[3]);
                source_pointer) {
                source = memory_.read_c_string(*source_pointer).value_or("");
            }
        }
        const auto existing = std::find_if(shared_state_->mounts.begin(),
            shared_state_->mounts.end(),
            [&](const KernelSharedState::MountEntry& mount) {
                return mount.path == *path;
            });
        const KernelSharedState::MountEntry entry { *type, *path, source,
            registers[2] };
        if (existing == shared_state_->mounts.end())
            shared_state_->mounts.push_back(entry);
        else
            *existing = entry;
        output_.write(
            "[vfs] mount " + *type + " " + source + " on " + *path + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 158:
        if (!file_descriptors_.contains(registers[0]) &&
            !virtual_descriptors_.contains(registers[0]) && registers[0] > 2) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
        } else if (const auto descriptor = file_descriptors_.find(registers[0]);
            !write_guest_statfs(registers[1],
                descriptor == file_descriptors_.end()
                    ? hfs_volumes_.for_guest_path("/")
                    : volume_for_descriptor_path(descriptor->second))) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return;
    case 346: {
        auto descriptor = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(descriptor);
            duplicate != duplicated_descriptors_.end()) {
            descriptor = duplicate->second;
        }
        if (!file_descriptors_.contains(descriptor) &&
            !virtual_descriptors_.contains(descriptor) &&
            !virtual_block_descriptors_.contains(descriptor) &&
            !bpf_descriptors_.contains(descriptor) && descriptor > 2) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto file = file_descriptors_.find(descriptor);
        const auto& volume = file == file_descriptors_.end()
                                 ? hfs_volumes_.for_guest_path("/")
                                 : volume_for_descriptor_path(file->second);
        if (!write_guest_statfs64(registers[1], volume)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 347: {
        const auto mount_count =
            static_cast<std::uint32_t>(shared_state_->mounts.size());
        if (registers[0] == 0) {
            bsd_success(cpu, mount_count);
            return;
        }
        constexpr std::uint32_t guest_statfs64_size = 2168;
        const auto capacity = registers[1] / guest_statfs64_size;
        const auto count = std::min(capacity, mount_count);
        for (std::uint32_t index = 0; index < count; ++index) {
            const auto& volume =
                hfs_volumes_.for_guest_path(shared_state_->mounts[index].path);
            if (!write_guest_statfs64(
                    registers[0] + index * guest_statfs64_size, volume)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
        bsd_success(cpu, count);
        return;
    }
    case 200: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto length = static_cast<std::uint64_t>(registers[1]) |
                            (static_cast<std::uint64_t>(registers[2]) << 32U);
        if (length > 128ULL * 1024ULL * 1024ULL) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto host = resolve_guest_path(*path);
        std::error_code error;
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            std::filesystem::resize_file(
                host, static_cast<std::uintmax_t>(length), error);
        }
        if (error) {
            bsd_error(cpu, bsd_support::darwin_filesystem_error(error));
            return;
        }
        static_cast<void>(
            shared_state_->guest_file_generation_registry->publish(
                host, GuestFileMutationKind::Truncate));
        bsd_success(cpu, 0);
        return;
    }
    case 201: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto file = file_descriptors_.find(fd);
        if (file == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto length = static_cast<std::uint64_t>(registers[1]) |
                            (static_cast<std::uint64_t>(registers[2]) << 32U);
        if (length > 128ULL * 1024ULL * 1024ULL) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto description = ensure_regular_file_open_description(fd);
        if (!description) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (::ftruncate(description->host_descriptor(),
                static_cast<off_t>(length)) != 0) {
            bsd_error(
                cpu, bsd_support::darwin_filesystem_error(
                         std::error_code { errno, std::generic_category() }));
            return;
        }
        static_cast<void>(
            shared_state_->guest_file_generation_registry->publish_descriptor(
                file->second, description->host_descriptor(),
                GuestFileMutationKind::Truncate));
        bsd_success(cpu, 0);
        return;
    }
    case 196:
    case 344: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto descriptor = file_descriptors_.find(fd);
        if (descriptor == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        std::error_code directory_error;
        if (!std::filesystem::is_directory(
                descriptor->second, directory_error)) {
            bsd_error(cpu, 20);
            return;
        }
        const auto cache_key = descriptor->second.lexically_normal();
        auto cached_entries = directory_entries_cache_.find(cache_key);
        if (cached_entries == directory_entries_cache_.end()) {
            const auto current_metadata =
                query_hfs_metadata(descriptor->second, true, false);
            const auto parent_path = descriptor->second == rootfs_
                                         ? descriptor->second
                                         : descriptor->second.parent_path();
            const auto parent_metadata =
                query_hfs_metadata(parent_path, true, false);
            std::vector<DirectoryEntry> entries {
                { ".", 4,
                    current_metadata ? current_metadata->catalog_id : 2U },
                { "..", 4, parent_metadata ? parent_metadata->catalog_id : 2U }
            };
            append_directory_entries(
                descriptor->second, entries, directory_error);
            if (directory_error) {
                bsd_error(cpu, 5);
                return;
            }
            std::error_code dev_directory_error;
            if (std::filesystem::equivalent(
                    descriptor->second, rootfs_ / "dev", dev_directory_error) &&
                !dev_directory_error) {
                const auto add_virtual = [&](std::string name,
                                             std::uint8_t type) {
                    if (std::none_of(entries.begin(), entries.end(),
                            [&](const DirectoryEntry& entry) {
                                return entry.name == name;
                            })) {
                        constexpr std::uint32_t first_virtual_catalog_id =
                            0x7fff0000U;
                        entries.push_back({ std::move(name), type,
                            first_virtual_catalog_id +
                                static_cast<std::uint32_t>(entries.size()) });
                    }
                };
                add_virtual("disk0s1", 6);
                add_virtual("disk0s2", 6);
                add_virtual("rdisk0s1", 2);
                add_virtual("rdisk0s2", 2);
                add_virtual("console", 2);
                add_virtual("null", 2);
                add_virtual("autofs_nowait", 2);
                add_virtual("random", 2);
                add_virtual("urandom", 2);
                add_virtual("bpf0", 2);
                if (shared_state_->baseband_device_state.available()) {
                    add_virtual(
                        std::string {
                            bsd::baseband_device::legacy_path.substr(5) },
                        2);
                    add_virtual(
                        std::string { bsd::baseband_device::directory_name },
                        2);
                    add_virtual(
                        std::string {
                            bsd::baseband_device::spi_mux_directory_name },
                        2);
                    add_virtual(
                        std::string {
                            bsd::baseband_device::h5_mux_directory_name },
                        2);
                }
                add_virtual(
                    std::string { bsd::offline_serial_device::directory_name },
                    2);
                std::ostringstream directory_trace;
                directory_trace << "[vfs] virtual /dev enumeration entries="
                                << entries.size() << " buffer=" << registers[2]
                                << " index=" << file_offsets_[fd] << '\n';
                output_.write(directory_trace.str());
            }
            std::sort(entries.begin() + 2, entries.end(),
                [](const DirectoryEntry& lhs, const DirectoryEntry& rhs) {
                    return lhs.name < rhs.name;
                });
            cached_entries =
                directory_entries_cache_.emplace(cache_key, std::move(entries))
                    .first;
        }
        const auto& entries = cached_entries->second;
        auto entry_index = static_cast<std::size_t>(file_offsets_[fd]);
        if (entry_index > entries.size())
            entry_index = entries.size();
        const auto initial_index = entry_index;
        const auto extended_entries = number == 344;
        std::vector<std::byte> bytes;
        bytes.reserve(registers[2]);
        const auto put16 = [&](std::size_t offset, std::uint16_t value) {
            bytes[offset] = static_cast<std::byte>(value & 0xffU);
            bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
        };
        const auto put32 = [&](std::size_t offset, std::uint32_t value) {
            for (std::size_t byte = 0; byte < 4; ++byte) {
                bytes[offset + byte] =
                    static_cast<std::byte>(value >> (byte * 8U));
            }
        };
        const auto put64 = [&](std::size_t offset, std::uint64_t value) {
            for (std::size_t byte = 0; byte < 8; ++byte) {
                bytes[offset + byte] =
                    static_cast<std::byte>(value >> (byte * 8U));
            }
        };
        while (entry_index < entries.size()) {
            const auto& entry = entries[entry_index];
            const auto record_size =
                extended_entries
                    ? static_cast<std::uint16_t>(
                          (25U + entry.name.size() + 7U) & ~7U)
                    : static_cast<std::uint16_t>(
                          (8U + entry.name.size() + 1U + 3U) & ~3U);
            if (record_size > registers[2] - bytes.size())
                break;
            const auto start = bytes.size();
            bytes.resize(start + record_size);
            if (extended_entries) {
                put64(start, entry.catalog_id);
                put64(start + 8, entry_index + 1U);
                put16(start + 16, record_size);
                put16(
                    start + 18, static_cast<std::uint16_t>(entry.name.size()));
                bytes[start + 20] = static_cast<std::byte>(entry.type);
                for (std::size_t byte = 0; byte < entry.name.size(); ++byte) {
                    bytes[start + 21 + byte] =
                        static_cast<std::byte>(entry.name[byte]);
                }
            } else {
                put32(start, entry.catalog_id);
                put16(start + 4, record_size);
                bytes[start + 6] = static_cast<std::byte>(entry.type);
                bytes[start + 7] = static_cast<std::byte>(entry.name.size());
                for (std::size_t byte = 0; byte < entry.name.size(); ++byte) {
                    bytes[start + 8 + byte] =
                        static_cast<std::byte>(entry.name[byte]);
                }
            }
            ++entry_index;
        }
        const auto position_written =
            registers[3] == 0 ||
            (extended_entries ? memory_.write64(registers[3],
                                    static_cast<std::uint64_t>(entry_index))
                              : memory_.write32(registers[3],
                                    static_cast<std::uint32_t>(initial_index)));
        if (!memory_.copy_in(registers[1], bytes) || !position_written) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        file_offsets_[fd] = entry_index;
        bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
        return;
    }
    case 222: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto descriptor = file_descriptors_.find(fd);
        std::error_code directory_error;
        if (descriptor == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (!std::filesystem::is_directory(descriptor->second, directory_error)) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto bitmap_count = memory_.read16(registers[1]);
        if (!bitmap_count) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (*bitmap_count != 5) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        std::array<std::uint32_t, 5> masks { };
        for (std::uint32_t index = 0; index < 5; ++index) {
            const auto mask = memory_.read32(registers[1] + 4U + index * 4U);
            if (!mask) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            masks[index] = *mask;
        }
        const hfs::AttributeRequest request { masks[0], masks[1], masks[2],
            masks[3], masks[4] };
        if (!hfs::MetadataProvider::valid_request(request) ||
            request.volume != 0) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        constexpr std::uint32_t fsopt_nofollow = 0x00000001U;
        constexpr std::uint32_t fsopt_noinmemupdate = 0x00000002U;
        constexpr std::size_t hfs_average_name_size = 22;
        if ((registers[7] & ~(fsopt_nofollow | fsopt_noinmemupdate)) != 0U) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto requested = memory_.read32(registers[4]);
        if (!requested) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (*requested == 0 || registers[3] == 0) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (registers[5] == 0 || registers[6] == 0) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::vector<DirectoryEntry> listing;
        append_directory_entries(descriptor->second, listing, directory_error);
        if (directory_error) {
            bsd_error(cpu, 5);
            return;
        }
        std::sort(listing.begin(), listing.end(),
            [](const DirectoryEntry& lhs, const DirectoryEntry& rhs) {
                return lhs.name < rhs.name;
            });
        const auto total = listing.size();
        const auto start = static_cast<std::size_t>(file_offsets_[fd]);
        auto index = start;
        std::uint32_t actual = 0;
        std::vector<std::byte> bytes;
        bool end_of_directory = true;
        if (index < total) {
            const auto average_record =
                hfs::MetadataProvider::fixed_block_size(request) +
                hfs_average_name_size;
            const auto resid = static_cast<std::size_t>(registers[3]);
            const auto maxentries =
                std::min<std::size_t>(resid / average_record, *requested);
            if (maxentries < 1) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto batch_end = std::min(total, index + maxentries);
            std::size_t remaining = resid;
            std::uint32_t allowed = *requested;
            while (index < batch_end) {
                const auto host_path = descriptor->second / listing[index].name;
                const auto metadata =
                    query_hfs_metadata(host_path, false, false);
                if (!metadata) {
                    bsd_error(cpu, 5);
                    return;
                }
                const auto guest_path =
                    (std::filesystem::path { "/" } /
                        host_path.lexically_relative(rootfs_))
                        .lexically_normal()
                        .generic_string();
                const auto record = hfs::MetadataProvider::pack_attributes(
                    *metadata, request, guest_path);
                if (record.size() > remaining)
                    break;
                bytes.insert(bytes.end(), record.begin(), record.end());
                remaining -= record.size();
                ++actual;
                ++index;
                if (--allowed == 0 || remaining < average_record)
                    break;
            }
            end_of_directory = actual == total;
            if (!(index < total && !end_of_directory && actual > 0))
                end_of_directory = true;
        }
        if (!memory_.write32(registers[4], actual) ||
            !memory_.write32(registers[5], static_cast<std::uint32_t>(start)) ||
            !memory_.write32(registers[6], static_cast<std::uint32_t>(total)) ||
            (!bytes.empty() && !memory_.copy_in(registers[2], bytes))) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        file_offsets_[fd] = index;
        bsd_success(cpu, end_of_directory ? 1U : 0U);
        return;
    }
    case 199: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto file = file_descriptors_.find(fd);
        if (file == file_descriptors_.end()) {
            bsd_error(cpu, virtual_descriptors_.contains(fd)
                               ? 29
                               : bsd_support::bad_file_descriptor);
            return;
        }
        const auto raw_offset =
            static_cast<std::uint64_t>(registers[1]) |
            (static_cast<std::uint64_t>(registers[2]) << 32U);
        const auto offset = static_cast<std::int64_t>(raw_offset);
        std::int64_t base = 0;
        switch (registers[3]) {
        case 0:
            break;
        case 1:
            base = static_cast<std::int64_t>(file_offsets_[fd]);
            break;
        case 2: {
            const auto description = ensure_regular_file_open_description(fd);
            struct stat status { };
            if (!description ||
                ::fstat(description->host_descriptor(), &status) != 0) {
                bsd_error(cpu,
                    description
                        ? bsd_support::darwin_filesystem_error(std::error_code {
                              errno, std::generic_category() })
                        : bsd_support::bad_file_descriptor);
                return;
            }
            base = static_cast<std::int64_t>(status.st_size);
            break;
        }
        default:
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if ((offset < 0 && base < -offset) ||
            (offset > 0 &&
                base > std::numeric_limits<std::int64_t>::max() - offset)) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto position = base + offset;
        if (position < 0) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        file_offsets_[fd] = static_cast<std::uint64_t>(position);
        const auto result = static_cast<std::uint64_t>(position);
        bsd_success(cpu, static_cast<std::uint32_t>(result),
            static_cast<std::uint32_t>(result >> 32U));
        return;
    }
    case 220: {
        const auto path = memory_.read_c_string(registers[0]);
        const auto bitmap_count = memory_.read16(registers[1]);
        if (!path || !bitmap_count || *bitmap_count != 5) {
            bsd_error(cpu, path && bitmap_count ? bsd_support::invalid_argument
                                                : bsd_support::bad_address);
            return;
        }
        std::array<std::uint32_t, 5> masks { };
        for (std::uint32_t index = 0; index < 5; ++index) {
            const auto mask = memory_.read32(registers[1] + 4U + index * 4U);
            if (!mask) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            masks[index] = *mask;
        }
        const hfs::AttributeRequest request { masks[0], masks[1], masks[2],
            masks[3], masks[4] };
        if (!hfs::MetadataProvider::valid_request(request)) {
            std::ostringstream message;
            message << "[hfs] invalid getattrlist " << *path << " masks";
            for (const auto mask : masks)
                message << " 0x" << std::hex << mask;
            message << std::dec << '\n';
            output_.write(message.str());
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        constexpr std::uint32_t fsopt_nofollow = 0x00000001U;
        constexpr std::uint32_t fsopt_report_full_size = 0x00000004U;
        constexpr std::uint32_t fsopt_pack_invalid_attributes = 0x00000008U;
        if ((registers[4] & fsopt_pack_invalid_attributes) != 0U &&
            (request.common & hfs::attribute::common_returned_attributes) == 0U) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto follow_symlink = (registers[4] & fsopt_nofollow) == 0;
        const auto host_path = resolve_guest_path(*path, follow_symlink);
        const auto metadata = query_hfs_metadata(host_path, follow_symlink);
        if (!metadata) {
            bsd_error(cpu, 2);
            return;
        }
        const auto& volume = hfs_volumes_.for_guest_path(*path);
        if (request.volume != 0 && !hfs_volumes_.is_mount_root(*path)) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        auto result =
            request.volume != 0
                ? hfs::MetadataProvider::pack_volume_attributes(
                      *metadata, volume, request)
                : hfs::MetadataProvider::pack_attributes(*metadata, request,
                      (std::filesystem::path { "/" } /
                          host_path.lexically_relative(rootfs_))
                          .lexically_normal().generic_string());
        const auto full_size = static_cast<std::uint32_t>(result.size());
        if (result.size() > registers[3]) {
            result.resize(registers[3]);
        }
        if (result.size() >= sizeof(std::uint32_t)) {
            const auto reported_size =
                (registers[4] & fsopt_report_full_size) != 0
                    ? full_size
                    : static_cast<std::uint32_t>(result.size());
            for (std::size_t byte = 0; byte < sizeof(std::uint32_t); ++byte) {
                result[byte] =
                    static_cast<std::byte>(reported_size >> (byte * 8U));
            }
        }
        if (!memory_.copy_in(registers[2], result)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 221: {
        const auto path = memory_.read_c_string(registers[0]);
        const auto bitmap_count = memory_.read16(registers[1]);
        if (!path || !bitmap_count || *bitmap_count != 5) {
            bsd_error(cpu, path && bitmap_count ? bsd_support::invalid_argument
                                                : bsd_support::bad_address);
            return;
        }
        std::array<std::uint32_t, 5> masks { };
        for (std::uint32_t index = 0; index < masks.size(); ++index) {
            const auto mask = memory_.read32(registers[1] + 4U + index * 4U);
            if (!mask) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            masks[index] = *mask;
        }
        using namespace hfs::attribute;
        constexpr std::uint32_t supported_common_set_attributes =
            common_script | common_creation_time | common_modification_time |
            common_change_time | common_access_time | common_backup_time |
            common_finder_info | common_owner_id | common_group_id |
            common_access_mask | common_flags;
        if ((masks[0] & ~supported_common_set_attributes) != 0 ||
            masks[1] != 0 || masks[2] != 0 || masks[3] != 0 || masks[4] != 0 ||
            registers[3] > 8192U) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto attributes = memory_.read_bytes(registers[2], registers[3]);
        if (!attributes) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::size_t cursor = 0;
        const auto take32 = [&]() -> std::optional<std::uint32_t> {
            if (cursor + sizeof(std::uint32_t) > attributes->size()) {
                return std::nullopt;
            }
            std::uint32_t value = 0;
            for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
                value |=
                    std::to_integer<std::uint32_t>((*attributes)[cursor + byte])
                    << (byte * 8U);
            }
            cursor += sizeof(value);
            return value;
        };
        const auto take_time = [&]() -> std::optional<hfs::Timestamp> {
            const auto seconds = take32();
            const auto nanoseconds = take32();
            if (!seconds || !nanoseconds || *nanoseconds >= 1'000'000'000U) {
                return std::nullopt;
            }
            return hfs::Timestamp { std::bit_cast<std::int32_t>(*seconds),
                static_cast<std::int32_t>(*nanoseconds) };
        };
        hfs::MetadataOverride update;
        if ((masks[0] & common_script) != 0 && !take32()) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto read_timestamp = [&](std::uint32_t bit,
                                        std::optional<hfs::Timestamp>& target) {
            if ((masks[0] & bit) == 0)
                return true;
            target = take_time();
            return target.has_value();
        };
        if (!read_timestamp(common_creation_time, update.creation_time) ||
            !read_timestamp(
                common_modification_time, update.modification_time) ||
            !read_timestamp(common_change_time, update.change_time) ||
            !read_timestamp(common_access_time, update.access_time) ||
            !read_timestamp(common_backup_time, update.backup_time)) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if ((masks[0] & common_finder_info) != 0) {
            if (cursor + 32U > attributes->size()) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            std::array<std::byte, 32> finder_info { };
            std::copy_n(
                attributes->begin() + static_cast<std::ptrdiff_t>(cursor),
                finder_info.size(), finder_info.begin());
            update.finder_info = finder_info;
            cursor += finder_info.size();
        }
        const auto read_word = [&](std::uint32_t bit,
                                   std::optional<std::uint32_t>& target) {
            if ((masks[0] & bit) == 0)
                return true;
            target = take32();
            return target.has_value();
        };
        if (!read_word(common_owner_id, update.owner) ||
            !read_word(common_group_id, update.group) ||
            !read_word(common_access_mask, update.mode) ||
            !read_word(common_flags, update.flags) ||
            cursor != attributes->size()) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        constexpr std::uint32_t fsopt_nofollow = 0x00000001U;
        const auto follow_symlink = (registers[4] & fsopt_nofollow) == 0;
        const auto host = resolve_guest_path(*path, follow_symlink);
        const auto existing = query_hfs_metadata(host, follow_symlink);
        if (!existing) {
            bsd_error(cpu, 2);
            return;
        }
        if (update.mode) {
            update.mode = (existing->mode & ~07777U) | (*update.mode & 07777U);
        }
        if (!update.change_time) {
            update.change_time =
                bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        }
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            auto& destination =
                shared_state_->hfs_metadata_overrides[existing->permanent_id];
            if (update.mode)
                destination.mode = update.mode;
            if (update.owner)
                destination.owner = update.owner;
            if (update.group)
                destination.group = update.group;
            if (update.flags)
                destination.flags = update.flags;
            if (update.creation_time) {
                destination.creation_time = update.creation_time;
            }
            if (update.modification_time) {
                destination.modification_time = update.modification_time;
            }
            if (update.change_time) {
                destination.change_time = update.change_time;
            }
            if (update.access_time) {
                destination.access_time = update.access_time;
            }
            if (update.backup_time) {
                destination.backup_time = update.backup_time;
            }
            if (update.finder_info) {
                destination.finder_info = update.finder_info;
                const auto empty = std::all_of(update.finder_info->begin(),
                    update.finder_info->end(),
                    [](std::byte value) { return value == std::byte { }; });
                auto& finder_attribute =
                    shared_state_->hfs_named_attribute_overrides[existing
                            ->permanent_id]["com.apple.FinderInfo"];
                finder_attribute =
                    empty ? std::nullopt
                          : std::optional { std::vector<std::byte> {
                                update.finder_info->begin(),
                                update.finder_info->end() } };
            }
        }
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::get_extended_attribute:
    case darwin::syscall::get_extended_attribute_fd:
    case darwin::syscall::set_extended_attribute:
    case darwin::syscall::set_extended_attribute_fd:
    case darwin::syscall::remove_extended_attribute:
    case darwin::syscall::remove_extended_attribute_fd:
    case darwin::syscall::list_extended_attributes:
    case darwin::syscall::list_extended_attributes_fd: {
        using namespace darwin::extended_attribute;
        const auto descriptor_form = (number & 1U) != 0;
        const auto operation =
            (number - darwin::syscall::get_extended_attribute) / 2U;
        const auto options_register = operation <= 1U   ? 5U
                                      : operation == 2U ? 2U
                                                        : 3U;
        const auto options = registers[options_register];
        const auto allowed_options =
            operation == 1U ? no_follow | create | replace : no_follow;
        if ((options & ~allowed_options) != 0 ||
            (descriptor_form && (options & no_follow) != 0) ||
            ((options & (create | replace)) == (create | replace))) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto follow_symlink = (options & no_follow) == 0;
        std::filesystem::path host;
        if (descriptor_form) {
            auto descriptor = registers[0];
            if (const auto duplicate = duplicated_descriptors_.find(descriptor);
                duplicate != duplicated_descriptors_.end()) {
                descriptor = duplicate->second;
            }
            const auto found = file_descriptors_.find(descriptor);
            if (found == file_descriptors_.end()) {
                bsd_error(cpu, bsd_support::bad_file_descriptor);
                return;
            }
            host = found->second;
        } else {
            const auto path = memory_.read_c_string(registers[0]);
            if (!path) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            host = resolve_guest_path(*path, follow_symlink);
        }
        const auto metadata = query_hfs_metadata(host, follow_symlink);
        if (!metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return;
        }

        if (operation == 3U) {
            const auto names = query_hfs_named_attributes(host, follow_symlink);
            std::vector<std::byte> packed;
            for (const auto& name : names) {
                std::transform(name.begin(), name.end(),
                    std::back_inserter(packed),
                    [](char value) { return static_cast<std::byte>(value); });
                packed.push_back(std::byte { });
            }
            const auto buffer = registers[1];
            const auto size = registers[2];
            if (buffer == 0 || size == 0) {
                bsd_success(cpu, static_cast<std::uint32_t>(packed.size()));
                return;
            }
            if (size < packed.size()) {
                bsd_error(cpu, darwin::error::result_too_large);
                return;
            }
            if (!memory_.copy_in(buffer, packed)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, static_cast<std::uint32_t>(packed.size()));
            return;
        }

        const auto name =
            memory_.read_c_string(registers[1], maximum_name_length + 1U);
        if (!name) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (name->empty() || name->size() > maximum_name_length) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto existing =
            query_hfs_named_attribute(host, follow_symlink, *name);

        if (operation == 0U) {
            if (!existing) {
                bsd_error(cpu, darwin::error::no_attribute);
                return;
            }
            const auto value = registers[2];
            const auto size = registers[3];
            const auto position = registers[4];
            if (*name != resource_fork_name && position != 0) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (value == 0 || size == 0) {
                bsd_success(cpu, static_cast<std::uint32_t>(existing->size()));
                return;
            }
            if (position >= existing->size()) {
                bsd_success(cpu, 0);
                return;
            }
            const auto remaining = existing->size() - position;
            const auto count = *name == resource_fork_name
                                   ? std::min<std::size_t>(size, remaining)
                                   : remaining;
            if (*name != resource_fork_name && size < remaining) {
                bsd_error(cpu, darwin::error::result_too_large);
                return;
            }
            if (!memory_.copy_in(
                    value, std::span { *existing }.subspan(position, count))) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, static_cast<std::uint32_t>(count));
            return;
        }

        if (operation == 1U) {
            const auto value = registers[2];
            const auto size = registers[3];
            const auto position = registers[4];
            if (value == 0 || size == 0 || size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if ((options & create) != 0 && existing) {
                bsd_error(cpu, darwin::error::file_exists);
                return;
            }
            if ((options & replace) != 0 && !existing) {
                bsd_error(cpu, darwin::error::no_attribute);
                return;
            }
            if (*name == finder_info_name && (position != 0 || size != 32U)) {
                bsd_error(cpu, darwin::error::result_too_large);
                return;
            }
            if (*name != resource_fork_name && position != 0) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (*name == resource_fork_name && metadata->object_type != 1U) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
            const auto incoming = memory_.read_bytes(value, size);
            if (!incoming) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            auto replacement = *incoming;
            if (*name == resource_fork_name) {
                replacement = existing.value_or(std::vector<std::byte> { });
                if (position > bsd_support::maximum_io ||
                    size > bsd_support::maximum_io - position) {
                    bsd_error(cpu, darwin::error::argument_list_too_long);
                    return;
                }
                replacement.resize(
                    std::max<std::size_t>(replacement.size(), position + size));
                std::copy(incoming->begin(), incoming->end(),
                    replacement.begin() + position);
            }
            {
                const std::lock_guard filesystem_lock {
                    shared_state_->filesystem_mutex
                };
                if (*name == resource_fork_name) {
                    std::ofstream stream {
                        hfs::MetadataProvider::resource_sidecar(host),
                        std::ios::binary | std::ios::trunc
                    };
                    stream.write(
                        reinterpret_cast<const char*>(replacement.data()),
                        static_cast<std::streamsize>(replacement.size()));
                    if (!stream) {
                        bsd_error(cpu, darwin::error::io);
                        return;
                    }
                }
                auto& named_override =
                    shared_state_->hfs_named_attribute_overrides[metadata
                            ->permanent_id][*name];
                const auto empty_finder =
                    *name == finder_info_name &&
                    std::all_of(replacement.begin(), replacement.end(),
                        [](std::byte byte) { return byte == std::byte { }; });
                named_override =
                    empty_finder ? std::nullopt : std::optional { replacement };
                auto& metadata_override =
                    shared_state_
                        ->hfs_metadata_overrides[metadata->permanent_id];
                if (*name == finder_info_name) {
                    std::array<std::byte, 32> finder_info { };
                    std::copy(replacement.begin(), replacement.end(),
                        finder_info.begin());
                    metadata_override.finder_info = finder_info;
                } else if (*name == resource_fork_name) {
                    metadata_override.resource_length = replacement.size();
                    metadata_override.resource_allocation_size =
                        (replacement.size() + hfs::allocation_block_size - 1U) &
                        ~(static_cast<std::uint64_t>(
                              hfs::allocation_block_size) -
                            1U);
                }
                metadata_override.change_time =
                    bsd_support::guest_filesystem_timestamp(
                        shared_state_->clock);
            }
            bsd_success(cpu, 0);
            return;
        }

        if (!existing) {
            bsd_error(cpu, darwin::error::no_attribute);
            return;
        }
        if (*name == resource_fork_name) {
            std::error_code error;
            static_cast<void>(hfs_metadata_.remove_name(
                hfs::MetadataProvider::resource_sidecar(host), error));
            if (error) {
                bsd_error(cpu, bsd_support::darwin_filesystem_error(error));
                return;
            }
        }
        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            shared_state_
                ->hfs_named_attribute_overrides[metadata->permanent_id][*name] =
                std::nullopt;
            auto& metadata_override =
                shared_state_->hfs_metadata_overrides[metadata->permanent_id];
            if (*name == finder_info_name) {
                metadata_override.finder_info = std::array<std::byte, 32> { };
            } else if (*name == resource_fork_name) {
                metadata_override.resource_length = 0;
                metadata_override.resource_allocation_size = 0;
            }
            metadata_override.change_time =
                bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        }
        bsd_success(cpu, 0);
        return;
    }
    case 338:
    case 340:
    case 341:
    case 342: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        output_.write("[vfs] stat64 " + *path + "\n");
        const auto finish_extended_security = [&]() -> bool {
            if ((number == 341 || number == 342) && registers[3] != 0 &&
                !memory_.write32(registers[3], 0)) {
                bsd_error(cpu, bsd_support::bad_address);
                return false;
            }
            return true;
        };
        if (reject_unavailable_baseband(*path)) {
            return;
        }
        if (bsd::baseband_device::is_mux_channel_path(*path) &&
            !shared_state_->baseband_device_state.mux_channel_path_available(
                *path)) {
            bsd_error(cpu, darwin::error::no_such_device_or_address);
            return;
        }
        if (const auto minor = virtual_character_path_minor(*path)) {
            if (!write_guest_device_stat64(registers[1], *minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (finish_extended_security()) {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto minor = darwin::bpf::device_minor(*path)) {
            if (!write_guest_device_stat64(registers[1], 32U + *minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (finish_extended_security()) {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (*path == "/dev/disk0s1" || *path == "/dev/disk0s2" ||
            *path == "/dev/rdisk0s1" || *path == "/dev/rdisk0s2") {
            const auto minor = path->ends_with("s1") ? 1U : 2U;
            if (!write_guest_device_stat64(
                    registers[1], minor, path->starts_with("/dev/rdisk"))) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (finish_extended_security()) {
                bsd_success(cpu, 0);
            }
            return;
        }
        const auto follow_symlink = number == 338 || number == 341;
        const auto host = resolve_guest_path(*path, follow_symlink);
        std::error_code error;
        const auto status = follow_symlink
                                ? std::filesystem::status(host, error)
                                : std::filesystem::symlink_status(host, error);
        if (error || status.type() == std::filesystem::file_type::not_found) {
            bsd_error(cpu, darwin::error::no_entry);
            return;
        }
        if (!write_guest_stat64(registers[1], host, follow_symlink)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (!finish_extended_security()) {
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 339:
    case 343: {
        auto descriptor = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(descriptor);
            duplicate != duplicated_descriptors_.end()) {
            descriptor = duplicate->second;
        }
        const auto finish_extended_security = [&]() -> bool {
            if (number == 343 && registers[3] != 0 &&
                !memory_.write32(registers[3], 0)) {
                bsd_error(cpu, bsd_support::bad_address);
                return false;
            }
            return true;
        };
        if (const auto queue = kqueues_.find(descriptor);
            queue != kqueues_.end()) {
            if (!write_guest_kqueue_stat(registers[1], 0, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (finish_extended_security()) {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto block = virtual_block_descriptors_.find(descriptor);
            block != virtual_block_descriptors_.end()) {
            if (!write_guest_device_stat64(
                    registers[1], block->second.first, block->second.second)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (finish_extended_security()) {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto bpf = bpf_descriptors_.find(descriptor);
            bpf != bpf_descriptors_.end()) {
            if (!write_guest_device_stat64(
                    registers[1], 32U + bpf->second->minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (finish_extended_security()) {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto device = virtual_descriptors_.find(descriptor);
            device != virtual_descriptors_.end()) {
            const auto minor = virtual_character_device_minor(device->second);
            if (!minor) {
                bsd_error(cpu, bsd_support::bad_file_descriptor);
                return;
            }
            if (!write_guest_device_stat64(registers[1], *minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (finish_extended_security()) {
                bsd_success(cpu, 0);
            }
            return;
        }
        const auto found = file_descriptors_.find(descriptor);
        if (found == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto description =
            ensure_regular_file_open_description(descriptor);
        if (!write_guest_stat64(registers[1], found->second, true,
                description ? description->host_descriptor() : -1)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (!finish_extended_security()) {
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 188:
    case 190: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        output_.write("[vfs] stat " + *path + "\n");
        if (reject_unavailable_baseband(*path)) {
            return;
        }
        if (bsd::baseband_device::is_mux_channel_path(*path) &&
            !shared_state_->baseband_device_state.mux_channel_path_available(
                *path)) {
            bsd_error(cpu, darwin::error::no_such_device_or_address);
            return;
        }
        if (const auto minor = virtual_character_path_minor(*path)) {
            if (!write_guest_device_stat(registers[1], *minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto minor = darwin::bpf::device_minor(*path)) {
            if (!write_guest_device_stat(registers[1], 32U + *minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (*path == "/dev/disk0s1" || *path == "/dev/disk0s2" ||
            *path == "/dev/rdisk0s1" || *path == "/dev/rdisk0s2") {
            const auto minor = path->ends_with("s1") ? 1U : 2U;
            if (!write_guest_device_stat(
                    registers[1], minor, path->starts_with("/dev/rdisk"))) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        const auto follow_symlink = number == 188;
        const auto host = resolve_guest_path(*path, follow_symlink);
        std::error_code error;
        const auto status = follow_symlink
                                ? std::filesystem::status(host, error)
                                : std::filesystem::symlink_status(host, error);
        if (error || status.type() == std::filesystem::file_type::not_found) {
            bsd_error(cpu, 2);
            return;
        }
        if (!write_guest_stat(registers[1], host, follow_symlink)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case 189: {
        auto descriptor = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(descriptor);
            duplicate != duplicated_descriptors_.end()) {
            descriptor = duplicate->second;
        }
        if (const auto queue = kqueues_.find(descriptor);
            queue != kqueues_.end()) {
            if (!write_guest_kqueue_stat(registers[1], 0, false)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto block = virtual_block_descriptors_.find(descriptor);
            block != virtual_block_descriptors_.end()) {
            if (!write_guest_device_stat(
                    registers[1], block->second.first, block->second.second)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto bpf = bpf_descriptors_.find(descriptor);
            bpf != bpf_descriptors_.end()) {
            if (!write_guest_device_stat(
                    registers[1], 32U + bpf->second->minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto device = virtual_descriptors_.find(descriptor);
            device != virtual_descriptors_.end()) {
            const auto minor = virtual_character_device_minor(device->second);
            if (!minor) {
                bsd_error(cpu, bsd_support::bad_file_descriptor);
                return;
            }
            if (!write_guest_device_stat(registers[1], *minor, true)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        const auto found = file_descriptors_.find(descriptor);
        if (found == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto description =
            ensure_regular_file_open_description(descriptor);
        if (!write_guest_stat(registers[1], found->second, true,
                description ? description->host_descriptor() : -1)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    default:
        trace_unknown(cpu, "BSD syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }
}

}
