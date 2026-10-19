// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest LayerKit scene and layer operations to emulator
// composition.

#pragma once

#include <memory>

#include "graphics/layerkit_compatibility.hpp"

namespace shade {

struct KernelSharedState;
class Output;
class SceneCoordinator;
class UserlandHleRegistry;

// Owns the firmware-facing LayerKit hooks and their cross-command scene
// compatibility state. CompatibilityKernel only controls lifecycle; command
// decoding, window placement, and detached-root repair remain in this module.
class LayerKitHle {
public:
    void register_handlers(UserlandHleRegistry& registry,
        std::shared_ptr<KernelSharedState> shared_state,
        std::shared_ptr<SceneCoordinator> scenes, Output& output);
    void set_shared_state(std::shared_ptr<KernelSharedState> shared_state);
    void set_scene_coordinator(std::shared_ptr<SceneCoordinator> scenes);
    void reset();
    void inherit_state(const LayerKitHle& parent);

private:
    LayerKitRootCompatibility compatibility_;
    std::shared_ptr<KernelSharedState> shared_state_;
    std::shared_ptr<SceneCoordinator> scene_coordinator_;
};

} // namespace shade
