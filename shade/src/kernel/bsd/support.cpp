// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Provide BSD dispatch helpers for guest paths, errors, timestamps
// and descriptor access.

#include "support.hpp"

#include "kernel/darwin_abi.hpp"

#include <algorithm>
#include <limits>
#include <string_view>

namespace shade::bsd_support {
namespace {

    constexpr std::uint64_t hfs_nanoseconds_per_second = 1'000'000'000ULL;

} // namespace

hfs::Timestamp guest_filesystem_timestamp(const VirtualClock& clock)
{
    const auto wall_time = clock.wall_time();
    const auto seconds = wall_time / hfs_nanoseconds_per_second;
    return hfs::Timestamp {
        static_cast<std::int32_t>(std::min<std::uint64_t>(
            seconds, static_cast<std::uint64_t>(
                         std::numeric_limits<std::int32_t>::max()))),
        static_cast<std::int32_t>(wall_time % hfs_nanoseconds_per_second)
    };
}

std::uint32_t darwin_filesystem_error(
    const std::error_code& error, std::uint32_t fallback)
{
    if (error == std::errc::no_such_file_or_directory)
        return 2U;
    if (error == std::errc::permission_denied ||
        error == std::errc::operation_not_permitted) {
        return 13U;
    }
    if (error == std::errc::file_exists)
        return 17U;
    if (error == std::errc::cross_device_link)
        return 18U;
    if (error == std::errc::not_a_directory)
        return 20U;
    if (error == std::errc::is_a_directory)
        return 21U;
    if (error == std::errc::invalid_argument)
        return 22U;
    if (error == std::errc::no_space_on_device)
        return 28U;
    if (error == std::errc::read_only_file_system)
        return 30U;
    if (error == std::errc::too_many_links)
        return 31U;
    if (error == std::errc::directory_not_empty)
        return 66U;
    return fallback;
}

std::string format_payload_prefix(std::span<const std::byte> bytes)
{
    constexpr std::string_view digits { "0123456789abcdef" };
    const auto count =
        std::min(bytes.size(), darwin::io::diagnostic_payload_bytes);
    std::string result;
    result.reserve(count * 2U + (bytes.size() > count ? 3U : 0U));
    for (std::size_t index = 0; index < count; ++index) {
        const auto value = std::to_integer<unsigned>(bytes[index]);
        result.push_back(digits[value >> 4U]);
        result.push_back(digits[value & 0x0fU]);
    }
    if (bytes.size() > count)
        result += "...";
    return result;
}

} // namespace shade::bsd_support
