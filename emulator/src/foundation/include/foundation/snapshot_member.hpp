// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe the members of a snapshotted owner: each member has a name, a
// test for whether it holds state, and its save and restore. An owner lists
// its members in save order, so that list is the byte layout of the owner.

#pragma once

#include "foundation/snapshot_io.hpp"

#include <array>
#include <cstddef>
#include <string>
#include <string_view>
#include <vector>

namespace emulator::snapshot {

template <typename Owner>
struct Member {
    std::string_view name;
    bool (*is_default)(const Owner&);
    void (*save)(Writer&, const Owner&);
    void (*restore)(Reader&, Owner&);
};

template <typename Owner, std::size_t N>
void save_members(Writer& out, const Owner& owner,
    const std::array<Member<Owner>, N>& members)
{
    for (const auto& member : members)
        member.save(out, owner);
}

template <typename Owner, std::size_t N>
void restore_members(Reader& in, Owner& owner,
    const std::array<Member<Owner>, N>& members)
{
    for (const auto& member : members)
        member.restore(in, owner);
}

template <typename Owner, std::size_t N>
void note_populated_members(std::vector<std::string>& out,
    const Owner& owner, const std::array<Member<Owner>, N>& members)
{
    for (const auto& member : members) {
        if (!member.is_default(owner))
            out.emplace_back(member.name);
    }
}

}
