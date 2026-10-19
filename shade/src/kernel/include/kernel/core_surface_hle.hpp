// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest CoreSurface allocation, sharing and pixel-access
// operations.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <vector>

#include "graphics/surface_transport_abi.hpp"

namespace shade {

class AddressSpace;
class DisplayState;
class PresentationTracker;
class SceneCoordinator;
struct KernelSharedState;
class SurfaceStore;
class UserlandHleCall;
class UserlandHleRegistry;

// User-space replacement for the private CoreSurface/IOSurface transports.
// Public CFRuntime wrappers remain firmware code; both private symbol-family
// profiles project their backing storage through one shared SurfaceStore.
class CoreSurfaceHle {
public:
    using CreateSurfacePortHandler =
        std::function<std::uint32_t(std::uint32_t, std::uint32_t)>;
    using LookupSurfacePortHandler = std::function<std::optional<std::uint32_t>(
        std::uint32_t, std::uint32_t)>;

    CoreSurfaceHle(UserlandHleRegistry& registry,
        std::shared_ptr<DisplayState> display,
        std::shared_ptr<SurfaceStore> surfaces = { },
        std::shared_ptr<PresentationTracker> presentations = { });

    void reset();
    void inherit_state(const CoreSurfaceHle& parent);
    void set_display(std::shared_ptr<DisplayState> display);
    void set_presentation_tracker(
        std::shared_ptr<PresentationTracker> presentations);
    void set_shared_state(std::shared_ptr<KernelSharedState> shared_state);
    void set_scene_coordinator(std::shared_ptr<SceneCoordinator> scenes);
    void set_surface_port_handlers(
        CreateSurfacePortHandler create, LookupSurfacePortHandler lookup);
    // The display user client exposes its front buffer as a reserved
    // CoreSurface ID. Unlike ordinary buffers, firmware draws into it while
    // it remains locked and the display controller scans it out at vsync.
    // Return true only when a newly visible frame was submitted.
    bool refresh_default_scanout(
        AddressSpace& memory, std::uint32_t owner_process_id = 0);

private:
    struct Buffer {
        std::uint32_t client { };
        std::uint32_t id { };
        std::uint32_t base { };
        std::uint32_t allocation_size { };
        std::uint32_t width { };
        std::uint32_t height { };
        std::uint32_t bytes_per_row { };
        std::uint32_t pixel_format { };
        std::uint32_t references { 1 };
        std::uint32_t seed { 1 };
        surface_transport::Kind transport {
            surface_transport::Kind::CoreSurfaceClientBuffer
        };
        bool owns_memory { };
        // Lookup imports a shared backing into this process' AddressSpace.
        // Keep the exact page range so the final client release can drop the
        // mapping without touching wrapped guest memory.
        std::uint32_t imported_mapping_base { };
        std::uint32_t imported_mapping_size { };
        std::uint64_t imported_mapping_lease_token { };
        std::vector<std::uint32_t> lock_options;
    };
    struct CreateRequest {
        std::uint32_t dictionary { };
        std::array<std::uint32_t, 7> properties { };
        std::size_t property_index { };
        std::uint32_t number_output { };
        surface_transport::Kind transport {
            surface_transport::Kind::CoreSurfaceClientBuffer
        };
    };

    void dispatch(UserlandHleCall& call);
    void create_from_dictionary(UserlandHleCall& call, std::uint32_t dictionary,
        surface_transport::Kind transport);
    void read_next_create_property(
        UserlandHleCall& call, const std::shared_ptr<CreateRequest>& request);
    void finish_create_from_dictionary(
        UserlandHleCall& call, const std::shared_ptr<CreateRequest>& request);
    [[nodiscard]] std::uint32_t create_default_buffer(UserlandHleCall& call,
        std::uint32_t requested_id = 0,
        surface_transport::Kind transport =
            surface_transport::Kind::CoreSurfaceClientBuffer);
    [[nodiscard]] std::uint32_t wrap_client_memory(UserlandHleCall& call,
        std::uint32_t base, std::uint32_t size,
        surface_transport::Kind transport);
    [[nodiscard]] std::uint32_t lookup_buffer(UserlandHleCall& call,
        std::uint32_t requested_id, surface_transport::Kind transport);
    [[nodiscard]] std::uint32_t create_mach_port(
        UserlandHleCall& call, const Buffer& buffer);
    [[nodiscard]] std::uint32_t lookup_from_mach_port(UserlandHleCall& call,
        std::uint32_t port_name, surface_transport::Kind transport);
    [[nodiscard]] std::uint32_t create_buffer(UserlandHleCall& call,
        std::uint32_t base, std::uint32_t size, std::uint32_t width,
        std::uint32_t height, std::uint32_t bytes_per_row,
        std::uint32_t pixel_format, bool owns_memory,
        std::uint32_t requested_id = 0, bool publish = true,
        surface_transport::Kind transport =
            surface_transport::Kind::CoreSurfaceClientBuffer);
    [[nodiscard]] std::uint32_t acquire_client_buffer(
        UserlandHleCall& call, const surface_transport::ClientAbi& profile);
    void recycle_client_buffer(
        std::uint32_t client, const surface_transport::ClientAbi& profile);
    [[nodiscard]] std::uint32_t acquire_imported_mapping(
        UserlandHleCall& call, std::uint32_t size);
    void recycle_imported_mapping(std::uint32_t base, std::uint32_t size);
    void release_imported_mapping(AddressSpace& memory, std::uint32_t base,
        std::uint32_t size, std::uint64_t mapping_lease_token);
    [[nodiscard]] Buffer* find(std::uint32_t client);
    void submit(Buffer& buffer, UserlandHleCall& call);

    std::map<std::uint32_t, Buffer> buffers_;
    std::map<std::pair<std::uint32_t, surface_transport::Kind>, std::uint32_t>
        clients_by_id_;
    std::map<std::uint32_t, std::vector<std::uint32_t>> free_client_buffers_;
    // Imported page ranges come from the HLE data arena, whose general-purpose
    // allocator is intentionally monotonic. Reuse only ranges that this class
    // allocated, unmapped, and observed through final client release.
    std::map<std::uint32_t, std::uint32_t> free_imported_mappings_;
    std::size_t unsupported_trace_count_ { };
    std::optional<std::uint64_t> last_scanout_generation_;
    std::vector<std::uint32_t> last_scanout_pixels_;
    std::shared_ptr<DisplayState> display_;
    std::shared_ptr<SurfaceStore> surfaces_;
    std::shared_ptr<PresentationTracker> presentation_tracker_;
    std::shared_ptr<KernelSharedState> shared_state_;
    std::shared_ptr<SceneCoordinator> scene_coordinator_;
    CreateSurfacePortHandler create_surface_port_;
    LookupSurfacePortHandler lookup_surface_port_;
};

} // namespace shade
