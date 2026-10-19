// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Store, identify and manage reusable portable and native JIT
// artifacts.

#include "foundation/jit_artifact.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <fcntl.h>
#include <fstream>
#include <functional>
#include <iterator>
#include <limits>
#include <span>
#include <sstream>
#include <stdexcept>
#include <sys/file.h>
#include <sys/resource.h>
#include <system_error>
#include <thread>
#include <unistd.h>
#include <unordered_set>
#include <utility>

#include <umbra/interface/A32/a32.h>

#include "umbra_ir_artifact.hpp"

namespace shade {
namespace {

    constexpr std::array<char, 8> artifact_magic { 'i', 'L', 'J', 'A', 'R', 'T',
        'F', '7' };
    constexpr std::array<char, 8> artifact_hotset_magic_v2 { 'i', 'L', 'J', 'H',
        'O', 'T', 'S', '2' };
    constexpr std::uint32_t artifact_hotset_schema_v2 = 2U;
    constexpr std::array<char, 8> artifact_append_magic_v2 { 'i', 'L', 'J', 'A',
        'P', 'P', 'F', '2' };
    constexpr std::array<char, 8> artifact_append_magic_v3 { 'i', 'L', 'J', 'A',
        'P', 'P', 'F', '3' };
    constexpr std::array<char, 8> artifact_segment_magic { 'i', 'L', 'J', 'S',
        'E', 'G', 'F', '1' };
    constexpr std::array<char, 8> artifact_segment_footer_magic { 'i', 'L', 'J',
        'E', 'N', 'D', 'F', '1' };
    constexpr std::array<char, 8> artifact_index_magic_v1 { 'i', 'L', 'J', 'I',
        'D', 'X', 'F', '1' };
    constexpr std::array<char, 8> artifact_index_magic_v2 { 'i', 'L', 'J', 'I',
        'D', 'X', 'F', '2' };
    constexpr std::array<char, 8> artifact_footer_magic { 'i', 'L', 'J', 'F',
        'O', 'O', 'T', '1' };
    constexpr std::size_t artifact_checksum_bytes = 32U;
    constexpr std::size_t serialized_key_bytes = 132U;
    constexpr std::size_t artifact_hotset_header_bytes =
        artifact_hotset_magic_v2.size() + sizeof(std::uint32_t) +
        artifact_checksum_bytes + sizeof(std::uint32_t);
    constexpr std::size_t artifact_header_bytes =
        artifact_magic.size() + sizeof(std::uint32_t);
    constexpr std::size_t artifact_index_v1_entry_bytes =
        serialized_key_bytes + sizeof(std::uint64_t) * 2U +
        artifact_checksum_bytes;
    constexpr std::size_t artifact_index_v1_header_bytes =
        artifact_index_magic_v1.size() + sizeof(std::uint32_t);
    constexpr std::size_t artifact_index_v2_header_bytes =
        artifact_index_magic_v2.size() + sizeof(std::uint32_t) * 3U;
    constexpr std::size_t artifact_index_image_bytes =
        artifact_checksum_bytes * 2U + sizeof(std::uint32_t);
    constexpr std::size_t artifact_index_profile_bytes = 52U;
    constexpr std::size_t artifact_index_v2_entry_bytes = 72U;
    constexpr std::size_t artifact_segment_header_bytes =
        artifact_segment_magic.size() + sizeof(std::uint64_t) * 3U +
        sizeof(std::uint32_t);
    constexpr std::size_t artifact_segment_footer_bytes =
        artifact_segment_footer_magic.size() + sizeof(std::uint64_t) +
        artifact_checksum_bytes;
    constexpr std::size_t artifact_footer_bytes =
        artifact_footer_magic.size() + sizeof(std::uint64_t) * 2U +
        sizeof(std::uint32_t) + artifact_checksum_bytes;
    constexpr std::uint32_t maximum_artifacts = 1'000'000;
    constexpr std::uint32_t maximum_ir_bytes = 16U * 1024U * 1024U;
    constexpr std::uint32_t maximum_metadata_entries = 1'000'000;
    constexpr std::uint32_t maximum_hotset_entries = 4096;
    constexpr std::size_t maximum_background_prepare_entries = 256U;
    constexpr std::size_t maximum_background_prepared_entries = 256U;
    constexpr std::uintmax_t maximum_persistence_bytes =
        std::uintmax_t { 4U } * 1024U * 1024U * 1024U;
    constexpr std::uint8_t lookup_state_consumed = 1U << 0U;
    constexpr std::uint8_t lookup_state_staged = 1U << 1U;
    constexpr std::uint8_t lookup_state_unused = 1U << 2U;
    constexpr std::uint8_t lookup_state_imported = 1U << 3U;
    std::atomic<std::uint64_t> next_context_id { 1 };

    template <typename T, typename Compare>
    [[nodiscard]] bool stable_sort_cancellable(std::vector<T>& values,
        Compare compare, const std::function<bool()>& cancelled)
    {
        if (values.size() < 2U)
            return !cancelled();
        std::vector<T> source = values;
        std::vector<T> output(values.size());
        for (std::size_t width = 1U; width < source.size();) {
            for (std::size_t left = 0U; left < source.size();
                left += width * 2U) {
                if (cancelled())
                    return false;
                const auto middle = std::min(left + width, source.size());
                const auto right = std::min(left + width * 2U, source.size());
                auto first = left;
                auto second = middle;
                auto destination = left;
                while (first < middle || second < right) {
                    if (cancelled())
                        return false;
                    if (first == middle) {
                        output[destination++] = source[second++];
                    } else if (second == right ||
                               !compare(source[second], source[first])) {
                        output[destination++] = source[first++];
                    } else {
                        output[destination++] = source[second++];
                    }
                }
            }
            source.swap(output);
            if (width > source.size() / 2U)
                break;
            width *= 2U;
        }
        values = std::move(source);
        return !cancelled();
    }

    [[nodiscard]] bool artifact_key_shape_valid(
        const JitArtifactKey& key) noexcept
    {
        const auto descriptor_pc =
            static_cast<std::uint32_t>(key.location_descriptor);
        const auto descriptor_thumb =
            ((key.location_descriptor >> 32U) & 1U) != 0U;
        return !key.content_identity.empty() && !key.layout_identity.empty() &&
               key.guest_pc == descriptor_pc && key.thumb == descriptor_thumb &&
               key.host_isa != JitHostIsa::Unknown &&
               key.architecture <= ArmArchitectureVersion::Armv7 &&
               key.cpu_model <= ArmCpuModelKind::CortexA9;
    }

    class ArtifactFileLock {
    public:
        enum class Mode { Shared, Exclusive };

        ArtifactFileLock(const ArtifactFileLock&) = delete;
        ArtifactFileLock& operator=(const ArtifactFileLock&) = delete;
        ArtifactFileLock(ArtifactFileLock&& other) noexcept
            : descriptor_ { std::exchange(other.descriptor_, -1) }
        {
        }
        ArtifactFileLock& operator=(ArtifactFileLock&& other) noexcept
        {
            if (this == &other)
                return *this;
            if (descriptor_ >= 0) {
                static_cast<void>(::flock(descriptor_, LOCK_UN));
                static_cast<void>(::close(descriptor_));
            }
            descriptor_ = std::exchange(other.descriptor_, -1);
            return *this;
        }
        ~ArtifactFileLock()
        {
            if (descriptor_ < 0)
                return;
            static_cast<void>(::flock(descriptor_, LOCK_UN));
            static_cast<void>(::close(descriptor_));
        }

        [[nodiscard]] static std::optional<ArtifactFileLock> acquire(
            const std::filesystem::path& persistence_path, Mode mode,
            bool nonblocking = false) noexcept
        {
            try {
                const auto lock_path = std::filesystem::path {
                    persistence_path.string() + ".writer.lock"
                };
                const auto parent = lock_path.parent_path();
                if (!parent.empty()) {
                    std::error_code directory_error;
                    std::filesystem::create_directories(
                        parent, directory_error);
                    if (directory_error)
                        return std::nullopt;
                }
                const auto descriptor = ::open(
                    lock_path.c_str(), O_CREAT | O_RDWR | O_CLOEXEC, 0600);
                if (descriptor < 0)
                    return std::nullopt;
                auto operation = mode == Mode::Exclusive ? LOCK_EX : LOCK_SH;
                if (nonblocking)
                    operation |= LOCK_NB;
                if (::flock(descriptor, operation) != 0) {
                    static_cast<void>(::close(descriptor));
                    return std::nullopt;
                }
                return ArtifactFileLock { descriptor };
            } catch (...) {
                return std::nullopt;
            }
        }

        [[nodiscard]] std::optional<std::uint64_t> generation() const noexcept
        {
            std::array<std::byte, sizeof(std::uint64_t)> bytes { };
            const auto count =
                ::pread(descriptor_, bytes.data(), bytes.size(), 0);
            if (count == 0)
                return 0U;
            if (count != static_cast<ssize_t>(bytes.size()))
                return std::nullopt;
            std::uint64_t result = 0;
            for (unsigned index = 0; index < bytes.size(); ++index) {
                result |= static_cast<std::uint64_t>(
                              std::to_integer<std::uint8_t>(bytes[index]))
                          << (index * 8U);
            }
            return result;
        }

        [[nodiscard]] std::optional<std::uint64_t> begin_write() const noexcept
        {
            const auto current = generation();
            if (!current ||
                *current == std::numeric_limits<std::uint64_t>::max()) {
                return std::nullopt;
            }
            const auto next = *current + 1U;
            std::array<std::byte, sizeof(next)> bytes { };
            for (unsigned index = 0; index < bytes.size(); ++index) {
                bytes[index] = static_cast<std::byte>(next >> (index * 8U));
            }
            if (::pwrite(descriptor_, bytes.data(), bytes.size(), 0) !=
                    static_cast<ssize_t>(bytes.size()) ||
                ::ftruncate(descriptor_, static_cast<off_t>(bytes.size())) !=
                    0 ||
                ::fsync(descriptor_) != 0) {
                return std::nullopt;
            }
            return next;
        }

    private:
        explicit ArtifactFileLock(int descriptor)
            : descriptor_ { descriptor }
        {
        }
        int descriptor_ { -1 };
    };

    class ArtifactReadHandle {
    public:
        ArtifactReadHandle(const ArtifactReadHandle&) = delete;
        ArtifactReadHandle& operator=(const ArtifactReadHandle&) = delete;
        ArtifactReadHandle(ArtifactReadHandle&& other) noexcept
            : descriptor_ { std::exchange(other.descriptor_, -1) }
        {
        }
        ArtifactReadHandle& operator=(ArtifactReadHandle&&) = delete;
        ~ArtifactReadHandle()
        {
            if (descriptor_ >= 0)
                static_cast<void>(::close(descriptor_));
        }

        [[nodiscard]] static std::optional<ArtifactReadHandle> open(
            const std::filesystem::path& path) noexcept
        {
            const auto descriptor = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
            if (descriptor < 0)
                return std::nullopt;
            return ArtifactReadHandle { descriptor };
        }

        [[nodiscard]] int descriptor() const noexcept { return descriptor_; }

        [[nodiscard]] std::ifstream stream() const
        {
            // Reopening the descriptor link retains the inode selected above
            // even if another process atomically replaces the cache path
            // between checksum and deserialization.
            std::ifstream result { std::filesystem::path {
                                       "/proc/self/fd/" +
                                       std::to_string(descriptor_) },
                std::ios::binary };
            if (result)
                return result;
            return std::ifstream { std::filesystem::path {
                                       "/dev/fd/" +
                                       std::to_string(descriptor_) },
                std::ios::binary };
        }

    private:
        explicit ArtifactReadHandle(int descriptor)
            : descriptor_ { descriptor }
        {
        }
        int descriptor_ { -1 };
    };

    void hash_bytes(
        std::size_t& hash, const void* data, std::size_t size) noexcept
    {
        const auto* bytes = static_cast<const std::byte*>(data);
        for (std::size_t index = 0; index < size; ++index) {
            hash ^= std::to_integer<std::uint8_t>(bytes[index]) +
                    static_cast<std::size_t>(0x9e3779b9U) + (hash << 6U) +
                    (hash >> 2U);
        }
    }

    template <typename T> void hash_scalar(std::size_t& hash, T value) noexcept
    {
        hash_bytes(hash, &value, sizeof(value));
    }

    void hash_identity(
        std::size_t& hash, const ContentIdentity& identity) noexcept
    {
        hash_bytes(hash, identity.digest.data(), identity.digest.size());
    }

    void write_u32(std::ostream& stream, std::uint32_t value)
    {
        for (unsigned shift = 0; shift < 32U; shift += 8U) {
            stream.put(static_cast<char>(value >> shift));
        }
    }

    void write_u64(std::ostream& stream, std::uint64_t value)
    {
        for (unsigned shift = 0; shift < 64U; shift += 8U) {
            stream.put(static_cast<char>(value >> shift));
        }
    }

    void append_u32(std::vector<std::byte>& bytes, std::uint32_t value)
    {
        for (unsigned shift = 0; shift < 32U; shift += 8U) {
            bytes.push_back(static_cast<std::byte>(value >> shift));
        }
    }

    void append_u64(std::vector<std::byte>& bytes, std::uint64_t value)
    {
        for (unsigned shift = 0; shift < 64U; shift += 8U) {
            bytes.push_back(static_cast<std::byte>(value >> shift));
        }
    }

    [[nodiscard]] std::optional<std::uint32_t> read_u32(std::istream& stream)
    {
        std::uint32_t value = 0;
        for (unsigned shift = 0; shift < 32U; shift += 8U) {
            const auto byte = stream.get();
            if (byte == std::char_traits<char>::eof())
                return std::nullopt;
            value |=
                static_cast<std::uint32_t>(static_cast<unsigned char>(byte))
                << shift;
        }
        return value;
    }

    [[nodiscard]] std::optional<std::uint64_t> read_u64(std::istream& stream)
    {
        std::uint64_t value = 0;
        for (unsigned shift = 0; shift < 64U; shift += 8U) {
            const auto byte = stream.get();
            if (byte == std::char_traits<char>::eof())
                return std::nullopt;
            value |=
                static_cast<std::uint64_t>(static_cast<unsigned char>(byte))
                << shift;
        }
        return value;
    }

    [[nodiscard]] std::optional<std::uint8_t> read_u8(std::istream& stream)
    {
        const auto byte = stream.get();
        if (byte == std::char_traits<char>::eof())
            return std::nullopt;
        return static_cast<std::uint8_t>(static_cast<unsigned char>(byte));
    }

    [[nodiscard]] bool read_zeroes(std::istream& stream, std::size_t count)
    {
        for (std::size_t index = 0; index < count; ++index) {
            const auto byte = read_u8(stream);
            if (!byte || *byte != 0U)
                return false;
        }
        return true;
    }

    void write_identity(std::ostream& stream, const ContentIdentity& identity)
    {
        stream.write(reinterpret_cast<const char*>(identity.digest.data()),
            static_cast<std::streamsize>(identity.digest.size()));
    }

    void append_identity(
        std::vector<std::byte>& bytes, const ContentIdentity& identity)
    {
        bytes.insert(
            bytes.end(), identity.digest.begin(), identity.digest.end());
    }

    [[nodiscard]] bool read_identity(
        std::istream& stream, ContentIdentity& identity)
    {
        stream.read(reinterpret_cast<char*>(identity.digest.data()),
            static_cast<std::streamsize>(identity.digest.size()));
        return static_cast<bool>(stream);
    }

    void write_key(std::ostream& stream, const JitArtifactKey& key)
    {
        write_identity(stream, key.content_identity);
        write_identity(stream, key.layout_identity);
        write_u32(stream, key.guest_pc);
        stream.put(static_cast<char>(key.thumb));
        write_u64(stream, key.location_descriptor);
        stream.put(static_cast<char>(key.architecture));
        stream.put(static_cast<char>(key.cpu_model));
        stream.put('\0');
        write_u32(stream, key.timing_model_version);
        write_u32(stream, key.guest_ticks_per_second);
        write_u32(stream, key.image_slide);
        write_u32(stream, key.hle_abi_version);
        write_u32(stream, key.backend_abi_version);
        write_u64(stream, key.umbra_build_fingerprint);
        write_u64(stream, key.codegen_options);
        stream.put(static_cast<char>(key.host_isa));
        stream.put('\0');
        stream.put('\0');
        stream.put('\0');
        write_u64(stream, key.host_feature_mask);
        write_u32(stream, key.artifact_format_version);
    }

    [[nodiscard]] std::string key_order_token(const JitArtifactKey& key)
    {
        std::ostringstream stream { std::ios::out | std::ios::binary };
        write_key(stream, key);
        return stream.str();
    }

    [[nodiscard]] std::optional<JitArtifactKey> read_key(std::istream& stream)
    {
        JitArtifactKey key;
        if (!read_identity(stream, key.content_identity) ||
            !read_identity(stream, key.layout_identity)) {
            return std::nullopt;
        }
        const auto guest_pc = read_u32(stream);
        if (!guest_pc)
            return std::nullopt;
        key.guest_pc = *guest_pc;
        const auto thumb = stream.get();
        if (thumb == std::char_traits<char>::eof())
            return std::nullopt;
        key.thumb = thumb != 0;
        const auto location_descriptor = read_u64(stream);
        if (!location_descriptor)
            return std::nullopt;
        key.location_descriptor = *location_descriptor;
        const auto architecture = stream.get();
        const auto cpu_model = stream.get();
        if (thumb == std::char_traits<char>::eof() ||
            architecture == std::char_traits<char>::eof() ||
            cpu_model == std::char_traits<char>::eof() ||
            stream.get() == std::char_traits<char>::eof()) {
            return std::nullopt;
        }
        key.architecture = static_cast<ArmArchitectureVersion>(architecture);
        key.cpu_model = static_cast<ArmCpuModelKind>(cpu_model);
        const auto timing = read_u32(stream);
        const auto ticks = read_u32(stream);
        const auto slide = read_u32(stream);
        const auto hle = read_u32(stream);
        const auto backend = read_u32(stream);
        const auto umbra = read_u64(stream);
        const auto options = read_u64(stream);
        if (!timing || !ticks || !slide || !hle || !backend || !umbra ||
            !options) {
            return std::nullopt;
        }
        key.timing_model_version = *timing;
        key.guest_ticks_per_second = *ticks;
        key.image_slide = *slide;
        key.hle_abi_version = *hle;
        key.backend_abi_version = *backend;
        key.umbra_build_fingerprint = *umbra;
        key.codegen_options = *options;
        const auto host_isa = stream.get();
        if (host_isa == std::char_traits<char>::eof() ||
            stream.get() == std::char_traits<char>::eof() ||
            stream.get() == std::char_traits<char>::eof() ||
            stream.get() == std::char_traits<char>::eof()) {
            return std::nullopt;
        }
        key.host_isa = static_cast<JitHostIsa>(host_isa);
        const auto host_features = read_u64(stream);
        const auto format = read_u32(stream);
        if (!host_features || !format)
            return std::nullopt;
        key.host_feature_mask = *host_features;
        key.artifact_format_version = *format;
        if (!artifact_key_shape_valid(key)) {
            return std::nullopt;
        }
        return key;
    }

    struct SnapshotArtifactEntry {
        JitArtifactKey key;
        std::uint64_t offset { };
        std::uint64_t serialized_bytes { };
        ContentIdentity checksum;
    };

    struct SnapshotArtifactWriteEntry {
        const JitArtifactKey* key { };
        std::uint64_t offset { };
        std::uint64_t serialized_bytes { };
        ContentIdentity checksum;
    };

    struct SnapshotIndexRead {
        std::vector<SnapshotArtifactEntry> entries;
        std::uint64_t index_bytes { };
        ContentIdentity snapshot_id;
    };

    [[nodiscard]] const JitArtifactKey* snapshot_artifact_key(
        const SnapshotArtifactEntry& entry) noexcept
    {
        return &entry.key;
    }

    [[nodiscard]] const JitArtifactKey* snapshot_artifact_key(
        const SnapshotArtifactWriteEntry& entry) noexcept
    {
        return entry.key;
    }

    struct ArtifactIndexImage {
        ContentIdentity content_identity;
        ContentIdentity layout_identity;
        std::uint32_t image_slide { };

        friend bool operator==(
            const ArtifactIndexImage&, const ArtifactIndexImage&) = default;
    };

    struct ArtifactIndexImageHash {
        [[nodiscard]] std::size_t operator()(
            const ArtifactIndexImage& image) const noexcept
        {
            std::size_t hash = 0;
            hash_identity(hash, image.content_identity);
            hash_identity(hash, image.layout_identity);
            hash_scalar(hash, image.image_slide);
            return hash;
        }
    };

    struct ArtifactIndexProfile {
        ArmArchitectureVersion architecture { ArmArchitectureVersion::Armv6K };
        ArmCpuModelKind cpu_model { ArmCpuModelKind::Arm1176JzfS };
        std::uint32_t timing_model_version { };
        std::uint32_t guest_ticks_per_second { };
        std::uint32_t hle_abi_version { };
        std::uint32_t backend_abi_version { };
        std::uint64_t umbra_build_fingerprint { };
        std::uint64_t codegen_options { };
        JitHostIsa host_isa { JitHostIsa::Unknown };
        std::uint64_t host_feature_mask { };
        std::uint32_t artifact_format_version { };

        friend bool operator==(
            const ArtifactIndexProfile&, const ArtifactIndexProfile&) = default;
    };

    struct ArtifactIndexProfileHash {
        [[nodiscard]] std::size_t operator()(
            const ArtifactIndexProfile& profile) const noexcept
        {
            std::size_t hash = 0;
            hash_scalar(hash, profile.architecture);
            hash_scalar(hash, profile.cpu_model);
            hash_scalar(hash, profile.timing_model_version);
            hash_scalar(hash, profile.guest_ticks_per_second);
            hash_scalar(hash, profile.hle_abi_version);
            hash_scalar(hash, profile.backend_abi_version);
            hash_scalar(hash, profile.umbra_build_fingerprint);
            hash_scalar(hash, profile.codegen_options);
            hash_scalar(hash, profile.host_isa);
            hash_scalar(hash, profile.host_feature_mask);
            hash_scalar(hash, profile.artifact_format_version);
            return hash;
        }
    };

    struct CompactIndexReference {
        std::uint32_t image { };
        std::uint32_t profile { };
        std::uint32_t guest_pc { };
        bool thumb { };
        std::uint64_t location_descriptor { };
    };

    struct CompactIndexLayout {
        std::vector<ArtifactIndexImage> images;
        std::vector<ArtifactIndexProfile> profiles;
        std::vector<CompactIndexReference> references;

        [[nodiscard]] std::optional<std::size_t>
        serialized_bytes() const noexcept
        {
            if (images.size() > maximum_artifacts ||
                profiles.size() > maximum_artifacts ||
                references.size() > maximum_artifacts) {
                return std::nullopt;
            }
            auto result = artifact_index_v2_header_bytes;
            const auto add = [&result](std::size_t count, std::size_t bytes) {
                if (count > (std::numeric_limits<std::size_t>::max() - result) /
                                bytes) {
                    return false;
                }
                result += count * bytes;
                return true;
            };
            if (!add(images.size(), artifact_index_image_bytes) ||
                !add(profiles.size(), artifact_index_profile_bytes) ||
                !add(references.size(), artifact_index_v2_entry_bytes)) {
                return std::nullopt;
            }
            return result;
        }
    };

    [[nodiscard]] ArtifactIndexImage index_image_for(const JitArtifactKey& key)
    {
        return ArtifactIndexImage { key.content_identity, key.layout_identity,
            key.image_slide };
    }

    [[nodiscard]] ArtifactIndexProfile index_profile_for(
        const JitArtifactKey& key)
    {
        return ArtifactIndexProfile { key.architecture, key.cpu_model,
            key.timing_model_version, key.guest_ticks_per_second,
            key.hle_abi_version, key.backend_abi_version,
            key.umbra_build_fingerprint, key.codegen_options, key.host_isa,
            key.host_feature_mask, key.artifact_format_version };
    }

    [[nodiscard]] std::optional<CompactIndexLayout> build_compact_index_layout(
        std::span<const JitArtifactKey* const> keys,
        const std::function<bool()>& cancellation_check = { })
    {
        if (keys.size() > maximum_artifacts)
            return std::nullopt;
        CompactIndexLayout result;
        result.images.reserve(std::min<std::size_t>(keys.size(), 1024U));
        result.profiles.reserve(std::min<std::size_t>(keys.size(), 16U));
        result.references.reserve(keys.size());
        std::unordered_map<ArtifactIndexImage, std::uint32_t,
            ArtifactIndexImageHash>
            images;
        std::unordered_map<ArtifactIndexProfile, std::uint32_t,
            ArtifactIndexProfileHash>
            profiles;
        images.reserve(std::min<std::size_t>(keys.size(), 1024U));
        profiles.reserve(std::min<std::size_t>(keys.size(), 16U));
        for (std::size_t key_index = 0; key_index < keys.size(); ++key_index) {
            if ((key_index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return std::nullopt;
            }
            const auto* key = keys[key_index];
            if (key == nullptr)
                return std::nullopt;
            const auto image = index_image_for(*key);
            auto image_index = images.find(image);
            if (image_index == images.end()) {
                if (result.images.size() >= maximum_artifacts)
                    return std::nullopt;
                const auto index =
                    static_cast<std::uint32_t>(result.images.size());
                result.images.push_back(image);
                image_index = images.emplace(image, index).first;
            }
            const auto profile = index_profile_for(*key);
            auto profile_index = profiles.find(profile);
            if (profile_index == profiles.end()) {
                if (result.profiles.size() >= maximum_artifacts)
                    return std::nullopt;
                const auto index =
                    static_cast<std::uint32_t>(result.profiles.size());
                result.profiles.push_back(profile);
                profile_index = profiles.emplace(profile, index).first;
            }
            result.references.push_back(CompactIndexReference {
                image_index->second, profile_index->second, key->guest_pc,
                key->thumb, key->location_descriptor });
        }
        if (!result.serialized_bytes())
            return std::nullopt;
        return result;
    }

    template <typename Entry>
    [[nodiscard]] std::optional<std::vector<std::byte>>
    encode_compact_index_impl(const CompactIndexLayout& layout,
        std::span<const Entry> entries,
        const std::function<bool()>& cancellation_check = { })
    {
        const auto serialized_bytes = layout.serialized_bytes();
        if (!serialized_bytes || entries.size() != layout.references.size()) {
            return std::nullopt;
        }
        std::vector<std::byte> result;
        result.reserve(*serialized_bytes);
        for (const auto byte : artifact_index_magic_v2) {
            result.push_back(static_cast<std::byte>(byte));
        }
        append_u32(result, static_cast<std::uint32_t>(entries.size()));
        append_u32(result, static_cast<std::uint32_t>(layout.images.size()));
        append_u32(result, static_cast<std::uint32_t>(layout.profiles.size()));
        for (std::size_t image_index = 0; image_index < layout.images.size();
            ++image_index) {
            if ((image_index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return std::nullopt;
            }
            const auto& image = layout.images[image_index];
            append_identity(result, image.content_identity);
            append_identity(result, image.layout_identity);
            append_u32(result, image.image_slide);
        }
        for (std::size_t profile_index = 0;
            profile_index < layout.profiles.size(); ++profile_index) {
            if ((profile_index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return std::nullopt;
            }
            const auto& profile = layout.profiles[profile_index];
            result.push_back(static_cast<std::byte>(profile.architecture));
            result.push_back(static_cast<std::byte>(profile.cpu_model));
            result.insert(result.end(), 2U, std::byte { });
            append_u32(result, profile.timing_model_version);
            append_u32(result, profile.guest_ticks_per_second);
            append_u32(result, profile.hle_abi_version);
            append_u32(result, profile.backend_abi_version);
            append_u64(result, profile.umbra_build_fingerprint);
            append_u64(result, profile.codegen_options);
            result.push_back(static_cast<std::byte>(profile.host_isa));
            result.insert(result.end(), 3U, std::byte { });
            append_u64(result, profile.host_feature_mask);
            append_u32(result, profile.artifact_format_version);
        }
        for (std::size_t index = 0; index < entries.size(); ++index) {
            if ((index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return std::nullopt;
            }
            const auto& reference = layout.references[index];
            const auto& entry = entries[index];
            const auto* key = snapshot_artifact_key(entry);
            if (key == nullptr || reference.image >= layout.images.size() ||
                reference.profile >= layout.profiles.size() ||
                index_image_for(*key) != layout.images[reference.image] ||
                index_profile_for(*key) != layout.profiles[reference.profile] ||
                key->guest_pc != reference.guest_pc ||
                key->thumb != reference.thumb ||
                key->location_descriptor != reference.location_descriptor) {
                return std::nullopt;
            }
            append_u32(result, reference.image);
            append_u32(result, reference.guest_pc);
            result.push_back(static_cast<std::byte>(reference.thumb));
            result.insert(result.end(), 3U, std::byte { });
            append_u64(result, reference.location_descriptor);
            append_u32(result, reference.profile);
            append_u64(result, entry.offset);
            append_u64(result, entry.serialized_bytes);
            append_identity(result, entry.checksum);
        }
        if (result.size() != *serialized_bytes)
            return std::nullopt;
        return result;
    }

    [[nodiscard]] std::optional<std::vector<std::byte>> encode_compact_index(
        const CompactIndexLayout& layout,
        std::span<const SnapshotArtifactEntry> entries,
        const std::function<bool()>& cancellation_check = { })
    {
        return encode_compact_index_impl(layout, entries, cancellation_check);
    }

    [[nodiscard]] std::optional<std::vector<std::byte>> encode_compact_index(
        const CompactIndexLayout& layout,
        std::span<const SnapshotArtifactWriteEntry> entries,
        const std::function<bool()>& cancellation_check = { })
    {
        return encode_compact_index_impl(layout, entries, cancellation_check);
    }

    [[nodiscard]] std::optional<std::vector<std::byte>> read_bytes(
        std::istream& stream, std::uint32_t count)
    {
        if (count > maximum_ir_bytes)
            return std::nullopt;
        std::vector<std::byte> bytes(count);
        stream.read(reinterpret_cast<char*>(bytes.data()),
            static_cast<std::streamsize>(bytes.size()));
        if (!stream)
            return std::nullopt;
        return bytes;
    }

    [[nodiscard]] std::optional<std::size_t> serialized_artifact_bytes(
        std::size_t normalized_ir_bytes, std::size_t relocation_count,
        std::size_t exit_count, std::size_t dependency_count,
        std::size_t constant_dependency_count)
    {
        if (normalized_ir_bytes > maximum_ir_bytes ||
            relocation_count > maximum_metadata_entries ||
            exit_count > maximum_metadata_entries) {
            return std::nullopt;
        }
        constexpr std::size_t serialized_data_header_bytes = 32U;
        constexpr std::size_t serialized_dependency_bytes = 72U;
        constexpr std::size_t serialized_constant_dependency_bytes = 80U;
        if (dependency_count > maximum_metadata_entries ||
            dependency_count > std::numeric_limits<std::size_t>::max() /
                                   serialized_dependency_bytes ||
            constant_dependency_count > maximum_metadata_entries ||
            constant_dependency_count >
                std::numeric_limits<std::size_t>::max() /
                    serialized_constant_dependency_bytes) {
            return std::nullopt;
        }
        std::size_t size = serialized_key_bytes + serialized_data_header_bytes;
        const auto add = [&size](std::size_t value) {
            if (value > std::numeric_limits<std::size_t>::max() - size) {
                return false;
            }
            size += value;
            return true;
        };
        return add(normalized_ir_bytes) &&
                       add(relocation_count * sizeof(std::uint64_t)) &&
                       add(exit_count * sizeof(std::uint64_t)) &&
                       add(dependency_count * serialized_dependency_bytes) &&
                       add(constant_dependency_count *
                           serialized_constant_dependency_bytes)
                   ? std::optional<std::size_t> { size }
                   : std::nullopt;
    }

    [[nodiscard]] std::optional<std::size_t> serialized_artifact_bytes(
        const JitArtifactData& data)
    {
        return serialized_artifact_bytes(data.normalized_ir.size(),
            data.relocation_targets.size(), data.exit_locations.size(),
            data.code_dependencies.size(), data.constant_dependencies.size());
    }

    [[nodiscard]] bool skip_bytes(
        std::istream& stream, std::uint64_t count, std::uint64_t payload_size)
    {
        const auto current = stream.tellg();
        if (current < 0)
            return false;
        const auto current_offset = static_cast<std::uint64_t>(current);
        if (current_offset > payload_size ||
            count > payload_size - current_offset ||
            count > static_cast<std::uint64_t>(
                        std::numeric_limits<std::streamoff>::max())) {
            return false;
        }
        stream.seekg(static_cast<std::streamoff>(count), std::ios::cur);
        return stream && stream.tellg() == static_cast<std::streamoff>(
                                               current_offset + count);
    }

    struct ArtifactMetadata {
        JitArtifactKey key;
        std::uint64_t serialized_bytes { };
    };

    [[nodiscard]] std::optional<ArtifactMetadata> read_artifact_metadata(
        std::istream& stream, std::uint64_t record_offset,
        std::uint64_t payload_size)
    {
        const auto key = read_key(stream);
        const auto ir_size = read_u32(stream);
        const auto relocation_count = read_u32(stream);
        const auto exit_count = read_u32(stream);
        const auto dependency_count = read_u32(stream);
        const auto constant_dependency_count = read_u32(stream);
        const auto instruction_count = read_u32(stream);
        const auto translation_nanoseconds = read_u64(stream);
        if (!key || !ir_size || !relocation_count || !exit_count ||
            !dependency_count || !constant_dependency_count ||
            !instruction_count || !translation_nanoseconds ||
            *relocation_count > maximum_metadata_entries ||
            *exit_count > maximum_metadata_entries ||
            *dependency_count > maximum_metadata_entries ||
            *constant_dependency_count > maximum_metadata_entries) {
            return std::nullopt;
        }
        const auto record_bytes =
            serialized_artifact_bytes(*ir_size, *relocation_count, *exit_count,
                *dependency_count, *constant_dependency_count);
        if (!record_bytes ||
            *record_bytes > std::numeric_limits<std::uint64_t>::max() ||
            record_offset >
                std::numeric_limits<std::uint64_t>::max() - *record_bytes) {
            return std::nullopt;
        }
        if (!skip_bytes(stream, *ir_size, payload_size) ||
            !skip_bytes(stream,
                static_cast<std::uint64_t>(*relocation_count) *
                    sizeof(std::uint64_t),
                payload_size) ||
            !skip_bytes(stream,
                static_cast<std::uint64_t>(*exit_count) * sizeof(std::uint64_t),
                payload_size)) {
            return std::nullopt;
        }
        for (std::uint32_t index = 0; index < *dependency_count; ++index) {
            const auto address = read_u32(stream);
            const auto size = read_u32(stream);
            if (!address || !size || *size == 0 ||
                !skip_bytes(
                    stream, ContentIdentity { }.digest.size(), payload_size) ||
                !skip_bytes(
                    stream, ContentIdentity { }.digest.size(), payload_size)) {
                return std::nullopt;
            }
        }
        for (std::uint32_t index = 0; index < *constant_dependency_count;
            ++index) {
            const auto address = read_u32(stream);
            const auto size = read_u32(stream);
            const auto value = read_u64(stream);
            if (!address || !size || *size == 0 || !value ||
                !skip_bytes(
                    stream, ContentIdentity { }.digest.size(), payload_size) ||
                !skip_bytes(
                    stream, ContentIdentity { }.digest.size(), payload_size)) {
                return std::nullopt;
            }
        }
        const auto end = stream.tellg();
        if (end < 0 || static_cast<std::uint64_t>(end) < record_offset ||
            static_cast<std::uint64_t>(end) - record_offset != *record_bytes) {
            return std::nullopt;
        }
        return ArtifactMetadata { *key,
            static_cast<std::uint64_t>(*record_bytes) };
    }

    [[nodiscard]] std::optional<std::vector<SnapshotArtifactEntry>>
    read_artifact_index(std::istream& stream, std::uint64_t index_offset,
        std::uint64_t index_bytes, std::uint32_t expected_count,
        std::uint64_t records_begin, std::uint64_t records_end)
    {
        if (index_offset > static_cast<std::uint64_t>(
                               std::numeric_limits<std::streamoff>::max()) ||
            index_bytes > static_cast<std::uint64_t>(
                              std::numeric_limits<std::streamoff>::max()) ||
            index_offset >
                std::numeric_limits<std::uint64_t>::max() - index_bytes) {
            return std::nullopt;
        }
        stream.clear();
        stream.seekg(static_cast<std::streamoff>(index_offset));
        std::array<char, artifact_index_magic_v1.size()> index_magic { };
        stream.read(index_magic.data(),
            static_cast<std::streamsize>(index_magic.size()));
        if (!stream)
            return std::nullopt;

        const auto maximum_record_bytes =
            serialized_artifact_bytes(maximum_ir_bytes,
                maximum_metadata_entries, maximum_metadata_entries,
                maximum_metadata_entries, maximum_metadata_entries);
        if (!maximum_record_bytes)
            return std::nullopt;
        std::vector<SnapshotArtifactEntry> entries;
        entries.reserve(expected_count);
        std::uint64_t expected_record_offset = records_begin;
        const auto append_entry = [&](JitArtifactKey key,
                                      std::uint64_t record_offset,
                                      std::uint64_t record_bytes,
                                      ContentIdentity checksum) {
            if (record_bytes == 0U || record_bytes > *maximum_record_bytes ||
                record_offset != expected_record_offset ||
                record_offset > records_end ||
                record_bytes > records_end - record_offset) {
                return false;
            }
            expected_record_offset += record_bytes;
            entries.push_back(SnapshotArtifactEntry {
                std::move(key), record_offset, record_bytes, checksum });
            return true;
        };

        if (index_magic == artifact_index_magic_v1) {
            const auto index_count = read_u32(stream);
            const auto expected_bytes =
                static_cast<std::uint64_t>(artifact_index_v1_header_bytes) +
                static_cast<std::uint64_t>(expected_count) *
                    artifact_index_v1_entry_bytes;
            if (!index_count || *index_count != expected_count ||
                index_bytes != expected_bytes) {
                return std::nullopt;
            }
            for (std::uint32_t index = 0; index < *index_count; ++index) {
                const auto key = read_key(stream);
                const auto record_offset = read_u64(stream);
                const auto record_bytes = read_u64(stream);
                ContentIdentity checksum;
                if (!key || !record_offset || !record_bytes ||
                    !read_identity(stream, checksum) ||
                    !append_entry(
                        *key, *record_offset, *record_bytes, checksum)) {
                    return std::nullopt;
                }
            }
        } else if (index_magic == artifact_index_magic_v2) {
            const auto index_count = read_u32(stream);
            const auto image_count = read_u32(stream);
            const auto profile_count = read_u32(stream);
            if (!index_count || !image_count || !profile_count ||
                *index_count != expected_count ||
                *image_count > expected_count ||
                *profile_count > expected_count ||
                (expected_count != 0U &&
                    (*image_count == 0U || *profile_count == 0U))) {
                return std::nullopt;
            }
            const auto expected_bytes =
                static_cast<std::uint64_t>(artifact_index_v2_header_bytes) +
                static_cast<std::uint64_t>(*image_count) *
                    artifact_index_image_bytes +
                static_cast<std::uint64_t>(*profile_count) *
                    artifact_index_profile_bytes +
                static_cast<std::uint64_t>(*index_count) *
                    artifact_index_v2_entry_bytes;
            if (index_bytes != expected_bytes)
                return std::nullopt;

            std::vector<ArtifactIndexImage> images;
            images.reserve(*image_count);
            for (std::uint32_t index = 0; index < *image_count; ++index) {
                ArtifactIndexImage image;
                const auto slide = [&] {
                    if (!read_identity(stream, image.content_identity) ||
                        !read_identity(stream, image.layout_identity)) {
                        return std::optional<std::uint32_t> { };
                    }
                    return read_u32(stream);
                }();
                if (!slide)
                    return std::nullopt;
                image.image_slide = *slide;
                images.push_back(std::move(image));
            }
            std::vector<ArtifactIndexProfile> profiles;
            profiles.reserve(*profile_count);
            for (std::uint32_t index = 0; index < *profile_count; ++index) {
                const auto architecture = read_u8(stream);
                const auto cpu_model = read_u8(stream);
                if (!architecture || !cpu_model || !read_zeroes(stream, 2U)) {
                    return std::nullopt;
                }
                const auto timing = read_u32(stream);
                const auto ticks = read_u32(stream);
                const auto hle = read_u32(stream);
                const auto backend = read_u32(stream);
                const auto umbra = read_u64(stream);
                const auto options = read_u64(stream);
                const auto host_isa = read_u8(stream);
                if (!timing || !ticks || !hle || !backend || !umbra ||
                    !options || !host_isa || !read_zeroes(stream, 3U)) {
                    return std::nullopt;
                }
                const auto host_features = read_u64(stream);
                const auto format = read_u32(stream);
                if (!host_features || !format ||
                    *architecture > static_cast<std::uint8_t>(
                                        ArmArchitectureVersion::Armv7) ||
                    *cpu_model >
                        static_cast<std::uint8_t>(ArmCpuModelKind::CortexA9) ||
                    *host_isa > static_cast<std::uint8_t>(JitHostIsa::Arm64)) {
                    return std::nullopt;
                }
                profiles.push_back(ArtifactIndexProfile {
                    static_cast<ArmArchitectureVersion>(*architecture),
                    static_cast<ArmCpuModelKind>(*cpu_model), *timing, *ticks,
                    *hle, *backend, *umbra, *options,
                    static_cast<JitHostIsa>(*host_isa), *host_features,
                    *format });
            }
            for (std::uint32_t index = 0; index < *index_count; ++index) {
                const auto image_index = read_u32(stream);
                const auto guest_pc = read_u32(stream);
                const auto thumb = read_u8(stream);
                if (!image_index || !guest_pc || !thumb || *thumb > 1U ||
                    !read_zeroes(stream, 3U)) {
                    return std::nullopt;
                }
                const auto location_descriptor = read_u64(stream);
                const auto profile_index = read_u32(stream);
                const auto record_offset = read_u64(stream);
                const auto record_bytes = read_u64(stream);
                ContentIdentity checksum;
                if (!location_descriptor || !profile_index || !record_offset ||
                    !record_bytes || !read_identity(stream, checksum) ||
                    *image_index >= images.size() ||
                    *profile_index >= profiles.size()) {
                    return std::nullopt;
                }
                const auto& image = images[*image_index];
                const auto& profile = profiles[*profile_index];
                JitArtifactKey key;
                key.content_identity = image.content_identity;
                key.layout_identity = image.layout_identity;
                key.guest_pc = *guest_pc;
                key.thumb = *thumb != 0U;
                key.location_descriptor = *location_descriptor;
                key.architecture = profile.architecture;
                key.cpu_model = profile.cpu_model;
                key.timing_model_version = profile.timing_model_version;
                key.guest_ticks_per_second = profile.guest_ticks_per_second;
                key.image_slide = image.image_slide;
                key.hle_abi_version = profile.hle_abi_version;
                key.backend_abi_version = profile.backend_abi_version;
                key.umbra_build_fingerprint =
                    profile.umbra_build_fingerprint;
                key.codegen_options = profile.codegen_options;
                key.host_isa = profile.host_isa;
                key.host_feature_mask = profile.host_feature_mask;
                key.artifact_format_version = profile.artifact_format_version;
                if (!append_entry(std::move(key), *record_offset, *record_bytes,
                        checksum)) {
                    return std::nullopt;
                }
            }
        } else {
            return std::nullopt;
        }

        if (entries.size() != expected_count ||
            expected_record_offset != records_end ||
            stream.tellg() !=
                static_cast<std::streamoff>(index_offset + index_bytes)) {
            return std::nullopt;
        }
        return entries;
    }

    [[nodiscard]] std::optional<SnapshotIndexRead> read_snapshot_index(
        const std::filesystem::path& path, std::uint64_t file_size)
    {
        if (file_size < artifact_header_bytes + artifact_index_v1_header_bytes +
                            artifact_footer_bytes) {
            return std::nullopt;
        }
        auto source = ArtifactReadHandle::open(path);
        if (!source)
            return std::nullopt;
        auto stream = source->stream();
        if (!stream)
            return std::nullopt;
        std::array<char, artifact_magic.size()> magic { };
        stream.read(magic.data(), static_cast<std::streamsize>(magic.size()));
        const auto header_count = read_u32(stream);
        if (!stream || magic != artifact_magic || !header_count ||
            *header_count > maximum_artifacts) {
            return std::nullopt;
        }

        const auto footer_offset = file_size - artifact_footer_bytes;
        if (footer_offset > static_cast<std::uint64_t>(
                                std::numeric_limits<std::streamoff>::max())) {
            return std::nullopt;
        }
        stream.seekg(static_cast<std::streamoff>(footer_offset));
        std::array<char, artifact_footer_magic.size()> footer_magic { };
        stream.read(footer_magic.data(),
            static_cast<std::streamsize>(footer_magic.size()));
        const auto index_offset = read_u64(stream);
        const auto index_bytes = read_u64(stream);
        const auto footer_count = read_u32(stream);
        ContentIdentity expected_index_checksum;
        if (!index_offset || !index_bytes || !footer_count ||
            !read_identity(stream, expected_index_checksum) ||
            footer_magic != artifact_footer_magic ||
            *footer_count != *header_count) {
            return std::nullopt;
        }
        if (*index_offset < artifact_header_bytes ||
            *index_offset > footer_offset ||
            *index_bytes != footer_offset - *index_offset) {
            return std::nullopt;
        }
        const auto actual_index_checksum =
            sha256_file(source->descriptor(), *index_offset, *index_bytes);
        if (!actual_index_checksum ||
            *actual_index_checksum != expected_index_checksum ||
            *index_offset > static_cast<std::uint64_t>(
                                std::numeric_limits<std::streamoff>::max())) {
            return std::nullopt;
        }

        const auto entries = read_artifact_index(stream, *index_offset,
            *index_bytes, *header_count, artifact_header_bytes, *index_offset);
        if (!entries)
            return std::nullopt;
        return SnapshotIndexRead { std::move(*entries), *index_bytes,
            *actual_index_checksum };
    }

    [[nodiscard]] std::filesystem::path current_snapshot_path(
        const std::filesystem::path& path)
    {
        // F7 is intentionally not layout-compatible with prior snapshots. Keep
        // an unrecognized user cache and its journal intact while all current
        // writers converge on the same versioned sibling.
        std::error_code error;
        if (!std::filesystem::exists(path, error) || error)
            return path;
        std::ifstream stream { path, std::ios::binary };
        std::array<char, artifact_magic.size()> magic { };
        if (stream) {
            stream.read(
                magic.data(), static_cast<std::streamsize>(magic.size()));
            if (stream && magic == artifact_magic)
                return path;
        }
        return std::filesystem::path { path.string() + ".indexed-v1" };
    }

    [[nodiscard]] std::filesystem::path append_path_for(
        const std::filesystem::path& path)
    {
        return std::filesystem::path { path.string() + ".append" };
    }

    [[nodiscard]] std::filesystem::path hotset_path_for(
        const std::filesystem::path& path)
    {
        return std::filesystem::path { path.string() + ".hotset" };
    }

    [[nodiscard]] std::optional<std::vector<JitArtifactKey>> read_hotset(
        const std::filesystem::path& path,
        const ContentIdentity& expected_snapshot_id)
    {
        std::error_code error;
        const auto file_size = std::filesystem::file_size(path, error);
        if (error || expected_snapshot_id.empty() ||
            file_size <
                artifact_hotset_header_bytes + artifact_checksum_bytes ||
            file_size >
                artifact_hotset_header_bytes +
                    static_cast<std::uintmax_t>(maximum_hotset_entries) *
                        serialized_key_bytes +
                    artifact_checksum_bytes ||
            file_size > std::numeric_limits<std::size_t>::max()) {
            return std::nullopt;
        }
        std::ifstream input { path, std::ios::binary };
        if (!input)
            return std::nullopt;
        std::vector<std::byte> bytes(static_cast<std::size_t>(file_size));
        input.read(reinterpret_cast<char*>(bytes.data()),
            static_cast<std::streamsize>(bytes.size()));
        if (!input ||
            input.gcount() != static_cast<std::streamsize>(bytes.size())) {
            return std::nullopt;
        }

        const auto payload_size = bytes.size() - artifact_checksum_bytes;
        ContentIdentity expected_checksum;
        std::copy_n(bytes.begin() + static_cast<std::ptrdiff_t>(payload_size),
            expected_checksum.digest.size(), expected_checksum.digest.begin());
        const auto actual_checksum =
            sha256(std::span<const std::byte> { bytes.data(), payload_size });
        if (actual_checksum != expected_checksum)
            return std::nullopt;

        const std::string encoded_payload {
            reinterpret_cast<const char*>(bytes.data()), payload_size
        };
        std::istringstream stream { encoded_payload,
            std::ios::in | std::ios::binary };
        std::array<char, artifact_hotset_magic_v2.size()> magic { };
        stream.read(magic.data(), static_cast<std::streamsize>(magic.size()));
        const auto schema = read_u32(stream);
        ContentIdentity snapshot_id;
        const auto snapshot_read = read_identity(stream, snapshot_id);
        const auto count = read_u32(stream);
        if (!stream || magic != artifact_hotset_magic_v2 || !schema ||
            *schema != artifact_hotset_schema_v2 || !snapshot_read || !count ||
            *count > maximum_hotset_entries ||
            snapshot_id != expected_snapshot_id) {
            return std::nullopt;
        }
        const auto expected_size =
            artifact_hotset_header_bytes +
            static_cast<std::uint64_t>(*count) * serialized_key_bytes;
        if (expected_size != payload_size)
            return std::nullopt;
        std::vector<JitArtifactKey> result;
        result.reserve(*count);
        std::unordered_set<JitArtifactKey, JitArtifactKeyHash> seen;
        seen.reserve(*count);
        for (std::uint32_t index = 0; index < *count; ++index) {
            const auto key = read_key(stream);
            if (!key || !seen.insert(*key).second)
                return std::nullopt;
            result.push_back(*key);
        }
        if (stream.tellg() != static_cast<std::streamoff>(payload_size)) {
            return std::nullopt;
        }
        return result;
    }

    [[nodiscard]] bool has_storage_headroom(const std::filesystem::path& path,
        std::uintmax_t minimum_free_bytes, std::uintmax_t additional_bytes)
    {
        if (minimum_free_bytes == 0U)
            return true;
        std::error_code error;
        auto candidate = std::filesystem::absolute(path, error);
        if (error || candidate.empty())
            candidate = path;
        for (;;) {
            const auto status = std::filesystem::status(candidate, error);
            if (!error &&
                status.type() != std::filesystem::file_type::not_found) {
                break;
            }
            const auto parent = candidate.parent_path();
            if (parent.empty() || parent == candidate)
                return false;
            candidate = parent;
            error.clear();
        }
        const auto space = std::filesystem::space(candidate, error);
        if (error || space.available < minimum_free_bytes)
            return false;
        return additional_bytes <= space.available - minimum_free_bytes;
    }

    struct JournalArtifactEntry {
        JitArtifactKey key;
        std::uint64_t offset { };
        std::uint64_t serialized_bytes { };
        ContentIdentity checksum;
        bool checksum_valid { };
    };

    struct ArtifactJournalScan {
        bool exists { };
        bool header_valid { };
        bool indexed { };
        std::uint64_t file_size { };
        std::uint64_t valid_bytes { };
        std::uint64_t index_bytes { };
        std::vector<JournalArtifactEntry> entries;
    };

    [[nodiscard]] ArtifactJournalScan scan_artifact_journal(
        const std::filesystem::path& path)
    {
        ArtifactJournalScan result;
        std::error_code error;
        const auto file_size = std::filesystem::file_size(path, error);
        if (error) {
            result.exists = error != std::errc::no_such_file_or_directory;
            return result;
        }
        result.exists = true;
        if (file_size > std::numeric_limits<std::uint64_t>::max() ||
            file_size < artifact_append_magic_v2.size()) {
            return result;
        }
        result.file_size = static_cast<std::uint64_t>(file_size);
        auto source = ArtifactReadHandle::open(path);
        if (!source)
            return result;
        auto stream = source->stream();
        if (!stream)
            return result;
        std::array<char, artifact_append_magic_v2.size()> magic { };
        stream.read(magic.data(), static_cast<std::streamsize>(magic.size()));
        if (!stream)
            return result;
        if (magic == artifact_append_magic_v3) {
            result.header_valid = true;
            result.indexed = true;
            result.valid_bytes = artifact_append_magic_v3.size();
            while (result.valid_bytes < result.file_size) {
                const auto segment_offset = result.valid_bytes;
                if (segment_offset >
                    static_cast<std::uint64_t>(
                        std::numeric_limits<std::streamoff>::max())) {
                    break;
                }
                stream.clear();
                stream.seekg(static_cast<std::streamoff>(segment_offset));
                std::array<char, artifact_segment_magic.size()>
                    segment_magic { };
                stream.read(segment_magic.data(),
                    static_cast<std::streamsize>(segment_magic.size()));
                const auto segment_bytes = read_u64(stream);
                const auto index_offset = read_u64(stream);
                const auto index_bytes = read_u64(stream);
                const auto count = read_u32(stream);
                if (!stream || segment_magic != artifact_segment_magic ||
                    !segment_bytes || !index_offset || !index_bytes || !count ||
                    *count == 0U || *count > maximum_artifacts ||
                    result.entries.size() > maximum_artifacts - *count ||
                    *segment_bytes < artifact_segment_header_bytes +
                                         artifact_index_v1_header_bytes +
                                         artifact_segment_footer_bytes ||
                    *segment_bytes > result.file_size - segment_offset ||
                    *index_offset < artifact_segment_header_bytes ||
                    *index_offset >
                        *segment_bytes - artifact_segment_footer_bytes ||
                    *index_bytes != *segment_bytes -
                                        artifact_segment_footer_bytes -
                                        *index_offset) {
                    break;
                }
                const auto absolute_index_offset =
                    segment_offset + *index_offset;
                const auto footer_offset = segment_offset + *segment_bytes -
                                           artifact_segment_footer_bytes;
                if (footer_offset >
                    static_cast<std::uint64_t>(
                        std::numeric_limits<std::streamoff>::max())) {
                    break;
                }
                stream.clear();
                stream.seekg(static_cast<std::streamoff>(footer_offset));
                std::array<char, artifact_segment_footer_magic.size()>
                    footer_magic { };
                stream.read(footer_magic.data(),
                    static_cast<std::streamsize>(footer_magic.size()));
                const auto footer_segment_bytes = read_u64(stream);
                ContentIdentity expected_index_checksum;
                if (!footer_segment_bytes ||
                    !read_identity(stream, expected_index_checksum) ||
                    footer_magic != artifact_segment_footer_magic ||
                    *footer_segment_bytes != *segment_bytes) {
                    break;
                }
                const auto index_checksum = sha256_file(
                    source->descriptor(), absolute_index_offset, *index_bytes);
                if (!index_checksum ||
                    *index_checksum != expected_index_checksum) {
                    break;
                }
                const auto entries = read_artifact_index(stream,
                    absolute_index_offset, *index_bytes, *count,
                    segment_offset + artifact_segment_header_bytes,
                    absolute_index_offset);
                if (!entries)
                    break;
                if (*index_bytes > std::numeric_limits<std::uint64_t>::max() -
                                       result.index_bytes) {
                    break;
                }
                result.index_bytes += *index_bytes;
                for (const auto& entry : *entries) {
                    result.entries.push_back(
                        JournalArtifactEntry { entry.key, entry.offset,
                            entry.serialized_bytes, entry.checksum, true });
                }
                result.valid_bytes = segment_offset + *segment_bytes;
            }
            return result;
        }
        if (magic != artifact_append_magic_v2)
            return result;
        result.header_valid = true;
        result.valid_bytes = artifact_append_magic_v2.size();

        while (result.valid_bytes < result.file_size) {
            const auto segment_offset_position = stream.tellg();
            if (segment_offset_position < 0)
                break;
            const auto segment_offset =
                static_cast<std::uint64_t>(segment_offset_position);
            const auto count = read_u32(stream);
            if (!count || *count > maximum_artifacts)
                break;
            std::vector<JournalArtifactEntry> segment_entries;
            segment_entries.reserve(*count);
            bool complete = true;
            for (std::uint32_t index = 0; index < *count; ++index) {
                const auto record_offset_position = stream.tellg();
                if (record_offset_position < 0) {
                    complete = false;
                    break;
                }
                const auto record_offset =
                    static_cast<std::uint64_t>(record_offset_position);
                const auto metadata = read_artifact_metadata(
                    stream, record_offset, result.file_size);
                if (!metadata) {
                    complete = false;
                    break;
                }
                segment_entries.push_back(JournalArtifactEntry { metadata->key,
                    record_offset, metadata->serialized_bytes, { }, false });
            }
            if (!complete)
                break;
            const auto checksum_offset_position = stream.tellg();
            if (checksum_offset_position < 0)
                break;
            const auto checksum_offset =
                static_cast<std::uint64_t>(checksum_offset_position);
            if (result.file_size < artifact_checksum_bytes ||
                checksum_offset > result.file_size - artifact_checksum_bytes) {
                break;
            }
            ContentIdentity expected_checksum;
            stream.read(
                reinterpret_cast<char*>(expected_checksum.digest.data()),
                static_cast<std::streamsize>(expected_checksum.digest.size()));
            if (!stream)
                break;
            const auto checksum = sha256_file(source->descriptor(),
                segment_offset, checksum_offset - segment_offset);
            if (!checksum || *checksum != expected_checksum)
                break;
            result.entries.insert(result.entries.end(), segment_entries.begin(),
                segment_entries.end());
            result.valid_bytes = checksum_offset + artifact_checksum_bytes;
        }
        return result;
    }

    [[nodiscard]] std::optional<std::shared_ptr<const BlockArtifact>>
    read_artifact_at(const std::filesystem::path& path, std::uint64_t offset,
        std::uint64_t expected_bytes,
        const ContentIdentity* expected_checksum = nullptr)
    {
        if (offset > static_cast<std::uint64_t>(
                         std::numeric_limits<std::streamoff>::max()) ||
            expected_bytes >
                std::numeric_limits<std::uint64_t>::max() - offset) {
            return std::nullopt;
        }
        auto source = ArtifactReadHandle::open(path);
        if (!source)
            return std::nullopt;
        if (expected_checksum != nullptr) {
            const auto actual_checksum =
                sha256_file(source->descriptor(), offset, expected_bytes);
            if (!actual_checksum || *actual_checksum != *expected_checksum) {
                return std::nullopt;
            }
        }
        auto stream = source->stream();
        if (!stream)
            return std::nullopt;
        stream.seekg(static_cast<std::streamoff>(offset));
        if (!stream)
            return std::nullopt;

        const auto key = read_key(stream);
        const auto ir_size = read_u32(stream);
        const auto relocation_count = read_u32(stream);
        const auto exit_count = read_u32(stream);
        const auto dependency_count = read_u32(stream);
        const auto constant_dependency_count = read_u32(stream);
        const auto instruction_count = read_u32(stream);
        const auto translation_nanoseconds = read_u64(stream);
        if (!key || !ir_size || !relocation_count || !exit_count ||
            !dependency_count || !constant_dependency_count ||
            !instruction_count || !translation_nanoseconds ||
            *relocation_count > maximum_metadata_entries ||
            *exit_count > maximum_metadata_entries ||
            *dependency_count > maximum_metadata_entries ||
            *constant_dependency_count > maximum_metadata_entries) {
            return std::nullopt;
        }

        const auto ir = read_bytes(stream, *ir_size);
        if (!ir)
            return std::nullopt;
        JitArtifactData data;
        data.normalized_ir = *ir;
        data.instruction_count = *instruction_count;
        data.translation_nanoseconds = *translation_nanoseconds;
        data.relocation_targets.reserve(*relocation_count);
        for (std::uint32_t index = 0; index < *relocation_count; ++index) {
            const auto target = read_u64(stream);
            if (!target)
                return std::nullopt;
            data.relocation_targets.push_back(*target);
        }
        data.exit_locations.reserve(*exit_count);
        for (std::uint32_t index = 0; index < *exit_count; ++index) {
            const auto location = read_u64(stream);
            if (!location)
                return std::nullopt;
            data.exit_locations.push_back(*location);
        }
        data.code_dependencies.reserve(*dependency_count);
        for (std::uint32_t index = 0; index < *dependency_count; ++index) {
            const auto address = read_u32(stream);
            const auto size = read_u32(stream);
            JitCodeDependency dependency;
            if (!address || !size || *size == 0 ||
                !read_identity(stream, dependency.content_identity) ||
                !read_identity(stream, dependency.layout_identity)) {
                return std::nullopt;
            }
            dependency.address = *address;
            dependency.size = *size;
            data.code_dependencies.push_back(std::move(dependency));
        }
        data.constant_dependencies.reserve(*constant_dependency_count);
        for (std::uint32_t index = 0; index < *constant_dependency_count;
            ++index) {
            const auto address = read_u32(stream);
            const auto size = read_u32(stream);
            const auto value = read_u64(stream);
            JitConstantDependency dependency;
            if (!address || !size || *size == 0 || !value ||
                !read_identity(stream, dependency.content_identity) ||
                !read_identity(stream, dependency.layout_identity)) {
                return std::nullopt;
            }
            dependency.address = *address;
            dependency.size = *size;
            dependency.value = *value;
            data.constant_dependencies.push_back(std::move(dependency));
        }
        const auto actual_bytes = serialized_artifact_bytes(data);
        const auto end = stream.tellg();
        if (!actual_bytes || *actual_bytes != expected_bytes || end < 0 ||
            static_cast<std::uint64_t>(end) != offset + expected_bytes) {
            return std::nullopt;
        }
        return std::make_shared<const BlockArtifact>(
            BlockArtifact { *key, std::move(data) });
    }

    struct CompactionProgress {
        JitArtifactCompactionResult* result { };
        std::uint64_t bytes_written { };
        std::uint64_t records_written { };
    };

    struct CompactionPhaseTimer {
        JitArtifactCompactionResult* result { };
        std::uint64_t JitArtifactCompactionResult::* field { };
        std::chrono::steady_clock::time_point started {
            std::chrono::steady_clock::now()
        };

        ~CompactionPhaseTimer()
        {
            if (result == nullptr || field == nullptr)
                return;
            result->*field = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - started)
                    .count());
        }
    };

    [[nodiscard]] std::optional<std::unique_lock<std::mutex>>
    try_lock_cancellable(
        std::mutex& mutex, const std::function<bool()>& cancellation_check)
    {
        if (!cancellation_check) {
            return std::unique_lock<std::mutex> { mutex };
        }
        std::unique_lock lock { mutex, std::defer_lock };
        while (!lock.owns_lock()) {
            if (cancellation_check())
                return std::nullopt;
            if (lock.try_lock())
                break;
            std::this_thread::sleep_for(std::chrono::milliseconds { 1 });
        }
        return lock.owns_lock()
                   ? std::optional<std::unique_lock<std::mutex>> { std::move(
                         lock) }
                   : std::nullopt;
    }

    bool write_bytes_cancellable(std::ostream& stream, const std::byte* data,
        std::size_t size, const std::function<bool()>& cancellation_check,
        CompactionProgress* progress)
    {
        std::size_t offset = 0;
        while (offset < size) {
            if (cancellation_check && cancellation_check())
                return false;
            const auto chunk =
                std::min<std::size_t>(64U * 1024U, size - offset);
            stream.write(reinterpret_cast<const char*>(data + offset),
                static_cast<std::streamsize>(chunk));
            if (!stream)
                return false;
            if (progress != nullptr) {
                if (progress->bytes_written <=
                    std::numeric_limits<std::uint64_t>::max() - chunk) {
                    progress->bytes_written += chunk;
                } else {
                    progress->bytes_written =
                        std::numeric_limits<std::uint64_t>::max();
                }
            }
            offset += chunk;
        }
        return true;
    }

    bool write_artifact(std::ostream& stream, const BlockArtifact& artifact,
        const std::function<bool()>& cancellation_check = { },
        CompactionProgress* progress = nullptr)
    {
        if (!serialized_artifact_bytes(artifact.data))
            return false;
        write_key(stream, artifact.key);
        write_u32(stream,
            static_cast<std::uint32_t>(artifact.data.normalized_ir.size()));
        write_u32(stream, static_cast<std::uint32_t>(
                              artifact.data.relocation_targets.size()));
        write_u32(stream,
            static_cast<std::uint32_t>(artifact.data.exit_locations.size()));
        write_u32(stream,
            static_cast<std::uint32_t>(artifact.data.code_dependencies.size()));
        write_u32(stream, static_cast<std::uint32_t>(
                              artifact.data.constant_dependencies.size()));
        write_u32(stream, artifact.data.instruction_count);
        write_u64(stream, artifact.data.translation_nanoseconds);
        if (!write_bytes_cancellable(stream, artifact.data.normalized_ir.data(),
                artifact.data.normalized_ir.size(), cancellation_check,
                progress)) {
            return false;
        }
        for (std::size_t index = 0;
            index < artifact.data.relocation_targets.size(); ++index) {
            if ((index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return false;
            }
            const auto target = artifact.data.relocation_targets[index];
            write_u64(stream, target);
        }
        for (std::size_t index = 0; index < artifact.data.exit_locations.size();
            ++index) {
            if ((index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return false;
            }
            const auto location = artifact.data.exit_locations[index];
            write_u64(stream, location);
        }
        for (std::size_t index = 0;
            index < artifact.data.code_dependencies.size(); ++index) {
            if ((index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return false;
            }
            const auto& dependency = artifact.data.code_dependencies[index];
            write_u32(stream, dependency.address);
            write_u32(stream, dependency.size);
            write_identity(stream, dependency.content_identity);
            write_identity(stream, dependency.layout_identity);
        }
        for (std::size_t index = 0;
            index < artifact.data.constant_dependencies.size(); ++index) {
            if ((index % 64U) == 0U && cancellation_check &&
                cancellation_check()) {
                return false;
            }
            const auto& dependency = artifact.data.constant_dependencies[index];
            write_u32(stream, dependency.address);
            write_u32(stream, dependency.size);
            write_u64(stream, dependency.value);
            write_identity(stream, dependency.content_identity);
            write_identity(stream, dependency.layout_identity);
        }
        return static_cast<bool>(stream);
    }

    struct IndexedSegmentPlan {
        CompactIndexLayout index_layout;
        std::vector<std::uint64_t> record_bytes;
        std::uint64_t index_offset { };
        std::uint64_t index_bytes { };
        std::uint64_t segment_bytes { };
    };

    [[nodiscard]] std::optional<IndexedSegmentPlan> prepare_indexed_segment(
        std::span<const std::shared_ptr<const BlockArtifact>> artifacts)
    {
        if (artifacts.empty() || artifacts.size() > maximum_artifacts) {
            return std::nullopt;
        }
        std::vector<const JitArtifactKey*> keys;
        keys.reserve(artifacts.size());
        for (const auto& artifact : artifacts) {
            if (!artifact)
                return std::nullopt;
            keys.push_back(&artifact->key);
        }
        auto layout = build_compact_index_layout(keys);
        if (!layout)
            return std::nullopt;
        const auto encoded_bytes = layout->serialized_bytes();
        if (!encoded_bytes ||
            *encoded_bytes > std::numeric_limits<std::uint64_t>::max()) {
            return std::nullopt;
        }

        IndexedSegmentPlan result;
        result.index_layout = std::move(*layout);
        result.record_bytes.reserve(artifacts.size());
        result.index_offset = artifact_segment_header_bytes;
        for (const auto& artifact : artifacts) {
            const auto serialized = serialized_artifact_bytes(artifact->data);
            if (!serialized ||
                *serialized > std::numeric_limits<std::uint64_t>::max()) {
                return std::nullopt;
            }
            const auto bytes = static_cast<std::uint64_t>(*serialized);
            if (bytes > std::numeric_limits<std::uint64_t>::max() -
                            result.index_offset) {
                return std::nullopt;
            }
            result.index_offset += bytes;
            result.record_bytes.push_back(bytes);
        }
        result.index_bytes = static_cast<std::uint64_t>(*encoded_bytes);
        if (result.index_bytes > std::numeric_limits<std::uint64_t>::max() -
                                     result.index_offset ||
            artifact_segment_footer_bytes >
                std::numeric_limits<std::uint64_t>::max() -
                    result.index_offset - result.index_bytes) {
            return std::nullopt;
        }
        result.segment_bytes = result.index_offset + result.index_bytes +
                               artifact_segment_footer_bytes;
        return result;
    }

    struct IndexedSegmentWrite {
        std::uint64_t end { };
        std::vector<SnapshotArtifactEntry> entries;
    };

    [[nodiscard]] std::optional<IndexedSegmentWrite> append_indexed_segment(
        const std::filesystem::path& path, std::uint64_t segment_offset,
        std::span<const std::shared_ptr<const BlockArtifact>> artifacts,
        const IndexedSegmentPlan& plan,
        const std::atomic<bool>* cancel = nullptr)
    {
        const auto cancelled = [cancel] {
            return cancel != nullptr && cancel->load(std::memory_order_acquire);
        };
        if (cancelled() || artifacts.empty() ||
            artifacts.size() != plan.record_bytes.size() ||
            plan.index_layout.references.size() != artifacts.size() ||
            segment_offset > std::numeric_limits<std::uint64_t>::max() -
                                 plan.segment_bytes) {
            return std::nullopt;
        }
        const auto journal_end = segment_offset + plan.segment_bytes;
        if (journal_end > static_cast<std::uint64_t>(
                              std::numeric_limits<std::streamoff>::max())) {
            return std::nullopt;
        }

        std::ofstream stream { path, std::ios::binary | std::ios::app };
        if (!stream)
            return std::nullopt;
        const auto position = stream.tellp();
        if (position < 0 ||
            static_cast<std::uint64_t>(position) != segment_offset) {
            return std::nullopt;
        }
        stream.write(artifact_segment_magic.data(),
            static_cast<std::streamsize>(artifact_segment_magic.size()));
        write_u64(stream, plan.segment_bytes);
        write_u64(stream, plan.index_offset);
        write_u64(stream, plan.index_bytes);
        write_u32(stream, static_cast<std::uint32_t>(artifacts.size()));

        IndexedSegmentWrite result;
        result.end = journal_end;
        result.entries.reserve(artifacts.size());
        std::uint64_t record_offset =
            segment_offset + artifact_segment_header_bytes;
        for (std::size_t index = 0; index < artifacts.size(); ++index) {
            if (cancelled() || !write_artifact(stream, *artifacts[index])) {
                return std::nullopt;
            }
            result.entries.push_back(
                SnapshotArtifactEntry { artifacts[index]->key, record_offset,
                    plan.record_bytes[index], { } });
            record_offset += plan.record_bytes[index];
        }
        const auto absolute_index_offset = segment_offset + plan.index_offset;
        stream.flush();
        if (!stream || record_offset != absolute_index_offset ||
            stream.tellp() !=
                static_cast<std::streamoff>(absolute_index_offset)) {
            return std::nullopt;
        }

        for (auto& entry : result.entries) {
            if (cancelled())
                return std::nullopt;
            const auto checksum =
                sha256_file(path, entry.offset, entry.serialized_bytes);
            if (!checksum)
                return std::nullopt;
            entry.checksum = *checksum;
        }
        if (cancelled())
            return std::nullopt;
        const auto encoded_index =
            encode_compact_index(plan.index_layout, result.entries);
        if (!encoded_index || encoded_index->size() != plan.index_bytes) {
            return std::nullopt;
        }
        stream.write(reinterpret_cast<const char*>(encoded_index->data()),
            static_cast<std::streamsize>(encoded_index->size()));
        stream.write(artifact_segment_footer_magic.data(),
            static_cast<std::streamsize>(artifact_segment_footer_magic.size()));
        write_u64(stream, plan.segment_bytes);
        write_identity(stream, sha256(*encoded_index));
        stream.flush();
        if (!stream ||
            stream.tellp() != static_cast<std::streamoff>(journal_end)) {
            return std::nullopt;
        }
        stream.close();
        if (!stream)
            return std::nullopt;
        return result;
    }

    bool copy_disk_record(std::istream& source, std::ostream& destination,
        std::uint64_t offset, std::uint64_t byte_count,
        const std::function<bool()>& cancellation_check = { },
        CompactionProgress* progress = nullptr)
    {
        if (offset > static_cast<std::uint64_t>(
                         std::numeric_limits<std::streamoff>::max()) ||
            byte_count > static_cast<std::uint64_t>(
                             std::numeric_limits<std::streamsize>::max())) {
            return false;
        }
        source.clear();
        source.seekg(static_cast<std::streamoff>(offset));
        if (!source)
            return false;
        std::array<char, 64U * 1024U> buffer { };
        auto remaining = byte_count;
        while (remaining != 0U) {
            if (cancellation_check && cancellation_check())
                return false;
            const auto requested =
                std::min<std::uint64_t>(remaining, buffer.size());
            source.read(buffer.data(), static_cast<std::streamsize>(requested));
            if (source.gcount() != static_cast<std::streamsize>(requested)) {
                return false;
            }
            destination.write(
                buffer.data(), static_cast<std::streamsize>(requested));
            if (!destination)
                return false;
            if (progress != nullptr) {
                if (progress->bytes_written <=
                    std::numeric_limits<std::uint64_t>::max() - requested) {
                    progress->bytes_written += requested;
                } else {
                    progress->bytes_written =
                        std::numeric_limits<std::uint64_t>::max();
                }
            }
            remaining -= requested;
        }
        return true;
    }

    class TemporaryPathCleanup {
    public:
        explicit TemporaryPathCleanup(
            JitArtifactCompactionResult* result = nullptr)
            : result_ { result }
        {
        }
        TemporaryPathCleanup(const TemporaryPathCleanup&) = delete;
        TemporaryPathCleanup& operator=(const TemporaryPathCleanup&) = delete;
        ~TemporaryPathCleanup()
        {
            if (path_.empty())
                return;
            const auto cleanup_started = std::chrono::steady_clock::now();
            if (result_ != nullptr) {
                result_->temporary_cleanup_attempted = true;
                ++result_->temporary_cleanup_attempts;
            }
            std::error_code error;
            std::filesystem::remove(path_, error);
            if (result_ == nullptr)
                return;
            const auto cleanup_elapsed = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - cleanup_started)
                    .count());
            result_->cleanup_nanoseconds =
                result_->cleanup_nanoseconds >
                        std::numeric_limits<std::uint64_t>::max() -
                            cleanup_elapsed
                    ? std::numeric_limits<std::uint64_t>::max()
                    : result_->cleanup_nanoseconds + cleanup_elapsed;
            if (error) {
                result_->temporary_cleanup_failed = true;
                ++result_->temporary_cleanup_failures;
                result_->temporary_cleanup = false;
                return;
            }
            std::error_code residue_error;
            const auto residue = std::filesystem::exists(path_, residue_error);
            if (residue_error || residue) {
                result_->temporary_residue_found = true;
                result_->temporary_cleanup_failed = true;
                ++result_->temporary_residues;
                ++result_->temporary_cleanup_failures;
                result_->temporary_cleanup = false;
                return;
            }
            result_->temporary_cleanup_succeeded = true;
            ++result_->temporary_cleanup_successes;
            result_->temporary_cleanup = true;
        }

        void set(std::filesystem::path path) { path_ = std::move(path); }
        void release() noexcept { path_.clear(); }

    private:
        std::filesystem::path path_;
        JitArtifactCompactionResult* result_ { };
    };

    bool write_hotset_contents(const std::filesystem::path& path,
        const std::vector<const JitArtifactKey*>& keys,
        const ContentIdentity& snapshot_id,
        const std::function<bool()>& cancellation_check = { },
        CompactionProgress* progress = nullptr) noexcept
    {
        try {
            if (keys.size() > maximum_hotset_entries || snapshot_id.empty()) {
                return false;
            }
            const auto parent = path.parent_path();
            if (!parent.empty())
                std::filesystem::create_directories(parent);

            std::ostringstream body { std::ios::out | std::ios::binary };
            body.write(artifact_hotset_magic_v2.data(),
                static_cast<std::streamsize>(artifact_hotset_magic_v2.size()));
            write_u32(body, artifact_hotset_schema_v2);
            write_identity(body, snapshot_id);
            write_u32(body, static_cast<std::uint32_t>(keys.size()));
            for (std::size_t index = 0; index < keys.size(); ++index) {
                if ((index % 256U) == 0U && cancellation_check &&
                    cancellation_check()) {
                    return false;
                }
                const auto* key = keys[index];
                if (key == nullptr)
                    return false;
                write_key(body, *key);
            }
            body.flush();
            if (!body)
                return false;
            const auto encoded = body.str();

            std::ofstream stream { path, std::ios::binary | std::ios::trunc };
            if (!stream)
                return false;
            if (!write_bytes_cancellable(stream,
                    reinterpret_cast<const std::byte*>(encoded.data()),
                    encoded.size(), cancellation_check, progress)) {
                return false;
            }
            stream.flush();
            stream.close();
            if (!stream)
                return false;
            const auto encoded_size = std::filesystem::file_size(path);
            const auto checksum =
                sha256_file(path, 0U, encoded_size, cancellation_check);
            if (!checksum)
                return false;
            if (cancellation_check && cancellation_check())
                return false;
            stream.open(path, std::ios::binary | std::ios::app);
            if (!stream)
                return false;
            write_identity(stream, *checksum);
            stream.flush();
            stream.close();
            return static_cast<bool>(stream);
        } catch (...) {
            return false;
        }
    }

    bool write_hotset_file(const std::filesystem::path& path,
        const std::vector<const JitArtifactKey*>& keys,
        const ContentIdentity& snapshot_id) noexcept
    {
        try {
            if (keys.size() > maximum_hotset_entries || snapshot_id.empty())
                return false;
            const auto parent = path.parent_path();
            if (!parent.empty())
                std::filesystem::create_directories(parent);
            const auto temporary = std::filesystem::path {
                path.string() + ".tmp-" +
                std::to_string(std::hash<std::thread::id> { }(
                    std::this_thread::get_id())) +
                "-" +
                std::to_string(
                    std::chrono::steady_clock::now().time_since_epoch().count())
            };
            TemporaryPathCleanup cleanup;
            cleanup.set(temporary);
            if (!write_hotset_contents(temporary, keys, snapshot_id))
                return false;
            std::error_code error;
            std::filesystem::rename(temporary, path, error);
            if (error)
                return false;
            cleanup.release();
            return true;
        } catch (...) {
            return false;
        }
    }

} // namespace

std::size_t JitArtifactKeyHash::operator()(
    const JitArtifactKey& key) const noexcept
{
    auto hash = std::size_t { 0 };
    hash_identity(hash, key.content_identity);
    hash_identity(hash, key.layout_identity);
    hash_scalar(hash, key.guest_pc);
    hash_scalar(hash, key.thumb);
    hash_scalar(hash, key.location_descriptor);
    hash_scalar(hash, key.architecture);
    hash_scalar(hash, key.cpu_model);
    hash_scalar(hash, key.timing_model_version);
    hash_scalar(hash, key.guest_ticks_per_second);
    hash_scalar(hash, key.image_slide);
    hash_scalar(hash, key.hle_abi_version);
    hash_scalar(hash, key.backend_abi_version);
    hash_scalar(hash, key.umbra_build_fingerprint);
    hash_scalar(hash, key.codegen_options);
    hash_scalar(hash, key.host_isa);
    hash_scalar(hash, key.host_feature_mask);
    hash_scalar(hash, key.artifact_format_version);
    return hash;
}

JitArtifactStore::JitArtifactStore(
    std::filesystem::path persistence_path, JitArtifactLimits limits)
    : limits_ { std::move(limits) }
    , persistence_path_ { std::move(persistence_path) }
{
    const auto initialization_started = std::chrono::steady_clock::now();
    boot_lru_begin_ = lru_.end();
    bool persistence_ready = false;
    if (!persistence_path_.empty() && limits_.persistence_enabled) {
        persistence_path_ = current_snapshot_path(persistence_path_);
        persistence_ready = load(persistence_path_);
        if (!persistence_ready) {
            persistence_ready = save(persistence_path_);
        }
    }
    stats_.initialization_nanoseconds = static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::steady_clock::now() - initialization_started)
            .count());
    writeback_disabled_ = !persistence_ready || limits_.writeback_bytes == 0U;
    background_worker_started_ = true;
    writeback_thread_ = std::thread { [this] { writeback_loop(); } };
}

JitArtifactStore::~JitArtifactStore()
{
    {
        const std::lock_guard lock { mutex_ };
        writeback_stopping_ = true;
        stats_.background_prepare_unused += background_prepared_.size();
        background_prepare_queue_.clear();
        background_prepare_pending_.clear();
        background_prepared_.clear();
        background_prepared_order_.clear();
        stats_.background_prepare_queue_entries = 0U;
        stats_.background_prepared_entries = 0U;
    }
    writeback_condition_.notify_all();
    if (writeback_thread_.joinable())
        writeback_thread_.join();
    static_cast<void>(save());
}

JitArtifactLookup JitArtifactStore::lookup(const JitArtifactKey& key,
    JitArtifactRetention retention, bool allow_disk_payload) const
{
    const auto record_disk_hit = [this, &key] {
        ++stats_.disk_hits;
        if (stats_.disk_hit_key_fingerprint_count <
            stats_.disk_hit_key_fingerprints.size()) {
            stats_.disk_hit_key_fingerprints[stats_
                    .disk_hit_key_fingerprint_count++] =
                static_cast<std::uint64_t>(JitArtifactKeyHash { }(key));
        }
    };
    const auto record_matches = [](const DiskArtifactRecord& left,
                                    const DiskArtifactRecord& right) {
        return left.generation == right.generation &&
               left.offset == right.offset &&
               left.serialized_bytes == right.serialized_bytes &&
               left.append_log == right.append_log &&
               left.checksum_valid == right.checksum_valid &&
               (!left.checksum_valid || left.checksum == right.checksum);
    };
    constexpr unsigned maximum_record_attempts = 3U;
    const auto make_lookup = [this, &key](
                                 std::shared_ptr<const BlockArtifact> artifact,
                                 bool disk_hit,
                                 bool transient_failure = false) {
        JitArtifactLookup result;
        result.artifact = std::move(artifact);
        result.transient_failure = transient_failure;
        if (!result.artifact)
            return result;
        if (disk_hit) {
            result.provenance = JitArtifactLookupProvenance::DiskDemand;
            if (const auto resident = artifacts_.find(key);
                resident != artifacts_.end() &&
                resident->second.startup_prefetched) {
                result.provenance = JitArtifactLookupProvenance::DiskPrefetched;
            }
        }
        switch (result.provenance) {
        case JitArtifactLookupProvenance::MemoryPublished:
            ++stats_.memory_published_lookups;
            break;
        case JitArtifactLookupProvenance::DiskDemand:
            ++stats_.disk_demand_lookups;
            break;
        case JitArtifactLookupProvenance::DiskPrefetched:
            ++stats_.disk_prefetched_lookups;
            break;
        }
        result.token = std::make_shared<JitArtifactLookupToken>();
        return result;
    };
    std::shared_ptr<DiskReadFlight> flight;
    {
        std::unique_lock lock { mutex_ };
        ++stats_.lookups;
        promote_retention_locked(key, retention);
        if (auto artifact = artifacts_.find(key);
            artifact != artifacts_.end()) {
            const auto disk_hit = artifact->second.loaded_from_disk;
            if (disk_hit) {
                record_disk_hit();
            } else {
                ++stats_.memory_hits;
            }
            touch_locked(artifact);
            return make_lookup(artifact->second.artifact, disk_hit);
        }
        if (const auto pending = pending_writebacks_.find(key);
            pending != pending_writebacks_.end()) {
            ++stats_.memory_hits;
            return make_lookup(pending->second.artifact, false);
        }
        const auto disk_artifact = disk_artifacts_.find(key);
        if (disk_artifact == disk_artifacts_.end() ||
            disk_artifact->second.serialized_bytes >
                std::numeric_limits<std::size_t>::max()) {
            ++stats_.misses;
            return { };
        }
        // Guest execution may opt into memory/hotset-only admission. Do not
        // start or wait on a disk flight on that path; a later background pass
        // can perform the full lookup without extending the CPU slice.
        if (!allow_disk_payload) {
            ++stats_.misses;
            return { };
        }
        if (const auto active = disk_read_flights_.find(key);
            active != disk_read_flights_.end()) {
            flight = active->second;
            ++stats_.disk_read_waits;
            flight->condition.wait(
                lock, [&flight] { return flight->complete; });
            const auto result = flight->artifact;
            if (!result) {
                ++stats_.misses;
                JitArtifactLookup missed;
                missed.transient_failure = flight->transient_failure;
                return missed;
            }
            if (flight->disk_hit) {
                record_disk_hit();
            } else {
                ++stats_.memory_hits;
            }
            if (auto resident = artifacts_.find(key);
                resident != artifacts_.end()) {
                if (retention == JitArtifactRetention::BootWorkingSet) {
                    resident->second.boot_working_set = true;
                }
                touch_locked(resident);
            }
            return make_lookup(result, flight->disk_hit);
        }
        flight = std::make_shared<DiskReadFlight>();
        disk_read_flights_.emplace(key, flight);
    }

    const auto finish_locked =
        [this, &key, &flight, &make_lookup](std::unique_lock<std::mutex>& lock,
            std::shared_ptr<const BlockArtifact> artifact, bool disk_hit,
            bool transient_failure = false) {
            flight->artifact = artifact;
            flight->disk_hit = disk_hit;
            flight->transient_failure = transient_failure;
            flight->complete = true;
            if (const auto active = disk_read_flights_.find(key);
                active != disk_read_flights_.end() &&
                active->second == flight) {
                disk_read_flights_.erase(active);
            }
            auto result =
                make_lookup(std::move(artifact), disk_hit, transient_failure);
            lock.unlock();
            flight->condition.notify_all();
            return result;
        };

    try {
        for (unsigned attempt = 0; attempt < maximum_record_attempts;
            ++attempt) {
            DiskArtifactRecord record;
            std::filesystem::path source_path;
            {
                std::unique_lock lock { mutex_ };
                promote_retention_locked(key, retention);
                if (auto artifact = artifacts_.find(key);
                    artifact != artifacts_.end()) {
                    const auto disk_hit = artifact->second.loaded_from_disk;
                    if (disk_hit) {
                        record_disk_hit();
                    } else {
                        ++stats_.memory_hits;
                    }
                    touch_locked(artifact);
                    return finish_locked(
                        lock, artifact->second.artifact, disk_hit);
                }
                if (const auto pending = pending_writebacks_.find(key);
                    pending != pending_writebacks_.end()) {
                    ++stats_.memory_hits;
                    return finish_locked(lock, pending->second.artifact, false);
                }
                const auto disk_artifact = disk_artifacts_.find(key);
                if (disk_artifact == disk_artifacts_.end() ||
                    disk_artifact->second.serialized_bytes >
                        std::numeric_limits<std::size_t>::max()) {
                    ++stats_.misses;
                    return finish_locked(lock, nullptr, false);
                }
                record = disk_artifact->second;
                source_path =
                    record.append_log ? disk_append_path_ : disk_source_path_;
            }

            // The per-key flight owns retries while disk latency and
            // deserialization remain outside the global store mutex.
            const auto demand_started = std::chrono::steady_clock::now();
            const auto loaded = read_artifact_at(source_path, record.offset,
                record.serialized_bytes,
                record.checksum_valid ? &record.checksum : nullptr);
            const auto demand_elapsed = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - demand_started)
                    .count());

            std::unique_lock lock { mutex_ };
            ++stats_.demand_payload_disk_loads;
            if (demand_elapsed <=
                std::numeric_limits<std::uint64_t>::max() -
                    stats_.demand_deserialization_nanoseconds) {
                stats_.demand_deserialization_nanoseconds += demand_elapsed;
            } else {
                stats_.demand_deserialization_nanoseconds =
                    std::numeric_limits<std::uint64_t>::max();
            }
            promote_retention_locked(key, retention);
            if (auto artifact = artifacts_.find(key);
                artifact != artifacts_.end()) {
                const auto disk_hit = artifact->second.loaded_from_disk;
                if (disk_hit) {
                    record_disk_hit();
                } else {
                    ++stats_.memory_hits;
                }
                touch_locked(artifact);
                return finish_locked(lock, artifact->second.artifact, disk_hit);
            }
            if (const auto pending = pending_writebacks_.find(key);
                pending != pending_writebacks_.end()) {
                ++stats_.memory_hits;
                return finish_locked(lock, pending->second.artifact, false);
            }
            const auto current = disk_artifacts_.find(key);
            const auto current_path =
                current != disk_artifacts_.end()
                    ? (current->second.append_log ? disk_append_path_
                                                  : disk_source_path_)
                    : std::filesystem::path { };
            if (current == disk_artifacts_.end() ||
                !record_matches(current->second, record) ||
                current_path != source_path) {
                if (attempt + 1U < maximum_record_attempts) {
                    ++stats_.disk_read_retries;
                    continue;
                }
                ++stats_.misses;
                return finish_locked(lock, nullptr, false, true);
            }
            if (!loaded || (*loaded)->key != key) {
                ++stats_.misses;
                return finish_locked(lock, nullptr, false, true);
            }
            insert_locked(*loaded,
                static_cast<std::size_t>(record.serialized_bytes), true, false,
                current->second.boot_working_set
                    ? JitArtifactRetention::BootWorkingSet
                    : retention);
            auto artifact = artifacts_.find(key);
            if (artifact == artifacts_.end()) {
                ++stats_.misses;
                return finish_locked(lock, nullptr, false, true);
            }
            record_disk_hit();
            touch_locked(artifact);
            return finish_locked(lock, artifact->second.artifact, true);
        }
    } catch (...) {
        std::unique_lock lock { mutex_ };
        ++stats_.misses;
        return finish_locked(lock, nullptr, false, true);
    }
    std::unique_lock lock { mutex_ };
    ++stats_.misses;
    return finish_locked(lock, nullptr, false, true);
}

JitArtifactBackgroundPrepareResult JitArtifactStore::request_background_prepare(
    const JitArtifactKey& key, JitArtifactRetention retention) const noexcept
{
    try {
        std::unique_lock lock { mutex_, std::try_to_lock };
        if (!lock.owns_lock()) {
            return JitArtifactBackgroundPrepareResult::Unavailable;
        }
        ++stats_.background_prepare_requests;
        if (background_prepared_.contains(key)) {
            return JitArtifactBackgroundPrepareResult::Ready;
        }
        if (background_prepare_pending_.contains(key)) {
            ++stats_.background_prepare_deduplicated;
            return JitArtifactBackgroundPrepareResult::Pending;
        }
        const bool available = artifacts_.contains(key) ||
                               pending_writebacks_.contains(key) ||
                               disk_artifacts_.contains(key);
        if (!available)
            return JitArtifactBackgroundPrepareResult::ExactMiss;
        if (!background_worker_started_ || writeback_stopping_ ||
            background_prepare_pending_.size() >=
                maximum_background_prepare_entries) {
            ++stats_.background_prepare_rejected;
            return JitArtifactBackgroundPrepareResult::Unavailable;
        }
        background_prepare_pending_.emplace(key, retention);
        background_prepare_queue_.push_back(key);
        stats_.background_prepare_queue_entries =
            background_prepare_pending_.size();
        stats_.background_prepare_queue_peak_entries =
            std::max(stats_.background_prepare_queue_peak_entries,
                stats_.background_prepare_queue_entries);
        lock.unlock();
        writeback_condition_.notify_one();
        return JitArtifactBackgroundPrepareResult::Queued;
    } catch (...) {
        return JitArtifactBackgroundPrepareResult::Unavailable;
    }
}

std::optional<JitArtifactPreparedLookup>
JitArtifactStore::take_background_prepared(
    const JitArtifactKey& key) const noexcept
{
    try {
        std::unique_lock lock { mutex_, std::try_to_lock };
        if (!lock.owns_lock())
            return std::nullopt;
        const auto prepared = background_prepared_.find(key);
        if (prepared == background_prepared_.end())
            return std::nullopt;
        auto result = std::move(prepared->second.prepared);
        background_prepared_order_.erase(prepared->second.order_position);
        background_prepared_.erase(prepared);
        stats_.background_prepared_entries = background_prepared_.size();
        const auto disk = disk_artifacts_.find(key);
        const bool replenish =
            static_cast<bool>(result) && disk != disk_artifacts_.end() &&
            disk->second.boot_working_set && !writeback_stopping_ &&
            !background_prepare_pending_.contains(key) &&
            background_prepare_pending_.size() <
                maximum_background_prepare_entries;
        if (replenish) {
            background_prepare_pending_.emplace(
                key, JitArtifactRetention::BootWorkingSet);
            background_prepare_queue_.push_back(key);
            ++stats_.background_prepare_requests;
            stats_.background_prepare_queue_entries =
                background_prepare_pending_.size();
            stats_.background_prepare_queue_peak_entries =
                std::max(stats_.background_prepare_queue_peak_entries,
                    stats_.background_prepare_queue_entries);
            lock.unlock();
            writeback_condition_.notify_one();
        }
        return result;
    } catch (...) {
        return std::nullopt;
    }
}

std::shared_ptr<const BlockArtifact> JitArtifactStore::find(
    const JitArtifactKey& key, JitArtifactRetention retention) const
{
    return lookup(key, retention).artifact;
}

void JitArtifactStore::touch_locked(ArtifactMap::iterator iterator) const
{
    const auto position = iterator->second.lru_position;
    if (iterator->second.boot_working_set) {
        const bool was_first_boot = position == boot_lru_begin_;
        const auto next = std::next(position);
        lru_.splice(lru_.end(), lru_, position);
        iterator->second.lru_position = std::prev(lru_.end());
        if (was_first_boot) {
            boot_lru_begin_ =
                next == lru_.end() ? iterator->second.lru_position : next;
        }
    } else {
        lru_.splice(boot_lru_begin_, lru_, position);
    }
}

std::uint64_t JitArtifactStore::next_disk_generation_locked() const noexcept
{
    return ++disk_index_generation_;
}

std::uint64_t JitArtifactStore::next_benefit_generation_locked() const noexcept
{
    if (benefit_generation_ != std::numeric_limits<std::uint64_t>::max()) {
        ++benefit_generation_;
    }
    return benefit_generation_;
}

void JitArtifactStore::note_artifact_consumed_locked(
    const JitArtifactLookup& lookup) const noexcept
{
    if (!lookup.artifact)
        return;
    const auto& key = lookup.artifact->key;
    const auto disk = disk_artifacts_.find(key);
    const auto resident = artifacts_.find(key);
    const auto pending = pending_writebacks_.find(key);
    const auto benefit_generation = next_benefit_generation_locked();
    const auto increment_benefit = [benefit_generation](auto& record) {
        record.benefit_generation = benefit_generation;
        if (record.benefit_hits != std::numeric_limits<std::uint64_t>::max()) {
            ++record.benefit_hits;
        }
    };
    if (disk != disk_artifacts_.end()) {
        increment_benefit(disk->second);
        disk->second.translation_nanoseconds =
            std::max(disk->second.translation_nanoseconds,
                lookup.artifact->data.translation_nanoseconds);
    }
    if (resident != artifacts_.end()) {
        increment_benefit(resident->second);
    }
    if (pending != pending_writebacks_.end()) {
        increment_benefit(pending->second);
    }
    mark_hotset_dirty_locked();
    const auto translation_nanoseconds =
        disk == disk_artifacts_.end()
            ? lookup.artifact->data.translation_nanoseconds
            : std::max(disk->second.translation_nanoseconds,
                  lookup.artifact->data.translation_nanoseconds);
    if (stats_.saved_translation_nanoseconds <=
        std::numeric_limits<std::uint64_t>::max() - translation_nanoseconds) {
        stats_.saved_translation_nanoseconds += translation_nanoseconds;
    } else {
        stats_.saved_translation_nanoseconds =
            std::numeric_limits<std::uint64_t>::max();
    }
    if (disk != disk_artifacts_.end() && disk->second.boot_working_set &&
        stats_.prefetched_useful < stats_.hotset_selected) {
        ++stats_.prefetched_useful;
    }
    if (lookup.provenance == JitArtifactLookupProvenance::DiskPrefetched) {
        if (resident != artifacts_.end() &&
            resident->second.startup_prefetched &&
            !resident->second.startup_prefetch_used) {
            if (stats_.prefetched_useful !=
                std::numeric_limits<std::uint64_t>::max()) {
                ++stats_.prefetched_useful;
            }
            resident->second.startup_prefetch_used = true;
            resident->second.loaded_from_disk = false;
        }
    }
    if (resident != artifacts_.end() &&
        resident->second.artifact == lookup.artifact) {
        resident->second.loaded_from_disk = false;
    }
}

void JitArtifactStore::mark_hotset_dirty_locked() const noexcept
{
    hotset_dirty_ = true;
    if (hotset_mutation_generation_ !=
        std::numeric_limits<std::uint64_t>::max()) {
        ++hotset_mutation_generation_;
    }
}

std::optional<JitArtifactStore::HotsetSnapshot>
JitArtifactStore::hotset_snapshot_locked() const
{
    if (!hotset_dirty_ || disk_snapshot_id_.empty())
        return std::nullopt;
    HotsetSnapshot snapshot;
    snapshot.snapshot_id = disk_snapshot_id_;
    snapshot.disk_index_generation = disk_index_generation_;
    snapshot.benefit_generation = benefit_generation_;
    snapshot.mutation_generation = hotset_mutation_generation_;
    snapshot.candidates.reserve(disk_artifacts_.size());
    std::unordered_set<JitArtifactKey, JitArtifactKeyHash> seen;
    seen.reserve(disk_artifacts_.size());
    const auto add = [&snapshot, &seen, this](const JitArtifactKey& key) {
        const auto entry = disk_artifacts_.find(key);
        if (entry == disk_artifacts_.end() || !entry->second.boot_working_set ||
            !seen.insert(key).second) {
            return;
        }
        auto benefit_generation = entry->second.benefit_generation;
        auto benefit_hits = entry->second.benefit_hits;
        auto translation_nanoseconds = entry->second.translation_nanoseconds;
        if (const auto resident = artifacts_.find(key);
            resident != artifacts_.end()) {
            benefit_generation = std::max(
                benefit_generation, resident->second.benefit_generation);
            benefit_hits =
                std::max(benefit_hits, resident->second.benefit_hits);
            translation_nanoseconds = std::max(translation_nanoseconds,
                resident->second.artifact->data.translation_nanoseconds);
        }
        if (const auto pending = pending_writebacks_.find(key);
            pending != pending_writebacks_.end()) {
            benefit_generation = std::max(
                benefit_generation, pending->second.benefit_generation);
            benefit_hits = std::max(benefit_hits, pending->second.benefit_hits);
            translation_nanoseconds = std::max(translation_nanoseconds,
                pending->second.artifact->data.translation_nanoseconds);
        }
        snapshot.candidates.push_back(HotsetCandidate {
            key, benefit_generation, benefit_hits, translation_nanoseconds });
    };
    for (const auto* key : disk_order_)
        add(*key);
    for (const auto& entry : disk_artifacts_)
        add(entry.first);
    return snapshot;
}

void JitArtifactStore::promote_retention_locked(
    const JitArtifactKey& key, JitArtifactRetention retention) const
{
    if (retention != JitArtifactRetention::BootWorkingSet)
        return;
    bool changed = false;
    std::uint64_t membership_generation = 0U;
    const auto generation = [this, &membership_generation] {
        if (membership_generation == 0U) {
            membership_generation = next_benefit_generation_locked();
        }
        return membership_generation;
    };
    if (const auto disk = disk_artifacts_.find(key);
        disk != disk_artifacts_.end()) {
        if (!disk->second.boot_working_set) {
            disk->second.boot_working_set = true;
            disk->second.benefit_generation = generation();
            changed = true;
        }
    }
    if (const auto resident = artifacts_.find(key);
        resident != artifacts_.end()) {
        if (!resident->second.boot_working_set) {
            promote_resident_retention_locked(resident);
            resident->second.benefit_generation = generation();
            changed = true;
        }
    }
    if (const auto pending = pending_writebacks_.find(key);
        pending != pending_writebacks_.end()) {
        if (!pending->second.boot_working_set) {
            pending->second.boot_working_set = true;
            pending->second.benefit_generation = generation();
            changed = true;
        }
    }
    if (changed)
        mark_hotset_dirty_locked();
}

void JitArtifactStore::promote_resident_retention_locked(
    ArtifactMap::iterator iterator) const
{
    if (iterator->second.boot_working_set)
        return;
    const bool had_boot_records = boot_lru_begin_ != lru_.end();
    lru_.splice(lru_.end(), lru_, iterator->second.lru_position);
    iterator->second.lru_position = std::prev(lru_.end());
    iterator->second.boot_working_set = true;
    if (!had_boot_records) {
        boot_lru_begin_ = iterator->second.lru_position;
    }
}

void JitArtifactStore::evict_until_fit_locked(std::size_t required_bytes) const
{
    if (limits_.resident_bytes == 0U)
        return;
    while (resident_bytes_ >
               limits_.resident_bytes -
                   std::min(limits_.resident_bytes, required_bytes) &&
           !lru_.empty()) {
        const auto victim = lru_.begin();
        const auto* key = *victim;
        if (victim == boot_lru_begin_) {
            boot_lru_begin_ = std::next(victim);
        }
        lru_.erase(victim);
        if (lru_.empty())
            boot_lru_begin_ = lru_.end();
        const auto iterator = artifacts_.find(key);
        if (iterator == artifacts_.end())
            continue;
        resident_bytes_ -= iterator->second.serialized_bytes;
        ++stats_.evictions;
        ++stats_.payload_evictions;
        artifacts_.erase(iterator);
    }
}

void JitArtifactStore::insert_locked(
    std::shared_ptr<const BlockArtifact> artifact, std::size_t serialized_bytes,
    bool loaded_from_disk, bool startup_prefetched,
    JitArtifactRetention retention) const
{
    const auto& key = artifact->key;
    const auto* key_pointer = &key;
    if (const auto existing = artifacts_.find(key);
        existing != artifacts_.end()) {
        if (retention == JitArtifactRetention::BootWorkingSet &&
            !existing->second.boot_working_set) {
            promote_resident_retention_locked(existing);
            mark_hotset_dirty_locked();
        }
        touch_locked(existing);
        return;
    }
    if (limits_.resident_bytes != 0U &&
        serialized_bytes > limits_.resident_bytes) {
        return;
    }
    evict_until_fit_locked(serialized_bytes);
    if (limits_.resident_bytes != 0U &&
        resident_bytes_ > limits_.resident_bytes - serialized_bytes) {
        return;
    }
    if (serialized_bytes >
        std::numeric_limits<std::size_t>::max() - resident_bytes_) {
        return;
    }
    const auto disk = disk_artifacts_.find(key);
    const bool boot_working_set =
        retention == JitArtifactRetention::BootWorkingSet ||
        (disk != disk_artifacts_.end() && disk->second.boot_working_set);
    const bool membership_added =
        retention == JitArtifactRetention::BootWorkingSet &&
        (disk == disk_artifacts_.end() || !disk->second.boot_working_set);
    if (membership_added)
        mark_hotset_dirty_locked();
    const auto benefit_generation =
        disk != disk_artifacts_.end()
            ? disk->second.benefit_generation
            : (membership_added ? next_benefit_generation_locked() : 0U);
    const auto benefit_hits =
        disk != disk_artifacts_.end() ? disk->second.benefit_hits : 0U;
    const bool had_boot_records = boot_lru_begin_ != lru_.end();
    const auto lru_position = boot_working_set
                                  ? lru_.insert(lru_.end(), key_pointer)
                                  : lru_.insert(boot_lru_begin_, key_pointer);
    if (boot_working_set && !had_boot_records) {
        boot_lru_begin_ = lru_position;
    }
    const auto [iterator, inserted] = artifacts_.try_emplace(key_pointer,
        ArtifactRecord { std::move(artifact), serialized_bytes, lru_position,
            loaded_from_disk, startup_prefetched, false, benefit_generation,
            benefit_hits, boot_working_set });
    if (!inserted) {
        if (boot_lru_begin_ == lru_position) {
            boot_lru_begin_ = std::next(lru_position);
        }
        lru_.erase(lru_position);
        if (lru_.empty())
            boot_lru_begin_ = lru_.end();
        touch_locked(iterator);
        return;
    }
    resident_bytes_ += serialized_bytes;
    if (loaded_from_disk)
        ++stats_.disk_loaded_entries;
}

bool JitArtifactStore::enqueue_writeback_locked(
    const std::shared_ptr<const BlockArtifact>& artifact,
    std::size_t serialized_bytes, JitArtifactRetention retention) const
{
    if (writeback_disabled_ || persistence_path_.empty() ||
        !limits_.persistence_enabled || limits_.writeback_bytes == 0U ||
        disk_artifacts_.contains(artifact->key) ||
        pending_writebacks_.contains(artifact->key)) {
        return false;
    }
    if (serialized_bytes > limits_.writeback_bytes ||
        pending_writeback_bytes_ > limits_.writeback_bytes - serialized_bytes) {
        ++stats_.writeback_dropped;
        return false;
    }
    writeback_order_.push_back(&artifact->key);
    const auto queue_position = std::prev(writeback_order_.end());
    const auto resident = artifacts_.find(artifact->key);
    const bool boot_working_set =
        retention == JitArtifactRetention::BootWorkingSet ||
        (resident != artifacts_.end() && resident->second.boot_working_set);
    const bool membership_added =
        boot_working_set &&
        (resident == artifacts_.end() || !resident->second.boot_working_set);
    const auto benefit_generation =
        resident != artifacts_.end()
            ? resident->second.benefit_generation
            : (membership_added ? next_benefit_generation_locked() : 0U);
    const auto benefit_hits =
        resident != artifacts_.end() ? resident->second.benefit_hits : 0U;
    const auto [iterator, inserted] =
        pending_writebacks_.try_emplace(&artifact->key,
            PendingWriteback { artifact, serialized_bytes, queue_position,
                benefit_generation, benefit_hits, boot_working_set });
    if (!inserted) {
        writeback_order_.erase(queue_position);
        return false;
    }
    if (serialized_bytes >
        std::numeric_limits<std::size_t>::max() - pending_writeback_bytes_) {
        writeback_order_.erase(iterator->second.queue_position);
        pending_writebacks_.erase(iterator);
        ++stats_.writeback_dropped;
        return false;
    }
    pending_writeback_bytes_ += serialized_bytes;
    if (membership_added) {
        mark_hotset_dirty_locked();
    }
    ++stats_.writeback_enqueued;
    return true;
}

void JitArtifactStore::retire_writeback_locked(const JitArtifactKey& key) const
{
    const auto pending = pending_writebacks_.find(key);
    if (pending == pending_writebacks_.end())
        return;
    pending_writeback_bytes_ -= pending->second.serialized_bytes;
    writeback_order_.erase(pending->second.queue_position);
    pending_writebacks_.erase(pending);
}

std::shared_ptr<const BlockArtifact> JitArtifactStore::publish(
    JitArtifactKey key, JitArtifactData data, JitArtifactRetention retention)
{
    if (!artifact_key_shape_valid(key))
        return nullptr;
    const auto artifact_bytes = serialized_artifact_bytes(data);
    if (!artifact_bytes)
        return nullptr;
    std::shared_ptr<const BlockArtifact> result;
    bool notify_writeback = false;
    {
        const std::lock_guard lock { mutex_ };
        ++stats_.publish_calls;
        promote_retention_locked(key, retention);
        if (const auto existing = artifacts_.find(key);
            existing != artifacts_.end()) {
            ++stats_.deduplicated_publishes;
            touch_locked(existing);
            return existing->second.artifact;
        }
        if (const auto pending = pending_writebacks_.find(key);
            pending != pending_writebacks_.end()) {
            ++stats_.deduplicated_publishes;
            return pending->second.artifact;
        }
        auto artifact = std::make_shared<const BlockArtifact>(
            BlockArtifact { std::move(key), std::move(data) });
        const auto& lookup_key = artifact->key;
        // The queue owns the immutable artifact before insert_locked can evict
        // a resident entry to make room for it.
        const auto requires_writeback =
            !writeback_disabled_ && !persistence_path_.empty() &&
            limits_.persistence_enabled && limits_.writeback_bytes != 0U &&
            !disk_artifacts_.contains(lookup_key);
        notify_writeback =
            enqueue_writeback_locked(artifact, *artifact_bytes, retention);
        // Under ordinary queue pressure, decline the optional publication
        // rather than evicting a retained artifact for an unqueued newcomer.
        // Boot-set translations are the exception: keep them resident so the
        // next full save can persist them after the bounded writer catches up.
        if (!requires_writeback || notify_writeback ||
            retention == JitArtifactRetention::BootWorkingSet) {
            insert_locked(artifact, *artifact_bytes, false, false, retention);
        }
        const auto inserted = artifacts_.find(lookup_key);
        result = inserted != artifacts_.end()
                     ? inserted->second.artifact
                     : (notify_writeback ? artifact : nullptr);
        if (result) {
            publication_generation_.fetch_add(1, std::memory_order_release);
        }
    }
    if (notify_writeback)
        writeback_condition_.notify_one();
    return result;
}

std::size_t JitArtifactStore::size() const
{
    const std::lock_guard lock { mutex_ };
    std::size_t result = disk_artifacts_.size();
    for (const auto& artifact : artifacts_) {
        if (disk_artifacts_.find(*artifact.first) == disk_artifacts_.end()) {
            ++result;
        }
    }
    for (const auto& pending : pending_writebacks_) {
        if (disk_artifacts_.find(*pending.first) == disk_artifacts_.end() &&
            artifacts_.find(pending.first) == artifacts_.end()) {
            ++result;
        }
    }
    return result;
}

JitArtifactStoreStats JitArtifactStore::stats() const
{
    JitArtifactStoreStats result;
    std::filesystem::path disk_path;
    std::filesystem::path append_path;
    {
        const std::lock_guard lock { mutex_ };
        result = stats_;
        result.unique_stage_attempts =
            unique_stage_attempts_.load(std::memory_order_relaxed);
        result.negative_probe_hits =
            negative_probe_hits_.load(std::memory_order_relaxed);
        result.generation_retries =
            generation_retries_.load(std::memory_order_relaxed);
        result.transient_retries =
            transient_retries_.load(std::memory_order_relaxed);
        for (const auto& [key, record] : disk_artifacts_) {
            static_cast<void>(key);
            if (record.boot_working_set) {
                ++result.boot_working_set_artifacts;
            }
        }
        for (const auto& [key, record] : artifacts_) {
            if (record.boot_working_set && !disk_artifacts_.contains(*key)) {
                ++result.boot_working_set_artifacts;
            }
        }
        for (const auto& [key, record] : pending_writebacks_) {
            if (record.boot_working_set && !disk_artifacts_.contains(*key) &&
                !artifacts_.contains(key)) {
                ++result.boot_working_set_artifacts;
            }
        }
        result.resident_bytes = resident_bytes_;
        result.writeback_pending_bytes = pending_writeback_bytes_;
        result.prefetched_unused =
            result.hotset_selected >= result.prefetched_useful
                ? result.hotset_selected - result.prefetched_useful
                : 0U;
        const auto disk_and_ir_cost =
            result.demand_deserialization_nanoseconds <=
                    std::numeric_limits<std::uint64_t>::max() -
                        result.background_ir_deserialization_nanoseconds
                ? result.demand_deserialization_nanoseconds +
                      result.background_ir_deserialization_nanoseconds
                : std::numeric_limits<std::uint64_t>::max();
        result.load_cost_nanoseconds =
            result.initialization_nanoseconds <=
                    std::numeric_limits<std::uint64_t>::max() - disk_and_ir_cost
                ? result.initialization_nanoseconds + disk_and_ir_cost
                : std::numeric_limits<std::uint64_t>::max();
        const auto signed_limit = static_cast<std::uint64_t>(
            std::numeric_limits<std::int64_t>::max());
        const auto saved_signed =
            std::min(result.saved_translation_nanoseconds, signed_limit);
        const auto cost_signed =
            std::min(result.load_cost_nanoseconds, signed_limit);
        result.net_benefit_nanoseconds =
            saved_signed >= cost_signed
                ? static_cast<std::int64_t>(saved_signed - cost_signed)
                : -static_cast<std::int64_t>(cost_signed - saved_signed);
        if (!limits_.persistence_enabled)
            return result;
        disk_path =
            !persistence_path_.empty() ? persistence_path_ : disk_source_path_;
        append_path = !disk_append_path_.empty() ? disk_append_path_
                                                 : append_path_for(disk_path);
    }
    if (!disk_path.empty()) {
        std::error_code error;
        result.disk_bytes = std::filesystem::file_size(disk_path, error);
        if (error)
            result.disk_bytes = 0;
        error.clear();
        const auto append_bytes =
            std::filesystem::file_size(append_path, error);
        if (!error &&
            append_bytes <= std::numeric_limits<std::uintmax_t>::max() -
                                result.disk_bytes) {
            result.disk_bytes += append_bytes;
        } else if (!error) {
            result.disk_bytes = std::numeric_limits<std::uintmax_t>::max();
        }
        error.clear();
        const auto hotset_bytes =
            std::filesystem::file_size(hotset_path_for(disk_path), error);
        if (!error &&
            hotset_bytes <= std::numeric_limits<std::uintmax_t>::max() -
                                result.disk_bytes) {
            result.disk_bytes += hotset_bytes;
        } else if (!error) {
            result.disk_bytes = std::numeric_limits<std::uintmax_t>::max();
        }
    }
    return result;
}

std::uint64_t JitArtifactStore::publication_generation() const noexcept
{
    return publication_generation_.load(std::memory_order_acquire);
}

void JitArtifactStore::record_validation_rejection(
    JitArtifactValidationRejection rejection) const noexcept
{
    const auto index = static_cast<std::size_t>(rejection);
    if (index >= jit_artifact_validation_rejection_count)
        return;
    const std::lock_guard lock { mutex_ };
    ++stats_.validation_rejections[index];
}

void JitArtifactStore::record_validation_success() const noexcept
{
    const std::lock_guard lock { mutex_ };
    ++stats_.validation_successes;
}

void JitArtifactStore::record_staged(
    const JitArtifactLookup& lookup) const noexcept
{
    if (!lookup.artifact || !lookup.token)
        return;
    auto state = lookup.token->state.load(std::memory_order_relaxed);
    for (;;) {
        if ((state & lookup_state_staged) != 0U)
            return;
        if (lookup.token->state.compare_exchange_weak(state,
                static_cast<std::uint8_t>(state | lookup_state_staged),
                std::memory_order_acq_rel, std::memory_order_relaxed)) {
            const std::lock_guard lock { mutex_ };
            ++stats_.staged;
            return;
        }
    }
}

void JitArtifactStore::record_native_imported(
    const JitArtifactLookup& lookup) const noexcept
{
    if (!lookup.artifact || !lookup.token)
        return;
    auto state = lookup.token->state.load(std::memory_order_relaxed);
    for (;;) {
        if ((state & lookup_state_imported) != 0U)
            return;
        if (lookup.token->state.compare_exchange_weak(state,
                static_cast<std::uint8_t>(state | lookup_state_imported),
                std::memory_order_acq_rel, std::memory_order_relaxed)) {
            const std::lock_guard lock { mutex_ };
            ++stats_.native_imported;
            return;
        }
    }
}

void JitArtifactStore::record_already_present(
    const JitArtifactLookup& lookup) const noexcept
{
    if (!lookup.artifact)
        return;
    const std::lock_guard lock { mutex_ };
    ++stats_.already_present;
}

void JitArtifactStore::record_demand_native_emitted() const noexcept
{
    const std::lock_guard lock { mutex_ };
    ++stats_.demand_native_emitted;
}

void JitArtifactStore::record_demand_emit_failed() const noexcept
{
    const std::lock_guard lock { mutex_ };
    ++stats_.demand_emit_failed;
}

void JitArtifactStore::record_demand_consumed(
    const JitArtifactLookup& lookup) const noexcept
{
    if (!lookup.artifact || !lookup.token)
        return;
    auto state = lookup.token->state.load(std::memory_order_relaxed);
    for (;;) {
        if ((state & lookup_state_consumed) != 0U) {
            const std::lock_guard lock { mutex_ };
            ++stats_.duplicate_consumptions;
            return;
        }
        if (lookup.token->state.compare_exchange_weak(state,
                static_cast<std::uint8_t>(state | lookup_state_consumed),
                std::memory_order_acq_rel, std::memory_order_relaxed)) {
            const std::lock_guard lock { mutex_ };
            ++stats_.demand_consumed;
            note_artifact_consumed_locked(lookup);
            return;
        }
    }
}

void JitArtifactStore::record_staged_unused(
    const JitArtifactLookup& lookup) const noexcept
{
    if (!lookup.artifact || !lookup.token)
        return;
    auto state = lookup.token->state.load(std::memory_order_relaxed);
    for (;;) {
        if ((state & lookup_state_consumed) != 0U ||
            (state & lookup_state_unused) != 0U) {
            return;
        }
        const auto next =
            static_cast<std::uint8_t>(state | lookup_state_unused);
        if (lookup.token->state.compare_exchange_weak(state, next,
                std::memory_order_acq_rel, std::memory_order_relaxed)) {
            const std::lock_guard lock { mutex_ };
            ++stats_.staged_unused;
            return;
        }
    }
}

void JitArtifactStore::record_demand_stage_attempt() const noexcept
{
    unique_stage_attempts_.fetch_add(1U, std::memory_order_relaxed);
}

void JitArtifactStore::record_demand_negative_probe_hit() const noexcept
{
    negative_probe_hits_.fetch_add(1U, std::memory_order_relaxed);
}

void JitArtifactStore::record_demand_generation_retry() const noexcept
{
    generation_retries_.fetch_add(1U, std::memory_order_relaxed);
}

void JitArtifactStore::record_demand_transient_retry() const noexcept
{
    transient_retries_.fetch_add(1U, std::memory_order_relaxed);
}

void JitArtifactStore::record_demand_probe_fingerprint_hit() const noexcept
{
    const std::lock_guard lock { mutex_ };
    ++stats_.probe_fingerprint_hits;
}

void JitArtifactStore::record_demand_probe_fingerprint_collision()
    const noexcept
{
    const std::lock_guard lock { mutex_ };
    ++stats_.probe_fingerprint_collisions;
}

void JitArtifactStore::record_demand_probe_eviction() const noexcept
{
    const std::lock_guard lock { mutex_ };
    ++stats_.probe_evictions;
}

void JitArtifactStore::record_demand_probe_size(
    std::size_t entries) const noexcept
{
    const std::lock_guard lock { mutex_ };
    stats_.probe_table_entries = static_cast<std::uint64_t>(entries);
    stats_.probe_table_peak_entries = std::max(
        stats_.probe_table_peak_entries, static_cast<std::uint64_t>(entries));
}

bool JitArtifactStore::admit_demand_artifact(
    std::uint64_t estimated_load_nanoseconds,
    std::uint64_t estimated_saved_nanoseconds,
    std::uint8_t confidence) const noexcept
{
    const std::lock_guard lock { mutex_ };
    ++stats_.admission_attempts;
    if (stats_.admission_estimated_load_nanoseconds <=
        std::numeric_limits<std::uint64_t>::max() -
            estimated_load_nanoseconds) {
        stats_.admission_estimated_load_nanoseconds +=
            estimated_load_nanoseconds;
    } else {
        stats_.admission_estimated_load_nanoseconds =
            std::numeric_limits<std::uint64_t>::max();
    }
    if (stats_.admission_estimated_saved_nanoseconds <=
        std::numeric_limits<std::uint64_t>::max() -
            estimated_saved_nanoseconds) {
        stats_.admission_estimated_saved_nanoseconds +=
            estimated_saved_nanoseconds;
    } else {
        stats_.admission_estimated_saved_nanoseconds =
            std::numeric_limits<std::uint64_t>::max();
    }
    constexpr std::uint8_t minimum_confidence = 80U;
    if (confidence < minimum_confidence) {
        ++stats_.admission_low_confidence;
        ++stats_.admission_rejected;
        return false;
    }
    if (estimated_saved_nanoseconds <= estimated_load_nanoseconds) {
        ++stats_.admission_rejected;
        return false;
    }
    ++stats_.admission_positive;
    return true;
}

std::size_t JitArtifactStore::trim_resident_bytes(
    std::size_t target_bytes) noexcept
{
    std::lock_guard lock { mutex_ };
    if (resident_bytes_ <= target_bytes)
        return 0U;
    const auto before = resident_bytes_;
    for (auto iterator = lru_.begin();
        iterator != boot_lru_begin_ && resident_bytes_ > target_bytes;) {
        const auto next = std::next(iterator);
        const auto* key = *iterator;
        const auto artifact = artifacts_.find(key);
        if (artifact != artifacts_.end() &&
            !artifact->second.boot_working_set &&
            artifact->second.artifact.use_count() == 1U) {
            const auto was_boot_begin = boot_lru_begin_ == iterator;
            resident_bytes_ -= artifact->second.serialized_bytes;
            retire_writeback_locked(*key);
            ++stats_.evictions;
            ++stats_.payload_evictions;
            ++stats_.quota_evictions;
            artifacts_.erase(artifact);
            if (lru_.empty())
                boot_lru_begin_ = lru_.end();
            else if (was_boot_begin)
                boot_lru_begin_ = next;
        }
        iterator = next;
    }
    return before - resident_bytes_;
}

void JitArtifactStore::cancel_writeback() noexcept
{
    if (writeback_cancel_requested_.exchange(true, std::memory_order_acq_rel)) {
        return;
    }
    {
        const std::lock_guard lock { mutex_ };
        writeback_disabled_ = true;
        ++stats_.writeback_cancellations;
        stats_.writeback_dropped += pending_writebacks_.size();
        writeback_order_.clear();
        pending_writebacks_.clear();
        pending_writeback_bytes_ = 0;
    }
    writeback_condition_.notify_all();
}

void JitArtifactStore::writeback_loop()
{
#if defined(__linux__)
    // This shared persistence/prepare worker must yield to Guest execution and
    // display work. Linux applies PRIO_PROCESS/0 to the calling thread.
    static_cast<void>(setpriority(PRIO_PROCESS, 0, 10));
#endif
    constexpr std::size_t maximum_batch_bytes = 4U * 1024U * 1024U;
    // Background prepare is optional and may be replenished continuously by
    // Guest demand. Keep it ahead of idle work, but never let a hot prepare
    // queue postpone persistence indefinitely once a writeback is pending.
    constexpr std::size_t maximum_consecutive_background_prepares = 16U;
    std::size_t consecutive_background_prepares { };
    for (;;) {
        std::vector<std::shared_ptr<const BlockArtifact>> batch;
        std::optional<std::pair<JitArtifactKey, JitArtifactRetention>>
            background_prepare;
        {
            std::unique_lock lock { mutex_ };
            writeback_condition_.wait(lock, [this] {
                return writeback_stopping_ ||
                       !background_prepare_queue_.empty() ||
                       (!writeback_disabled_ && !pending_writebacks_.empty());
            });
            if (writeback_stopping_ && background_prepare_queue_.empty() &&
                (pending_writebacks_.empty() || writeback_disabled_)) {
                return;
            }

            const bool writeback_pending =
                !writeback_disabled_ && !pending_writebacks_.empty();
            const bool yield_to_writeback =
                writeback_pending &&
                consecutive_background_prepares >=
                    maximum_consecutive_background_prepares;
            if (!yield_to_writeback) {
                while (!background_prepare_queue_.empty()) {
                    auto key = std::move(background_prepare_queue_.front());
                    background_prepare_queue_.pop_front();
                    const auto pending = background_prepare_pending_.find(key);
                    if (pending == background_prepare_pending_.end())
                        continue;
                    background_prepare.emplace(std::move(key), pending->second);
                    break;
                }
            }
            if (background_prepare) {
                stats_.background_prepare_queue_entries =
                    background_prepare_pending_.size();
            } else {
                for (auto key = writeback_order_.begin();
                    key != writeback_order_.end();) {
                    const auto pending = pending_writebacks_.find(*key);
                    if (pending == pending_writebacks_.end()) {
                        key = writeback_order_.erase(key);
                        continue;
                    }
                    if (disk_artifacts_.contains(**key)) {
                        const auto* persisted_key = *key;
                        ++key;
                        retire_writeback_locked(*persisted_key);
                        continue;
                    }
                    std::size_t batch_bytes = 0;
                    for (auto candidate = key;
                        candidate != writeback_order_.end(); ++candidate) {
                        const auto entry = pending_writebacks_.find(*candidate);
                        if (entry == pending_writebacks_.end() ||
                            disk_artifacts_.contains(**candidate)) {
                            continue;
                        }
                        const auto bytes = entry->second.serialized_bytes;
                        if (!batch.empty() &&
                            (bytes > maximum_batch_bytes ||
                                batch_bytes > maximum_batch_bytes - bytes)) {
                            break;
                        }
                        batch.push_back(entry->second.artifact);
                        batch_bytes += bytes;
                    }
                    break;
                }
            }
            if (batch.empty() && !background_prepare) {
                if (writeback_stopping_ && pending_writebacks_.empty())
                    return;
                continue;
            }
        }

        if (background_prepare) {
            perform_background_prepare(std::move(background_prepare->first),
                background_prepare->second);
            if (consecutive_background_prepares <
                maximum_consecutive_background_prepares) {
                ++consecutive_background_prepares;
            }
            continue;
        }

        const auto saved = append_writeback_batch(batch);
        consecutive_background_prepares = 0U;
        const std::lock_guard lock { mutex_ };
        if (!saved) {
            if (writeback_cancel_requested_.load(std::memory_order_acquire)) {
                continue;
            }
            ++stats_.writeback_failures;
            stats_.writeback_dropped += pending_writebacks_.size();
            writeback_order_.clear();
            pending_writebacks_.clear();
            pending_writeback_bytes_ = 0;
            writeback_disabled_ = true;
            continue;
        }
        for (const auto& artifact : batch) {
            if (disk_artifacts_.contains(artifact->key)) {
                retire_writeback_locked(artifact->key);
                ++stats_.writeback_saved;
            }
        }
    }
}

void JitArtifactStore::perform_background_prepare(
    JitArtifactKey key, JitArtifactRetention retention) noexcept
{
    const auto started = std::chrono::steady_clock::now();
    std::uint64_t ir_deserialization_nanoseconds { };
    JitArtifactPreparedLookup prepared;
    try {
        prepared.lookup = lookup(key, retention, true);
        if (!prepared.lookup) {
            prepared.result =
                prepared.lookup.transient_failure
                    ? JitDemandArtifactStageResult::TransientFailure
                    : JitDemandArtifactStageResult::ExactMiss;
            prepared.rejection =
                prepared.lookup.transient_failure
                    ? JitArtifactValidationRejection::Exception
                    : JitArtifactValidationRejection::NoExactArtifact;
        } else if (prepared.lookup.artifact->data.normalized_ir.empty()) {
            prepared.result =
                JitDemandArtifactStageResult::PermanentValidationFailure;
            prepared.rejection = JitArtifactValidationRejection::EmptyIr;
        } else {
            const auto ir_started = std::chrono::steady_clock::now();
            auto block = deserialize_umbra_ir(
                prepared.lookup.artifact->data.normalized_ir);
            ir_deserialization_nanoseconds =
                static_cast<std::uint64_t>(std::max<std::int64_t>(
                    0, std::chrono::duration_cast<std::chrono::nanoseconds>(
                           std::chrono::steady_clock::now() - ir_started)
                           .count()));
            if (block && block->Location().Value() == key.location_descriptor) {
                prepared.block =
                    std::make_shared<Umbra::IR::Block>(std::move(*block));
                prepared.result = JitDemandArtifactStageResult::Staged;
            } else if (!block) {
                prepared.result =
                    JitDemandArtifactStageResult::PermanentValidationFailure;
                prepared.rejection =
                    JitArtifactValidationRejection::DeserializeFailed;
            } else {
                prepared.result =
                    JitDemandArtifactStageResult::PermanentValidationFailure;
                prepared.rejection =
                    JitArtifactValidationRejection::DescriptorMismatch;
            }
        }
    } catch (...) {
        prepared.result = JitDemandArtifactStageResult::TransientFailure;
    }
    prepared.preparation_nanoseconds =
        static_cast<std::uint64_t>(std::max<std::int64_t>(
            0, std::chrono::duration_cast<std::chrono::nanoseconds>(
                   std::chrono::steady_clock::now() - started)
                   .count()));

    const std::lock_guard lock { mutex_ };
    background_prepare_pending_.erase(key);
    stats_.background_prepare_queue_entries =
        background_prepare_pending_.size();
    if (stats_.background_ir_deserialization_nanoseconds <=
        std::numeric_limits<std::uint64_t>::max() -
            ir_deserialization_nanoseconds) {
        stats_.background_ir_deserialization_nanoseconds +=
            ir_deserialization_nanoseconds;
    } else {
        stats_.background_ir_deserialization_nanoseconds =
            std::numeric_limits<std::uint64_t>::max();
    }
    if (writeback_stopping_) {
        ++stats_.background_prepare_failed;
        return;
    }
    while (background_prepared_.size() >= maximum_background_prepared_entries &&
           !background_prepared_order_.empty()) {
        const auto victim = background_prepared_order_.front();
        background_prepared_order_.pop_front();
        if (background_prepared_.erase(victim) != 0U) {
            ++stats_.background_prepare_unused;
        }
    }
    const auto existing = background_prepared_.find(key);
    if (existing != background_prepared_.end()) {
        background_prepared_order_.erase(existing->second.order_position);
        background_prepared_.erase(existing);
        ++stats_.background_prepare_unused;
    }
    const bool completed = static_cast<bool>(prepared);
    background_prepared_order_.push_back(key);
    const auto order = std::prev(background_prepared_order_.end());
    background_prepared_.emplace(
        key, BackgroundPreparedRecord { std::move(prepared), order });
    if (completed) {
        ++stats_.background_prepare_completed;
    } else {
        ++stats_.background_prepare_failed;
    }
    stats_.background_prepared_entries = background_prepared_.size();
    stats_.background_prepared_peak_entries =
        std::max(stats_.background_prepared_peak_entries,
            stats_.background_prepared_entries);
}

bool JitArtifactStore::append_writeback_batch(
    const std::vector<std::shared_ptr<const BlockArtifact>>& batch)
    const noexcept
{
    try {
        if (batch.empty())
            return true;
        if (!limits_.persistence_enabled || persistence_path_.empty()) {
            return false;
        }
        if (writeback_cancel_requested_.load(std::memory_order_acquire)) {
            return false;
        }
        const std::lock_guard persistence_lock { persistence_mutex_ };
        if (writeback_cancel_requested_.load(std::memory_order_acquire)) {
            return false;
        }
        auto file_lock = ArtifactFileLock::acquire(
            persistence_path_, ArtifactFileLock::Mode::Exclusive);
        if (!file_lock)
            return false;
        const auto writer_generation = file_lock->generation();
        if (!writer_generation)
            return false;
        std::uint64_t known_generation = 0;
        {
            const std::lock_guard lock { mutex_ };
            known_generation = external_writer_generation_;
        }
        if (known_generation != *writer_generation) {
            if (!load_coordinated(persistence_path_))
                return false;
            const std::lock_guard lock { mutex_ };
            external_writer_generation_ = *writer_generation;
        }
        if (writeback_cancel_requested_.load(std::memory_order_acquire)) {
            return false;
        }
        const auto next_writer_generation = file_lock->begin_write();
        if (!next_writer_generation)
            return false;
        {
            const std::lock_guard lock { mutex_ };
            external_writer_generation_ = *next_writer_generation;
        }

        std::vector<std::shared_ptr<const BlockArtifact>> artifacts;
        {
            const std::lock_guard lock { mutex_ };
            artifacts.reserve(batch.size());
            for (const auto& artifact : batch) {
                if (!disk_artifacts_.contains(artifact->key)) {
                    artifacts.push_back(artifact);
                }
            }
        }
        if (artifacts.empty())
            return true;
        if (artifacts.size() > maximum_artifacts)
            return false;

        std::error_code base_error;
        const auto base_size =
            std::filesystem::file_size(persistence_path_, base_error);
        if (base_error || base_size > maximum_persistence_bytes)
            return false;
        const auto configured_limit =
            limits_.persistence_bytes == 0U
                ? maximum_persistence_bytes
                : std::min<std::uintmax_t>(
                      limits_.persistence_bytes, maximum_persistence_bytes);
        if (base_size > configured_limit)
            return false;

        const auto append_path = append_path_for(persistence_path_);
        std::uint64_t journal_size = 0;
        bool journal_indexed = true;
        {
            const std::lock_guard lock { mutex_ };
            if (disk_artifacts_.size() > maximum_artifacts - artifacts.size()) {
                return false;
            }
            journal_size = disk_append_valid_bytes_;
            journal_indexed = disk_append_indexed_;
        }
        if (journal_size != 0U && !journal_indexed) {
            return save_full(persistence_path_);
        }
        if (journal_size == 0U) {
            const auto parent = append_path.parent_path();
            if (!parent.empty()) {
                std::error_code directory_error;
                std::filesystem::create_directories(parent, directory_error);
                if (directory_error)
                    return false;
            }
            std::ofstream initialize { append_path,
                std::ios::binary | std::ios::trunc };
            if (!initialize)
                return false;
            initialize.write(artifact_append_magic_v3.data(),
                static_cast<std::streamsize>(artifact_append_magic_v3.size()));
            initialize.flush();
            if (!initialize)
                return false;
            initialize.close();
            journal_size = artifact_append_magic_v3.size();
            const std::lock_guard lock { mutex_ };
            disk_append_path_ = append_path;
            disk_append_valid_bytes_ = journal_size;
            disk_append_indexed_ = true;
        } else {
            std::error_code journal_error;
            const auto actual_size =
                std::filesystem::file_size(append_path, journal_error);
            if (journal_error || actual_size < journal_size)
                return false;
            if (actual_size > journal_size) {
                std::filesystem::resize_file(
                    append_path, journal_size, journal_error);
                if (journal_error)
                    return false;
            }
        }

        const auto segment_plan = prepare_indexed_segment(artifacts);
        if (!segment_plan ||
            journal_size > std::numeric_limits<std::uint64_t>::max() -
                               segment_plan->segment_bytes) {
            return false;
        }
        const auto append_bytes = segment_plan->segment_bytes;
        const auto journal_end = journal_size + append_bytes;
        const bool quota_exceeded =
            journal_end > maximum_persistence_bytes ||
            journal_end > configured_limit ||
            base_size > configured_limit - journal_size ||
            append_bytes > configured_limit - base_size - journal_size;
        if (quota_exceeded)
            return save_full(persistence_path_);
        if (!has_storage_headroom(persistence_path_, limits_.minimum_free_bytes,
                static_cast<std::uintmax_t>(append_bytes))) {
            return false;
        }

        const auto written = append_indexed_segment(append_path, journal_size,
            artifacts, *segment_plan, &writeback_cancel_requested_);
        if (!written || written->end != journal_end ||
            written->entries.size() != artifacts.size()) {
            return false;
        }
        std::vector<DiskArtifactRecord> records;
        records.reserve(artifacts.size());
        for (std::size_t index = 0; index < artifacts.size(); ++index) {
            const auto& entry = written->entries[index];
            if (entry.key != artifacts[index]->key)
                return false;
            records.push_back(DiskArtifactRecord { entry.offset,
                entry.serialized_bytes, true, entry.checksum, true, 0U });
        }

        const std::lock_guard lock { mutex_ };
        disk_source_path_ = persistence_path_;
        disk_append_path_ = append_path;
        disk_append_valid_bytes_ = journal_end;
        disk_append_indexed_ = true;
        for (std::size_t index = 0; index < artifacts.size(); ++index) {
            records[index].generation = next_disk_generation_locked();
            records[index].translation_nanoseconds =
                artifacts[index]->data.translation_nanoseconds;
            const auto resident = artifacts_.find(artifacts[index]->key);
            const auto pending =
                pending_writebacks_.find(artifacts[index]->key);
            if (resident != artifacts_.end()) {
                records[index].benefit_generation =
                    resident->second.benefit_generation;
                records[index].benefit_hits = resident->second.benefit_hits;
            }
            if (pending != pending_writebacks_.end()) {
                records[index].benefit_generation =
                    std::max(records[index].benefit_generation,
                        pending->second.benefit_generation);
                records[index].benefit_hits = std::max(
                    records[index].benefit_hits, pending->second.benefit_hits);
            }
            records[index].boot_working_set =
                (resident != artifacts_.end() &&
                    resident->second.boot_working_set) ||
                (pending != pending_writebacks_.end() &&
                    pending->second.boot_working_set);
            const auto [disk, inserted] = disk_artifacts_.insert_or_assign(
                artifacts[index]->key, records[index]);
            static_cast<void>(inserted);
            disk_order_.push_back(&disk->first);
        }
        return true;
    } catch (...) {
        return false;
    }
}

bool JitArtifactStore::compaction_needed() const noexcept
{
    try {
        if (!limits_.persistence_enabled || limits_.compaction_bytes == 0U) {
            return false;
        }
        std::filesystem::path disk_path;
        {
            const std::lock_guard lock { mutex_ };
            disk_path = !persistence_path_.empty() ? persistence_path_
                                                   : disk_source_path_;
        }
        if (disk_path.empty())
            return false;
        std::error_code error;
        const auto append_bytes =
            std::filesystem::file_size(append_path_for(disk_path), error);
        return !error && append_bytes >= limits_.compaction_bytes;
    } catch (...) {
        return false;
    }
}

bool JitArtifactStore::compact() const noexcept
{
    return compact_with_result({ }).completed;
}

bool JitArtifactStore::compact(
    CancellationCheck cancellation_check) const noexcept
{
    return compact_with_result(std::move(cancellation_check)).completed;
}

JitArtifactCompactionResult JitArtifactStore::compact_with_result(
    CancellationCheck cancellation_check) const noexcept
{
    JitArtifactCompactionResult result;
    const auto return_started = std::chrono::steady_clock::now();
    const auto finish = [&] {
        result.return_nanoseconds = static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now() - return_started)
                .count());
        return result;
    };
    try {
        const auto cancelled = [&] {
            if (!cancellation_check || !cancellation_check())
                return false;
            result.cancelled = true;
            if (result.first_cancellation_observed_nanoseconds == 0U) {
                result.first_cancellation_observed_nanoseconds =
                    static_cast<std::uint64_t>(
                        std::chrono::duration_cast<std::chrono::nanoseconds>(
                            std::chrono::steady_clock::now().time_since_epoch())
                            .count());
            }
            return true;
        };
        const CancellationCheck cancellable_check =
            cancellation_check ? CancellationCheck { cancelled }
                               : CancellationCheck { };
        const auto failed = [&] {
            if (!result.cancelled)
                result.failed = true;
            return finish();
        };
        if (cancelled())
            return finish();
        if (!limits_.persistence_enabled || limits_.compaction_bytes == 0U) {
            result.completed = true;
            return finish();
        }
        std::filesystem::path disk_path;
        {
            const std::lock_guard lock { mutex_ };
            disk_path = !persistence_path_.empty() ? persistence_path_
                                                   : disk_source_path_;
        }
        if (disk_path.empty()) {
            result.completed = true;
            return finish();
        }
        {
            if (cancelled())
                return finish();
            const auto lock_started = std::chrono::steady_clock::now();
            auto persistence_lock =
                try_lock_cancellable(persistence_mutex_, cancellable_check);
            if (!persistence_lock) {
                result.lock_wait_nanoseconds = static_cast<std::uint64_t>(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        std::chrono::steady_clock::now() - lock_started)
                        .count());
                return cancelled() ? finish() : failed();
            }
            std::optional<ArtifactFileLock> file_lock;
            // flock() is deliberately polled in short, cancellable intervals.
            // A compaction request must not leave the guest/UI thread parked
            // behind another writer for hundreds of milliseconds.
            for (unsigned attempt = 0; attempt < 32U && !file_lock; ++attempt) {
                if (cancelled())
                    return finish();
                file_lock = ArtifactFileLock::acquire(
                    disk_path, ArtifactFileLock::Mode::Exclusive, true);
                if (!file_lock) {
                    std::this_thread::sleep_for(
                        std::chrono::milliseconds { 1 });
                }
            }
            if (!file_lock)
                return cancelled() ? finish() : failed();
            if (cancelled())
                return finish();
            result.lock_wait_nanoseconds = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - lock_started)
                    .count());
            const auto writer_generation = file_lock->generation();
            if (!writer_generation)
                return failed();
            std::uint64_t known_generation = 0;
            {
                const std::lock_guard lock { mutex_ };
                known_generation = external_writer_generation_;
            }
            if (known_generation != *writer_generation) {
                if (cancelled())
                    return finish();
                if (!load_coordinated(disk_path))
                    return failed();
                const std::lock_guard lock { mutex_ };
                external_writer_generation_ = *writer_generation;
            }
            std::error_code error;
            const auto append_bytes =
                std::filesystem::file_size(append_path_for(disk_path), error);
            if (error || append_bytes < limits_.compaction_bytes) {
                result.completed = true;
                return finish();
            }
            if (cancelled())
                return finish();
            const auto next_writer_generation = file_lock->begin_write();
            if (!next_writer_generation)
                return failed();
            {
                const std::lock_guard lock { mutex_ };
                external_writer_generation_ = *next_writer_generation;
            }
            const auto save_started = std::chrono::steady_clock::now();
            if (!save_full(disk_path, cancellation_check, &result)) {
                result.save_nanoseconds = static_cast<std::uint64_t>(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        std::chrono::steady_clock::now() - save_started)
                        .count());
                return result.cancelled ? finish() : failed();
            }
            result.save_nanoseconds = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - save_started)
                    .count());
        }
        if (cancelled())
            return finish();
        auto lock = try_lock_cancellable(mutex_, cancellable_check);
        if (!lock)
            return cancelled() ? finish() : failed();
        if (cancelled())
            return finish();
        ++stats_.compactions;
        result.completed = true;
        return finish();
    } catch (...) {
        if (!result.cancelled)
            result.failed = true;
        return finish();
    }
}

bool JitArtifactStore::load(const std::filesystem::path& path) noexcept
{
    if (!limits_.persistence_enabled || path.empty())
        return false;
    const std::lock_guard persistence_lock { persistence_mutex_ };
    auto file_lock =
        ArtifactFileLock::acquire(path, ArtifactFileLock::Mode::Shared);
    if (!file_lock)
        return false;
    const auto writer_generation = file_lock->generation();
    if (!writer_generation || !load_coordinated(path))
        return false;
    const std::lock_guard lock { mutex_ };
    external_writer_generation_ = *writer_generation;
    return true;
}

bool JitArtifactStore::load_coordinated(
    const std::filesystem::path& path) const noexcept
{
    try {
        if (!limits_.persistence_enabled)
            return false;
        struct DiskEntry {
            const JitArtifactKey* key;
            DiskArtifactRecord record;
        };

        std::error_code size_error;
        const auto file_size = std::filesystem::file_size(path, size_error);
        if (size_error)
            return false;
        const auto configured_limit =
            limits_.persistence_bytes == 0U
                ? maximum_persistence_bytes
                : std::min<std::uintmax_t>(
                      limits_.persistence_bytes, maximum_persistence_bytes);
        if (file_size > configured_limit)
            return false;
        if (file_size > std::numeric_limits<std::uint64_t>::max())
            return false;
        const auto indexed =
            read_snapshot_index(path, static_cast<std::uint64_t>(file_size));
        if (!indexed)
            return false;
        std::vector<JitArtifactKey> persisted_hotset_order;
        std::unordered_set<JitArtifactKey, JitArtifactKeyHash> persisted_hotset;
        if (const auto hotset =
                read_hotset(hotset_path_for(path), indexed->snapshot_id)) {
            persisted_hotset_order = *hotset;
            persisted_hotset.reserve(hotset->size());
            for (const auto& key : *hotset)
                persisted_hotset.insert(key);
        }

        DiskArtifactMap loaded_index;
        loaded_index.reserve(indexed->entries.size());
        std::vector<DiskEntry> scanned;
        scanned.reserve(indexed->entries.size());
        for (const auto& entry : indexed->entries) {
            const DiskArtifactRecord record { entry.offset,
                entry.serialized_bytes, false, entry.checksum, true, 0U };
            const auto [indexed_entry, inserted] =
                loaded_index.emplace(entry.key, record);
            if (!inserted)
                return false;
            indexed_entry->second.boot_working_set =
                persisted_hotset.contains(entry.key);
            scanned.push_back(
                DiskEntry { &indexed_entry->first, indexed_entry->second });
        }

        const auto append_path = append_path_for(path);
        const auto journal = scan_artifact_journal(append_path);
        if (journal.exists &&
            journal.file_size > configured_limit - file_size) {
            return false;
        }
        if (journal.header_valid) {
            for (const auto& entry : journal.entries) {
                const DiskArtifactRecord record { entry.offset,
                    entry.serialized_bytes, true, entry.checksum,
                    entry.checksum_valid, 0U };
                const auto [indexed_entry, inserted] =
                    loaded_index.insert_or_assign(entry.key, record);
                static_cast<void>(inserted);
                indexed_entry->second.boot_working_set =
                    persisted_hotset.contains(entry.key);
                scanned.push_back(
                    DiskEntry { &indexed_entry->first, indexed_entry->second });
            }
        }
        std::vector<DiskEntry> unique;
        unique.reserve(scanned.size());
        for (const auto& entry : scanned) {
            const auto latest = loaded_index.find(*entry.key);
            if (latest != loaded_index.end() &&
                latest->second.offset == entry.record.offset &&
                latest->second.append_log == entry.record.append_log) {
                unique.push_back(entry);
            }
        }

        std::vector<DiskEntry> prefetch;
        std::size_t prefetch_bytes = 0;
        std::uint64_t hotset_skipped_byte_limit = 0U;
        if (limits_.startup_prefetch_entries != 0U &&
            limits_.startup_prefetch_bytes != 0U) {
            for (const auto& hotset_key : persisted_hotset_order) {
                const auto iterator = loaded_index.find(hotset_key);
                if (iterator == loaded_index.end() ||
                    prefetch.size() >= limits_.startup_prefetch_entries ||
                    iterator->second.serialized_bytes >
                        std::numeric_limits<std::size_t>::max()) {
                    continue;
                }
                const auto bytes =
                    static_cast<std::size_t>(iterator->second.serialized_bytes);
                if (bytes > limits_.startup_prefetch_bytes ||
                    prefetch_bytes > limits_.startup_prefetch_bytes - bytes) {
                    if (hotset_skipped_byte_limit !=
                        std::numeric_limits<std::uint64_t>::max()) {
                        ++hotset_skipped_byte_limit;
                    }
                    continue;
                }
                prefetch.push_back(
                    DiskEntry { &iterator->first, iterator->second });
                prefetch_bytes += bytes;
            }
        }
        std::vector<JitArtifactKey> background_hotset_keys;
        background_hotset_keys.reserve(prefetch.size());
        for (const auto& entry : prefetch) {
            background_hotset_keys.push_back(*entry.key);
        }

        std::vector<const JitArtifactKey*> loaded_order;
        loaded_order.reserve(unique.size());
        for (const auto& entry : unique) {
            loaded_order.push_back(entry.key);
        }
        std::filesystem::path loaded_source_path { path };
        std::filesystem::path loaded_append_path { append_path };

        const std::lock_guard lock { mutex_ };
        stats_.disk_records_indexed = loaded_index.size();
        stats_.index_bytes = indexed->index_bytes;
        if (journal.index_bytes <=
            std::numeric_limits<std::uint64_t>::max() - stats_.index_bytes) {
            stats_.index_bytes += journal.index_bytes;
        }
        stats_.hotset_candidates = persisted_hotset_order.size();
        stats_.hotset_skipped_byte_limit = hotset_skipped_byte_limit;
        stats_.startup_payloads_prefetched = 0U;
        stats_.hotset_selected = 0U;
        stats_.startup_prefetch_bytes = 0U;
        for (auto& entry : loaded_index) {
            const auto previous = disk_artifacts_.find(entry.first);
            if (previous != disk_artifacts_.end()) {
                entry.second.benefit_generation =
                    previous->second.benefit_generation;
                entry.second.benefit_hits = previous->second.benefit_hits;
                entry.second.translation_nanoseconds =
                    std::max(entry.second.translation_nanoseconds,
                        previous->second.translation_nanoseconds);
                benefit_generation_ = std::max(
                    benefit_generation_, entry.second.benefit_generation);
            }
            const auto resident = artifacts_.find(entry.first);
            const auto pending = pending_writebacks_.find(entry.first);
            entry.second.boot_working_set =
                persisted_hotset.contains(entry.first) ||
                (resident != artifacts_.end() &&
                    resident->second.boot_working_set) ||
                (pending != pending_writebacks_.end() &&
                    pending->second.boot_working_set);
        }
        for (auto& entry : loaded_index) {
            entry.second.generation = next_disk_generation_locked();
        }
        disk_artifacts_ = std::move(loaded_index);
        disk_order_ = std::move(loaded_order);
        disk_source_path_ = std::move(loaded_source_path);
        disk_append_path_ = std::move(loaded_append_path);
        disk_snapshot_id_ = indexed->snapshot_id;
        disk_append_valid_bytes_ =
            journal.header_valid ? journal.valid_bytes : 0U;
        disk_append_indexed_ = !journal.header_valid || journal.indexed;
        for (const auto& key : background_hotset_keys) {
            if (background_prepare_pending_.size() >=
                    maximum_background_prepare_entries ||
                background_prepare_pending_.contains(key) ||
                background_prepared_.contains(key)) {
                continue;
            }
            background_prepare_pending_.emplace(
                key, JitArtifactRetention::BootWorkingSet);
            background_prepare_queue_.push_back(key);
            ++stats_.background_prepare_requests;
            ++stats_.hotset_selected;
        }
        stats_.background_prepare_queue_entries =
            background_prepare_pending_.size();
        stats_.background_prepare_queue_peak_entries =
            std::max(stats_.background_prepare_queue_peak_entries,
                stats_.background_prepare_queue_entries);
        publication_generation_.fetch_add(1U, std::memory_order_release);
        writeback_condition_.notify_one();
        return true;
    } catch (...) {
        return false;
    }
}

JitArtifactStore::AppendResult JitArtifactStore::append_new_artifacts(
    const std::filesystem::path& path) const noexcept
{
    try {
        if (!limits_.persistence_enabled)
            return AppendResult::Failed;
        if (path.empty())
            return AppendResult::Failed;

        {
            const std::lock_guard lock { mutex_ };
            if (disk_source_path_.empty() || disk_source_path_ != path) {
                return AppendResult::NotApplicable;
            }
        }

        std::error_code base_error;
        const auto base_size = std::filesystem::file_size(path, base_error);
        if (base_error)
            return AppendResult::NotApplicable;
        if (base_size > maximum_persistence_bytes)
            return AppendResult::Failed;

        const auto configured_limit =
            limits_.persistence_bytes == 0U
                ? maximum_persistence_bytes
                : std::min<std::uintmax_t>(
                      limits_.persistence_bytes, maximum_persistence_bytes);
        if (base_size > configured_limit)
            return AppendResult::Failed;

        const auto append_path = append_path_for(path);
        auto journal = scan_artifact_journal(append_path);
        std::vector<std::pair<const JitArtifactKey*,
            std::shared_ptr<const BlockArtifact>>>
            new_artifacts;
        {
            const std::lock_guard lock { mutex_ };
            if (disk_source_path_.empty() || disk_source_path_ != path) {
                return AppendResult::NotApplicable;
            }
            if (journal.header_valid) {
                for (const auto& entry : journal.entries) {
                    DiskArtifactRecord record { entry.offset,
                        entry.serialized_bytes, true, entry.checksum,
                        entry.checksum_valid, 0U };
                    const auto existing = disk_artifacts_.find(entry.key);
                    const bool changed =
                        existing == disk_artifacts_.end() ||
                        existing->second.offset != record.offset ||
                        existing->second.serialized_bytes !=
                            record.serialized_bytes ||
                        existing->second.append_log != record.append_log ||
                        existing->second.checksum_valid !=
                            record.checksum_valid ||
                        (record.checksum_valid &&
                            existing->second.checksum != record.checksum);
                    if (changed) {
                        if (existing != disk_artifacts_.end()) {
                            record.benefit_generation =
                                existing->second.benefit_generation;
                            record.benefit_hits = existing->second.benefit_hits;
                            record.translation_nanoseconds =
                                existing->second.translation_nanoseconds;
                            record.boot_working_set =
                                existing->second.boot_working_set;
                        }
                        const auto resident = artifacts_.find(entry.key);
                        const auto pending =
                            pending_writebacks_.find(entry.key);
                        if (resident != artifacts_.end()) {
                            record.benefit_generation =
                                std::max(record.benefit_generation,
                                    resident->second.benefit_generation);
                            record.benefit_hits = std::max(record.benefit_hits,
                                resident->second.benefit_hits);
                        }
                        if (pending != pending_writebacks_.end()) {
                            record.benefit_generation =
                                std::max(record.benefit_generation,
                                    pending->second.benefit_generation);
                            record.benefit_hits = std::max(record.benefit_hits,
                                pending->second.benefit_hits);
                        }
                        record.boot_working_set =
                            record.boot_working_set ||
                            (resident != artifacts_.end() &&
                                resident->second.boot_working_set) ||
                            (pending != pending_writebacks_.end() &&
                                pending->second.boot_working_set);
                        record.generation = next_disk_generation_locked();
                        const auto [disk, inserted] =
                            disk_artifacts_.insert_or_assign(entry.key, record);
                        static_cast<void>(inserted);
                        disk_order_.push_back(&disk->first);
                    }
                }
                disk_append_path_ = append_path;
                disk_append_valid_bytes_ = journal.valid_bytes;
                disk_append_indexed_ = journal.indexed;
            }

            for (auto pending = writeback_order_.begin();
                pending != writeback_order_.end();) {
                if (!disk_artifacts_.contains(**pending)) {
                    ++pending;
                    continue;
                }
                const auto* persisted_key = *pending;
                ++pending;
                retire_writeback_locked(*persisted_key);
            }

            new_artifacts.reserve(
                artifacts_.size() + pending_writebacks_.size());
            std::unordered_set<const JitArtifactKey*, JitArtifactKeyPointerHash,
                JitArtifactKeyPointerEqual>
                considered;
            considered.reserve(artifacts_.size() + pending_writebacks_.size());
            const auto consider = [&](const JitArtifactKey* key) {
                if (!considered.insert(key).second)
                    return;
                if (disk_artifacts_.find(*key) != disk_artifacts_.end())
                    return;
                const auto resident = artifacts_.find(*key);
                if (resident != artifacts_.end()) {
                    new_artifacts.emplace_back(&resident->second.artifact->key,
                        resident->second.artifact);
                    return;
                }
                const auto pending = pending_writebacks_.find(*key);
                if (pending != pending_writebacks_.end()) {
                    new_artifacts.emplace_back(&pending->second.artifact->key,
                        pending->second.artifact);
                }
            };
            for (const auto* key : lru_)
                consider(key);
            for (const auto& entry : artifacts_)
                consider(entry.first);
            for (const auto* key : writeback_order_)
                consider(key);
            for (const auto& entry : pending_writebacks_)
                consider(entry.first);
            if (new_artifacts.size() > maximum_artifacts ||
                disk_artifacts_.size() >
                    maximum_artifacts -
                        static_cast<std::uint32_t>(new_artifacts.size())) {
                return AppendResult::Failed;
            }
        }

        if (journal.header_valid && !journal.indexed) {
            return AppendResult::NotApplicable;
        }
        const auto publish_hotset_if_dirty = [&]() -> AppendResult {
            std::optional<HotsetSnapshot> snapshot;
            {
                const std::lock_guard lock { mutex_ };
                snapshot = hotset_snapshot_locked();
            }
            if (!snapshot)
                return AppendResult::Saved;
            std::sort(snapshot->candidates.begin(), snapshot->candidates.end(),
                [](const HotsetCandidate& left, const HotsetCandidate& right) {
                    if (left.benefit_hits != right.benefit_hits) {
                        return left.benefit_hits > right.benefit_hits;
                    }
                    if (left.translation_nanoseconds !=
                        right.translation_nanoseconds) {
                        return left.translation_nanoseconds >
                               right.translation_nanoseconds;
                    }
                    if (left.benefit_generation != right.benefit_generation) {
                        return left.benefit_generation >
                               right.benefit_generation;
                    }
                    return key_order_token(left.key) <
                           key_order_token(right.key);
                });
            if (snapshot->candidates.size() > maximum_hotset_entries) {
                snapshot->candidates.resize(maximum_hotset_entries);
            }
            std::vector<const JitArtifactKey*> keys;
            keys.reserve(snapshot->candidates.size());
            for (const auto& candidate : snapshot->candidates) {
                keys.push_back(&candidate.key);
            }
            if (!write_hotset_file(
                    hotset_path_for(path), keys, snapshot->snapshot_id)) {
                return AppendResult::Failed;
            }
            {
                const std::lock_guard lock { mutex_ };
                if (hotset_mutation_generation_ ==
                        snapshot->mutation_generation &&
                    disk_index_generation_ == snapshot->disk_index_generation &&
                    benefit_generation_ == snapshot->benefit_generation &&
                    disk_snapshot_id_ == snapshot->snapshot_id) {
                    hotset_dirty_ = false;
                }
            }
            return AppendResult::Saved;
        };
        if (new_artifacts.empty()) {
            return publish_hotset_if_dirty();
        }

        if (!journal.header_valid) {
            const auto parent = append_path.parent_path();
            if (!parent.empty()) {
                std::error_code directory_error;
                std::filesystem::create_directories(parent, directory_error);
                if (directory_error)
                    return AppendResult::Failed;
            }
            std::ofstream initialize { append_path,
                std::ios::binary | std::ios::trunc };
            if (!initialize)
                return AppendResult::Failed;
            initialize.write(artifact_append_magic_v3.data(),
                static_cast<std::streamsize>(artifact_append_magic_v3.size()));
            initialize.flush();
            if (!initialize)
                return AppendResult::Failed;
            initialize.close();
            journal = scan_artifact_journal(append_path);
            if (!journal.header_valid || !journal.indexed) {
                return AppendResult::Failed;
            }
        }
        if (journal.valid_bytes < journal.file_size) {
            std::error_code truncate_error;
            std::filesystem::resize_file(
                append_path, journal.valid_bytes, truncate_error);
            if (truncate_error)
                return AppendResult::Failed;
            journal.file_size = journal.valid_bytes;
        }
        if (journal.file_size > maximum_persistence_bytes ||
            journal.file_size > configured_limit) {
            return AppendResult::Failed;
        }
        std::vector<std::shared_ptr<const BlockArtifact>> artifacts;
        artifacts.reserve(new_artifacts.size());
        for (const auto& entry : new_artifacts) {
            artifacts.push_back(entry.second);
        }
        const auto segment_plan = prepare_indexed_segment(artifacts);
        if (!segment_plan ||
            journal.file_size > std::numeric_limits<std::uint64_t>::max() -
                                    segment_plan->segment_bytes) {
            return AppendResult::Failed;
        }
        const auto append_bytes = segment_plan->segment_bytes;
        const auto journal_end = journal.file_size + append_bytes;
        if (journal_end > maximum_persistence_bytes ||
            journal_end > configured_limit ||
            base_size > configured_limit - journal.file_size ||
            append_bytes > configured_limit - base_size - journal.file_size) {
            return AppendResult::NotApplicable;
        }
        if (!has_storage_headroom(path, limits_.minimum_free_bytes,
                static_cast<std::uintmax_t>(append_bytes))) {
            return AppendResult::Failed;
        }

        const auto written = append_indexed_segment(
            append_path, journal.file_size, artifacts, *segment_plan);
        if (!written || written->end != journal_end ||
            written->entries.size() != new_artifacts.size()) {
            return AppendResult::Failed;
        }
        std::vector<DiskArtifactRecord> output_records;
        output_records.reserve(new_artifacts.size());
        for (std::size_t index = 0; index < new_artifacts.size(); ++index) {
            const auto& entry = written->entries[index];
            if (entry.key != *new_artifacts[index].first) {
                return AppendResult::Failed;
            }
            output_records.push_back(DiskArtifactRecord { entry.offset,
                entry.serialized_bytes, true, entry.checksum, true, 0U });
        }

        {
            const std::lock_guard lock { mutex_ };
            if (disk_source_path_.empty() || disk_source_path_ != path) {
                return AppendResult::NotApplicable;
            }
            disk_append_path_ = append_path;
            for (std::size_t index = 0; index < new_artifacts.size(); ++index) {
                const auto& key = *new_artifacts[index].first;
                output_records[index].generation =
                    next_disk_generation_locked();
                output_records[index].translation_nanoseconds =
                    new_artifacts[index].second->data.translation_nanoseconds;
                const auto resident = artifacts_.find(key);
                const auto pending = pending_writebacks_.find(key);
                if (resident != artifacts_.end()) {
                    output_records[index].benefit_generation =
                        resident->second.benefit_generation;
                    output_records[index].benefit_hits =
                        resident->second.benefit_hits;
                }
                if (pending != pending_writebacks_.end()) {
                    output_records[index].benefit_generation =
                        std::max(output_records[index].benefit_generation,
                            pending->second.benefit_generation);
                    output_records[index].benefit_hits =
                        std::max(output_records[index].benefit_hits,
                            pending->second.benefit_hits);
                }
                output_records[index].boot_working_set =
                    (resident != artifacts_.end() &&
                        resident->second.boot_working_set) ||
                    (pending != pending_writebacks_.end() &&
                        pending->second.boot_working_set);
                const auto [disk, inserted] = disk_artifacts_.insert_or_assign(
                    key, output_records[index]);
                static_cast<void>(inserted);
                disk_order_.push_back(&disk->first);
                retire_writeback_locked(key);
            }
            disk_append_valid_bytes_ = journal_end;
            disk_append_indexed_ = true;
        }
        return publish_hotset_if_dirty();
    } catch (...) {
        return AppendResult::Failed;
    }
}

bool JitArtifactStore::save() const noexcept
{
    return persistence_path_.empty() || save(persistence_path_);
}

bool JitArtifactStore::save(const std::filesystem::path& path) const noexcept
{
    if (path.empty())
        return false;
    if (!limits_.persistence_enabled)
        return true;
    const std::lock_guard persistence_lock { persistence_mutex_ };
    auto file_lock =
        ArtifactFileLock::acquire(path, ArtifactFileLock::Mode::Exclusive);
    if (!file_lock)
        return false;
    const auto writer_generation = file_lock->generation();
    if (!writer_generation)
        return false;
    bool tracks_path = false;
    std::uint64_t known_generation = 0;
    {
        const std::lock_guard lock { mutex_ };
        tracks_path = persistence_path_ == path || disk_source_path_ == path;
        known_generation = external_writer_generation_;
    }
    if (tracks_path && known_generation != *writer_generation) {
        std::error_code exists_error;
        const auto cache_exists = std::filesystem::exists(path, exists_error);
        if (exists_error || (cache_exists && !load_coordinated(path))) {
            return false;
        }
        const std::lock_guard lock { mutex_ };
        external_writer_generation_ = *writer_generation;
    }
    const auto next_writer_generation = file_lock->begin_write();
    if (!next_writer_generation)
        return false;
    {
        const std::lock_guard lock { mutex_ };
        external_writer_generation_ = *next_writer_generation;
    }
    const auto append_result = append_new_artifacts(path);
    if (append_result == AppendResult::Saved)
        return true;
    if (append_result == AppendResult::Failed)
        return false;
    return save_full(path);
}

bool JitArtifactStore::finalize() const noexcept
{
    const auto finish = [this](bool success) {
        const std::lock_guard lock { mutex_ };
        if (success) {
            ++stats_.finalizations;
        } else {
            ++stats_.finalization_failures;
        }
        return success;
    };
    try {
        if (!limits_.persistence_enabled || persistence_path_.empty()) {
            return finish(true);
        }
        const auto path = persistence_path_;
        const std::lock_guard persistence_lock { persistence_mutex_ };
        auto file_lock =
            ArtifactFileLock::acquire(path, ArtifactFileLock::Mode::Exclusive);
        if (!file_lock)
            return finish(false);
        const auto writer_generation = file_lock->generation();
        if (!writer_generation)
            return finish(false);
        std::uint64_t known_generation = 0;
        {
            const std::lock_guard lock { mutex_ };
            known_generation = external_writer_generation_;
        }
        if (known_generation != *writer_generation) {
            std::error_code exists_error;
            const auto cache_exists =
                std::filesystem::exists(path, exists_error);
            if (exists_error || (cache_exists && !load_coordinated(path))) {
                return finish(false);
            }
            const std::lock_guard lock { mutex_ };
            external_writer_generation_ = *writer_generation;
        }
        const auto next_writer_generation = file_lock->begin_write();
        if (!next_writer_generation)
            return finish(false);
        {
            const std::lock_guard lock { mutex_ };
            external_writer_generation_ = *next_writer_generation;
        }
        return finish(save_full(path));
    } catch (...) {
        return finish(false);
    }
}

bool JitArtifactStore::save_full(
    const std::filesystem::path& path) const noexcept
{
    return save_full(path, { }, nullptr);
}

bool JitArtifactStore::save_full(const std::filesystem::path& path,
    const CancellationCheck& cancellation_check) const noexcept
{
    return save_full(path, cancellation_check, nullptr);
}

bool JitArtifactStore::save_full(const std::filesystem::path& path,
    const CancellationCheck& cancellation_check,
    JitArtifactCompactionResult* compaction_result) const noexcept
{
    try {
        CompactionProgress progress { compaction_result };
        const auto cancelled = [&] {
            if (!cancellation_check || !cancellation_check())
                return false;
            if (compaction_result != nullptr) {
                compaction_result->cancelled = true;
                if (compaction_result
                        ->first_cancellation_observed_nanoseconds == 0U) {
                    compaction_result->first_cancellation_observed_nanoseconds =
                        static_cast<std::uint64_t>(std::chrono::duration_cast<
                            std::chrono::nanoseconds>(
                            std::chrono::steady_clock::now().time_since_epoch())
                                .count());
                }
                compaction_result->bytes_before_cancel = progress.bytes_written;
                compaction_result->records_before_cancel =
                    progress.records_written;
            }
            return true;
        };
        const CancellationCheck cancellable_check =
            cancellation_check ? CancellationCheck { cancelled }
                               : CancellationCheck { };
        if (cancelled())
            return false;
        if (path.empty())
            return false;
        struct SaveEntry {
            const JitArtifactKey* key;
            std::shared_ptr<const BlockArtifact> artifact;
            DiskArtifactRecord disk_record;
            bool resident { };
            bool boot_working_set { };
        };

        std::vector<SaveEntry> entries;
        std::filesystem::path source_path;
        std::filesystem::path append_source_path;
        std::uint64_t saved_hotset_mutation_generation = 0U;
        std::uint64_t saved_benefit_generation = 0U;
        {
            const CompactionPhaseTimer snapshot_timer { compaction_result,
                &JitArtifactCompactionResult::snapshot_nanoseconds };
            auto lock = try_lock_cancellable(mutex_, cancellable_check);
            if (!lock) {
                static_cast<void>(cancelled());
                return false;
            }
            entries.reserve(disk_artifacts_.size() + artifacts_.size() +
                            pending_writebacks_.size());
            std::unordered_set<const JitArtifactKey*, JitArtifactKeyPointerHash,
                JitArtifactKeyPointerEqual>
                emitted;
            emitted.reserve(disk_artifacts_.size() + artifacts_.size() +
                            pending_writebacks_.size());
            std::size_t snapshot_entries_examined { };
            const auto snapshot_cancelled = [&] {
                // Keep cancellation latency bounded while this potentially
                // large metadata snapshot holds mutex_. A 64-entry interval
                // avoids an atomic token read on every map/list visit.
                constexpr std::size_t cancellation_interval = 64U;
                const bool check =
                    snapshot_entries_examined++ % cancellation_interval == 0U;
                return check && cancelled();
            };
            const auto append_disk_entry = [&entries, &emitted, this](
                                               const JitArtifactKey& key) {
                const auto disk = disk_artifacts_.find(key);
                if (disk == disk_artifacts_.end() ||
                    !emitted.insert(&disk->first).second) {
                    return;
                }
                const auto resident = artifacts_.find(key);
                if (resident != artifacts_.end()) {
                    auto record = disk->second;
                    record.benefit_generation =
                        std::max(record.benefit_generation,
                            resident->second.benefit_generation);
                    record.benefit_hits = std::max(
                        record.benefit_hits, resident->second.benefit_hits);
                    record.boot_working_set = record.boot_working_set ||
                                              resident->second.boot_working_set;
                    entries.push_back(
                        SaveEntry { &disk->first, resident->second.artifact,
                            record, true, record.boot_working_set });
                } else if (const auto pending = pending_writebacks_.find(key);
                    pending != pending_writebacks_.end()) {
                    auto record = disk->second;
                    record.benefit_generation =
                        std::max(record.benefit_generation,
                            pending->second.benefit_generation);
                    record.benefit_hits = std::max(
                        record.benefit_hits, pending->second.benefit_hits);
                    record.boot_working_set = record.boot_working_set ||
                                              pending->second.boot_working_set;
                    entries.push_back(
                        SaveEntry { &disk->first, pending->second.artifact,
                            record, true, record.boot_working_set });
                } else {
                    entries.push_back(SaveEntry { &disk->first, { },
                        disk->second, false, disk->second.boot_working_set });
                }
            };
            for (const auto* key : disk_order_) {
                if (snapshot_cancelled())
                    return false;
                append_disk_entry(*key);
            }
            for (const auto& entry : disk_artifacts_) {
                if (snapshot_cancelled())
                    return false;
                append_disk_entry(entry.first);
            }
            const auto append_resident_entry = [&entries, &emitted, this](
                                                   const JitArtifactKey& key) {
                if (!emitted.insert(&key).second)
                    return;
                const auto resident = artifacts_.find(key);
                if (resident != artifacts_.end()) {
                    DiskArtifactRecord record;
                    record.benefit_generation =
                        resident->second.benefit_generation;
                    record.benefit_hits = resident->second.benefit_hits;
                    record.boot_working_set = resident->second.boot_working_set;
                    entries.push_back(
                        SaveEntry { &resident->second.artifact->key,
                            resident->second.artifact, record, true,
                            record.boot_working_set });
                    return;
                }
                const auto pending = pending_writebacks_.find(key);
                if (pending != pending_writebacks_.end()) {
                    DiskArtifactRecord record;
                    record.benefit_generation =
                        pending->second.benefit_generation;
                    record.benefit_hits = pending->second.benefit_hits;
                    record.boot_working_set = pending->second.boot_working_set;
                    entries.push_back(
                        SaveEntry { &pending->second.artifact->key,
                            pending->second.artifact, record, true,
                            record.boot_working_set });
                }
            };
            for (const auto* key : lru_) {
                if (snapshot_cancelled())
                    return false;
                append_resident_entry(*key);
            }
            for (const auto& entry : artifacts_) {
                if (snapshot_cancelled())
                    return false;
                append_resident_entry(*entry.first);
            }
            for (const auto* key : writeback_order_) {
                if (snapshot_cancelled())
                    return false;
                append_resident_entry(*key);
            }
            for (const auto& entry : pending_writebacks_) {
                if (snapshot_cancelled())
                    return false;
                append_resident_entry(*entry.first);
            }
            for (auto& entry : entries) {
                if (snapshot_cancelled())
                    return false;
                if (entry.disk_record.benefit_generation == 0U &&
                    entry.boot_working_set) {
                    entry.disk_record.benefit_generation =
                        next_benefit_generation_locked();
                }
                if (entry.resident) {
                    entry.disk_record.translation_nanoseconds =
                        std::max(entry.disk_record.translation_nanoseconds,
                            entry.artifact->data.translation_nanoseconds);
                }
            }
            source_path = disk_source_path_;
            append_source_path = disk_append_path_;
            saved_hotset_mutation_generation = hotset_mutation_generation_;
            saved_benefit_generation = benefit_generation_;
        }

        if (cancelled())
            return false;
        if (entries.size() > maximum_artifacts)
            return false;
        std::vector<std::uint64_t> record_bytes;
        record_bytes.reserve(entries.size());
        for (const auto& entry : entries) {
            if (cancelled())
                return false;
            std::uint64_t bytes = 0;
            if (entry.resident) {
                const auto artifact_size =
                    serialized_artifact_bytes(entry.artifact->data);
                if (!artifact_size ||
                    *artifact_size >
                        std::numeric_limits<std::uint64_t>::max()) {
                    return false;
                }
                bytes = static_cast<std::uint64_t>(*artifact_size);
            } else {
                bytes = entry.disk_record.serialized_bytes;
            }
            record_bytes.push_back(bytes);
        }

        const auto configured_limit =
            limits_.persistence_bytes == 0U
                ? maximum_persistence_bytes
                : std::min<std::uintmax_t>(
                      limits_.persistence_bytes, maximum_persistence_bytes);
        constexpr auto fixed_snapshot_bytes = artifact_header_bytes +
                                              artifact_index_v2_header_bytes +
                                              artifact_footer_bytes;
        if (configured_limit < fixed_snapshot_bytes)
            return false;

        struct QuotaEvictedKey {
            const JitArtifactKey* key { };
            std::shared_ptr<const BlockArtifact> owner;
        };
        std::vector<QuotaEvictedKey> quota_evicted_keys;
        std::vector<const JitArtifactKey*> index_keys;
        index_keys.reserve(entries.size());
        for (const auto& entry : entries)
            index_keys.push_back(entry.key);
        auto index_layout = build_compact_index_layout(index_keys, cancelled);
        if (!index_layout)
            return false;
        auto compact_index_size = index_layout->serialized_bytes();
        if (!compact_index_size)
            return false;
        auto index_size = *compact_index_size;
        std::uint64_t candidate_total =
            artifact_header_bytes + index_size + artifact_footer_bytes;
        for (const auto bytes : record_bytes) {
            if (cancelled())
                return false;
            if (bytes >
                std::numeric_limits<std::uint64_t>::max() - candidate_total) {
                return false;
            }
            candidate_total += bytes;
        }

        if (candidate_total > configured_limit) {
            std::vector<std::size_t> candidates;
            candidates.reserve(entries.size());
            for (std::size_t index = 0; index < entries.size(); ++index) {
                if (cancelled())
                    return false;
                candidates.push_back(index);
            }
            if (!stable_sort_cancellable(
                    candidates,
                    [&entries, &record_bytes](
                        std::size_t left, std::size_t right) {
                        const auto& left_entry = entries[left];
                        const auto& right_entry = entries[right];
                        if (left_entry.boot_working_set !=
                            right_entry.boot_working_set) {
                            return left_entry.boot_working_set;
                        }
                        if (left_entry.resident != right_entry.resident) {
                            return left_entry.resident;
                        }
                        if (left_entry.disk_record.benefit_hits !=
                            right_entry.disk_record.benefit_hits) {
                            return left_entry.disk_record.benefit_hits >
                                   right_entry.disk_record.benefit_hits;
                        }
                        if (left_entry.disk_record.translation_nanoseconds !=
                            right_entry.disk_record.translation_nanoseconds) {
                            return left_entry.disk_record
                                       .translation_nanoseconds >
                                   right_entry.disk_record
                                       .translation_nanoseconds;
                        }
                        if (left_entry.disk_record.benefit_generation !=
                            right_entry.disk_record.benefit_generation) {
                            return left_entry.disk_record.benefit_generation >
                                   right_entry.disk_record.benefit_generation;
                        }
                        return record_bytes[left] < record_bytes[right];
                    },
                    cancelled)) {
                return false;
            }

            std::unordered_set<ArtifactIndexImage, ArtifactIndexImageHash>
                selected_images;
            std::unordered_set<ArtifactIndexProfile, ArtifactIndexProfileHash>
                selected_profiles;
            selected_images.reserve(
                std::min<std::size_t>(entries.size(), 1024U));
            selected_profiles.reserve(
                std::min<std::size_t>(entries.size(), 16U));
            std::vector<bool> selected(entries.size());
            std::uint64_t selected_bytes = fixed_snapshot_bytes;
            for (const auto index : candidates) {
                if (cancelled())
                    return false;
                const auto image = index_image_for(*entries[index].key);
                const auto profile = index_profile_for(*entries[index].key);
                const bool new_image = !selected_images.contains(image);
                const bool new_profile = !selected_profiles.contains(profile);
                std::uint64_t additional =
                    record_bytes[index] + artifact_index_v2_entry_bytes;
                if (new_image)
                    additional += artifact_index_image_bytes;
                if (new_profile)
                    additional += artifact_index_profile_bytes;
                if (additional > configured_limit - selected_bytes)
                    continue;
                selected[index] = true;
                selected_bytes += additional;
                if (new_image)
                    selected_images.insert(image);
                if (new_profile)
                    selected_profiles.insert(profile);
            }

            std::vector<std::size_t> retained_indices;
            retained_indices.reserve(entries.size());
            quota_evicted_keys.reserve(entries.size());
            for (std::size_t index = 0; index < entries.size(); ++index) {
                if (selected[index]) {
                    retained_indices.push_back(index);
                } else {
                    quota_evicted_keys.push_back(QuotaEvictedKey {
                        entries[index].key, entries[index].artifact });
                }
            }
            if (!stable_sort_cancellable(
                    retained_indices,
                    [&entries](std::size_t left, std::size_t right) {
                        if (entries[left].boot_working_set !=
                            entries[right].boot_working_set) {
                            // The on-disk order is the restart recency proxy.
                            // Keep protected records at the recent end even
                            // before their process next runs.
                            return !entries[left].boot_working_set;
                        }
                        return entries[left].disk_record.benefit_generation <
                               entries[right].disk_record.benefit_generation;
                    },
                    cancelled)) {
                return false;
            }
            std::vector<SaveEntry> retained_entries;
            std::vector<std::uint64_t> retained_record_bytes;
            retained_entries.reserve(retained_indices.size());
            retained_record_bytes.reserve(retained_indices.size());
            for (const auto index : retained_indices) {
                retained_entries.push_back(std::move(entries[index]));
                retained_record_bytes.push_back(record_bytes[index]);
            }
            entries = std::move(retained_entries);
            record_bytes = std::move(retained_record_bytes);

            index_keys.clear();
            index_keys.reserve(entries.size());
            for (const auto& entry : entries)
                index_keys.push_back(entry.key);
            index_layout = build_compact_index_layout(index_keys, cancelled);
            if (!index_layout)
                return false;
            compact_index_size = index_layout->serialized_bytes();
            if (!compact_index_size)
                return false;
            index_size = *compact_index_size;
        }

        std::vector<const SaveEntry*> hotset_entries;
        hotset_entries.reserve(entries.size());
        for (const auto& entry : entries) {
            if (entry.boot_working_set) {
                hotset_entries.push_back(&entry);
            }
        }
        if (!stable_sort_cancellable(
                hotset_entries,
                [](const auto* left, const auto* right) {
                    if (left->disk_record.benefit_hits !=
                        right->disk_record.benefit_hits) {
                        return left->disk_record.benefit_hits >
                               right->disk_record.benefit_hits;
                    }
                    if (left->disk_record.translation_nanoseconds !=
                        right->disk_record.translation_nanoseconds) {
                        return left->disk_record.translation_nanoseconds >
                               right->disk_record.translation_nanoseconds;
                    }
                    if (left->disk_record.benefit_generation !=
                        right->disk_record.benefit_generation) {
                        return left->disk_record.benefit_generation >
                               right->disk_record.benefit_generation;
                    }
                    return key_order_token(*left->key) <
                           key_order_token(*right->key);
                },
                cancelled)) {
            return false;
        }
        if (hotset_entries.size() > maximum_hotset_entries) {
            hotset_entries.resize(maximum_hotset_entries);
        }
        std::vector<const JitArtifactKey*> hotset_keys;
        hotset_keys.reserve(hotset_entries.size());
        for (const auto* entry : hotset_entries)
            hotset_keys.push_back(entry->key);

        std::size_t serialized_size = artifact_header_bytes;
        bool needs_source = false;
        bool needs_append_source = false;
        for (std::size_t index = 0; index < entries.size(); ++index) {
            if (cancelled())
                return false;
            const auto bytes = record_bytes[index];
            if (bytes > std::numeric_limits<std::size_t>::max() ||
                static_cast<std::size_t>(bytes) >
                    std::numeric_limits<std::size_t>::max() - serialized_size) {
                return false;
            }
            serialized_size += static_cast<std::size_t>(bytes);
            if (!entries[index].resident) {
                if (entries[index].disk_record.append_log) {
                    needs_append_source = true;
                } else {
                    needs_source = true;
                }
            }
        }
        if (serialized_size >
                std::numeric_limits<std::size_t>::max() - index_size ||
            serialized_size + index_size >
                std::numeric_limits<std::size_t>::max() -
                    artifact_footer_bytes) {
            return false;
        }
        const auto total_size =
            serialized_size + index_size + artifact_footer_bytes;
        if (total_size > configured_limit ||
            total_size > maximum_persistence_bytes) {
            return false;
        }
        if (!has_storage_headroom(path, limits_.minimum_free_bytes,
                static_cast<std::uintmax_t>(total_size))) {
            return false;
        }
        std::filesystem::path new_source_path { path };
        std::ifstream source;
        if (needs_source) {
            if (source_path.empty())
                return false;
            source.open(source_path, std::ios::binary);
            if (!source)
                return false;
        }
        std::ifstream append_source;
        if (needs_append_source) {
            if (append_source_path.empty())
                return false;
            append_source.open(append_source_path, std::ios::binary);
            if (!append_source)
                return false;
        }
        const auto parent = path.parent_path();
        if (!parent.empty())
            std::filesystem::create_directories(parent);
        const auto temporary = std::filesystem::path {
            path.string() + ".tmp-" +
            std::to_string(
                std::hash<std::thread::id> { }(std::this_thread::get_id())) +
            "-" +
            std::to_string(
                std::chrono::steady_clock::now().time_since_epoch().count())
        };
        TemporaryPathCleanup temporary_cleanup { compaction_result };
        temporary_cleanup.set(temporary);
        const auto hotset_path = hotset_path_for(path);
        const auto hotset_temporary = std::filesystem::path {
            hotset_path.string() + ".tmp-" +
            std::to_string(
                std::hash<std::thread::id> { }(std::this_thread::get_id())) +
            "-" +
            std::to_string(
                std::chrono::steady_clock::now().time_since_epoch().count())
        };
        TemporaryPathCleanup hotset_cleanup { compaction_result };
        hotset_cleanup.set(hotset_temporary);
        {
            std::ofstream stream { temporary,
                std::ios::binary | std::ios::trunc };
            if (!stream)
                return false;
            stream.write(artifact_magic.data(),
                static_cast<std::streamsize>(artifact_magic.size()));
            write_u32(stream, static_cast<std::uint32_t>(entries.size()));
            std::uint64_t output_offset =
                artifact_magic.size() + sizeof(std::uint32_t);
            std::vector<DiskArtifactRecord> output_records;
            output_records.reserve(entries.size());
            for (std::size_t index = 0; index < entries.size(); ++index) {
                if (cancelled())
                    return false;
                const auto& entry = entries[index];
                const auto bytes = record_bytes[index];
                auto& source_stream =
                    entry.disk_record.append_log ? append_source : source;
                if (!entry.resident && entry.disk_record.checksum_valid) {
                    const auto& record_source = entry.disk_record.append_log
                                                    ? append_source_path
                                                    : source_path;
                    const auto source_checksum = sha256_file(record_source,
                        entry.disk_record.offset, bytes, cancelled);
                    if (cancelled())
                        return false;
                    if (!source_checksum ||
                        *source_checksum != entry.disk_record.checksum) {
                        return false;
                    }
                }
                const bool written =
                    entry.resident ? write_artifact(stream, *entry.artifact,
                                         cancelled, &progress)
                                   : copy_disk_record(source_stream, stream,
                                         entry.disk_record.offset, bytes,
                                         cancelled, &progress);
                if (!written)
                    return false;
                if (progress.records_written !=
                    std::numeric_limits<std::uint64_t>::max()) {
                    ++progress.records_written;
                }
                auto output_record = DiskArtifactRecord { output_offset, bytes,
                    false, { }, false, 0U };
                output_record.benefit_generation =
                    entry.disk_record.benefit_generation;
                output_record.benefit_hits = entry.disk_record.benefit_hits;
                output_record.translation_nanoseconds =
                    entry.disk_record.translation_nanoseconds;
                output_record.boot_working_set = entry.boot_working_set;
                output_records.push_back(std::move(output_record));
                if (output_offset >
                    std::numeric_limits<std::uint64_t>::max() - bytes) {
                    return false;
                }
                output_offset += bytes;
            }
            stream.flush();
            if (!stream ||
                stream.tellp() != static_cast<std::streamoff>(output_offset)) {
                return false;
            }
            stream.close();
            if (!stream || output_offset != serialized_size)
                return false;

            for (std::size_t index = 0; index < entries.size(); ++index) {
                if (cancelled())
                    return false;
                const auto checksum =
                    sha256_file(temporary, output_records[index].offset,
                        output_records[index].serialized_bytes, cancelled);
                if (!checksum)
                    return false;
                output_records[index].checksum = *checksum;
                output_records[index].checksum_valid = true;
            }

            const auto index_offset = output_offset;
            std::vector<SnapshotArtifactWriteEntry> indexed_entries;
            indexed_entries.reserve(entries.size());
            for (std::size_t index = 0; index < entries.size(); ++index) {
                indexed_entries.push_back(SnapshotArtifactWriteEntry {
                    entries[index].key, output_records[index].offset,
                    output_records[index].serialized_bytes,
                    output_records[index].checksum });
            }
            const auto encoded_index =
                encode_compact_index(*index_layout, indexed_entries, cancelled);
            if (cancelled())
                return false;
            if (!encoded_index || encoded_index->size() != index_size)
                return false;
            std::ofstream index_stream { temporary,
                std::ios::binary | std::ios::app };
            if (!index_stream)
                return false;
            if (!write_bytes_cancellable(index_stream, encoded_index->data(),
                    encoded_index->size(), cancelled, &progress)) {
                return false;
            }
            index_stream.flush();
            if (!index_stream ||
                index_stream.tellp() !=
                    static_cast<std::streamoff>(index_offset + index_size)) {
                return false;
            }
            index_stream.close();
            if (!index_stream)
                return false;
            const auto index_checksum = sha256(*encoded_index);
            if (!write_hotset_contents(hotset_temporary, hotset_keys,
                    index_checksum, cancelled, &progress)) {
                return false;
            }

            std::ofstream footer_stream { temporary,
                std::ios::binary | std::ios::app };
            if (!footer_stream)
                return false;
            footer_stream.write(artifact_footer_magic.data(),
                static_cast<std::streamsize>(artifact_footer_magic.size()));
            write_u64(footer_stream, index_offset);
            write_u64(footer_stream, static_cast<std::uint64_t>(index_size));
            write_u32(
                footer_stream, static_cast<std::uint32_t>(entries.size()));
            write_identity(footer_stream, index_checksum);
            footer_stream.flush();
            if (!footer_stream || footer_stream.tellp() !=
                                      static_cast<std::streamoff>(total_size)) {
                return false;
            }
            footer_stream.close();
            if (!footer_stream)
                return false;

            DiskArtifactMap output_index;
            output_index.reserve(entries.size());
            std::vector<const JitArtifactKey*> output_order;
            output_order.reserve(entries.size());
            for (std::size_t index = 0; index < entries.size(); ++index) {
                const auto [iterator, inserted] = output_index.emplace(
                    *entries[index].key, output_records[index]);
                if (!inserted || iterator->first != *entries[index].key)
                    return false;
                output_order.push_back(&iterator->first);
            }

            auto lock = try_lock_cancellable(mutex_, cancellable_check);
            if (!lock) {
                static_cast<void>(cancelled());
                return false;
            }
            if (cancelled())
                return false;
            if (disk_source_path_ != source_path ||
                disk_append_path_ != append_source_path) {
                std::error_code stale_error;
                std::filesystem::remove(temporary, stale_error);
                return false;
            }
            std::error_code error;
            const auto rename_started = std::chrono::steady_clock::now();
            std::filesystem::rename(hotset_temporary, hotset_path, error);
            if (error) {
                if (compaction_result != nullptr) {
                    compaction_result
                        ->rename_nanoseconds = static_cast<std::uint64_t>(
                        std::chrono::duration_cast<std::chrono::nanoseconds>(
                            std::chrono::steady_clock::now() - rename_started)
                            .count());
                }
                error.clear();
                return false;
            }
            hotset_cleanup.release();
            std::filesystem::rename(temporary, path, error);
            if (compaction_result != nullptr) {
                compaction_result->rename_nanoseconds =
                    static_cast<std::uint64_t>(
                        std::chrono::duration_cast<std::chrono::nanoseconds>(
                            std::chrono::steady_clock::now() - rename_started)
                            .count());
            }
            if (error) {
                error.clear();
                // The old snapshot remains authoritative if its publish fails.
                // Remove the newly published sidecar so a crash cannot pair it
                // with that old snapshot; a missing sidecar is a safe
                // zero-prefetch state.
                std::filesystem::remove(hotset_path, error);
                return false;
            }
            temporary_cleanup.release();
            for (auto& entry : output_index) {
                const auto current_disk = disk_artifacts_.find(entry.first);
                const auto resident = artifacts_.find(entry.first);
                const auto pending = pending_writebacks_.find(entry.first);
                if (current_disk != disk_artifacts_.end()) {
                    entry.second.benefit_generation =
                        std::max(entry.second.benefit_generation,
                            current_disk->second.benefit_generation);
                    entry.second.benefit_hits =
                        std::max(entry.second.benefit_hits,
                            current_disk->second.benefit_hits);
                }
                if (resident != artifacts_.end()) {
                    entry.second.benefit_generation =
                        std::max(entry.second.benefit_generation,
                            resident->second.benefit_generation);
                    entry.second.benefit_hits =
                        std::max(entry.second.benefit_hits,
                            resident->second.benefit_hits);
                    entry.second.translation_nanoseconds =
                        std::max(entry.second.translation_nanoseconds,
                            resident->second.artifact->data
                                .translation_nanoseconds);
                }
                if (pending != pending_writebacks_.end()) {
                    entry.second.benefit_generation =
                        std::max(entry.second.benefit_generation,
                            pending->second.benefit_generation);
                    entry.second.benefit_hits =
                        std::max(entry.second.benefit_hits,
                            pending->second.benefit_hits);
                    entry.second.translation_nanoseconds = std::max(
                        entry.second.translation_nanoseconds,
                        pending->second.artifact->data.translation_nanoseconds);
                }
                entry.second.boot_working_set =
                    entry.second.boot_working_set ||
                    (current_disk != disk_artifacts_.end() &&
                        current_disk->second.boot_working_set) ||
                    (resident != artifacts_.end() &&
                        resident->second.boot_working_set) ||
                    (pending != pending_writebacks_.end() &&
                        pending->second.boot_working_set);
                entry.second.generation = next_disk_generation_locked();
            }
            // Disk-backed SaveEntry pointers still refer to the old index.
            // Retire pending owners before replacing that index, while every
            // key is valid.
            for (const auto& entry : entries) {
                retire_writeback_locked(*entry.key);
            }
            for (const auto& entry : quota_evicted_keys) {
                retire_writeback_locked(*entry.key);
            }
            disk_artifacts_ = std::move(output_index);
            disk_order_ = std::move(output_order);
            disk_source_path_ = std::move(new_source_path);
            disk_append_path_ = append_path_for(path);
            disk_append_valid_bytes_ = 0;
            disk_append_indexed_ = true;
            disk_snapshot_id_ = index_checksum;
            stats_.disk_records_indexed = disk_artifacts_.size();
            stats_.index_bytes = index_size;
            // The snapshot and sidecar were written without holding the store
            // lock. Preserve a concurrent membership or confirmed-benefit
            // mutation so a subsequent save republishes ranking that was not in
            // this snapshot.
            hotset_dirty_ = hotset_mutation_generation_ !=
                                saved_hotset_mutation_generation ||
                            benefit_generation_ != saved_benefit_generation;
            stats_.quota_evictions += quota_evicted_keys.size();
            std::error_code sidecar_error;
            std::filesystem::remove(disk_append_path_, sidecar_error);
            return true;
        }
    } catch (...) {
        return false;
    }
}

ExecutionContext::ExecutionContext()
    : context_id_ { next_context_id.fetch_add(1, std::memory_order_relaxed) }
    , native_code_slab_ { std::make_shared<Umbra::A32::NativeCodeSlab>() }
{
}

ExecutionContext::ExecutionContext(std::uint32_t process_id)
    : ExecutionContext { }
{
    bind_process_id(process_id);
}

ExecutionContext::~ExecutionContext() = default;

void ExecutionContext::bind_process_id(std::uint32_t process_id)
{
    const std::lock_guard lock { mutex_ };
    if (process_id_bound_) {
        if (process_id_.load(std::memory_order_relaxed) != process_id) {
            throw std::logic_error {
                "execution context cannot be rebound to another process"
            };
        }
        return;
    }
    process_id_.store(process_id, std::memory_order_release);
    process_id_bound_ = true;
}

std::size_t ExecutionContext::create_link_cell()
{
    const std::lock_guard lock { mutex_ };
    link_cells_.push_back(std::make_unique<LinkCell>());
    return link_cells_.size() - 1U;
}

void ExecutionContext::link(std::size_t cell, std::uint64_t target_token)
{
    const std::lock_guard lock { mutex_ };
    link_cells_.at(cell)->target_token.store(
        target_token, std::memory_order_release);
}

void ExecutionContext::unlink(std::size_t cell) { link(cell, 0); }

std::uint64_t ExecutionContext::linked_target(std::size_t cell) const
{
    const std::lock_guard lock { mutex_ };
    return link_cells_.at(cell)->target_token.load(std::memory_order_acquire);
}

std::atomic<std::uint64_t>* ExecutionContext::link_cell_address(
    std::size_t cell) const
{
    const std::lock_guard lock { mutex_ };
    return &link_cells_.at(cell)->target_token;
}

Umbra::A32::NativeCodeSlab*
ExecutionContext::native_code_slab() const noexcept
{
    return native_code_slab_.get();
}

std::uint64_t ExecutionContext::request_cache_clear()
{
    const std::lock_guard lock { invalidation_mutex_ };
    native_code_slab_->request_cache_clear();
    auto clear_epoch =
        cache_clear_epoch_.fetch_add(1U, std::memory_order_acq_rel) + 1U;
    if (clear_epoch == 0U) {
        cache_clear_epoch_.store(1U, std::memory_order_release);
    }
    auto epoch =
        cache_invalidation_epoch_.fetch_add(1U, std::memory_order_acq_rel) + 1U;
    if (epoch == 0U) {
        cache_invalidation_epoch_.store(1U, std::memory_order_release);
        epoch = 1U;
    }
    return epoch;
}

std::uint64_t ExecutionContext::request_cache_range(
    std::uint32_t address, std::size_t length)
{
    if (length == 0U)
        return cache_invalidation_epoch();
    const std::lock_guard lock { invalidation_mutex_ };
    native_code_slab_->request_cache_range(address, length);
    auto epoch =
        cache_invalidation_epoch_.fetch_add(1U, std::memory_order_acq_rel) + 1U;
    if (epoch == 0U) {
        cache_invalidation_epoch_.store(1U, std::memory_order_release);
        epoch = 1U;
    }
    return epoch;
}

bool ExecutionContext::observe_slab_generation(
    std::uint64_t generation) noexcept
{
    if (generation == 0U)
        return false;
    auto observed = observed_slab_generation_.load(std::memory_order_acquire);
    for (;;) {
        if (observed == generation)
            return false;
        if (observed == 0U) {
            if (observed_slab_generation_.compare_exchange_weak(observed,
                    generation, std::memory_order_acq_rel,
                    std::memory_order_acquire)) {
                return false;
            }
            continue;
        }
        if (observed_slab_generation_.compare_exchange_weak(observed,
                generation, std::memory_order_acq_rel,
                std::memory_order_acquire)) {
            return true;
        }
    }
}

} // namespace shade
