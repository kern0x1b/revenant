// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "diagnostic_data.hpp"

#include "kernel/kernel_shared_state.hpp"

#include <algorithm>
#include <array>
#include <string>
#include <vector>

namespace shade::kernel_iokit {

std::uint32_t DiagnosticDataService::ensure_locked(KernelSharedState& state)
{
    const auto existing = std::find_if(state.iokit_services.begin(),
        state.iokit_services.end(), [](const auto& entry) {
            return entry.second.class_name == service_class;
        });
    if (existing != state.iokit_services.end())
        return existing->first;

    // ARM SysCfg starts with six little-endian words; the final word is the
    // count of 20-byte key records. An empty store is valid and cacheable by
    // MobileGestalt, unlike an absent driver that must await publication on
    // every query. Do not invent manufacturing identity or calibration keys.
    constexpr std::array<std::uint32_t, 6> header {
        0x53436667U, 24U, 0U, 1U, 0U, 0U
    };
    std::vector<std::byte> data;
    data.reserve(sizeof(header));
    for (const auto word : header) {
        for (unsigned shift = 0; shift < 32U; shift += 8U)
            data.push_back(static_cast<std::byte>(word >> shift));
    }

    const auto object = state.allocate_mach_object();
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    KernelSharedState::IOKitService service {
        std::string { service_class }, { "IOService" }, { },
        "IOService:/AppleDiagnosticDataAccessReadOnly",
        state.iokit_registry_root_object
    };
    service.properties.emplace("AppleDiagnosticDataSysCfg",
        KernelSharedState::IOKitRegistryProperty {
            KernelSharedState::IOKitRegistryProperty::Kind::Data,
            std::move(data) });
    state.iokit_services.emplace(object, std::move(service));
    return object;
}

} // namespace shade::kernel_iokit
