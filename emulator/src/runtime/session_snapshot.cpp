// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "runtime/session_snapshot.hpp"

#include <sys/stat.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <map>
#include <span>
#include <stdexcept>
#include <string>
#include <system_error>
#include <utility>
#include <vector>

#include "foundation/snapshot_io.hpp"

namespace emulator {

namespace {

namespace fs = std::filesystem;

constexpr std::array<char, 8> magic { 'R', 'E', 'V', 'S', 'N', 'A', 'P', '\0' };
constexpr std::array<char, 8> cache_magic { 'R', 'E', 'V', 'M', 'A', 'N', 'I', '\0' };

struct FileIdentity {
    std::uint64_t size { };
    std::uint64_t modified_seconds { };
    std::uint64_t modified_nanoseconds { };
    std::uint64_t changed_seconds { };
    std::uint64_t changed_nanoseconds { };
    std::uint64_t inode { };

    friend bool operator==(const FileIdentity&, const FileIdentity&) = default;
};

struct CachedDigest {
    FileIdentity identity;
    ContentIdentity digest;
};

using DigestCache = std::map<std::string, CachedDigest>;

struct ManifestWalk {
    std::string text;
    DigestCache digests;
};

FileIdentity identity_of(const fs::path& path)
{
    struct stat info { };
    if (::stat(path.c_str(), &info) != 0)
        throw fs::filesystem_error { "cannot stat rootfs entry", path,
            std::error_code { errno, std::generic_category() } };
    return { static_cast<std::uint64_t>(info.st_size),
        static_cast<std::uint64_t>(info.st_mtimespec.tv_sec),
        static_cast<std::uint64_t>(info.st_mtimespec.tv_nsec),
        static_cast<std::uint64_t>(info.st_ctimespec.tv_sec),
        static_cast<std::uint64_t>(info.st_ctimespec.tv_nsec),
        static_cast<std::uint64_t>(info.st_ino) };
}

ContentIdentity digest_of(const fs::path& path)
{
    const auto digest = sha256_file(path);
    if (!digest)
        throw std::runtime_error { "cannot read rootfs file " + path.string() };
    return *digest;
}

ManifestWalk walk_rootfs(const fs::path& rootfs, const DigestCache& previous)
{
    std::vector<std::string> lines;
    ManifestWalk walk;
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
            const auto identity = identity_of(entry.path());
            const auto cached = previous.find(relative);
            const auto digest = cached != previous.end() &&
                    cached->second.identity == identity
                ? cached->second.digest
                : digest_of(entry.path());
            walk.digests[relative] = { identity, digest };
            lines.push_back("f " + digest.hex() + " " +
                std::to_string(identity.size) + " " + relative);
        } else {
            lines.push_back("o " + relative);
        }
    }
    std::sort(lines.begin(), lines.end());
    for (const auto& line : lines) {
        walk.text += line;
        walk.text += '\n';
    }
    return walk;
}

DigestCache load_digest_cache(const fs::path& cache_file)
{
    DigestCache cache;
    if (cache_file.empty())
        return cache;
    std::ifstream stream { cache_file, std::ios::binary };
    if (!stream)
        return cache;
    const std::string text { std::istreambuf_iterator<char> { stream }, {} };
    const auto* data = reinterpret_cast<const std::byte*>(text.data());
    try {
        snapshot::Reader in { std::span<const std::byte> { data, text.size() } };
        if (!std::ranges::equal(in.raw(cache_magic.size()),
                std::as_bytes(std::span { cache_magic })))
            return {};
        std::uint32_t version { };
        snapshot::load(in, version);
        if (version != session_snapshot_version)
            return {};
        std::uint64_t count { };
        snapshot::load(in, count);
        for (std::uint64_t index = 0; index < count; ++index) {
            std::string path;
            CachedDigest cached;
            snapshot::load(in, path);
            snapshot::load(in, cached.identity.size);
            snapshot::load(in, cached.identity.modified_seconds);
            snapshot::load(in, cached.identity.modified_nanoseconds);
            snapshot::load(in, cached.identity.changed_seconds);
            snapshot::load(in, cached.identity.changed_nanoseconds);
            snapshot::load(in, cached.identity.inode);
            snapshot::load(in, cached.digest.digest);
            cache.emplace(std::move(path), cached);
        }
        if (!in.at_end())
            return {};
    } catch (const snapshot::FormatError&) {
        return {};
    }
    return cache;
}

void store_digest_cache(const fs::path& cache_file, const DigestCache& cache)
{
    if (cache_file.empty())
        return;
    snapshot::Writer out;
    out.raw(std::as_bytes(std::span { cache_magic }));
    snapshot::save(out, session_snapshot_version);
    snapshot::save(out, static_cast<std::uint64_t>(cache.size()));
    for (const auto& [path, cached] : cache) {
        snapshot::save(out, path);
        snapshot::save(out, cached.identity.size);
        snapshot::save(out, cached.identity.modified_seconds);
        snapshot::save(out, cached.identity.modified_nanoseconds);
        snapshot::save(out, cached.identity.changed_seconds);
        snapshot::save(out, cached.identity.changed_nanoseconds);
        snapshot::save(out, cached.identity.inode);
        snapshot::save(out, cached.digest.digest);
    }
    const auto temporary = fs::path { cache_file }.concat(".tmp");
    {
        std::ofstream stream { temporary, std::ios::binary | std::ios::trunc };
        if (!stream)
            return;
        stream.write(reinterpret_cast<const char*>(out.bytes().data()),
            static_cast<std::streamsize>(out.bytes().size()));
        if (!stream)
            return;
    }
    std::error_code error;
    fs::rename(temporary, cache_file, error);
}

}

ContentIdentity rootfs_manifest_identity(
    const fs::path& rootfs, const fs::path& cache_file)
{
    const auto walk = walk_rootfs(rootfs, load_digest_cache(cache_file));
    store_digest_cache(cache_file, walk.digests);
    return sha256(std::as_bytes(std::span { walk.text }));
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
    const fs::path& rootfs, const fs::path& cache_file)
{
    const auto actual = rootfs_manifest_identity(rootfs, cache_file);
    if (actual == header.rootfs_manifest)
        return;
    throw RootfsMismatchError { "snapshot was taken from a different rootfs: "
        "its manifest is " + header.rootfs_manifest.hex() + " but " +
        rootfs.string() + " has " + actual.hex() };
}

}
