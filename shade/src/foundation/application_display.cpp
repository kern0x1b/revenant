// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve application presentation size and orientation from bundle
// metadata.

#include "foundation/application_display.hpp"

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <optional>
#include <string>
#include <system_error>

#if defined(SHADE_HAS_LIBPLIST)
#include <plist/plist.h>
#endif

namespace shade {
namespace {

    std::optional<DisplayOrientation> parse_orientation(std::string_view value)
    {
        if (value == "UIInterfaceOrientationPortrait")
            return DisplayOrientation::Portrait;
        if (value == "UIInterfaceOrientationPortraitUpsideDown")
            return DisplayOrientation::PortraitUpsideDown;
        if (value == "UIInterfaceOrientationLandscapeLeft")
            return DisplayOrientation::LandscapeLeft;
        if (value == "UIInterfaceOrientationLandscapeRight")
            return DisplayOrientation::LandscapeRight;
        return std::nullopt;
    }

    bool tablet_sized(DisplayGeometry geometry)
    {
        return geometry.valid() &&
               std::min(geometry.width, geometry.height) > 480U;
    }

    std::filesystem::path info_plist_path(
        const std::filesystem::path& rootfs, std::string_view executable_path)
    {
        auto relative = std::filesystem::path { executable_path };
        if (relative.is_absolute())
            relative = relative.relative_path();
        return rootfs / relative.parent_path() / "Info.plist";
    }

    // A number of pre-iOS 3 applications did not put an orientation key in
    // their top-level manifest.  Their UIKit/OpenFeint resource profile is
    // nevertheless explicit in the bundle layout (for example, an
    // iPhone_Landscape resource bundle).  Treat a single, unambiguous resource
    // orientation as a capability; never let a landscape-only helper coexist
    // with a portrait profile and then guess which one the application wanted.
    std::optional<DisplayOrientation> resource_bundle_orientation(
        const std::filesystem::path& app_bundle)
    {
        bool landscape = false;
        bool portrait = false;
        std::error_code error;
        std::filesystem::directory_iterator entries { app_bundle, error };
        if (error)
            return std::nullopt;
        for (const auto& entry : entries) {
            std::error_code entry_error;
            if (!entry.is_directory(entry_error) || entry_error)
                continue;
            const auto filename = entry.path().filename().string();
            std::string lowercase;
            lowercase.reserve(filename.size());
            for (const auto character : filename) {
                lowercase.push_back(static_cast<char>(
                    std::tolower(static_cast<unsigned char>(character))));
            }
            if (lowercase.size() < 7U ||
                lowercase.compare(lowercase.size() - 7U, 7U, ".bundle") != 0)
                continue;
            landscape =
                landscape || lowercase.find("landscape") != std::string::npos;
            portrait =
                portrait || lowercase.find("portrait") != std::string::npos;
        }
        if (landscape && !portrait)
            return DisplayOrientation::LandscapeLeft;
        return std::nullopt;
    }

#if defined(SHADE_HAS_LIBPLIST)
    class PlistOwner {
    public:
        explicit PlistOwner(plist_t node = nullptr)
            : node_ { node }
        {
        }
        ~PlistOwner()
        {
            if (node_ != nullptr)
                plist_free(node_);
        }
        PlistOwner(const PlistOwner&) = delete;
        PlistOwner& operator=(const PlistOwner&) = delete;
        [[nodiscard]] plist_t get() const { return node_; }

    private:
        plist_t node_ { };
    };

    std::optional<DisplayOrientation> plist_orientation(plist_t root)
    {
        const auto read_string =
            [](plist_t node) -> std::optional<DisplayOrientation> {
            if (node == nullptr || plist_get_node_type(node) != PLIST_STRING)
                return std::nullopt;
            std::uint64_t length { };
            const auto* value = plist_get_string_ptr(node, &length);
            if (value == nullptr)
                return std::nullopt;
            return parse_orientation(
                std::string_view { value, static_cast<std::size_t>(length) });
        };

        if (const auto value = read_string(
                plist_dict_get_item(root, "UIInterfaceOrientation")))
            return value;
        // UISupportedInterfaceOrientations is a capability set, not a request
        // for the application's initial orientation. UIKit owns selection
        // within that set; choosing the first parseable member here can rotate
        // an application merely because an earlier capability is unknown to
        // this host.
        return std::nullopt;
    }

    bool plist_is_iphone_only(plist_t root)
    {
        const auto families = plist_dict_get_item(root, "UIDeviceFamily");
        if (families == nullptr || plist_get_node_type(families) != PLIST_ARRAY)
            return false;
        bool iphone = false;
        bool ipad = false;
        for (std::uint32_t index = 0; index < plist_array_get_size(families);
            ++index) {
            const auto family = plist_array_get_item(families, index);
            if (family == nullptr || plist_get_node_type(family) != PLIST_UINT)
                continue;
            std::uint64_t value { };
            plist_get_uint_val(family, &value);
            iphone = iphone || value == 1U;
            ipad = ipad || value == 2U;
        }
        return iphone && !ipad;
    }
#endif

} // namespace

ApplicationDisplay detect_application_display(
    const std::filesystem::path& rootfs, std::string_view executable_path,
    DisplayGeometry user_interface_geometry)
{
    ApplicationDisplay profile;
    if (!tablet_sized(user_interface_geometry) || rootfs.empty() ||
        executable_path.empty()) {
        return profile;
    }

#if defined(SHADE_HAS_LIBPLIST)
    const auto path = info_plist_path(rootfs, executable_path);
    std::ifstream input { path, std::ios::binary };
    if (!input)
        return profile;
    const std::string bytes { std::istreambuf_iterator<char> { input },
        std::istreambuf_iterator<char> { } };
    plist_t parsed = nullptr;
    plist_format_t format = PLIST_FORMAT_NONE;
    if (plist_from_memory(bytes.data(),
            static_cast<std::uint32_t>(bytes.size()), &parsed, &format) !=
            PLIST_ERR_SUCCESS ||
        parsed == nullptr || plist_get_node_type(parsed) != PLIST_DICT) {
        if (parsed != nullptr)
            plist_free(parsed);
        return profile;
    }
    PlistOwner root { parsed };
    if (plist_is_iphone_only(root.get())) {
        profile.kind = ApplicationDisplayMode::IPhoneCompatibility1x;
        profile.logical_geometry = default_display_geometry;
    }
#else
    static_cast<void>(rootfs);
    static_cast<void>(executable_path);
#endif
    return profile;
}

DisplayGeometry application_display_geometry(
    const ApplicationDisplay& profile, DisplayGeometry output)
{
    if (profile.kind != ApplicationDisplayMode::Native &&
        profile.logical_geometry.valid()) {
        return profile.logical_geometry;
    }
    return output;
}

DisplayViewport application_display_viewport(
    const ApplicationDisplay& profile, DisplayGeometry output)
{
    if (!output.valid())
        return { };
    if (profile.kind == ApplicationDisplayMode::Native ||
        !profile.logical_geometry.valid()) {
        return { 0, 0, output.width, output.height };
    }
    if (profile.logical_geometry.width <= output.width &&
        profile.logical_geometry.height <= output.height) {
        return { static_cast<std::int32_t>(
                     (output.width - profile.logical_geometry.width) / 2U),
            static_cast<std::int32_t>(
                (output.height - profile.logical_geometry.height) / 2U),
            profile.logical_geometry.width, profile.logical_geometry.height };
    }
    return fit_display_viewport(profile.logical_geometry, output);
}

std::vector<std::uint32_t> compose_application_display_pixels(
    const ApplicationDisplay& profile, DisplayGeometry source,
    DisplayGeometry output, std::span<const std::uint32_t> pixels)
{
    if (!source.valid() || !output.valid() ||
        pixels.size() != source.pixel_count()) {
        return { };
    }
    if (profile.kind == ApplicationDisplayMode::Native) {
        if (source.width != output.width || source.height != output.height)
            return { };
        return { pixels.begin(), pixels.end() };
    }
    if (!profile.logical_geometry.valid())
        return { };
    const auto viewport = application_display_viewport(profile, output);
    const auto source_width =
        std::min(profile.logical_geometry.width, source.width);
    const auto source_height =
        std::min(profile.logical_geometry.height, source.height);
    if (viewport.width == 0U || viewport.height == 0U || source_width == 0U ||
        source_height == 0U || viewport.x < 0 || viewport.y < 0 ||
        viewport.width > output.width || viewport.height > output.height ||
        static_cast<std::uint32_t>(viewport.x) >
            output.width - viewport.width ||
        static_cast<std::uint32_t>(viewport.y) >
            output.height - viewport.height) {
        return { };
    }
    std::vector<std::uint32_t> composed(output.pixel_count(), 0xff000000U);
    for (std::uint32_t y = 0; y < viewport.height; ++y) {
        const auto source_y = std::min(
            source_height - 1U,
            static_cast<std::uint32_t>(static_cast<std::uint64_t>(y) *
                                        source_height / viewport.height));
        for (std::uint32_t x = 0; x < viewport.width; ++x) {
            const auto source_x = std::min(
                source_width - 1U,
                static_cast<std::uint32_t>(static_cast<std::uint64_t>(x) *
                                            source_width / viewport.width));
            composed[static_cast<std::size_t>(viewport.y +
                                               static_cast<std::int32_t>(y)) *
                         output.width +
                     static_cast<std::uint32_t>(viewport.x) + x] =
                pixels[static_cast<std::size_t>(source_y) * source.width +
                       source_x];
        }
    }
    return composed;
}

DisplayOrientation detect_application_display_orientation(
    const std::filesystem::path& rootfs, std::string_view executable_path)
{
    const auto portrait_fallback = [&] {
        return resource_bundle_orientation(
            info_plist_path(rootfs, executable_path).parent_path())
            .value_or(DisplayOrientation::Portrait);
    };
    if (rootfs.empty() || executable_path.empty())
        return DisplayOrientation::Portrait;
    const auto path = info_plist_path(rootfs, executable_path);
    std::ifstream input { path, std::ios::binary };
    if (!input)
        return portrait_fallback();

#if defined(SHADE_HAS_LIBPLIST)
    const std::string bytes { std::istreambuf_iterator<char> { input },
        std::istreambuf_iterator<char> { } };
    plist_t parsed = nullptr;
    plist_format_t format = PLIST_FORMAT_NONE;
    if (plist_from_memory(bytes.data(),
            static_cast<std::uint32_t>(bytes.size()), &parsed,
            &format) != PLIST_ERR_SUCCESS ||
        parsed == nullptr || plist_get_node_type(parsed) != PLIST_DICT) {
        if (parsed != nullptr)
            plist_free(parsed);
        return portrait_fallback();
    }
    PlistOwner root { parsed };
    if (const auto orientation = plist_orientation(root.get()))
        return *orientation;
    if (const auto orientation =
            resource_bundle_orientation(path.parent_path()))
        return *orientation;
    return DisplayOrientation::Portrait;
#else
    static_cast<void>(input);
    return portrait_fallback();
#endif
}

const char* display_orientation_name(DisplayOrientation orientation)
{
    switch (orientation) {
    case DisplayOrientation::Portrait:
        return "portrait";
    case DisplayOrientation::PortraitUpsideDown:
        return "portrait-upside-down";
    case DisplayOrientation::LandscapeLeft:
        return "landscape-left";
    case DisplayOrientation::LandscapeRight:
        return "landscape-right";
    }
    return "portrait";
}

std::vector<std::uint32_t> orient_display_pixels(
    DisplayGeometry source_geometry, std::span<const std::uint32_t> pixels,
    DisplayOrientation orientation)
{
    if (!source_geometry.valid() ||
        pixels.size() != source_geometry.pixel_count())
        return { };
    const auto output_geometry =
        is_landscape(orientation)
            ? DisplayGeometry { source_geometry.height, source_geometry.width }
            : source_geometry;
    std::vector<std::uint32_t> output(output_geometry.pixel_count());
    const auto source_at = [&](std::uint32_t x, std::uint32_t y) {
        return pixels[static_cast<std::size_t>(y) * source_geometry.width + x];
    };
    for (std::uint32_t y = 0; y < output_geometry.height; ++y) {
        for (std::uint32_t x = 0; x < output_geometry.width; ++x) {
            std::uint32_t source_x { };
            std::uint32_t source_y { };
            switch (orientation) {
            case DisplayOrientation::Portrait:
                source_x = x;
                source_y = y;
                break;
            case DisplayOrientation::PortraitUpsideDown:
                source_x = source_geometry.width - 1U - x;
                source_y = source_geometry.height - 1U - y;
                break;
            case DisplayOrientation::LandscapeLeft:
                source_x = y;
                source_y = x;
                break;
            case DisplayOrientation::LandscapeRight:
                source_x = source_geometry.width - 1U - y;
                source_y = source_geometry.height - 1U - x;
                break;
            }
            output[static_cast<std::size_t>(y) * output_geometry.width + x] =
                source_at(source_x, source_y);
        }
    }
    return output;
}

} // namespace shade
