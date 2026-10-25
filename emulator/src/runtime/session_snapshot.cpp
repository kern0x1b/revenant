// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "runtime/session_snapshot.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <string>
#include <utility>

#include "foundation/snapshot_io.hpp"

namespace emulator {

namespace {

constexpr std::array<char, 8> magic { 'R', 'E', 'V', 'S', 'N', 'A', 'P', '\0' };

std::string manifest_text(const std::filesystem::path& rootfs)
{
    namespace fs = std::filesystem;
    std::vector<std::string> lines;
    for (const auto& entry : fs::recursive_directory_iterator(rootfs)) {
        const auto relative =
            entry.path().lexically_relative(rootfs).generic_string();
        const auto status = entry.symlink_status();
        if (fs::is_symlink(status)) {
            lines.push_back("l " + relative + " -> " +
                fs::read_symlink(entry.path()).generic_string());
        } else if (fs::is_directory(status)) {
            lines.push_back("d " + relative);
        } else if (fs::is_regular_file(status)) {
            lines.push_back("f " + std::to_string(fs::file_size(entry.path())) +
                " " + relative);
        } else {
            lines.push_back("o " + relative);
        }
    }
    std::sort(lines.begin(), lines.end());
    std::string text;
    for (const auto& line : lines) {
        text += line;
        text += '\n';
    }
    return text;
}

}

ContentIdentity rootfs_manifest_identity(const std::filesystem::path& rootfs)
{
    const auto text = manifest_text(rootfs);
    return sha256(std::as_bytes(std::span { text }));
}

std::vector<std::byte> encode_session_snapshot(const SessionSnapshot& snapshot)
{
    snapshot::Writer out;
    out.raw(std::as_bytes(std::span { magic }));
    snapshot::save(out, session_snapshot_version);
    snapshot::save(out, snapshot.header.device);
    snapshot::save(out, snapshot.header.binary);
    snapshot::save(out, snapshot.header.ticks);
    snapshot::save(out, snapshot.header.rootfs_manifest.digest);
    snapshot::save(out, static_cast<std::uint64_t>(snapshot.body.size()));
    out.raw(snapshot.body);
    return std::move(out.bytes());
}

SessionSnapshot decode_session_snapshot(std::span<const std::byte> bytes)
{
    snapshot::Reader in { bytes };
    if (!std::ranges::equal(in.raw(magic.size()),
            std::as_bytes(std::span { magic })))
        throw snapshot::FormatError { "not a session snapshot" };
    std::uint32_t version { };
    snapshot::load(in, version);
    if (version != session_snapshot_version)
        throw snapshot::FormatError { "session snapshot version " +
            std::to_string(version) + " is not supported" };
    SessionSnapshot result;
    snapshot::load(in, result.header.device);
    snapshot::load(in, result.header.binary);
    snapshot::load(in, result.header.ticks);
    snapshot::load(in, result.header.rootfs_manifest.digest);
    std::uint64_t body_size { };
    snapshot::load(in, body_size);
    const auto body = in.raw(body_size);
    result.body.assign(body.begin(), body.end());
    if (!in.at_end())
        throw snapshot::FormatError { "session snapshot has trailing bytes" };
    return result;
}

void require_rootfs_identity(const SessionSnapshotHeader& header,
    const std::filesystem::path& rootfs)
{
    const auto actual = rootfs_manifest_identity(rootfs);
    if (actual == header.rootfs_manifest)
        return;
    throw RootfsMismatchError { "snapshot was taken from a different rootfs: "
        "its manifest is " + header.rootfs_manifest.hex() + " but " +
        rootfs.string() + " has " + actual.hex() };
}

}
