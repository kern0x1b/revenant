// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/jit_artifact.hpp"
#include "foundation/process_loader.hpp"

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

using namespace emulator;

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "process_loader_test.cpp:%d: check failed: %s\n", line,
        expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

constexpr std::uint32_t mh_magic = 0xfeedfaceU;
constexpr std::uint32_t cpu_type_arm = 12U;
constexpr std::uint32_t cpu_subtype_arm_v6 = 6U;
constexpr std::uint32_t mh_execute = 2U;
constexpr std::uint32_t mh_dylinker = 7U;
constexpr std::uint32_t lc_segment = 0x1U;
constexpr std::uint32_t lc_unixthread = 0x5U;
constexpr std::uint32_t lc_load_dylinker = 0xeU;
constexpr std::uint32_t image_bytes = 0x1000U;
constexpr std::uint32_t system_dyld_base = 0x2fe00000U;
constexpr std::uint32_t system_dyld_end = 0x2fe21000U;
constexpr std::uint32_t system_dyld_entry = 0x2fe01028U;
constexpr std::uint32_t executable_base = 0x1000U;
constexpr std::size_t mebibyte = 1024U * 1024U;

void put_u32(std::vector<std::uint8_t>& bytes, std::uint32_t value)
{
    for (std::uint32_t shift = 0; shift < 32; shift += 8)
        bytes.push_back(static_cast<std::uint8_t>(value >> shift));
}

void put_text(std::vector<std::uint8_t>& bytes, const std::string& text,
    std::size_t width)
{
    for (const char character : text)
        bytes.push_back(static_cast<std::uint8_t>(character));
    bytes.resize(bytes.size() + (width - text.size()), std::uint8_t { 0 });
}

std::vector<std::uint8_t> macho_image(std::uint32_t file_type,
    std::uint32_t text_address, std::uint32_t entry,
    const std::string& dylinker)
{
    std::vector<std::uint8_t> commands;
    put_u32(commands, lc_segment);
    put_u32(commands, 56U);
    put_text(commands, "__TEXT", 16U);
    put_u32(commands, text_address);
    put_u32(commands, image_bytes);
    put_u32(commands, 0U);
    put_u32(commands, image_bytes);
    put_u32(commands, 7U);
    put_u32(commands, 5U);
    put_u32(commands, 0U);
    put_u32(commands, 0U);

    put_u32(commands, lc_unixthread);
    put_u32(commands, 84U);
    put_u32(commands, 1U);
    put_u32(commands, 17U);
    for (std::uint32_t word = 0; word < 17U; ++word)
        put_u32(commands, word == 15U ? entry : 0U);

    std::uint32_t command_count = 2U;
    if (!dylinker.empty()) {
        const auto name_size = (dylinker.size() + 4U) & ~std::size_t { 3U };
        put_u32(commands, lc_load_dylinker);
        put_u32(commands, static_cast<std::uint32_t>(12U + name_size));
        put_u32(commands, 12U);
        put_text(commands, dylinker, name_size);
        ++command_count;
    }

    std::vector<std::uint8_t> bytes;
    put_u32(bytes, mh_magic);
    put_u32(bytes, cpu_type_arm);
    put_u32(bytes, cpu_subtype_arm_v6);
    put_u32(bytes, file_type);
    put_u32(bytes, command_count);
    put_u32(bytes, static_cast<std::uint32_t>(commands.size()));
    put_u32(bytes, 0U);
    bytes.insert(bytes.end(), commands.begin(), commands.end());
    bytes.resize(image_bytes, std::uint8_t { 0 });
    return bytes;
}

void write_file(const std::filesystem::path& path,
    const std::vector<std::uint8_t>& bytes)
{
    std::filesystem::create_directories(path.parent_path());
    std::ofstream out { path, std::ios::binary };
    out.write(reinterpret_cast<const char*>(bytes.data()),
        static_cast<std::streamsize>(bytes.size()));
}

std::optional<std::string> load_error(const std::filesystem::path& root,
    const std::string& guest)
{
    AddressSpace memory;
    ProcessLoader loader { root, memory };
    try {
        static_cast<void>(loader.load(guest));
        return std::nullopt;
    } catch (const std::runtime_error& error) {
        return std::string { error.what() };
    }
}

}

int main()
{
    const auto root = std::filesystem::temp_directory_path() /
        "emulator-process-loader-test";
    std::filesystem::remove_all(root);
    write_file(root / "usr" / "lib" / "dyld",
        macho_image(mh_dylinker, system_dyld_base, system_dyld_entry, ""));
    write_file(root / "evil" / "dyld",
        macho_image(mh_dylinker, system_dyld_base, system_dyld_base + 0x100U,
            ""));
    write_file(root / "bin" / "system",
        macho_image(mh_execute, executable_base, executable_base,
            "/usr/lib/dyld"));
    write_file(root / "bin" / "foreign",
        macho_image(mh_execute, executable_base, executable_base,
            "/evil/dyld"));

    set_machine_image_code_region(ImageCodeRegion { "process-loader-test|rootfs",
        0x30000000U, 0x40000000U, 8U * mebibyte, system_dyld_base,
        system_dyld_end });
    CHECK(machine_image_code_slab() != nullptr);
    const auto refused = load_error(root, "/bin/foreign");
    CHECK(refused.has_value());
    CHECK(refused.has_value() &&
        refused->find("--no-shared-image-slab") != std::string::npos);
    CHECK(!load_error(root, "/bin/system").has_value());

    set_machine_image_code_region(ImageCodeRegion { });
    CHECK(machine_image_code_slab() == nullptr);
    CHECK(!load_error(root, "/bin/foreign").has_value());
    CHECK(!load_error(root, "/bin/system").has_value());

    std::filesystem::remove_all(root);
    if (failures == 0)
        std::puts("process_loader_test: ok");
    return failures == 0 ? 0 : 1;
}
