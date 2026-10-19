// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Prepare bounded executable catalogs and reusable translation
// artifacts for firmware startup.

#include "foundation/firmware_prepare.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <fstream>
#include <functional>
#include <iterator>
#include <limits>
#include <queue>
#include <set>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <unordered_set>
#include <utility>
#include <vector>

#include <umbra/interface/exclusive_monitor.h>

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/jit_translation_profile.hpp"

namespace shade {
namespace {

    constexpr std::array<char, 8> prepare_state_magic { 'i', 'L', 'E', 'M', 'P',
        'R', 'P', '1' };
    constexpr std::uint32_t prepare_state_schema = 1U;
    constexpr std::uint32_t maximum_state_records = 100'000U;
    constexpr std::size_t bytes_per_mebibyte = 1024U * 1024U;
    constexpr std::size_t minimum_jit_slab_bytes = 8U * bytes_per_mebibyte;
    constexpr std::size_t maximum_prepare_jit_slab_bytes =
        64U * bytes_per_mebibyte;

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

    void append_generation(std::vector<std::byte>& bytes,
        const ExecutableCatalogFileGeneration& generation)
    {
        append_u64(bytes, generation.device);
        append_u64(bytes, generation.inode);
        append_u64(bytes, generation.file_size);
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.modified_seconds));
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.modified_nanoseconds));
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.changed_seconds));
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.changed_nanoseconds));
    }

    class ByteReader {
    public:
        explicit ByteReader(std::span<const std::byte> bytes)
            : bytes_ { bytes }
        {
        }

        [[nodiscard]] bool read_u8(std::uint8_t& value)
        {
            if (offset_ >= bytes_.size())
                return false;
            value = std::to_integer<std::uint8_t>(bytes_[offset_++]);
            return true;
        }

        [[nodiscard]] bool read_u32(std::uint32_t& value)
        {
            value = 0;
            for (unsigned shift = 0; shift < 32U; shift += 8U) {
                std::uint8_t byte { };
                if (!read_u8(byte))
                    return false;
                value |= static_cast<std::uint32_t>(byte) << shift;
            }
            return true;
        }

        [[nodiscard]] bool read_u64(std::uint64_t& value)
        {
            value = 0;
            for (unsigned shift = 0; shift < 64U; shift += 8U) {
                std::uint8_t byte { };
                if (!read_u8(byte))
                    return false;
                value |= static_cast<std::uint64_t>(byte) << shift;
            }
            return true;
        }

        [[nodiscard]] bool read_identity(ContentIdentity& identity)
        {
            if (bytes_.size() - offset_ < identity.digest.size())
                return false;
            std::copy_n(bytes_.begin() + static_cast<std::ptrdiff_t>(offset_),
                identity.digest.size(), identity.digest.begin());
            offset_ += identity.digest.size();
            return true;
        }

        [[nodiscard]] bool at_end() const noexcept
        {
            return offset_ == bytes_.size();
        }

    private:
        std::span<const std::byte> bytes_;
        std::size_t offset_ { };
    };

    void append_state_record(std::vector<std::byte>& bytes,
        const ContentIdentity& identity,
        const ExecutableCatalogFileGeneration& generation)
    {
        bytes.insert(
            bytes.end(), identity.digest.begin(), identity.digest.end());
        append_generation(bytes, generation);
    }

    bool is_path_inside(
        const std::filesystem::path& root, const std::filesystem::path& path)
    {
        std::error_code error;
        const auto root_absolute =
            std::filesystem::weakly_canonical(root, error);
        if (error)
            return false;
        error.clear();
        const auto path_absolute =
            std::filesystem::weakly_canonical(path, error);
        if (error)
            return false;
        const auto relative = path_absolute.lexically_relative(root_absolute);
        return !relative.empty() && relative != "." &&
               relative.begin() != relative.end() && *relative.begin() != "..";
    }

    bool path_has_component(
        const std::filesystem::path& path, std::string_view suffix)
    {
        for (const auto& component : path) {
            if (component.string() == suffix)
                return true;
        }
        return false;
    }

    bool is_springboard_path(const std::filesystem::path& path)
    {
        return path_has_component(path, "SpringBoard.app") ||
               path.filename() == "SpringBoard";
    }

    bool is_loader_path(const std::filesystem::path& path)
    {
        const auto filename = path.filename().string();
        return filename == "launchd" || filename == "dyld" ||
               filename == "dyld_sim";
    }

    bool is_foreground_path(const std::filesystem::path& path)
    {
        if (path_has_component(path, "Applications"))
            return true;
        for (const auto& component : path) {
            if (component.string().ends_with(".app"))
                return true;
        }
        return false;
    }

    bool dependency_matches(
        const std::filesystem::path& candidate, std::string_view dependency)
    {
        const std::filesystem::path dependency_path { dependency };
        if (dependency_path.filename() == candidate.filename())
            return true;
        return candidate.lexically_normal().string().ends_with(
            dependency_path.lexically_normal().string());
    }

    struct Candidate {
        const ExecutableCatalogEntry* entry { };
        std::filesystem::path path;
        ExecutableCatalogFileGeneration generation;
        std::shared_ptr<JitTranslationProfile> profile;
        std::vector<std::uint64_t> catalog_entry_points;
        std::vector<std::uint64_t> profile_entry_points;
        std::vector<std::uint64_t> reliable_entry_points;
        bool critical_closure { };
        bool historical_profile { };
        bool boot_working_set { };
        unsigned priority { };
        JitPrecompilePhase phase { JitPrecompilePhase::Opportunistic };
    };

    void collect_artifact_result(
        const JitPrecompileBatchResult& batch, FirmwarePrepareStats& stats)
    {
        stats.blocks_attempted += static_cast<std::size_t>(batch.attempted);
        stats.portable_generated +=
            static_cast<std::size_t>(batch.portable_generated);
        stats.portable_artifact_hits +=
            static_cast<std::size_t>(batch.portable_artifact_hits);
        stats.deferred += static_cast<std::size_t>(batch.deferred);
        stats.unstable += static_cast<std::size_t>(batch.unstable);
        stats.failed += static_cast<std::size_t>(batch.failed);
        stats.deadline_stops += static_cast<std::size_t>(batch.deadline_stops);
    }

} // namespace

FirmwarePreparer::FirmwarePreparer(std::filesystem::path rootfs,
    std::filesystem::path catalog_manifest, std::filesystem::path host_cache,
    ArmArchitectureVersion architecture, const ArmCpuModel& cpu_model,
    FirmwarePrepareLimits limits)
    : rootfs_ { std::move(rootfs) }
    , catalog_manifest_ { std::move(catalog_manifest) }
    , host_cache_ { std::move(host_cache) }
    , architecture_ { architecture }
    , cpu_model_ { cpu_model }
    , limits_ { limits }
{
}

bool FirmwarePreparer::load_state()
{
    completed_state_.clear();
    const auto path = host_cache_ / "firmware-prepare-state.bin";
    std::error_code error;
    const auto size = std::filesystem::file_size(path, error);
    if (error || size < prepare_state_magic.size() +
                            sizeof(ContentIdentity { }.digest) +
                            sizeof(ContentIdentity { }.digest)) {
        return false;
    }
    std::ifstream input { path, std::ios::binary };
    if (!input || size > 64U * 1024U * 1024U)
        return false;
    std::vector<std::byte> bytes(static_cast<std::size_t>(size));
    input.read(reinterpret_cast<char*>(bytes.data()),
        static_cast<std::streamsize>(bytes.size()));
    if (input.gcount() != static_cast<std::streamsize>(bytes.size()) ||
        bytes.size() <
            prepare_state_magic.size() + ContentIdentity { }.digest.size()) {
        return false;
    }
    const auto payload_size = bytes.size() - ContentIdentity { }.digest.size();
    ContentIdentity checksum;
    std::copy_n(bytes.begin() + static_cast<std::ptrdiff_t>(payload_size),
        checksum.digest.size(), checksum.digest.begin());
    if (sha256(std::span<const std::byte> { bytes.data(), payload_size }) !=
        checksum) {
        return false;
    }
    const std::span<const std::byte> payload { bytes.data(), payload_size };
    if (payload.size() < prepare_state_magic.size() ||
        !std::equal(prepare_state_magic.begin(), prepare_state_magic.end(),
            reinterpret_cast<const char*>(payload.data()))) {
        return false;
    }
    ByteReader reader { payload.subspan(prepare_state_magic.size()) };
    std::uint32_t schema { };
    std::uint32_t count { };
    if (!reader.read_u32(schema) || schema != prepare_state_schema ||
        !reader.read_u32(count) || count > maximum_state_records) {
        return false;
    }
    for (std::uint32_t index = 0; index < count; ++index) {
        ContentIdentity identity;
        std::uint64_t device { };
        std::uint64_t inode { };
        std::uint64_t file_size { };
        std::uint64_t modified_seconds { };
        std::uint64_t modified_nanoseconds { };
        std::uint64_t changed_seconds { };
        std::uint64_t changed_nanoseconds { };
        std::uint8_t completed { };
        if (!reader.read_identity(identity) || !reader.read_u64(device) ||
            !reader.read_u64(inode) || !reader.read_u64(file_size) ||
            !reader.read_u64(modified_seconds) ||
            !reader.read_u64(modified_nanoseconds) ||
            !reader.read_u64(changed_seconds) ||
            !reader.read_u64(changed_nanoseconds) ||
            !reader.read_u8(completed) || completed > 1U) {
            completed_state_.clear();
            return false;
        }
        if (completed != 0U) {
            completed_state_.emplace(identity,
                ExecutableCatalogFileGeneration { device, inode, file_size,
                    static_cast<std::int64_t>(modified_seconds),
                    static_cast<std::int64_t>(modified_nanoseconds),
                    static_cast<std::int64_t>(changed_seconds),
                    static_cast<std::int64_t>(changed_nanoseconds) });
        }
    }
    return reader.at_end();
}

bool FirmwarePreparer::save_state()
{
    try {
        std::vector<std::byte> payload;
        payload.reserve(prepare_state_magic.size() + 8U +
                        completed_state_.size() * (32U + 7U * 8U + 1U));
        payload.insert(payload.end(),
            reinterpret_cast<const std::byte*>(prepare_state_magic.data()),
            reinterpret_cast<const std::byte*>(
                prepare_state_magic.data() + prepare_state_magic.size()));
        append_u32(payload, prepare_state_schema);
        append_u32(
            payload, static_cast<std::uint32_t>(completed_state_.size()));
        for (const auto& [identity, generation] : completed_state_) {
            append_state_record(payload, identity, generation);
            payload.push_back(std::byte { 1 });
        }
        const auto checksum = sha256(payload);
        payload.insert(
            payload.end(), checksum.digest.begin(), checksum.digest.end());
        std::filesystem::create_directories(host_cache_);
        const auto temporary = host_cache_ / "firmware-prepare-state.bin.tmp";
        const auto target = host_cache_ / "firmware-prepare-state.bin";
        {
            std::ofstream output { temporary,
                std::ios::binary | std::ios::trunc };
            if (!output)
                return false;
            output.write(reinterpret_cast<const char*>(payload.data()),
                static_cast<std::streamsize>(payload.size()));
            output.flush();
            if (!output)
                return false;
        }
        std::error_code error;
        std::filesystem::rename(temporary, target, error);
        if (error) {
            std::error_code cleanup;
            std::filesystem::remove(temporary, cleanup);
            return false;
        }
        return true;
    } catch (...) {
        return false;
    }
}

FirmwarePrepareStats FirmwarePreparer::run()
{
    FirmwarePrepareStats stats;
    std::filesystem::create_directories(host_cache_);

    ExecutableCatalog catalog;
    const bool had_catalog = catalog.load(catalog_manifest_);
    stats.catalog_scan = had_catalog
                             ? catalog.refresh_tree(rootfs_, architecture_)
                             : catalog.register_tree(rootfs_, architecture_);
    if (!catalog.save(catalog_manifest_)) {
        throw std::runtime_error {
            "failed to atomically publish firmware catalog: " +
            catalog_manifest_.string()
        };
    }
    stats.catalog_entries = catalog.size();
    stats.reliable_entry_points = catalog.reliable_entry_point_count();
    static_cast<void>(load_state());

    JitArtifactLimits artifact_limits;
    artifact_limits.resident_bytes = limits_.artifact_resident_bytes;
    artifact_limits.persistence_bytes = limits_.artifact_persistence_bytes;
    artifact_limits.persistence_enabled = limits_.artifact_persistence_enabled;
    artifact_limits.minimum_free_bytes = limits_.artifact_minimum_free_bytes;
    artifact_limits.writeback_bytes = 0U;
    artifact_limits.compaction_bytes = 0U;
    if (limits_.artifact_seed_mode == FirmwareArtifactSeedMode::CatalogOnly) {
        // Catalog-only comparison runs must not load, rewrite, or otherwise
        // perturb an existing artifact seed.
        artifact_limits.persistence_enabled = false;
        artifact_limits.persistence_bytes = 0U;
    }
    auto artifacts = std::make_shared<JitArtifactStore>(
        host_cache_ / "jit-artifacts.bin", artifact_limits);
    JitTranslationProfileStore profiles { host_cache_ /
                                          "jit-translation-profiles" };

    std::vector<Candidate> candidates;
    for (const auto& entry : catalog.entries()) {
        if (entry.kinds.contains(ExecutableCatalogKind::DynamicMapping)) {
            ++stats.skipped_dynamic_mappings;
            continue;
        }
        std::optional<Candidate> candidate;
        for (const auto& generation : entry.file_generations) {
            std::error_code error;
            if (!std::filesystem::is_regular_file(generation.path, error) ||
                error || !is_path_inside(rootfs_, generation.path)) {
                continue;
            }
            candidate = Candidate { &entry, generation.path,
                generation.generation,
                profiles.profile_for(entry.content_identity),
                entry.reliable_entry_points, { }, { }, false, false, false };
            break;
        }
        if (!candidate) {
            ++stats.skipped_without_generation;
            continue;
        }
        const auto profile_locations = candidate->profile->snapshot();
        candidate->profile_entry_points = profile_locations;
        candidate->historical_profile = !profile_locations.empty();
        const auto loader = is_loader_path(candidate->path);
        const auto springboard = is_springboard_path(candidate->path);
        const auto foreground = is_foreground_path(candidate->path);
        candidate->priority = loader || springboard           ? 0U
                              : candidate->historical_profile ? 1U
                              : foreground                    ? 2U
                                                              : 3U;
        candidate->phase =
            loader                          ? JitPrecompilePhase::Bootstrap
            : springboard                   ? JitPrecompilePhase::Scanout
            : candidate->historical_profile ? JitPrecompilePhase::PriorStartup
            : foreground ? JitPrecompilePhase::InteractiveActivation
                         : JitPrecompilePhase::Opportunistic;
        const bool has_seed_candidate =
            limits_.artifact_seed_mode ==
                FirmwareArtifactSeedMode::CatalogOnly ||
            (limits_.artifact_seed_mode ==
                        FirmwareArtifactSeedMode::StaticCatalog
                    ? !candidate->catalog_entry_points.empty()
                    : !candidate->profile_entry_points.empty());
        if (!has_seed_candidate) {
            continue;
        }
        candidates.push_back(std::move(*candidate));
    }
    // Expand the startup closure using catalog dependency names. Matching is
    // deliberately path-only and only affects preparation order; every image is
    // still validated from its current file generation before translation.
    std::queue<std::size_t> closure_queue;
    for (std::size_t index = 0; index < candidates.size(); ++index) {
        if (candidates[index].priority == 0U) {
            candidates[index].critical_closure = true;
            closure_queue.push(index);
        }
    }
    std::unordered_set<std::size_t> queued;
    while (!closure_queue.empty()) {
        const auto index = closure_queue.front();
        closure_queue.pop();
        for (const auto& dependency : candidates[index].entry->dependencies) {
            for (std::size_t candidate_index = 0;
                candidate_index < candidates.size(); ++candidate_index) {
                if (candidates[candidate_index].critical_closure ||
                    !dependency_matches(
                        candidates[candidate_index].path, dependency)) {
                    continue;
                }
                candidates[candidate_index].critical_closure = true;
                candidates[candidate_index].priority = 0U;
                candidates[candidate_index].phase =
                    JitPrecompilePhase::PriorStartup;
                if (queued.insert(candidate_index).second) {
                    closure_queue.push(candidate_index);
                }
            }
        }
    }
    std::sort(candidates.begin(), candidates.end(),
        [](const Candidate& left, const Candidate& right) {
            if (left.priority != right.priority)
                return left.priority < right.priority;
            if (left.historical_profile != right.historical_profile)
                return left.historical_profile > right.historical_profile;
            return left.path < right.path;
        });
    stats.candidates = candidates.size();

    // Value selection is intentionally deterministic and identity-safe. The
    // catalog remains the source of boot-critical points; a bounded historical
    // profile can replace catalog points for non-critical service/application
    // images, where it represents the observed first-frame/main-page path.
    std::size_t profile_blocks_remaining = limits_.max_profile_hotset_blocks;
    for (auto& candidate : candidates) {
        switch (limits_.artifact_seed_mode) {
        case FirmwareArtifactSeedMode::CatalogOnly:
            ++stats.catalog_only_candidates;
            break;
        case FirmwareArtifactSeedMode::StaticCatalog:
            candidate.reliable_entry_points = candidate.catalog_entry_points;
            stats.static_seed_selected +=
                candidate.reliable_entry_points.size();
            break;
        case FirmwareArtifactSeedMode::ProfileHotset: {
            const bool use_profile = !candidate.profile_entry_points.empty() &&
                                     profile_blocks_remaining != 0U;
            if (use_profile) {
                const auto selected = std::min(profile_blocks_remaining,
                    candidate.profile_entry_points.size());
                candidate.reliable_entry_points.assign(
                    candidate.profile_entry_points.begin(),
                    candidate.profile_entry_points.begin() +
                        static_cast<std::ptrdiff_t>(selected));
                profile_blocks_remaining -= selected;
                stats.profile_hotset_selected += selected;
            } else {
                // ProfileHotset is deliberately profile-only. A catalog
                // fallback would silently turn a bounded experiment into a
                // broad static seed and recreate the critical-closure startup
                // cost this mode is intended to measure.
                candidate.reliable_entry_points.clear();
            }
            candidate.boot_working_set = use_profile;
            break;
        }
        }
    }

    if (limits_.artifact_seed_mode == FirmwareArtifactSeedMode::CatalogOnly) {
        stats.artifact_stats = artifacts->stats();
        return stats;
    }

    const auto started = std::chrono::steady_clock::now();
    const auto firmware_deadline =
        limits_.max_firmware_time.count() > 0
            ? started + limits_.max_firmware_time
            : std::chrono::steady_clock::time_point::max();
    std::size_t firmware_blocks { };
    std::size_t firmware_memory { };
    std::size_t file_sequence { };
    for (const auto& candidate : candidates) {
        if (std::chrono::steady_clock::now() >= firmware_deadline ||
            firmware_blocks >= limits_.max_firmware_blocks ||
            firmware_memory >= limits_.max_firmware_memory_bytes) {
            stats.interrupted = true;
            break;
        }
        if (!limits_.force) {
            const auto completed =
                completed_state_.find(candidate.entry->content_identity);
            if (completed != completed_state_.end() &&
                completed->second == candidate.generation) {
                ++stats.resumed;
                continue;
            }
        }
        if (candidate.entry->file_size > limits_.max_file_memory_bytes ||
            candidate.entry->file_size > limits_.max_image_memory_bytes ||
            candidate.entry->file_size >
                limits_.max_firmware_memory_bytes -
                    std::min(
                        firmware_memory, limits_.max_firmware_memory_bytes)) {
            ++stats.skipped_limits;
            continue;
        }
        ++stats.files_processed;
        ++file_sequence;
        const auto file_started = std::chrono::steady_clock::now();
        const auto file_deadline =
            limits_.max_file_time.count() > 0
                ? std::min(
                      firmware_deadline, file_started + limits_.max_file_time)
                : firmware_deadline;
        const auto image_deadline =
            limits_.max_image_time.count() > 0
                ? std::min(file_deadline, file_started + limits_.max_image_time)
                : file_deadline;
        try {
            const auto image = MachOImage::parse(candidate.path, architecture_,
                candidate.entry->content_identity,
                ImmutableSnapshotKind::CatalogScan);
            AddressSpace memory;
            image.map_into(memory);
            const auto mapped_bytes =
                memory.mapped_page_count() * AddressSpace::page_size;
            if (mapped_bytes > limits_.max_image_memory_bytes ||
                mapped_bytes > limits_.max_file_memory_bytes) {
                ++stats.skipped_limits;
                continue;
            }
            const auto image_memory = std::max<std::size_t>(
                static_cast<std::size_t>(image.file_size()), mapped_bytes);
            if (firmware_memory >
                limits_.max_firmware_memory_bytes - image_memory) {
                ++stats.skipped_limits;
                stats.interrupted = true;
                break;
            }
            firmware_memory += image_memory;
            stats.prepared_memory_bytes =
                std::max(stats.prepared_memory_bytes, firmware_memory);

            Umbra::ExclusiveMonitor monitor { 1U };
            CpuCluster cluster { 1U, 1U, memory, 1U, cpu_model_, monitor, 0U,
                artifacts };
            const auto slab_bytes =
                std::clamp<std::size_t>(limits_.max_image_memory_bytes / 2U,
                    minimum_jit_slab_bytes, maximum_prepare_jit_slab_bytes);
            cluster.set_jit_code_cache_size(slab_bytes);
            cluster.set_process_id(static_cast<std::uint32_t>(file_sequence));
            cluster.set_jit_artifact_retention(
                candidate.boot_working_set
                    ? JitArtifactRetention::BootWorkingSet
                    : JitArtifactRetention::Normal);
            cluster.set_translation_profile(candidate.profile, candidate.phase);
            cluster.add_precompile_entries(
                candidate.reliable_entry_points, candidate.phase);

            std::size_t file_blocks { };
            bool batch_had_failures { };
            bool stopped_by_deadline { };
            while (cluster.next_precompile_phase(
                       JitPrecompileTarget::PortableIr) &&
                   file_blocks < limits_.max_file_blocks &&
                   file_blocks < limits_.max_image_blocks &&
                   firmware_blocks < limits_.max_firmware_blocks) {
                const auto now = std::chrono::steady_clock::now();
                if (now >= image_deadline || now >= file_deadline ||
                    now >= firmware_deadline) {
                    ++stats.deadline_stops;
                    stopped_by_deadline = true;
                    break;
                }
                const auto remaining_time =
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        image_deadline - now);
                const auto remaining_blocks =
                    std::min({ limits_.max_file_blocks - file_blocks,
                        limits_.max_image_blocks - file_blocks,
                        limits_.max_firmware_blocks - firmware_blocks });
                const auto batch = cluster.precompile_pending(remaining_blocks,
                    static_cast<std::uint64_t>(
                        std::max<std::int64_t>(1, remaining_time.count())),
                    JitPrecompileTarget::PortableIr,
                    [image_deadline, file_deadline, firmware_deadline] {
                        const auto current = std::chrono::steady_clock::now();
                        return current >= image_deadline ||
                               current >= file_deadline ||
                               current >= firmware_deadline;
                    });
                collect_artifact_result(batch, stats);
                batch_had_failures = batch_had_failures ||
                                     batch.deferred != 0U ||
                                     batch.unstable != 0U || batch.failed != 0U;
                file_blocks += static_cast<std::size_t>(batch.attempted);
                firmware_blocks += static_cast<std::size_t>(batch.attempted);
                if (batch.attempted == 0U)
                    break;
            }
            cluster.quiesce_precompilation();
            const auto artifact_stats_before = artifacts->stats();
            const auto artifact_save_succeeded = artifacts->save();
            if (!artifact_save_succeeded) {
                ++stats.preparation_failures;
            }
            const auto artifact_stats_after = artifacts->stats();
            const auto current_storage = artifact_stats_after.disk_bytes;
            const auto storage_delta =
                artifact_stats_after.resident_bytes >=
                        artifact_stats_before.resident_bytes
                    ? artifact_stats_after.resident_bytes -
                          artifact_stats_before.resident_bytes
                    : 0U;
            if (current_storage > limits_.max_firmware_storage_bytes ||
                storage_delta > limits_.max_file_storage_bytes ||
                storage_delta > limits_.max_image_storage_bytes) {
                stats.storage_limited = true;
                ++stats.skipped_limits;
                break;
            }
            ++stats.images_processed;
            const auto complete =
                !stopped_by_deadline && !batch_had_failures &&
                artifact_save_succeeded &&
                !cluster.next_precompile_phase(JitPrecompileTarget::PortableIr);
            if (complete) {
                completed_state_[candidate.entry->content_identity] =
                    candidate.generation;
                ++stats.completed_files;
            } else {
                ++stats.partial_files;
            }
            if (save_state())
                ++stats.state_writes;
        } catch (const std::exception&) {
            ++stats.preparation_failures;
        } catch (...) {
            ++stats.preparation_failures;
        }
    }
    stats.artifact_finalized = artifacts->finalize();
    if (!stats.artifact_finalized) {
        ++stats.preparation_failures;
    }
    stats.artifact_stats = artifacts->stats();
    return stats;
}

} // namespace shade
