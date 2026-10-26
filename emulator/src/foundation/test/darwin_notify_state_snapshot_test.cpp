// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/darwin_notify_state_hle.hpp"
#include "foundation/output.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/userland_hle.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
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

}

int main()
{
    round_trip_keeps_the_wired_state();
    provider_mismatch_is_a_format_error();
    abi_mismatch_is_a_format_error();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " darwin notify snapshot checks failed\n";
        return 1;
    }
    std::cout << "darwin notify snapshot checks passed\n";
    return 0;
}
