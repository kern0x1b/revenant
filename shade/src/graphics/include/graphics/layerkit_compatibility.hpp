// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track legacy LayerKit root-window placement and scene compatibility
// state.

#pragma once

#include <cstdint>
#include <map>
#include <optional>
#include <set>
#include <span>

namespace shade {

struct LayerKitApplicationPlacement {
    std::uint32_t position_y { };
    float presentation_offset_x { };
    float presentation_offset_y { };
    float screen_origin_y { };

    bool operator==(const LayerKitApplicationPlacement&) const = default;
};

// Early LayerKit clients can publish a fully populated window tree, then set
// the render context to a detached, empty wrapper layer. Real iPhone OS 2.x
// reconnects that wrapper during the same transaction. Track the transaction
// shape so the compatibility kernel can select the already-committed wrapper
// when the detached root arrives without a cached presentation object. The
// wrapper must be preserved so the client context remains structurally intact.
class LayerKitRootCompatibility {
public:
    // Returns true when this starts a new remote scene generation.
    bool set_layer_id(std::uint32_t context, std::uint32_t layer_id);

    [[nodiscard]] std::optional<LayerKitApplicationPlacement>
    application_window_placement(std::uint32_t context,
        std::uint32_t current_layer_id, std::uint32_t object_id,
        std::uint32_t render_flags, std::uint32_t position_x,
        std::uint32_t position_y, std::uint32_t width, std::uint32_t height,
        std::uint32_t viewport_width, std::uint32_t viewport_height) const;

    [[nodiscard]] std::optional<std::uint32_t> observe_commit(
        std::uint32_t context, std::uint32_t current_layer_id,
        std::uint32_t object_id, std::uint32_t render_flags,
        std::uint32_t commit_flags, std::span<const std::uint32_t> children,
        bool root_handle_cached);

private:
    struct ContextState {
        std::uint32_t layer_id { };
        std::uint32_t attached_window_wrapper { };
        std::uint32_t attached_window_root { };
        std::set<std::uint32_t> complete_layers;
        std::set<std::uint32_t> nested_complete_layers;
        bool redirected { };
    };

    std::map<std::uint32_t, ContextState> contexts_;
};

} // namespace shade
