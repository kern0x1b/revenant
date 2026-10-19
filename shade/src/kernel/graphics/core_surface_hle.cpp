// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest CoreSurface allocation, sharing and pixel-access
// operations.

#include "kernel/core_surface_hle.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <iterator>
#include <limits>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/application_display.hpp"
#include "foundation/application_path.hpp"
#include "graphics/core_surface_abi.hpp"
#include "foundation/cpu.hpp"
#include "graphics/display.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "foundation/output.hpp"
#include "graphics/presentation_tracker.hpp"
#include "foundation/scene_coordinator.hpp"
#include "graphics/surface_store.hpp"
#include "foundation/userland_hle.hpp"
#include "surface_transport_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view core_surface_image {
        "/CoreSurface.framework/CoreSurface"
    };
    constexpr std::string_view io_surface_image {
        "/IOSurface.framework/IOSurface"
    };
    constexpr std::string_view core_foundation_image {
        "/CoreFoundation.framework/CoreFoundation"
    };
    constexpr std::string_view client_buffer_prefix {
        "_CoreSurfaceClientBuffer"
    };
    constexpr std::string_view client_buffer_alloc {
        "_CoreSurfaceClientBufferAlloc"
    };
    constexpr std::string_view client_buffer_wrap_image {
        "_CoreSurfaceClientBufferWrapClientImage"
    };
    constexpr std::string_view client_buffer_wrap_image_transport {
        "__coreSurfaceClientBufferWrapClientImage"
    };

    constexpr std::size_t client_buffer_alignment = 16;
    constexpr std::size_t pixel_buffer_alignment = 64;
    constexpr std::size_t maximum_unsupported_traces = 32;
    constexpr std::uint64_t maximum_surface_bytes = 256ULL * 1024ULL * 1024ULL;
    constexpr std::uint32_t cf_number_sint32_type = 3;

    enum CreateProperty : std::size_t {
        client_address,
        allocation_size,
        width,
        height,
        pitch,
        pixel_format,
        data_offset,
    };

    // Bytes in guest memory are B,G,R,A; when read as a little-endian uint32_t
    // this is the DisplayState 0xAARRGGBB representation without conversion.
    constexpr std::uint32_t success = 0;

    std::optional<ApplicationDisplay> application_display_for_process(
        const std::shared_ptr<KernelSharedState>& shared_state,
        std::uint32_t process_id)
    {
        if (!shared_state)
            return std::nullopt;
        std::lock_guard lock { shared_state->mach_mutex };
        const auto process = shared_state->processes.find(process_id);
        return process == shared_state->processes.end()
                   ? std::nullopt
                   : std::optional<ApplicationDisplay> {
                         process->second.application_display };
    }

    DisplayGeometry display_geometry_for_process(
        const std::shared_ptr<KernelSharedState>& shared_state,
        std::uint32_t process_id, DisplayGeometry output)
    {
        const auto profile =
            application_display_for_process(shared_state, process_id);
        return profile ? application_display_geometry(*profile, output) : output;
    }

} // namespace

CoreSurfaceHle::CoreSurfaceHle(UserlandHleRegistry& registry,
    std::shared_ptr<DisplayState> display,
    std::shared_ptr<SurfaceStore> surfaces,
    std::shared_ptr<PresentationTracker> presentations)
    : display_ { std::move(display) }
    , surfaces_ { surfaces ? std::move(surfaces)
                           : std::make_shared<SurfaceStore>() }
    , presentation_tracker_ { std::move(presentations) }
{
    registry.register_prefix(std::string { core_surface_image },
        std::string { client_buffer_prefix },
        [this](UserlandHleCall& call) { dispatch(call); });
    registry.register_prefix(std::string { io_surface_image },
        std::string { surface_transport::io_surface_client.symbol_prefix },
        [this](UserlandHleCall& call) { dispatch(call); });
    // These public helpers construct the firmware's client wrapper around a
    // transport identifier. Keep that native object lifecycle and intercept
    // only the private transport transaction that would otherwise require
    // the unavailable CoreSurface kernel user client.
    for (const auto symbol :
        { client_buffer_alloc, client_buffer_wrap_image }) {
        registry.register_function(std::string { core_surface_image },
            std::string { symbol },
            [](UserlandHleCall& call) { call.resume_original_persistently(); });
    }
    registry.register_function(std::string { core_surface_image },
        std::string { client_buffer_wrap_image_transport },
        [this](UserlandHleCall& call) { dispatch(call); });
    const auto register_property_symbols =
        [&registry](const surface_transport::ClientAbi& profile) {
            for (const auto symbol : profile.create_property_symbols) {
                if (!symbol.empty()) {
                    registry.register_guest_data_symbol(
                        std::string { profile.image_suffix },
                        std::string { symbol });
                }
            }
        };
    register_property_symbols(surface_transport::core_surface_client_buffer);
    register_property_symbols(surface_transport::io_surface_client);
    registry.register_guest_function(
        std::string { core_foundation_image }, "_CFDictionaryGetValue");
    registry.register_guest_function(
        std::string { core_foundation_image }, "_CFNumberGetValue");
}

void CoreSurfaceHle::reset()
{
    buffers_.clear();
    clients_by_id_.clear();
    free_client_buffers_.clear();
    free_imported_mappings_.clear();
    unsupported_trace_count_ = 0;
    last_scanout_generation_.reset();
    last_scanout_pixels_.clear();
    surfaces_->reset();
}

void CoreSurfaceHle::inherit_state(const CoreSurfaceHle& parent)
{
    buffers_ = parent.buffers_;
    clients_by_id_ = parent.clients_by_id_;
    free_client_buffers_ = parent.free_client_buffers_;
    free_imported_mappings_ = parent.free_imported_mappings_;
    last_scanout_generation_ = parent.last_scanout_generation_;
    last_scanout_pixels_ = parent.last_scanout_pixels_;
    presentation_tracker_ = parent.presentation_tracker_;
    surfaces_->inherit_state(*parent.surfaces_);
}

void CoreSurfaceHle::set_display(std::shared_ptr<DisplayState> display)
{
    display_ = std::move(display);
}

void CoreSurfaceHle::set_presentation_tracker(
    std::shared_ptr<PresentationTracker> presentations)
{
    presentation_tracker_ = std::move(presentations);
}

void CoreSurfaceHle::set_shared_state(
    std::shared_ptr<KernelSharedState> shared_state)
{
    shared_state_ = std::move(shared_state);
}

void CoreSurfaceHle::set_scene_coordinator(
    std::shared_ptr<SceneCoordinator> scenes)
{
    scene_coordinator_ = std::move(scenes);
}

void CoreSurfaceHle::set_surface_port_handlers(
    CreateSurfacePortHandler create, LookupSurfacePortHandler lookup)
{
    create_surface_port_ = std::move(create);
    lookup_surface_port_ = std::move(lookup);
}

bool CoreSurfaceHle::refresh_default_scanout(
    AddressSpace& memory, std::uint32_t owner_process_id)
{
    if (!display_)
        return false;
    const auto backing =
        surfaces_->find(iokit_abi::mobile_framebuffer_default_surface_id);
    if (!backing)
        return false;
    const auto generation =
        memory.range_write_generation(backing->base, backing->allocation_size);
    if (!generation || generation == last_scanout_generation_)
        return false;
    last_scanout_generation_ = generation;
    const auto pixels = surfaces_->read_argb(
        memory, iokit_abi::mobile_framebuffer_default_surface_id);
    if (!pixels || pixels->empty() || *pixels == last_scanout_pixels_) {
        return false;
    }

    // A freshly allocated CoreSurface is zero-filled.  Do not replace the
    // display's opaque-black power-on frame until the firmware has actually
    // rendered something into the LCD backing store.
    if (std::none_of(pixels->begin(), pixels->end(),
            [](std::uint32_t pixel) { return pixel != 0; })) {
        last_scanout_pixels_ = *pixels;
        return false;
    }

    std::optional<ApplicationDisplay> profile;
    if (shared_state_) {
        std::lock_guard lock { shared_state_->mach_mutex };
        const auto process = shared_state_->processes.find(owner_process_id);
        if (process != shared_state_->processes.end() &&
            process->second.application_display.kind !=
                ApplicationDisplayMode::Native) {
            profile = process->second.application_display;
        }
    }
    auto display_pixels = *pixels;
    if (profile) {
        display_pixels = compose_application_display_pixels(*profile,
            { backing->width, backing->height }, display_->geometry(),
            display_pixels);
        if (display_pixels.empty())
            return false;
    }
    last_scanout_pixels_ = *pixels;
    display_->replace_pixels(std::move(display_pixels), owner_process_id);
    display_->present(owner_process_id);
    return true;
}

CoreSurfaceHle::Buffer* CoreSurfaceHle::find(std::uint32_t client)
{
    const auto found = buffers_.find(client);
    return found == buffers_.end() ? nullptr : &found->second;
}

void CoreSurfaceHle::create_from_dictionary(UserlandHleCall& call,
    std::uint32_t dictionary, surface_transport::Kind transport)
{
    if (dictionary == 0) {
        call.set_return(create_default_buffer(call, 0, transport));
        return;
    }
    auto request = std::make_shared<CreateRequest>();
    request->dictionary = dictionary;
    request->transport = transport;
    request->number_output =
        call.allocate_data(sizeof(std::uint32_t), alignof(std::uint32_t));
    if (request->number_output == 0) {
        call.set_return(0);
        return;
    }
    read_next_create_property(call, request);
}

void CoreSurfaceHle::read_next_create_property(
    UserlandHleCall& call, const std::shared_ptr<CreateRequest>& request)
{
    const auto& profile = surface_transport::for_kind(request->transport);
    if (request->property_index >= profile.create_property_symbols.size()) {
        finish_create_from_dictionary(call, request);
        return;
    }
    const auto property_symbol =
        profile.create_property_symbols[request->property_index];
    if (property_symbol.empty()) {
        ++request->property_index;
        read_next_create_property(call, request);
        return;
    }
    const auto variable = call.symbol_address(property_symbol);
    const auto key = variable ? call.memory().read32(*variable).value_or(0) : 0;
    if (key == 0) {
        ++request->property_index;
        read_next_create_property(call, request);
        return;
    }
    call.cpu().registers()[0] = request->dictionary;
    call.cpu().registers()[1] = key;
    if (!call.call_guest_function("_CFDictionaryGetValue",
            [this, request](UserlandHleCall& value_call) {
                const auto value = value_call.cpu().registers()[0];
                if (value == 0) {
                    ++request->property_index;
                    read_next_create_property(value_call, request);
                    return;
                }
                if (!value_call.memory().write32(request->number_output, 0)) {
                    value_call.set_return(0);
                    return;
                }
                value_call.cpu().registers()[0] = value;
                value_call.cpu().registers()[1] = cf_number_sint32_type;
                value_call.cpu().registers()[2] = request->number_output;
                if (!value_call.call_guest_function("_CFNumberGetValue",
                        [this, request](UserlandHleCall& number_call) {
                            if (number_call.cpu().registers()[0] != 0) {
                                request->properties[request->property_index] =
                                    number_call.memory()
                                        .read32(request->number_output)
                                        .value_or(0);
                            }
                            ++request->property_index;
                            read_next_create_property(number_call, request);
                        })) {
                    value_call.set_return(0);
                }
            })) {
        call.set_return(0);
    }
}

void CoreSurfaceHle::finish_create_from_dictionary(
    UserlandHleCall& call, const std::shared_ptr<CreateRequest>& request)
{
    const auto address = request->properties[client_address];
    auto size = request->properties[allocation_size];
    const auto surface_width = request->properties[width];
    const auto surface_height = request->properties[height];
    auto bytes_per_row = request->properties[pitch];
    auto format = request->properties[pixel_format];
    const auto offset = request->properties[data_offset];

    if (format == 0)
        format = surface_pixel_format_bgra;
    const auto bytes_per_pixel = surface_bytes_per_pixel(format);
    const auto decoded_row_bytes =
        static_cast<std::uint64_t>(surface_width) * bytes_per_pixel;
    if (bytes_per_row == 0 && bytes_per_pixel != 0U &&
        decoded_row_bytes <= std::numeric_limits<std::uint32_t>::max()) {
        bytes_per_row = static_cast<std::uint32_t>(decoded_row_bytes);
    }
    // CoreSurface also transports encoded and otherwise opaque byte buffers.
    // Those formats have no host-side bytes-per-pixel interpretation, but the
    // firmware still supplies an exact pitch, height, and allocation size.
    const auto row_bytes = bytes_per_pixel == 0U
                               ? static_cast<std::uint64_t>(bytes_per_row)
                               : decoded_row_bytes;
    const auto required =
        surface_height == 0
            ? 0
            : static_cast<std::uint64_t>(surface_height - 1U) * bytes_per_row +
                  row_bytes;
    if (size == 0 && required <= std::numeric_limits<std::uint32_t>::max()) {
        size = static_cast<std::uint32_t>(required);
    }
    const auto valid_offset = offset <= size;
    const auto usable_size = valid_offset ? size - offset : 0;
    const auto valid_address =
        address <= std::numeric_limits<std::uint32_t>::max() - offset;
    const auto base = valid_address ? address + offset : 0;

    // The CoreSurface compatibility wrapper can forward a framebuffer request
    // whose dictionary contains only the pixel format.  The native transport
    // supplies the display geometry for that form; keep the same implicit
    // default instead of returning a null client that the firmware will use.
    if (address == 0 && size == 0 && surface_width == 0 &&
        surface_height == 0 && bytes_per_row == 0 && offset == 0 &&
        format == surface_pixel_format_bgra) {
        call.set_return(create_default_buffer(call, 0, request->transport));
        return;
    }

    if (surface_width == 0 || surface_height == 0 || bytes_per_row == 0 ||
        row_bytes > bytes_per_row || required == 0 || required > usable_size ||
        usable_size > maximum_surface_bytes) {
        call.output().write("[coresurface-hle] invalid create properties\n");
        call.set_return(0);
        return;
    }

    auto owns_memory = address == 0;
    auto storage = base;
    if (owns_memory) {
        storage = call.allocate_data(usable_size, pixel_buffer_alignment);
    } else if (!call.memory().mapped(storage, usable_size)) {
        storage = 0;
    }
    call.set_return(
        storage == 0 ? 0
                     : create_buffer(call, storage, usable_size, surface_width,
                           surface_height, bytes_per_row, format, owns_memory,
                           0, true, request->transport));
}

std::uint32_t CoreSurfaceHle::create_default_buffer(UserlandHleCall& call,
    std::uint32_t requested_id, surface_transport::Kind transport)
{
    const auto geometry = display_geometry_for_process(shared_state_,
        call.process_id(),
        display_ ? display_->geometry() : default_display_geometry);
    const auto width = geometry.width;
    const auto height = geometry.height;
    const auto pitch = width * core_surface_abi::bytes_per_bgra_pixel;
    const auto size = pitch * height;
    const auto base = call.allocate_data(size, pixel_buffer_alignment);
    if (base == 0)
        return 0;
    return create_buffer(call, base, size, width, height, pitch,
        surface_pixel_format_bgra, true, requested_id, true, transport);
}

std::uint32_t CoreSurfaceHle::wrap_client_memory(UserlandHleCall& call,
    std::uint32_t base, std::uint32_t size, surface_transport::Kind transport)
{
    if (base == 0 || size < core_surface_abi::bytes_per_bgra_pixel ||
        !call.memory().mapped(base, size)) {
        return 0;
    }
    const auto geometry = display_geometry_for_process(shared_state_,
        call.process_id(),
        display_ ? display_->geometry() : default_display_geometry);
    const auto full_screen_size = geometry.width * geometry.height *
                                  core_surface_abi::bytes_per_bgra_pixel;
    const auto width =
        size >= full_screen_size
            ? geometry.width
            : std::max(1U, size / core_surface_abi::bytes_per_bgra_pixel);
    const auto height = size >= full_screen_size ? geometry.height : 1U;
    return create_buffer(call, base, size, width, height,
        width * core_surface_abi::bytes_per_bgra_pixel,
        surface_pixel_format_bgra, false, 0, true, transport);
}

std::uint32_t CoreSurfaceHle::lookup_buffer(UserlandHleCall& call,
    std::uint32_t requested_id, surface_transport::Kind transport)
{
    if (requested_id == 0)
        return 0;
    const auto client_key = std::pair { requested_id, transport };
    auto client = clients_by_id_.find(client_key);
    const auto retain_existing = client != clients_by_id_.end();
    if (client == clients_by_id_.end()) {
        std::uint32_t created = 0;
        if (const auto local = surfaces_->find(requested_id)) {
            created = create_buffer(call, local->base, local->allocation_size,
                local->width, local->height, local->bytes_per_row,
                local->pixel_format, false, requested_id, false, transport);
        } else if (const auto shared =
                       surfaces_->shared_mapping(requested_id)) {
            const auto mapping_address =
                acquire_imported_mapping(call, shared->mapping_size);
            if (mapping_address != 0) {
                std::uint64_t mapping_lease_token = 0;
                if (const auto imported = surfaces_->import(call.memory(),
                        *shared, mapping_address, &mapping_lease_token)) {
                    created = create_buffer(call, imported->base,
                        imported->allocation_size, imported->width,
                        imported->height, imported->bytes_per_row,
                        imported->pixel_format, false, requested_id, false,
                        transport);
                    if (auto* buffer = find(created)) {
                        buffer->imported_mapping_base = mapping_address;
                        buffer->imported_mapping_size = shared->mapping_size;
                        buffer->imported_mapping_lease_token =
                            mapping_lease_token;
                    } else {
                        surfaces_->release(requested_id);
                        release_imported_mapping(call.memory(), mapping_address,
                            shared->mapping_size, mapping_lease_token);
                    }
                } else {
                    // import() installs the complete page range or nothing.
                    // Do not unmap on failure: the guest may have occupied
                    // this candidate after the availability check.
                    recycle_imported_mapping(
                        mapping_address, shared->mapping_size);
                }
            }
        } else {
            created = create_default_buffer(call, requested_id, transport);
        }
        if (created == 0)
            return 0;
        client = clients_by_id_.find(client_key);
    }
    auto* buffer = find(client->second);
    if (buffer && retain_existing) {
        const auto& profile = surface_transport::for_kind(transport);
        ++buffer->references;
        static_cast<void>(call.memory().write32(
            buffer->client + profile.reference_count_offset,
            buffer->references));
    }
    return client->second;
}

std::uint32_t CoreSurfaceHle::create_mach_port(
    UserlandHleCall& call, const Buffer& buffer)
{
    return create_surface_port_
               ? create_surface_port_(call.process_id(), buffer.id)
               : 0U;
}

std::uint32_t CoreSurfaceHle::lookup_from_mach_port(UserlandHleCall& call,
    std::uint32_t port_name, surface_transport::Kind transport)
{
    if (!lookup_surface_port_ || port_name == 0)
        return 0;
    const auto surface_id = lookup_surface_port_(call.process_id(), port_name);
    return surface_id ? lookup_buffer(call, *surface_id, transport) : 0U;
}

std::uint32_t CoreSurfaceHle::create_buffer(UserlandHleCall& call,
    std::uint32_t base, std::uint32_t size, std::uint32_t width,
    std::uint32_t height, std::uint32_t bytes_per_row,
    std::uint32_t pixel_format, bool owns_memory, std::uint32_t requested_id,
    bool publish, surface_transport::Kind transport)
{
    const auto& profile = surface_transport::for_kind(transport);
    const auto client = acquire_client_buffer(call, profile);
    if (client == 0)
        return 0;
    const auto id =
        requested_id == 0 ? surfaces_->allocate_identifier() : requested_id;
    const std::pair<std::uint32_t, std::uint32_t> fields[] {
        { profile.reference_count_offset, 1 },
        { profile.identifier_offset, id },
        { profile.base_address_offset, base },
        { profile.allocation_size_offset, size },
        { profile.width_offset, width },
        { profile.height_offset, height },
        { profile.bytes_per_row_offset, bytes_per_row },
        { profile.data_offset_offset, 0 },
        { profile.pixel_format_offset, pixel_format },
        { profile.plane_count_offset, 0 },
    };
    for (const auto& [offset, value] : fields) {
        if (!call.memory().write32(client + offset, value)) {
            recycle_client_buffer(client, profile);
            return 0;
        }
    }
    auto backing = SurfaceStore::Backing { id, base, size, width, height,
        bytes_per_row, pixel_format, { } };
    backing.provenance.producer_process_id = call.process_id();
    // Only the legacy continuously scanned display surface needs per-store
    // generations. Ordinary CoreSurface/IOSurface buffers publish completed
    // CPU writes at their explicit synchronization boundary instead.
    if (pixel_format == surface_pixel_format_bgra &&
        id == iokit_abi::mobile_framebuffer_default_surface_id &&
        !call.memory().track_write_generation(base, size)) {
        recycle_client_buffer(client, profile);
        return 0;
    }
    if (publish && !surfaces_->publish(call.memory(), backing)) {
        recycle_client_buffer(client, profile);
        return 0;
    }
    const auto application_viewport_minimum_height =
        display_ ? display_->height() -
                       std::min(display_->height(), std::uint32_t { 64 })
                 : 0U;
    if (publish && pixel_format == surface_pixel_format_bgra && shared_state_ &&
        display_ && width == display_->width() &&
        height >= application_viewport_minimum_height &&
        height <= display_->height() &&
        bytes_per_row ==
            display_->width() * core_surface_abi::bytes_per_bgra_pixel) {
        const auto published = surfaces_->find(id);
        if (published && published->provenance.publication_sequence != 0U) {
            std::lock_guard lock { shared_state_->mach_mutex };
            const auto process =
                shared_state_->processes.find(call.process_id());
            if (process != shared_state_->processes.end() &&
                is_application_executable_path(
                    process->second.executable_path)) {
                const auto publication_sequence =
                    published->provenance.publication_sequence;
                shared_state_
                    ->application_fullscreen_surface_publications[call
                            .process_id()]
                    .insert(publication_sequence);
                if (shared_state_
                        ->suppress_future_application_fullscreen_surface_processes
                        .contains(call.process_id())) {
                    shared_state_
                        ->suppressed_application_fullscreen_surface_publications
                        .emplace(call.process_id(), publication_sequence);
                    shared_state_
                        ->application_fullscreen_surface_suppression_active
                        .store(true, std::memory_order_release);
                }
            }
        }
    }
    buffers_[client] =
        Buffer { client, id, base, size, width, height, bytes_per_row,
            pixel_format, 1, 1, transport, owns_memory, 0, 0, 0, { } };
    clients_by_id_[{ id, transport }] = client;
    call.output().write(
        "[coresurface-hle] create pid=" + std::to_string(call.process_id()) +
        " id=" + std::to_string(id) + " client=" + std::to_string(client) +
        " base=" + std::to_string(base) + " size=" + std::to_string(size) +
        "\n");
    return client;
}

std::uint32_t CoreSurfaceHle::acquire_client_buffer(
    UserlandHleCall& call, const surface_transport::ClientAbi& profile)
{
    constexpr auto permissions =
        MemoryPermission::Read | MemoryPermission::Write;
    auto& free_clients = free_client_buffers_[profile.client_structure_size];
    while (!free_clients.empty()) {
        const auto client = free_clients.back();
        free_clients.pop_back();
        if (!call.memory().accessible(
                client, profile.client_structure_size, permissions)) {
            continue;
        }
        std::vector<std::byte> cleared(profile.client_structure_size);
        if (call.memory().copy_in(client, cleared))
            return client;
    }

    const auto client = call.allocate_data(
        profile.client_structure_size, client_buffer_alignment);
    if (client == 0)
        return 0;
    std::vector<std::byte> cleared(profile.client_structure_size);
    return call.memory().copy_in(client, cleared) ? client : 0;
}

void CoreSurfaceHle::recycle_client_buffer(
    std::uint32_t client, const surface_transport::ClientAbi& profile)
{
    if (client != 0)
        free_client_buffers_[profile.client_structure_size].push_back(client);
}

std::uint32_t CoreSurfaceHle::acquire_imported_mapping(
    UserlandHleCall& call, std::uint32_t size)
{
    if (size == 0 || size % AddressSpace::page_size != 0)
        return 0;

    auto selected = free_imported_mappings_.end();
    for (auto candidate = free_imported_mappings_.begin();
        candidate != free_imported_mappings_.end();) {
        bool occupied = false;
        for (std::uint64_t page = candidate->first;
            page <
            static_cast<std::uint64_t>(candidate->first) + candidate->second;
            page += AddressSpace::page_size) {
            if (call.memory().mapped(static_cast<std::uint32_t>(page))) {
                occupied = true;
                break;
            }
        }
        if (occupied) {
            candidate = free_imported_mappings_.erase(candidate);
            continue;
        }
        if (candidate->second < size) {
            ++candidate;
            continue;
        }
        if (selected == free_imported_mappings_.end() ||
            candidate->second < selected->second) {
            selected = candidate;
        }
        ++candidate;
    }
    if (selected != free_imported_mappings_.end()) {
        const auto address = selected->first;
        const auto available = selected->second;
        free_imported_mappings_.erase(selected);
        if (available > size) {
            free_imported_mappings_.emplace(address + size, available - size);
        }
        return address;
    }

    const auto address = call.allocate_data(size, AddressSpace::page_size);
    if (address == 0 || !call.memory().unmap(address, size))
        return 0;
    return address;
}

void CoreSurfaceHle::recycle_imported_mapping(
    std::uint32_t base, std::uint32_t size)
{
    if (base == 0 || size == 0 || base % AddressSpace::page_size != 0 ||
        size % AddressSpace::page_size != 0 ||
        size > std::numeric_limits<std::uint32_t>::max() - base) {
        return;
    }

    auto merged_base = base;
    auto merged_end = static_cast<std::uint64_t>(base) + size;
    auto next = free_imported_mappings_.lower_bound(base);
    if (next != free_imported_mappings_.begin()) {
        const auto previous = std::prev(next);
        const auto previous_end =
            static_cast<std::uint64_t>(previous->first) + previous->second;
        if (previous_end >= merged_base) {
            merged_base = previous->first;
            merged_end = std::max(merged_end, previous_end);
            free_imported_mappings_.erase(previous);
        }
    }
    next = free_imported_mappings_.lower_bound(merged_base);
    while (next != free_imported_mappings_.end() && next->first <= merged_end) {
        merged_end = std::max(
            merged_end, static_cast<std::uint64_t>(next->first) + next->second);
        next = free_imported_mappings_.erase(next);
    }
    free_imported_mappings_.emplace(
        merged_base, static_cast<std::uint32_t>(merged_end - merged_base));
}

void CoreSurfaceHle::release_imported_mapping(AddressSpace& memory,
    std::uint32_t base, std::uint32_t size, std::uint64_t mapping_lease_token)
{
    if (base != 0 && size != 0 &&
        memory.unmap_mapping_lease(mapping_lease_token)) {
        recycle_imported_mapping(base, size);
    }
}

void CoreSurfaceHle::submit(Buffer& buffer, UserlandHleCall& call)
{
    if (!display_)
        return;
    const auto output_geometry = display_->geometry();
    const auto guest_geometry = display_geometry_for_process(shared_state_,
        call.process_id(), output_geometry);
    if (buffer.width != guest_geometry.width ||
        buffer.height != guest_geometry.height ||
        buffer.bytes_per_row !=
            guest_geometry.width * core_surface_abi::bytes_per_bgra_pixel) {
        return;
    }
    std::optional<ApplicationDisplay> profile;
    if (shared_state_) {
        std::lock_guard lock { shared_state_->mach_mutex };
        const auto process = shared_state_->processes.find(call.process_id());
        if (process != shared_state_->processes.end() &&
            is_application_executable_path(process->second.executable_path)) {
            if (!active_application_owns_display_locked(*shared_state_,
                call.process_id(),
                scene_coordinator_
                    ? std::optional<bool> { scene_coordinator_
                              ->client_scene_presentable(call.process_id()) }
                    : std::nullopt)) {
                return;
            }
            if (process->second.application_display.kind !=
                ApplicationDisplayMode::Native) {
                profile = process->second.application_display;
            }
        }
    }
    // Unlock publishes guest writes to the CoreSurface backing. Once the
    // firmware has entered transactional hardware-layer presentation, only
    // IOMobileFramebuffer SwapEnd may turn those backing updates into scanout.
    if (presentation_tracker_ && presentation_tracker_->has_presented_frame()) {
        return;
    }
    const auto bytes =
        call.memory().read_bytes(buffer.base, buffer.allocation_size);
    if (!bytes || bytes->size() < static_cast<std::size_t>(guest_geometry.width) *
                                      guest_geometry.height *
                                      core_surface_abi::bytes_per_bgra_pixel) {
        return;
    }
    std::vector<std::uint32_t> pixels(guest_geometry.pixel_count());
    for (std::size_t index = 0; index < pixels.size(); ++index) {
        const auto offset = index * core_surface_abi::bytes_per_bgra_pixel;
        pixels[index] =
            std::to_integer<std::uint32_t>((*bytes)[offset]) |
            (std::to_integer<std::uint32_t>((*bytes)[offset + 1U]) << 8U) |
            (std::to_integer<std::uint32_t>((*bytes)[offset + 2U]) << 16U) |
            (std::to_integer<std::uint32_t>((*bytes)[offset + 3U]) << 24U);
    }
    if (profile)
        pixels = compose_application_display_pixels(*profile,
            guest_geometry, output_geometry, pixels);
    if (profile && pixels.empty())
        return;
    display_->replace_pixels(std::move(pixels), call.process_id());
}

void CoreSurfaceHle::dispatch(UserlandHleCall& call)
{
    const auto symbol = call.symbol();
    if (symbol == client_buffer_wrap_image_transport) {
        const auto width = call.argument(0);
        const auto height = call.argument(1);
        const auto pixel_format = call.argument(2);
        const auto bytes_per_row = call.argument(3);
        const auto allocation_size = call.argument(4);
        const auto base = call.argument(5);
        const auto output = call.argument(6);
        const auto bytes_per_pixel = surface_bytes_per_pixel(pixel_format);
        const auto row_bytes =
            static_cast<std::uint64_t>(width) * bytes_per_pixel;
        const auto required =
            height == 0
                ? 0
                : static_cast<std::uint64_t>(height - 1U) * bytes_per_row +
                      row_bytes;
        if (output == 0 ||
            !call.memory().mapped(output, sizeof(std::uint32_t)) || base == 0 ||
            width == 0 || height == 0 || bytes_per_pixel == 0 ||
            row_bytes > bytes_per_row || required == 0 ||
            required > allocation_size ||
            allocation_size > maximum_surface_bytes ||
            !call.memory().mapped(base, allocation_size)) {
            call.set_return(1);
            return;
        }
        const auto client = create_buffer(call, base, allocation_size, width,
            height, bytes_per_row, pixel_format, false);
        const auto* buffer = find(client);
        // The firmware's CoreSurfaceClientBufferAlloc owns the public wrapper
        // and expects the transport transaction to return its numeric object
        // identifier. Keep the HLE client private to the transport layer.
        if (buffer == nullptr || !call.memory().write32(output, buffer->id)) {
            call.set_return(1);
            return;
        }
        call.set_return(success);
        return;
    }
    const auto transport =
        symbol.starts_with(surface_transport::io_surface_client.symbol_prefix)
            ? surface_transport::io_surface_kind(call)
            : surface_transport::Kind::CoreSurfaceClientBuffer;
    const auto& profile = surface_transport::for_kind(transport);
    if (!symbol.starts_with(profile.symbol_prefix)) {
        call.set_return(0);
        return;
    }
    const auto operation = symbol.substr(profile.symbol_prefix.size());

    if (operation == "Create") {
        create_from_dictionary(call, call.argument(0), transport);
        return;
    }
    if (operation == "WrapClientMemory") {
        call.set_return(wrap_client_memory(
            call, call.argument(0), call.argument(1), transport));
        return;
    }
    if (operation == "WrapClientImage") {
        const auto width = call.argument(0);
        const auto height = call.argument(1);
        const auto pixel_format = call.argument(2);
        const auto bytes_per_row = call.argument(3);
        const auto allocation_size = call.argument(4);
        const auto base = call.argument(5);
        const auto bytes_per_pixel = surface_bytes_per_pixel(pixel_format);
        const auto row_bytes =
            static_cast<std::uint64_t>(width) * bytes_per_pixel;
        const auto required =
            height == 0
                ? 0
                : static_cast<std::uint64_t>(height - 1U) * bytes_per_row +
                      row_bytes;
        call.set_return(
            base == 0 || width == 0 || height == 0 || bytes_per_pixel == 0 ||
                    row_bytes > bytes_per_row || required == 0 ||
                    required > allocation_size ||
                    allocation_size > maximum_surface_bytes ||
                    !call.memory().mapped(base, allocation_size)
                ? 0
                : create_buffer(call, base, allocation_size, width, height,
                      bytes_per_row, pixel_format, false, 0, true, transport));
        return;
    }
    if (operation == "Lookup") {
        call.set_return(lookup_buffer(call, call.argument(0), transport));
        return;
    }
    if (operation == "LookupFromMachPort") {
        call.set_return(
            lookup_from_mach_port(call, call.argument(0), transport));
        return;
    }

    const auto argument = call.argument(0);
    auto* buffer = find(argument);
    if (buffer == nullptr) {
        // Also accept a direct transport identifier or a native client object
        // carrying that identifier at its profile-defined offset.
        auto client = clients_by_id_.find({ argument, transport });
        if (client == clients_by_id_.end() &&
            argument <= std::numeric_limits<std::uint32_t>::max() -
                            profile.identifier_offset) {
            if (const auto identifier = call.memory().read32(
                    argument + profile.identifier_offset)) {
                client = clients_by_id_.find({ *identifier, transport });
            }
        }
        if (client != clients_by_id_.end()) {
            buffer = find(client->second);
        }
    }
    if (buffer == nullptr) {
        call.set_return(0);
        return;
    }
    const auto& buffer_abi = surface_transport::for_kind(buffer->transport);
    if (operation == "CreateMachPort") {
        call.set_return(create_mach_port(call, *buffer));
    } else if (operation == "Retain") {
        ++buffer->references;
        static_cast<void>(call.memory().write32(
            buffer->client + buffer_abi.reference_count_offset,
            buffer->references));
        call.set_return(argument);
    } else if (operation == "Release") {
        if (buffer->references != 0)
            --buffer->references;
        static_cast<void>(call.memory().write32(
            buffer->client + buffer_abi.reference_count_offset,
            buffer->references));
        if (buffer->references == 0) {
            const auto client = buffer->client;
            const auto id = buffer->id;
            const auto imported_mapping_base = buffer->imported_mapping_base;
            const auto imported_mapping_size = buffer->imported_mapping_size;
            const auto imported_mapping_lease_token =
                buffer->imported_mapping_lease_token;
            const auto indexed = clients_by_id_.find({ id, buffer->transport });
            if (indexed != clients_by_id_.end() && indexed->second == client) {
                clients_by_id_.erase(indexed);
            }
            buffers_.erase(client);
            surfaces_->release(id);
            release_imported_mapping(call.memory(), imported_mapping_base,
                imported_mapping_size, imported_mapping_lease_token);
            recycle_client_buffer(client, buffer_abi);
        }
        call.set_return(0);
    } else if (operation == "GetID") {
        call.set_return(buffer->id);
    } else if (operation == "GetAllocSize") {
        call.set_return(buffer->allocation_size);
    } else if (operation == "GetWidth") {
        call.set_return(buffer->width);
    } else if (operation == "GetWidthOfPlane") {
        call.set_return(call.argument(1) == 0 ? buffer->width : 0);
    } else if (operation == "GetHeight") {
        call.set_return(buffer->height);
    } else if (operation == "GetHeightOfPlane") {
        call.set_return(call.argument(1) == 0 ? buffer->height : 0);
    } else if (operation == "GetBytesPerRow") {
        call.set_return(buffer->bytes_per_row);
    } else if (operation == "GetBytesPerRowOfPlane") {
        call.set_return(call.argument(1) == 0 ? buffer->bytes_per_row : 0);
    } else if (operation == "GetPixelFormatType" ||
               operation == "GetPixelFormat") {
        call.set_return(buffer->pixel_format);
    } else if (operation == "GetBaseAddress") {
        call.set_return(buffer->base);
    } else if (operation == "GetBaseAddressOfPlane") {
        call.set_return(call.argument(1) == 0 ? buffer->base : 0);
    } else if (operation == "GetPlaneCount") {
        call.set_return(0);
    } else if (operation == "GetSeed" || operation == "GetSeedOfPlane") {
        call.set_return(buffer->seed);
    } else if (operation == "GetOffset" || operation == "GetOffsetOfPlane") {
        call.set_return(0);
    } else if (operation == "GetBytesPerElement" ||
               operation == "GetBytesPerElementOfPlane") {
        call.set_return(core_surface_abi::bytes_per_bgra_pixel);
    } else if (operation == "GetElementWidth" ||
               operation == "GetElementHeight" ||
               operation == "GetElementWidthOfPlane" ||
               operation == "GetElementHeightOfPlane" ||
               operation == "GetBlockWidthOfPlane" ||
               operation == "GetBlockHeightOfPlane") {
        call.set_return(1);
    } else if (operation == "GetBitsPerBlock" ||
               operation == "GetBitsPerBlockOfPlane") {
        call.set_return(32);
    } else if (operation == "IsGlobal") {
        call.set_return(1);
    } else if (operation == "Lock" || operation == "LockPlane") {
        const auto options = call.argument(1);
        const auto synchronized = surfaces_->synchronize_for_cpu(call.memory(),
            buffer->id,
            SurfaceStore::CpuSynchronizationOptions {
                .avoid_sync =
                    (options & core_surface_abi::lock_avoid_sync) != 0,
                .read_only = (options & core_surface_abi::lock_read_only) != 0,
            });
        if (synchronized)
            buffer->lock_options.push_back(options);
        if (synchronized && buffer_abi.lock_seed_output &&
            call.argument(2) != 0) {
            static_cast<void>(
                call.memory().write32(call.argument(2), buffer->seed));
        }
        call.set_return(synchronized ? success : 1U);
    } else if (operation == "FlushProcessorCaches") {
        static_cast<void>(
            surfaces_->synchronize_from_guest(call.memory(), buffer->id));
        call.set_return(success);
    } else if (operation == "Unlock" || operation == "UnlockPlane") {
        // A matching explicit Lock is authoritative. WrapClientImage also
        // owns an implicit lock and later calls Unlock with its options in r1,
        // so preserve that firmware argument when no explicit Lock was seen.
        auto options = call.argument(1);
        if (!buffer->lock_options.empty()) {
            options = buffer->lock_options.back();
            buffer->lock_options.pop_back();
        }
        if ((options & core_surface_abi::lock_read_only) == 0) {
            static_cast<void>(
                surfaces_->synchronize_from_guest(call.memory(), buffer->id));
            ++buffer->seed;
            submit(*buffer, call);
        }
        if (buffer_abi.lock_seed_output && call.argument(2) != 0) {
            static_cast<void>(
                call.memory().write32(call.argument(2), buffer->seed));
        }
        call.set_return(success);
    } else if (operation == "GetYCbCrMatrix" || operation == "CopyProperty" ||
               operation == "CopyValue") {
        call.set_return(0);
    } else if (operation == "SetYCbCrMatrix" || operation == "SetProperty" ||
               operation == "RemoveProperty" || operation == "SetValue" ||
               operation == "RemoveValue" || operation == "IncrementUseCount" ||
               operation == "DecrementUseCount" || operation == "BindAccel" ||
               operation == "BindAccelOnPlane") {
        call.set_return(success);
    } else if (operation == "GetUseCount" || operation == "IsInUse") {
        call.set_return(0);
    } else {
        if (unsupported_trace_count_ < maximum_unsupported_traces) {
            call.output().write(
                "[coresurface-hle] deferred symbol=" + std::string { symbol } +
                " pid=" + std::to_string(call.process_id()) + "\n");
            ++unsupported_trace_count_;
        }
        call.set_return(0);
    }
}

} // namespace shade
