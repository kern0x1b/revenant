// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "media/core_audio_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/snapshot_member.hpp"
#include "foundation/userland_hle.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::CoreAudioHle;
using emulator::Output;
using emulator::UserlandHleRegistry;
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
    CoreAudioHle audio { registry, nullptr };
};

std::vector<std::byte> save_audio(const CoreAudioHle& audio)
{
    Writer out;
    audio.save(out);
    return out.bytes();
}

void fresh_layout_is_fixed()
{
    const Wiring wiring;
    Writer expected;
    emulator::snapshot::save(expected, std::uint32_t { 1024U });
    emulator::snapshot::save(expected, std::uint32_t { 0x7000'0000U });
    expect(save_audio(wiring.audio) == expected.bytes(),
        "the Core Audio state saves its buffer size, then its next native I/O proc id");
}

void descriptors_name_the_saved_fields_in_order()
{
    std::vector<std::string> names;
    for (const auto& member : CoreAudioHle::snapshot_members())
        names.emplace_back(member.name);
    const std::vector<std::string> expected {
        "coreaudio.buffer_frame_size_",
        "coreaudio.next_native_io_proc_id_",
    };
    expect(names == expected, "the Core Audio members are named in save order");
}

void populated_members_name_the_fields_that_hold_state()
{
    const Wiring wiring;
    std::vector<std::string> populated;
    emulator::snapshot::note_populated_members(
        populated, wiring.audio, CoreAudioHle::snapshot_members());
    const std::vector<std::string> expected {
        "coreaudio.buffer_frame_size_",
        "coreaudio.next_native_io_proc_id_",
    };
    expect(populated == expected,
        "a fresh Core Audio state populates its buffer size and its next I/O proc id");
}

void restored_fields_are_saved_again_in_the_same_stream()
{
    Writer stream;
    emulator::snapshot::save(stream, std::uint32_t { 512U });
    emulator::snapshot::save(stream, std::uint32_t { 0x7000'0005U });
    const auto bytes = stream.bytes();

    Wiring restored;
    Reader in { bytes };
    restored.audio.load(in);
    expect(in.at_end(), "the Core Audio stream is consumed");
    expect(save_audio(restored.audio) == bytes,
        "a restored Core Audio state is saved again in the same stream");
}

void truncated_stream_is_a_format_error()
{
    const Wiring wiring;
    const auto bytes = save_audio(wiring.audio);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() - 1U) };

    Wiring restored;
    bool threw = false;
    try {
        Reader in { truncated };
        restored.audio.load(in);
    } catch (const emulator::snapshot::FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated Core Audio stream throws FormatError");
}

}

int main()
{
    fresh_layout_is_fixed();
    descriptors_name_the_saved_fields_in_order();
    populated_members_name_the_fields_that_hold_state();
    restored_fields_are_saved_again_in_the_same_stream();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " Core Audio snapshot checks failed\n";
        return 1;
    }
    std::cout << "Core Audio snapshot checks passed\n";
    return 0;
}
