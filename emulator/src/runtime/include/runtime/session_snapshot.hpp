// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Frame a session snapshot with the identity of the rootfs it was taken from,
// so that a restore refuses a rootfs that has changed.

#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

#include "foundation/content_identity.hpp"

namespace emulator {

inline constexpr std::uint32_t session_snapshot_version = 1;

struct SessionSnapshotHeader {
    std::string device;
    std::string binary;
    std::uint64_t ticks { };
    ContentIdentity rootfs_manifest;

    friend bool operator==(const SessionSnapshotHeader&,
        const SessionSnapshotHeader&) = default;
};

struct SessionSnapshot {
    SessionSnapshotHeader header;
    std::vector<std::byte> body;
};

class RootfsMismatchError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

[[nodiscard]] ContentIdentity rootfs_manifest_identity(
    const std::filesystem::path& rootfs);

[[nodiscard]] std::vector<std::byte> encode_session_snapshot(
    const SessionSnapshot& snapshot);

[[nodiscard]] SessionSnapshot decode_session_snapshot(
    std::span<const std::byte> bytes);

void require_rootfs_identity(const SessionSnapshotHeader& header,
    const std::filesystem::path& rootfs);

}
