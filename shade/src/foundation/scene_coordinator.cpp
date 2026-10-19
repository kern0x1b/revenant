// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Coordinate guest scene ownership, lifecycle and presentation
// activity.

#include "foundation/scene_coordinator.hpp"

#include <algorithm>
#include <cmath>
#include <utility>

namespace shade {

std::pair<float, float> SceneTransform::map(float x, float y) const
{
    return { xx * x + xy * y + tx, yx * x + yy * y + ty };
}

std::uint64_t SceneCoordinator::allocate_sequence_locked()
{
    const auto sequence = next_sequence_++;
    if (next_sequence_ == 0U)
        next_sequence_ = 1U;
    return sequence;
}

void SceneCoordinator::commit_client_scene(std::uint32_t client_process_id,
    std::optional<SceneTransform> input_transform)
{
    if (client_process_id == 0U)
        return;
    if (input_transform && (!std::isfinite(input_transform->xx) ||
                               !std::isfinite(input_transform->xy) ||
                               !std::isfinite(input_transform->yx) ||
                               !std::isfinite(input_transform->yy) ||
                               !std::isfinite(input_transform->tx) ||
                               !std::isfinite(input_transform->ty))) {
        return;
    }
    std::lock_guard lock { mutex_ };
    auto state = ClientSceneState::Committed;
    if (const auto existing = client_scenes_.find(client_process_id);
        existing != client_scenes_.end()) {
        state = existing->second.state;
    }
    client_scenes_.insert_or_assign(client_process_id,
        ClientScene { allocate_sequence_locked(), client_process_id,
            std::move(input_transform), state });
}

void SceneCoordinator::activate_client_scene(std::uint32_t client_process_id)
{
    std::lock_guard lock { mutex_ };
    const auto found = client_scenes_.find(client_process_id);
    if (found == client_scenes_.end())
        return;
    for (auto& [process_id, scene] : client_scenes_) {
        if (process_id != client_process_id &&
            (scene.state == ClientSceneState::Active ||
                scene.state == ClientSceneState::Exiting)) {
            scene.state = ClientSceneState::Suspended;
        }
    }
    found->second.state = ClientSceneState::Active;
}

void SceneCoordinator::suspend_client_scene(std::uint32_t client_process_id)
{
    std::lock_guard lock { mutex_ };
    const auto found = client_scenes_.find(client_process_id);
    if (found != client_scenes_.end())
        found->second.state = ClientSceneState::Suspended;
}

void SceneCoordinator::begin_client_scene_exit(std::uint32_t client_process_id)
{
    std::lock_guard lock { mutex_ };
    const auto found = client_scenes_.find(client_process_id);
    if (found != client_scenes_.end()) {
        found->second.state = ClientSceneState::Exiting;
    }
}

bool SceneCoordinator::client_scene_active(
    std::uint32_t client_process_id) const
{
    std::lock_guard lock { mutex_ };
    const auto found = client_scenes_.find(client_process_id);
    return found != client_scenes_.end() &&
           found->second.state == ClientSceneState::Active;
}

bool SceneCoordinator::client_scene_presentable(
    std::uint32_t client_process_id) const
{
    std::lock_guard lock { mutex_ };
    const auto found = client_scenes_.find(client_process_id);
    return found != client_scenes_.end() &&
           (found->second.state == ClientSceneState::Active ||
               found->second.state == ClientSceneState::Exiting);
}

std::optional<ClientScene> SceneCoordinator::client_scene(
    std::uint32_t client_process_id) const
{
    std::lock_guard lock { mutex_ };
    const auto found = client_scenes_.find(client_process_id);
    return found == client_scenes_.end()
               ? std::nullopt
               : std::optional<ClientScene> { found->second };
}

std::optional<ClientScene> SceneCoordinator::active_client_scene() const
{
    std::lock_guard lock { mutex_ };
    const auto found = std::find_if(
        client_scenes_.begin(), client_scenes_.end(), [](const auto& entry) {
            return entry.second.state == ClientSceneState::Active;
        });
    return found == client_scenes_.end()
               ? std::nullopt
               : std::optional<ClientScene> { found->second };
}

std::optional<ClientScene> SceneCoordinator::foreground_client_scene() const
{
    std::lock_guard lock { mutex_ };
    const auto found = std::find_if(
        client_scenes_.begin(), client_scenes_.end(), [](const auto& entry) {
            return entry.second.state == ClientSceneState::Active ||
                   entry.second.state == ClientSceneState::Exiting;
        });
    return found == client_scenes_.end()
               ? std::nullopt
               : std::optional<ClientScene> { found->second };
}

void SceneCoordinator::retire_process(std::uint32_t process_id)
{
    if (process_id == 0U)
        return;
    std::lock_guard lock { mutex_ };
    client_scenes_.erase(process_id);
}

} // namespace shade
