// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode and decode firmware media-source and category-volume IPC
// payloads.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>

namespace shade::celestial_volume_protocol {

struct CategoryVolume {
    std::string category;
    float value { };
};

struct SourceFloatProperty {
    // Player properties apply to the most recently created source, while
    // item properties carry an explicit server-side source identifier.
    std::optional<std::uint32_t> source;
    std::string property;
    float value { };
};

struct SourceCreateReply {
    std::uint32_t source { };
};

// Decode the mediaserverd response that reports the canonical category
// affected by an AVSystemController volume operation. Callers remain agnostic
// to SpringBoard and Preferences; both clients use the same service protocol.
[[nodiscard]] std::optional<CategoryVolume> decode_reply(
    std::uint32_t identifier, std::span<const std::byte> bytes);

// Fig media source creation transports either a canonical filesystem path or
// a local file URL out of line. The response returns a server-side source
// identifier. The Mach layer correlates the two through the request's reply-
// port object.
[[nodiscard]] std::optional<std::string> decode_source_create_path(
    std::uint32_t identifier, std::span<const std::byte> payload);
[[nodiscard]] std::optional<SourceCreateReply> decode_source_create_reply(
    std::uint32_t identifier, std::span<const std::byte> bytes);

// Fig media clients set typed float properties (including playback rate and
// user volume) on a source, or on the player's current source. Preserve
// explicit source identity so overlapping previews cannot affect one another.
[[nodiscard]] std::optional<SourceFloatProperty>
decode_source_float_property_request(
    std::uint32_t identifier, std::span<const std::byte> bytes);

} // namespace shade::celestial_volume_protocol
