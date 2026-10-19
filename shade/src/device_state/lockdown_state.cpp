// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Read and update the configured guest Lockdown activation state.

#include "device_state/lockdown_state.hpp"

#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <string>

#include "foundation/macho.hpp"

#if defined(SHADE_HAS_LIBPLIST)
#include <cstdlib>
#include <plist/plist.h>
#endif

namespace shade {
namespace {

    constexpr std::string_view activation_state_key { "-ActivationState" };
    constexpr std::string_view activation_acknowledged_key {
        "-ActivationStateAcknowledged"
    };
    constexpr std::string_view springboard_registered_key {
        "-SBLockdownEverRegisteredKey"
    };
    constexpr std::string_view cached_activation_state_key {
        "com.apple.mobile.lockdown_cache-ActivationState"
    };
    constexpr std::string_view persisted_brick_state_key { "-BrickState" };
    constexpr std::string_view springboard_path {
        "System/Library/CoreServices/SpringBoard.app/SpringBoard"
    };
    constexpr std::string_view brick_state_symbol { "_kLockdownBrickStateKey" };

    std::string initial_plist()
    {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
               "<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST "
               "1.0//EN\" "
               "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
               "<plist version=\"1.0\">\n<dict>\n</dict>\n</plist>\n";
    }

    std::string read_file(const std::filesystem::path& path)
    {
        if (!std::filesystem::exists(path))
            return initial_plist();
        std::ifstream input { path, std::ios::binary };
        if (!input) {
            throw std::runtime_error { "could not read Lockdown state: " +
                                       path.string() };
        }
        return { std::istreambuf_iterator<char> { input },
            std::istreambuf_iterator<char> { } };
    }

    void write_file_atomically(
        const std::filesystem::path& path, std::string_view content)
    {
        std::filesystem::create_directories(path.parent_path());
        auto temporary = path;
        temporary += ".shade.tmp";
        {
            std::ofstream output { temporary,
                std::ios::binary | std::ios::trunc };
            if (!output || !output.write(content.data(),
                               static_cast<std::streamsize>(content.size()))) {
                throw std::runtime_error { "could not write Lockdown state: " +
                                           temporary.string() };
            }
        }
        std::filesystem::rename(temporary, path);
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
        plist_dict_set_item(
            parent, key, plist_new_string(std::string { value }.c_str()));
        changed = true;
    }

    void ensure_bool(plist_t parent, const char* key, bool value, bool& changed)
    {
        const auto node = plist_dict_get_item(parent, key);
        if (node != nullptr && plist_get_node_type(node) == PLIST_BOOLEAN) {
            std::uint8_t current { };
            plist_get_bool_val(node, &current);
            if ((current != 0) == value)
                return;
        }
        plist_dict_set_item(parent, key, plist_new_bool(value ? 1U : 0U));
        changed = true;
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
            throw std::runtime_error { "could not serialize Lockdown state" };
        }
        write_file_atomically(path, { serialized, length });
        std::free(serialized);
    }
#endif

    [[maybe_unused]] std::size_t value_end(
        const std::string& xml, std::size_t begin)
    {
        if (xml.compare(begin, 7, "<true/>") == 0)
            return begin + 7;
        if (xml.compare(begin, 8, "<false/>") == 0)
            return begin + 8;
        const auto tag_end = xml.find('>', begin);
        if (tag_end == std::string::npos || xml[begin] != '<') {
            throw std::runtime_error { "malformed Lockdown data_ark value" };
        }
        const auto name_end = xml.find_first_of(" >", begin + 1);
        if (name_end == std::string::npos || name_end > tag_end) {
            throw std::runtime_error { "malformed Lockdown data_ark tag" };
        }
        const auto closing =
            "</" + xml.substr(begin + 1, name_end - begin - 1) + ">";
        const auto end = xml.find(closing, tag_end + 1);
        if (end == std::string::npos) {
            throw std::runtime_error { "unterminated Lockdown data_ark value" };
        }
        return end + closing.size();
    }

    [[maybe_unused]] void upsert(
        std::string& xml, std::string_view key, std::string_view encoded_value)
    {
        const auto encoded_key = "<key>" + std::string { key } + "</key>";
        const auto key_position = xml.find(encoded_key);
        if (key_position == std::string::npos) {
            const auto dictionary_end = xml.rfind("</dict>");
            if (dictionary_end == std::string::npos) {
                throw std::runtime_error {
                    "Lockdown data_ark has no dictionary"
                };
            }
            const auto entry = "\t" + encoded_key + "\n\t" +
                               std::string { encoded_value } + "\n";
            xml.insert(dictionary_end, entry);
            return;
        }
        const auto value_begin =
            xml.find('<', key_position + encoded_key.size());
        if (value_begin == std::string::npos) {
            throw std::runtime_error { "Lockdown data_ark key has no value" };
        }
        xml.replace(value_begin, value_end(xml, value_begin) - value_begin,
            encoded_value);
    }

} // namespace

std::optional<LockdownActivation> parse_lockdown_activation(
    std::string_view value)
{
    if (value == "preserve")
        return LockdownActivation::Preserve;
    if (value == "activated")
        return LockdownActivation::Activated;
    if (value == "unactivated")
        return LockdownActivation::Unactivated;
    return std::nullopt;
}

LockdownCapabilities detect_lockdown_capabilities(
    const std::filesystem::path& rootfs, ArmArchitectureVersion architecture)
{
    LockdownCapabilities profile;
    // Early prototype firmware can own a different UI process and legitimately
    // omit SpringBoard altogether.  The profile fields below are optional
    // capabilities discovered from the image; absence of that capability must
    // not make an otherwise bootable root filesystem fail before its loader has
    // started.  Keep the default profile (registration state only) for such
    // firmware, while retaining strict Mach-O parsing when the image exists.
    const auto image_path = rootfs / springboard_path;
    std::error_code status_error;
    if (!std::filesystem::is_regular_file(image_path, status_error) ||
        status_error) {
        return profile;
    }
    const auto image = MachOImage::parse(image_path, architecture);
    profile.brick_state = image.find_symbol(brick_state_symbol) != nullptr;
    return profile;
}

LockdownStateUpdate apply_lockdown_state(
    const std::filesystem::path& rootfs, LockdownActivation activation,
    const LockdownCapabilities& profile)
{
    const auto path =
        rootfs / "private/var/root/Library/Lockdown/data_ark.plist";
    if (activation == LockdownActivation::Preserve)
        return { path, false };

#if defined(SHADE_HAS_LIBPLIST)
    const auto content = read_file(path);
    plist_t parsed = nullptr;
    plist_format_t format = PLIST_FORMAT_XML;
    if (plist_from_memory(content.data(),
            static_cast<std::uint32_t>(content.size()), &parsed,
            &format) != PLIST_ERR_SUCCESS ||
        parsed == nullptr || plist_get_node_type(parsed) != PLIST_DICT) {
        if (parsed != nullptr)
            plist_free(parsed);
        parsed = plist_new_dict();
        format = PLIST_FORMAT_XML;
    }
    PlistOwner root { parsed };
    bool changed = false;
    const auto activated = activation == LockdownActivation::Activated;

    ensure_string(root.get(), activation_state_key.data(),
        activated ? "Activated" : "Unactivated", changed);
    ensure_bool(
        root.get(), activation_acknowledged_key.data(), activated, changed);
    if (profile.registration_state) {
        ensure_string(
            root.get(), springboard_registered_key.data(), "0", changed);
    }
    if (profile.brick_state) {
        ensure_bool(
            root.get(), persisted_brick_state_key.data(), !activated, changed);
    }
    ensure_string(root.get(), cached_activation_state_key.data(),
        activated ? "Activated" : "Unactivated", changed);
    if (changed)
        write_plist_atomically(path, root.get(), format);
    return { path, changed };
#else
    auto xml = read_file(path);
    const auto original = xml;
    const auto activated = activation == LockdownActivation::Activated;
    upsert(xml, activation_state_key,
        activated ? "<string>Activated</string>"
                  : "<string>Unactivated</string>");
    upsert(
        xml, activation_acknowledged_key, activated ? "<true/>" : "<false/>");
    if (profile.registration_state) {
        // This is cellular-network registration history, not device
        // activation. The default offline modem has never registered; a real
        // or replayed baseband remains free to update the firmware-owned key.
        // SpringBoard stores and parses this value as a decimal CFString.
        upsert(xml, springboard_registered_key, "<string>0</string>");
    }
    if (profile.brick_state) {
        // Later Lockdown profiles persist the repair-mode bit independently
        // of ActivationState. Keep both sides of that firmware-owned state in
        // agreement; the runtime query adapter remains authoritative after
        // boot if the emulated baseband refreshes its cache.
        upsert(
            xml, persisted_brick_state_key, activated ? "<false/>" : "<true/>");
    }
    // lockdownd publishes its effective state through this persisted cache.
    // Keep it in sync with the requested device profile so a prior offline
    // baseband boot cannot override --activation on the next launch.
    upsert(xml, cached_activation_state_key,
        activated ? "<string>Activated</string>"
                  : "<string>Unactivated</string>");
    if (xml == original)
        return { path, false };

    write_file_atomically(path, xml);
    return { path, true };
#endif
}

} // namespace shade
