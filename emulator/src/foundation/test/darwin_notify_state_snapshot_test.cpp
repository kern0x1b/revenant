// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/darwin_notify_state_hle.hpp"
#include "foundation/output.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/snapshot_member.hpp"
#include "foundation/userland_hle.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::DarwinNotifyStateAbi;
using emulator::DarwinNotifyStateHle;
using emulator::Output;
using emulator::UserlandHleRegistry;
using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

struct Wiring {
    std::ostringstream log;
    Output output { log };
    AddressSpace memory;
    UserlandHleRegistry registry { memory, output };
    DarwinNotifyStateHle notify { registry };
};

void wire_providers(DarwinNotifyStateHle& notify)
{
    notify.set_provider("com.apple.system.locale", [] { return 1U; });
    notify.set_provider("com.apple.system.timezone", [] { return 2U; });
    notify.set_abi(DarwinNotifyStateAbi::BootstrapAwareServerTokens);
}

std::vector<std::byte> save_notify(const DarwinNotifyStateHle& notify)
{
    Writer out;
    notify.save(out);
    return out.bytes();
}

void round_trip_keeps_the_wired_state()
{
    auto source = std::make_unique<Wiring>();
    wire_providers(source->notify);
    const auto bytes = save_notify(source->notify);

    auto restored = std::make_unique<Wiring>();
    wire_providers(restored->notify);
    Reader in { bytes };
    restored->notify.load(in);
    expect(in.at_end(), "the notify stream is consumed");
    expect(save_notify(restored->notify) == bytes,
        "saving the restored notify state reproduces the same stream");
}

void provider_mismatch_is_a_format_error()
{
    auto source = std::make_unique<Wiring>();
    wire_providers(source->notify);
    const auto bytes = save_notify(source->notify);

    auto restored = std::make_unique<Wiring>();
    restored->notify.set_provider("com.apple.system.locale", [] { return 1U; });
    restored->notify.set_abi(DarwinNotifyStateAbi::BootstrapAwareServerTokens);
    bool threw = false;
    try {
        Reader in { bytes };
        restored->notify.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a provider set that differs from the wiring is refused");
}

void abi_mismatch_is_a_format_error()
{
    auto source = std::make_unique<Wiring>();
    wire_providers(source->notify);
    const auto bytes = save_notify(source->notify);

    auto restored = std::make_unique<Wiring>();
    restored->notify.set_provider("com.apple.system.locale", [] { return 1U; });
    restored->notify.set_provider("com.apple.system.timezone", [] { return 2U; });
    bool threw = false;
    try {
        Reader in { bytes };
        restored->notify.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "an ABI that differs from the wiring is refused");
}

void truncated_stream_is_a_format_error()
{
    auto source = std::make_unique<Wiring>();
    wire_providers(source->notify);
    const auto bytes = save_notify(source->notify);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() - 1U) };

    auto restored = std::make_unique<Wiring>();
    wire_providers(restored->notify);
    bool threw = false;
    try {
        Reader in { truncated };
        restored->notify.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated notify stream throws FormatError");
}

void wired_layout_is_fixed()
{
    auto source = std::make_unique<Wiring>();
    wire_providers(source->notify);
    Writer expected;
    emulator::snapshot::save(expected, std::vector<std::string> {
        "com.apple.system.locale", "com.apple.system.timezone" });
    emulator::snapshot::save(expected, DarwinNotifyStateAbi::BootstrapAwareServerTokens);
    emulator::snapshot::save(expected, std::map<std::uint32_t, std::string> {});
    emulator::snapshot::save(expected, std::set<std::uint32_t> {});
    emulator::snapshot::save(expected, static_cast<std::uint32_t>(0x4000'0000U));
    emulator::snapshot::save(expected, std::set<std::pair<std::uint32_t, std::uint32_t>> {});
    emulator::snapshot::save(expected, static_cast<std::uint64_t>(0));
    expect(save_notify(source->notify) == expected.bytes(),
        "the notify state saves its members in their fixed order");
}

void descriptors_name_the_saved_fields_in_order()
{
    std::vector<std::string> names;
    for (const auto& member : DarwinNotifyStateHle::snapshot_members())
        names.emplace_back(member.name);
    const std::vector<std::string> expected {
        "notify.providers_",
        "notify.abi_",
        "notify.token_names_",
        "notify.virtual_tokens_",
        "notify.next_virtual_token_",
        "notify.owned_registrations_",
        "bus.registrations",
    };
    expect(names == expected, "the notify members are named in save order");
}

void is_default_follows_the_saved_fields()
{
    auto wired = std::make_unique<Wiring>();
    wire_providers(wired->notify);
    const auto& members = DarwinNotifyStateHle::snapshot_members();
    expect(!members[0].is_default(wired->notify), "wired providers are not default");
    expect(!members[1].is_default(wired->notify), "a bootstrap-aware ABI is not default");
    expect(members[2].is_default(wired->notify), "no token names are default");
    expect(members[3].is_default(wired->notify), "no virtual tokens are default");
    expect(!members[4].is_default(wired->notify), "the first virtual token is not zero");
    expect(members[5].is_default(wired->notify), "no owned registrations are default");
    expect(members[6].is_default(wired->notify), "no bus registrations are default");
}

void populated_members_name_the_fields_that_hold_state()
{
    auto wired = std::make_unique<Wiring>();
    wire_providers(wired->notify);
    std::vector<std::string> populated;
    emulator::snapshot::note_populated_members(
        populated, wired->notify, DarwinNotifyStateHle::snapshot_members());
    const std::vector<std::string> expected {
        "notify.providers_", "notify.abi_", "notify.next_virtual_token_" };
    expect(populated == expected,
        "a wired notify state populates its providers, ABI and next virtual token");
}

void registration_round_trip_republishes_the_bus()
{
    auto wired = std::make_unique<Wiring>();
    wire_providers(wired->notify);
    wired->notify.set_notification_dispatcher(
        [](std::uint32_t, std::uint32_t, std::uint32_t) { });
    Writer stream;
    emulator::snapshot::save(stream, std::vector<std::string> {
        "com.apple.system.locale", "com.apple.system.timezone" });
    emulator::snapshot::save(stream, DarwinNotifyStateAbi::BootstrapAwareServerTokens);
    emulator::snapshot::save(stream, std::map<std::uint32_t, std::string> { { 1U, "com.a" } });
    emulator::snapshot::save(stream, std::set<std::uint32_t> {});
    emulator::snapshot::save(stream, static_cast<std::uint32_t>(0x4000'0000U));
    emulator::snapshot::save(stream,
        std::set<std::pair<std::uint32_t, std::uint32_t>> { { 10U, 1U } });
    emulator::snapshot::save(stream, static_cast<std::uint64_t>(1));
    emulator::snapshot::save(stream, std::pair<std::uint32_t, std::uint32_t> { 10U, 1U });
    emulator::snapshot::save(stream, std::string { "com.a" });
    emulator::snapshot::save(stream, static_cast<std::uint32_t>(77U));
    const auto bytes = stream.bytes();

    Reader in { bytes };
    wired->notify.load(in);
    expect(in.at_end(), "the notify stream with a registration is consumed");
    expect(save_notify(wired->notify) == bytes,
        "a restored registration is saved again in the same stream");
}

}

int main()
{
    round_trip_keeps_the_wired_state();
    provider_mismatch_is_a_format_error();
    abi_mismatch_is_a_format_error();
    truncated_stream_is_a_format_error();
    wired_layout_is_fixed();
    descriptors_name_the_saved_fields_in_order();
    is_default_follows_the_saved_fields();
    populated_members_name_the_fields_that_hold_state();
    registration_round_trip_republishes_the_bus();
    if (failures != 0) {
        std::cerr << failures << " darwin notify snapshot checks failed\n";
        return 1;
    }
    std::cout << "darwin notify snapshot checks passed\n";
    return 0;
}
