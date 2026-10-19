// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include "sandbox.hpp"
#include <compare>
#include <cstdint>
#include <map>
#include <string>

namespace shade::bsd::sandbox {

// Opaque guest capabilities for the non-enforcing Sandbox provider. The
// firmware decides when to grant access; these tokens never grant host access.
// All calls are serialized by KernelSharedState::mach_mutex.
class Extensions {
public:
    [[nodiscard]] CallResult dispatch(AddressSpace& memory, std::uint32_t pid,
        std::uint32_t operation, std::uint32_t argument);
    void fork_process(std::uint32_t parent, std::uint32_t child);
    void exit_process(std::uint32_t pid);

private:
    struct Grant {
        std::string class_name;
        std::string resource;
        std::uint64_t kind;
        std::uint64_t flags;
        auto operator<=>(const Grant&) const = default;
    };
    std::map<Grant, std::uint64_t> grants_;
    std::map<std::string, std::uint64_t> tokens_;
    std::map<std::uint32_t, std::map<std::uint64_t, std::uint64_t>> handles_;
    std::uint64_t next_handle_ { 1U };
};

} // namespace shade::bsd::sandbox
