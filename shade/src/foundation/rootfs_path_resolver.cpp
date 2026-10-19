// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve guest paths and symbolic links within the selected firmware
// root filesystem.

#include "foundation/rootfs_path_resolver.hpp"

#include <system_error>
#include <vector>

namespace shade {
namespace {

    std::filesystem::path normalize_inside_root(
        const std::filesystem::path& guest_path)
    {
        std::filesystem::path relative;
        for (const auto& component : guest_path) {
            if (component.empty() || component == "/" || component == ".")
                continue;
            if (component == "..") {
                if (!relative.empty())
                    relative = relative.parent_path();
                continue;
            }
            relative /= component;
        }
        return relative;
    }

} // namespace

std::filesystem::path RootfsPathResolver::resolve(std::string_view guest_path,
    const std::filesystem::path& guest_working_directory,
    bool follow_final_symlink) const
{
    std::filesystem::path guest { guest_path };
    if (!guest.is_absolute())
        guest = guest_working_directory / guest;

    auto relative = normalize_inside_root(guest);
    for (unsigned depth = 0; depth < 16; ++depth) {
        std::vector<std::filesystem::path> components;
        for (const auto& component : relative)
            components.push_back(component);

        std::filesystem::path prefix;
        bool restarted = false;
        for (std::size_t index = 0; index < components.size(); ++index) {
            prefix /= components[index];
            const auto final_component = index + 1U == components.size();
            if (final_component && !follow_final_symlink)
                continue;

            const auto candidate = rootfs_ / prefix;
            std::error_code error;
            if (!std::filesystem::is_symlink(candidate, error) || error)
                continue;

            const auto target = std::filesystem::read_symlink(candidate, error);
            if (error)
                return rootfs_ / relative;
            auto redirected =
                target.is_absolute()
                    ? normalize_inside_root(target)
                    : normalize_inside_root(prefix.parent_path() / target);
            for (std::size_t remaining = index + 1U;
                remaining < components.size(); ++remaining) {
                redirected /= components[remaining];
            }
            relative = normalize_inside_root(redirected);
            restarted = true;
            break;
        }
        if (!restarted)
            return relative.empty() ? rootfs_ : rootfs_ / relative;
    }
    return relative.empty() ? rootfs_ : rootfs_ / relative;
}

} // namespace shade
