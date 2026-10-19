// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve guest paths and symbolic links within the selected firmware
// root filesystem.

#pragma once

#include <filesystem>
#include <string_view>
#include <utility>

namespace shade {

class RootfsPathResolver {
public:
    explicit RootfsPathResolver(std::filesystem::path rootfs)
        : rootfs_ { std::move(rootfs) }
    {
    }

    [[nodiscard]] std::filesystem::path resolve(std::string_view guest_path,
        const std::filesystem::path& guest_working_directory = "/",
        bool follow_final_symlink = true) const;

private:
    std::filesystem::path rootfs_;
};

} // namespace shade
