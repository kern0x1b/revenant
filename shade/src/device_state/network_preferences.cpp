// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain writable guest SystemConfiguration preferences for the
// virtual network.

#include "device_state/network_preferences.hpp"
#include "foundation/rootfs_path_resolver.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <system_error>
#include <utility>
#include <vector>

#if defined(SHADE_HAS_LIBPLIST)
#include <plist/plist.h>
#endif

namespace shade {
namespace {

    constexpr std::string_view default_set_identifier {
        "A1F4F2E2-EE3B-4C6D-8B67-1E6A43530002"
    };
    constexpr std::string_view default_service_identifier {
        "A1F4F2E2-EE3B-4C6D-8B67-1E6A43530001"
    };
    constexpr std::string_view managed_service_key { "ShadeManaged" };

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

    std::vector<char> read_file(const std::filesystem::path& path)
    {
        std::ifstream input { path, std::ios::binary };
        if (!input)
            return { };
        return { std::istreambuf_iterator<char> { input },
            std::istreambuf_iterator<char> { } };
    }

    plist_t ensure_dictionary(plist_t parent, const char* key, bool& changed)
    {
        auto node = plist_dict_get_item(parent, key);
        if (node != nullptr && plist_get_node_type(node) == PLIST_DICT)
            return node;
        node = plist_new_dict();
        plist_dict_set_item(parent, key, node);
        changed = true;
        return node;
    }

    plist_t ensure_array(plist_t parent, const char* key, bool& changed)
    {
        auto node = plist_dict_get_item(parent, key);
        if (node != nullptr && plist_get_node_type(node) == PLIST_ARRAY)
            return node;
        node = plist_new_array();
        plist_dict_set_item(parent, key, node);
        changed = true;
        return node;
    }

    bool string_equals(plist_t node, std::string_view expected)
    {
        if (node == nullptr || plist_get_node_type(node) != PLIST_STRING) {
            return false;
        }
        std::uint64_t length { };
        const auto* value = plist_get_string_ptr(node, &length);
        return value != nullptr && std::string_view { value,
            static_cast<std::size_t>(length) } == expected;
    }

    void ensure_string(
        plist_t parent, const char* key, std::string_view value, bool& changed)
    {
        if (string_equals(plist_dict_get_item(parent, key), value))
            return;
        const std::string owned { value };
        plist_dict_set_item(parent, key, plist_new_string(owned.c_str()));
        changed = true;
    }

    void ensure_uint(
        plist_t parent, const char* key, std::uint64_t value, bool& changed)
    {
        const auto node = plist_dict_get_item(parent, key);
        std::uint64_t current { };
        if (node != nullptr && plist_get_node_type(node) == PLIST_UINT) {
            plist_get_uint_val(node, &current);
            if (current == value)
                return;
        }
        plist_dict_set_item(parent, key, plist_new_uint(value));
        changed = true;
    }

    void ensure_bool(plist_t parent, const char* key, bool value, bool& changed)
    {
        const auto node = plist_dict_get_item(parent, key);
        std::uint8_t current { };
        if (node != nullptr && plist_get_node_type(node) == PLIST_BOOLEAN) {
            plist_get_bool_val(node, &current);
            if ((current != 0) == value)
                return;
        }
        plist_dict_set_item(parent, key, plist_new_bool(value ? 1U : 0U));
        changed = true;
    }

    bool array_contains_string(plist_t array, std::string_view value)
    {
        const auto count = plist_array_get_size(array);
        for (std::uint32_t index = 0; index < count; ++index) {
            if (string_equals(plist_array_get_item(array, index), value)) {
                return true;
            }
        }
        return false;
    }

    bool string_array_equals(
        plist_t node, const std::vector<std::string>& expected)
    {
        if (node == nullptr || plist_get_node_type(node) != PLIST_ARRAY ||
            plist_array_get_size(node) !=
                static_cast<std::uint32_t>(expected.size())) {
            return false;
        }
        for (std::uint32_t index = 0; index < expected.size(); ++index) {
            if (!string_equals(
                    plist_array_get_item(node, index), expected[index])) {
                return false;
            }
        }
        return true;
    }

    void ensure_string_array(plist_t parent, const char* key,
        const std::vector<std::string>& values, bool& changed)
    {
        if (string_array_equals(plist_dict_get_item(parent, key), values))
            return;
        const auto array = plist_new_array();
        for (const auto& value : values) {
            plist_array_append_item(array, plist_new_string(value.c_str()));
        }
        plist_dict_set_item(parent, key, array);
        changed = true;
    }

    std::string mac_address_string(const std::array<std::byte, 6>& address)
    {
        std::ostringstream text;
        text << std::hex << std::setfill('0');
        for (std::size_t index = 0; index < address.size(); ++index) {
            if (index != 0)
                text << ':';
            text << std::setw(2)
                 << std::to_integer<unsigned int>(address[index]);
        }
        return text.str();
    }

    std::string ipv4_address_string(const std::array<std::byte, 4>& address)
    {
        std::ostringstream text;
        for (std::size_t index = 0; index < address.size(); ++index) {
            if (index != 0)
                text << '.';
            text << std::to_integer<unsigned int>(address[index]);
        }
        return text.str();
    }

    bool bool_value(plist_t node)
    {
        if (node == nullptr || plist_get_node_type(node) != PLIST_BOOLEAN) {
            return false;
        }
        std::uint8_t value { };
        plist_get_bool_val(node, &value);
        return value != 0;
    }

    std::vector<std::string> preferred_wifi_networks(
        const RootfsPathResolver& resolver)
    {
        const auto path = resolver.resolve(
            "/Library/Preferences/SystemConfiguration/com.apple.wifi.plist");
        const auto bytes = read_file(path);
        if (bytes.empty() ||
            bytes.size() > std::numeric_limits<std::uint32_t>::max()) {
            return { };
        }

        plist_t parsed = nullptr;
        plist_format_t format { };
        if (plist_from_memory(bytes.data(),
                static_cast<std::uint32_t>(bytes.size()), &parsed,
                &format) != PLIST_ERR_SUCCESS ||
            parsed == nullptr || plist_get_node_type(parsed) != PLIST_DICT) {
            if (parsed != nullptr)
                plist_free(parsed);
            return { };
        }
        PlistOwner root { parsed };
        if (!string_equals(
                plist_dict_get_item(root.get(), "JoinMode"), "Automatic")) {
            return { };
        }

        const auto known =
            plist_dict_get_item(root.get(), "List of known networks");
        if (known == nullptr || plist_get_node_type(known) != PLIST_ARRAY) {
            return { };
        }
        std::vector<std::string> result;
        const auto count = plist_array_get_size(known);
        result.reserve(count);
        for (std::uint32_t index = 0; index < count; ++index) {
            const auto network = plist_array_get_item(known, index);
            if (network == nullptr ||
                plist_get_node_type(network) != PLIST_DICT) {
                continue;
            }
            const auto ssid = plist_dict_get_item(network, "SSID_STR");
            if (ssid == nullptr || plist_get_node_type(ssid) != PLIST_STRING) {
                continue;
            }
            std::uint64_t length { };
            const auto* value = plist_get_string_ptr(ssid, &length);
            if (value == nullptr || length == 0)
                continue;
            std::string candidate { value, static_cast<std::size_t>(length) };
            if (std::find(result.begin(), result.end(), candidate) ==
                result.end()) {
                result.push_back(std::move(candidate));
            }
        }
        return result;
    }

    std::string current_set_identifier(plist_t root)
    {
        const auto node = plist_dict_get_item(root, "CurrentSet");
        if (node == nullptr || plist_get_node_type(node) != PLIST_STRING) {
            return std::string { default_set_identifier };
        }
        std::uint64_t length { };
        const auto* value = plist_get_string_ptr(node, &length);
        if (value == nullptr || length == 0) {
            return std::string { default_set_identifier };
        }
        const std::string_view path { value, static_cast<std::size_t>(length) };
        const auto separator = path.find_last_of('/');
        const auto identifier = separator == std::string_view::npos
                                    ? path
                                    : path.substr(separator + 1);
        return identifier.empty() ? std::string { default_set_identifier }
                                  : std::string { identifier };
    }

    struct AirportService {
        std::string identifier;
        std::uint32_t property_count { };
        bool managed { };
    };

    std::vector<AirportService> find_airport_services(
        plist_t services, std::string_view interface_name)
    {
        std::vector<AirportService> result;
        plist_dict_iter iterator = nullptr;
        plist_dict_new_iter(services, &iterator);
        while (iterator != nullptr) {
            char* key = nullptr;
            plist_t service = nullptr;
            plist_dict_next_item(services, iterator, &key, &service);
            if (service == nullptr) {
                std::free(key);
                break;
            }
            const auto interface =
                plist_get_node_type(service) == PLIST_DICT
                    ? plist_dict_get_item(service, "Interface")
                    : nullptr;
            const bool matches =
                interface != nullptr &&
                plist_get_node_type(interface) == PLIST_DICT &&
                string_equals(plist_dict_get_item(interface, "DeviceName"),
                    interface_name);
            if (matches) {
                result.push_back({
                    .identifier = key == nullptr ? "" : key,
                    .property_count = plist_dict_get_size(service),
                    .managed = bool_value(plist_dict_get_item(
                        service, managed_service_key.data())),
                });
                std::free(key);
                continue;
            }
            std::free(key);
        }
        std::free(iterator);
        return result;
    }

    std::string preferred_airport_service(
        const std::vector<AirportService>& services)
    {
        if (services.empty())
            return { };
        const auto preferred =
            std::max_element(services.begin(), services.end(),
                [](const AirportService& left, const AirportService& right) {
                    if (left.managed != right.managed) {
                        return left.managed && !right.managed;
                    }
                    return left.property_count < right.property_count;
                });
        return preferred->identifier;
    }

    void remove_string_from_array(
        plist_t array, std::string_view value, bool& changed)
    {
        if (array == nullptr || plist_get_node_type(array) != PLIST_ARRAY)
            return;
        for (auto index = plist_array_get_size(array); index > 0; --index) {
            if (string_equals(plist_array_get_item(array, index - 1U), value)) {
                plist_array_remove_item(array, index - 1U);
                changed = true;
            }
        }
    }

    void remove_service_links(
        plist_t root, std::string_view identifier, bool& changed)
    {
        const auto sets = plist_dict_get_item(root, "Sets");
        if (sets == nullptr || plist_get_node_type(sets) != PLIST_DICT)
            return;
        plist_dict_iter iterator = nullptr;
        plist_dict_new_iter(sets, &iterator);
        while (iterator != nullptr) {
            char* key = nullptr;
            plist_t set = nullptr;
            plist_dict_next_item(sets, iterator, &key, &set);
            std::free(key);
            if (set == nullptr)
                break;
            if (plist_get_node_type(set) != PLIST_DICT)
                continue;
            const auto network = plist_dict_get_item(set, "Network");
            if (network == nullptr ||
                plist_get_node_type(network) != PLIST_DICT) {
                continue;
            }
            const auto global = plist_dict_get_item(network, "Global");
            const auto ipv4 =
                global != nullptr && plist_get_node_type(global) == PLIST_DICT
                    ? plist_dict_get_item(global, "IPv4")
                    : nullptr;
            if (ipv4 != nullptr && plist_get_node_type(ipv4) == PLIST_DICT) {
                remove_string_from_array(
                    plist_dict_get_item(ipv4, "ServiceOrder"), identifier,
                    changed);
            }
            const auto service_links = plist_dict_get_item(network, "Service");
            if (service_links != nullptr &&
                plist_get_node_type(service_links) == PLIST_DICT &&
                plist_dict_get_item(service_links,
                    std::string { identifier }.c_str()) != nullptr) {
                plist_dict_remove_item(
                    service_links, std::string { identifier }.c_str());
                changed = true;
            }
        }
        std::free(iterator);
    }

    void write_plist_atomically(
        const std::filesystem::path& path, plist_t root, plist_format_t format)
    {
        char* serialized = nullptr;
        std::uint32_t length { };
        const auto error = format == PLIST_FORMAT_BINARY
                               ? plist_to_bin(root, &serialized, &length)
                               : plist_to_xml(root, &serialized, &length);
        if (error != PLIST_ERR_SUCCESS || serialized == nullptr ||
            length == 0) {
            std::free(serialized);
            throw std::runtime_error {
                "could not serialize network preferences"
            };
        }

        std::filesystem::create_directories(path.parent_path());
        auto temporary = path;
        temporary += ".shade.tmp";
        {
            std::ofstream output { temporary,
                std::ios::binary | std::ios::trunc };
            if (!output || !output.write(serialized,
                               static_cast<std::streamsize>(length))) {
                std::free(serialized);
                throw std::runtime_error {
                    "could not write network preferences: " + temporary.string()
                };
            }
        }
        std::free(serialized);
        std::filesystem::rename(temporary, path);
    }

    bool ensure_wifi_capability_preferences(
        const RootfsPathResolver& resolver)
    {
        const auto path = resolver.resolve(
            "/Library/Preferences/SystemConfiguration/com.apple.wifi.plist");
        const auto bytes = read_file(path);
        plist_t parsed = nullptr;
        plist_format_t format = PLIST_FORMAT_XML;
        if (!bytes.empty()) {
            if (bytes.size() > std::numeric_limits<std::uint32_t>::max() ||
                plist_from_memory(bytes.data(),
                    static_cast<std::uint32_t>(bytes.size()), &parsed,
                    &format) != PLIST_ERR_SUCCESS ||
                parsed == nullptr || plist_get_node_type(parsed) != PLIST_DICT) {
                if (parsed != nullptr)
                    plist_free(parsed);
                throw std::runtime_error {
                    "could not parse Wi-Fi preferences: " + path.string()
                };
            }
        } else {
            parsed = plist_new_dict();
            format = PLIST_FORMAT_XML;
        }
        PlistOwner root { parsed };

        // WiFiManager on legacy firmware treats a missing capability as an
        // uninitialized serialized-data response. Add only the default for a
        // missing key; an explicit guest value remains guest-owned.
        if (plist_dict_get_item(root.get(), "WAPIEnabled") != nullptr)
            return false;
        plist_dict_set_item(root.get(), "WAPIEnabled", plist_new_bool(0));
        write_plist_atomically(path, root.get(), format);
        return true;
    }

#endif

} // namespace

NetworkPreferencesResult ensure_network_preferences(
    const std::filesystem::path& rootfs,
    std::optional<NetworkPreferencesAirport> airport_configuration)
{
    NetworkPreferencesResult result;
    const RootfsPathResolver resolver { rootfs };
    result.path = resolver.resolve(
        "/Library/Preferences/SystemConfiguration/preferences.plist");

#if defined(SHADE_HAS_LIBPLIST)
    result.supported = true;
    result.preferred_wifi_networks = preferred_wifi_networks(resolver);
    bool wifi_capability_changed = false;
    if (airport_configuration)
        wifi_capability_changed = ensure_wifi_capability_preferences(resolver);
    auto bytes = read_file(result.path);
    plist_t parsed = nullptr;
    plist_format_t format = PLIST_FORMAT_XML;
    if (!bytes.empty()) {
        if (bytes.size() > std::numeric_limits<std::uint32_t>::max() ||
            plist_from_memory(bytes.data(),
                static_cast<std::uint32_t>(bytes.size()), &parsed,
                &format) != PLIST_ERR_SUCCESS ||
            parsed == nullptr || plist_get_node_type(parsed) != PLIST_DICT) {
            if (parsed != nullptr)
                plist_free(parsed);
            throw std::runtime_error { "could not parse network preferences: " +
                                       result.path.string() };
        }
    } else {
        parsed = plist_new_dict();
        format = PLIST_FORMAT_XML;
    }
    PlistOwner root { parsed };

    bool changed = bytes.empty();
    const auto set_identifier = current_set_identifier(root.get());
    ensure_string(root.get(), "CurrentSet", "/Sets/" + set_identifier, changed);
    const auto sets = ensure_dictionary(root.get(), "Sets", changed);
    const auto set = ensure_dictionary(sets, set_identifier.c_str(), changed);
    ensure_string(set, "UserDefinedName", "Automatic", changed);
    const auto network = ensure_dictionary(set, "Network", changed);
    const auto global = ensure_dictionary(network, "Global", changed);
    const auto global_ipv4 = ensure_dictionary(global, "IPv4", changed);
    const auto service_order =
        ensure_array(global_ipv4, "ServiceOrder", changed);
    const auto service_links = ensure_dictionary(network, "Service", changed);
    const auto interfaces = ensure_dictionary(network, "Interface", changed);

    if (airport_configuration) {
        const auto& airport_configuration_value = *airport_configuration;
        const auto services =
            ensure_dictionary(root.get(), "NetworkServices", changed);
        const auto airport_services = find_airport_services(
            services, airport_configuration_value.interface_name);
        auto service_identifier = preferred_airport_service(airport_services);
        if (service_identifier.empty())
            service_identifier = std::string { default_service_identifier };
        for (const auto& candidate : airport_services) {
            if (!candidate.managed ||
                candidate.identifier == service_identifier) {
                continue;
            }
            plist_dict_remove_item(services, candidate.identifier.c_str());
            remove_service_links(root.get(), candidate.identifier, changed);
            changed = true;
        }
        result.service_identifier = service_identifier;

        const auto service =
            ensure_dictionary(services, service_identifier.c_str(), changed);
        const auto airport = ensure_dictionary(service, "AirPort", changed);
        ensure_string(airport, "MACAddress",
            mac_address_string(airport_configuration_value.mac_address),
            changed);
        const auto ipv4 = ensure_dictionary(service, "IPv4", changed);
        if (!bool_value(
                plist_dict_get_item(service, managed_service_key.data()))) {
            ensure_string(ipv4, "ConfigMethod", "Manual", changed);
            ensure_string_array(ipv4, "Addresses",
                { ipv4_address_string(
                    airport_configuration_value.ipv4.address) },
                changed);
            ensure_string_array(ipv4, "SubnetMasks",
                { ipv4_address_string(
                    airport_configuration_value.ipv4.netmask) },
                changed);
            ensure_string(ipv4, "Router",
                ipv4_address_string(airport_configuration_value.ipv4.gateway),
                changed);
            std::vector<std::string> dns_servers;
            dns_servers.reserve(
                airport_configuration_value.ipv4.dns_servers.size());
            for (const auto& address :
                airport_configuration_value.ipv4.dns_servers) {
                dns_servers.push_back(ipv4_address_string(address));
            }
            const auto dns = ensure_dictionary(service, "DNS", changed);
            ensure_string_array(dns, "ServerAddresses", dns_servers, changed);
            ensure_bool(service, managed_service_key.data(), true, changed);
        }
        const auto interface = ensure_dictionary(service, "Interface", changed);
        ensure_string(interface, "DeviceName",
            airport_configuration_value.interface_name, changed);
        ensure_string(interface, "Hardware", "AirPort", changed);
        ensure_string(interface, "Type", "Ethernet", changed);
        static_cast<void>(ensure_dictionary(service, "Proxies", changed));
        ensure_string(service, "UserDefinedName", "AirPort", changed);

        if (!array_contains_string(service_order, service_identifier)) {
            plist_array_append_item(
                service_order, plist_new_string(service_identifier.c_str()));
            changed = true;
        }
        const auto service_link = ensure_dictionary(
            service_links, service_identifier.c_str(), changed);
        ensure_string(service_link, "__LINK__",
            "/NetworkServices/" + service_identifier, changed);
        const std::string owned_interface_name {
            airport_configuration_value.interface_name
        };
        const auto interface_preferences = ensure_dictionary(
            interfaces, owned_interface_name.c_str(), changed);
        const auto airport_preferences =
            ensure_dictionary(interface_preferences, "AirPort", changed);
        ensure_uint(airport_preferences, "AllowEnable", 1, changed);
        ensure_string(airport_preferences, "JoinMode", "Automatic", changed);
    }

    result.changed = changed || wifi_capability_changed;
    if (changed)
        write_plist_atomically(result.path, root.get(), format);
#else
    static_cast<void>(airport_configuration);
#endif
    return result;
}

} // namespace shade
