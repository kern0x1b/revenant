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

namespace emulator::celestial_volume_protocol {

struct CategoryVolume {
    std::string category;
    float value { };
};

struct SourceFloatProperty {
    std::optional<std::uint32_t> source;
    std::string property;
    float value { };
};

struct SourceCreateReply {
    std::uint32_t source { };
};

[[nodiscard]] std::optional<CategoryVolume> decode_reply(
    std::uint32_t identifier, std::span<const std::byte> bytes);

[[nodiscard]] std::optional<std::string> decode_source_create_path(
    std::uint32_t identifier, std::span<const std::byte> payload);
[[nodiscard]] std::optional<SourceCreateReply> decode_source_create_reply(
    std::uint32_t identifier, std::span<const std::byte> bytes);

[[nodiscard]] std::optional<SourceFloatProperty>
decode_source_float_property_request(
    std::uint32_t identifier, std::span<const std::byte> bytes);

}
