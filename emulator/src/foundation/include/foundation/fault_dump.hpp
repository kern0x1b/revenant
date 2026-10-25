// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describes the guest words a fatal fault left behind: for each general
// register that points at mapped memory, the first words there, and for the
// first word of that memory, the words at the address it holds (the isa or
// vtable of an Objective-C or dispatch object). Words are labelled by the
// caller, so the image and symbol that a word lands in is named in the log.

#pragma once

#include "foundation/macho.hpp"

#include <array>
#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace emulator {

using GuestWordReader =
    std::function<std::optional<std::uint32_t>(std::uint32_t)>;
using GuestWordLabel = std::function<std::string(std::uint32_t)>;

[[nodiscard]] std::string symbol_offset_label(
    const std::vector<MachSymbol>& symbols,
    const std::vector<MachSection>& sections, std::uint32_t address);

[[nodiscard]] std::vector<std::string> describe_fault_words(
    const std::array<std::uint32_t, 16>& registers,
    const GuestWordReader& read32, const GuestWordLabel& label);

}
