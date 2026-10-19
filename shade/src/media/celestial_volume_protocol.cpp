// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode and decode firmware media-source and category-volume IPC
// payloads.

#include "media/celestial_volume_protocol.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <cstring>
#include <limits>
#include <string_view>
#include <utility>

#if defined(SHADE_HAS_LIBPLIST)
#include <plist/plist.h>
#endif

namespace shade::celestial_volume_protocol {
namespace {

    constexpr std::uint32_t category_volume_reply_identifier = 1138;
    struct SourceProtocolProfile {
        std::uint32_t create_request;
        std::uint32_t create_reply;
        std::uint32_t source_property_request;
        std::uint32_t player_property_request;
        bool file_url_path;
        bool binary_property_list;
    };
    constexpr SourceProtocolProfile fig_movie_profile {
        1027, 1127, 1031, 0, false, false };
    constexpr SourceProtocolProfile fig_player_remote_profile {
        2023, 2123, 2030, 2026, true, true };
    constexpr std::array source_profiles { fig_movie_profile,
        fig_player_remote_profile };
    constexpr std::size_t return_code_offset = 32;
    constexpr std::size_t volume_offset = 36;
    constexpr std::size_t category_present_offset = 40;
    constexpr std::size_t category_length_offset = 44;
    constexpr std::size_t category_offset = 48;
    constexpr std::uint32_t maximum_category_length = 128;
    constexpr std::size_t source_identifier_offset = 32;
    constexpr std::size_t source_property_length_offset = 40;
    constexpr std::size_t source_property_offset = 44;
    constexpr std::size_t player_property_length_offset = 36;
    constexpr std::size_t player_property_offset = 40;
    constexpr std::uint32_t maximum_source_property_length = 128;
    constexpr std::uint32_t maximum_source_path_length = 4096;

    std::uint32_t read_word(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint32_t value { };
        std::memcpy(&value, bytes.data() + offset, sizeof(value));
        return value;
    }

    bool printable_ascii(std::span<const std::byte> bytes)
    {
        return std::ranges::all_of(bytes, [](std::byte value) {
            const auto character = std::to_integer<unsigned char>(value);
            return character >= 0x20U && character <= 0x7eU;
        });
    }

    const SourceProtocolProfile* find_profile(
        std::uint32_t identifier, std::uint32_t SourceProtocolProfile::*field)
    {
        for (const auto& profile : source_profiles) {
            if (profile.*field == identifier)
                return &profile;
        }
        return nullptr;
    }

    std::optional<float> decode_binary_plist_number(
        std::span<const std::byte> bytes)
    {
#if defined(SHADE_HAS_LIBPLIST)
        if (bytes.empty() ||
            bytes.size() > std::numeric_limits<std::uint32_t>::max()) {
            return std::nullopt;
        }
        plist_t root = nullptr;
        const auto result = plist_from_bin(
            reinterpret_cast<const char*>(bytes.data()),
            static_cast<std::uint32_t>(bytes.size()), &root);
        if (result != PLIST_ERR_SUCCESS || root == nullptr)
            return std::nullopt;
        double value { };
        switch (plist_get_node_type(root)) {
        case PLIST_BOOLEAN: {
            std::uint8_t boolean { };
            plist_get_bool_val(root, &boolean);
            value = boolean != 0 ? 1.0 : 0.0;
            break;
        }
        case PLIST_INT: {
            std::int64_t integer { };
            plist_get_int_val(root, &integer);
            value = static_cast<double>(integer);
            break;
        }
        case PLIST_REAL:
            plist_get_real_val(root, &value);
            break;
        default:
            plist_free(root);
            return std::nullopt;
        }
        plist_free(root);
        if (!std::isfinite(value) ||
            value < -std::numeric_limits<float>::max() ||
            value > std::numeric_limits<float>::max()) {
            return std::nullopt;
        }
        return static_cast<float>(value);
#else
        static_cast<void>(bytes);
        return std::nullopt;
#endif
    }

    std::optional<SourceFloatProperty> decode_float_property(
        const SourceProtocolProfile& profile, std::uint32_t identifier,
        std::span<const std::byte> bytes)
    {
        const auto player_property = identifier == profile.player_property_request;
        const auto length_offset = player_property
                                       ? player_property_length_offset
                                       : source_property_length_offset;
        const auto property_offset = player_property ? player_property_offset
                                                     : source_property_offset;
        if (bytes.size() < property_offset)
            return std::nullopt;
        const auto encoded_length = read_word(bytes, length_offset);
        if (encoded_length < 2U ||
            encoded_length > maximum_source_property_length ||
            encoded_length > bytes.size() - property_offset) {
            return std::nullopt;
        }
        const auto property_bytes =
            bytes.subspan(property_offset, encoded_length - 1U);
        if (!printable_ascii(property_bytes) ||
            bytes[property_offset + encoded_length - 1U] !=
                std::byte { }) {
            return std::nullopt;
        }
        const auto value_size_offset =
            (property_offset + encoded_length + 3U) &
            ~std::size_t { 3U };
        const auto value_offset = value_size_offset + sizeof(std::uint32_t);
        if (value_size_offset > bytes.size() ||
            sizeof(std::uint32_t) > bytes.size() - value_size_offset) {
            return std::nullopt;
        }
        const auto value_size = read_word(bytes, value_size_offset);
        if (value_offset > bytes.size() || value_size > bytes.size() - value_offset)
            return std::nullopt;
        std::optional<float> value;
        if (profile.binary_property_list) {
            value = decode_binary_plist_number(
                bytes.subspan(value_offset, value_size));
        } else if (value_size == sizeof(float)) {
            const auto decoded =
                std::bit_cast<float>(read_word(bytes, value_offset));
            if (std::isfinite(decoded))
                value = decoded;
        }
        if (!value)
            return std::nullopt;

        std::string property {
            reinterpret_cast<const char*>(property_bytes.data()),
            property_bytes.size() };
        if (property == "Server_Rate")
            property = "rate";
        else if (property == "Volume")
            property = "uservolume";
        return SourceFloatProperty {
            player_property
                ? std::nullopt
                : std::optional { read_word(bytes, source_identifier_offset) },
            std::move(property), *value };
    }

} // namespace

std::optional<CategoryVolume> decode_reply(
    std::uint32_t identifier, std::span<const std::byte> bytes)
{
    if (identifier != category_volume_reply_identifier ||
        bytes.size() < category_offset ||
        read_word(bytes, return_code_offset) != 0 ||
        read_word(bytes, category_present_offset) == 0) {
        return std::nullopt;
    }

    const auto length = read_word(bytes, category_length_offset);
    if (length == 0 || length > maximum_category_length ||
        length > bytes.size() - category_offset) {
        return std::nullopt;
    }
    const auto value = std::bit_cast<float>(read_word(bytes, volume_offset));
    if (!std::isfinite(value) || value < 0.0F || value > 1.0F)
        return std::nullopt;

    std::string category;
    category.reserve(length);
    for (std::size_t index = 0; index < length; ++index) {
        const auto character =
            std::to_integer<unsigned char>(bytes[category_offset + index]);
        if (character < 0x20U || character > 0x7eU)
            return std::nullopt;
        category.push_back(static_cast<char>(character));
    }
    return CategoryVolume { std::move(category), value };
}

std::optional<std::string> decode_source_create_path(
    std::uint32_t identifier, std::span<const std::byte> payload)
{
    const auto* profile =
        find_profile(identifier, &SourceProtocolProfile::create_request);
    if (profile == nullptr || payload.empty() ||
        payload.size() > maximum_source_path_length) {
        return std::nullopt;
    }
    const auto terminator = std::ranges::find(payload, std::byte { });
    const auto path_bytes = payload.first(
        static_cast<std::size_t>(std::distance(payload.begin(), terminator)));
    if (path_bytes.empty())
        return std::nullopt;
    if (!printable_ascii(path_bytes))
        return std::nullopt;
    std::string_view path { reinterpret_cast<const char*>(path_bytes.data()),
        path_bytes.size() };
    if (profile->file_url_path) {
        constexpr std::string_view local_file_url = "file://localhost";
        constexpr std::string_view file_url = "file://";
        if (path.starts_with(local_file_url))
            path.remove_prefix(local_file_url.size());
        else if (path.starts_with(file_url))
            path.remove_prefix(file_url.size());
    }
    if (path.empty() || path.front() != '/')
        return std::nullopt;
    return std::string { path };
}

std::optional<SourceCreateReply> decode_source_create_reply(
    std::uint32_t identifier, std::span<const std::byte> bytes)
{
    if (find_profile(identifier, &SourceProtocolProfile::create_reply) == nullptr ||
        bytes.size() < source_identifier_offset + sizeof(std::uint32_t) * 2U ||
        read_word(bytes, return_code_offset) != 0) {
        return std::nullopt;
    }
    const auto source = read_word(bytes, source_identifier_offset + 4U);
    return source == 0 ? std::nullopt
                       : std::optional { SourceCreateReply { source } };
}

std::optional<SourceFloatProperty> decode_source_float_property_request(
    std::uint32_t identifier, std::span<const std::byte> bytes)
{
    for (const auto& profile : source_profiles) {
        if (identifier == profile.source_property_request ||
            (profile.player_property_request != 0 &&
                identifier == profile.player_property_request)) {
            return decode_float_property(profile, identifier, bytes);
        }
    }
    return std::nullopt;
}

} // namespace shade::celestial_volume_protocol
