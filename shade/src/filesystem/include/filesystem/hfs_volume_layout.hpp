// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Discover guest HFS mount identities and geometry from the firmware
// filesystem.

#pragma once

#include <cstdint>
#include <filesystem>
#include <span>
#include <string_view>
#include <vector>

#include "filesystem/hfs_metadata.hpp"

namespace shade::hfs {

// Guest-visible HFS volumes discovered from the firmware's own fstab. This
// keeps partition identity in the filesystem layer and avoids leaking host
// filesystem geometry through statfs/getattrlist.
class VolumeLayout {
public:
    VolumeLayout(std::filesystem::path rootfs, std::uint64_t storage_bytes);

    [[nodiscard]] const VolumeMetadata& for_guest_path(
        std::string_view path) const;
    [[nodiscard]] const VolumeMetadata& for_mounted_device(
        std::string_view device) const;
    [[nodiscard]] bool is_mount_root(std::string_view path) const;
    [[nodiscard]] std::span<const VolumeMetadata> volumes() const
    {
        return volumes_;
    }

private:
    std::vector<VolumeMetadata> volumes_;
};

} // namespace shade::hfs
