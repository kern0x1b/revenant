// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "graphics/surface_store.hpp"

#include "foundation/address_space.hpp"
#include "foundation/snapshot_io.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::MemoryPermission;
using emulator::SurfaceStore;
using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::RefusedError;
using emulator::snapshot::Writer;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

std::vector<std::byte> save_store(const SurfaceStore& store)
{
    Writer out;
    store.save(out);
    return out.bytes();
}

void empty_store_round_trip()
{
    const SurfaceStore source;
    const auto bytes = save_store(source);
    SurfaceStore restored;
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the surface store stream is consumed");
    expect(save_store(restored) == bytes,
        "saving the restored surface store reproduces the same stream");
}

void identifiers_survive_the_round_trip()
{
    SurfaceStore source;
    static_cast<void>(source.allocate_identifier());
    static_cast<void>(source.allocate_identifier());
    const auto bytes = save_store(source);

    SurfaceStore restored;
    Reader in { bytes };
    restored.load(in);
    expect(restored.publication_watermark() == source.publication_watermark(),
        "the publication watermark survives the round trip");
    expect(restored.allocate_identifier() == source.allocate_identifier(),
        "the next identifier survives the round trip");
}

void published_backing_is_refused()
{
    AddressSpace memory;
    expect(memory.map(0x20000, 0x1000,
               MemoryPermission::Read | MemoryPermission::Write),
        "map the surface pages");
    SurfaceStore store;
    SurfaceStore::Backing backing;
    backing.id = store.allocate_identifier();
    backing.base = 0x20000;
    backing.allocation_size = 0x1000;
    backing.width = 16;
    backing.height = 16;
    backing.bytes_per_row = 64;
    backing.pixel_format = emulator::surface_pixel_format_bgra;
    expect(store.publish(memory, backing), "publish a surface backing");

    bool refused = false;
    std::string member;
    try {
        static_cast<void>(save_store(store));
    } catch (const RefusedError& error) {
        refused = true;
        member = error.member();
    }
    expect(refused, "a published surface backing is refused");
    expect(member == "surface.backings",
        "the refusal names surface.backings");
}

void truncated_stream_is_a_format_error()
{
    SurfaceStore source;
    static_cast<void>(source.allocate_identifier());
    const auto bytes = save_store(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() - 1U) };

    SurfaceStore restored;
    bool threw = false;
    try {
        Reader in { truncated };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated surface store stream throws FormatError");
}

}

int main()
{
    empty_store_round_trip();
    identifiers_survive_the_round_trip();
    published_backing_is_refused();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " surface store snapshot checks failed\n";
        return 1;
    }
    std::cout << "surface store snapshot checks passed\n";
    return 0;
}
