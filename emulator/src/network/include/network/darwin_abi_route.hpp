// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Map firmware kernel epochs to named Darwin syscall and interface
// compatibility profiles.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/syscalls.master
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/kern/syscalls.master

#pragma once

#include <cstdint>

namespace emulator {

enum class DarwinAbiEpoch {
    Unknown,
    IphoneOs1,
    IphoneOs2,
    IphoneOs3,
    Darwin10,
    Darwin11,
    Darwin13,
    Later,
};

enum class DarwinAbiDomain {
    BsdSyscall,
    MachTrap,
    ArmFastTrap,
    MigRoutine,
};

enum class DarwinAbiCompatibility {
    Additive,
    ShapeDispatched,
    VersionSensitive,
    Unsupported,
};

struct DarwinAbiRoute {
    DarwinAbiDomain domain { };
    std::uint32_t identifier { };
    DarwinAbiCompatibility compatibility {
        DarwinAbiCompatibility::Unsupported
    };
    DarwinAbiEpoch minimum_epoch { DarwinAbiEpoch::Unknown };
    DarwinAbiEpoch maximum_epoch { DarwinAbiEpoch::Unknown };
};

inline constexpr DarwinAbiRoute legacy_iopolicysys_route {
    DarwinAbiDomain::BsdSyscall, 322U, DarwinAbiCompatibility::VersionSensitive,
    DarwinAbiEpoch::IphoneOs2, DarwinAbiEpoch::Later
};

inline constexpr DarwinAbiRoute arm_cache_trap_execute_route {
    DarwinAbiDomain::ArmFastTrap,
    0U,
    DarwinAbiCompatibility::VersionSensitive, DarwinAbiEpoch::IphoneOs1,
    DarwinAbiEpoch::IphoneOs1
};

[[nodiscard]] constexpr bool darwin_abi_route_supported(
    const DarwinAbiRoute& route, DarwinAbiEpoch epoch)
{
    switch (route.compatibility) {
    case DarwinAbiCompatibility::Additive:
        return true;
    case DarwinAbiCompatibility::ShapeDispatched:
        return true;
    case DarwinAbiCompatibility::VersionSensitive:
        if (epoch == DarwinAbiEpoch::Unknown)
            return false;
        return static_cast<std::uint8_t>(epoch) >=
                   static_cast<std::uint8_t>(route.minimum_epoch) &&
               static_cast<std::uint8_t>(epoch) <=
                   static_cast<std::uint8_t>(route.maximum_epoch);
    case DarwinAbiCompatibility::Unsupported:
        return false;
    }
    return false;
}

}
