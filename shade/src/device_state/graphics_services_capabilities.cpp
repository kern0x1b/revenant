// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Build the guest GraphicsServices capability payload from firmware
// and device state.

#include "device_state/graphics_services_capabilities.hpp"

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <optional>
#include <set>
#include <string>
#include <string_view>

#if defined(SHADE_HAS_LIBPLIST)
#include <plist/plist.h>
#endif

namespace shade {
namespace {

    std::vector<std::byte> pack_payload(std::string_view xml)
    {
        if (xml.size() > std::numeric_limits<std::uint32_t>::max())
            return { };
        std::vector<std::byte> payload(sizeof(std::uint32_t) + xml.size());
        const auto length = static_cast<std::uint32_t>(xml.size());
        for (std::size_t index = 0; index < sizeof(length); ++index) {
            payload[index] = static_cast<std::byte>(
                (length >> (index * 8U)) & 0xffU);
        }
        for (std::size_t index = 0; index < xml.size(); ++index)
            payload[sizeof(length) + index] =
                static_cast<std::byte>(xml[index]);
        return payload;
    }

#if defined(SHADE_HAS_LIBPLIST)
    void merge_dictionary(plist_t destination, plist_t source)
    {
        if (destination == nullptr || source == nullptr ||
            plist_get_node_type(destination) != PLIST_DICT ||
            plist_get_node_type(source) != PLIST_DICT) {
            return;
        }
        plist_dict_iter iterator = nullptr;
        plist_dict_new_iter(source, &iterator);
        if (iterator == nullptr)
            return;
        char* key = nullptr;
        plist_t value = nullptr;
        while (true) {
            plist_dict_next_item(source, iterator, &key, &value);
            if (key == nullptr || value == nullptr)
                break;
            plist_dict_set_item(destination, key, plist_copy(value));
            std::free(key);
            key = nullptr;
        }
        if (key != nullptr)
            std::free(key);
        std::free(iterator);
    }

    std::optional<std::string> read_file(const std::filesystem::path& path)
    {
        std::ifstream input { path, std::ios::binary };
        if (!input)
            return std::nullopt;
        return std::string { std::istreambuf_iterator<char> { input },
            std::istreambuf_iterator<char> { } };
    }

    plist_t load_capabilities(const std::filesystem::path& directory,
        std::string_view file_name, std::set<std::string>& visiting)
    {
        const auto name = std::string { file_name };
        if (name.empty() || !visiting.insert(name).second)
            return plist_new_dict();
        const auto content = read_file(directory / (name + ".plist"));
        if (!content) {
            visiting.erase(name);
            return plist_new_dict();
        }
        plist_t root = nullptr;
        plist_format_t format = PLIST_FORMAT_XML;
        if (plist_from_memory(content->data(),
                static_cast<std::uint32_t>(content->size()), &root,
                &format) != PLIST_ERR_SUCCESS || root == nullptr ||
            plist_get_node_type(root) != PLIST_DICT) {
            if (root != nullptr)
                plist_free(root);
            visiting.erase(name);
            return plist_new_dict();
        }

        auto merged = plist_new_dict();
        const auto includes = plist_dict_get_item(root, "include");
        if (includes != nullptr && plist_get_node_type(includes) == PLIST_ARRAY) {
            for (std::uint32_t index = 0;
                index < plist_array_get_size(includes); ++index) {
                const auto item = plist_array_get_item(includes, index);
                if (item == nullptr ||
                    plist_get_node_type(item) != PLIST_STRING) {
                    continue;
                }
                std::uint64_t length = 0;
                const auto* include_name =
                    plist_get_string_ptr(item, &length);
                if (include_name == nullptr || length == 0)
                    continue;
                auto include = load_capabilities(directory,
                    std::string_view { include_name,
                        static_cast<std::size_t>(length) },
                    visiting);
                // load_capabilities returns the already-flattened capability
                // dictionary. Do not look for a second "capabilities" wrapper
                // here; inherited flags such as homescreen-wallpaper live at
                // this level in the recursive result.
                merge_dictionary(merged, include);
                plist_free(include);
            }
        }
        merge_dictionary(merged, plist_dict_get_item(root, "capabilities"));
        plist_free(root);
        visiting.erase(name);
        return merged;
    }

    void ensure_string(
        plist_t dictionary, const char* key, std::string_view value)
    {
        if (plist_dict_get_item(dictionary, key) != nullptr)
            return;
        plist_dict_set_item(dictionary, key,
            plist_new_string(std::string { value }.c_str()));
    }

    void ensure_bool(plist_t dictionary, const char* key, bool value)
    {
        plist_dict_set_item(dictionary, key, plist_new_bool(value ? 1 : 0));
    }

    void ensure_screen_dimensions(
        plist_t dictionary, const DeviceModel& profile)
    {
        auto dimensions = plist_dict_get_item(dictionary, "screen-dimensions");
        if (dimensions == nullptr) {
            dimensions = plist_new_dict();
            plist_dict_set_item(dictionary, "screen-dimensions", dimensions);
        }
        if (plist_get_node_type(dimensions) != PLIST_DICT)
            return;
        const auto ensure_uint = [dimensions](const char* key,
                                   std::uint64_t value) {
            if (plist_dict_get_item(dimensions, key) == nullptr)
                plist_dict_set_item(dimensions, key, plist_new_uint(value));
        };
        ensure_uint("width", profile.screen.panel.width);
        ensure_uint("height", profile.screen.panel.height);
        ensure_uint("main-screen-width", profile.screen.panel.width);
        ensure_uint("main-screen-height", profile.screen.panel.height);
        ensure_uint(
            "main-screen-scale", display_scale_factor(profile.screen.panel,
                                     profile.screen.user_interface));
        if (plist_dict_get_item(dimensions, "main-screen-orientation") ==
            nullptr) {
            plist_dict_set_item(
                dimensions, "main-screen-orientation", plist_new_real(0.0));
        }
    }

    std::vector<std::byte> from_firmware_plist(
        const std::filesystem::path& rootfs, const DeviceModel& profile)
    {
        const auto directory =
            rootfs / "System/Library/CoreServices/SpringBoard.app";
        std::set<std::string> visiting;
        auto capabilities = load_capabilities(
            directory, profile.identity.board_config, visiting);
        ensure_string(capabilities, "device-name",
            profile.screen.graphics_services.device_name);
        ensure_string(capabilities, "device-name-localized",
            profile.screen.graphics_services.device_name);
        ensure_string(capabilities, "marketing-name",
            profile.screen.graphics_services.marketing_name);
        ensure_bool(capabilities, "multitasking",
            profile.screen.graphics_services.supports_multitasking);
        ensure_bool(capabilities, "cellular-data",
            profile.screen.graphics_services.supports_cellular_data);
        ensure_screen_dimensions(capabilities, profile);

        char* serialized = nullptr;
        std::uint32_t length = 0;
        const auto result = plist_to_xml(capabilities, &serialized, &length);
        const bool valid = result == PLIST_ERR_SUCCESS && serialized != nullptr;
        std::vector<std::byte> payload = valid
            ? pack_payload({ serialized, static_cast<std::size_t>(length) })
            : std::vector<std::byte> { };
        if (serialized != nullptr)
            plist_mem_free(serialized);
        plist_free(capabilities);
        return payload;
    }
#endif

    std::vector<std::byte> fallback_payload(const DeviceModel& profile)
    {
        const auto& capabilities = profile.screen.graphics_services;
        const auto boolean = [](std::string_view key, bool value) {
            return "\t\t<key>" + std::string { key } + "</key>" +
                   (value ? "<true/>\n" : "<false/>\n");
        };
        std::string xml {
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            "<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" "
            "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
            "<plist version=\"1.0\"><dict>\n"
        };
        xml += "\t\t<key>device-name</key><string>" +
               std::string { capabilities.device_name } + "</string>\n";
        xml += "\t\t<key>device-name-localized</key><string>" +
               std::string { capabilities.device_name } + "</string>\n";
        xml += "\t\t<key>marketing-name</key><string>" +
               std::string { capabilities.marketing_name } + "</string>\n";
        xml += boolean("multitasking", capabilities.supports_multitasking);
        xml += boolean("cellular-data", capabilities.supports_cellular_data);
        xml += boolean("wifi", true);
        xml += boolean("accelerometer", true);
        xml += boolean("location-services", true);
        xml += boolean("microphone", true);
        xml += boolean("volume-buttons", true);
        xml += "\t\t<key>screen-dimensions</key><dict>"
               "<key>width</key><integer>" +
               std::to_string(profile.screen.panel.width) +
               "</integer><key>height</key><integer>" +
               std::to_string(profile.screen.panel.height) +
               "</integer><key>main-screen-width</key><integer>" +
               std::to_string(profile.screen.panel.width) +
               "</integer><key>main-screen-height</key><integer>" +
               std::to_string(profile.screen.panel.height) +
               "</integer><key>main-screen-scale</key><integer>" +
               std::to_string(display_scale_factor(
                   profile.screen.panel, profile.screen.user_interface)) +
               "</integer>"
               "<key>main-screen-orientation</key><real>0</real></dict>\n";
        xml += "</dict></plist>\n";
        return pack_payload(xml);
    }

} // namespace

std::vector<std::byte> make_graphics_services_capability_memory(
    const std::filesystem::path& rootfs, const DeviceModel& profile)
{
#if defined(SHADE_HAS_LIBPLIST)
    if (const auto payload = from_firmware_plist(rootfs, profile);
        !payload.empty()) {
        return payload;
    }
#else
    static_cast<void>(rootfs);
#endif
    return fallback_payload(profile);
}

} // namespace shade
