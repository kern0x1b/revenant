// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define session startup options and resolve runtime cache defaults.

#include "runtime/boot_options.hpp"

namespace shade {

std::filesystem::path default_host_cache_directory(
    const std::filesystem::path& rootfs)
{
    const auto normalized = rootfs.lexically_normal();
    auto rootfs_name = normalized.filename();
    if (rootfs_name.empty() || rootfs_name == "." ||
        rootfs_name == normalized.root_name()) {
        rootfs_name = "rootfs";
    }
    return normalized.parent_path() / ".shade-cache" / rootfs_name;
}

} // namespace shade
