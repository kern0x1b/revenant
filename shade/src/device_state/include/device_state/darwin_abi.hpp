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

namespace shade {

// libpthread moved thread creation and workqueue registration behind BSD
// syscalls in Darwin 10. Keep that wire contract separate from the broader
// kernel epoch: later Darwin releases revise the registration arguments and
// workqueue operations without changing the device model.
enum class DarwinPthreadAbi : std::uint8_t {
    LegacyMachThreads,
    BsdThreadRegisterV1,
    // Darwin 10.4 ARM32 uses an embedded TSD base in pthread_t.
    BsdThreadRegisterV1TsdBase,
    // Darwin 11 retains the ARM32 v1 registration/TSD layout and adds the
    // background workqueue priority to high/default/low.
    BsdThreadRegisterV1TsdBaseFourPriorityWorkqueues,
    // Split libpthread retains v1 registration and four queues, but moves
    // its embedded TSD past the expanded thread bookkeeping fields.
    BsdThreadRegisterV1ExpandedTsdFourPriorityWorkqueues,
    BsdThreadRegisterV2,
};

// Apple80211 keeps selector 201 across these releases, but the native driver
// record packed behind the ioctl changed independently of the public API.
// Name the two audited wire layouts so BSD emulation never needs to inspect a
// firmware build string or infer a layout from a caller-provided byte count.
enum class DarwinApple80211IoctlAbi : std::uint8_t {
    AlignedCurrentNetworkRecord,
    CompactCurrentNetworkRecord,
};

// The private io_connect_method request retained the same MIG routine number
// across revisions which independently reordered the output capacities and
// widened the out-of-line address/size fields to Mach VM values.
// Keep that wire detail independent of the user-client selector and broad
// kernel epoch so unknown firmware cannot be guessed from request contents.
enum class DarwinIOConnectMethodAbi : std::uint8_t {
    Natural32OolScalarThenStructure,
    Natural32OolStructureThenScalar,
    MachVm64OolStructureThenScalar,
};

// Address width changed within the Darwin 11 ARM32 family. It is independent
// of the kernel epoch and of vm_map's always-natural-sized address fields.
enum class DarwinMachVmAddressWidth : std::uint8_t {
    Natural32,
    Wide64,
};

// Sandbox MAC requests widened every argument slot, including pointers,
// independently of the application's ARM32 address space.
enum class DarwinSandboxAbi : std::uint8_t {
    Natural32Arguments,
    Wide64Arguments,
};

// ARM32 userland reads CPU capabilities and topology from a read-only
// commpage. Its virtual address is a separately selected kernel ABI.
enum class DarwinArmCommpageAbi : std::uint8_t {
    LegacyAddress,
    HighAddress,
    HighDataAddress,
};

// Later ARM32 firmware added a fixed mach_vm shared-region mapping array plus
// an optional dyld slide-info bitmap. Keep that wire contract independent of
// the broad kernel epoch: syscall numbers and argument meanings changed while
// the surrounding VM model remained stable.
enum class DarwinSharedRegionAbi : std::uint8_t {
    LegacyRelocatableMappings,
    FixedMappingsWithSlideInfoV1,
};

// Some ARM32 libSystem releases use direct kernel-RPC traps for the hot Mach
// port operations that older releases send through MIG. Keep the selection
// explicit so a legacy guest never observes newer trap-table entries.
enum class DarwinMachKernelRpcAbi : std::uint8_t {
    LegacyMigOnly,
    DirectVmAndPortTrapsV1,
    DirectWideVmAndPortTraps,
};

// Darwin 10 introduced the psynch syscall family in slots that older ARM32
// kernels used for shared-region operations.  Keep that syscall-table and
// argument-packing contract explicit so dispatch never guesses from a call's
// register contents or from an individual firmware build.
enum class DarwinPsynchAbi : std::uint8_t {
    Unsupported,
    Arm32GenerationV1,
};

// __semwait_signal widened tv_sec independently of ARM pointer width.
// The timespec-pointer syscall has its own number and is not affected.
enum class DarwinSemaphoreWaitAbi : std::uint8_t {
    InlineSeconds32,
    InlineSeconds64,
};

// Darwin 11 exposes the legacy stack_snapshot diagnostic syscall. Later
// kernels widened its argument list before retiring the old implementation;
// keep that shape explicit so a diagnostic call cannot be mistaken for a
// generic nosys entry on an audited profile.
enum class DarwinStackSnapshotAbi : std::uint8_t {
    Unsupported,
    LegacyFourArguments,
    LegacyFiveArguments,
};

// Darwin 11's IOKit client added a private inline matching RPC which returns
// the first service directly instead of an iterator.  Its routine number and
// compact c-string request are independent of the registry contents, so keep
// the transport contract explicit and let all service classes share the same
// registry matcher.
enum class DarwinIOKitMatchingRpcAbi : std::uint8_t {
    PluralIteratorOnly,
    InlineSingleServiceV1,
    // A variable-output connect method was inserted before the singular RPC.
    InlineSingleServiceAfterVariableOutput,
};

// The LCD user client moved from SoC-specific registry classes to a common
// class. This changes guest discovery, independently of the physical panel.
enum class DarwinFramebufferRegistryAbi : std::uint8_t {
    DeviceSpecificClass,
    UnifiedClcdClass,
};

// Early memorystatus clients pass a signed priority (larger values are less
// protected); later clients pass an ascending, bounded jetsam band.
enum class DarwinMemoryStatusPriorityAbi : std::uint8_t {
    Unsupported,
    SignedPriority,
    PriorityBands,
};

// Earlier HID consumers derive hand phases from the collection's contact
// changes. Later consumers route child contacts separately and interpret
// collection contact changes as touch-count-only notifications.
enum class DarwinHidDigitizerAbi : std::uint8_t {
    CollectionContactChanges,
    ChildContactChanges,
};

struct DarwinGuestCapabilities {
    // XNU's nosys entry returns ENOSYS and raises SIGSYS on the audited
    // production epochs. Unknown profiles conservatively suppress the signal
    // until their kernel policy is identified.
    bool send_sigsys { };
    // Early UIKit emits writable ARM trampolines and relies on the emulator's
    // compatibility permission promotion after the instruction-cache trap.
    // This is a version-sensitive capability; later and unknown profiles keep
    // the XNU behavior of leaving VM permissions unchanged.
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
    // Port-context MIG fields widened after other Mach VM routines did.
    DarwinMachVmAddressWidth mach_port_context {
        DarwinMachVmAddressWidth::Natural32
    };
    DarwinMemoryStatusPriorityAbi memory_status_priority {
        DarwinMemoryStatusPriorityAbi::Unsupported
    };
    DarwinHidDigitizerAbi hid_digitizer {
        DarwinHidDigitizerAbi::CollectionContactChanges
    };
    // Firmware route databases can require a retail or development-board
    // identity for offline activation. Keep this contract independent of
    // product names and application paths.
    ActivationHardwareModelPolicy activation_hardware_model_policy {
        ActivationHardwareModelPolicy::Retail
    };
    DarwinAddressLayout address_layout { DarwinAddressLayout::ClassicArm };
    DarwinGuestCapabilities capabilities;
};

} // namespace shade
