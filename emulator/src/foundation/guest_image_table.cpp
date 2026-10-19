// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/guest_image_table.hpp"

#include <algorithm>
#include <cstring>
#include <string>
#include <utility>
#include <vector>

namespace shade {
namespace {

    constexpr std::uint32_t dyld_all_image_info_version_offset = 0;
    constexpr std::uint32_t dyld_all_image_info_count_offset = 4;
    constexpr std::uint32_t dyld_all_image_info_array_offset = 8;
    constexpr std::uint32_t dyld_all_image_info_dyld_offset = 20;
    constexpr std::uint32_t dyld_all_image_info_dyld_version = 2;
    constexpr std::uint32_t dyld_image_info_size = 12;
    constexpr char dyld_path[] = "/usr/lib/dyld";
    constexpr std::uint32_t maximum_image_count = 4096;
    constexpr std::uint32_t macho32_magic = 0xfeedfaceU;
    constexpr std::uint32_t macho32_header_size = 28;
    constexpr std::uint32_t macho_ncmds_offset = 16;
    constexpr std::uint32_t maximum_load_commands = 1024;
    constexpr std::uint32_t lc_segment = 0x1U;
    constexpr std::uint32_t segment_name_offset = 8;
    constexpr std::uint32_t segment_vmsize_offset = 28;
    constexpr std::size_t segment_name_size = 16;

    std::uint32_t text_size_of(const AddressSpace& memory, std::uint32_t load)
    {
        const auto magic = memory.read32(load);
        const auto ncmds = memory.read32(load + macho_ncmds_offset);
        if (!magic || *magic != macho32_magic || !ncmds)
            return 0U;
        std::uint32_t command_address = load + macho32_header_size;
        for (std::uint32_t index = 0;
            index < std::min(*ncmds, maximum_load_commands); ++index) {
            const auto command = memory.read32(command_address);
            const auto size = memory.read32(command_address + 4U);
            if (!command || !size || *size < 8U)
                return 0U;
            if (*command == lc_segment) {
                const auto name = memory.read_bytes(
                    command_address + segment_name_offset, segment_name_size);
                const auto vmsize =
                    memory.read32(command_address + segment_vmsize_offset);
                if (name && vmsize &&
                    std::memcmp(name->data(), "__TEXT", 7) == 0)
                    return *vmsize;
            }
            command_address += *size;
        }
        return 0U;
    }

}

GuestImageTable read_guest_image_table(
    const AddressSpace& memory, std::uint32_t all_image_info_address)
{
    const auto count = memory.read32(
        all_image_info_address + dyld_all_image_info_count_offset);
    const auto array = memory.read32(
        all_image_info_address + dyld_all_image_info_array_offset);
    if (!count || !array)
        return GuestImageTable { };
    std::vector<GuestImage> images;
    for (std::uint32_t index = 0; index < std::min(*count, maximum_image_count);
        ++index) {
        const auto info = *array + index * dyld_image_info_size;
        const auto load = memory.read32(info);
        const auto path_address = memory.read32(info + 4U);
        if (!load || !path_address)
            continue;
        const auto path = memory.read_c_string(*path_address);
        if (!path)
            continue;
        images.push_back(
            GuestImage { *path, *load, text_size_of(memory, *load) });
    }
    const auto version = memory.read32(
        all_image_info_address + dyld_all_image_info_version_offset);
    const auto dyld_load =
        memory.read32(all_image_info_address + dyld_all_image_info_dyld_offset);
    if (version && *version >= dyld_all_image_info_dyld_version && dyld_load &&
        *dyld_load != 0U &&
        std::none_of(
            images.begin(), images.end(), [&](const GuestImage& image) {
                return image.load_address == *dyld_load;
            }))
        images.push_back(GuestImage {
            dyld_path, *dyld_load, text_size_of(memory, *dyld_load) });
    return GuestImageTable { std::move(images) };
}

}
