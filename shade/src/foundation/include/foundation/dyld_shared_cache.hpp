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
    // A published generation owns the exact bytes used to build its metadata.
    // Lazy image parsing must not reopen path after a rootfs replacement.
    std::shared_ptr<const std::vector<std::byte>> immutable_snapshot;
    // Cross-process content-addressed backing for the same immutable file
    // generation. Shared-cache images prefer this demand-paged view; the
    // vector remains available for standalone/fallback parser callers.
    std::shared_ptr<const ImmutableFileView> immutable_file_view;
    DyldCacheUuid uuid { };
    std::uint64_t cache_vm_offset { };
    std::string file_suffix;
    std::vector<DyldCacheMapping> mappings;
};

// Views returned by a published generation.  The scalar records are typed
// accessors, while strings and range tables point directly into the read-only
// generation artifact (or into the owning records used while building a new
// generation).  In particular, artifact loads do not materialize a second
// vector of DyldCacheImage/DyldCacheFile records in the emulator process.
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
    // When empty, the 16-byte magic is used as the architecture identity in
    // the generation key. A firmware catalog can provide a normalized Guest
    // ISA tag instead.
    std::string architecture;
    // Entries are ordered exactly as the main cache's subCacheArray. If this is
    // empty, fileSuffix is used to discover each sibling next to the main file.
    std::vector<std::filesystem::path> subcache_paths;
};

class DyldSharedCache {
public:
    static constexpr std::uint32_t parser_schema_version = 2;
    static constexpr std::uint32_t hle_profile_schema_version = 2;

    // Pointer-like parse result retaining the historical optional-style
    // has_value()/operator* API while allowing all successful callers to share
    // one immutable generation object.
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

    // Returns one immutable parsed Mach-O view per logical image and guest
    // architecture. The returned object is shared by all registries/processes
    // that use this cache generation.
    [[nodiscard]] std::shared_ptr<const MachOImage> parse_image(
        std::uint32_t image_index, ArmArchitectureVersion architecture) const;
    [[nodiscard]] std::vector<std::uint32_t> images_intersecting_file_range(
        std::uint32_t file_index, std::uint64_t file_offset,
        std::uint64_t size) const;

    [[nodiscard]] DyldCacheFileView main_cache() const;
    [[nodiscard]] DyldCacheFileRange files() const noexcept;
    // Return the retained immutable, demand-paged backing for one cache file.
    // Shared-region mappings use this to avoid reopening and revalidating the
    // same cache member once per mapping entry during process startup.
    [[nodiscard]] std::shared_ptr<const ImmutableFileView>
    immutable_file_view_at(std::size_t index) const;
    // Resolve one unslid cache VM address across the main cache or subcaches.
    // Objective-C selector uniquing can point an image's method metadata at a
    // string owned by a different cache image.
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
    // Artifact-loaded generations have no process-local DyldCacheFile records
    // that can retain their immutable member views. Keep one demand-paged view
    // per member so logical images sharing a subcache do not reopen/remap it.
    struct FileViewStore;
    std::shared_ptr<FileViewStore> file_view_store_;
    // Cross-process artifact loads retain the read-only mmap backing for the
    // lifetime of this generation. Typed lookup records remain a small local
    // façade for the existing API; the immutable serialized source is never
    // copied into a process-local byte vector.
    std::shared_ptr<const GenerationArtifactView> generation_artifact_view_;

    [[nodiscard]] DyldCacheFileView file_view_at(std::size_t index) const;
    [[nodiscard]] DyldCacheImageView image_view_at(std::size_t index) const;
    friend class DyldCacheFileRange;
    friend class DyldCacheImageRange;
};

} // namespace shade
