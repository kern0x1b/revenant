// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/snapshot_io.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::MemoryPermission;
using emulator::VmInheritance;
using emulator::snapshot::FormatError;
using emulator::snapshot::RefusedError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

constexpr std::size_t guest_page_size = 0x1000;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

std::vector<std::byte> save_space(const AddressSpace& space)
{
    Writer out;
    space.save(out);
    return out.bytes();
}

std::unique_ptr<AddressSpace> load_space(const std::vector<std::byte>& bytes)
{
    auto space = std::make_unique<AddressSpace>();
    space->set_backing_root(std::filesystem::temp_directory_path());
    Reader in { bytes };
    space->load(in);
    expect(in.at_end(), "the address space stream is consumed");
    return space;
}

std::vector<std::byte> patterned(std::size_t size, std::uint8_t seed)
{
    std::vector<std::byte> bytes(size);
    for (std::size_t index = 0; index < size; ++index)
        bytes[index] = static_cast<std::byte>(seed + index * 7U);
    return bytes;
}

bool same_region(const std::optional<AddressSpace::MappingRegion>& expected,
    const std::optional<AddressSpace::MappingRegion>& actual)
{
    if (!expected || !actual)
        return !expected && !actual;
    return expected->address == actual->address && expected->end == actual->end &&
           expected->permissions == actual->permissions &&
           expected->inheritance == actual->inheritance;
}

void round_trip_keeps_contents_and_regions()
{
    AddressSpace source;
    const auto read_write = MemoryPermission::Read | MemoryPermission::Write;
    const auto read_execute = MemoryPermission::Read | MemoryPermission::Execute;
    expect(source.map(0x1000, 0x4000, read_write), "map the data region");
    expect(source.map(0x10000, 0x2000, read_write), "map the code region");
    expect(source.map(0x20000, 0x1000, read_write), "map the untouched region");
    const auto data = patterned(0x4000, 0x11);
    const auto code = patterned(0x2000, 0x5a);
    expect(source.copy_in(0x1000, data), "write the data region");
    expect(source.copy_in(0x10000, code), "write the code region");
    expect(source.protect(0x1000, 0x1000, MemoryPermission::Read),
        "make the first data page read-only");
    expect(source.protect(0x10000, 0x2000, read_execute),
        "make the code region executable");
    expect(source.inherit(0x10000, 0x2000, VmInheritance::Share),
        "share the code region on fork");
    source.mark_translation_profile_stable(0x10000, 0x2000);

    const auto bytes = save_space(source);
    const auto restored = load_space(bytes);

    expect(restored->read_bytes(0x1000, 0x4000) == data,
        "data region bytes survive the round trip");
    expect(restored->read_bytes(0x10000, 0x2000) == code,
        "code region bytes survive the round trip");
    const auto untouched = restored->read_bytes(0x20000, 0x1000);
    expect(untouched && std::all_of(untouched->begin(), untouched->end(),
                            [](std::byte value) { return value == std::byte { }; }),
        "an unwritten region reads as zeros");
    expect(!restored->mapped(0x6000), "the gap stays unmapped");
    expect(restored->mapping_region_count() == source.mapping_region_count(),
        "the region count survives the round trip");
    for (const std::uint32_t probe : { 0x0U, 0x1000U, 0x2000U, 0x5000U,
             0x10000U, 0x12000U, 0x20000U, 0x21000U }) {
        expect(same_region(source.mapping_region_at_or_after(probe),
                   restored->mapping_region_at_or_after(probe)),
            "region at or after the probe address matches");
    }
    expect(!restored->accessible(0x1000, 1, MemoryPermission::Write),
        "a read-only page stays read-only");
    expect(restored->accessible(0x1000, 1, MemoryPermission::Read),
        "a read-only page stays readable");
    expect(restored->accessible(0x10000, 1, MemoryPermission::Execute),
        "an executable region stays executable");
    expect(restored->translation_profile_stable(0x10000, 0x2000),
        "the translation profile stays stable");
    expect(restored->executable_content_generation() ==
            source.executable_content_generation(),
        "the executable content generation survives");
    expect(restored->translation_profile_mapping_generation() ==
            source.translation_profile_mapping_generation(),
        "the translation profile generation survives");
    expect(save_space(*restored) == bytes,
        "saving the restored space reproduces the same stream");
}

void restored_space_is_independent_and_writable()
{
    AddressSpace source;
    expect(source.map(0x1000, 0x1000,
               MemoryPermission::Read | MemoryPermission::Write),
        "map the page");
    expect(source.write32(0x1000, 0x01020304U), "seed the page");
    const auto restored = load_space(save_space(source));

    expect(source.write32(0x1000, 0xaabbccddU), "write the source page");
    expect(restored->read32(0x1000) == 0x01020304U,
        "the restored page is not aliased to the source");
    expect(restored->write32(0x1004, 0x55667788U),
        "the restored page accepts writes");
    expect(restored->read32(0x1004) == 0x55667788U,
        "the restored write is visible");
}

void shared_writable_page_is_refused()
{
    AddressSpace space;
    expect(space.map(0x1000, 0x1000,
               MemoryPermission::Read | MemoryPermission::Write),
        "map the page");
    const auto shared = space.share_pages(0x1000, 0x1000);
    expect(shared.has_value(), "share the page");
    bool refused = false;
    std::string member;
    try {
        static_cast<void>(save_space(space));
    } catch (const RefusedError& error) {
        refused = true;
        member = error.member();
    }
    expect(refused, "a shared writable page is refused");
    expect(member == "memory.shared_writable",
        "the refusal names memory.shared_writable");
}

std::filesystem::path test_file_path()
{
    return std::filesystem::temp_directory_path() /
           "address_space_snapshot_test.bin";
}

std::vector<std::byte> write_test_file(
    const std::filesystem::path& path, std::uint8_t seed)
{
    const auto file = patterned(0x2000, seed);
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    output.write(reinterpret_cast<const char*>(file.data()),
        static_cast<std::streamsize>(file.size()));
    return file;
}

std::vector<std::byte> read_test_file(const std::filesystem::path& path)
{
    std::ifstream input(path, std::ios::binary);
    std::vector<std::byte> bytes;
    char value = 0;
    while (input.get(value))
        bytes.push_back(static_cast<std::byte>(value));
    return bytes;
}

void clean_file_pages_come_back_from_the_file()
{
    const auto path = test_file_path();
    const auto file = write_test_file(path, 0x3c);
    AddressSpace source;
    source.set_backing_root(std::filesystem::temp_directory_path());
    expect(source.map_file(0x30000, 0x2000, MemoryPermission::Read, path, 0),
        "map the file read-only");
    expect(source.read_bytes(0x30000, 0x2000) == file,
        "the source reads the file");
    const auto bytes = save_space(source);
    expect(bytes.size() < guest_page_size,
        "clean file pages are not stored in the snapshot");
    const auto restored = load_space(bytes);
    expect(restored->read_bytes(0x30000, 0x2000) == file,
        "a file-backed region reads its file after restore");
    expect(restored->materialized_page_counts().file_cached ==
            source.materialized_page_counts().file_cached,
        "file-cached pages stay file-cached");
    expect(save_space(*restored) == bytes,
        "saving the restored file mapping reproduces the same stream");
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
}

void changed_file_is_refused_on_restore()
{
    const auto path = test_file_path();
    static_cast<void>(write_test_file(path, 0x3c));
    AddressSpace source;
    source.set_backing_root(std::filesystem::temp_directory_path());
    expect(source.map_file(0x30000, 0x2000, MemoryPermission::Read, path, 0),
        "map the file read-only");
    const auto bytes = save_space(source);
    static_cast<void>(write_test_file(path, 0x4d));
    bool threw = false;
    try {
        static_cast<void>(load_space(bytes));
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a file that changed since the snapshot is refused");
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
}

void written_file_page_is_stored_and_the_file_is_untouched()
{
    const auto path = test_file_path();
    const auto file = write_test_file(path, 0x5e);
    AddressSpace source;
    source.set_backing_root(std::filesystem::temp_directory_path());
    expect(source.map_file(0x40000, 0x2000,
               MemoryPermission::Read | MemoryPermission::Write, path, 0),
        "map the file writable");
    expect(source.write32(0x40000, 0xcafebabeU), "write the first page");
    const auto bytes = save_space(source);
    expect(bytes.size() >= guest_page_size,
        "the written page is stored in the snapshot");
    const auto restored = load_space(bytes);
    expect(restored->read32(0x40000) == 0xcafebabeU,
        "the written page keeps its contents");
    expect(restored->read_bytes(0x41000, 0x1000) ==
            std::vector<std::byte>(file.begin() + 0x1000, file.end()),
        "the untouched page is read from the file");
    expect(read_test_file(path) == file, "the file on disk is not written");
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
}

template <typename T>
void write_little_endian(std::vector<std::byte>& bytes, std::size_t offset,
    T value)
{
    for (std::size_t index = 0; index < sizeof(T); ++index)
        bytes[offset + index] = static_cast<std::byte>(value >> (index * 8U));
}

template <typename T>
T read_little_endian(const std::vector<std::byte>& bytes, std::size_t offset)
{
    T value { };
    for (std::size_t index = 0; index < sizeof(T); ++index) {
        value |= static_cast<T>(static_cast<std::uint8_t>(bytes[offset + index]))
                 << (index * 8U);
    }
    return value;
}

void move_second_file_mapping(std::vector<std::byte>& bytes,
    const std::filesystem::path& path, std::uint32_t address,
    std::uint64_t end)
{
    std::vector<std::byte> needle;
    const auto relative =
        path.lexically_relative(std::filesystem::temp_directory_path());
    for (const char character : relative.string())
        needle.push_back(static_cast<std::byte>(character));
    const auto first = std::search(
        bytes.begin(), bytes.end(), needle.begin(), needle.end());
    if (first == bytes.end())
        throw std::logic_error { "the stream holds no file mapping record" };
    const auto second = std::search(
        first + 1, bytes.end(), needle.begin(), needle.end());
    if (second == bytes.end())
        throw std::logic_error { "the stream holds one file mapping record" };
    const auto name = static_cast<std::size_t>(second - bytes.begin());
    if (name < 28U ||
        read_little_endian<std::uint64_t>(bytes, name - 8U) != needle.size()) {
        throw std::logic_error { "the file mapping record layout changed" };
    }
    write_little_endian(bytes, name - 28U, address);
    write_little_endian(bytes, name - 24U, end);
}

void overlapping_file_mapping_is_refused_on_restore()
{
    const auto path = test_file_path();
    static_cast<void>(write_test_file(path, 0x6b));
    AddressSpace source;
    source.set_backing_root(std::filesystem::temp_directory_path());
    expect(source.map_file(0x30000, 0x2000, MemoryPermission::Read, path, 0),
        "map the first file range");
    expect(source.map_file(0x32000, 0x2000, MemoryPermission::Read, path, 0),
        "map the second file range");
    auto bytes = save_space(source);
    move_second_file_mapping(bytes, path, 0x31000, 0x33000);
    bool threw = false;
    std::string message;
    try {
        static_cast<void>(load_space(bytes));
    } catch (const FormatError& error) {
        threw = true;
        message = error.what();
    }
    expect(threw, "an overlapping file mapping is refused");
    expect(message == "snapshot holds a bad file mapping",
        "the refusal names the bad file mapping");
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
}

void truncated_stream_is_a_format_error()
{
    AddressSpace source;
    expect(source.map(0x1000, 0x2000,
               MemoryPermission::Read | MemoryPermission::Write),
        "map the region");
    expect(source.copy_in(0x1000, patterned(0x2000, 0x21)),
        "write the region");
    const auto bytes = save_space(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() / 2) };
    bool threw = false;
    try {
        static_cast<void>(load_space(truncated));
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated address space throws FormatError");
}

}

int main()
{
    round_trip_keeps_contents_and_regions();
    restored_space_is_independent_and_writable();
    shared_writable_page_is_refused();
    clean_file_pages_come_back_from_the_file();
    changed_file_is_refused_on_restore();
    written_file_page_is_stored_and_the_file_is_untouched();
    overlapping_file_mapping_is_refused_on_restore();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " address space snapshot checks failed\n";
        return 1;
    }
    std::cout << "address space snapshot checks passed\n";
    return 0;
}
