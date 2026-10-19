// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track guest vnode changes and notify registered filesystem
// watchers.

#pragma once

#include "foundation/file_page_cache.hpp"

#include <cstdint>
#include <filesystem>

namespace shade {

class VnodeWatch {
public:
    VnodeWatch(std::filesystem::path path, GuestFileGenerationRegistry& files);

    [[nodiscard]] std::uint32_t pending(
        GuestFileGenerationRegistry& files) const;
    void acknowledge(std::uint32_t flags) const;

private:
    std::filesystem::path path_;
    mutable GuestFileGenerationSnapshot observed_;
    mutable std::uint64_t mutation_generation_ { };
    mutable std::uint32_t pending_ { };
    mutable bool detached_ { };
};

}
