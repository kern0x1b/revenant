// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual keybag requests using persistent device key state.

#include "kernel/kernel_iokit_keybag.hpp"

#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "crypto/key_store.hpp"

#include <algorithm>
#include <mutex>
#include <string>

namespace shade::kernel_iokit::keybag {
namespace {

    constexpr std::string_view registry_path {
        "IOService:/IOResources/AppleKeyStore"
    };
    constexpr std::string_view effaceable_storage_registry_path {
        "IOService:/AppleEffaceableStorage"
    };
    constexpr std::uint32_t init_user_client_selector = 0U;
    constexpr std::uint32_t get_keybag_lock_state_selector = 7U;
    constexpr std::uint32_t get_device_lock_state_selector = 17U;
    constexpr std::uint32_t get_system_keybag_selector = 14U;
    constexpr std::uint32_t copy_keybag_uuid_selector = 23U;
    constexpr std::uint32_t load_blastable_bytes_selector = 5U;
    constexpr std::uint32_t store_blastable_bytes_selector = 6U;
    // MobileKeyBag treats device state 3 as an unlocked device with no
    // passcode. State 0 means a passcode exists but the device is currently
    // unlocked, so returning zero for a fresh virtual data volume incorrectly
    // sends the firmware through passcode entry.
    constexpr std::uint64_t device_lock_state_no_passcode = 3U;
    // AppleKeyStoreGetLockState bit 2 records that the selected bag has been
    // unlocked since boot. A no-passcode virtual system bag is always in that
    // state.
    constexpr std::uint64_t keybag_unlocked_since_boot = 1U << 2U;

    bool matches_class(std::span<const std::byte> matching,
        std::string_view class_name)
    {
        return std::search(matching.begin(), matching.end(), class_name.begin(),
                   class_name.end(), [](std::byte byte, char character) {
                       return std::to_integer<unsigned char>(byte) ==
                              static_cast<unsigned char>(character);
                   }) != matching.end();
    }

    void ensure_device_tree_defaults_locked(KernelSharedState& state)
    {
        if (state.effaceable_storage_available ||
            !state.virtual_effaceable_storage_available) {
            return;
        }
        const auto create_node = [&state](std::string_view path,
                                          std::uint32_t& node_slot) {
            if (node_slot != 0) {
                return;
            }
            const auto object = state.allocate_mach_object();
            node_slot = object;
            static_cast<void>(state.mach_port_objects.create(object));
            state.mach_queues.try_emplace(object);
            state.iokit_services.emplace(object,
                KernelSharedState::IOKitService {
                    "IODeviceTree", { },
                    { { "no-effaceable-storage",
                        KernelSharedState::IOKitRegistryProperty {
                            KernelSharedState::IOKitRegistryProperty::Kind::
                                Boolean,
                            { std::byte { 1 } } } } },
                    std::string { path } });
        };
        create_node("IODeviceTree:/defaults",
            state.keybag_device_tree_defaults_service);
        create_node("IODeviceTree:/options",
            state.keybag_device_tree_options_service);
    }

} // namespace

bool matches_service(std::span<const std::byte> matching)
{
    return matches_class(matching, service_class);
}

bool matches_effaceable_storage_service(std::span<const std::byte> matching)
{
    return matches_class(matching, effaceable_storage_service_class);
}

std::uint32_t ensure_service_locked(KernelSharedState& state,
    std::uint32_t parent_object)
{
    ensure_device_tree_defaults_locked(state);
    if (state.apple_key_store_service != 0)
        return state.apple_key_store_service;
    const auto object = state.allocate_mach_object();
    state.apple_key_store_service = object;
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { "IOService" }, { }, std::string { registry_path },
            parent_object,
            KernelSharedState::IOKitUserClientKind::AppleKeyStore });
    return object;
}

std::uint32_t ensure_effaceable_storage_service_locked(
    KernelSharedState& state, std::uint32_t parent_object)
{
    if (state.effaceable_storage_service != 0)
        return state.effaceable_storage_service;
    ensure_device_tree_defaults_locked(state);
    const auto object = state.allocate_mach_object();
    state.effaceable_storage_service = object;
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService {
            std::string { effaceable_storage_service_class },
            { "IOService" }, { },
            std::string { effaceable_storage_registry_path }, parent_object,
            KernelSharedState::IOKitUserClientKind::AppleEffaceableStorage
        });
    return object;
}

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, std::uint32_t connection_object,
    std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity, std::uint32_t inband_output_capacity)
{
    std::lock_guard lock { state.mach_mutex };
    const auto connection = state.iokit_connections.find(connection_object);
    if (connection == state.iokit_connections.end() ||
        connection->second.owner_pid != process.pid) {
        return std::nullopt;
    }
    const auto service =
        state.iokit_services.find(connection->second.service_port);
    if (service == state.iokit_services.end() ||
        service->second.user_client_kind !=
            KernelSharedState::IOKitUserClientKind::AppleKeyStore) {
        return std::nullopt;
    }
    if (selector == init_user_client_selector && scalar_input.empty() &&
        inband_input.empty() && scalar_output_capacity == 0U &&
        inband_output_capacity == 0U) {
        return MethodResult { iokit_abi::success, { }, { } };
    }
    // The kernel key store owns the live system-bag handle. User space only
    // falls back to deserializing /private/var/keybags/systembag.kb when the
    // kernel reports that no handle exists; on a restored data volume without
    // that persistence file, keybagd treats the fallback failure as fatal and
    // requests a reboot. Lazily provision the virtual kernel handle so the
    // firmware can follow its normal already-loaded path without synthesizing
    // or modifying guest keybag files.
    if (selector == get_system_keybag_selector && scalar_input.empty() &&
        inband_input.empty() && scalar_output_capacity >= 1U &&
        inband_output_capacity == 0U) {
        if (state.system_keybag_handle == 0)
            state.system_keybag_handle = state.next_keybag_handle++;
        return MethodResult { iokit_abi::success,
            { state.system_keybag_handle }, { } };
    }
    if (selector == 6U && scalar_input.empty() && !inband_input.empty() &&
        scalar_output_capacity >= 1U && inband_output_capacity == 0U) {
        const auto handle = state.next_keybag_handle++;
        return MethodResult { iokit_abi::success, { handle }, { } };
    }
    if (selector == 5U && scalar_input.size() == 1U &&
        inband_input.empty() && scalar_output_capacity == 0U &&
        inband_output_capacity == 0U && scalar_input.front() != 0) {
        state.system_keybag_handle = scalar_input.front();
        return MethodResult { iokit_abi::success, { }, { } };
    }
    if (selector == 4U && scalar_input.size() == 1U &&
        inband_input.empty() && scalar_output_capacity == 0U &&
        inband_output_capacity == 0U) {
        return MethodResult { iokit_abi::success, { }, { } };
    }
    if (selector == get_keybag_lock_state_selector &&
        scalar_input.size() == 1U &&
        inband_input.empty() && scalar_output_capacity >= 1U &&
        inband_output_capacity == 0U) {
        return MethodResult {
            iokit_abi::success, { keybag_unlocked_since_boot }, { } };
    }
    if (selector == get_device_lock_state_selector && scalar_input.empty() &&
        inband_input.empty() && scalar_output_capacity >= 1U &&
        inband_output_capacity == 0U) {
        return MethodResult {
            iokit_abi::success, { device_lock_state_no_passcode }, { } };
    }
    if (selector == copy_keybag_uuid_selector) {
        constexpr std::uint32_t uuid_size = 16U;
        if (scalar_input.size() != 1U || !inband_input.empty() ||
            scalar_output_capacity != 0U || inband_output_capacity < uuid_size)
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        // Handles allocated by this store are positive. Zero aliases the
        // system bag; unregistered special bags and unknown handles do not
        // exist. Native MobileKeyBag distinguishes absence from unsupported
        // UUID export and can safely skip cleanup of an unregistered bag.
        const auto handle = scalar_input.front();
        const bool known = handle == 0U ||
                           handle == state.system_keybag_handle ||
                           (handle > 0U && handle < state.next_keybag_handle);
        if (!known)
            return MethodResult { iokit_abi::not_found, { }, { } };
    }
    // AppleKeyStore's symmetric system-bag ABI uses selectors 10/11 for
    // authenticated wrapping/unwrapping. The no-passcode model already exposes
    // unlocked class keys; retain firmware ownership of keychain records.
    if ((selector == 10U || selector == 11U) && state.key_store) {
        if (scalar_input.size() != 2U || scalar_output_capacity != 0U ||
            scalar_input[1] < 1U || scalar_input[1] > 11U ||
            (scalar_input[0] != 0U &&
                scalar_input[0] != state.system_keybag_handle))
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        const auto key_class = static_cast<std::uint32_t>(scalar_input[1]);
        auto result = selector == 10U
                          ? state.key_store->wrap(key_class, inband_input)
                          : state.key_store->unwrap(key_class, inband_input);
        if (!result)
            return MethodResult { 0xe00002bcU, { }, { } };
        if (result->size() > inband_output_capacity)
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        return MethodResult { iokit_abi::success, { }, std::move(*result) };
    }
    // Keep the remaining endpoint honest while the firmware-era method
    // contract is being filled in: this exposes selector and argument shape
    // through the normal IOKit result without fabricating a key or lock-state
    // transition.
    return MethodResult { iokit_abi::unsupported, { }, { } };
}

std::optional<MethodResult> dispatch_effaceable_storage_connect_method(
    KernelSharedState& state, const ProcessContext& process,
    std::uint32_t connection_object, std::uint32_t selector,
    std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity,
    std::uint32_t inband_output_capacity)
{
    std::lock_guard lock { state.mach_mutex };
    const auto connection = state.iokit_connections.find(connection_object);
    if (connection == state.iokit_connections.end() ||
        connection->second.owner_pid != process.pid) {
        return std::nullopt;
    }
    const auto service = state.iokit_services.find(connection->second.service_port);
    if (service == state.iokit_services.end() ||
        service->second.user_client_kind !=
            KernelSharedState::IOKitUserClientKind::AppleEffaceableStorage) {
        return std::nullopt;
    }
    if (selector == load_blastable_bytes_selector &&
        scalar_input.size() == 1U && inband_input.empty() &&
        scalar_output_capacity >= 1U &&
        inband_output_capacity >= state.effaceable_storage_blob.size()) {
        return MethodResult { iokit_abi::success, { 0 },
            { state.effaceable_storage_blob.begin(),
                state.effaceable_storage_blob.end() } };
    }
    if (selector == store_blastable_bytes_selector &&
        scalar_input.size() == 1U &&
        inband_input.size() == state.effaceable_storage_blob.size() &&
        scalar_output_capacity == 0U && inband_output_capacity == 0U) {
        std::copy(inband_input.begin(), inband_input.end(),
            state.effaceable_storage_blob.begin());
        return MethodResult { iokit_abi::success, { }, { } };
    }
    return MethodResult { iokit_abi::unsupported, { }, { } };
}

} // namespace shade::kernel_iokit::keybag
