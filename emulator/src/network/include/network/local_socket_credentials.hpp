// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace emulator::bsd {

class LocalSocketCredentials {
public:
    LocalSocketCredentials(std::uint32_t uid, std::uint32_t gid)
        : uid_ { uid }, gid_ { gid }
    {
    }

    [[nodiscard]] std::array<std::byte, 76> encode() const
    {
        std::array<std::byte, 76> bytes { };
        const auto write32 = [&](std::size_t offset, std::uint32_t value) {
            for (std::size_t index = 0; index < 4; ++index)
                bytes[offset + index] =
                    static_cast<std::byte>(value >> (index * 8U));
        };
        write32(4, uid_);
        bytes[8] = std::byte { 1 };
        write32(12, gid_);
        return bytes;
    }

private:
    std::uint32_t uid_;
    std::uint32_t gid_;
};

}
