// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode guest process argument records for Darwin sysctl queries.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_sysctl.c

#include "kernel/darwin_sysctl.hpp"

#include <algorithm>
#include <iterator>

namespace shade::darwin::sysctl {
namespace {

    void append_string(std::vector<std::byte>& result, std::string_view value)
    {
        std::transform(value.begin(), value.end(), std::back_inserter(result),
            [](char character) { return static_cast<std::byte>(character); });
        result.push_back(std::byte { });
    }

    void align_word(std::vector<std::byte>& result)
    {
        constexpr std::size_t word_size = sizeof(std::uint32_t);
        while (result.size() % word_size != 0)
            result.push_back(std::byte { });
    }

    void append_word(std::vector<std::byte>& result, std::uint32_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            result.push_back(static_cast<std::byte>(value >> (index * 8U)));
        }
    }

    std::vector<std::byte> encode_process_arguments_impl(
        std::string_view executable_path,
        std::span<const std::string> arguments,
        std::span<const std::string> environment, bool include_argument_count)
    {
        std::vector<std::byte> result;
        const auto argument_bytes = [](std::span<const std::string> values) {
            std::size_t size = 1;
            for (const auto& value : values)
                size += value.size() + 1U;
            return size;
        };
        result.reserve(executable_path.size() + 1U + sizeof(std::uint32_t) +
                       argument_bytes(arguments) + argument_bytes(environment));
        append_string(result, executable_path);
        align_word(result);
        if (include_argument_count) {
            append_word(result, static_cast<std::uint32_t>(arguments.size()));
        }
        for (const auto& argument : arguments)
            append_string(result, argument);
        result.push_back(std::byte { });
        for (const auto& variable : environment)
            append_string(result, variable);
        result.push_back(std::byte { });
        return result;
    }

} // namespace

std::vector<std::byte> encode_process_arguments(
    std::string_view executable_path, std::span<const std::string> arguments,
    std::span<const std::string> environment)
{
    return encode_process_arguments_impl(
        executable_path, arguments, environment, false);
}

std::vector<std::byte> encode_process_arguments2(
    std::string_view executable_path, std::span<const std::string> arguments,
    std::span<const std::string> environment)
{
    return encode_process_arguments_impl(
        executable_path, arguments, environment, true);
}

} // namespace shade::darwin::sysctl
