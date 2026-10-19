// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Read baseband replay fixtures and write transport capture files.

#include "kernel/baseband_replay.hpp"

#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace shade::bsd::baseband_device {

std::vector<std::byte> load_replay_file(const std::filesystem::path& path)
{
    std::ifstream stream { path, std::ios::binary };
    if (!stream) {
        throw std::runtime_error { "cannot open baseband replay input: " +
                                   path.string() };
    }
    stream.seekg(0, std::ios::end);
    const auto end = stream.tellg();
    if (end < 0 || static_cast<std::uintmax_t>(end) > maximum_replay_bytes) {
        throw std::runtime_error { "baseband replay input exceeds the bounded "
                                   "replay budget: " +
                                   path.string() };
    }
    const auto size = static_cast<std::size_t>(end);
    stream.seekg(0, std::ios::beg);
    std::vector<std::byte> bytes(size);
    if (size != 0) {
        stream.read(reinterpret_cast<char*>(bytes.data()),
            static_cast<std::streamsize>(size));
    }
    if (!stream || stream.gcount() != static_cast<std::streamsize>(size)) {
        throw std::runtime_error { "cannot read baseband replay input: " +
                                   path.string() };
    }
    return bytes;
}

void write_capture_file(
    const std::filesystem::path& path, std::span<const std::byte> bytes)
{
    std::ofstream stream { path, std::ios::binary | std::ios::trunc };
    if (!stream) {
        throw std::runtime_error { "cannot open baseband capture output: " +
                                   path.string() };
    }
    stream.write(reinterpret_cast<const char*>(bytes.data()),
        static_cast<std::streamsize>(bytes.size()));
    if (!stream) {
        throw std::runtime_error { "cannot write baseband capture output: " +
                                   path.string() };
    }
}

} // namespace shade::bsd::baseband_device
