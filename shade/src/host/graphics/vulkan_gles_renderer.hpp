// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Render guest GLES state and shared surfaces through Vulkan.

#pragma once

#include <filesystem>
#include <memory>
#include <string>

#include "graphics/gles_renderer.hpp"

namespace shade {

// Returns null when Vulkan exposes no device matching the selection policy.
// Failure details let the policy layer reject an explicitly requested backend.
[[nodiscard]] std::unique_ptr<GlesRenderer> create_vulkan_gles_renderer(
    const std::filesystem::path& pipeline_cache,
    const VulkanPresenterConfiguration* presenter,
    GlesDeviceSelection selection,
    std::string* failure = nullptr) noexcept;

} // namespace shade
