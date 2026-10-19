// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse and expose guest dyld cache mappings and cached Mach-O
// images.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <iterator>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "foundation/arm_cpu_model.hpp"
#include "foundation/content_identity.hpp"
#include "foundation/file_page_cache.hpp"

namespace shade {

class MachOImage;
class DyldSharedCache;

using DyldCacheUuid = std::array<std::byte, 16>;

struct DyldCacheRange {
    std::uint64_t address { };
    std::uint64_t size { };
    std::uint64_t file_offset { };
    std::uint32_t file_index { };
    std::uint32_t initial_protection { };
    std::uint32_t maximum_protection { };
};

struct DyldCacheMapping : DyldCacheRange {
    std::uint64_t slide_info_offset { };
    std::uint64_t slide_info_size { };
    std::uint64_t flags { };
    std::optional<std::uint32_t> slide_info_version;
};

struct DyldCacheImage {
    std::uint32_t index { };
    std::string path;
    std::uint64_t unslid_load_address { };
    std::optional<DyldCacheUuid> text_uuid;
    std::uint64_t text_segment_size { };
    std::vector<DyldCacheRange> executable_ranges;
    std::optional<ContentIdentity> text_identity;
};

struct DyldCacheFile {
    std::filesystem::path path;
    std::uintmax_t file_size { };
    std::optional<GuestFileGeneration> file_generation;
    ContentIdentity content_identity;
    std::shared_ptr<const std::vector<std::byte>> immutable_snapshot;
    std::shared_ptr<const ImmutableFileView> immutable_file_view;
    DyldCacheUuid uuid { };
    std::uint64_t cache_vm_offset { };
    std::string file_suffix;
    std::vector<DyldCacheMapping> mappings;
};

struct DyldCacheFileView {
    std::string_view path;
    std::uintmax_t file_size { };
    std::optional<GuestFileGeneration> file_generation;
    ContentIdentity content_identity;
    DyldCacheUuid uuid { };
    std::uint64_t cache_vm_offset { };
    std::string_view file_suffix;
    std::span<const DyldCacheMapping> mappings;
};

struct DyldCacheImageView {
    std::uint32_t index { };
    std::string_view path;
    std::uint64_t unslid_load_address { };
    std::optional<DyldCacheUuid> text_uuid;
    std::uint64_t text_segment_size { };
    std::span<const DyldCacheRange> executable_ranges;
    std::optional<ContentIdentity> text_identity;
};

class DyldCacheFileRange {
public:
    class iterator {
    public:
        using iterator_category = std::random_access_iterator_tag;
        using value_type = DyldCacheFileView;
        using difference_type = std::ptrdiff_t;
        using reference = value_type;

        reference operator*() const;
        value_type operator[](difference_type offset) const;
        iterator& operator++();
        iterator& operator--();
        iterator& operator+=(difference_type offset);
        iterator& operator-=(difference_type offset);
        friend iterator operator+(iterator value, difference_type offset)
        {
            return value += offset;
        }
        friend iterator operator+(difference_type offset, iterator value)
        {
            return value += offset;
        }
        friend iterator operator-(iterator value, difference_type offset)
        {
            return value -= offset;
        }
        friend difference_type operator-(
            const iterator& left, const iterator& right)
        {
            return left.index_ - right.index_;
        }
        friend bool operator==(const iterator&, const iterator&) = default;
        friend auto operator<=>(const iterator&, const iterator&) = default;

    private:
        friend class DyldCacheFileRange;
        iterator(const DyldSharedCache* cache, std::size_t index) noexcept
            : cache_ { cache }
            , index_ { index }
        {
        }
        const DyldSharedCache* cache_ { };
        std::size_t index_ { };
    };

    iterator begin() const noexcept;
    iterator end() const noexcept;
    [[nodiscard]] std::size_t size() const noexcept;
    DyldCacheFileView operator[](std::size_t index) const;

private:
    friend class DyldSharedCache;
    explicit DyldCacheFileRange(const DyldSharedCache* cache) noexcept
        : cache_ { cache }
    {
    }
    const DyldSharedCache* cache_ { };
};

class DyldCacheImageRange {
public:
    class iterator {
    public:
        using iterator_category = std::random_access_iterator_tag;
        using value_type = DyldCacheImageView;
        using difference_type = std::ptrdiff_t;
        using reference = value_type;

        reference operator*() const;
        value_type operator[](difference_type offset) const;
        iterator& operator++();
        iterator& operator--();
        iterator& operator+=(difference_type offset);
        iterator& operator-=(difference_type offset);
        friend iterator operator+(iterator value, difference_type offset)
        {
            return value += offset;
        }
        friend iterator operator+(difference_type offset, iterator value)
        {
            return value += offset;
        }
        friend iterator operator-(iterator value, difference_type offset)
        {
            return value -= offset;
        }
        friend difference_type operator-(
            const iterator& left, const iterator& right)
        {
            return left.index_ - right.index_;
        }
        friend bool operator==(const iterator&, const iterator&) = default;
        friend auto operator<=>(const iterator&, const iterator&) = default;

    private:
        friend class DyldCacheImageRange;
        iterator(const DyldSharedCache* cache, std::size_t index) noexcept
            : cache_ { cache }
            , index_ { index }
        {
        }
        const DyldSharedCache* cache_ { };
        std::size_t index_ { };
    };

    iterator begin() const noexcept;
    iterator end() const noexcept;
    [[nodiscard]] std::size_t size() const noexcept;
    DyldCacheImageView operator[](std::size_t index) const;

private:
    friend class DyldSharedCache;
    explicit DyldCacheImageRange(const DyldSharedCache* cache) noexcept
        : cache_ { cache }
    {
    }
    const DyldSharedCache* cache_ { };
};

struct DyldSharedCacheOptions {
    std::string architecture;
    std::vector<std::filesystem::path> subcache_paths;
};

class DyldSharedCache {
public:
    static constexpr std::uint32_t parser_schema_version = 2;
    static constexpr std::uint32_t hle_profile_schema_version = 2;

    class ParseResult {
    public:
        ParseResult() = default;
        ParseResult(std::shared_ptr<const DyldSharedCache> generation) noexcept;

        [[nodiscard]] bool has_value() const noexcept;
        explicit operator bool() const noexcept;
        [[nodiscard]] const DyldSharedCache* operator->() const noexcept;
        [[nodiscard]] const DyldSharedCache& operator*() const noexcept;
        [[nodiscard]] std::shared_ptr<const DyldSharedCache>
        shared() const noexcept;

    private:
        std::shared_ptr<const DyldSharedCache> generation_;
    };

    DyldSharedCache();
    ~DyldSharedCache();
    DyldSharedCache(const DyldSharedCache&) = delete;
    DyldSharedCache& operator=(const DyldSharedCache&) = delete;
    DyldSharedCache(DyldSharedCache&&) noexcept;
    DyldSharedCache& operator=(DyldSharedCache&&) noexcept;

    [[nodiscard]] static ParseResult parse(const std::filesystem::path& path,
        DyldSharedCacheOptions options = { });

    struct ParseStats {
        std::uint64_t generation_builds { };
        std::uint64_t generation_hits { };
        std::uint64_t generation_artifact_builds { };
        std::uint64_t generation_artifact_hits { };
        std::uint64_t file_view_builds { };
        std::uint64_t file_view_hits { };
        std::uint64_t image_builds { };
        std::uint64_t image_hits { };
    };

    [[nodiscard]] static ParseStats parse_stats() noexcept;

    [[nodiscard]] std::shared_ptr<const MachOImage> parse_image(
        std::uint32_t image_index, ArmArchitectureVersion architecture) const;
    [[nodiscard]] std::vector<std::uint32_t> images_intersecting_file_range(
        std::uint32_t file_index, std::uint64_t file_offset,
        std::uint64_t size) const;

    [[nodiscard]] DyldCacheFileView main_cache() const;
    [[nodiscard]] DyldCacheFileRange files() const noexcept;
    [[nodiscard]] std::shared_ptr<const ImmutableFileView>
    immutable_file_view_at(std::size_t index) const;
    [[nodiscard]] std::optional<std::string> read_vm_c_string(
        std::uint64_t address) const;
    [[nodiscard]] DyldCacheImageRange images() const noexcept;
    [[nodiscard]] const ContentIdentity& generation_identity() const noexcept;
    [[nodiscard]] std::uint32_t platform() const noexcept;
    [[nodiscard]] std::uint8_t format_version() const noexcept;
    [[nodiscard]] std::uint64_t shared_region_start() const noexcept;
    [[nodiscard]] std::uint64_t shared_region_size() const noexcept;
    [[nodiscard]] std::uint64_t max_slide() const noexcept;

    [[nodiscard]] std::optional<DyldCacheImageView> find_image(
        std::string_view install_name) const;

private:
    [[nodiscard]] static std::shared_ptr<const DyldSharedCache>
    load_shared_generation_artifact(const std::filesystem::path& path,
        const DyldSharedCacheOptions& options,
        const GuestFileGeneration& main_generation,
        const ContentIdentity& main_identity);
    void publish_shared_generation_artifact(const std::filesystem::path& path,
        const DyldSharedCacheOptions& options,
        const GuestFileGeneration& main_generation,
        const ContentIdentity& main_identity) const;

    struct ImageStore;
    struct GenerationArtifactView;
    struct ImageRangeIndexEntry {
        std::uint64_t file_offset { };
        std::uint64_t file_end { };
        std::uint64_t prefix_file_end { };
        std::uint32_t image_index { };
        std::uint32_t file_index { };
    };

    DyldCacheFile main_cache_;
    std::vector<DyldCacheFile> files_;
    std::vector<DyldCacheImage> images_;
    ContentIdentity generation_identity_;
    std::uint32_t platform_ { };
    std::uint8_t format_version_ { };
    std::uint64_t shared_region_start_ { };
    std::uint64_t shared_region_size_ { };
    std::uint64_t max_slide_ { };
    std::vector<std::vector<ImageRangeIndexEntry>> image_range_index_;
    std::shared_ptr<ImageStore> image_store_;
    struct FileViewStore;
    std::shared_ptr<FileViewStore> file_view_store_;
    std::shared_ptr<const GenerationArtifactView> generation_artifact_view_;

    [[nodiscard]] DyldCacheFileView file_view_at(std::size_t index) const;
    [[nodiscard]] DyldCacheImageView image_view_at(std::size_t index) const;
    friend class DyldCacheFileRange;
    friend class DyldCacheImageRange;
};

}
