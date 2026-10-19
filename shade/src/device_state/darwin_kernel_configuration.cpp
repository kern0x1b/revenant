// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve device and firmware evidence into a session's Darwin ABI
// configuration.

#include "device_state/darwin_kernel_configuration.hpp"

#include "darwin_firmware_identity.hpp"

#include <algorithm>
#include <array>
#include <stdexcept>

namespace shade {
namespace {

    constexpr DarwinAbi disk_policy_abi {
        .abi_epoch = DarwinAbiEpoch::IphoneOs2,
        .activation_hardware_model_policy =
            ActivationHardwareModelPolicy::DevelopmentBoard,
        .capabilities = { .send_sigsys = true },
    };

    constexpr DarwinAbi darwin11_wide_vm_abi {
        .abi_epoch = DarwinAbiEpoch::Darwin11,
        .pthread_abi =
            DarwinPthreadAbi::BsdThreadRegisterV1TsdBaseFourPriorityWorkqueues,
        .apple80211_ioctl =
            DarwinApple80211IoctlAbi::CompactCurrentNetworkRecord,
        .io_connect_method =
            DarwinIOConnectMethodAbi::MachVm64OolStructureThenScalar,
        .mach_vm_address = DarwinMachVmAddressWidth::Wide64,
        .initial_apple_vector_abi =
            DarwinInitialAppleVectorAbi::LegacyExecutablePath,
        .shared_region_abi =
            DarwinSharedRegionAbi::FixedMappingsWithSlideInfoV1,
        .mach_kernel_rpc = DarwinMachKernelRpcAbi::DirectVmAndPortTrapsV1,
        .psynch_abi = DarwinPsynchAbi::Arm32GenerationV1,
        .semaphore_wait_abi = DarwinSemaphoreWaitAbi::InlineSeconds64,
        .stack_snapshot_abi = DarwinStackSnapshotAbi::LegacyFourArguments,
        .iokit_matching_rpc = DarwinIOKitMatchingRpcAbi::InlineSingleServiceV1,
        .capabilities = { .send_sigsys = true },
    };

    constexpr DarwinAbi darwin11_wide_vm_high_vectors_abi = [] {
        auto abi = darwin11_wide_vm_abi;
        abi.arm_commpage = DarwinArmCommpageAbi::HighAddress;
        return abi;
    }();

    // Darwin 13 keeps the audited wide-VM wire contracts and the high-address
    // commpage. Keep the profile separate so later Darwin revisions can
    // evolve their contracts without making this compatibility boundary
    // depend on a firmware build string.
    constexpr DarwinAbi darwin13_wide_vm_high_commpage_abi = [] {
        auto abi = darwin11_wide_vm_high_vectors_abi;
        abi.abi_epoch = DarwinAbiEpoch::Darwin13;
        abi.sandbox_abi = DarwinSandboxAbi::Wide64Arguments;
        abi.mach_port_context = DarwinMachVmAddressWidth::Wide64;
        abi.memory_status_priority = DarwinMemoryStatusPriorityAbi::SignedPriority;
        abi.hid_digitizer = DarwinHidDigitizerAbi::ChildContactChanges;
        abi.iokit_matching_rpc =
            DarwinIOKitMatchingRpcAbi::InlineSingleServiceAfterVariableOutput;
        return abi;
    }();

    // Release identity and ABI values are independent. Entries sharing a
    // Darwin release retain the wire differences required by their callers.
    constexpr std::array configurations {
        DarwinConfigurationEntry {
            .name = "darwin9.0.0d1",
            .darwin_release = "9.0.0d1",
            .abi = {
                .abi_epoch = DarwinAbiEpoch::IphoneOs1,
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::DevelopmentBoard,
                .capabilities = {
                    .send_sigsys = true,
                    .arm_cache_trap_grants_execute = true,
                },
            },
        },
        DarwinConfigurationEntry {
            .name = "darwin9.3.1",
            .darwin_release = "9.3.1",
            .abi = disk_policy_abi,
        },
        DarwinConfigurationEntry {
            .name = "darwin9.4.1",
            .darwin_release = "9.4.1",
            .abi = disk_policy_abi,
        },
        DarwinConfigurationEntry {
            .name = "darwin10.0.0d3",
            .darwin_release = "10.0.0d3",
            .abi = {
                .abi_epoch = DarwinAbiEpoch::IphoneOs3,
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::DevelopmentBoard,
                .capabilities = { .send_sigsys = true },
            },
        },
        DarwinConfigurationEntry {
            .name = "darwin10.3.1-bootstrap-notify",
            .darwin_release = "10.3.1",
            .abi = {
                .abi_epoch = DarwinAbiEpoch::Darwin10,
                .pthread_abi = DarwinPthreadAbi::BsdThreadRegisterV1,
                .apple80211_ioctl =
                    DarwinApple80211IoctlAbi::CompactCurrentNetworkRecord,
                .notify_state_abi =
                    DarwinNotifyStateAbi::BootstrapAwareServerTokens,
                .psynch_abi = DarwinPsynchAbi::Arm32GenerationV1,
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::DevelopmentBoard,
                .capabilities = { .send_sigsys = true },
            },
        },
        DarwinConfigurationEntry {
            .name = "darwin10.3.1-native-notify",
            .darwin_release = "10.3.1",
            .abi = {
                .abi_epoch = DarwinAbiEpoch::Darwin10,
                .pthread_abi = DarwinPthreadAbi::BsdThreadRegisterV1,
                .apple80211_ioctl =
                    DarwinApple80211IoctlAbi::CompactCurrentNetworkRecord,
                .initial_apple_vector_abi =
                    DarwinInitialAppleVectorAbi::LegacyExecutablePath,
                .psynch_abi = DarwinPsynchAbi::Arm32GenerationV1,
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::DevelopmentBoard,
                .capabilities = { .send_sigsys = true },
            },
        },
        DarwinConfigurationEntry {
            .name = "darwin10.4.0",
            .darwin_release = "10.4.0",
            .abi = {
                .abi_epoch = DarwinAbiEpoch::Darwin10,
                .pthread_abi = DarwinPthreadAbi::BsdThreadRegisterV1TsdBase,
                .apple80211_ioctl =
                    DarwinApple80211IoctlAbi::CompactCurrentNetworkRecord,
                .initial_apple_vector_abi =
                    DarwinInitialAppleVectorAbi::LegacyExecutablePath,
                .psynch_abi = DarwinPsynchAbi::Arm32GenerationV1,
                .semaphore_wait_abi = DarwinSemaphoreWaitAbi::InlineSeconds64,
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::DevelopmentBoard,
                .capabilities = { .send_sigsys = true },
            },
        },
        DarwinConfigurationEntry {
            .name = "darwin11.0.0-inline-iokit",
            .darwin_release = "11.0.0",
            .abi = {
                .abi_epoch = DarwinAbiEpoch::Darwin11,
                .pthread_abi =
                    DarwinPthreadAbi::BsdThreadRegisterV1TsdBaseFourPriorityWorkqueues,
                .apple80211_ioctl =
                    DarwinApple80211IoctlAbi::CompactCurrentNetworkRecord,
                .io_connect_method =
                    DarwinIOConnectMethodAbi::Natural32OolStructureThenScalar,
                .initial_apple_vector_abi =
                    DarwinInitialAppleVectorAbi::LegacyExecutablePath,
                .psynch_abi = DarwinPsynchAbi::Arm32GenerationV1,
                .semaphore_wait_abi = DarwinSemaphoreWaitAbi::InlineSeconds64,
                .stack_snapshot_abi =
                    DarwinStackSnapshotAbi::LegacyFourArguments,
                .iokit_matching_rpc =
                    DarwinIOKitMatchingRpcAbi::InlineSingleServiceV1,
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::DevelopmentBoard,
                .capabilities = { .send_sigsys = true },
            },
        },
        DarwinConfigurationEntry {
            .name = "darwin11.0.0-wide-vm",
            .darwin_release = "11.0.0",
            .abi = darwin11_wide_vm_abi,
        },
        DarwinConfigurationEntry {
            .name = "darwin11.0.0-wide-vm-high-vectors",
            .darwin_release = "11.0.0",
            .abi = darwin11_wide_vm_high_vectors_abi,
        },
        DarwinConfigurationEntry {
            .name = "darwin13.0.0-wide-vm-high-commpage",
            .darwin_release = "13.0.0",
            .abi = darwin13_wide_vm_high_commpage_abi,
        },
        DarwinConfigurationEntry {
            .name = "darwin14.0.0",
            .darwin_release = "14.0.0",
            .abi = {
                .abi_epoch = DarwinAbiEpoch::Later,
                .pthread_abi = DarwinPthreadAbi::
                    BsdThreadRegisterV1ExpandedTsdFourPriorityWorkqueues,
                .io_connect_method =
                    DarwinIOConnectMethodAbi::MachVm64OolStructureThenScalar,
                .mach_vm_address = DarwinMachVmAddressWidth::Wide64,
                .arm_commpage = DarwinArmCommpageAbi::HighDataAddress,
                .initial_apple_vector_abi =
                    DarwinInitialAppleVectorAbi::LegacyExecutablePath,
                .shared_region_abi =
                    DarwinSharedRegionAbi::FixedMappingsWithSlideInfoV1,
                .mach_kernel_rpc =
                    DarwinMachKernelRpcAbi::DirectWideVmAndPortTraps,
                .psynch_abi = DarwinPsynchAbi::Arm32GenerationV1,
                .semaphore_wait_abi = DarwinSemaphoreWaitAbi::InlineSeconds64,
                .iokit_matching_rpc = DarwinIOKitMatchingRpcAbi::
                    InlineSingleServiceAfterVariableOutput,
                .framebuffer_registry =
                    DarwinFramebufferRegistryAbi::UnifiedClcdClass,
                .sandbox_abi = DarwinSandboxAbi::Wide64Arguments,
                .mach_port_context = DarwinMachVmAddressWidth::Wide64,
                .memory_status_priority = DarwinMemoryStatusPriorityAbi::PriorityBands,
                .hid_digitizer = DarwinHidDigitizerAbi::ChildContactChanges,
                .address_layout = DarwinAddressLayout::ExpandedArmSharedRegion,
                .capabilities = { .send_sigsys = true },
            },
        },
    };

    const DarwinConfigurationEntry* find_configuration(std::string_view name)
    {
        const auto found = std::find_if(
            configurations.begin(), configurations.end(),
            [name](const auto& entry) { return entry.name == name; });
        return found == configurations.end() ? nullptr : &*found;
    }

    bool valid_ios_build(std::string_view build)
    {
        constexpr std::string_view digits { "0123456789" };
        const auto branch = build.find_first_not_of(digits);
        if (branch == 0 || branch == std::string_view::npos ||
            build[branch] < 'A' || build[branch] > 'Z')
            return false;
        const auto revision = build.substr(branch + 1);
        if (revision.empty())
            return false;
        const auto suffix = revision.find_first_not_of(digits);
        return suffix == std::string_view::npos ||
               (suffix > 0 && suffix == revision.size() - 1 &&
                   revision.back() >= 'a' && revision.back() <= 'z');
    }

    // Both firmware metadata and frontend overrides use this mapping. Dispatch
    // depends on the selected contracts, never on firmware build strings.
    const DarwinConfigurationEntry* configuration_for_build(
        std::string_view build)
    {
        struct Rule { std::string_view prefix; std::string_view abi_name; };
        constexpr std::array rules {
            Rule { "1A", "darwin9.0.0d1" },
            Rule { "3A", "darwin9.0.0d1" },
            Rule { "4B", "darwin9.0.0d1" },
            Rule { "5A", "darwin9.3.1" },
            Rule { "5G", "darwin9.4.1" },
            Rule { "7A", "darwin10.0.0d3" },
            Rule { "7B", "darwin10.3.1-bootstrap-notify" },
            Rule { "8A", "darwin10.3.1-native-notify" },
            Rule { "8C", "darwin10.4.0" },
            Rule { "8F", "darwin11.0.0-inline-iokit" },
            Rule { "9A", "darwin11.0.0-wide-vm" },
            // The 9B dyld keeps the Darwin 11 wire contracts but probes the
            // high commpage while selecting atomic routines.
            Rule { "9B", "darwin11.0.0-wide-vm-high-vectors" },
            Rule { "10", "darwin13.0.0-wide-vm-high-commpage" },
            Rule { "11", "darwin14.0.0" },
        };
        const auto branch = build.find_first_not_of("0123456789");
        const auto generation = build.substr(0, branch);
        const auto family = build.substr(0, branch + 1);
        for (const auto& rule : rules) {
            if (rule.prefix == family || rule.prefix == generation)
                return find_configuration(rule.abi_name);
        }
        return nullptr;
    }

} // namespace

std::span<const DarwinConfigurationEntry> darwin_configurations()
{
    return configurations;
}

std::string_view darwin_abi_source_name(DarwinAbiSource source)
{
    switch (source) {
    case DarwinAbiSource::CompiledDefault: return "compiled-default";
    case DarwinAbiSource::FirmwareMetadata: return "firmware-metadata";
    case DarwinAbiSource::Explicit: return "explicit";
    case DarwinAbiSource::Unresolved: return "unresolved";
    }
    return "unresolved";
}

DarwinKernelConfiguration resolve_darwin_configuration(
    const std::filesystem::path& rootfs,
    std::optional<std::string_view> ios_build)
{
    DarwinKernelConfiguration configuration;
    const auto build = ios_build ? std::string { *ios_build }
                                : read_darwin_build_version(rootfs);
    const DarwinConfigurationEntry* selected = nullptr;
    if (ios_build) {
        if (!valid_ios_build(build)) {
            throw std::invalid_argument { "invalid iOS build code: " + build +
                                          "; expected a code such as 9A334" };
        }
        selected = configuration_for_build(build);
        if (selected == nullptr) {
            throw std::invalid_argument { "unsupported iOS build code: " +
                                          build };
        }
        configuration.abi_source = DarwinAbiSource::Explicit;
        configuration.abi_source_detail = build;
    } else if (!build.empty()) {
        selected = valid_ios_build(build) ? configuration_for_build(build)
                                         : nullptr;
        configuration.abi_source = selected ? DarwinAbiSource::FirmwareMetadata
                                           : DarwinAbiSource::Unresolved;
        configuration.abi_source_detail = build;
    } else if (rootfs.empty() || !std::filesystem::exists(rootfs)) {
        selected = find_configuration("darwin9.0.0d1");
        configuration.abi_source = DarwinAbiSource::CompiledDefault;
    }
    if (selected != nullptr) {
        configuration.abi = selected->abi;
        configuration.identity = DarwinKernelIdentity { selected->darwin_release,
            build.empty() ? "1A543a" : std::string_view { build } };
        configuration.abi_name = selected->name;
    } else {
        configuration.identity = DarwinKernelIdentity { "unknown",
            build.empty() ? "unknown" : std::string_view { build } };
    }
    return configuration;
}

} // namespace shade
