// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Prepare bounded executable catalogs and reusable translation
// artifacts for firmware startup.

#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <map>
#include <string_view>

#include "foundation/arm_cpu_model.hpp"
#include "foundation/executable_catalog.hpp"
#include "foundation/jit_artifact.hpp"
#include "foundation/macho.hpp"

namespace shade {

enum class FirmwareArtifactSeedMode : std::uint8_t {
    CatalogOnly,
    StaticCatalog,
    ProfileHotset,
};

[[nodiscard]] constexpr std::string_view firmware_artifact_seed_mode_name(
    FirmwareArtifactSeedMode mode) noexcept
{
    switch (mode) {
    case FirmwareArtifactSeedMode::CatalogOnly:
        return "catalog-only";
    case FirmwareArtifactSeedMode::StaticCatalog:
        return "static-catalog";
    case FirmwareArtifactSeedMode::ProfileHotset:
        return "profile-hotset";
    }
    return "catalog-only";
}

// All limits are host-side preparation limits. They bound optional work only;
// a runtime can always fall back to demand JIT when preparation is incomplete.
struct FirmwarePrepareLimits {
    std::size_t max_file_blocks { 128U };
    std::size_t max_image_blocks { 128U };
    std::size_t max_firmware_blocks { 4096U };
    std::chrono::milliseconds max_file_time { 500 };
    std::chrono::milliseconds max_image_time { 500 };
    std::chrono::milliseconds max_firmware_time { 30'000 };
    std::size_t max_file_memory_bytes { 128U * 1024U * 1024U };
    std::size_t max_image_memory_bytes { 128U * 1024U * 1024U };
    std::size_t max_firmware_memory_bytes { 512U * 1024U * 1024U };
    std::size_t max_file_storage_bytes { 32U * 1024U * 1024U };
    std::size_t max_image_storage_bytes { 32U * 1024U * 1024U };
    std::size_t max_firmware_storage_bytes { 256U * 1024U * 1024U };
    std::size_t artifact_resident_bytes { 64U * 1024U * 1024U };
    std::size_t artifact_persistence_bytes { 256U * 1024U * 1024U };
    std::uintmax_t artifact_minimum_free_bytes { 1U * 1024U * 1024U * 1024U };
    bool artifact_persistence_enabled { true };
    FirmwareArtifactSeedMode artifact_seed_mode {
        FirmwareArtifactSeedMode::CatalogOnly
    };
    std::size_t max_profile_hotset_blocks { 256U };
    bool force { };
};

struct FirmwarePrepareStats {
    ExecutableCatalogScanSummary catalog_scan;
    std::size_t catalog_entries { };
    std::size_t reliable_entry_points { };
    std::size_t profile_hotset_selected { };
    std::size_t static_seed_selected { };
    std::size_t catalog_only_candidates { };
    std::size_t candidates { };
    std::size_t skipped_dynamic_mappings { };
    std::size_t skipped_without_generation { };
    std::size_t skipped_limits { };
    std::size_t resumed { };
    std::size_t files_processed { };
    std::size_t images_processed { };
    std::size_t completed_files { };
    std::size_t partial_files { };
    std::size_t preparation_failures { };
    std::size_t blocks_attempted { };
    std::size_t portable_generated { };
    std::size_t portable_artifact_hits { };
    std::size_t deferred { };
    std::size_t unstable { };
    std::size_t failed { };
    std::size_t deadline_stops { };
    std::size_t state_writes { };
    std::size_t prepared_memory_bytes { };
    bool artifact_finalized { };
    bool interrupted { };
    bool storage_limited { };
    JitArtifactStoreStats artifact_stats;
};

class FirmwarePreparer {
public:
    FirmwarePreparer(std::filesystem::path rootfs,
        std::filesystem::path catalog_manifest,
        std::filesystem::path host_cache, ArmArchitectureVersion architecture,
        const ArmCpuModel& cpu_model, FirmwarePrepareLimits limits = { });

    [[nodiscard]] FirmwarePrepareStats run();

private:
    struct StateRecord {
        ContentIdentity content_identity;
        ExecutableCatalogFileGeneration generation;
    };

    [[nodiscard]] bool load_state();
    [[nodiscard]] bool save_state();

    std::filesystem::path rootfs_;
    std::filesystem::path catalog_manifest_;
    std::filesystem::path host_cache_;
    ArmArchitectureVersion architecture_;
    const ArmCpuModel& cpu_model_;
    FirmwarePrepareLimits limits_;
    std::map<ContentIdentity, ExecutableCatalogFileGeneration> completed_state_;
};

} // namespace shade
