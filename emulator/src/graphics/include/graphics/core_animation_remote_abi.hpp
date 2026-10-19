// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve firmware capabilities for remote CoreAnimation transaction
// messages.

#pragma once

#include <cstdint>
#include <optional>
#include <string_view>

namespace emulator {

class MachOImage;

struct CoreAnimationRemoteAbi {
    std::string_view name;
    std::uint32_t inline_transaction_message { };
    std::uint32_t out_of_line_transaction_message { };
    bool render_server_port_rendezvous { };

    [[nodiscard]] bool is_transaction_message(std::uint32_t identifier) const;

    [[nodiscard]] static std::optional<CoreAnimationRemoteAbi> detect(
        const MachOImage& image);

    bool operator==(const CoreAnimationRemoteAbi&) const = default;
};

}
