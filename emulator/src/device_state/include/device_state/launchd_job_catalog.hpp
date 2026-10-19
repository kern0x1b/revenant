// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Index firmware launchd job declarations and their advertised Mach
// services.

#pragma once

#include <filesystem>
#include <map>
#include <set>
#include <string>
#include <string_view>

namespace emulator {

class LaunchdJobCatalog {
public:
    [[nodiscard]] static LaunchdJobCatalog load(
        const std::filesystem::path& rootfs);

    [[nodiscard]] bool executable_provides_service(
        std::string_view executable, std::string_view service) const;

private:
    void add_job(const std::filesystem::path& path);
    std::map<std::string, std::set<std::string, std::less<>>, std::less<>>
        services_by_executable_;
};

}
