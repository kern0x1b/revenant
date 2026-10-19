// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Record and persist bounded translation working sets for future JIT
// preparation.

#include "foundation/jit_translation_profile.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <fstream>
#include <iterator>
#include <limits>
#include <optional>
#include <span>
#include <sstream>
#include <system_error>
#include <utility>

namespace shade {
namespace {

    constexpr std::array<char, 8> profile_magic { 'i', 'L', 'J', 'T', 'P', 'R',
        'F', '3' };
    constexpr std::uint32_t profile_schema_version = 3U;
    constexpr std::array<char, 8> profile_index_magic { 'i', 'L', 'J', 'T', 'I',
        'D', 'X', '1' };
    constexpr std::uint32_t profile_index_schema_version = 1U;
    constexpr std::uint64_t fnv_offset_basis = 14695981039346656037ULL;
    constexpr std::uint64_t fnv_prime = 1099511628211ULL;
    constexpr std::size_t profile_identity_bytes =
        sizeof(ContentIdentity { }.digest);
    constexpr std::size_t profile_header_bytes =
        profile_magic.size() + sizeof(std::uint32_t) + sizeof(std::uint32_t) +
        sizeof(std::uint64_t) + profile_identity_bytes;

    void hash_bytes(
        std::uint64_t& hash, const void* data, std::size_t size) noexcept
    {
        const auto* bytes = static_cast<const unsigned char*>(data);
        for (std::size_t index = 0; index < size; ++index) {
            hash ^= bytes[index];
            hash *= fnv_prime;
        }
    }

    std::uint64_t profile_checksum(const ContentIdentity& identity,
        std::span<const std::uint64_t> locations) noexcept
    {
        auto hash = fnv_offset_basis;
        hash_bytes(hash, identity.digest.data(), identity.digest.size());
        for (const auto location : locations) {
            for (unsigned shift = 0; shift < 64; shift += 8) {
                const auto byte = static_cast<unsigned char>(location >> shift);
                hash_bytes(hash, &byte, 1);
            }
        }
        return hash;
    }

    std::string profile_file_stem(const ContentIdentity& identity)
    {
        return identity.hex();
    }

    std::filesystem::path profile_index_path(
        const std::filesystem::path& directory)
    {
        return directory / "profiles.index";
    }

    void write_u32(std::ostream& stream, std::uint32_t value)
    {
        for (unsigned shift = 0; shift < 32; shift += 8) {
            stream.put(static_cast<char>(value >> shift));
        }
    }

    void write_u64(std::ostream& stream, std::uint64_t value)
    {
        for (unsigned shift = 0; shift < 64; shift += 8) {
            stream.put(static_cast<char>(value >> shift));
        }
    }

    std::optional<std::uint32_t> read_u32(std::istream& stream)
    {
        std::uint32_t value = 0;
        for (unsigned shift = 0; shift < 32; shift += 8) {
            const auto byte = stream.get();
            if (byte == std::char_traits<char>::eof())
                return std::nullopt;
            value |=
                static_cast<std::uint32_t>(static_cast<unsigned char>(byte))
                << shift;
        }
        return value;
    }

    std::optional<std::uint64_t> read_u64(std::istream& stream)
    {
        std::uint64_t value = 0;
        for (unsigned shift = 0; shift < 64; shift += 8) {
            const auto byte = stream.get();
            if (byte == std::char_traits<char>::eof())
                return std::nullopt;
            value |=
                static_cast<std::uint64_t>(static_cast<unsigned char>(byte))
                << shift;
        }
        return value;
    }

    struct ProfileLoadResult {
        std::vector<std::uint64_t> locations;
        std::uint64_t file_bytes { };
        bool accepted { };
    };

    ProfileLoadResult load_profile(const std::filesystem::path& path,
        const ContentIdentity& expected_identity)
    {
        std::error_code error;
        const auto file_bytes = std::filesystem::file_size(path, error);
        if (error || file_bytes < profile_header_bytes ||
            file_bytes > jit_translation_profile_maximum_file_bytes) {
            return { };
        }
        std::ifstream stream { path, std::ios::binary };
        if (!stream)
            return { };

        std::array<char, profile_magic.size()> magic { };
        stream.read(magic.data(), static_cast<std::streamsize>(magic.size()));
        const auto schema = read_u32(stream);
        const auto location_count = read_u32(stream);
        const auto expected_checksum = read_u64(stream);
        ContentIdentity identity;
        stream.read(reinterpret_cast<char*>(identity.digest.data()),
            static_cast<std::streamsize>(identity.digest.size()));
        if (!stream || magic != profile_magic || !schema ||
            *schema != profile_schema_version || !location_count ||
            !expected_checksum || identity != expected_identity ||
            *location_count > jit_translation_profile_maximum_locations) {
            return { };
        }
        const auto expected_bytes =
            profile_header_bytes +
            static_cast<std::size_t>(*location_count) * sizeof(std::uint64_t);
        if (expected_bytes != file_bytes)
            return { };

        ProfileLoadResult result;
        result.locations.reserve(*location_count);
        for (std::uint32_t index = 0; index < *location_count; ++index) {
            const auto location = read_u64(stream);
            if (!location)
                return { };
            result.locations.push_back(*location);
        }
        if (stream.peek() != std::char_traits<char>::eof() ||
            profile_checksum(identity, result.locations) !=
                *expected_checksum) {
            return { };
        }
        result.file_bytes = file_bytes;
        result.accepted = true;
        return result;
    }

    bool save_profile(const std::filesystem::path& directory,
        const ContentIdentity& identity,
        std::span<const std::uint64_t> locations)
    {
        if (identity.empty() || locations.empty() ||
            locations.size() > jit_translation_profile_maximum_locations) {
            return false;
        }
        const auto expected_bytes =
            profile_header_bytes + locations.size() * sizeof(std::uint64_t);
        if (expected_bytes > jit_translation_profile_maximum_file_bytes) {
            return false;
        }
        std::filesystem::create_directories(directory);
        const auto stem = profile_file_stem(identity);
        const auto target = directory / (stem + ".profile");
        const auto temporary = directory / (stem + ".profile.tmp");
        {
            std::ofstream stream { temporary,
                std::ios::binary | std::ios::trunc };
            if (!stream)
                return false;
            stream.write(profile_magic.data(),
                static_cast<std::streamsize>(profile_magic.size()));
            write_u32(stream, profile_schema_version);
            write_u32(stream, static_cast<std::uint32_t>(locations.size()));
            write_u64(stream, profile_checksum(identity, locations));
            stream.write(reinterpret_cast<const char*>(identity.digest.data()),
                static_cast<std::streamsize>(identity.digest.size()));
            for (const auto location : locations)
                write_u64(stream, location);
            stream.flush();
            if (!stream)
                return false;
        }
        std::error_code error;
        std::filesystem::rename(temporary, target, error);
        if (error) {
            error.clear();
            std::filesystem::remove(temporary, error);
            return false;
        }
        return true;
    }

    struct ProfileIndexRecord {
        ContentIdentity identity;
        std::uint64_t access_order { };
        std::uint64_t file_bytes { };
    };

    std::vector<ProfileIndexRecord> load_profile_index(
        const std::filesystem::path& path)
    {
        std::error_code error;
        const auto file_bytes = std::filesystem::file_size(path, error);
        constexpr std::size_t fixed_bytes = profile_index_magic.size() +
                                            sizeof(std::uint32_t) * 2U +
                                            sizeof(std::uint64_t);
        constexpr std::size_t record_bytes =
            profile_identity_bytes + sizeof(std::uint64_t) * 2U;
        if (error || file_bytes < fixed_bytes ||
            file_bytes > jit_translation_profile_maximum_file_bytes) {
            return { };
        }
        std::ifstream stream { path, std::ios::binary };
        if (!stream)
            return { };
        std::array<char, profile_index_magic.size()> magic { };
        stream.read(magic.data(), static_cast<std::streamsize>(magic.size()));
        const auto schema = read_u32(stream);
        const auto count = read_u32(stream);
        const auto checksum = read_u64(stream);
        if (!stream || magic != profile_index_magic || !schema ||
            *schema != profile_index_schema_version || !count ||
            *count > jit_translation_profile_maximum_profiles || !checksum ||
            fixed_bytes + static_cast<std::size_t>(*count) * record_bytes !=
                file_bytes) {
            return { };
        }
        std::vector<std::byte> material;
        material.reserve(static_cast<std::size_t>(*count) * record_bytes);
        std::vector<ProfileIndexRecord> result;
        result.reserve(*count);
        auto append_u64_bytes = [&material](std::uint64_t value) {
            for (unsigned shift = 0; shift < 64; shift += 8) {
                material.push_back(static_cast<std::byte>(value >> shift));
            }
        };
        for (std::uint32_t index = 0; index < *count; ++index) {
            ProfileIndexRecord record;
            stream.read(reinterpret_cast<char*>(record.identity.digest.data()),
                static_cast<std::streamsize>(record.identity.digest.size()));
            const auto access_order = read_u64(stream);
            const auto bytes = read_u64(stream);
            if (!stream || !access_order || !bytes ||
                *bytes > jit_translation_profile_maximum_file_bytes) {
                return { };
            }
            record.access_order = *access_order;
            record.file_bytes = *bytes;
            material.insert(material.end(),
                reinterpret_cast<const std::byte*>(
                    record.identity.digest.data()),
                reinterpret_cast<const std::byte*>(
                    record.identity.digest.data()) +
                    record.identity.digest.size());
            append_u64_bytes(record.access_order);
            append_u64_bytes(record.file_bytes);
            result.push_back(record);
        }
        if (stream.peek() != std::char_traits<char>::eof())
            return { };
        auto computed = fnv_offset_basis;
        hash_bytes(computed, material.data(), material.size());
        if (computed != *checksum)
            return { };
        return result;
    }

    bool save_profile_index(const std::filesystem::path& directory,
        const std::map<ContentIdentity, std::uint64_t>& access_order,
        const std::map<ContentIdentity, std::size_t>& file_bytes)
    {
        if (access_order.size() > jit_translation_profile_maximum_profiles) {
            return false;
        }
        std::vector<std::byte> material;
        material.reserve(access_order.size() *
                         (profile_identity_bytes + sizeof(std::uint64_t) * 2U));
        auto append_u64_bytes = [&material](std::uint64_t value) {
            for (unsigned shift = 0; shift < 64; shift += 8) {
                material.push_back(static_cast<std::byte>(value >> shift));
            }
        };
        for (const auto& [identity, access] : access_order) {
            material.insert(material.end(),
                reinterpret_cast<const std::byte*>(identity.digest.data()),
                reinterpret_cast<const std::byte*>(identity.digest.data()) +
                    identity.digest.size());
            append_u64_bytes(access);
            const auto bytes = file_bytes.find(identity);
            append_u64_bytes(bytes == file_bytes.end() ? 0U : bytes->second);
        }
        auto checksum = fnv_offset_basis;
        hash_bytes(checksum, material.data(), material.size());

        std::filesystem::create_directories(directory);
        const auto target = profile_index_path(directory);
        const auto temporary = directory / "profiles.index.tmp";
        {
            std::ofstream stream { temporary,
                std::ios::binary | std::ios::trunc };
            if (!stream)
                return false;
            stream.write(profile_index_magic.data(),
                static_cast<std::streamsize>(profile_index_magic.size()));
            write_u32(stream, profile_index_schema_version);
            write_u32(stream, static_cast<std::uint32_t>(access_order.size()));
            write_u64(stream, checksum);
            for (const auto& [identity, access] : access_order) {
                stream.write(
                    reinterpret_cast<const char*>(identity.digest.data()),
                    static_cast<std::streamsize>(identity.digest.size()));
                write_u64(stream, access);
                const auto bytes = file_bytes.find(identity);
                write_u64(
                    stream, bytes == file_bytes.end() ? 0U : bytes->second);
            }
            stream.flush();
            if (!stream)
                return false;
        }
        std::error_code error;
        std::filesystem::rename(temporary, target, error);
        if (error) {
            error.clear();
            std::filesystem::remove(temporary, error);
            return false;
        }
        return true;
    }

} // namespace

std::size_t JitTranslationProfileRecorder::hash(
    std::uint64_t location_descriptor) noexcept
{
    auto value = location_descriptor;
    value ^= value >> 30U;
    value *= 0xbf58476d1ce4e5b9ULL;
    value ^= value >> 27U;
    value *= 0x94d049bb133111ebULL;
    value ^= value >> 31U;
    return static_cast<std::size_t>(value);
}

bool JitTranslationProfileRecorder::contains(
    std::span<const std::uint64_t> table,
    std::uint64_t location_descriptor) noexcept
{
    auto slot = hash(location_descriptor) & (table.size() - 1U);
    for (std::size_t probe = 0; probe < table.size(); ++probe) {
        const auto known = table[slot];
        if (known == location_descriptor)
            return true;
        if (known == 0U)
            return false;
        slot = (slot + 1U) & (table.size() - 1U);
    }
    return false;
}

bool JitTranslationProfileRecorder::insert(std::span<std::uint64_t> table,
    std::uint64_t location_descriptor) noexcept
{
    auto slot = hash(location_descriptor) & (table.size() - 1U);
    for (std::size_t probe = 0; probe < table.size(); ++probe) {
        auto& known = table[slot];
        if (known == location_descriptor)
            return true;
        if (known == 0U) {
            known = location_descriptor;
            return true;
        }
        slot = (slot + 1U) & (table.size() - 1U);
    }
    return false;
}

JitTranslationProfileRecordResult JitTranslationProfileRecorder::record(
    std::uint64_t location_descriptor) noexcept
{
    if (location_descriptor == 0) {
        return JitTranslationProfileRecordResult::Ignored;
    }
    if (contains(prefix_hash_, location_descriptor) ||
        contains(recent_hashes_[0], location_descriptor) ||
        contains(recent_hashes_[1], location_descriptor)) {
        ++deduplicated_;
        return JitTranslationProfileRecordResult::Deduplicated;
    }
    if (prefix_size_ < prefix_locations_.size()) {
        if (!insert(prefix_hash_, location_descriptor)) {
            ++dropped_capacity_;
            return JitTranslationProfileRecordResult::DroppedCapacity;
        }
        prefix_locations_[prefix_size_++] = location_descriptor;
        if (work_signal_)
            work_signal_->notify_work();
        return JitTranslationProfileRecordResult::Recorded;
    }

    if (recent_sizes_[active_recent_bank_] ==
        recent_locations_[active_recent_bank_].size()) {
        active_recent_bank_ = 1U - active_recent_bank_;
        dropped_capacity_ += recent_sizes_[active_recent_bank_];
        recent_sizes_[active_recent_bank_] = 0U;
        recent_hashes_[active_recent_bank_].fill(0U);
        recent_sequences_[active_recent_bank_] = next_recent_sequence_++;
        if (next_recent_sequence_ == 0U)
            next_recent_sequence_ = 1U;
    }
    if (!insert(recent_hashes_[active_recent_bank_], location_descriptor)) {
        ++dropped_capacity_;
        return JitTranslationProfileRecordResult::DroppedCapacity;
    }
    recent_locations_[active_recent_bank_]
                     [recent_sizes_[active_recent_bank_]++] =
        location_descriptor;
    if (work_signal_)
        work_signal_->notify_work();
    return JitTranslationProfileRecordResult::Recorded;
}

std::vector<std::uint64_t> JitTranslationProfileRecorder::snapshot() const
{
    std::vector<std::uint64_t> result;
    result.reserve(size());
    result.insert(result.end(), prefix_locations_.begin(),
        std::next(prefix_locations_.begin(),
            static_cast<std::ptrdiff_t>(prefix_size_)));
    const auto first_recent =
        recent_sequences_[0] <= recent_sequences_[1] ? 0U : 1U;
    for (const auto bank : { first_recent, 1U - first_recent }) {
        result.insert(result.end(), recent_locations_[bank].begin(),
            std::next(recent_locations_[bank].begin(),
                static_cast<std::ptrdiff_t>(recent_sizes_[bank])));
    }
    return result;
}

void JitTranslationProfileRecorder::reset() noexcept
{
    prefix_hash_.fill(0U);
    for (auto& hash_table : recent_hashes_)
        hash_table.fill(0U);
    prefix_size_ = 0U;
    recent_sizes_.fill(0U);
    recent_sequences_ = { 1U, 0U };
    active_recent_bank_ = 0U;
    next_recent_sequence_ = 2U;
    deduplicated_ = 0;
    dropped_capacity_ = 0;
}

JitTranslationProfile::JitTranslationProfile(
    std::vector<std::uint64_t> location_descriptors)
{
    const auto retained = std::min(
        location_descriptors.size(), jit_translation_profile_maximum_locations);
    known_locations_.reserve(retained);
    for (std::size_t index = 0; index < retained; ++index) {
        const auto location = location_descriptors[index];
        if (location != 0 && known_locations_.insert(location).second) {
            locations_.push_back(location);
        }
    }
    if (location_descriptors.size() > retained) {
        dropped_capacity_.fetch_add(
            location_descriptors.size() - retained, std::memory_order_relaxed);
    }
}

void JitTranslationProfile::record(std::uint64_t location_descriptor) noexcept
{
    if (location_descriptor == 0)
        return;
    merge(std::span<const std::uint64_t> { &location_descriptor, 1U });
}

void JitTranslationProfile::merge(
    std::span<const std::uint64_t> location_descriptors,
    std::uint64_t recorder_deduplicated,
    std::uint64_t recorder_dropped_capacity,
    std::size_t activation_prefix_locations) noexcept
{
    const auto started = std::chrono::steady_clock::now();
    std::uint64_t recorded = 0;
    std::uint64_t deduplicated = recorder_deduplicated;
    std::uint64_t dropped = recorder_dropped_capacity;
    std::uint64_t evicted = 0;
    try {
        const std::lock_guard lock { mutex_ };

        // Build the replacement off to the side so allocation failure leaves
        // the current profile intact. Recorder batches are already unique,
        // but merge() is public and still validates arbitrary callers.
        std::vector<std::uint64_t> recent_locations;
        recent_locations.reserve(std::min(location_descriptors.size(),
            jit_translation_profile_maximum_locations));
        std::unordered_set<std::uint64_t> recent_set;
        recent_set.reserve(recent_locations.capacity());
        for (const auto location_descriptor : location_descriptors) {
            if (location_descriptor == 0 ||
                discarded_locations_.contains(location_descriptor)) {
                ++deduplicated;
                continue;
            }
            if (!recent_set.insert(location_descriptor).second) {
                ++deduplicated;
                continue;
            }
            recent_locations.push_back(location_descriptor);
            if (known_locations_.contains(location_descriptor)) {
                ++deduplicated;
            } else {
                ++recorded;
            }
        }

        if (recent_locations.size() >
            jit_translation_profile_maximum_locations) {
            const auto excess = recent_locations.size() -
                                jit_translation_profile_maximum_locations;
            for (std::size_t index = 0; index < excess; ++index) {
                if (!known_locations_.contains(recent_locations[index]))
                    --recorded;
            }
            recent_locations.erase(recent_locations.begin(),
                std::next(recent_locations.begin(),
                    static_cast<std::ptrdiff_t>(excess)));
            dropped += excess;
            recent_set.clear();
            recent_set.reserve(recent_locations.size());
            recent_set.insert(recent_locations.begin(), recent_locations.end());
        }

        const auto activation_count = std::min(
            activation_prefix_locations, recent_locations.size());
        std::vector<std::uint64_t> replacement;
        replacement.reserve(jit_translation_profile_maximum_locations);
        replacement.insert(replacement.end(), recent_locations.begin(),
            std::next(recent_locations.begin(),
                static_cast<std::ptrdiff_t>(activation_count)));
        std::vector<std::uint64_t> historical_locations;
        historical_locations.reserve(locations_.size());
        for (const auto location : locations_) {
            if (known_locations_.contains(location) &&
                !recent_set.contains(location)) {
                historical_locations.push_back(location);
            }
        }
        const auto retained_old =
            jit_translation_profile_maximum_locations - recent_locations.size();
        if (historical_locations.size() > retained_old) {
            const auto excess = historical_locations.size() - retained_old;
            historical_locations.erase(historical_locations.begin(),
                std::next(historical_locations.begin(),
                    static_cast<std::ptrdiff_t>(excess)));
            evicted += excess;
        }
        replacement.insert(replacement.end(), historical_locations.begin(),
            historical_locations.end());
        replacement.insert(replacement.end(),
            std::next(recent_locations.begin(),
                static_cast<std::ptrdiff_t>(activation_count)),
            recent_locations.end());

        if (replacement != locations_) {
            std::unordered_set<std::uint64_t> replacement_known;
            replacement_known.reserve(replacement.size());
            replacement_known.insert(replacement.begin(), replacement.end());
            for (const auto location : known_locations_) {
                if (!replacement_known.contains(location)) {
                    profile_portable_artifact_locations_.erase(location);
                }
            }
            locations_.swap(replacement);
            known_locations_.swap(replacement_known);
            revision_.fetch_add(1U, std::memory_order_release);
        }
    } catch (...) {
        dropped += location_descriptors.size();
        recorded = 0;
        evicted = 0;
    }
    recorded_.fetch_add(recorded, std::memory_order_relaxed);
    deduplicated_.fetch_add(deduplicated, std::memory_order_relaxed);
    recorder_deduplicated_.fetch_add(
        recorder_deduplicated, std::memory_order_relaxed);
    recorder_dropped_capacity_.fetch_add(
        recorder_dropped_capacity, std::memory_order_relaxed);
    dropped_capacity_.fetch_add(dropped, std::memory_order_relaxed);
    working_set_evicted_.fetch_add(evicted, std::memory_order_relaxed);
    const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - started);
    merge_calls_.fetch_add(1, std::memory_order_relaxed);
    merge_nanoseconds_.fetch_add(
        static_cast<std::uint64_t>(std::max<std::int64_t>(0, elapsed.count())),
        std::memory_order_relaxed);
}

void JitTranslationProfile::discard(std::uint64_t location_descriptor) noexcept
{
    if (location_descriptor == 0)
        return;
    try {
        const std::lock_guard lock { mutex_ };
        profile_portable_artifact_locations_.erase(location_descriptor);
        if (!known_locations_.contains(location_descriptor))
            return;
        discarded_locations_.insert(location_descriptor);
        known_locations_.erase(location_descriptor);
        revision_.fetch_add(1U, std::memory_order_release);
    } catch (...) {
        // Invalidating a host optimization hint must not affect the guest.
    }
}

std::vector<std::uint64_t> JitTranslationProfile::snapshot() const
{
    const std::lock_guard lock { mutex_ };
    std::vector<std::uint64_t> result;
    result.reserve(known_locations_.size());
    for (const auto location : locations_) {
        if (known_locations_.contains(location))
            result.push_back(location);
    }
    return result;
}

JitTranslationProfilePrediction
JitTranslationProfile::snapshot_prediction() const
{
    return snapshot_prediction(JitTranslationProfilePredictionLimits {
        jit_translation_profile_activation_prediction_capacity,
        jit_translation_profile_recent_prediction_capacity,
        jit_translation_profile_maximum_locations });
}

JitTranslationProfilePrediction JitTranslationProfile::snapshot_prediction(
    JitTranslationProfilePredictionLimits limits) const
{
    const std::lock_guard lock { mutex_ };
    JitTranslationProfilePrediction result;
    const auto maximum = std::min(known_locations_.size(),
        limits.activation_locations + limits.recent_locations +
            limits.historical_locations);
    result.ordered_locations.reserve(maximum);

    std::size_t activation_end { };
    for (; activation_end < locations_.size() &&
         result.ordered_locations.size() < limits.activation_locations;
         ++activation_end) {
        const auto location = locations_[activation_end];
        if (known_locations_.contains(location))
            result.ordered_locations.push_back(location);
    }

    std::size_t recent_begin = locations_.size();
    result.recent_locations.reserve(
        std::min(limits.recent_locations, known_locations_.size()));
    while (recent_begin > activation_end &&
           result.recent_locations.size() < limits.recent_locations) {
        --recent_begin;
        const auto location = locations_[recent_begin];
        if (!known_locations_.contains(location))
            continue;
        result.ordered_locations.push_back(location);
        result.recent_locations.push_back(location);
    }

    std::size_t historical_count { };
    for (auto index = activation_end;
         index < recent_begin &&
         historical_count < limits.historical_locations;
         ++index) {
        const auto location = locations_[index];
        if (!known_locations_.contains(location))
            continue;
        result.ordered_locations.push_back(location);
        ++historical_count;
    }
    return result;
}

std::pair<std::vector<std::uint64_t>, std::size_t>
JitTranslationProfile::snapshot_range(
    std::size_t offset, std::size_t maximum) const
{
    const std::lock_guard lock { mutex_ };
    const auto start = std::min(offset, locations_.size());
    std::vector<std::uint64_t> result;
    result.reserve(std::min(maximum, locations_.size() - start));
    std::size_t cursor = start;
    for (; cursor < locations_.size() && result.size() < maximum; ++cursor) {
        const auto location = locations_[cursor];
        if (known_locations_.contains(location))
            result.push_back(location);
    }
    return { std::move(result), cursor };
}

std::pair<std::vector<std::uint64_t>, std::size_t>
JitTranslationProfile::snapshot_recent_range(
    std::size_t offset, std::size_t maximum) const
{
    const std::lock_guard lock { mutex_ };
    const auto start = std::min(offset, locations_.size());
    std::vector<std::uint64_t> result;
    result.reserve(std::min(maximum, locations_.size() - start));
    std::size_t cursor = start;
    for (; cursor < locations_.size() && result.size() < maximum; ++cursor) {
        const auto location = locations_[locations_.size() - cursor - 1U];
        if (known_locations_.contains(location))
            result.push_back(location);
    }
    return { std::move(result), cursor };
}

std::pair<std::vector<std::uint64_t>, std::size_t>
JitTranslationProfile::snapshot_recent_missing_portable_range(
    std::size_t offset, std::size_t maximum) const
{
    const std::lock_guard lock { mutex_ };
    const auto start = std::min(offset, locations_.size());
    std::vector<std::uint64_t> result;
    result.reserve(std::min(maximum, locations_.size() - start));
    std::size_t cursor = start;
    for (; cursor < locations_.size() && result.size() < maximum; ++cursor) {
        const auto location =
            locations_[locations_.size() - cursor - 1U];
        if (known_locations_.contains(location) &&
            !profile_portable_artifact_locations_.contains(location)) {
            result.push_back(location);
        }
    }
    return { std::move(result), cursor };
}

std::size_t JitTranslationProfile::storage_size() const noexcept
{
    const std::lock_guard lock { mutex_ };
    return locations_.size();
}

JitTranslationProfileStats JitTranslationProfile::stats() const noexcept
{
    JitTranslationProfileStats result;
    result.recorded = recorded_.load(std::memory_order_relaxed);
    result.recorded_descriptors = result.recorded;
    result.newly_recorded_descriptors = result.recorded;
    result.deduplicated = deduplicated_.load(std::memory_order_relaxed);
    result.recorder_deduplicated =
        recorder_deduplicated_.load(std::memory_order_relaxed);
    result.recorder_dropped_capacity =
        recorder_dropped_capacity_.load(std::memory_order_relaxed);
    result.dropped_capacity = dropped_capacity_.load(std::memory_order_relaxed);
    result.working_set_evicted =
        working_set_evicted_.load(std::memory_order_relaxed);
    result.unstable_dropped = unstable_dropped_.load(std::memory_order_relaxed);
    result.profile_loaded = profile_loaded_.load(std::memory_order_relaxed);
    result.disk_descriptors_loaded = result.profile_loaded;
    result.profile_files_loaded =
        profile_files_loaded_.load(std::memory_order_relaxed);
    result.disk_files_loaded = result.profile_files_loaded;
    result.profile_enqueued_portable =
        profile_enqueued_portable_.load(std::memory_order_relaxed);
    result.profile_native_enqueued =
        profile_native_enqueued_.load(std::memory_order_relaxed);
    result.profile_native_attempted =
        profile_native_attempted_.load(std::memory_order_relaxed);
    result.profile_native_executed =
        profile_native_executed_.load(std::memory_order_relaxed);
    result.profile_portable_attempted =
        profile_portable_attempted_.load(std::memory_order_relaxed);
    result.profile_portable_executed =
        profile_portable_executed_.load(std::memory_order_relaxed);
    result.profile_portable_generated =
        profile_portable_generated_.load(std::memory_order_relaxed);
    result.portable_existence_hits =
        portable_existence_hits_.load(std::memory_order_relaxed);
    result.native_preimport_attempted =
        native_preimport_attempted_.load(std::memory_order_relaxed);
    result.native_preimport_imported =
        native_preimport_imported_.load(std::memory_order_relaxed);
    result.native_preimport_already_present =
        native_preimport_already_present_.load(std::memory_order_relaxed);
    result.native_preimport_before_first_demand =
        native_preimport_before_first_demand_.load(std::memory_order_relaxed);
    result.native_preimport_used =
        native_preimport_used_.load(std::memory_order_relaxed);
    result.native_preimport_first_use_distance_samples =
        native_preimport_first_use_distance_samples_.load(
            std::memory_order_relaxed);
    result.native_preimport_first_use_distance_total =
        native_preimport_first_use_distance_total_.load(
            std::memory_order_relaxed);
    result.demand_artifact_staged =
        demand_artifact_staged_.load(std::memory_order_relaxed);
    result.demand_artifact_consumed =
        demand_artifact_consumed_.load(std::memory_order_relaxed);
    result.profile_portable_artifact_consumed =
        profile_portable_artifact_consumed_.load(std::memory_order_relaxed);
    result.ordinary_demand_artifact_consumed =
        ordinary_demand_artifact_consumed_.load(std::memory_order_relaxed);
    result.demand_artifact_stage_unused =
        demand_artifact_stage_unused_.load(std::memory_order_relaxed);
    result.profile_imported_before_first_run =
        profile_imported_before_first_run_.load(std::memory_order_relaxed);
    result.merge_calls = merge_calls_.load(std::memory_order_relaxed);
    result.merge_nanoseconds =
        merge_nanoseconds_.load(std::memory_order_relaxed);
    result.save_calls = save_calls_.load(std::memory_order_relaxed);
    result.save_nanoseconds = save_nanoseconds_.load(std::memory_order_relaxed);
    result.load_nanoseconds = load_nanoseconds_.load(std::memory_order_relaxed);
    result.profile_bytes = profile_bytes_.load(std::memory_order_relaxed);
    result.profile_save_failures =
        profile_save_failures_.load(std::memory_order_relaxed);
    {
        const std::lock_guard lock { mutex_ };
        constexpr auto estimated_unordered_node_bytes =
            sizeof(std::uint64_t) + sizeof(void*);
        result.profile_object_bytes = sizeof(JitTranslationProfile);
        result.location_vector_bytes =
            locations_.capacity() * sizeof(std::uint64_t);
        result.known_set_bucket_bytes =
            known_locations_.bucket_count() * sizeof(void*);
        result.known_set_node_bytes =
            known_locations_.size() * estimated_unordered_node_bytes;
        result.discarded_set_bucket_bytes =
            discarded_locations_.bucket_count() * sizeof(void*);
        result.discarded_set_node_bytes =
            discarded_locations_.size() * estimated_unordered_node_bytes;
        result.portable_ready_set_bucket_bytes =
            profile_portable_artifact_locations_.bucket_count() * sizeof(void*);
        result.portable_ready_set_node_bytes =
            profile_portable_artifact_locations_.size() *
            estimated_unordered_node_bytes;
        result.resident_bytes =
            result.profile_object_bytes + result.location_vector_bytes +
            result.known_set_bucket_bytes + result.known_set_node_bytes +
            result.discarded_set_bucket_bytes +
            result.discarded_set_node_bytes +
            result.portable_ready_set_bucket_bytes +
            result.portable_ready_set_node_bytes;
    }
    return result;
}

void JitTranslationProfile::note_profile_loaded(
    std::uint64_t descriptors) noexcept
{
    profile_loaded_.fetch_add(descriptors, std::memory_order_relaxed);
    if (descriptors != 0) {
        profile_files_loaded_.fetch_add(1, std::memory_order_relaxed);
    }
}
void JitTranslationProfile::note_profile_enqueued_portable(
    std::uint64_t count) noexcept
{
    profile_enqueued_portable_.fetch_add(count, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_native_enqueued(
    std::uint64_t count) noexcept
{
    profile_native_enqueued_.fetch_add(count, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_native_attempted() noexcept
{
    profile_native_attempted_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_native_executed() noexcept
{
    profile_native_executed_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_portable_attempted() noexcept
{
    profile_portable_attempted_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_portable_executed() noexcept
{
    profile_portable_executed_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_portable_existence_hit() noexcept
{
    portable_existence_hits_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_portable_generated() noexcept
{
    profile_portable_generated_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_portable_artifact_ready(
    std::uint64_t location_descriptor) noexcept
{
    const std::lock_guard lock { mutex_ };
    if (profile_portable_artifact_locations_.contains(location_descriptor) ||
        profile_portable_artifact_locations_.size() >=
            jit_translation_profile_maximum_locations) {
        return;
    }
    try {
        profile_portable_artifact_locations_.insert(location_descriptor);
    } catch (...) {
        // Attribution is advisory and must never break translation.
    }
}
void JitTranslationProfile::note_native_preimport_attempted() noexcept
{
    native_preimport_attempted_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_native_preimport_before_first_demand() noexcept
{
    native_preimport_before_first_demand_.fetch_add(
        1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_native_preimport_imported() noexcept
{
    native_preimport_imported_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_native_preimport_already_present() noexcept
{
    native_preimport_already_present_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_native_preimport_used(
    std::uint64_t first_use_distance) noexcept
{
    native_preimport_used_.fetch_add(1, std::memory_order_relaxed);
    native_preimport_first_use_distance_samples_.fetch_add(
        1, std::memory_order_relaxed);
    native_preimport_first_use_distance_total_.fetch_add(
        first_use_distance, std::memory_order_relaxed);
}
void JitTranslationProfile::note_demand_artifact_staged() noexcept
{
    demand_artifact_staged_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_demand_artifact_consumed() noexcept
{
    demand_artifact_consumed_.fetch_add(1, std::memory_order_relaxed);
}
bool JitTranslationProfile::consume_profile_portable_artifact(
    std::uint64_t location_descriptor) noexcept
{
    const std::lock_guard lock { mutex_ };
    const auto found =
        profile_portable_artifact_locations_.find(location_descriptor);
    if (found == profile_portable_artifact_locations_.end())
        return false;
    profile_portable_artifact_locations_.erase(found);
    profile_portable_artifact_consumed_.fetch_add(1, std::memory_order_relaxed);
    return true;
}
void JitTranslationProfile::note_ordinary_demand_artifact_consumed() noexcept
{
    ordinary_demand_artifact_consumed_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_demand_artifact_stage_unused() noexcept
{
    demand_artifact_stage_unused_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_imported_before_first_run() noexcept
{
    profile_imported_before_first_run_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_unstable_dropped(std::uint64_t count) noexcept
{
    unstable_dropped_.fetch_add(count, std::memory_order_relaxed);
}
void JitTranslationProfile::note_save(
    std::uint64_t nanoseconds, std::uint64_t bytes) noexcept
{
    save_calls_.fetch_add(1, std::memory_order_relaxed);
    save_nanoseconds_.fetch_add(nanoseconds, std::memory_order_relaxed);
    profile_bytes_.store(bytes, std::memory_order_relaxed);
}
void JitTranslationProfile::note_save_failure() noexcept
{
    profile_save_failures_.fetch_add(1, std::memory_order_relaxed);
}
void JitTranslationProfile::note_profile_bytes(std::uint64_t bytes) noexcept
{
    profile_bytes_.store(bytes, std::memory_order_relaxed);
}
void JitTranslationProfile::note_load(std::uint64_t nanoseconds) noexcept
{
    load_nanoseconds_.fetch_add(nanoseconds, std::memory_order_relaxed);
}

JitTranslationProfileStore::JitTranslationProfileStore(
    std::filesystem::path data_directory, bool save_enabled)
    : data_directory_ { std::move(data_directory) }
    , save_enabled_ { save_enabled }
{
    for (const auto& record :
        load_profile_index(profile_index_path(data_directory_))) {
        profile_access_order_[record.identity] = record.access_order;
        known_profile_bytes_[record.identity] =
            static_cast<std::size_t>(record.file_bytes);
        known_storage_bytes_ += static_cast<std::size_t>(record.file_bytes);
        next_access_order_ =
            std::max(next_access_order_, record.access_order + 1U);
    }
}

JitTranslationProfileStore::~JitTranslationProfileStore()
{
    if (save_enabled_)
        save();
}

std::shared_ptr<JitTranslationProfile> JitTranslationProfileStore::profile_for(
    const ContentIdentity& executable_identity, bool load_from_disk)
{
    if (const auto entry = profiles_.find(executable_identity);
        entry != profiles_.end()) {
        profile_access_order_[executable_identity] = next_access_order_++;
        return entry->second;
    }

    // A process can encounter more images than the persistent profile budget.
    // Keep execution working with an ephemeral profile instead of allowing the
    // profile map or its save set to grow without bound.
    if (profiles_.size() >= jit_translation_profile_maximum_profiles) {
        return std::make_shared<JitTranslationProfile>();
    }

    std::uint64_t loaded_bytes { };
    if (load_from_disk && !executable_identity.empty()) {
        const auto path = data_directory_ /
                          (profile_file_stem(executable_identity) + ".profile");
        const auto started = std::chrono::steady_clock::now();
        const auto loaded = load_profile(path, executable_identity);
        const auto elapsed =
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now() - started);
        auto profile =
            std::make_shared<JitTranslationProfile>(loaded.locations);
        profile->note_load(static_cast<std::uint64_t>(
            std::max<std::int64_t>(0, elapsed.count())));
        if (loaded.accepted) {
            loaded_bytes = loaded.file_bytes;
            profile->note_profile_loaded(loaded.locations.size());
            profile->note_profile_bytes(loaded.file_bytes);
            ++profile_loads_;
        }
        profiles_.emplace(executable_identity, std::move(profile));
        profile_access_order_[executable_identity] = next_access_order_++;
        if (loaded_bytes != 0) {
            const auto previous =
                known_profile_bytes_.find(executable_identity);
            if (previous != known_profile_bytes_.end()) {
                known_storage_bytes_ =
                    previous->second > known_storage_bytes_
                        ? 0U
                        : known_storage_bytes_ - previous->second;
            }
            known_profile_bytes_[executable_identity] =
                static_cast<std::size_t>(loaded_bytes);
            known_storage_bytes_ += static_cast<std::size_t>(loaded_bytes);
        }
        return profiles_.at(executable_identity);
    }
    auto profile = std::make_shared<JitTranslationProfile>();
    profiles_.emplace(executable_identity, profile);
    profile_access_order_[executable_identity] = next_access_order_++;
    return profile;
}

void JitTranslationProfileStore::save() noexcept
{
    if (!save_enabled_)
        return;
    try {
        for (const auto& [executable_identity, profile] : profiles_) {
            if (!profile || executable_identity.empty())
                continue;
            const auto locations = profile->snapshot();
            if (locations.empty())
                continue;
            const auto started = std::chrono::steady_clock::now();
            const bool saved =
                save_profile(data_directory_, executable_identity, locations);
            const auto elapsed =
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - started);
            std::error_code error;
            const auto file_bytes =
                saved ? std::filesystem::file_size(
                            data_directory_ /
                                (profile_file_stem(executable_identity) +
                                    ".profile"),
                            error)
                      : 0U;
            profile->note_save(static_cast<std::uint64_t>(
                                   std::max<std::int64_t>(0, elapsed.count())),
                error ? 0U : file_bytes);
            if (!saved || error) {
                profile->note_save_failure();
                ++profile_save_failures_;
                continue;
            }
            const auto previous =
                known_profile_bytes_.find(executable_identity);
            if (previous != known_profile_bytes_.end()) {
                known_storage_bytes_ =
                    previous->second > known_storage_bytes_
                        ? 0U
                        : known_storage_bytes_ - previous->second;
            }
            known_profile_bytes_[executable_identity] =
                static_cast<std::size_t>(file_bytes);
            known_storage_bytes_ += static_cast<std::size_t>(file_bytes);
        }

        while (known_storage_bytes_ >
                   jit_translation_profile_maximum_storage_bytes &&
               !known_profile_bytes_.empty()) {
            auto oldest = known_profile_bytes_.begin();
            for (auto candidate = std::next(known_profile_bytes_.begin());
                candidate != known_profile_bytes_.end(); ++candidate) {
                if (profile_access_order_[candidate->first] <
                    profile_access_order_[oldest->first]) {
                    oldest = candidate;
                }
            }
            const auto identity = oldest->first;
            const auto path =
                data_directory_ / (profile_file_stem(identity) + ".profile");
            std::error_code error;
            std::filesystem::remove(path, error);
            known_storage_bytes_ = oldest->second > known_storage_bytes_
                                       ? 0U
                                       : known_storage_bytes_ - oldest->second;
            known_profile_bytes_.erase(oldest);
            profile_access_order_.erase(identity);
            profiles_.erase(identity);
        }
        static_cast<void>(save_profile_index(
            data_directory_, profile_access_order_, known_profile_bytes_));
    } catch (...) {
        // A cache write must not change simulator shutdown semantics.
    }
}

JitTranslationProfileStats JitTranslationProfileStore::stats() const noexcept
{
    JitTranslationProfileStats result;
    result.profile_bytes = known_storage_bytes_;
    for (const auto& [identity, profile] : profiles_) {
        static_cast<void>(identity);
        if (!profile)
            continue;
        const auto current = profile->stats();
        result.recorded += current.recorded;
        result.newly_recorded_descriptors += current.newly_recorded_descriptors;
        result.deduplicated += current.deduplicated;
        result.recorder_deduplicated += current.recorder_deduplicated;
        result.recorder_dropped_capacity += current.recorder_dropped_capacity;
        result.dropped_capacity += current.dropped_capacity;
        result.working_set_evicted += current.working_set_evicted;
        result.unstable_dropped += current.unstable_dropped;
        result.profile_loaded += current.profile_loaded;
        result.profile_files_loaded += current.profile_files_loaded;
        result.profile_enqueued_portable += current.profile_enqueued_portable;
        result.profile_native_enqueued += current.profile_native_enqueued;
        result.profile_native_attempted += current.profile_native_attempted;
        result.profile_native_executed += current.profile_native_executed;
        result.profile_portable_attempted += current.profile_portable_attempted;
        result.profile_portable_executed += current.profile_portable_executed;
        result.profile_portable_generated += current.profile_portable_generated;
        result.portable_existence_hits += current.portable_existence_hits;
        result.native_preimport_attempted += current.native_preimport_attempted;
        result.native_preimport_imported += current.native_preimport_imported;
        result.native_preimport_already_present +=
            current.native_preimport_already_present;
        result.native_preimport_before_first_demand +=
            current.native_preimport_before_first_demand;
        result.native_preimport_used += current.native_preimport_used;
        result.native_preimport_first_use_distance_samples +=
            current.native_preimport_first_use_distance_samples;
        result.native_preimport_first_use_distance_total +=
            current.native_preimport_first_use_distance_total;
        result.demand_artifact_staged += current.demand_artifact_staged;
        result.demand_artifact_consumed += current.demand_artifact_consumed;
        result.profile_portable_artifact_consumed +=
            current.profile_portable_artifact_consumed;
        result.ordinary_demand_artifact_consumed +=
            current.ordinary_demand_artifact_consumed;
        result.demand_artifact_stage_unused +=
            current.demand_artifact_stage_unused;
        result.profile_imported_before_first_run +=
            current.profile_imported_before_first_run;
        result.merge_calls += current.merge_calls;
        result.merge_nanoseconds += current.merge_nanoseconds;
        result.save_calls += current.save_calls;
        result.save_nanoseconds += current.save_nanoseconds;
        result.load_nanoseconds += current.load_nanoseconds;
        result.profile_save_failures += current.profile_save_failures;
        result.profile_object_bytes += current.profile_object_bytes;
        result.location_vector_bytes += current.location_vector_bytes;
        result.known_set_bucket_bytes += current.known_set_bucket_bytes;
        result.known_set_node_bytes += current.known_set_node_bytes;
        result.discarded_set_bucket_bytes += current.discarded_set_bucket_bytes;
        result.discarded_set_node_bytes += current.discarded_set_node_bytes;
        result.portable_ready_set_bucket_bytes +=
            current.portable_ready_set_bucket_bytes;
        result.portable_ready_set_node_bytes +=
            current.portable_ready_set_node_bytes;
        result.resident_bytes += current.resident_bytes;
    }
    result.recorded_descriptors = result.recorded;
    result.disk_descriptors_loaded = result.profile_loaded;
    result.disk_files_loaded = result.profile_files_loaded;
    return result;
}

} // namespace shade
