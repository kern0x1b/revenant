// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Publish profile-driven environmental sensor registry services.

#include "environment.hpp"

#include "kernel/kernel_shared_state.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <map>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace shade::kernel_iokit::environment {
namespace {

    constexpr std::string_view io_service_class { "IOService" };
    bool contains(std::span<const std::byte> bytes, std::string_view value)
    {
        return std::search(bytes.begin(), bytes.end(), value.begin(),
                   value.end(), [](std::byte byte, char character) {
                       return std::to_integer<unsigned char>(byte) ==
                              static_cast<unsigned char>(character);
                   }) != bytes.end();
    }

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

} // namespace

bool matches_service(
    std::span<const std::byte> matching, const KernelSharedState& state)
{
    return !state.ambient_light_sensor.service_class.empty() &&
           contains(matching, state.ambient_light_sensor.service_class);
}

std::uint32_t ensure_service_locked(KernelSharedState& state)
{
    const auto service_class = state.ambient_light_sensor.service_class;
    const auto existing = std::find_if(state.iokit_services.begin(),
        state.iokit_services.end(), [service_class](const auto& entry) {
            return entry.second.class_name == service_class;
        });
    if (existing != state.iokit_services.end())
        return existing->first;

    const auto object = state.allocate_mach_object();
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);

    std::map<std::string, KernelSharedState::IOKitRegistryProperty> properties;
    properties.emplace("Product", string_property("ambient"));
    properties.emplace("ALSCh0Gain",
        number_property(state.ambient_light_sensor.channel0_gain));
    properties.emplace("ALSCh1Gain",
        number_property(state.ambient_light_sensor.channel1_gain));
    properties.emplace("ALSIntegrationCycles",
        number_property(state.ambient_light_sensor.integration_cycles));
    properties.emplace("PrimaryUsagePage", number_property(0x01U));
    properties.emplace("PrimaryUsage", number_property(0x04U));

    std::string registry_path { "IOService:/" };
    registry_path += service_class;
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { std::string { io_service_class } }, std::move(properties),
            std::move(registry_path), state.iokit_registry_root_object });
    return object;
}

} // namespace shade::kernel_iokit::environment
