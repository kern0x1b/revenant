// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse command-line options and dispatch emulator, preparation and
// inspection commands.

#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <exception>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>

#include <dynarmic/interface/A32/disassembler.h>

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/device_model.hpp"
#include "foundation/dyld_shared_cache.hpp"
#include "foundation/executable_catalog.hpp"
#include "foundation/firmware_prepare.hpp"
#include "foundation/jit_artifact.hpp"
#include "foundation/jit_code_cache_governor.hpp"
#include "foundation/jit_work_policy.hpp"
#include "foundation/macho.hpp"
#include "foundation/output.hpp"
#include "foundation/performance.hpp"

#include "app/abi_command.hpp"
#include "app/desktop_host.hpp"
#include "foundation/host_memory.hpp"
#include "host/resource_usage.hpp"
#include "runtime/emulator_session.hpp"

namespace {

using namespace emulator;

constexpr std::size_t maximum_virtual_processors = 64;
constexpr std::size_t bytes_per_mebibyte = 1024U * 1024U;

std::string usage()
{
    return "Usage:\n"
           "  emulator profile [--list | --device PROFILE] [--output FILE]\n"
           "  emulator abi [--rootfs DIR] [--ios-build CODE] [--output FILE]\n"
           "  emulator inspect --rootfs DIR [--binary /sbin/launchd] "
           "[--device PROFILE] [--shared-cache GUEST_PATH] "
           "[--symbols SUBSTRING] [--output FILE]\n"
           "  emulator catalog --rootfs DIR [--device PROFILE] [--manifest FILE] "
           "[--host-cache DIR] "
           "[--output FILE]\n"
           "  emulator firmware prepare --rootfs DIR [--device PROFILE] "
           "[--manifest FILE] [--host-cache DIR] [--prepare-force] "
           "[--prepare-file-blocks N] [--prepare-image-blocks N] "
           "[--prepare-firmware-blocks N] [--prepare-file-ms N] "
           "[--prepare-image-ms N] [--prepare-firmware-ms N] "
           "[--prepare-artifact-mode "
           "catalog-only|static-catalog|profile-hotset] "
           "[--prepare-profile-hotset-blocks N] "
           "[--jit-artifact-memory-mib 1..4096] "
           "[--jit-artifact-disk-mib 0..4096] [--output FILE]\n"
           "  emulator disasm --rootfs DIR --binary PATH "
           "(--symbol NAME | --address ADDR) [--device PROFILE] [--count N] "
           "[--shared-cache GUEST_PATH] [--thumb]\n"
           "  emulator boot --rootfs DIR [--device PROFILE] [--ios-build CODE] "
           "[--binary /sbin/launchd] [--guest-command COMMAND] [--ticks N] "
           "[--census-output FILE] [--snapshot-out FILE] [--snapshot-in FILE] "
           "[--cores N] [--jit-cache-mib 8..512] "
           "[--jit-cache-budget-mib 256..4096] "
           "[--watch-address ADDR] [--gdb PORT] "
           "[--display headless|sdl] [--network isolated|loopback|host] "
           "[--gles-backend auto|software|vulkan] [--gpu] "
           "[--host-cache DIR] [--catalog FILE] "
           "[--jit-artifact-disk-mib 0..4096] "
           "[--jit-artifact-memory-mib 1..4096] "
           "[--display-size WIDTHxHEIGHT] "
           "[--activation activated|unactivated|preserve] "
           "[--boot-logo PNG] [--frame-output FILE] [--touch-replay FILE] [--control-stdin] "
           "[--baseband-input FILE] [--baseband-output FILE] "
           "[--disable-scheduler-preemption] [--time-scale FACTOR] [--verbose] "
           "[--perf-summary] [--jit-observer-only] [--perf-frame-content] "
           "[--perf-cpu-phases] "
           "[--perf-jit-native-lookups] [--perf-block-profile] "
           "[--jit-profile-mode "
           "adaptive|off|record-only|load-only|idle|startup] "
           "[--jit-startup-profile] "
           "[--jit-startup-profile-blocks N] "
           "[--jit-startup-profile-budget-us N] "
           "[--jit-catalog-warming no-enqueue] "
           "[--output FILE]\n"
           "  emulator smoke [--cores N] [--jit-cache-mib 8..512] "
           "[--perf-summary] [--output FILE]\n"
           "  emulator benchmark arm [--iterations N] "
           "[--jit-cache-mib 8..512] [--perf-summary] "
           "[--output FILE]\n"
           "\nBoot/ABI selection reads SystemVersion.plist by default.\n"
           "  GLES auto/vulkan prefer hardware; software selects a CPU Vulkan ICD.\n"
           "  --ios-build CODE overrides it (e.g. 9A334).\n";
}

std::optional<std::string> option(
    const std::vector<std::string>& args, std::string_view name)
{
    const auto inline_prefix = std::string { name } + "=";
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == name) {
            if (i + 1 >= args.size()) {
                throw std::runtime_error { "missing value for " +
                                           std::string { name } };
            }
            return args[i + 1];
        }
        if (args[i].starts_with(inline_prefix)) {
            const auto value = args[i].substr(inline_prefix.size());
            if (value.empty()) {
                throw std::runtime_error { "missing value for " +
                                           std::string { name } };
            }
            return value;
        }
    }
    return std::nullopt;
}

std::optional<std::string> ios_build_option(
    const std::vector<std::string>& args)
{
    if (option(args, "--abi"))
        throw std::runtime_error {
            "--abi has been replaced by --ios-build CODE (e.g. 9A334)"
        };
    return option(args, "--ios-build");
}

std::filesystem::path host_cache_directory(
    const std::vector<std::string>& args, const std::filesystem::path& rootfs)
{
    if (const auto configured = option(args, "--host-cache")) {
        return std::filesystem::path { *configured };
    }
    return default_host_cache_directory(rootfs);
}

bool flag(const std::vector<std::string>& args, std::string_view name)
{
    return std::find(args.begin(), args.end(), name) != args.end();
}

[[nodiscard]] JitCatalogWarmingMode parse_jit_catalog_warming_mode(
    const std::vector<std::string>& args)
{
    const auto configured = option(args, "--jit-catalog-warming");
    if (!configured || *configured == "no-enqueue") {
        return JitCatalogWarmingMode::NoEnqueue;
    }
    throw std::runtime_error { "--jit-catalog-warming only supports "
                               "no-enqueue; idle warming was removed" };
}

[[nodiscard]] JitProfileMode parse_jit_profile_mode(
    const std::vector<std::string>& args)
{
    const auto configured = option(args, "--jit-profile-mode");
    JitProfileMode mode = BootOptions { }.jit_profile_mode;
    if (configured) {
        if (*configured == "adaptive")
            mode = JitProfileMode::Adaptive;
        else if (*configured == "off")
            mode = JitProfileMode::Off;
        else if (*configured == "record-only")
            mode = JitProfileMode::RecordOnly;
        else if (*configured == "load-only")
            mode = JitProfileMode::LoadOnly;
        else if (*configured == "idle")
            mode = JitProfileMode::Idle;
        else if (*configured == "startup")
            mode = JitProfileMode::Startup;
        else {
            throw std::runtime_error {
                "--jit-profile-mode must be adaptive, off, record-only, "
                "load-only, idle, or startup"
            };
        }
    }
    if (flag(args, "--jit-startup-profile")) {
        if (configured && mode != JitProfileMode::Startup) {
            throw std::runtime_error {
                "--jit-startup-profile conflicts with --jit-profile-mode"
            };
        }
        mode = JitProfileMode::Startup;
    }
    if (flag(args, "--jit-startup-profile-adaptive")) {
        throw std::runtime_error {
            "--jit-startup-profile-adaptive is unsupported: no persisted "
            "cross-run history exists"
        };
    }
    return mode;
}

std::size_t jit_code_cache_size(const std::vector<std::string>& args)
{
    const auto configured = option(args, "--jit-cache-mib");
    if (!configured) {
        const auto memory = host_memory_budget_snapshot();
        const auto effective = effective_host_memory_limit(memory);
        return JitWorkPolicy::recommended_native_slab_bytes(
            effective.value_or(0U), effective.has_value(),
            memory.available_bytes, memory.available_known);
    }
    const auto& value = *configured;
    std::size_t consumed { };
    const auto mebibytes = std::stoull(value, &consumed, 10);
    const auto minimum_mebibytes =
        JitCodeCacheGovernor::minimum_demand_working_set_bytes / bytes_per_mebibyte;
    const auto maximum_mebibytes =
        JitWorkPolicy::maximum_native_slab_bytes() / bytes_per_mebibyte;
    if (consumed != value.size() || mebibytes < minimum_mebibytes ||
        mebibytes > maximum_mebibytes) {
        throw std::runtime_error { "--jit-cache-mib must be in the range " +
                                   std::to_string(minimum_mebibytes) + ".." +
                                   std::to_string(maximum_mebibytes) };
    }
    return static_cast<std::size_t>(mebibytes) * 1024U * 1024U;
}

std::uintmax_t parse_mib_value(std::string_view value, std::string_view name,
    std::uintmax_t minimum, std::uintmax_t maximum)
{
    std::size_t consumed { };
    const auto mebibytes = std::stoull(std::string { value }, &consumed, 10);
    if (consumed != value.size() || mebibytes < minimum ||
        mebibytes > maximum ||
        mebibytes >
            std::numeric_limits<std::uintmax_t>::max() / (1024U * 1024U)) {
        throw std::runtime_error {
            std::string { name } + " must be in the range " +
            std::to_string(minimum) + ".." + std::to_string(maximum) + " MiB"
        };
    }
    return static_cast<std::uintmax_t>(mebibytes) * 1024U * 1024U;
}

std::size_t parse_prepare_count(const std::vector<std::string>& args,
    std::string_view name, std::size_t fallback, std::size_t maximum)
{
    const auto value = option(args, name).value_or(std::to_string(fallback));
    std::size_t consumed { };
    const auto parsed = std::stoull(value, &consumed, 10);
    if (consumed != value.size() || parsed == 0U || parsed > maximum) {
        throw std::runtime_error { std::string { name } +
                                   " must be in the range 1.." +
                                   std::to_string(maximum) };
    }
    return static_cast<std::size_t>(parsed);
}

FirmwareArtifactSeedMode parse_prepare_artifact_mode(
    const std::vector<std::string>& args)
{
    const auto value =
        option(args, "--prepare-artifact-mode").value_or("catalog-only");
    if (value == "catalog-only")
        return FirmwareArtifactSeedMode::CatalogOnly;
    if (value == "static-catalog") {
        return FirmwareArtifactSeedMode::StaticCatalog;
    }
    if (value == "profile-hotset") {
        return FirmwareArtifactSeedMode::ProfileHotset;
    }
    throw std::runtime_error {
        "--prepare-artifact-mode must be catalog-only, static-catalog, or "
        "profile-hotset"
    };
}

std::chrono::milliseconds parse_prepare_time(
    const std::vector<std::string>& args, std::string_view name,
    std::size_t fallback, std::size_t maximum)
{
    return std::chrono::milliseconds { parse_prepare_count(
        args, name, fallback, maximum) };
}

std::size_t jit_artifact_memory_limit(const std::vector<std::string>& args)
{
    const auto value = option(args, "--jit-artifact-memory-mib").value_or("64");
    return static_cast<std::size_t>(
        parse_mib_value(value, "--jit-artifact-memory-mib", 1U, 4096U));
}

GlesBackend parse_gles_backend(const std::vector<std::string>& args)
{
    const auto configured = option(args, "--gles-backend");
    auto backend = GlesBackend::Auto;
    if (configured) {
        if (*configured == "software") {
            backend = GlesBackend::Software;
        } else if (*configured == "vulkan") {
            backend = GlesBackend::Vulkan;
        } else if (*configured != "auto") {
            throw std::runtime_error {
                "--gles-backend must be auto, software, or vulkan"
            };
        }
    }
    if (flag(args, "--gpu")) {
        if (configured && backend == GlesBackend::Software) {
            throw std::runtime_error {
                "--gpu conflicts with --gles-backend=software"
            };
        }
        backend = GlesBackend::Vulkan;
    }
    return backend;
}

DisplayGeometry parse_display_geometry(std::string_view value)
{
    const auto separator = value.find_first_of("xX");
    if (separator == std::string_view::npos || separator == 0U ||
        separator + 1U >= value.size()) {
        throw std::runtime_error { "--display-size must use WIDTHxHEIGHT" };
    }
    const auto parse_extent = [](std::string_view text) {
        std::size_t consumed = 0;
        const auto extent = std::stoull(std::string { text }, &consumed, 10);
        if (consumed != text.size() || extent == 0U || extent > 4'096U) {
            throw std::runtime_error {
                "display extents must be in the range 1..4096"
            };
        }
        return static_cast<std::uint32_t>(extent);
    };
    return DisplayGeometry { parse_extent(value.substr(0, separator)),
        parse_extent(value.substr(separator + 1U)) };
}

std::unique_ptr<Output> make_output(const std::vector<std::string>& args)
{
    if (const auto path = option(args, "--output")) {
        return std::make_unique<Output>(*path);
    }
    return std::make_unique<Output>(std::cout);
}

const DeviceModel& select_device_model(const std::vector<std::string>& args)
{
    const auto requested =
        option(args, "--device")
            .value_or(std::string {
                DeviceModel::default_model().identity.product_type });
    if (const auto* profile = DeviceModel::find(requested)) {
        return *profile;
    }
    std::ostringstream message;
    message << "unknown device profile: " << requested << "; available:";
    for (const auto& profile : DeviceModel::available_models()) {
        message << ' ' << profile.identity.product_type;
    }
    throw std::runtime_error { message.str() };
}

void profile(const std::vector<std::string>& args, Output& output)
{
    if (flag(args, "--list")) {
        for (const auto& model : DeviceModel::available_models())
            output.line(std::string { model.identity.product_type });
        return;
    }
    const auto& device = select_device_model(args);
    std::ostringstream text;
    text << "product: " << device.identity.product_type << '\n'
         << "board: " << device.identity.board_config << '\n'
         << "model_number: " << device.identity.model_number << '\n'
         << "soc: " << device.processor.soc << '\n'
         << "cpu: " << device.processor.core_name() << " ("
         << device.processor.instruction_set_name() << ")\n"
         << "cpu_hz: " << device.processor.frequency_hz() << '\n'
         << "ram_bytes: " << device.memory.ram_bytes << '\n'
         << "guest_physical_core_count: "
         << device.processor.topology.physical_core_count << '\n'
         << "guest_logical_cpu_count: "
         << device.processor.topology.logical_cpu_count << '\n'
         << "guest_cpu_clusters: " << device.processor.topology.cluster_count
         << '\n'
         << "display: " << device.screen.panel.width << 'x'
         << device.screen.panel.height << '\n'
         << "ui: " << device.screen.user_interface.width << 'x'
         << device.screen.user_interface.height << '\n'
         << "framebuffer_service: " << device.screen.framebuffer_service_class;
    output.line(text.str());
}

std::shared_ptr<const MachOImage> inspection_image(
    const std::vector<std::string>& args, std::string_view guest_binary)
{
    const auto rootfs = option(args, "--rootfs");
    if (!rootfs)
        throw std::runtime_error { "image inspection requires --rootfs" };
    const auto architecture =
        arm_architecture_for_model(select_device_model(args).processor.model);
    if (const auto cache_path = option(args, "--shared-cache")) {
        const auto host_cache =
            std::filesystem::path { *rootfs } /
            std::filesystem::path { *cache_path }.relative_path();
        DyldSharedCacheOptions options;
        options.architecture = architecture == ArmArchitectureVersion::Armv7
                                   ? "armv7"
                                   : "armv6k";
        const auto cache = DyldSharedCache::parse(host_cache, options);
        if (!cache)
            throw std::runtime_error { "invalid dyld shared cache: " +
                                       host_cache.string() };
        const auto entry = cache->find_image(guest_binary);
        if (!entry)
            throw std::runtime_error { "image not found in dyld shared cache: " +
                                       std::string { guest_binary } };
        const auto image = cache->parse_image(entry->index, architecture);
        if (!image)
            throw std::runtime_error { "cannot parse image in dyld shared cache: " +
                                       std::string { guest_binary } };
        return image;
    }
    return std::make_shared<MachOImage>(MachOImage::parse(
        std::filesystem::path { *rootfs } /
            std::filesystem::path { guest_binary }.relative_path(),
        architecture));
}

std::string dylib_version_string(std::uint32_t version)
{
    return std::to_string(version >> 16U) + "." +
           std::to_string((version >> 8U) & 0xffU) + "." +
           std::to_string(version & 0xffU);
}

void inspect(const std::vector<std::string>& args, Output& output)
{
    const auto rootfs = option(args, "--rootfs");
    if (!rootfs) {
        throw std::runtime_error { "inspect requires --rootfs" };
    }
    const auto guest_binary =
        option(args, "--binary").value_or("/sbin/launchd");
    std::filesystem::path relative = guest_binary;
    if (relative.is_absolute()) {
        relative = relative.relative_path();
    }
    const auto host_path = std::filesystem::path { *rootfs } / relative;
    const auto selected_image = inspection_image(args, guest_binary);
    const auto& image = *selected_image;

    std::ostringstream text;
    text << "path: " << host_path.string() << '\n'
         << "cpu: " << mach_cpu_name(image.cpu_type(), image.cpu_subtype())
         << '\n'
         << "file_type: " << mach_file_type_name(image.file_type()) << '\n'
         << "load_commands: " << image.command_count() << '\n'
         << "entry: ";
    if (image.entry_point()) {
        text << "0x" << std::hex << *image.entry_point() << std::dec;
    } else {
        text << "unknown";
    }
    text << '\n' << "dyld: " << image.dynamic_linker().value_or("none") << '\n';
    if (option(args, "--shared-cache"))
        text << "storage: " << image.path().string() << '\n';
    for (const auto& segment : image.segments()) {
        text << "segment " << segment.name << " vm=0x" << std::hex
             << segment.vm_address << " size=0x" << segment.vm_size
             << " file=0x" << segment.file_offset << "+0x" << segment.file_size
             << std::dec << '\n';
        for (const auto& section : segment.sections) {
            text << "  section " << section.segment << ',' << section.name
                 << " vm=0x" << std::hex << section.address << " size=0x"
                 << section.size << " file=0x" << section.file_offset
                 << " flags=0x" << section.flags << " reserved1=0x"
                 << section.reserved1 << " reserved2=0x" << section.reserved2
                 << std::dec << '\n';
        }
    }
    const auto* dylib_identity = image.dylib_identity();
    for (const auto& dylib : image.dylibs()) {
        text << (dylib.prebound ? "prebound "
                 : &dylib == dylib_identity ? "dylib-id " : "dylib ")
             << dylib.path;
        if (dylib.version) {
            text << " current=" << dylib_version_string(dylib.version->current)
                 << " compatibility="
                 << dylib_version_string(dylib.version->compatibility);
        }
        text << '\n';
    }
    if (!image.unknown_commands().empty()) {
        text << "unknown_commands:";
        for (const auto command : image.unknown_commands()) {
            text << " 0x" << std::hex << command;
        }
        text << std::dec << '\n';
    }
    if (const auto pattern = option(args, "--symbols")) {
        for (const auto& symbol : image.symbols()) {
            if (symbol.name.find(*pattern) == std::string::npos)
                continue;
            text << "symbol " << symbol.name << " vm=0x" << std::hex
                 << symbol.value << " type=0x"
                 << static_cast<unsigned>(symbol.type) << " section=0x"
                 << static_cast<unsigned>(symbol.section) << " desc=0x"
                 << symbol.description
                 << (symbol.thumb_definition() ? " thumb" : "") << std::dec
                 << '\n';
        }
        for (const auto& stub : image.stubs()) {
            if (stub.symbol.find(*pattern) == std::string::npos)
                continue;
            text << "stub " << stub.symbol << " vm=0x" << std::hex
                 << stub.address << " size=0x" << stub.size << std::dec << '\n';
        }
    }

    if (!option(args, "--shared-cache")) {
        AddressSpace memory;
        image.map_into(memory);
        text << "mapped_pages: " << memory.mapped_page_count();
    }
    output.line(text.str());
}

void catalog(const std::vector<std::string>& args, Output& output)
{
    const auto rootfs = option(args, "--rootfs");
    if (!rootfs)
        throw std::runtime_error { "catalog requires --rootfs" };
    const auto architecture =
        arm_architecture_for_model(select_device_model(args).processor.model);
    ExecutableCatalog executable_catalog;
    const auto manifest =
        option(args, "--manifest")
            .value_or(
                (host_cache_directory(args, std::filesystem::path { *rootfs }) /
                    "executable-catalog.bin")
                    .string());
    const auto had_manifest = executable_catalog.load(manifest);
    const auto summary =
        had_manifest ? executable_catalog.refresh_tree(*rootfs, architecture)
                     : executable_catalog.register_tree(*rootfs, architecture);
    if (!executable_catalog.save(manifest)) {
        throw std::runtime_error {
            "failed to save executable catalog manifest: " + manifest
        };
    }
    output.line(
        "[catalog] rootfs=" + *rootfs +
        " regular-files=" + std::to_string(summary.regular_files) +
        " macho-images=" + std::to_string(summary.mach_o_images) +
        " reused-macho-images=" + std::to_string(summary.reused_mach_o_images) +
        " shared-cache-generations=" +
        std::to_string(summary.dyld_shared_cache_generations) +
        " shared-cache-images=" +
        std::to_string(summary.dyld_shared_cache_images) +
        " failed-files=" + std::to_string(summary.failed_files) + " entries=" +
        std::to_string(executable_catalog.size()) + " reliable-entry-points=" +
        std::to_string(executable_catalog.reliable_entry_point_count()) +
        " manifest=" + manifest);
}

void firmware_prepare(const std::vector<std::string>& args, Output& output)
{
    const auto rootfs = option(args, "--rootfs");
    if (!rootfs)
        throw std::runtime_error { "firmware prepare requires --rootfs" };
    const auto& device = select_device_model(args);
    const auto cpu_model = make_arm_cpu_model(
        device.processor.model, device.processor.frequency_hz());
    const auto host_cache =
        host_cache_directory(args, std::filesystem::path { *rootfs });
    const auto manifest =
        option(args, "--manifest")
            .value_or((host_cache / "executable-catalog.bin").string());

    FirmwarePrepareLimits limits;
    limits.max_file_blocks =
        parse_prepare_count(args, "--prepare-file-blocks", 128U, 65'536U);
    limits.max_image_blocks =
        parse_prepare_count(args, "--prepare-image-blocks", 128U, 65'536U);
    limits.max_firmware_blocks = parse_prepare_count(
        args, "--prepare-firmware-blocks", 4096U, 1'000'000U);
    limits.max_file_time =
        parse_prepare_time(args, "--prepare-file-ms", 500U, 3'600'000U);
    limits.max_image_time =
        parse_prepare_time(args, "--prepare-image-ms", 500U, 3'600'000U);
    limits.max_firmware_time =
        parse_prepare_time(args, "--prepare-firmware-ms", 30'000U, 86'400'000U);
    limits.artifact_seed_mode = parse_prepare_artifact_mode(args);
    limits.max_profile_hotset_blocks = parse_prepare_count(
        args, "--prepare-profile-hotset-blocks", 256U, 4096U);
    const auto file_memory = parse_mib_value(
        option(args, "--prepare-file-memory-mib").value_or("128"),
        "--prepare-file-memory-mib", 1U, 4096U);
    const auto image_memory = parse_mib_value(
        option(args, "--prepare-image-memory-mib").value_or("128"),
        "--prepare-image-memory-mib", 1U, 4096U);
    const auto firmware_memory = parse_mib_value(
        option(args, "--prepare-firmware-memory-mib").value_or("512"),
        "--prepare-firmware-memory-mib", 1U, 16'384U);
    const auto file_storage = parse_mib_value(
        option(args, "--prepare-file-storage-mib").value_or("32"),
        "--prepare-file-storage-mib", 1U, 4096U);
    const auto image_storage = parse_mib_value(
        option(args, "--prepare-image-storage-mib").value_or("32"),
        "--prepare-image-storage-mib", 1U, 4096U);
    const auto firmware_storage = parse_mib_value(
        option(args, "--prepare-firmware-storage-mib").value_or("256"),
        "--prepare-firmware-storage-mib", 1U, 4096U);
    limits.max_file_memory_bytes = static_cast<std::size_t>(file_memory);
    limits.max_image_memory_bytes = static_cast<std::size_t>(image_memory);
    limits.max_firmware_memory_bytes =
        static_cast<std::size_t>(firmware_memory);
    limits.max_file_storage_bytes = static_cast<std::size_t>(file_storage);
    limits.max_image_storage_bytes = static_cast<std::size_t>(image_storage);
    limits.max_firmware_storage_bytes =
        static_cast<std::size_t>(firmware_storage);
    limits.artifact_resident_bytes = jit_artifact_memory_limit(args);
    const auto disk_mib = option(args, "--jit-artifact-disk-mib");
    if (disk_mib && *disk_mib == "0") {
        limits.artifact_persistence_bytes = 0U;
        limits.artifact_persistence_enabled = false;
    } else {
        limits.artifact_persistence_bytes =
            static_cast<std::size_t>(parse_mib_value(disk_mib.value_or("256"),
                "--jit-artifact-disk-mib", 1U, 4096U));
    }
    limits.artifact_minimum_free_bytes =
        static_cast<std::uintmax_t>(parse_mib_value(
            option(args, "--jit-artifact-min-free-mib").value_or("1024"),
            "--jit-artifact-min-free-mib", 0U, 16'384U));
    limits.force = flag(args, "--prepare-force");

    FirmwarePreparer preparer { std::filesystem::path { *rootfs },
        std::filesystem::path { manifest }, host_cache,
        cpu_model->architecture_version(), *cpu_model, limits };
    const auto stats = preparer.run();
    const auto status = stats.interrupted || stats.partial_files != 0U ||
                                stats.preparation_failures != 0U ||
                                stats.skipped_limits != 0U
                            ? "partial"
                            : "complete";
    output.line(
        "[firmware-prepare] rootfs=" + *rootfs + " manifest=" + manifest +
        " catalog-entries=" + std::to_string(stats.catalog_entries) +
        " regular-files=" + std::to_string(stats.catalog_scan.regular_files) +
        " macho-images=" + std::to_string(stats.catalog_scan.mach_o_images) +
        " reused-macho-images=" +
        std::to_string(stats.catalog_scan.reused_mach_o_images) +
        " shared-cache-images=" +
        std::to_string(stats.catalog_scan.dyld_shared_cache_images) +
        " failed-files=" + std::to_string(stats.catalog_scan.failed_files) +
        " reliable-entry-points=" +
        std::to_string(stats.reliable_entry_points) + " artifact-seed-mode=" +
        std::string {
            firmware_artifact_seed_mode_name(limits.artifact_seed_mode) } +
        " status=" + status);
    output.line(
        "[firmware-prepare-seed] profile-hotset-selected=" +
        std::to_string(stats.profile_hotset_selected) +
        " static-selected=" + std::to_string(stats.static_seed_selected) +
        " catalog-only-candidates=" +
        std::to_string(stats.catalog_only_candidates) + " hotset-block-limit=" +
        std::to_string(limits.max_profile_hotset_blocks) +
        " artifact-finalized=" +
        std::to_string(stats.artifact_finalized ? 1 : 0));
    output.line(
        "[firmware-prepare-work] candidates=" +
        std::to_string(stats.candidates) +
        " skipped-dynamic=" + std::to_string(stats.skipped_dynamic_mappings) +
        " skipped-without-generation=" +
        std::to_string(stats.skipped_without_generation) +
        " skipped-limits=" + std::to_string(stats.skipped_limits) +
        " resumed=" + std::to_string(stats.resumed) +
        " files-processed=" + std::to_string(stats.files_processed) +
        " images-processed=" + std::to_string(stats.images_processed) +
        " completed=" + std::to_string(stats.completed_files) +
        " partial=" + std::to_string(stats.partial_files) +
        " failures=" + std::to_string(stats.preparation_failures) +
        " interrupted=" + std::to_string(stats.interrupted ? 1 : 0) +
        " storage-limited=" + std::to_string(stats.storage_limited ? 1 : 0) +
        " state-writes=" + std::to_string(stats.state_writes));
    output.line(
        "[precompile] target=portable-ir attempted=" +
        std::to_string(stats.blocks_attempted) +
        " generated=" + std::to_string(stats.portable_generated) +
        " artifact-hits=" + std::to_string(stats.portable_artifact_hits) +
        " deferred=" + std::to_string(stats.deferred) +
        " unstable=" + std::to_string(stats.unstable) +
        " failed=" + std::to_string(stats.failed) + " deadline-stops=" +
        std::to_string(stats.deadline_stops) + " prepared-memory-bytes=" +
        std::to_string(stats.prepared_memory_bytes));
    output.line(
        "[jit-artifact] resident-bytes=" +
        std::to_string(stats.artifact_stats.resident_bytes) +
        " writeback-pending-bytes=" +
        std::to_string(stats.artifact_stats.writeback_pending_bytes) +
        " disk-bytes=" + std::to_string(stats.artifact_stats.disk_bytes) +
        " disk-hits=" + std::to_string(stats.artifact_stats.disk_hits) +
        " disk-hit-fingerprints=" +
        disk_hit_fingerprint_text(stats.artifact_stats) +
        " memory-hits=" + std::to_string(stats.artifact_stats.memory_hits) +
        " lookup-memory-published=" +
        std::to_string(stats.artifact_stats.memory_published_lookups) +
        " lookup-disk-demand=" +
        std::to_string(stats.artifact_stats.disk_demand_lookups) +
        " lookup-disk-prefetched=" +
        std::to_string(stats.artifact_stats.disk_prefetched_lookups) +
        " validation-successes=" +
        std::to_string(stats.artifact_stats.validation_successes) + " staged=" +
        std::to_string(stats.artifact_stats.staged) + " native-imported=" +
        std::to_string(stats.artifact_stats.native_imported) +
        " already-present=" +
        std::to_string(stats.artifact_stats.already_present) +
        " demand-native-emitted=" +
        std::to_string(stats.artifact_stats.demand_native_emitted) +
        " demand-emit-failed=" +
        std::to_string(stats.artifact_stats.demand_emit_failed) +
        " demand-consumed=" +
        std::to_string(stats.artifact_stats.demand_consumed) +
        " staged-unused=" + std::to_string(stats.artifact_stats.staged_unused) +
        " duplicate-consumptions=" +
        std::to_string(stats.artifact_stats.duplicate_consumptions) +
        " disk-indexed=" +
        std::to_string(stats.artifact_stats.disk_records_indexed) +
        " index-bytes=" + std::to_string(stats.artifact_stats.index_bytes) +
        " hotset-candidates=" +
        std::to_string(stats.artifact_stats.hotset_candidates) +
        " hotset-selected=" +
        std::to_string(stats.artifact_stats.hotset_selected) +
        " hotset-skipped-byte-limit=" +
        std::to_string(stats.artifact_stats.hotset_skipped_byte_limit) +
        " startup-prefetch=" +
        std::to_string(stats.artifact_stats.startup_payloads_prefetched) +
        " startup-prefetch-bytes=" +
        std::to_string(stats.artifact_stats.startup_prefetch_bytes) +
        " prefetched-useful=" +
        std::to_string(stats.artifact_stats.prefetched_useful) +
        " prefetched-unused=" +
        std::to_string(stats.artifact_stats.prefetched_unused) +
        " saved-translation-ns=" +
        std::to_string(stats.artifact_stats.saved_translation_nanoseconds) +
        " load-cost-ns=" +
        std::to_string(stats.artifact_stats.load_cost_nanoseconds) +
        " net-benefit-ns=" +
        std::to_string(stats.artifact_stats.net_benefit_nanoseconds) +
        " demand-payload-loads=" +
        std::to_string(stats.artifact_stats.demand_payload_disk_loads) +
        " background-prepare-requests=" +
        std::to_string(stats.artifact_stats.background_prepare_requests) +
        " background-prepare-deduplicated=" +
        std::to_string(stats.artifact_stats.background_prepare_deduplicated) +
        " background-prepare-rejected=" +
        std::to_string(stats.artifact_stats.background_prepare_rejected) +
        " background-prepare-completed=" +
        std::to_string(stats.artifact_stats.background_prepare_completed) +
        " background-prepare-failed=" +
        std::to_string(stats.artifact_stats.background_prepare_failed) +
        " background-prepare-unused=" +
        std::to_string(stats.artifact_stats.background_prepare_unused) +
        " background-prepare-queue=" +
        std::to_string(stats.artifact_stats.background_prepare_queue_entries) +
        " background-prepare-queue-peak=" +
        std::to_string(
            stats.artifact_stats.background_prepare_queue_peak_entries) +
        " background-prepared=" +
        std::to_string(stats.artifact_stats.background_prepared_entries) +
        " background-prepared-peak=" +
        std::to_string(stats.artifact_stats.background_prepared_peak_entries) +
        " background-ir-ns=" +
        std::to_string(
            stats.artifact_stats.background_ir_deserialization_nanoseconds) +
        " admission-attempts=" +
        std::to_string(stats.artifact_stats.admission_attempts) +
        " admission-rejected=" +
        std::to_string(stats.artifact_stats.admission_rejected) +
        " admission-positive=" +
        std::to_string(stats.artifact_stats.admission_positive) +
        " admission-low-confidence=" +
        std::to_string(stats.artifact_stats.admission_low_confidence) +
        " admission-estimated-load-ns=" +
        std::to_string(
            stats.artifact_stats.admission_estimated_load_nanoseconds) +
        " admission-estimated-saved-ns=" +
        std::to_string(
            stats.artifact_stats.admission_estimated_saved_nanoseconds) +
        " finalizations=" + std::to_string(stats.artifact_stats.finalizations) +
        " finalization-failures=" +
        std::to_string(stats.artifact_stats.finalization_failures) +
        " boot-working-set=" +
        std::to_string(stats.artifact_stats.boot_working_set_artifacts) +
        " evictions=" + std::to_string(stats.artifact_stats.evictions) +
        " quota-evictions=" +
        std::to_string(stats.artifact_stats.quota_evictions));
}

template <std::size_t Size>
void append_word(
    std::array<std::byte, Size>& code, std::size_t offset, std::uint32_t word)
{
    for (std::size_t i = 0; i < 4; ++i) {
        code[offset + i] = static_cast<std::byte>((word >> (i * 8U)) & 0xffU);
    }
}

void disasm(const std::vector<std::string>& args, Output& output)
{
    const auto rootfs = option(args, "--rootfs");
    const auto binary = option(args, "--binary");
    const auto symbol_name = option(args, "--symbol");
    const auto address_option = option(args, "--address");
    if (!rootfs || !binary || (!symbol_name && !address_option) ||
        (symbol_name && address_option)) {
        throw std::runtime_error {
            "disasm requires --rootfs, --binary, and exactly "
            "one of --symbol/--address"
        };
    }
    const auto selected_image = inspection_image(args, *binary);
    const auto& image = *selected_image;
    const MachSymbol* symbol = nullptr;
    std::uint32_t start_address = 0;
    if (symbol_name) {
        symbol = image.find_symbol(*symbol_name);
        if (symbol == nullptr || symbol->value == 0) {
            throw std::runtime_error { "defined symbol not found: " +
                                       *symbol_name };
        }
        start_address = symbol->value;
    } else {
        start_address =
            static_cast<std::uint32_t>(std::stoul(*address_option, nullptr, 0));
        for (const auto& candidate : image.symbols()) {
            if (candidate.value != 0 && candidate.value <= start_address &&
                (symbol == nullptr || candidate.value > symbol->value)) {
                symbol = &candidate;
            }
        }
    }
    const auto count = static_cast<std::size_t>(
        std::stoul(option(args, "--count").value_or("8")));
    const auto thumb =
        std::find(args.begin(), args.end(), "--thumb") != args.end();
    std::ostringstream text;
    if (symbol != nullptr) {
        text << symbol->name;
        if (start_address != symbol->value) {
            text << "+0x" << std::hex << (start_address - symbol->value)
                 << std::dec;
        }
        text << " @ ";
    }
    text << "0x" << std::hex << start_address << std::dec << '\n';
    for (std::size_t index = 0; index < count; ++index) {
        if (thumb) {
            const auto address =
                start_address + static_cast<std::uint32_t>(index * 2U);
            const auto instruction = image.read_vm_u16(address);
            if (!instruction)
                break;
            text << "0x" << std::hex << std::setw(8) << std::setfill('0')
                 << address << "  " << std::setw(4) << *instruction << "      "
                 << Dynarmic::A32::DisassembleThumb16(*instruction) << '\n';
        } else {
            const auto address =
                start_address + static_cast<std::uint32_t>(index * 4U);
            const auto instruction = image.read_vm_u32(address);
            if (!instruction)
                break;
            text << "0x" << std::hex << std::setw(8) << std::setfill('0')
                 << address << "  " << std::setw(8) << *instruction << "  "
                 << Dynarmic::A32::DisassembleArm(*instruction);
            if ((*instruction & 0x0f000000U) == 0x0b000000U) {
                auto displacement =
                    static_cast<std::int32_t>(*instruction << 8U) >> 6U;
                const auto target =
                    address + 8U + static_cast<std::uint32_t>(displacement);
                if (const auto* stub = image.find_stub(target)) {
                    text << " ; " << stub->symbol;
                }
            }
            text << '\n';
        }
    }
    output.write(text.str());
}

void smoke(const std::vector<std::string>& args, Output& output)
{
    const auto core_count_string = option(args, "--cores").value_or("2");
    const auto core_count =
        static_cast<std::size_t>(std::stoul(core_count_string));
    if (core_count == 0 || core_count > maximum_virtual_processors) {
        throw std::runtime_error { "--cores must be in the range 1.." +
                                   std::to_string(maximum_virtual_processors) };
    }

    AddressSpace memory;
    constexpr std::uint32_t code_address = 0x1000;
    memory.map(code_address, AddressSpace::page_size,
        MemoryPermission::Read | MemoryPermission::Write |
            MemoryPermission::Execute);
    std::array<std::byte, 8> code { };
    append_word(code, 0, 0xe2800001U);
    append_word(code, 4, 0xef000080U);
    memory.copy_in(code_address, code);

    Dynarmic::ExclusiveMonitor shared_exclusive_monitor { core_count };
    auto shared_exclusive_address_resolver =
        std::make_shared<GuestExclusiveAddressResolver>();
    CpuCluster cluster { core_count, core_count, memory, core_count,
        default_arm_cpu_model(), shared_exclusive_monitor, 0, { },
        shared_exclusive_address_resolver };
    cluster.set_jit_code_cache_size(jit_code_cache_size(args));
    for (std::size_t index = 0; index < cluster.size(); ++index) {
        cluster.cpu(index).registers()[0] =
            static_cast<std::uint32_t>(index * 100);
        cluster.cpu(index).registers()[15] = code_address;
        cluster.cpu(index).set_cpsr(0x10);
    }
    const auto results = cluster.run_parallel(16);

    std::ostringstream text;
    text << "Dynarmic ARMv6 parallel smoke test: " << core_count
         << " virtual CPU(s)\n";
    if (core_count > 1) {
        text << "mode: exact; execution-slot LDREX state resolves through "
                "GuestPageBacking identity for shared-page atomics\n";
    }
    for (std::size_t index = 0; index < cluster.size(); ++index) {
        text << "cpu" << index << " r0=" << cluster.cpu(index).registers()[0]
             << " pc=0x" << std::hex << cluster.cpu(index).registers()[15]
             << std::dec << " svc="
             << (results[index].svc ? std::to_string(*results[index].svc)
                                    : "none")
             << '\n';
        const auto expected = static_cast<std::uint32_t>(index * 100 + 1);
        if (cluster.cpu(index).registers()[0] != expected ||
            results[index].svc != std::optional<std::uint32_t> { 0x80 }) {
            throw std::runtime_error {
                "Dynarmic smoke test produced an unexpected CPU state"
            };
        }
    }
    text << "status: ok";
    output.line(text.str());
}

void benchmark(const std::vector<std::string>& args, Output& output)
{
    if (args.empty() || args.front() != "arm") {
        throw std::runtime_error { "benchmark requires the 'arm' baseline" };
    }
    const auto value = option(args, "--iterations").value_or("1000000");
    std::size_t consumed = 0;
    const auto parsed = std::stoull(value, &consumed, 10);
    if (consumed != value.size() || parsed == 0 ||
        parsed > std::numeric_limits<std::uint32_t>::max()) {
        throw std::runtime_error {
            "--iterations must be in the range 1..4294967295"
        };
    }
    const auto iterations = static_cast<std::uint32_t>(parsed);

    AddressSpace memory;
    constexpr std::uint32_t code_address = 0x1000;
    if (!memory.map(code_address, AddressSpace::page_size,
            MemoryPermission::Read | MemoryPermission::Write |
                MemoryPermission::Execute)) {
        throw std::runtime_error { "ARM benchmark code mapping failed" };
    }
    std::array<std::byte, 16> code { };
    append_word(code, 0, 0xe3a01000U);
    append_word(code, 4, 0xe2811001U);
    append_word(code, 8, 0xe2500001U);
    append_word(code, 12, 0x1afffffcU);
    if (!memory.copy_in(code_address, code)) {
        throw std::runtime_error { "ARM benchmark code upload failed" };
    }
    constexpr std::uint32_t svc_address = code_address + sizeof(code);
    const std::array<std::byte, 4> svc { std::byte { 0x80 }, std::byte { 0x00 },
        std::byte { 0x00 }, std::byte { 0xef } };
    if (!memory.copy_in(svc_address, svc)) {
        throw std::runtime_error { "ARM benchmark SVC upload failed" };
    }

    CpuCluster cluster { 1, memory };
    cluster.set_jit_code_cache_size(jit_code_cache_size(args));
    auto& cpu = cluster.cpu(0);
    cpu.registers()[0] = iterations;
    cpu.registers()[15] = code_address;
    cpu.set_cpsr(0x10);
    const auto tick_budget = static_cast<std::uint64_t>(iterations) * 16U + 32U;
    const auto started = std::chrono::steady_clock::now();
    const auto result = cpu.run(tick_budget);
    const auto elapsed = std::chrono::steady_clock::now() - started;
    if (cpu.registers()[0] != 0 || cpu.registers()[1] != iterations ||
        result.svc != std::optional<std::uint32_t> { 0x80 }) {
        throw std::runtime_error {
            "ARM benchmark produced an unexpected CPU state"
        };
    }
    const auto elapsed_nanoseconds =
        std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed).count();
    const auto iterations_per_second =
        elapsed_nanoseconds > 0
            ? static_cast<std::uint64_t>(
                  static_cast<long double>(iterations) * 1'000'000'000.0L /
                  static_cast<long double>(elapsed_nanoseconds))
            : 0U;
    output.line(
        "[benchmark] baseline=arm iterations=" + std::to_string(iterations) +
        " ticks=" + std::to_string(result.ticks_consumed) + " elapsed-ns=" +
        std::to_string(elapsed_nanoseconds) + " jit-cache-mib=" +
        std::to_string(jit_code_cache_size(args) / 1024U / 1024U) +
        " iterations-per-second=" + std::to_string(iterations_per_second) +
        " status=ok");
}

void boot(const std::vector<std::string>& args, Output& output)
{
    const auto rootfs = option(args, "--rootfs");
    if (!rootfs)
        throw std::runtime_error { "boot requires --rootfs" };
    BootOptions options;
    options.rootfs = *rootfs;
    options.host_cache = host_cache_directory(args, options.rootfs);
    options.catalog = option(args, "--catalog");
    options.ios_build = ios_build_option(args);
    options.device = select_device_model(args);
    options.gles_backend = parse_gles_backend(args);
    options.binary = option(args, "--binary").value_or("/sbin/launchd");
    options.guest_command = option(args, "--guest-command");
    if (const auto value = option(args, "--display-size"))
        options.display_geometry = parse_display_geometry(*value);
    const auto activation = parse_lockdown_activation(
        option(args, "--activation").value_or("activated"));
    if (!activation)
        throw std::runtime_error {
            "--activation must be activated, unactivated, or preserve"
        };
    options.activation = *activation;
    const auto network =
        parse_host_network_policy(option(args, "--network").value_or("host"));
    if (!network)
        throw std::runtime_error {
            "--network must be isolated, loopback, or host"
        };
    options.network = *network;
    const auto display = option(args, "--display").value_or("headless");
    if (display != "sdl" && display != "headless")
        throw std::runtime_error { "--display must be headless or sdl" };
    options.windowed = display == "sdl";
    options.control_enabled = flag(args, "--control-stdin");
    options.disable_scheduler_preemption =
        flag(args, "--disable-scheduler-preemption");
    if (const auto value = option(args, "--time-scale")) {
        const auto parsed = std::stod(*value);
        if (!(parsed >= 1.0) || parsed > 1000.0) {
            throw std::runtime_error {
                "--time-scale must be between 1 and 1000"
            };
        }
        options.time_scale = parsed;
    }
    options.jit_observer_only = flag(args, "--jit-observer-only");
    options.shared_image_slab = flag(args, "--shared-image-slab");
    if (const auto value = option(args, "--image-slab-mib")) {
        if (!options.shared_image_slab)
            throw std::runtime_error {
                "--image-slab-mib needs --shared-image-slab"
            };
        options.image_slab_bytes = static_cast<std::size_t>(parse_mib_value(
            *value, "--image-slab-mib", 8U,
            JitWorkPolicy::maximum_native_slab_bytes() / bytes_per_mebibyte));
    }
    options.report_performance = flag(args, "--perf-summary");
    options.test_concurrent_threads = flag(args, "--test-concurrent-threads");
    if (const auto value = option(args, "--ticks"))
        options.ticks = std::stoull(*value);
    if (const auto value = option(args, "--cores"))
        options.cores = static_cast<std::size_t>(std::stoul(*value));
    if (option(args, "--jit-cache-mib"))
        options.jit_cache_bytes = jit_code_cache_size(args);
    if (const auto value = option(args, "--jit-cache-budget-mib"))
        options.jit_cache_budget_bytes = static_cast<std::size_t>(
            parse_mib_value(*value, "--jit-cache-budget-mib", 256U,
                JitCodeCacheGovernor::maximum_adaptive_budget_bytes /
                    bytes_per_mebibyte));
    options.artifact_memory_bytes = jit_artifact_memory_limit(args);
    if (const auto value = option(args, "--jit-artifact-disk-mib"))
        options.artifact_disk_bytes = static_cast<std::size_t>(
            parse_mib_value(*value, "--jit-artifact-disk-mib", 0U, 4096U));
    options.jit_profile_mode = parse_jit_profile_mode(args);
    options.jit_catalog_warming = parse_jit_catalog_warming_mode(args);
    options.startup_profile_blocks =
        parse_prepare_count(args, "--jit-startup-profile-blocks", 64U, 64U);
    options.startup_profile_budget_us =
        parse_prepare_count(args, "--jit-startup-profile-budget-us", 4'000U,
            std::numeric_limits<std::size_t>::max());
    options.frame_output = option(args, "--frame-output");
    options.boot_logo = option(args, "--boot-logo");
    options.touch_replay = option(args, "--touch-replay");
    if (const auto value = option(args, "--gdb")) {
        const auto parsed = std::stoul(*value);
        if (parsed == 0 || parsed > std::numeric_limits<std::uint16_t>::max())
            throw std::runtime_error {
                "--gdb must be a TCP port in the range 1..65535"
            };
        options.gdb_port = static_cast<std::uint16_t>(parsed);
    }
    if (const auto value = option(args, "--watch-address")) {
        const auto parsed = std::stoull(*value, nullptr, 0);
        if (parsed > std::numeric_limits<std::uint32_t>::max())
            throw std::runtime_error {
                "--watch-address exceeds the 32-bit guest address space"
            };
        options.watch_address = static_cast<std::uint32_t>(parsed);
    }
    options.baseband_input = option(args, "--baseband-input");
    options.baseband_output = option(args, "--baseband-output");
    options.quiet_output = !flag(args, "--verbose");
    const auto census_output = option(args, "--census-output");
    if (census_output && !options.ticks) {
        throw std::runtime_error {
            "--census-output needs --ticks, which sets the tick it is taken at"
        };
    }
    options.snapshot_output = option(args, "--snapshot-out");
    if (options.snapshot_output && !options.ticks)
        throw std::runtime_error { "--snapshot-out needs --ticks" };
    if (options.snapshot_output &&
        *options.ticks % bounded_tick_alignment != 0)
        throw std::runtime_error {
            "--snapshot-out needs --ticks to be a multiple of " +
            std::to_string(bounded_tick_alignment)
        };
    options.snapshot_input = option(args, "--snapshot-in");
    if (options.snapshot_input && !options.ticks)
        throw std::runtime_error {
            "--snapshot-in needs --ticks, the total tick count of the restored run"
        };
    DesktopHost host { census_output ? std::filesystem::path { *census_output }
                                     : std::filesystem::path { } };
    EmulatorSession session { std::move(options), host, output };
    session.run();
}

}

int main(int argc, char** argv)
{
    try {
        if (argc < 2) {
            std::cerr << usage();
            return 2;
        }
        std::vector<std::string> args;
        for (int i = 2; i < argc; ++i) {
            args.emplace_back(argv[i]);
        }
        const std::string_view command { argv[1] };
        if (command == "help" || command == "--help" || command == "-h" ||
            flag(args, "--help") || flag(args, "-h")) {
            std::cout << usage();
            return 0;
        }
        auto output = make_output(args);
        const auto perf_summary = flag(args, "--perf-summary");
        const auto jit_observer_only = flag(args, "--jit-observer-only");
        if (perf_summary && jit_observer_only) {
            throw std::runtime_error {
                "--perf-summary and --jit-observer-only are mutually exclusive"
            };
        }
        performance_counters().reset(perf_summary);
        const auto perf_frame_content = flag(args, "--perf-frame-content");
        const auto perf_cpu_phases = flag(args, "--perf-cpu-phases");
        const auto perf_jit_native_lookups =
            flag(args, "--perf-jit-native-lookups");
        if (perf_frame_content && !perf_summary) {
            throw std::runtime_error {
                "--perf-frame-content requires --perf-summary"
            };
        }
        performance_counters().set_frame_content_diagnostics(
            perf_frame_content);
        if (perf_cpu_phases && !perf_summary) {
            throw std::runtime_error {
                "--perf-cpu-phases requires --perf-summary"
            };
        }
        performance_counters().set_cpu_source_diagnostics(perf_cpu_phases);
        if (perf_jit_native_lookups && !perf_summary) {
            throw std::runtime_error {
                "--perf-jit-native-lookups requires --perf-summary"
            };
        }
        performance_counters().set_native_lookup_diagnostics(
            perf_jit_native_lookups);
        const auto perf_block_profile = flag(args, "--perf-block-profile");
        if (perf_block_profile && !perf_summary) {
            throw std::runtime_error {
                "--perf-block-profile requires --perf-summary"
            };
        }
        performance_counters().set_block_profile_diagnostics(
            perf_block_profile);
        try {
            if (command == "profile") {
                profile(args, *output);
            } else if (command == "abi") {
                inspect_abi(option(args, "--rootfs"), ios_build_option(args),
                    *output);
            } else if (command == "inspect") {
                inspect(args, *output);
            } else if (command == "catalog") {
                catalog(args, *output);
            } else if (command == "firmware") {
                if (args.empty() || args.front() != "prepare") {
                    throw std::runtime_error {
                        "firmware requires the 'prepare' mode"
                    };
                }
                firmware_prepare(
                    std::vector<std::string> { args.begin() + 1, args.end() },
                    *output);
            } else if (command == "disasm") {
                disasm(args, *output);
            } else if (command == "smoke") {
                smoke(args, *output);
            } else if (command == "benchmark") {
                benchmark(args, *output);
            } else if (command == "boot") {
                boot(args, *output);
            } else {
                throw std::runtime_error { "unknown command: " +
                                           std::string { command } };
            }
        } catch (...) {
            shutdown_gles_renderer();
            if (perf_summary) {
                output->line(format_performance_summary(
                    performance_counters().snapshot()));
            }
            throw;
        }
        shutdown_gles_renderer();
        if (perf_summary && command != "boot") {
            output->line(
                format_performance_summary(performance_counters().snapshot()));
        }
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "emulator: " << error.what() << '\n';
        return 1;
    }
}
