// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode guest HFS attributes, ownership, timestamps and volume
// metadata.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/attr.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/hfs/hfs_attrlist.c

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

namespace shade::hfs {

inline constexpr std::string_view resource_sidecar_suffix { ".shade-rsrc" };
inline constexpr std::uint32_t allocation_block_size = 4096;

namespace attribute {
    inline constexpr std::uint32_t common_name = 0x00000001U;
    inline constexpr std::uint32_t common_device = 0x00000002U;
    inline constexpr std::uint32_t common_fsid = 0x00000004U;
    inline constexpr std::uint32_t common_object_type = 0x00000008U;
    inline constexpr std::uint32_t common_object_tag = 0x00000010U;
    inline constexpr std::uint32_t common_object_id = 0x00000020U;
    inline constexpr std::uint32_t common_permanent_id = 0x00000040U;
    inline constexpr std::uint32_t common_parent_id = 0x00000080U;
    inline constexpr std::uint32_t common_script = 0x00000100U;
    inline constexpr std::uint32_t common_creation_time = 0x00000200U;
    inline constexpr std::uint32_t common_modification_time = 0x00000400U;
    inline constexpr std::uint32_t common_change_time = 0x00000800U;
    inline constexpr std::uint32_t common_access_time = 0x00001000U;
    inline constexpr std::uint32_t common_backup_time = 0x00002000U;
    inline constexpr std::uint32_t common_finder_info = 0x00004000U;
    inline constexpr std::uint32_t common_owner_id = 0x00008000U;
    inline constexpr std::uint32_t common_group_id = 0x00010000U;
    inline constexpr std::uint32_t common_access_mask = 0x00020000U;
    inline constexpr std::uint32_t common_flags = 0x00040000U;
    inline constexpr std::uint32_t common_user_access = 0x00200000U;
    inline constexpr std::uint32_t common_file_id = 0x02000000U;
    inline constexpr std::uint32_t common_parent_file_id = 0x04000000U;
    inline constexpr std::uint32_t common_full_path = 0x08000000U;
    inline constexpr std::uint32_t common_returned_attributes = 0x80000000U;
    inline constexpr std::uint32_t common_supported_mask = 0x8e27ffffU;
    inline constexpr std::uint32_t volume_common_supported_mask = 0x8027ffffU;

    inline constexpr std::uint32_t volume_filesystem_type = 0x00000001U;
    inline constexpr std::uint32_t volume_signature = 0x00000002U;
    inline constexpr std::uint32_t volume_size = 0x00000004U;
    inline constexpr std::uint32_t volume_space_free = 0x00000008U;
    inline constexpr std::uint32_t volume_space_available = 0x00000010U;
    inline constexpr std::uint32_t volume_minimum_allocation = 0x00000020U;
    inline constexpr std::uint32_t volume_allocation_clump = 0x00000040U;
    inline constexpr std::uint32_t volume_io_block_size = 0x00000080U;
    inline constexpr std::uint32_t volume_object_count = 0x00000100U;
    inline constexpr std::uint32_t volume_file_count = 0x00000200U;
    inline constexpr std::uint32_t volume_directory_count = 0x00000400U;
    inline constexpr std::uint32_t volume_max_object_count = 0x00000800U;
    inline constexpr std::uint32_t volume_mount_point = 0x00001000U;
    inline constexpr std::uint32_t volume_name = 0x00002000U;
    inline constexpr std::uint32_t volume_mount_flags = 0x00004000U;
    inline constexpr std::uint32_t volume_mounted_device = 0x00008000U;
    inline constexpr std::uint32_t volume_encodings_used = 0x00010000U;
    inline constexpr std::uint32_t volume_capabilities = 0x00020000U;
    inline constexpr std::uint32_t volume_attributes = 0x40000000U;
    inline constexpr std::uint32_t volume_info = 0x80000000U;
    inline constexpr std::uint32_t volume_valid_mask = 0xc003ffffU;

    inline constexpr std::uint32_t directory_link_count = 0x00000001U;
    inline constexpr std::uint32_t directory_entry_count = 0x00000002U;
    inline constexpr std::uint32_t directory_mount_status = 0x00000004U;
    inline constexpr std::uint32_t directory_supported_mask = 0x00000007U;

    inline constexpr std::uint32_t file_link_count = 0x00000001U;
    inline constexpr std::uint32_t file_total_size = 0x00000002U;
    inline constexpr std::uint32_t file_allocation_size = 0x00000004U;
    inline constexpr std::uint32_t file_io_block_size = 0x00000008U;
    inline constexpr std::uint32_t file_device_type = 0x00000020U;
    inline constexpr std::uint32_t file_data_length = 0x00000200U;
    inline constexpr std::uint32_t file_data_allocation_size = 0x00000400U;
    inline constexpr std::uint32_t file_resource_length = 0x00001000U;
    inline constexpr std::uint32_t file_resource_allocation_size = 0x00002000U;
    // Exact Darwin 8 getattrlist_file_tab mask. Deprecated clump/file-type and
    // extent attributes are defined in attr.h but rejected by getattrlist().
    inline constexpr std::uint32_t file_supported_mask = 0x0000362fU;
} // namespace attribute

struct AttributeRequest {
    std::uint32_t common { };
    std::uint32_t volume { };
    std::uint32_t directory { };
    std::uint32_t file { };
    std::uint32_t fork { };
};

struct Timestamp {
    std::int32_t seconds { };
    std::int32_t nanoseconds { };
};

struct Metadata {
    std::string name;
    std::uint32_t catalog_id { };
    std::uint32_t permanent_id { };
    std::uint32_t parent_catalog_id { };
    std::uint32_t object_type { };
    std::uint32_t mode { };
    std::uint32_t owner { };
    std::uint32_t group { };
    std::uint32_t flags { };
    std::uint32_t link_count { };
    std::uint32_t directory_entry_count { };
    std::uint64_t data_length { };
    std::uint64_t data_allocation_size { };
    std::uint64_t resource_length { };
    std::uint64_t resource_allocation_size { };
    Timestamp creation_time;
    Timestamp modification_time;
    Timestamp change_time;
    Timestamp access_time;
    Timestamp backup_time;
    std::array<std::byte, 32> finder_info { };
    bool directory { };
};

struct MetadataOverride {
    std::optional<std::uint32_t> mode;
    std::optional<std::uint32_t> owner;
    std::optional<std::uint32_t> group;
    std::optional<std::uint32_t> flags;
    std::optional<Timestamp> creation_time;
    std::optional<Timestamp> modification_time;
    std::optional<Timestamp> change_time;
    std::optional<Timestamp> access_time;
    std::optional<Timestamp> backup_time;
    std::optional<std::array<std::byte, 32>> finder_info;
    std::optional<std::uint64_t> resource_length;
    std::optional<std::uint64_t> resource_allocation_size;
};

// Facts from the HFSX volume header in 694-5262-39-decrypted.dmg.  They are
// deliberately independent of the host filesystem: the host is only the VFS
// data backend and must not leak ext4/APFS volume geometry to iPhoneOS.
struct VolumeMetadata {
    std::string name { "Heavenly1A543a.UserBundle" };
    std::string mount_point { "/" };
    std::string mounted_device { "/dev/disk0s1" };
    std::uint32_t filesystem_type { 17 };
    std::uint32_t signature { 0x4858 }; // kHFSXSigWord, "HX"
    std::uint32_t block_size { 4096 };
    std::uint32_t total_blocks { 47'269 };
    std::uint32_t free_blocks { 5'832 };
    std::uint32_t allocation_clump { 65'536 };
    std::uint32_t io_block_size { 512 };
    std::uint32_t file_count { 2'557 };
    std::uint32_t directory_count { 352 };
    std::uint32_t next_catalog_id { 2'929 };
    std::uint32_t mount_flags { 0x00005001U }; // RDONLY|LOCAL|ROOTFS
    std::uint64_t encodings_used { 1 };
};

// The guest ids of a bounded (--ticks) run. A host inode is named by its host
// identity (device, inode), which the host allocates in an order the run does
// not control. The first sighting of an identity takes the id of its guest path;
// later sightings of the same identity (also after a rename) keep it. Removing
// the last link of an inode ends its entry, so a recycled host inode is a new
// file with a new id. The table is shared by every kernel of one run.
class GuestIdTable {
public:
    struct Identity {
        std::uint64_t device { };
        std::uint64_t inode { };
        auto operator<=>(const Identity&) const = default;
    };

    // The id of `identity`. On a first sighting the id is a hash of `guest_path`;
    // when another identity already holds that id, the next free id is taken.
    [[nodiscard]] std::uint32_t id_for(
        const Identity& identity, std::string_view guest_path);
    // Ends the entry of an identity whose last link was removed.
    void forget(const Identity& identity);
    // The number of sightings whose path hash was already taken.
    [[nodiscard]] std::size_t collisions() const;

private:
    mutable std::mutex mutex_;
    std::map<Identity, std::uint32_t> ids_;
    std::map<std::uint32_t, Identity> owners_;
    std::size_t collisions_ { };
};

class MetadataProvider {
public:
    // A null `guest_ids` is a normal run: host-derived ids and plain removals.
    explicit MetadataProvider(std::filesystem::path root,
        std::shared_ptr<GuestIdTable> guest_ids = nullptr);

    // The guest id of a host inode in a bounded run; nullopt in a normal run.
    [[nodiscard]] std::optional<std::uint32_t> table_id(std::uint64_t device,
        std::uint64_t inode, const std::filesystem::path& path) const;
    // The host identity that removing `path` ends, or nullopt when another
    // link keeps the inode alive or when there is no table. A directory has
    // no second name, so removing it always ends its inode.
    [[nodiscard]] std::optional<GuestIdTable::Identity> last_link_identity(
        const std::filesystem::path& path) const;
    // Removes a host name and ends the table entry of the inode it held the
    // last link to.
    bool remove_name(
        const std::filesystem::path& path, std::error_code& error) const;
    void forget(const GuestIdTable::Identity& identity) const;

    [[nodiscard]] std::optional<Metadata> query(
        const std::filesystem::path& path, bool follow_symlink,
        bool include_directory_entry_count = true) const;
    [[nodiscard]] static bool valid_request(const AttributeRequest& request);
    [[nodiscard]] static std::vector<std::byte> pack_attributes(
        const Metadata& metadata, const AttributeRequest& request,
        std::string_view guest_path = {});
    [[nodiscard]] static std::vector<std::byte> pack_volume_attributes(
        const Metadata& root_metadata, const VolumeMetadata& volume,
        const AttributeRequest& request);
    [[nodiscard]] std::optional<std::vector<std::byte>> named_attribute(
        const std::filesystem::path& path, std::string_view name,
        bool follow_symlink) const;
    [[nodiscard]] std::vector<std::string> named_attributes(
        const std::filesystem::path& path, bool follow_symlink) const;
    static void apply_override(
        Metadata& metadata, const MetadataOverride& override);
    [[nodiscard]] static bool is_resource_sidecar(
        const std::filesystem::path& path);
    [[nodiscard]] static std::filesystem::path resource_sidecar(
        const std::filesystem::path& path);

private:
    std::filesystem::path root_;
    std::shared_ptr<GuestIdTable> guest_ids_;
};

} // namespace shade::hfs
