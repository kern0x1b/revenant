// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Map guest executables and libraries and construct their initial
// execution state.

#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/darwin_process_start_abi.hpp"
#include "foundation/darwin_address_layout.hpp"
#include "foundation/macho.hpp"

namespace shade {

class ExecutableCatalog;

struct LoadedProcess {
    MachOImage executable;
    MachOImage dynamic_linker;
    std::string executable_path;
    std::vector<std::string> arguments;
    std::uint32_t entry_point { };
    std::uint32_t stack_pointer { };
    std::uint32_t main_header { };
};

class ProcessLoader {
public:
    ProcessLoader(std::filesystem::path rootfs, AddressSpace& memory,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K,
        ExecutableCatalog* catalog = nullptr,
        DarwinInitialAppleVectorAbi initial_apple_vector_abi =
            DarwinInitialAppleVectorAbi::KeyedExecutablePath,
        DarwinAddressLayout address_layout = DarwinAddressLayout::ClassicArm);

    LoadedProcess load(std::string guest_executable,
        std::vector<std::string> arguments = { },
        std::vector<std::string> environment = { });
    [[nodiscard]] bool validate(std::string guest_executable) const;

private:
    struct ResolvedInvocation {
        std::string executable_path;
        std::vector<std::string> arguments;
    };

    [[nodiscard]] std::filesystem::path host_path(
        const std::string& guest_path) const;
    [[nodiscard]] MachOImage parse_catalogued(
        const std::filesystem::path& path) const;
    [[nodiscard]] ResolvedInvocation resolve_invocation(
        std::string guest_executable, std::vector<std::string> arguments) const;

    std::filesystem::path rootfs_;
    AddressSpace& memory_;
    ArmArchitectureVersion architecture_;
    ExecutableCatalog* catalog_ { };
    DarwinAddressLayout address_layout_;
    DarwinInitialAppleVectorAbi initial_apple_vector_abi_ {
        DarwinInitialAppleVectorAbi::KeyedExecutablePath
    };
};

} // namespace shade
