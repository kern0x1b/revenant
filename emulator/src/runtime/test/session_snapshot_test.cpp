// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "runtime/session_snapshot.hpp"

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "foundation/snapshot_io.hpp"

namespace {

namespace fs = std::filesystem;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

fs::path scratch_root()
{
    return fs::temp_directory_path() / "revenant-session-snapshot-test";
}

void write_file(const fs::path& path, const std::string& text)
{
    fs::create_directories(path.parent_path());
    std::ofstream out { path, std::ios::binary };
    out << text;
}

fs::path make_rootfs(const fs::path& root)
{
    const auto rootfs = root / "rootfs";
    write_file(rootfs / "usr" / "bin" / "minimal", "minimal guest");
    write_file(rootfs / "etc" / "hosts", "127.0.0.1 localhost");
    fs::create_directories(rootfs / "var" / "empty");
    fs::create_symlink("/usr/bin/minimal", rootfs / "bin-link");
    return rootfs;
}

std::vector<std::byte> bytes_of(const std::string& text)
{
    std::vector<std::byte> result;
    for (const char character : text)
        result.push_back(static_cast<std::byte>(character));
    return result;
}

emulator::SessionSnapshot sample_snapshot(const fs::path& rootfs)
{
    emulator::SessionSnapshot snapshot;
    snapshot.header.device = "iPhone4,1";
    snapshot.header.binary = "/usr/local/bin/minimal";
    snapshot.header.ticks = 4'288'321;
    snapshot.header.rootfs_manifest = emulator::rootfs_manifest_identity(rootfs);
    snapshot.body = bytes_of("kernel state");
    return snapshot;
}

template <typename Action> bool throws_format_error(Action action)
{
    try {
        action();
    } catch (const emulator::snapshot::FormatError&) {
        return true;
    } catch (...) {
    }
    return false;
}

void round_trip_restores_the_header_and_body(const fs::path& rootfs)
{
    const auto original = sample_snapshot(rootfs);
    const auto bytes = emulator::encode_session_snapshot(original);
    const auto restored = emulator::decode_session_snapshot(bytes);
    expect(restored.header == original.header, "header round trip");
    expect(restored.body == original.body, "body round trip");
    expect(emulator::encode_session_snapshot(restored) == bytes,
        "encode, decode and encode reproduce the same bytes");
}

void rejects_foreign_and_damaged_streams(const fs::path& rootfs)
{
    const auto bytes = emulator::encode_session_snapshot(sample_snapshot(rootfs));

    auto foreign = bytes;
    foreign[0] = static_cast<std::byte>('X');
    expect(throws_format_error([&] {
        return emulator::decode_session_snapshot(foreign);
    }), "a stream without the magic is rejected");

    auto newer = bytes;
    newer[8] = static_cast<std::byte>(emulator::session_snapshot_version + 1U);
    expect(throws_format_error([&] {
        return emulator::decode_session_snapshot(newer);
    }), "an unsupported version is rejected");

    const std::vector<std::byte> truncated(bytes.begin(), bytes.end() - 1);
    expect(throws_format_error([&] {
        return emulator::decode_session_snapshot(truncated);
    }), "a truncated stream is rejected");

    auto trailing = bytes;
    trailing.push_back(std::byte { 0 });
    expect(throws_format_error([&] {
        return emulator::decode_session_snapshot(trailing);
    }), "trailing bytes are rejected");
}

void manifest_follows_the_tree_not_the_timestamps(const fs::path& root)
{
    const auto rootfs = make_rootfs(root);
    const auto identity = emulator::rootfs_manifest_identity(rootfs);
    expect(emulator::rootfs_manifest_identity(rootfs) == identity,
        "the manifest is stable for an unchanged rootfs");

    fs::last_write_time(rootfs / "etc" / "hosts",
        fs::last_write_time(rootfs / "etc" / "hosts") + std::chrono::hours { 24 });
    expect(emulator::rootfs_manifest_identity(rootfs) == identity,
        "a copy with new timestamps keeps its manifest");

    write_file(rootfs / "etc" / "hosts", "127.0.0.1 localhost and more");
    expect(emulator::rootfs_manifest_identity(rootfs) != identity,
        "a changed file size changes the manifest");

    write_file(rootfs / "etc" / "hosts", "127.0.0.1 localhost");
    expect(emulator::rootfs_manifest_identity(rootfs) == identity,
        "restoring the file restores the manifest");

    write_file(rootfs / "etc" / "motd", "hello");
    expect(emulator::rootfs_manifest_identity(rootfs) != identity,
        "an added file changes the manifest");
    fs::remove(rootfs / "etc" / "motd");

    fs::remove(rootfs / "bin-link");
    fs::create_symlink("/usr/bin/other", rootfs / "bin-link");
    expect(emulator::rootfs_manifest_identity(rootfs) != identity,
        "a changed symlink target changes the manifest");
}

void same_size_edit_with_restored_timestamp_is_caught(const fs::path& root)
{
    const auto rootfs = make_rootfs(root);
    const auto file = rootfs / "usr" / "bin" / "minimal";
    const auto cache = root / "manifest.cache";
    const auto before = emulator::rootfs_manifest_identity(rootfs, cache);
    expect(fs::exists(cache), "the manifest cache is written");

    const auto timestamp = fs::last_write_time(file);
    write_file(file, "minimal gueSt");
    fs::last_write_time(file, timestamp);
    expect(emulator::rootfs_manifest_identity(rootfs, cache) !=
            before,
        "a same-size edit with its timestamp restored is caught through the cache");
    expect(emulator::rootfs_manifest_identity(rootfs) ==
            emulator::rootfs_manifest_identity(rootfs, cache),
        "the cached manifest matches an uncached one");
}

void corrupt_manifest_cache_is_ignored(const fs::path& root)
{
    const auto rootfs = make_rootfs(root);
    const auto cache = root / "manifest.cache";
    const auto expected = emulator::rootfs_manifest_identity(rootfs);
    write_file(cache, "not a cache");
    expect(emulator::rootfs_manifest_identity(rootfs, cache) == expected,
        "a corrupt manifest cache is ignored");
    expect(emulator::rootfs_manifest_identity(rootfs, cache) == expected,
        "a manifest cache rewritten after corruption is used again");
}

void refuses_a_changed_rootfs(const fs::path& root)
{
    const auto rootfs = make_rootfs(root);
    const auto header = sample_snapshot(rootfs).header;
    emulator::require_rootfs_identity(header, rootfs);

    write_file(rootfs / "usr" / "bin" / "minimal", "a rebuilt guest binary");
    bool refused = false;
    try {
        emulator::require_rootfs_identity(header, rootfs);
    } catch (const emulator::RootfsMismatchError& error) {
        refused = std::string { error.what() }.find("different rootfs") !=
            std::string::npos;
    }
    expect(refused, "a restore against a changed rootfs is refused by name");
}

}

int main()
{
    const auto root = scratch_root();
    fs::remove_all(root);
    const auto rootfs = make_rootfs(root);

    round_trip_restores_the_header_and_body(rootfs);
    rejects_foreign_and_damaged_streams(rootfs);
    manifest_follows_the_tree_not_the_timestamps(root / "timestamps");
    same_size_edit_with_restored_timestamp_is_caught(root / "same-size");
    corrupt_manifest_cache_is_ignored(root / "corrupt");
    refuses_a_changed_rootfs(root / "changed");

    fs::remove_all(root);
    if (failures != 0) {
        std::cerr << failures << " session snapshot checks failed\n";
        return 1;
    }
    std::cout << "session snapshot checks passed\n";
    return 0;
}
