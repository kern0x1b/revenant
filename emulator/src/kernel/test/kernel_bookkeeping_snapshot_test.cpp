// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "foundation/snapshot_io.hpp"
#include "kernel/kernel.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::CompatibilityKernel;
using emulator::Output;
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

struct Machine {
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    CompatibilityKernel kernel { memory, output };
};

std::vector<std::byte> save_bookkeeping(const CompatibilityKernel& kernel)
{
    Writer out;
    kernel.save_kernel_bookkeeping(out);
    return out.bytes();
}

void populate(CompatibilityKernel& kernel)
{
    kernel.seed_random(0x1234'5678U);
    expect(kernel.set_virtual_processor_count(3),
        "three virtual processors are accepted");
    kernel.set_process_image("/Applications/Snapshot.app/Snapshot");
    kernel.sample_load_average(2);
}

void round_trip_restores_the_bookkeeping()
{
    Machine source;
    populate(source.kernel);
    const auto bytes = save_bookkeeping(source.kernel);

    Machine restored;
    expect(save_bookkeeping(restored.kernel) != bytes,
        "a fresh kernel saves differently from the populated one");
    Reader in { bytes };
    restored.kernel.load_kernel_bookkeeping(in);
    expect(in.at_end(), "the bookkeeping stream is consumed");
    expect(save_bookkeeping(restored.kernel) == bytes,
        "saving the restored kernel reproduces the same stream");
}

void truncated_stream_is_a_format_error()
{
    Machine source;
    populate(source.kernel);
    const auto bytes = save_bookkeeping(source.kernel);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() / 2) };
    Machine restored;
    bool threw = false;
    try {
        Reader in { truncated };
        restored.kernel.load_kernel_bookkeeping(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated bookkeeping stream throws FormatError");
}

}

int main()
{
    round_trip_restores_the_bookkeeping();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " kernel bookkeeping snapshot checks failed\n";
        return 1;
    }
    std::cout << "kernel bookkeeping snapshot checks passed\n";
    return 0;
}
