// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "backlight.hpp"
#include "kernel/iokit_abi.hpp"

#ifdef SHADE_HAS_LIBPLIST
#include <plist/plist.h>
#endif

#include <memory>

namespace shade::kernel_iokit {
namespace {
    using Property = KernelSharedState::IOKitRegistryProperty;

    Property number(std::uint32_t value)
    {
        std::vector<std::byte> bytes(4);
        for (std::size_t index = 0; index < bytes.size(); ++index)
            bytes[index] = static_cast<std::byte>(value >> (index * 8U));
        return { Property::Kind::Number, std::move(bytes) };
    }

    Property dictionary(std::map<std::string, Property> values)
    {
        Property result;
        result.kind = Property::Kind::Dictionary;
        result.dictionary_value = std::move(values);
        return result;
    }
#ifdef SHADE_HAS_LIBPLIST
    using Plist = std::unique_ptr<void, decltype(&plist_free)>;

    Plist parse(std::span<const std::byte> data)
    {
        auto xml =
            std::string_view { reinterpret_cast<const char*>(data.data()),
                data.size() };
        if (const auto end = xml.find('\0'); end != std::string_view::npos)
            xml = xml.substr(0, end);
        // IOCFSerialize returns an XML value without a plist document wrapper.
        const auto document = std::string { "<plist version=\"1.0\">" } +
                              std::string { xml } + "</plist>";
        plist_t parsed = nullptr;
        plist_from_xml(document.data(),
            static_cast<std::uint32_t>(document.size()), &parsed);
        return Plist { parsed, plist_free };
    }
#endif
}

bool BacklightControl::matches(std::span<const std::byte> matching)
{
#ifdef SHADE_HAS_LIBPLIST
    const auto root = parse(matching);
    const auto parsed = root.get();
    if (parsed == nullptr || plist_get_node_type(parsed) != PLIST_DICT ||
        plist_dict_get_size(parsed) != 1U)
        return false;
    const auto properties = plist_dict_get_item(parsed, "IOPropertyMatch");
    if (properties == nullptr ||
        plist_get_node_type(properties) != PLIST_DICT ||
        plist_dict_get_size(properties) != 1U)
        return false;
    const auto control = plist_dict_get_item(properties, "backlight-control");
    if (control == nullptr || plist_get_node_type(control) != PLIST_BOOLEAN)
        return false;
    std::uint8_t enabled = 0;
    plist_get_bool_val(control, &enabled);
    return enabled != 0;
#else
    return false;
#endif
}

void BacklightControl::publish(KernelSharedState::IOKitService& service)
{
    service.properties.emplace("backlight-control",
        Property { Property::Kind::Boolean, { std::byte { 1 } } });
    service.properties.emplace("IODisplayParameters",
        dictionary({ { "brightness",
            dictionary({ { "min", number(0) }, { "max", number(255) },
                { "value", number(255) } }) } }));
}

std::uint32_t BacklightControl::set_properties(
    KernelSharedState::IOKitService& service, std::span<const std::byte> data)
{
#ifdef SHADE_HAS_LIBPLIST
    const auto root = parse(data);
    if (!root || plist_get_node_type(root.get()) != PLIST_DICT)
        return iokit_abi::bad_argument;
    std::map<std::string, std::uint32_t> updates;
    for (const auto* key : { "brightness", "backlight-level", "FadePeriod" }) {
        const auto item = plist_dict_get_item(root.get(), key);
        if (item == nullptr)
            continue;
        if (plist_get_node_type(item) != PLIST_UINT)
            return iokit_abi::bad_argument;
        std::uint64_t value = 0;
        plist_get_uint_val(item, &value);
        if (value >
            (std::string_view { key } == "FadePeriod" ? 0xffffffffULL : 255ULL))
            return iokit_abi::bad_argument;
        updates.emplace(key, static_cast<std::uint32_t>(value));
    }
    if (updates.size() != plist_dict_get_size(root.get()))
        return iokit_abi::unsupported;
    for (const auto& [key, value] : updates) {
        if (key == "brightness") {
            service.properties.at("IODisplayParameters")
                .dictionary_value.at("brightness")
                .dictionary_value["value"] = number(value);
        } else {
            service.properties[key] = number(value);
        }
    }
    return iokit_abi::success;
#else
    return iokit_abi::unsupported;
#endif
}

} // namespace shade::kernel_iokit
