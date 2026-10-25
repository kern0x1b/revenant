// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <string>
#include <vector>

namespace emulator {

class AddressSpace;
class CompatibilityKernel;

struct CompatibilityKernelSnapshot {
    static std::vector<std::string> populated_members(
        const CompatibilityKernel& kernel);
    static std::vector<std::string> populated_memory(
        const AddressSpace& memory);
    static void add_pending_timer(CompatibilityKernel& kernel);
};

void require_covered_members(
    const CompatibilityKernel& kernel, const AddressSpace& memory);

}
