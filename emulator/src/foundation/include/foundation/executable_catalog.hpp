// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track executable files, mappings and generations for loading and
// translation reuse.

#pragma once

#include <array>
#include <cstdint>
#include <filesystem>
#include <map>
#include <optional>
#include <set>
#include <span>
#include <string>
#include <unordered_map>
#include <vector>

#include "foundation/content_identity.hpp"
#include "foundation/dyld_shared_cache.hpp"
#include "foundation/macho.hpp"

namespace emulator {

enum class ExecutableCatalogKind : std::uint8_t {
    MachO,
    Dylib,
    Framework,
    PlugIn,
    DynamicMapping,
};

struct ExecutableMappingIdentity {
    std::uint64_t file_offset { };
    std::uint64_t byte_count { };
    std::uint64_t guest_address { };
    std::uint64_t guest_byte_count { };

    friend constexpr bool operator==(const ExecutableMappingIdentity&,
        const ExecutableMappingIdentity&) = default;
};

struct ExecutableCatalogFileGeneration {
    std::uint64_t device { };
    std::uint64_t inode { };
    std::uint64_t file_size { };
    std::int64_t modified_seconds { };
    std::int64_t modified_nanoseconds { };
    std::int64_t changed_seconds { };
    std::int64_t changed_nanoseconds { };

    friend constexpr bool operator==(const ExecutableCatalogFileGeneration&,
        const ExecutableCatalogFileGeneration&) = default;
};

struct ExecutableCatalogPathGeneration {
    std::filesystem::path path;
    ExecutableCatalogFileGeneration generation;
};

struct ExecutableCatalogKnownIdentity {
    ExecutableCatalogFileGeneration generation;
    ContentIdentity content_identity;
};

struct ExecutableCatalogEntry {
    ContentIdentity content_identity;
    std::vector<std::filesystem::path> aliases;
    std::vector<ExecutableCatalogPathGeneration> file_generations;
    std::set<ExecutableCatalogKind> kinds;
    std::optional<std::array<std::byte, 16>> uuid;
    std::uint32_t cpu_type { };
    std::uint32_t cpu_subtype { };
    std::uint32_t file_type { };
    std::uint64_t file_size { };
    bool fat_container { };
    std::vector<std::string> dependencies;
    std::vector<ExecutableMappingIdentity> mappings;
    std::vector<std::uint64_t> reliable_entry_points;
};

struct ExecutableCatalogScanSummary {
    std::size_t regular_files { };
    std::size_t mach_o_images { };
    std::size_t reused_mach_o_images { };
    std::size_t dyld_shared_cache_generations { };
    std::size_t dyld_shared_cache_images { };
    std::size_t failed_files { };
};

class ExecutableCatalog {
public:
    [[nodiscard]] const ExecutableCatalogEntry& register_image(
        const MachOImage& image);
    [[nodiscard]] const ExecutableCatalogEntry& register_path(
        const std::filesystem::path& path,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K,
        std::optional<ContentIdentity> known_identity = std::nullopt);
    [[nodiscard]] const ExecutableCatalogEntry& register_mapping(
        const std::filesystem::path& path, std::uint64_t file_offset,
        std::uint64_t byte_count);
    [[nodiscard]] std::size_t register_shared_cache(
        const DyldSharedCache& cache);
    [[nodiscard]] ExecutableCatalogScanSummary register_tree(
        const std::filesystem::path& root,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K);
    [[nodiscard]] ExecutableCatalogScanSummary refresh_tree(
        const std::filesystem::path& root,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K);
    [[nodiscard]] ExecutableCatalogScanSummary refresh_paths(
        const std::filesystem::path& root,
        const std::vector<std::filesystem::path>& paths,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K,
        const std::map<std::filesystem::path, ExecutableCatalogKnownIdentity>&
            known_identities = { });

    [[nodiscard]] bool load(const std::filesystem::path& path) noexcept;
    [[nodiscard]] bool save(const std::filesystem::path& path) const noexcept;

    [[nodiscard]] const ExecutableCatalogEntry* find(
        const ContentIdentity& identity) const;
    [[nodiscard]] const ExecutableCatalogEntry* find_path(
        const std::filesystem::path& path) const;
    [[nodiscard]] bool path_is_current(const std::filesystem::path& path) const;
    [[nodiscard]] std::vector<std::uint64_t> fixed_mapping_entry_points(
        const std::filesystem::path& path, std::uint32_t mapping_address,
        std::uint32_t mapping_size, std::uint64_t file_offset) const;
    [[nodiscard]] std::size_t reliable_entry_point_count() const noexcept;
    [[nodiscard]] std::vector<ContentIdentity> content_identities() const;
    [[nodiscard]] std::span<const ExecutableCatalogEntry>
    entries() const noexcept;
    [[nodiscard]] std::size_t size() const noexcept { return entries_.size(); }
    [[nodiscard]] std::size_t resident_bytes_estimate() const noexcept;
    [[nodiscard]] std::uint64_t revision() const noexcept
    {
        return mutation_revision_;
    }

private:
    [[nodiscard]] static std::filesystem::path normalize_path(
        const std::filesystem::path& path);
    [[nodiscard]] static ExecutableCatalogKind classify(
        const MachOImage& image, const std::filesystem::path& path);
    [[nodiscard]] ExecutableCatalogEntry& upsert(ContentIdentity identity,
        const std::filesystem::path& path, ExecutableCatalogKind kind);
    [[nodiscard]] const ExecutableCatalogEntry& register_path_alias(
        const std::filesystem::path& alias, const std::filesystem::path& target,
        ArmArchitectureVersion architecture,
        std::optional<ContentIdentity> known_identity = std::nullopt);
    void remove_path(const std::filesystem::path& path);
    [[nodiscard]] ExecutableCatalogScanSummary scan_tree(
        const std::filesystem::path& root, ArmArchitectureVersion architecture,
        const ExecutableCatalog* previous);

    std::vector<ExecutableCatalogEntry> entries_;
    std::unordered_map<ContentIdentity, std::size_t, ContentIdentityHash>
        identity_index_;
    bool reliable_entry_points_current_ { true };
    std::uint64_t mutation_revision_ { };
};

}
