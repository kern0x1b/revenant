// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose virtual battery and power-source registry properties.

#include "battery.hpp"

#include "kernel/kernel_shared_state.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <map>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace shade::kernel_iokit::battery {
namespace {

    constexpr std::string_view io_service_class { "IOService" };
    constexpr std::string_view registry_path {
        "IOService:/IOPower:/IOPowerConnection/IOPMrootDomain/IOPMPowerSource"
    };
    constexpr std::uint32_t default_capacity_percent = 100U;

    std::vector<std::byte> bytes_from_string(std::string_view value)
    {
        std::vector<std::byte> bytes(value.size());
        std::transform(value.begin(), value.end(), bytes.begin(),
            [](char character) { return static_cast<std::byte>(character); });
        return bytes;
    }

    KernelSharedState::IOKitRegistryProperty string_property(
        std::string_view value)
    {
        return { KernelSharedState::IOKitRegistryProperty::Kind::String,
            bytes_from_string(value) };
    }

    KernelSharedState::IOKitRegistryProperty number_property(
        std::uint32_t value)
    {
        std::vector<std::byte> bytes(sizeof(value));
        for (std::size_t index = 0; index < bytes.size(); ++index)
            bytes[index] = static_cast<std::byte>(value >> (index * 8U));
        return { KernelSharedState::IOKitRegistryProperty::Kind::Number,
            std::move(bytes) };
    }

    KernelSharedState::IOKitRegistryProperty boolean_property(bool value)
    {
        return { KernelSharedState::IOKitRegistryProperty::Kind::Boolean,
            { value ? std::byte { 1 } : std::byte { 0 } } };
    }

} // namespace

bool matches_service(std::span<const std::byte> matching)
{
    return std::search(matching.begin(), matching.end(), service_class.begin(),
               service_class.end(), [](std::byte byte, char character) {
                   return std::to_integer<unsigned char>(byte) ==
                          static_cast<unsigned char>(character);
               }) != matching.end();
}

std::uint32_t ensure_service_locked(KernelSharedState& state)
{
    const auto existing = std::find_if(state.iokit_services.begin(),
        state.iokit_services.end(), [](const auto& entry) {
            return entry.second.class_name == service_class;
        });
    if (existing != state.iokit_services.end())
        return existing->first;

    const auto object = state.allocate_mach_object();
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);

    std::map<std::string, KernelSharedState::IOKitRegistryProperty> properties;
    properties.emplace("built-in", boolean_property(true));
    properties.emplace(
        "Current Capacity", number_property(default_capacity_percent));
    properties.emplace(
        "Max Capacity", number_property(default_capacity_percent));
    // IOPowerSources normalizes the registry names above to the compact keys
    // consumed by PowerManagement and SpringBoard. Publish both forms because
    // the older firmware calls both the raw registry and normalized paths.
    properties.emplace(
        "CurrentCapacity", number_property(default_capacity_percent));
    properties.emplace(
        "MaxCapacity", number_property(default_capacity_percent));
    properties.emplace("ExternalConnected", boolean_property(false));
    properties.emplace("IsCharging", boolean_property(false));
    properties.emplace("TimeRemaining", number_property(0));
    properties.emplace("Amperage", number_property(0));
    properties.emplace("Type", string_property("InternalBattery"));
    properties.emplace("Name", string_property("InternalBattery-0"));
    properties.emplace("Transport Type", string_property("InternalBattery"));

    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { std::string { io_service_class } }, std::move(properties),
            std::string { registry_path }, state.iokit_registry_root_object });
    return object;
}

} // namespace shade::kernel_iokit::battery
