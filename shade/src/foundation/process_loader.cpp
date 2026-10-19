// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Map guest executables and libraries and construct their initial
// execution state.

#include "foundation/process_loader.hpp"

#include "foundation/executable_catalog.hpp"
#include "foundation/rootfs_path_resolver.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace shade {
namespace {

    constexpr std::uint32_t stack_size = 0x00100000U;
    constexpr std::size_t maximum_interpreter_line = 256;
    constexpr std::size_t maximum_interpreter_depth = 4;
    constexpr std::string_view launch_services_directory_name {
        "LS_DATABASE_DIR="
    };
    constexpr std::array<std::string_view, 2> adaptive_ogl_names {
        "CA_AUTO_ENABLE_OGL=",
        "LK_AUTO_ENABLE_OGL=",
    };
    constexpr std::array<std::string_view, 2> adaptive_ogl_settings {
        "CA_AUTO_ENABLE_OGL=1",
        "LK_AUTO_ENABLE_OGL=1",
    };
    constexpr std::string_view core_animation_ogl_name { "CA_ENABLE_OGL=" };
    constexpr std::string_view core_animation_ogl_setting { "CA_ENABLE_OGL=1" };

    struct InterpreterDirective {
        std::string path;
        std::optional<std::string> argument;
    };

    std::array<std::byte, 4> little_endian_word(std::uint32_t value)
    {
        return {
            static_cast<std::byte>(value & 0xffU),
            static_cast<std::byte>((value >> 8U) & 0xffU),
            static_cast<std::byte>((value >> 16U) & 0xffU),
            static_cast<std::byte>((value >> 24U) & 0xffU),
        };
    }

    std::optional<InterpreterDirective> read_interpreter_directive(
        const std::filesystem::path& path)
    {
        std::ifstream input { path, std::ios::binary };
        if (!input) {
            throw std::runtime_error { "cannot open executable: " +
                                       path.string() };
        }
        std::array<char, maximum_interpreter_line> prefix { };
        input.read(prefix.data(), static_cast<std::streamsize>(prefix.size()));
        const auto count = static_cast<std::size_t>(input.gcount());
        if (count < 2 || prefix[0] != '#' || prefix[1] != '!') {
            return std::nullopt;
        }
        const auto newline = std::find(prefix.begin() + 2,
            prefix.begin() + static_cast<std::ptrdiff_t>(count), '\n');
        if (newline == prefix.begin() + static_cast<std::ptrdiff_t>(count)) {
            throw std::runtime_error { "interpreter directive is too long: " +
                                       path.string() };
        }
        std::string_view directive { prefix.data() + 2,
            static_cast<std::size_t>(newline - (prefix.begin() + 2)) };
        if (!directive.empty() && directive.back() == '\r') {
            directive.remove_suffix(1);
        }
        const auto trim_left = [](std::string_view value) {
            const auto first = value.find_first_not_of(" \t");
            return first == std::string_view::npos ? std::string_view { }
                                                   : value.substr(first);
        };
        directive = trim_left(directive);
        const auto separator = directive.find_first_of(" \t");
        const auto interpreter = directive.substr(0, separator);
        if (interpreter.empty() || interpreter.front() != '/') {
            throw std::runtime_error { "invalid interpreter directive: " +
                                       path.string() };
        }
        InterpreterDirective result { std::string { interpreter },
            std::nullopt };
        if (separator != std::string_view::npos) {
            const auto argument = trim_left(directive.substr(separator));
            if (!argument.empty()) {
                result.argument = std::string { argument };
            }
        }
        return result;
    }

} // namespace

ProcessLoader::ProcessLoader(std::filesystem::path rootfs, AddressSpace& memory,
    ArmArchitectureVersion architecture, ExecutableCatalog* catalog,
    DarwinInitialAppleVectorAbi initial_apple_vector_abi,
    DarwinAddressLayout address_layout)
    : rootfs_ { std::move(rootfs) }
    , memory_ { memory }
    , architecture_ { architecture }
    , catalog_ { catalog }
    , address_layout_ { address_layout }
    , initial_apple_vector_abi_ { initial_apple_vector_abi }
{
}

std::filesystem::path ProcessLoader::host_path(
    const std::string& guest_path) const
{
    std::filesystem::path relative { guest_path };
    if (relative.is_absolute()) {
        relative = relative.relative_path();
    }
    if (relative.empty()) {
        throw std::runtime_error { "guest path is empty" };
    }
    for (const auto& component : relative) {
        if (component == "..") {
            throw std::runtime_error {
                "guest path escapes the root filesystem"
            };
        }
    }
    return RootfsPathResolver { rootfs_ }.resolve(guest_path);
}

MachOImage ProcessLoader::parse_catalogued(
    const std::filesystem::path& path) const
{
    const auto* entry = catalog_ ? catalog_->find_path(path) : nullptr;
    const auto parse_and_refresh = [&]() {
        auto image = MachOImage::parse(path, architecture_);
        if (catalog_ != nullptr) {
            static_cast<void>(catalog_->register_image(image));
        }
        return image;
    };
    if (catalog_ == nullptr || entry == nullptr || entry->file_size == 0U ||
        !entry->uuid || !catalog_->path_is_current(path)) {
        return parse_and_refresh();
    }
    auto image =
        MachOImage::parse(path, architecture_, entry->content_identity);
    if (image.file_size() != entry->file_size || image.uuid() != entry->uuid) {
        return parse_and_refresh();
    }
    return image;
}

LoadedProcess ProcessLoader::load(std::string guest_executable,
    std::vector<std::string> arguments, std::vector<std::string> environment)
{
    auto invocation =
        resolve_invocation(std::move(guest_executable), std::move(arguments));
    auto mapped_executable = std::move(invocation.executable_path);
    arguments = std::move(invocation.arguments);

    auto executable = parse_catalogued(host_path(mapped_executable));
    if (!executable.dynamic_linker() || !executable.entry_point()) {
        throw std::runtime_error {
            "executable lacks LC_LOAD_DYLINKER or LC_UNIXTHREAD"
        };
    }
    auto dynamic_linker =
        parse_catalogued(host_path(*executable.dynamic_linker()));
    if (!dynamic_linker.entry_point()) {
        throw std::runtime_error { "dynamic linker lacks LC_UNIXTHREAD" };
    }
    // Each image can have several executable segments. Keep the first
    // validated file backing for that image so later segments reuse its open
    // descriptor and generation/content identity checks. The contexts are
    // intentionally separate because the executable and dyld are different
    // pathnames and may have independent generations.
    FileMappingBatchContext executable_mapping_context;
    executable.map_into(memory_, &executable_mapping_context);
    FileMappingBatchContext dynamic_linker_mapping_context;
    dynamic_linker.map_into(memory_, &dynamic_linker_mapping_context);
    const auto stack_top = darwin_address_bounds(address_layout_).stack_top;
    const auto stack_base = stack_top - stack_size;
    if (!memory_.map(stack_base, stack_size,
            MemoryPermission::Read | MemoryPermission::Write)) {
        throw std::runtime_error { "failed to map initial user stack" };
    }

    if (environment.empty()) {
        environment = {
            "PATH=/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME=/var/root",
            "SHELL=/bin/sh",
        };
    }
    // LaunchServices accepts a persistent database-directory override. Its
    // native fallback can retain a pointer to a temporary path buffer across
    // database reloads. Supply the firmware's default through the process
    // environment so both the service and its clients retain stable storage.
    if (std::none_of(environment.begin(), environment.end(),
            [](const std::string& variable) {
                return variable.starts_with(launch_services_directory_name);
            })) {
        environment.emplace_back("LS_DATABASE_DIR=/var/mobile/Library/Caches");
    }
    // CoreAnimation and its LayerKit predecessor use aliases for the same
    // adaptive renderer switch. Preserve an explicit guest choice through
    // either alias; otherwise allow complex updates to select GLES while
    // ordinary composition remains on the firmware's MBX2D fast path.
    const auto adaptive_ogl_is_explicit = std::any_of(environment.begin(),
        environment.end(), [](const std::string& variable) {
            return std::any_of(adaptive_ogl_names.begin(),
                adaptive_ogl_names.end(), [&variable](std::string_view name) {
                    return variable.starts_with(name);
                });
        });
    if (!adaptive_ogl_is_explicit) {
        for (const auto setting : adaptive_ogl_settings)
            environment.emplace_back(setting);
    }
    // The public EAGL bridge accepts the firmware's programmable compositor
    // inputs and forwards them through the host renderer. Prefer that path to
    // the firmware's CPU rasterizer; an explicit guest setting remains
    // authoritative.
    const auto core_animation_ogl_is_explicit = std::any_of(environment.begin(),
        environment.end(), [](const std::string& variable) {
            return variable.starts_with(core_animation_ogl_name);
        });
    if (!core_animation_ogl_is_explicit)
        environment.emplace_back(core_animation_ogl_setting);

    std::uint32_t string_cursor = stack_top;
    auto push_string = [&](const std::string& value) {
        const auto bytes = static_cast<std::uint32_t>(value.size() + 1);
        if (bytes > string_cursor - stack_base) {
            throw std::runtime_error {
                "initial stack strings exceed stack mapping"
            };
        }
        string_cursor -= bytes;
        const auto* data = reinterpret_cast<const std::byte*>(value.c_str());
        if (!memory_.copy_in(
                string_cursor, std::span<const std::byte> { data, bytes })) {
            throw std::runtime_error { "failed to write initial stack string" };
        }
        return string_cursor;
    };

    std::vector<std::uint32_t> argument_pointers;
    for (auto it = arguments.rbegin(); it != arguments.rend(); ++it) {
        argument_pointers.push_back(push_string(*it));
    }
    std::reverse(argument_pointers.begin(), argument_pointers.end());

    std::vector<std::uint32_t> environment_pointers;
    for (auto it = environment.rbegin(); it != environment.rend(); ++it) {
        environment_pointers.push_back(push_string(*it));
    }
    std::reverse(environment_pointers.begin(), environment_pointers.end());
    const auto apple_vector_executable_path =
        initial_apple_vector_abi_ ==
                DarwinInitialAppleVectorAbi::LegacyExecutablePath
            ? mapped_executable
            : "executable_path=" + mapped_executable;
    const auto executable_path = push_string(apple_vector_executable_path);

    const auto text_segment = std::find_if(executable.segments().begin(),
        executable.segments().end(), [](const MachSegment& segment) {
            return segment.file_offset == 0 && segment.file_size != 0;
        });
    if (text_segment == executable.segments().end()) {
        throw std::runtime_error {
            "cannot locate the main Mach-O header mapping"
        };
    }
    const auto main_header = text_segment->vm_address;

    std::vector<std::uint32_t> words;
    words.reserve(5 + argument_pointers.size() + environment_pointers.size());
    words.push_back(main_header); // dyld's ARM start shim consumes this first.
    words.push_back(static_cast<std::uint32_t>(argument_pointers.size()));
    words.insert(
        words.end(), argument_pointers.begin(), argument_pointers.end());
    words.push_back(0);
    words.insert(
        words.end(), environment_pointers.begin(), environment_pointers.end());
    words.push_back(0);
    words.push_back(executable_path);
    words.push_back(0);

    const auto word_bytes =
        static_cast<std::uint32_t>(words.size() * sizeof(std::uint32_t));
    if (word_bytes > string_cursor - stack_base) {
        throw std::runtime_error {
            "initial stack vectors exceed stack mapping"
        };
    }
    auto stack_pointer = (string_cursor - word_bytes) & ~7U;
    if (stack_pointer < stack_base) {
        throw std::runtime_error {
            "initial stack vectors exceed stack mapping"
        };
    }
    for (std::size_t index = 0; index < words.size(); ++index) {
        const auto encoded = little_endian_word(words[index]);
        if (!memory_.copy_in(
                stack_pointer + static_cast<std::uint32_t>(index * 4U),
                encoded)) {
            throw std::runtime_error { "failed to write initial stack vector" };
        }
    }

    const auto dyld_entry = *dynamic_linker.entry_point();
    return LoadedProcess {
        std::move(executable),
        std::move(dynamic_linker),
        std::move(mapped_executable),
        std::move(arguments),
        dyld_entry,
        stack_pointer,
        main_header,
    };
}

ProcessLoader::ResolvedInvocation ProcessLoader::resolve_invocation(
    std::string guest_executable, std::vector<std::string> arguments) const
{
    if (arguments.empty()) {
        arguments.push_back(guest_executable);
    }
    auto mapped_executable = guest_executable;
    for (std::size_t depth = 0; depth < maximum_interpreter_depth; ++depth) {
        const auto directive =
            read_interpreter_directive(host_path(mapped_executable));
        if (!directive) {
            break;
        }
        std::vector<std::string> interpreter_arguments;
        interpreter_arguments.reserve(arguments.size() + 2U);
        interpreter_arguments.push_back(directive->path);
        if (directive->argument) {
            interpreter_arguments.push_back(*directive->argument);
        }
        interpreter_arguments.push_back(mapped_executable);
        if (arguments.size() > 1U) {
            interpreter_arguments.insert(interpreter_arguments.end(),
                arguments.begin() + 1, arguments.end());
        }
        arguments = std::move(interpreter_arguments);
        mapped_executable = directive->path;
        if (depth + 1U == maximum_interpreter_depth &&
            read_interpreter_directive(host_path(mapped_executable))) {
            throw std::runtime_error { "interpreter nesting limit exceeded: " +
                                       guest_executable };
        }
    }
    return ResolvedInvocation { std::move(mapped_executable),
        std::move(arguments) };
}

bool ProcessLoader::validate(std::string guest_executable) const
{
    try {
        const auto invocation =
            resolve_invocation(std::move(guest_executable), { });
        const auto executable =
            parse_catalogued(host_path(invocation.executable_path));
        if (!executable.dynamic_linker() || !executable.entry_point()) {
            return false;
        }
        const auto dynamic_linker =
            parse_catalogued(host_path(*executable.dynamic_linker()));
        return dynamic_linker.entry_point().has_value();
    } catch (const std::exception&) {
        return false;
    }
}

} // namespace shade
