// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track legacy LayerKit root-window placement and scene compatibility
// state.

#include "graphics/layerkit_compatibility.hpp"

#include <bit>
#include <cmath>
#include <limits>

namespace shade {
namespace {

    constexpr std::uint32_t render_type_mask = 0x001f0000U;
    constexpr std::uint32_t render_layer_type = 0x00020000U;
    constexpr std::uint32_t complete_object_flag = 0x01000000U;
    constexpr std::uint32_t sublayers_commit_flag = 2U;

} // namespace

bool LayerKitRootCompatibility::set_layer_id(
    std::uint32_t context, std::uint32_t layer_id)
{
    auto& state = contexts_[context];
    // SpringBoard reuses one remote render context and one detached root ID
    // across application launches. Once a transaction has been redirected,
    // setting even the same ID starts a new application generation and must
    // discard the previous wrapper graph.
    if (state.layer_id != layer_id || state.redirected) {
        state = ContextState { };
        state.layer_id = layer_id;
        return true;
    }
    return false;
}

std::optional<LayerKitApplicationPlacement>
LayerKitRootCompatibility::application_window_placement(std::uint32_t context,
    std::uint32_t current_layer_id, std::uint32_t object_id,
    std::uint32_t render_flags, std::uint32_t position_x,
    std::uint32_t position_y, std::uint32_t width, std::uint32_t height,
    std::uint32_t viewport_width, std::uint32_t viewport_height) const
{
    const auto found = contexts_.find(context);
    if (found == contexts_.end() || found->second.layer_id == 0U ||
        current_layer_id == 0U || object_id != current_layer_id ||
        (render_flags & render_type_mask) != render_layer_type ||
        (render_flags & complete_object_flag) == 0U || viewport_width == 0U ||
        viewport_height == 0U) {
        return std::nullopt;
    }
    const auto x = std::bit_cast<float>(position_x);
    const auto y = std::bit_cast<float>(position_y);
    const auto layer_width = std::bit_cast<float>(width);
    const auto layer_height = std::bit_cast<float>(height);
    const auto screen_width = static_cast<float>(viewport_width);
    const auto screen_height = static_cast<float>(viewport_height);
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(layer_width) ||
        !std::isfinite(layer_height) || layer_width != screen_width ||
        x * 2.0F != layer_width || layer_height <= 0.0F ||
        layer_height > screen_height) {
        return std::nullopt;
    }
    const auto inset = screen_height - layer_height;
    const auto rounded_inset = std::round(inset);
    const auto current_top = y - layer_height * 0.5F;
    if (inset < 0.0F || inset * 4.0F > screen_height ||
        inset != rounded_inset ||
        (current_top != 0.0F && current_top != inset) ||
        rounded_inset >
            static_cast<float>(std::numeric_limits<std::int32_t>::max())) {
        return std::nullopt;
    }
    // Only the render context's current root represents the remotely hosted App
    // scene. Full-width navigation/table children have their own shorter local
    // bounds; treating those as scenes adds their height deficit a second time.
    // Normalize both observed root transaction shapes from viewport geometry.
    const auto final_y = y + inset - current_top;
    // UIKit already converts the absolute UIWindow origin. Touch routing must
    // invert only the extra movement performed here, while screen_origin_y is
    // retained separately for SpringBoard's exit-snapshot preparation.
    return LayerKitApplicationPlacement { std::bit_cast<std::uint32_t>(final_y),
        0.0F, final_y - y, final_y - layer_height * 0.5F };
}

std::optional<std::uint32_t> LayerKitRootCompatibility::observe_commit(
    std::uint32_t context, std::uint32_t current_layer_id,
    std::uint32_t object_id, std::uint32_t render_flags,
    std::uint32_t commit_flags, std::span<const std::uint32_t> children,
    bool root_handle_cached)
{
    auto found = contexts_.find(context);
    if (found == contexts_.end() ||
        (render_flags & render_type_mask) != render_layer_type) {
        return std::nullopt;
    }
    auto& state = found->second;
    if ((render_flags & complete_object_flag) != 0U) {
        state.complete_layers.insert(object_id);
        state.nested_complete_layers.insert(children.begin(), children.end());
    }
    if (!state.redirected && commit_flags == sublayers_commit_flag &&
        children.size() == 1U &&
        state.complete_layers.contains(children.front()) &&
        !state.nested_complete_layers.contains(children.front())) {
        state.attached_window_wrapper = object_id;
        state.attached_window_root = children.front();
    }
    if (state.redirected || root_handle_cached ||
        state.complete_layers.contains(state.layer_id) ||
        current_layer_id != state.layer_id || object_id != state.layer_id ||
        commit_flags != 0U || !children.empty()) {
        return std::nullopt;
    }

    // Clients either publish an incomplete wrapper around one complete UIWindow
    // root, or make the wrapper itself the unique top-level complete layer.
    if (state.attached_window_wrapper == 0U) {
        std::uint32_t candidate { };
        for (const auto layer : state.complete_layers) {
            if (layer == state.layer_id ||
                state.nested_complete_layers.contains(layer)) {
                continue;
            }
            if (candidate != 0U) {
                return std::nullopt;
            }
            candidate = layer;
        }
        state.attached_window_wrapper = candidate;
        state.attached_window_root = state.attached_window_wrapper;
    }
    if (state.attached_window_wrapper == 0U ||
        state.attached_window_root == 0U ||
        !state.complete_layers.contains(state.attached_window_root)) {
        return std::nullopt;
    }
    state.redirected = true;
    return state.attached_window_wrapper;
}

} // namespace shade
