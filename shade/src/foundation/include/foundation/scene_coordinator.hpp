// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Coordinate guest scene ownership, lifecycle and presentation
// activity.

#pragma once

#include <cstdint>
#include <map>
#include <mutex>
#include <optional>
#include <utility>

namespace shade {

// Host/display coordinates to an OS client's input coordinate space. The full
// affine form supports translation, scale, rotation, and later graphics stacks
// without exposing any host backend or private framework object layout.
struct SceneTransform {
    float xx { 1.0F };
    float xy { };
    float yx { };
    float yy { 1.0F };
    float tx { };
    float ty { };

    [[nodiscard]] std::pair<float, float> map(float x, float y) const;
};

enum class ClientSceneState {
    Committed,
    Active,
    Exiting,
    Suspended,
};

struct ClientScene {
    std::uint64_t sequence { };
    std::uint32_t client_process_id { };
    std::optional<SceneTransform> input_transform;
    ClientSceneState state { ClientSceneState::Committed };
};

// Common semantic scene state. Version-specific graphics adapters commit
// logical clients here; input, display policy, and lifecycle code consume the
// same process identity without depending on LayerKit, QuartzCore, or SDL.
class SceneCoordinator {
public:
    void commit_client_scene(std::uint32_t client_process_id,
        std::optional<SceneTransform> input_transform);
    [[nodiscard]] std::optional<ClientScene> client_scene(
        std::uint32_t client_process_id) const;
    [[nodiscard]] std::optional<ClientScene> active_client_scene() const;
    // The outgoing scene remains visually foreground while its exit transition
    // is being composed. Display policy consumes this broader lifetime; input
    // continues to use active_client_scene() so an exiting client cannot
    // receive new touches.
    [[nodiscard]] std::optional<ClientScene> foreground_client_scene() const;
    void activate_client_scene(std::uint32_t client_process_id);
    void begin_client_scene_exit(std::uint32_t client_process_id);
    void suspend_client_scene(std::uint32_t client_process_id);
    [[nodiscard]] bool client_scene_active(
        std::uint32_t client_process_id) const;
    [[nodiscard]] bool client_scene_presentable(
        std::uint32_t client_process_id) const;
    void retire_process(std::uint32_t process_id);

private:
    [[nodiscard]] std::uint64_t allocate_sequence_locked();

    mutable std::mutex mutex_;
    std::uint64_t next_sequence_ { 1 };
    std::map<std::uint32_t, ClientScene> client_scenes_;
};

} // namespace shade
