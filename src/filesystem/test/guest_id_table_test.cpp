// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Guest-free check of the sighting-order guest ids of a bounded (--ticks) run.
// The table sees host identities (device, inode) and guest paths only: no host
// file, no kernel and no guest is involved.

#include "filesystem/hfs_metadata.hpp"

#include <cstdint>
#include <iostream>
#include <map>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

using shade::hfs::GuestIdTable;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

constexpr std::uint32_t first_user_catalog_id = 16U;
constexpr std::uint32_t last_user_catalog_id = 0x7fff'ffffU;

GuestIdTable::Identity host(std::uint64_t inode)
{
    return GuestIdTable::Identity { 1U, inode };
}

void distinct_keys_get_distinct_ids()
{
    GuestIdTable table;
    std::unordered_set<std::uint32_t> ids;
    std::size_t count = 0;
    for (std::uint64_t inode = 100U; inode < 600U; ++inode) {
        const auto id = table.id_for(
            host(inode), "System/Library/file" + std::to_string(inode));
        ids.insert(id);
        ++count;
        expect(id >= first_user_catalog_id && id <= last_user_catalog_id,
            "guest id is in the user catalog range");
    }
    expect(ids.size() == count, "distinct host identities get distinct ids");
}

void same_key_keeps_its_id_across_renames()
{
    GuestIdTable table;
    const auto before = table.id_for(host(42U), "private/var/a");
    // A rename moves the name, not the inode: the key is the same.
    const auto after = table.id_for(host(42U), "private/var/b");
    expect(before == after, "same host identity keeps its id across a rename");
}

void id_does_not_depend_on_first_sighting_order()
{
    const std::vector<std::pair<std::uint64_t, std::string>> sightings {
        { 10U, "Library/Caches/a" },
        { 11U, "Library/Caches/b" },
        { 12U, "Library/Preferences/c" },
        { 13U, "usr/lib/d.dylib" },
        { 14U, "usr/share/e" },
        { 15U, "private/var/mobile/f" },
        { 16U, "System/Library/g.plist" },
        { 17U, "bin/h" },
    };
    GuestIdTable forward;
    std::map<std::string, std::uint32_t> forward_ids;
    for (const auto& [inode, path] : sightings)
        forward_ids[path] = forward.id_for(host(inode), path);

    GuestIdTable backward;
    std::map<std::string, std::uint32_t> backward_ids;
    for (auto it = sightings.rbegin(); it != sightings.rend(); ++it)
        backward_ids[it->second] = backward.id_for(host(it->first), it->second);

    expect(forward.collisions() == 0 && backward.collisions() == 0,
        "precondition: the sample set has no colliding paths");
    expect(forward_ids == backward_ids,
        "the ids of a path do not depend on the order of first sightings");
}

void recycled_inode_gets_a_fresh_id()
{
    GuestIdTable table;
    const auto old_id = table.id_for(host(7U), "Library/old.plist");
    const auto neighbour = table.id_for(host(8U), "Library/other.plist");

    table.forget(host(7U));
    const auto recycled = table.id_for(host(7U), "Library/new.plist");

    GuestIdTable fresh;
    const auto expected = fresh.id_for(host(7U), "Library/new.plist");
    expect(recycled == expected,
        "a recycled inode is a new sighting: its id is the id of its new path");
    expect(recycled != old_id,
        "a recycled inode does not keep the id of the removed file");
    expect(table.id_for(host(8U), "Library/other.plist") == neighbour,
        "forgetting one identity leaves the other identities alone");
}

void colliding_paths_get_probed_distinct_ids()
{
    GuestIdTable table;
    const auto first = table.id_for(host(1U), "same/path");
    const auto second = table.id_for(host(2U), "same/path");
    expect(first != second, "two identities with one path get two ids");
    expect(second == first + 1U,
        "a colliding identity takes the next free id");
    expect(table.collisions() == 1U, "the collision is counted");

    table.forget(host(1U));
    expect(table.id_for(host(2U), "same/path") == second,
        "forgetting a colliding identity does not renumber the others");
}

} // namespace

int main()
{
    distinct_keys_get_distinct_ids();
    same_key_keeps_its_id_across_renames();
    id_does_not_depend_on_first_sighting_order();
    recycled_inode_gets_a_fresh_id();
    colliding_paths_get_probed_distinct_ids();
    if (failures != 0) {
        std::cerr << failures << " guest id table check(s) failed\n";
        return 1;
    }
    std::cout << "guest id table: all checks passed\n";
    return 0;
}
