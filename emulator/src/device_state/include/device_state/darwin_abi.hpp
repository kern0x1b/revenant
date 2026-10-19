// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define named capability profiles for guest syscall, pthread, IOKit
// and shared-region ABIs.

#pragma once

#include <cstdint>

#include "network/darwin_abi_route.hpp"
#include "foundation/darwin_notify_state_hle.hpp"
#include "foundation/darwin_process_start_abi.hpp"
#include "foundation/darwin_address_layout.hpp"
#include "foundation/device_identity.hpp"

namespace emulator {

enum class DarwinPthreadAbi : std::uint8_t {
    LegacyMachThreads,
    BsdThreadRegisterV1,
    BsdThreadRegisterV1TsdBase,
    BsdThreadRegisterV1TsdBaseFourPriorityWorkqueues,
    BsdThreadRegisterV1ExpandedTsdFourPriorityWorkqueues,
    BsdThreadRegisterV2,
};

enum class DarwinApple80211IoctlAbi : std::uint8_t {
    AlignedCurrentNetworkRecord,
    CompactCurrentNetworkRecord,
};

enum class DarwinIOConnectMethodAbi : std::uint8_t {
    Natural32OolScalarThenStructure,
    Natural32OolStructureThenScalar,
    MachVm64OolStructureThenScalar,
};

enum class DarwinMachVmAddressWidth : std::uint8_t {
    Natural32,
    Wide64,
};

enum class DarwinSandboxAbi : std::uint8_t {
    Natural32Arguments,
    Wide64Arguments,
};

enum class DarwinArmCommpageAbi : std::uint8_t {
    LegacyAddress,
    HighAddress,
    HighDataAddress,
};

enum class DarwinSharedRegionAbi : std::uint8_t {
    LegacyRelocatableMappings,
    FixedMappingsWithSlideInfoV1,
};

enum class DarwinMachKernelRpcAbi : std::uint8_t {
    LegacyMigOnly,
    DirectVmAndPortTrapsV1,
    DirectWideVmAndPortTraps,
};

enum class DarwinPsynchAbi : std::uint8_t {
    Unsupported,
    Arm32GenerationV1,
};

enum class DarwinSemaphoreWaitAbi : std::uint8_t {
    InlineSeconds32,
    InlineSeconds64,
};

enum class DarwinStackSnapshotAbi : std::uint8_t {
    Unsupported,
    LegacyFourArguments,
    LegacyFiveArguments,
};

enum class DarwinIOKitMatchingRpcAbi : std::uint8_t {
    PluralIteratorOnly,
    InlineSingleServiceV1,
    InlineSingleServiceAfterVariableOutput,
};

enum class DarwinFramebufferRegistryAbi : std::uint8_t {
    DeviceSpecificClass,
    UnifiedClcdClass,
};

enum class DarwinMemoryStatusPriorityAbi : std::uint8_t {
    Unsupported,
    SignedPriority,
    PriorityBands,
};

enum class DarwinHidDigitizerAbi : std::uint8_t {
    CollectionContactChanges,
    ChildContactChanges,
};

struct DarwinGuestCapabilities {
    bool send_sigsys { };
    bool arm_cache_trap_grants_execute { };
};

struct DarwinAbi {
    DarwinAbiEpoch abi_epoch { DarwinAbiEpoch::Unknown };
    DarwinPthreadAbi pthread_abi {
        DarwinPthreadAbi::LegacyMachThreads
    };
    DarwinApple80211IoctlAbi apple80211_ioctl {
        DarwinApple80211IoctlAbi::AlignedCurrentNetworkRecord
    };
    DarwinIOConnectMethodAbi io_connect_method {
        DarwinIOConnectMethodAbi::Natural32OolScalarThenStructure
    };
    DarwinMachVmAddressWidth mach_vm_address {
        DarwinMachVmAddressWidth::Natural32
    };
    DarwinArmCommpageAbi arm_commpage {
        DarwinArmCommpageAbi::LegacyAddress
    };
    DarwinNotifyStateAbi notify_state_abi {
        DarwinNotifyStateAbi::NativeServerTokens
    };
    DarwinInitialAppleVectorAbi initial_apple_vector_abi {
        DarwinInitialAppleVectorAbi::KeyedExecutablePath
    };
    DarwinSharedRegionAbi shared_region_abi {
        DarwinSharedRegionAbi::LegacyRelocatableMappings
    };
    DarwinMachKernelRpcAbi mach_kernel_rpc {
        DarwinMachKernelRpcAbi::LegacyMigOnly
    };
    DarwinPsynchAbi psynch_abi {
        DarwinPsynchAbi::Unsupported
    };
    DarwinSemaphoreWaitAbi semaphore_wait_abi {
        DarwinSemaphoreWaitAbi::InlineSeconds32
    };
    DarwinStackSnapshotAbi stack_snapshot_abi {
        DarwinStackSnapshotAbi::Unsupported
    };
    DarwinIOKitMatchingRpcAbi iokit_matching_rpc {
        DarwinIOKitMatchingRpcAbi::PluralIteratorOnly
    };
    DarwinFramebufferRegistryAbi framebuffer_registry {
        DarwinFramebufferRegistryAbi::DeviceSpecificClass
    };
    DarwinSandboxAbi sandbox_abi { DarwinSandboxAbi::Natural32Arguments };
    DarwinMachVmAddressWidth mach_port_context {
        DarwinMachVmAddressWidth::Natural32
    };
    DarwinMemoryStatusPriorityAbi memory_status_priority {
        DarwinMemoryStatusPriorityAbi::Unsupported
    };
    DarwinHidDigitizerAbi hid_digitizer {
        DarwinHidDigitizerAbi::CollectionContactChanges
    };
    ActivationHardwareModelPolicy activation_hardware_model_policy {
        ActivationHardwareModelPolicy::Retail
    };
    DarwinAddressLayout address_layout { DarwinAddressLayout::ClassicArm };
    DarwinGuestCapabilities capabilities;
};

}
