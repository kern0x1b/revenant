// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Translate runtime observations into optional JIT preparation
// policy.

#pragma once

#include "foundation/cpu.hpp"
#include "runtime/boot_options.hpp"

namespace shade::runtime_detail {

[[nodiscard]] inline std::string_view jit_precompile_source_name(
    JitPrecompileSource source) noexcept
{
    switch (source) {
    case JitPrecompileSource::DemandProfile:
        return "DemandProfile";
    case JitPrecompileSource::ExecutableCatalog:
        return "ExecutableCatalog";
    case JitPrecompileSource::Other:
        return "Other";
    }
    return "Unknown";
}

[[nodiscard]] inline std::string_view jit_catalog_warming_mode_name(
    JitCatalogWarmingMode mode) noexcept
{
    switch (mode) {
    case JitCatalogWarmingMode::NoEnqueue:
        return "no-enqueue";
    }
    return "no-enqueue";
}

[[nodiscard]] inline std::string_view jit_profile_mode_name(
    JitProfileMode mode) noexcept
{
    switch (mode) {
    case JitProfileMode::Adaptive:
        return "adaptive";
    case JitProfileMode::Off:
        return "off";
    case JitProfileMode::RecordOnly:
        return "record-only";
    case JitProfileMode::LoadOnly:
        return "load-only";
    case JitProfileMode::Idle:
        return "idle";
    case JitProfileMode::Startup:
        return "startup";
    }
    return "off";
}

[[nodiscard]] inline bool jit_profile_records(JitProfileMode mode) noexcept
{
    return mode == JitProfileMode::Adaptive ||
           mode == JitProfileMode::RecordOnly || mode == JitProfileMode::Idle ||
           mode == JitProfileMode::Startup;
}

[[nodiscard]] inline bool jit_profile_loads(JitProfileMode mode) noexcept
{
    return mode == JitProfileMode::Adaptive ||
           mode == JitProfileMode::LoadOnly || mode == JitProfileMode::Idle ||
           mode == JitProfileMode::Startup;
}

[[nodiscard]] inline bool jit_profile_saves(JitProfileMode mode) noexcept
{
    return mode == JitProfileMode::Adaptive ||
           mode == JitProfileMode::RecordOnly || mode == JitProfileMode::Idle ||
           mode == JitProfileMode::Startup;
}

[[nodiscard]] inline bool jit_profile_precompiles(JitProfileMode mode) noexcept
{
    return mode == JitProfileMode::Idle || mode == JitProfileMode::Startup;
}

[[nodiscard]] inline bool jit_profile_idle_work(JitProfileMode mode) noexcept
{
    return mode == JitProfileMode::Idle;
}

[[nodiscard]] inline bool jit_profile_startup_work(JitProfileMode mode) noexcept
{
    return mode == JitProfileMode::Startup;
}

} // namespace shade::runtime_detail
