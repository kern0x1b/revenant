// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/virtual_clock.hpp"
#include "kernel/snapshot_ledger.hpp"

#include <cstddef>
#include <iostream>
#include <set>
#include <string>
#include <string_view>
#include <vector>

namespace {

using emulator::snapshot_ledger::Coverage;
using emulator::snapshot_ledger::count_of;
using emulator::snapshot_ledger::find_member;
using emulator::snapshot_ledger::first_uncovered;
using emulator::snapshot_ledger::is_covered;
using emulator::snapshot_ledger::members;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

void every_name_has_one_descriptor()
{
    std::set<std::string_view> names;
    for (const auto& member : members)
        names.insert(member.name);
    expect(names.size() == members.size(),
        "every member name has exactly one descriptor");
}

void every_class_is_counted()
{
    const auto total = count_of(Coverage::saved) + count_of(Coverage::open) +
                       count_of(Coverage::wired) + count_of(Coverage::refused);
    expect(total == members.size(),
        "each descriptor has one of the four coverage classes");
}

void coverage_follows_the_class()
{
    const auto* saved = find_member("clock.now");
    expect(saved && saved->coverage == Coverage::saved,
        "clock.now is a saved member");
    const auto* wired = find_member("kss.launchd_job_catalog");
    expect(wired && wired->coverage == Coverage::wired,
        "kss.launchd_job_catalog is a wired member");
    const auto* open_member = find_member("kss.iokit_display_connections");
    expect(open_member && open_member->coverage == Coverage::open,
        "kss.iokit_display_connections is an open member");
    const auto* refused = find_member("kss.iokit_services");
    expect(refused && refused->coverage == Coverage::refused,
        "kss.iokit_services is a refused member");
    expect(find_member("ck.not_a_member_") == nullptr,
        "a name with no descriptor has no descriptor");
}

void only_saved_and_wired_members_are_covered()
{
    expect(is_covered("clock.now"), "a saved member is covered");
    expect(is_covered("kss.launchd_job_catalog"), "a wired member is covered");
    expect(!is_covered("kss.iokit_display_connections"),
        "an open member is not covered");
    expect(!is_covered("kss.iokit_services"), "a refused member is not covered");
    expect(!is_covered("ck.not_a_member_"),
        "a member without a descriptor is not covered");
}

void every_clock_descriptor_is_a_saved_row()
{
    for (const auto& member : emulator::VirtualClock::snapshot_members()) {
        const auto* row = find_member(member.name);
        expect(row != nullptr && row->coverage == Coverage::saved,
            "the clock member " + std::string { member.name } +
                " has a saved ledger row");
    }
}

void covered_members_pass_the_walk()
{
    const std::vector<std::string> populated { "clock.now", "kss.launchd_job_catalog" };
    expect(!first_uncovered(populated).has_value(),
        "populated members that are saved or wired pass the walk");
}

void member_added_without_a_descriptor_fails_by_name()
{
    const std::vector<std::string> populated { "clock.now", "ck.brand_new_member_" };
    const auto uncovered = first_uncovered(populated);
    expect(uncovered.has_value() && *uncovered == "ck.brand_new_member_",
        "a populated member with no descriptor is named by the walk");
}

void open_and_refused_members_fail_by_name()
{
    const std::vector<std::string> open_populated { "clock.now", "kss.iokit_display_connections" };
    const auto open_uncovered = first_uncovered(open_populated);
    expect(open_uncovered.has_value() && *open_uncovered == "kss.iokit_display_connections",
        "a populated open member is named by the walk");
    const std::vector<std::string> refused { "clock.now", "kss.iokit_services" };
    const auto refused_uncovered = first_uncovered(refused);
    expect(refused_uncovered.has_value() && *refused_uncovered == "kss.iokit_services",
        "a populated refused member is named by the walk");
}

void the_first_uncovered_member_in_order_is_named()
{
    const std::vector<std::string> populated { "ck.new_first_", "kss.iokit_services", "ck.new_second_" };
    const auto uncovered = first_uncovered(populated);
    expect(uncovered.has_value() && *uncovered == "ck.new_first_",
        "the walk names the first uncovered member in the order it was populated");
}

}

int main()
{
    every_name_has_one_descriptor();
    every_class_is_counted();
    coverage_follows_the_class();
    only_saved_and_wired_members_are_covered();
    every_clock_descriptor_is_a_saved_row();
    covered_members_pass_the_walk();
    member_added_without_a_descriptor_fails_by_name();
    open_and_refused_members_fail_by_name();
    the_first_uncovered_member_in_order_is_named();

    if (failures != 0) {
        std::cerr << failures << " snapshot ledger checks failed\n";
        return 1;
    }
    std::cout << "snapshot ledger checks passed: " << members.size()
              << " members\n";
    return 0;
}
