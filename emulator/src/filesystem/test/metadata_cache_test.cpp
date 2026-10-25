// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Checks the host xattr cache of the guest metadata provider on a scratch
// rootfs: a cached value stays until the emulator's own writes invalidate it,
// and a removed name never gives its value to a file created at the same path.

#include "filesystem/hfs_metadata.hpp"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>

#include <sys/xattr.h>

namespace {

namespace fs = std::filesystem;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

constexpr std::string_view host_mode_name = "hfsfuse.record.file_mode";
constexpr std::uint32_t first_mode = 4660U;
constexpr std::uint32_t second_mode = 22136U;
constexpr std::uint32_t third_mode = 43981U;

void touch(const fs::path& path)
{
    std::ofstream { path, std::ios::binary | std::ios::trunc };
}

void set_mode(const fs::path& path, std::uint32_t value)
{
    const auto text = std::to_string(value);
    setxattr(path.c_str(), std::string { host_mode_name }.c_str(), text.data(),
        text.size(), 0, 0);
}

std::uint32_t mode_of(const emulator::hfs::MetadataProvider& provider,
    const fs::path& path)
{
    const auto metadata = provider.query(path, true);
    return metadata ? metadata->mode : 0;
}

void cached_value_survives_host_changes_until_invalidated(const fs::path& root)
{
    const auto file = root / "cached";
    touch(file);
    set_mode(file, first_mode);
    const emulator::hfs::MetadataProvider provider { root };
    expect(mode_of(provider, file) == first_mode, "first query reads the xattr");
    set_mode(file, second_mode);
    expect(mode_of(provider, file) == first_mode,
        "a query without invalidation returns the cached value");
    provider.invalidate_xattrs();
    expect(mode_of(provider, file) == second_mode,
        "invalidation makes the host value visible");
}

void removed_name_does_not_leak_its_value(const fs::path& root)
{
    const auto file = root / "removed";
    touch(file);
    set_mode(file, first_mode);
    const emulator::hfs::MetadataProvider provider { root };
    expect(mode_of(provider, file) == first_mode, "query before removal");
    std::error_code error;
    expect(provider.remove_name(file, error) && !error,
        "remove_name removes the file");
    touch(file);
    set_mode(file, third_mode);
    expect(mode_of(provider, file) == third_mode,
        "a file created after removal reads its own xattr");
}

}

int main()
{
    const auto root =
        fs::temp_directory_path() / "revenant-metadata-cache-test";
    std::error_code error;
    fs::remove_all(root, error);
    fs::create_directories(root);
    cached_value_survives_host_changes_until_invalidated(root);
    removed_name_does_not_leak_its_value(root);
    fs::remove_all(root, error);
    if (failures != 0) {
        std::cerr << failures << " metadata cache check(s) failed\n";
        return 1;
    }
    std::cout << "metadata cache: all checks passed\n";
    return 0;
}
