// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track presented layers, geometry and hit-test information across
// completed frames.

#include "graphics/presentation_tracker.hpp"

#include <algorithm>
#include <cmath>
#include <map>
#include <utility>

namespace shade {

std::uint64_t PresentationTracker::record(std::uint32_t submitting_process_id,
    std::vector<PresentationLayer> layers,
    std::optional<ClientScene> logical_client_scene)
{
    std::stable_sort(
        layers.begin(), layers.end(), [](const auto& left, const auto& right) {
            return left.order < right.order;
        });
    std::lock_guard lock { mutex_ };
    const auto sequence = allocate_sequence_locked();
    latest_ = PresentationFrame { sequence, submitting_process_id,
        std::move(logical_client_scene), std::move(layers) };
    return sequence;
}

std::uint64_t PresentationTracker::allocate_sequence_locked()
{
    const auto sequence = next_sequence_++;
    if (next_sequence_ == 0U)
        next_sequence_ = 1U;
    return sequence;
}

std::optional<PresentationFrame> PresentationTracker::latest() const
{
    std::lock_guard lock { mutex_ };
    return latest_;
}

std::vector<PresentationScene> PresentationTracker::latest_scenes() const
{
    std::lock_guard lock { mutex_ };
    return latest_scenes_locked();
}

std::optional<PresentationScene> PresentationTracker::latest_scene(
    std::uint32_t producer_process_id) const
{
    std::lock_guard lock { mutex_ };
    const auto scenes = latest_scenes_locked();
    const auto found = std::find_if(
        scenes.begin(), scenes.end(), [producer_process_id](const auto& scene) {
            return scene.producer_process_id == producer_process_id;
        });
    return found == scenes.end() ? std::nullopt
                                 : std::optional<PresentationScene> { *found };
}

std::optional<PresentationHitTest> PresentationTracker::hit_test(
    float x, float y) const
{
    if (!std::isfinite(x) || !std::isfinite(y))
        return std::nullopt;

    std::lock_guard lock { mutex_ };
    if (!latest_)
        return std::nullopt;

    PresentationHitTest result { latest_->sequence,
        latest_->submitting_process_id, latest_->logical_client_scene, { } };
    result.layers_front_to_back.reserve(latest_->layers.size());
    for (auto layer = latest_->layers.rbegin(); layer != latest_->layers.rend();
        ++layer) {
        const auto process_id = layer->surface_provenance.producer_process_id;
        const auto publication_sequence =
            layer->surface_provenance.publication_sequence;
        const auto& destination = layer->destination;
        if (process_id == 0U || publication_sequence == 0U ||
            !std::isfinite(destination.x) || !std::isfinite(destination.y) ||
            !std::isfinite(destination.width) ||
            !std::isfinite(destination.height) || destination.width <= 0.0F ||
            destination.height <= 0.0F) {
            continue;
        }
        if (const auto retired = retired_process_watermarks_.find(process_id);
            retired != retired_process_watermarks_.end() &&
            publication_sequence <= retired->second) {
            continue;
        }
        const auto right = destination.x + destination.width;
        const auto bottom = destination.y + destination.height;
        if (!std::isfinite(right) || !std::isfinite(bottom) ||
            x < destination.x || x >= right || y < destination.y ||
            y >= bottom) {
            continue;
        }
        result.layers_front_to_back.push_back(PresentationHit {
            layer->order, layer->surface_id, layer->surface_provenance });
    }
    return result;
}

bool PresentationTracker::has_presented_frame() const
{
    std::lock_guard lock { mutex_ };
    return latest_.has_value();
}

void PresentationTracker::retire_process(
    std::uint32_t process_id, std::uint64_t publication_watermark)
{
    if (process_id == 0U)
        return;
    std::lock_guard lock { mutex_ };
    auto& retired = retired_process_watermarks_[process_id];
    retired = std::max(retired, publication_watermark);
    if (latest_ && latest_->logical_client_scene &&
        latest_->logical_client_scene->client_process_id == process_id) {
        latest_->logical_client_scene.reset();
    }
}

std::vector<PresentationScene> PresentationTracker::latest_scenes_locked() const
{
    if (!latest_)
        return { };

    struct Accumulator {
        PresentationScene scene;
        float right { };
        float bottom { };
        float primary_area { -1.0F };
    };
    std::map<std::uint32_t, Accumulator> accumulated;
    for (const auto& layer : latest_->layers) {
        const auto process_id = layer.surface_provenance.producer_process_id;
        const auto publication_sequence =
            layer.surface_provenance.publication_sequence;
        if (process_id == 0U || publication_sequence == 0U ||
            !std::isfinite(layer.destination.x) ||
            !std::isfinite(layer.destination.y) ||
            !std::isfinite(layer.destination.width) ||
            !std::isfinite(layer.destination.height) ||
            layer.destination.width <= 0.0F ||
            layer.destination.height <= 0.0F) {
            continue;
        }
        if (const auto retired = retired_process_watermarks_.find(process_id);
            retired != retired_process_watermarks_.end() &&
            publication_sequence <= retired->second) {
            continue;
        }

        const auto right = layer.destination.x + layer.destination.width;
        const auto bottom = layer.destination.y + layer.destination.height;
        const auto area = layer.destination.width * layer.destination.height;
        auto [found, inserted] = accumulated.try_emplace(process_id);
        auto& entry = found->second;
        if (inserted) {
            entry.scene.frame_sequence = latest_->sequence;
            entry.scene.producer_process_id = process_id;
            entry.scene.destination_bounds = layer.destination;
            entry.right = right;
            entry.bottom = bottom;
        } else {
            const auto left =
                std::min(entry.scene.destination_bounds.x, layer.destination.x);
            const auto top =
                std::min(entry.scene.destination_bounds.y, layer.destination.y);
            entry.right = std::max(entry.right, right);
            entry.bottom = std::max(entry.bottom, bottom);
            entry.scene.destination_bounds = PresentationRectangle { left, top,
                entry.right - left, entry.bottom - top };
        }
        ++entry.scene.layer_count;
        if (area > entry.primary_area ||
            (area == entry.primary_area &&
                publication_sequence > entry.scene.primary_surface_sequence)) {
            entry.primary_area = area;
            entry.scene.primary_surface_id = layer.surface_id;
            entry.scene.primary_surface_sequence = publication_sequence;
            entry.scene.screen_to_surface = layer.screen_to_surface;
        }
    }

    std::vector<PresentationScene> scenes;
    scenes.reserve(accumulated.size());
    for (auto& [process_id, entry] : accumulated) {
        static_cast<void>(process_id);
        scenes.push_back(std::move(entry.scene));
    }
    return scenes;
}

} // namespace shade
