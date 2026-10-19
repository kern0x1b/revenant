// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe the kernel identity values exposed to guest software.

#include "device_state/darwin_kernel_identity.hpp"

namespace shade {

DarwinKernelIdentity::DarwinKernelIdentity(
    std::string_view darwin_release, std::string_view ios_build)
    : name { "darwin" + std::string { darwin_release } },
      operating_system_release { darwin_release },
      version { "Darwin Kernel Version " + operating_system_release +
                ": Shade compatibility kernel; " + name + "/RELEASE_ARM" },
      build_version { ios_build }
{
}

} // namespace shade
