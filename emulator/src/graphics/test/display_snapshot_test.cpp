// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "graphics/display.hpp"

#include "foundation/display_geometry.hpp"
#include "foundation/snapshot_io.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using emulator::DisplayGeometry;
using emulator::DisplayState;
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

constexpr DisplayGeometry geometry { 4, 3 };

std::vector<std::byte> save_display(const DisplayState& display)
{
    Writer out;
    display.save(out);
    return out.bytes();
}

std::vector<std::uint32_t> patterned_pixels()
{
    std::vector<std::uint32_t> pixels(geometry.pixel_count());
    for (std::size_t index = 0; index < pixels.size(); ++index)
        pixels[index] = 0xff00'0000U + static_cast<std::uint32_t>(index * 9U);
    return pixels;
}

void round_trip_keeps_the_frame_and_its_counters()
{
    DisplayState source(geometry);
    source.replace_pixels(patterned_pixels(), 7);
    source.present(7);
    source.set_powered_on(false);
    source.set_powered_on(true);
    const auto bytes = save_display(source);

    DisplayState restored(geometry);
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the display stream is consumed");
    expect(restored.snapshot().pixels == source.snapshot().pixels,
        "the displayed pixels survive the round trip");
    expect(restored.content_revision() == source.content_revision(),
        "the content revision survives the round trip");
    expect(restored.content_owner_process_id() ==
            source.content_owner_process_id(),
        "the content owner survives the round trip");
    expect(restored.presented_frames() == source.presented_frames(),
        "the presented frame count survives the round trip");
    expect(restored.powered_on() == source.powered_on(),
        "the power state survives the round trip");
    expect(save_display(restored) == bytes,
        "saving the restored display reproduces the same stream");
}

void powered_off_display_round_trips()
{
    DisplayState source(geometry);
    source.replace_pixels(patterned_pixels(), 3);
    source.set_powered_on(false);
    const auto bytes = save_display(source);

    DisplayState restored(geometry);
    Reader in { bytes };
    restored.load(in);
    expect(!restored.powered_on(), "a powered-off display stays off");
    expect(save_display(restored) == bytes,
        "a powered-off display saves to the same stream");
}

void geometry_mismatch_is_a_format_error()
{
    DisplayState source(geometry);
    source.replace_pixels(patterned_pixels(), 7);
    const auto bytes = save_display(source);

    DisplayState restored(DisplayGeometry { 3, 4 });
    bool threw = false;
    try {
        Reader in { bytes };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a display geometry that differs from the wiring is refused");
}

void truncated_stream_is_a_format_error()
{
    DisplayState source(geometry);
    source.replace_pixels(patterned_pixels(), 7);
    const auto bytes = save_display(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() - 1U) };

    DisplayState restored(geometry);
    bool threw = false;
    try {
        Reader in { truncated };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated display stream throws FormatError");
}

}

int main()
{
    round_trip_keeps_the_frame_and_its_counters();
    powered_off_display_round_trips();
    geometry_mismatch_is_a_format_error();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " display snapshot checks failed\n";
        return 1;
    }
    std::cout << "display snapshot checks passed\n";
    return 0;
}
