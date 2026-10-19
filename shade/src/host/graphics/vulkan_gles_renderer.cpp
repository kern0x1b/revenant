// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Render guest GLES state and shared surfaces through Vulkan.

#include "vulkan_gles_renderer.hpp"
#include "vulkan_memory_allocator.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <chrono>
#include <cmath>
#include <compare>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <tuple>
#include <utility>
#include <vector>

#include "graphics/display.hpp"
#include "graphics/gles_abi.hpp"
#include "graphics/gles_primitive_assembler.hpp"
#include "graphics/gles_resources.hpp"
#include "graphics/gles_sampler_state.hpp"

namespace shade {
namespace {

    constexpr VkFormat color_format = VK_FORMAT_B8G8R8A8_UNORM;
    constexpr std::uint64_t fence_timeout_nanoseconds = 5'000'000'000ULL;
    constexpr std::uint64_t acquire_timeout_nanoseconds = 2'000'000ULL;
    constexpr std::size_t maximum_batch_draws = 128;
    constexpr std::size_t command_ring_size = 6;
    constexpr VkDeviceSize minimum_vertex_arena_bytes = 1U << 20U;
    constexpr VkDeviceSize minimum_staging_arena_bytes = 4U << 20U;
    constexpr VkDeviceSize staging_alignment = 256U;
    constexpr std::uintmax_t maximum_pipeline_cache_bytes = 64U * 1024U * 1024U;
    constexpr VkDeviceSize mebibyte = 1024U * 1024U;
    constexpr VkDeviceSize default_texture_cache_budget = 128U * mebibyte;
    constexpr VkDeviceSize maximum_texture_cache_budget = 256U * mebibyte;
    constexpr std::size_t maximum_texture_cache_entries = 4096;
    constexpr VkDeviceSize render_target_pool_budget = 32U * mebibyte;
    constexpr std::size_t maximum_render_target_pool_entries = 64;
    constexpr HostSurfaceKey quad_white_surface_key {
        std::numeric_limits<std::uint64_t>::max(),
        std::numeric_limits<std::uint64_t>::max()
    };
    constexpr float host_quad_edge_tolerance = 0.01F;

    VkImageAspectFlags stencil_aspect(VkFormat format)
    {
        return format == VK_FORMAT_S8_UINT
                   ? VK_IMAGE_ASPECT_STENCIL_BIT
                   : VK_IMAGE_ASPECT_DEPTH_BIT | VK_IMAGE_ASPECT_STENCIL_BIT;
    }

    HostPoint expand_quad_triangle_vertex(std::span<const HostPoint> values,
        const std::array<std::size_t, 3>& triangle, std::size_t vertex)
    {
        HostPoint sum { };
        for (const auto index : triangle) {
            sum.x += values[index].x;
            sum.y += values[index].y;
        }
        const auto& value = values[triangle[vertex]];
        constexpr auto scale = 1.0F + 3.0F * host_quad_edge_tolerance;
        return { scale * value.x - host_quad_edge_tolerance * sum.x,
            scale * value.y - host_quad_edge_tolerance * sum.y };
    }

    bool valid_host_quad(std::span<const HostPoint> positions)
    {
        if (positions.size() != 4)
            return false;
        const auto diagonal_x = positions[2].x - positions[0].x;
        const auto diagonal_y = positions[2].y - positions[0].y;
        const auto side = [&](std::size_t vertex) {
            const auto point_x = positions[vertex].x - positions[0].x;
            const auto point_y = positions[vertex].y - positions[0].y;
            return diagonal_x * point_y - diagonal_y * point_x;
        };
        const auto first = side(1);
        const auto second = side(3);
        return (first > host_quad_edge_tolerance &&
                   second < -host_quad_edge_tolerance) ||
               (first < -host_quad_edge_tolerance &&
                   second > host_quad_edge_tolerance);
    }

    void add_damage(
        std::optional<HostRectangle>& damage, HostRectangle rectangle)
    {
        if (!damage) {
            damage = rectangle;
            return;
        }
        const auto x = std::min(damage->x, rectangle.x);
        const auto y = std::min(damage->y, rectangle.y);
        const auto right =
            std::max(static_cast<std::int64_t>(damage->x) + damage->width,
                static_cast<std::int64_t>(rectangle.x) + rectangle.width);
        const auto bottom =
            std::max(static_cast<std::int64_t>(damage->y) + damage->height,
                static_cast<std::int64_t>(rectangle.y) + rectangle.height);
        damage = HostRectangle { x, y, static_cast<std::uint32_t>(right - x),
            static_cast<std::uint32_t>(bottom - y) };
    }


    void require_success(VkResult result, std::string_view operation)
    {
        if (result == VK_SUCCESS)
            return;
        throw std::runtime_error {
            std::string { operation } + " failed with VkResult " +
            std::to_string(static_cast<std::int32_t>(result))
        };
    }

    template <typename Structure>
    Structure make_vulkan_structure(VkStructureType type)
    {
        Structure value { };
        value.sType = type;
        return value;
    }

    std::vector<std::byte> read_pipeline_cache(
        const std::filesystem::path& path)
    {
        if (path.empty())
            return { };
        std::error_code error;
        const auto size = std::filesystem::file_size(path, error);
        if (error || size == 0 || size > maximum_pipeline_cache_bytes)
            return { };
        std::ifstream input { path, std::ios::binary };
        if (!input)
            return { };
        std::vector<std::byte> data(static_cast<std::size_t>(size));
        input.read(reinterpret_cast<char*>(data.data()),
            static_cast<std::streamsize>(data.size()));
        return input ? std::move(data) : std::vector<std::byte> { };
    }

    void write_pipeline_cache(
        const std::filesystem::path& path, std::span<const std::byte> data)
    {
        if (path.empty() || data.empty())
            return;
        std::error_code error;
        std::filesystem::create_directories(path.parent_path(), error);
        if (error)
            return;
        auto temporary = path;
        temporary += ".tmp";
        {
            std::ofstream output { temporary,
                std::ios::binary | std::ios::trunc };
            if (!output)
                return;
            output.write(reinterpret_cast<const char*>(data.data()),
                static_cast<std::streamsize>(data.size()));
            if (!output)
                return;
        }
        std::filesystem::rename(temporary, path, error);
        if (error) {
            std::filesystem::remove(path, error);
            error.clear();
            std::filesystem::rename(temporary, path, error);
        }
        if (error)
            std::filesystem::remove(temporary, error);
    }

#if 0
std::vector<std::uint32_t> compile_shader(std::string_view source,
                                          shaderc_shader_kind kind,
                                          std::string_view name) {
    shaderc::Compiler compiler;
    shaderc::CompileOptions options;
    options.SetTargetEnvironment(shaderc_target_env_vulkan,
                                 shaderc_env_version_vulkan_1_0);
    options.SetOptimizationLevel(shaderc_optimization_level_performance);
    const auto result = compiler.CompileGlslToSpv(
        source.data(), source.size(), kind, std::string{name}.c_str(), options);
    if (result.GetCompilationStatus() != shaderc_compilation_status_success) {
        throw std::runtime_error{std::string{name} + ": " +
                                 result.GetErrorMessage()};
    }
    return {result.cbegin(), result.cend()};
}
#endif

    constexpr std::uint32_t vertex_shader_code[] =
#include "gles.vert.inc"
        ;
    constexpr std::uint32_t fragment_shader_code[] =
#include "gles.frag.inc"
        ;

    struct GpuVertex {
        std::array<float, 4> position { };
        std::array<float, 4> color { };
        std::array<float, 2> texture0 { };
        std::array<float, 2> texture1 { };
        std::array<float, 2> texture2 { };
        std::array<float, 2> texture3 { };
    };

    struct alignas(16) GpuTextureEnvironment {
        std::array<std::int32_t, 4> mode_combine_enabled { };
        std::array<float, 4> color { };
        std::array<std::int32_t, 4> rgb_sources { };
        std::array<std::int32_t, 4> alpha_sources { };
        std::array<std::int32_t, 4> rgb_operands { };
        std::array<std::int32_t, 4> alpha_operands { };
        std::array<float, 4> scales_rectangle { };
        std::array<float, 4> clamp_rectangle { };
    };

    struct alignas(16) GpuFixedFunctionState {
        std::array<GpuTextureEnvironment, gles_abi::texture_unit_count>
            units { };
        std::array<std::int32_t, 4> target_flags { };
    };

    static_assert(gles_abi::texture_unit_count == 4);
    static_assert(sizeof(GpuVertex) == 64);
    static_assert(sizeof(GpuTextureEnvironment) == 128);
    static_assert(sizeof(GpuFixedFunctionState) ==
                  128 * gles_abi::texture_unit_count + 16);

    struct PipelineKey {
        enum class StencilMode : std::uint8_t {
            Disabled,
            WriteFirstTriangle,
            TestOutsideFirstTriangle,
        };

        bool blend_enabled { };
        std::uint32_t blend_source { };
        std::uint32_t blend_destination { };
        std::uint8_t color_mask { };
        StencilMode stencil_mode { };

        auto operator<=>(const PipelineKey&) const = default;
    };

    constexpr std::uint32_t constant_alpha_blend_factor = 0x8003U;
    constexpr std::uint32_t one_minus_constant_alpha_blend_factor = 0x8004U;

    class VulkanGlesRenderer final : public GlesRenderer {
    public:
        VulkanGlesRenderer(std::filesystem::path pipeline_cache,
            const VulkanPresenterConfiguration* presenter,
            GlesDeviceSelection selection);
        ~VulkanGlesRenderer() override;

        VulkanGlesRenderer(const VulkanGlesRenderer&) = delete;
        VulkanGlesRenderer& operator=(const VulkanGlesRenderer&) = delete;

        bool draw(DisplayFrame& frame, GlesRenderTargetKey target,
            std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
            const GlesRasterState& state) override;
        bool flush(GlesRenderTargetKey target) override;
        bool finish(GlesRenderTargetKey target) override;
        bool synchronize(DisplayFrame& frame, GlesRenderTargetKey target,
            std::optional<HostRectangle>* readback_damage) override;
        void invalidate(GlesRenderTargetKey target) override;
        void release(std::span<const GlesRenderTargetKey> targets) override;
        void release_owner(std::uint64_t owner) override;
        [[nodiscard]] std::string_view name() const override
        {
            return renderer_name_;
        }
        [[nodiscard]] bool accelerated() const override { return true; }
        [[nodiscard]] bool hardware_accelerated() const override
        {
            return hardware_accelerated_;
        }
        [[nodiscard]] bool software_fallback_allowed() const override
        {
            return false;
        }
        [[nodiscard]] PerfFallbackReason failure_reason() const override
        {
            return last_failure_reason_.load(std::memory_order_relaxed);
        }
        [[nodiscard]] std::uint64_t resource_bytes() const noexcept override;
        [[nodiscard]] HostNativeImage native_image(
            const HostSurface& surface) const override;
        [[nodiscard]] std::unique_ptr<CommandEncoder>
        create_command_encoder() override;
        [[nodiscard]] PresentResult present(
            const std::shared_ptr<HostSurface>& surface) override;
        [[nodiscard]] bool native_presentation_available() const override
        {
            return presentation_swapchain_ != VK_NULL_HANDLE;
        }
        [[nodiscard]] bool release_presentation_surface() override;
        [[nodiscard]] bool refresh_presentation_surface() override;

    private:
        class Encoder;
        struct Buffer {
            VkDevice device { };
            VkBuffer buffer { };
            VkDeviceMemory memory { };
            VkDeviceSize size { };
            void* mapped { };
            bool coherent { };

            Buffer() = default;
            Buffer(const Buffer&) = delete;
            Buffer& operator=(const Buffer&) = delete;
            Buffer(Buffer&& other) noexcept;
            Buffer& operator=(Buffer&& other) noexcept;
            ~Buffer();
        };

        struct Image {
            VmaAllocator allocator { };
            VmaAllocation allocation { };
            VkDevice device { };
            VkImage image { };
            VkImageView view { };
            VkSampler sampler { };
            std::uint32_t width { };
            std::uint32_t height { };
            VkDeviceSize allocation_size { };
            bool rectangle { };

            Image() = default;
            Image(const Image&) = delete;
            Image& operator=(const Image&) = delete;
            Image(Image&& other) noexcept;
            Image& operator=(Image&& other) noexcept;
            ~Image();

            void reset() noexcept;
        };

        struct TextureKey {
            std::uint64_t owner { };
            HostSurfaceKey surface { };
            std::uint32_t name { };
            bool uses_surface { };
            bool rectangle { };

            auto operator<=>(const TextureKey&) const = default;
        };

        struct Target {
            Image image;
            Image stencil;
            Buffer download;
            VkFramebuffer framebuffer { };
            VkFramebuffer stencil_framebuffer { };
            VkImageLayout layout { VK_IMAGE_LAYOUT_UNDEFINED };
            std::uint64_t cpu_generation { };
            PerfSurfaceKind kind { PerfSurfaceKind::GlesRenderTarget };
            bool valid { };
            std::optional<HostRectangle> dirty;
        };

        struct PooledTarget {
            Target target;
            VkDeviceSize allocation_size { };
            std::uint64_t last_used { };
        };

        struct SurfacePreparation {
            std::uint64_t cpu_generation { };
            std::uint64_t gpu_generation { };
            DisplayFrame cpu_frame;
            std::vector<HostRectangle> cpu_damage;
        };

        struct CachedTexture {
            Image image;
            std::uint64_t revision { };
            std::uint64_t last_used { };
            std::uint64_t last_upload_batch { };
            std::uint64_t last_draw_batch { };
        };

        struct CommandSlot {
            VkCommandBuffer command { };
            VkFence fence { };
            VkSemaphore image_available { };
            std::array<VkDescriptorSet, maximum_batch_draws> descriptors { };
            Buffer staging;
            Buffer vertex;
            Buffer uniform;
            VkDeviceSize staging_bytes_used { };
            VkDeviceSize vertex_bytes_used { };
            std::size_t draw_count { };
            bool in_flight { };
        };

        [[nodiscard]] std::uint32_t find_memory_type(std::uint32_t candidates,
            VkMemoryPropertyFlags required,
            VkMemoryPropertyFlags preferred = 0) const;
        [[nodiscard]] Buffer create_buffer(VkDeviceSize size,
            VkBufferUsageFlags usage, VkMemoryPropertyFlags required,
            VkMemoryPropertyFlags preferred = 0) const;
        void create_color_image_pool();
        [[nodiscard]] Image create_image(std::uint32_t width,
            std::uint32_t height, VkImageUsageFlags usage, bool sampled,
            bool rectangle, VkFormat format = color_format,
            VkImageAspectFlags aspect = VK_IMAGE_ASPECT_COLOR_BIT) const;
        void ensure_buffer(
            Buffer& buffer, VkDeviceSize size, VkBufferUsageFlags usage) const;
        [[nodiscard]] Target& ensure_target(
            GlesRenderTargetKey key, std::uint32_t width, std::uint32_t height);
        [[nodiscard]] std::optional<Target> take_pooled_target(
            std::uint32_t width, std::uint32_t height);
        void pool_target(Target&& target);
        void trim_target_pool();
        void destroy_target_framebuffers(Target& target) noexcept;
        [[nodiscard]] static VkDeviceSize target_allocation_size(
            const Target& target);
        void ensure_stencil_framebuffer(Target& target);
        void upload(Buffer& buffer, const void* data, std::size_t size,
            VkDeviceSize offset = 0,
            PerfSurfaceKind surface = PerfSurfaceKind::Unknown) const;
        void download(Buffer& buffer, void* destination, std::size_t size,
            PerfSurfaceKind surface = PerfSurfaceKind::Unknown) const;
        void begin_commands();
        void submit_commands(bool wait = true,
            PerfSubmitReason reason = PerfSubmitReason::Other,
            VkSemaphore wait_semaphore = VK_NULL_HANDLE,
            VkPipelineStageFlags wait_stage = VK_PIPELINE_STAGE_TRANSFER_BIT,
            VkSemaphore signal_semaphore = VK_NULL_HANDLE);
        void wait_for_slot(CommandSlot& slot);
        void wait_for_all_slots();
        [[nodiscard]] CommandSlot& command_slot()
        {
            return command_slots_[command_slot_index_];
        }
        void end_render_pass();
        [[nodiscard]] bool encode_fill(HostSurface& destination,
            HostRectangle rectangle, std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha);
        [[nodiscard]] bool encode_copy(HostSurface& source,
            HostSurface& destination, HostRectangle source_rectangle,
            HostRectangle destination_rectangle, HostCompositeMode mode,
            std::uint8_t global_alpha, HostFilter filter, HostRotation rotation,
            std::optional<HostRectangle> clip);
        [[nodiscard]] bool encode_fill_triangles(HostSurface& destination,
            std::span<const HostPoint> positions, HostRectangle scissor,
            std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha);
        [[nodiscard]] bool encode_copy_triangles(HostSurface& source,
            HostSurface& destination,
            std::span<const HostTexturedVertex> vertices, HostRectangle scissor,
            HostCompositeMode mode, std::uint8_t global_alpha,
            HostFilter filter);
        [[nodiscard]] bool encode_fill_quad(HostSurface& destination,
            std::span<const HostPoint> positions, HostRectangle scissor,
            std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha);
        [[nodiscard]] bool encode_copy_quad(HostSurface& source,
            HostSurface& destination,
            std::span<const HostTexturedVertex> vertices,
            HostRectangle source_rectangle, HostRectangle scissor,
            HostCompositeMode mode, std::uint8_t global_alpha,
            HostFilter filter);
        [[nodiscard]] bool draw_host_texture(Target& source,
            Target& destination, HostSurfaceKey destination_key,
            HostSurfaceDescriptor destination_descriptor,
            std::span<const GpuVertex> vertices, HostRectangle viewport,
            HostRectangle scissor, HostCompositeMode mode,
            std::uint8_t global_alpha, bool ordered_quad = false,
            std::optional<HostRectangle> source_clamp = std::nullopt);
        [[nodiscard]] Target& prepare_host_surface(HostSurface& surface,
            const DisplayFrame& cpu_frame, std::uint64_t cpu_generation,
            std::uint64_t gpu_generation,
            std::vector<HostRectangle> cpu_damage);
        [[nodiscard]] SurfacePreparation capture_surface_preparation(
            HostSurface& surface);
        [[nodiscard]] bool create_presentation_swapchain();
        [[nodiscard]] bool recreate_presentation_surface();
        void destroy_presentation_swapchain() noexcept;
        [[nodiscard]] PresentResult present_target(Target& target);
        void discard_commands() noexcept;
        [[nodiscard]] VkShaderModule create_shader_module(
            std::span<const std::uint32_t> code) const;
        [[nodiscard]] VkPipeline pipeline(const PipelineKey& key);
        [[nodiscard]] std::optional<VkBlendFactor> blend_factor(
            std::uint32_t factor) const;
        [[nodiscard]] std::vector<GpuVertex> expand_vertices(
            std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
            const GlesRasterState& state) const;
        [[nodiscard]] GpuFixedFunctionState fixed_function_state(
            const GlesRasterState& state) const;
        void transition_image(VkCommandBuffer command, VkImage image,
            VkImageLayout old_layout, VkImageLayout new_layout,
            VkPipelineStageFlags source_stage,
            VkPipelineStageFlags destination_stage, VkAccessFlags source_access,
            VkAccessFlags destination_access) const;
        void destroy() noexcept;

        VkInstance instance_ { };
        VulkanPresenterConfiguration presenter_;
        VkSurfaceKHR presentation_surface_ { };
        VkSwapchainKHR presentation_swapchain_ { };
        VkFormat presentation_format_ { };
        VkFilter presentation_filter_ { VK_FILTER_NEAREST };
        VkExtent2D presentation_extent_ { };
        std::vector<VkImage> presentation_images_;
        std::vector<VkImageLayout> presentation_layouts_;
        std::vector<VkSemaphore> presentation_render_finished_;
        VkPhysicalDevice physical_device_ { };
        bool hardware_accelerated_ { };
        VkFormat stencil_format_ { VK_FORMAT_UNDEFINED };
        VkDevice device_ { };
        VmaAllocator image_allocator_ { };
        VmaPool color_image_pool_ { };
        VkQueue queue_ { };
        std::uint32_t queue_family_ { };
        VkPhysicalDeviceMemoryProperties memory_properties_ { };
        VkCommandPool command_pool_ { };
        VkRenderPass render_pass_ { };
        VkRenderPass stencil_render_pass_ { };
        VkDescriptorSetLayout descriptor_layout_ { };
        VkPipelineLayout pipeline_layout_ { };
        VkPipelineCache pipeline_cache_ { };
        VkDescriptorPool descriptor_pool_ { };
        VkSampler host_clamp_sampler_ { };
        std::map<GlesSamplerState, VkSampler> texture_samplers_;
        [[nodiscard]] VkSampler texture_sampler(const GlesSamplerState& state);
        VkShaderModule vertex_shader_ { };
        VkShaderModule fragment_shader_ { };
        std::map<PipelineKey, VkPipeline> pipelines_;
        std::map<GlesRenderTargetKey, Target> targets_;
        std::multimap<std::pair<std::uint32_t, std::uint32_t>, PooledTarget>
            target_pool_;
        VkDeviceSize target_pool_bytes_ { };
        std::uint64_t target_pool_use_sequence_ { };
        std::shared_ptr<HostSurface> quad_white_surface_;
        std::map<TextureKey, CachedTexture> texture_cache_;
        VkDeviceSize texture_cache_bytes_ { };
        VkDeviceSize texture_cache_budget_bytes_ {
            default_texture_cache_budget
        };
        std::uint64_t texture_use_sequence_ { };
        std::uint64_t batch_sequence_ { 1 };
        VkDeviceSize uniform_stride_ { };
        std::array<CommandSlot, command_ring_size> command_slots_;
        std::size_t command_slot_index_ { };
        bool command_recording_ { };
        bool render_pass_open_ { };
        std::optional<GlesRenderTargetKey> render_pass_target_;
        std::string renderer_name_;
        std::filesystem::path pipeline_cache_path_;
        mutable std::mutex mutex_;
        // Non-zero only while a native presenter owns mutex_ and has committed
        // to submit every command recorded before releasing it. Encoder::submit
        // may then use that guaranteed queue boundary instead of blocking a
        // Guest thread on presentation work.
        std::atomic<std::uint32_t> presentation_submissions_pending_ { };
        std::atomic<PerfFallbackReason> last_failure_reason_ {
            PerfFallbackReason::None
        };
    };

    VulkanGlesRenderer::Buffer::Buffer(Buffer&& other) noexcept
        : device { std::exchange(other.device, VK_NULL_HANDLE) }
        , buffer { std::exchange(other.buffer, VK_NULL_HANDLE) }
        , memory { std::exchange(other.memory, VK_NULL_HANDLE) }
        , size { std::exchange(other.size, 0) }
        , mapped { std::exchange(other.mapped, nullptr) }
        , coherent { std::exchange(other.coherent, false) }
    {
    }

    VulkanGlesRenderer::Buffer& VulkanGlesRenderer::Buffer::operator=(
        Buffer&& other) noexcept
    {
        if (this == &other)
            return *this;
        if (mapped != nullptr)
            vkUnmapMemory(device, memory);
        if (buffer != VK_NULL_HANDLE)
            vkDestroyBuffer(device, buffer, nullptr);
        if (memory != VK_NULL_HANDLE)
            vkFreeMemory(device, memory, nullptr);
        device = std::exchange(other.device, VK_NULL_HANDLE);
        buffer = std::exchange(other.buffer, VK_NULL_HANDLE);
        memory = std::exchange(other.memory, VK_NULL_HANDLE);
        size = std::exchange(other.size, 0);
        mapped = std::exchange(other.mapped, nullptr);
        coherent = std::exchange(other.coherent, false);
        return *this;
    }

    VulkanGlesRenderer::Buffer::~Buffer()
    {
        if (mapped != nullptr)
            vkUnmapMemory(device, memory);
        if (buffer != VK_NULL_HANDLE)
            vkDestroyBuffer(device, buffer, nullptr);
        if (memory != VK_NULL_HANDLE)
            vkFreeMemory(device, memory, nullptr);
    }

    VulkanGlesRenderer::Image::Image(Image&& other) noexcept
        : allocator { std::exchange(other.allocator, nullptr) }
        , allocation { std::exchange(other.allocation, nullptr) }
        , device { std::exchange(other.device, VK_NULL_HANDLE) }
        , image { std::exchange(other.image, VK_NULL_HANDLE) }
        , view { std::exchange(other.view, VK_NULL_HANDLE) }
        , sampler { std::exchange(other.sampler, VK_NULL_HANDLE) }
        , width { std::exchange(other.width, 0) }
        , height { std::exchange(other.height, 0) }
        , allocation_size { std::exchange(other.allocation_size, 0) }
        , rectangle { std::exchange(other.rectangle, false) }
    {
    }

    VulkanGlesRenderer::Image& VulkanGlesRenderer::Image::operator=(
        Image&& other) noexcept
    {
        if (this == &other)
            return *this;
        reset();
        allocator = std::exchange(other.allocator, nullptr);
        allocation = std::exchange(other.allocation, nullptr);
        device = std::exchange(other.device, VK_NULL_HANDLE);
        image = std::exchange(other.image, VK_NULL_HANDLE);
        view = std::exchange(other.view, VK_NULL_HANDLE);
        sampler = std::exchange(other.sampler, VK_NULL_HANDLE);
        width = std::exchange(other.width, 0);
        height = std::exchange(other.height, 0);
        allocation_size = std::exchange(other.allocation_size, 0);
        rectangle = std::exchange(other.rectangle, false);
        return *this;
    }

    VulkanGlesRenderer::Image::~Image() { reset(); }

    void VulkanGlesRenderer::Image::reset() noexcept
    {
        if (sampler != VK_NULL_HANDLE)
            vkDestroySampler(device, sampler, nullptr);
        if (view != VK_NULL_HANDLE)
            vkDestroyImageView(device, view, nullptr);
        if (allocator != nullptr)
            vmaDestroyImage(allocator, image, allocation);
        allocator = nullptr;
        allocation = nullptr;
        device = VK_NULL_HANDLE;
        image = VK_NULL_HANDLE;
        view = VK_NULL_HANDLE;
        sampler = VK_NULL_HANDLE;
    }

    class VulkanGlesRenderer::Encoder final : public CommandEncoder {
    public:
        explicit Encoder(VulkanGlesRenderer& renderer)
            : renderer_ { renderer }
        {
        }

        bool fill(const std::shared_ptr<HostSurface>& destination,
            HostRectangle rectangle, std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha) override
        {
            const auto encoded = destination != nullptr &&
                                 renderer_.encode_fill(*destination, rectangle,
                                     argb, mode, global_alpha);
            if (encoded)
                performance_counters().record_host_fill();
            return encoded;
        }

        bool copy(const std::shared_ptr<HostSurface>& source,
            const std::shared_ptr<HostSurface>& destination,
            HostRectangle source_rectangle, HostRectangle destination_rectangle,
            HostCompositeMode mode, std::uint8_t global_alpha,
            HostFilter filter, HostRotation rotation,
            std::optional<HostRectangle> clip) override
        {
            const auto encoded =
                source != nullptr && destination != nullptr &&
                renderer_.encode_copy(*source, *destination, source_rectangle,
                    destination_rectangle, mode, global_alpha, filter, rotation,
                    clip);
            if (encoded)
                performance_counters().record_host_copy();
            return encoded;
        }

        bool fill_quad(const std::shared_ptr<HostSurface>& destination,
            std::span<const HostPoint> positions, HostRectangle scissor,
            std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha) override
        {
            const auto encoded =
                destination != nullptr &&
                renderer_.encode_fill_quad(
                    *destination, positions, scissor, argb, mode, global_alpha);
            if (encoded)
                performance_counters().record_host_fill();
            return encoded;
        }

        bool copy_quad(const std::shared_ptr<HostSurface>& source,
            const std::shared_ptr<HostSurface>& destination,
            std::span<const HostTexturedVertex> vertices,
            HostRectangle source_rectangle, HostRectangle scissor,
            HostCompositeMode mode, std::uint8_t global_alpha,
            HostFilter filter) override
        {
            const auto encoded =
                source != nullptr && destination != nullptr &&
                renderer_.encode_copy_quad(*source, *destination, vertices,
                    source_rectangle, scissor, mode, global_alpha, filter);
            if (encoded)
                performance_counters().record_host_copy();
            return encoded;
        }

        bool fill_triangles(const std::shared_ptr<HostSurface>& destination,
            std::span<const HostPoint> positions, HostRectangle scissor,
            std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha) override
        {
            const auto encoded =
                destination != nullptr &&
                renderer_.encode_fill_triangles(
                    *destination, positions, scissor, argb, mode, global_alpha);
            if (encoded)
                performance_counters().record_host_fill();
            return encoded;
        }

        bool copy_triangles(const std::shared_ptr<HostSurface>& source,
            const std::shared_ptr<HostSurface>& destination,
            std::span<const HostTexturedVertex> vertices, HostRectangle scissor,
            HostCompositeMode mode, std::uint8_t global_alpha,
            HostFilter filter) override
        {
            const auto encoded =
                source != nullptr && destination != nullptr &&
                renderer_.encode_copy_triangles(*source, *destination, vertices,
                    scissor, mode, global_alpha, filter);
            if (encoded)
                performance_counters().record_host_copy();
            return encoded;
        }

        bool submit(PerfSubmitReason reason) override
        {
            // Native presentation serializes the same global command stream and
            // always submits it before releasing renderer_.mutex_. If it
            // already owns that lock, waiting here can pin the only Guest CPU
            // for an entire host-present interval even though presentation will
            // satisfy this non-blocking flush itself.
            if (renderer_.presentation_submissions_pending_.load(
                    std::memory_order_acquire) != 0) {
                return true;
            }
            std::lock_guard lock { renderer_.mutex_ };
            try {
                renderer_.submit_commands(false, reason);
                return true;
            } catch (...) {
                renderer_.last_failure_reason_.store(
                    PerfFallbackReason::BackendFailure,
                    std::memory_order_relaxed);
                static_cast<void>(vkDeviceWaitIdle(renderer_.device_));
                renderer_.discard_commands();
                return false;
            }
        }

        bool finish(PerfSubmitReason reason) override
        {
            std::lock_guard lock { renderer_.mutex_ };
            try {
                renderer_.submit_commands(true, reason);
                return true;
            } catch (...) {
                renderer_.last_failure_reason_.store(
                    PerfFallbackReason::BackendFailure,
                    std::memory_order_relaxed);
                static_cast<void>(vkDeviceWaitIdle(renderer_.device_));
                renderer_.discard_commands();
                return false;
            }
        }

    private:
        VulkanGlesRenderer& renderer_;
    };

    VulkanGlesRenderer::VulkanGlesRenderer(std::filesystem::path pipeline_cache,
        const VulkanPresenterConfiguration* presenter,
        GlesDeviceSelection selection)
        : presenter_ { presenter != nullptr ? *presenter
                                            : VulkanPresenterConfiguration { } }
        , pipeline_cache_path_ { std::move(pipeline_cache) }
    {
        try {
            constexpr std::array<std::uint32_t, 1> white { 0xffffffffU };
            quad_white_surface_ = make_host_surface(quad_white_surface_key,
                HostSurfaceDescriptor { 1U, 1U, sizeof(std::uint32_t), 0U,
                    PerfSurfaceKind::Unknown },
                white);
            auto application = make_vulkan_structure<VkApplicationInfo>(
                VK_STRUCTURE_TYPE_APPLICATION_INFO);
            application.pApplicationName = "Shade";
            application.applicationVersion = VK_MAKE_VERSION(0, 1, 0);
            application.pEngineName = "Shade GLES HLE";
            application.engineVersion = VK_MAKE_VERSION(0, 1, 0);
            application.apiVersion = VK_API_VERSION_1_0;

            auto instance_info = make_vulkan_structure<VkInstanceCreateInfo>(
                VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
            instance_info.pApplicationInfo = &application;
            std::vector<const char*> instance_extensions;
            instance_extensions.reserve(presenter_.instance_extensions.size());
            for (const auto& extension : presenter_.instance_extensions)
                instance_extensions.push_back(extension.c_str());
            instance_info.enabledExtensionCount =
                static_cast<std::uint32_t>(instance_extensions.size());
            instance_info.ppEnabledExtensionNames =
                instance_extensions.empty() ? nullptr
                                            : instance_extensions.data();
            require_success(
                vkCreateInstance(&instance_info, nullptr, &instance_),
                "vkCreateInstance");
            if (presenter_.create_surface) {
                presentation_surface_ =
                    reinterpret_cast<VkSurfaceKHR>(presenter_.create_surface(
                        reinterpret_cast<std::uintptr_t>(instance_)));
            }

            std::uint32_t device_count { };
            require_success(
                vkEnumeratePhysicalDevices(instance_, &device_count, nullptr),
                "vkEnumeratePhysicalDevices");
            if (device_count == 0) {
                throw std::runtime_error {
                    "Vulkan exposes no physical devices"
                };
            }
            std::vector<VkPhysicalDevice> devices(device_count);
            require_success(vkEnumeratePhysicalDevices(
                                instance_, &device_count, devices.data()),
                "vkEnumeratePhysicalDevices");

            const auto device_score = [](VkPhysicalDevice device) {
                VkPhysicalDeviceProperties properties { };
                vkGetPhysicalDeviceProperties(device, &properties);
                switch (properties.deviceType) {
                case VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU: return 300;
                case VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU: return 200;
                case VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU: return 100;
                case VK_PHYSICAL_DEVICE_TYPE_CPU: return 0;
                default: return 50;
                }
            };
            std::stable_sort(devices.begin(), devices.end(),
                [&](VkPhysicalDevice left, VkPhysicalDevice right) {
                    return device_score(left) > device_score(right);
                });
            for (const auto candidate : devices) {
                VkPhysicalDeviceProperties properties { };
                vkGetPhysicalDeviceProperties(candidate, &properties);
                const auto cpu_device =
                    properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_CPU;
                if (selection == GlesDeviceSelection::SoftwareOnly &&
                    !cpu_device) {
                    continue;
                }
                std::uint32_t family_count { };
                vkGetPhysicalDeviceQueueFamilyProperties(
                    candidate, &family_count, nullptr);
                std::vector<VkQueueFamilyProperties> families(family_count);
                vkGetPhysicalDeviceQueueFamilyProperties(
                    candidate, &family_count, families.data());
                for (std::uint32_t family = 0; family < family_count;
                    ++family) {
                    if ((families[family].queueFlags & VK_QUEUE_GRAPHICS_BIT) ==
                        0) {
                        continue;
                    }
                    if (presentation_surface_ != VK_NULL_HANDLE) {
                        VkBool32 present_supported { };
                        if (vkGetPhysicalDeviceSurfaceSupportKHR(candidate,
                                family, presentation_surface_,
                                &present_supported) != VK_SUCCESS ||
                            present_supported == VK_FALSE) {
                            continue;
                        }
                    }
                    physical_device_ = candidate;
                    hardware_accelerated_ = !cpu_device;
                    queue_family_ = family;
                    renderer_name_ = "Shade GLES 1.1 Vulkan (" +
                                     std::string { properties.deviceName } +
                                     ")";
                    break;
                }
                // A compatible higher-priority device is sufficient. Avoid
                // initializing window-system support in unused ICDs.
                if (physical_device_ != VK_NULL_HANDLE)
                    break;
            }
            if (physical_device_ == VK_NULL_HANDLE) {
                throw std::runtime_error {
                    selection == GlesDeviceSelection::SoftwareOnly
                        ? "Vulkan exposes no CPU graphics queue; install a CPU Vulkan ICD"
                        : "Vulkan exposes no compatible graphics/presentation queue"
                };
            }
            VkFormatProperties color_properties { };
            vkGetPhysicalDeviceFormatProperties(
                physical_device_, color_format, &color_properties);
            if ((color_properties.optimalTilingFeatures &
                    VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) != 0) {
                presentation_filter_ = VK_FILTER_LINEAR;
            }
            for (const auto format :
                { VK_FORMAT_S8_UINT, VK_FORMAT_D24_UNORM_S8_UINT,
                    VK_FORMAT_D32_SFLOAT_S8_UINT }) {
                VkFormatProperties properties { };
                vkGetPhysicalDeviceFormatProperties(
                    physical_device_, format, &properties);
                if ((properties.optimalTilingFeatures &
                        VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT) != 0) {
                    stencil_format_ = format;
                    break;
                }
            }
            if (stencil_format_ == VK_FORMAT_UNDEFINED) {
                throw std::runtime_error {
                    "Vulkan exposes no stencil attachment format"
                };
            }

            VkPhysicalDeviceProperties physical_properties { };
            vkGetPhysicalDeviceProperties(
                physical_device_, &physical_properties);
            const auto uniform_alignment = std::max<VkDeviceSize>(
                1, physical_properties.limits.minUniformBufferOffsetAlignment);
            uniform_stride_ =
                (sizeof(GpuFixedFunctionState) + uniform_alignment - 1U) &
                ~(uniform_alignment - 1U);
            vkGetPhysicalDeviceMemoryProperties(
                physical_device_, &memory_properties_);
            VkDeviceSize largest_device_local_heap { };
            for (std::uint32_t heap = 0;
                heap < memory_properties_.memoryHeapCount; ++heap) {
                const auto& properties = memory_properties_.memoryHeaps[heap];
                if ((properties.flags & VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) != 0) {
                    largest_device_local_heap =
                        std::max(largest_device_local_heap, properties.size);
                }
            }
            if (largest_device_local_heap != 0) {
                const auto proportional = std::max<VkDeviceSize>(
                    largest_device_local_heap / 8U, 16U * mebibyte);
                texture_cache_budget_bytes_ = std::max<VkDeviceSize>(
                    1, std::min({ maximum_texture_cache_budget, proportional,
                           largest_device_local_heap / 2U }));
            }
            constexpr float queue_priority = 1.0F;
            auto queue_info = make_vulkan_structure<VkDeviceQueueCreateInfo>(
                VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
            queue_info.queueFamilyIndex = queue_family_;
            queue_info.queueCount = 1;
            queue_info.pQueuePriorities = &queue_priority;
            auto device_info = make_vulkan_structure<VkDeviceCreateInfo>(
                VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
            device_info.queueCreateInfoCount = 1;
            device_info.pQueueCreateInfos = &queue_info;
            constexpr std::array swapchain_extensions {
                VK_KHR_SWAPCHAIN_EXTENSION_NAME
            };
            if (presentation_surface_ != VK_NULL_HANDLE) {
                device_info.enabledExtensionCount =
                    static_cast<std::uint32_t>(swapchain_extensions.size());
                device_info.ppEnabledExtensionNames =
                    swapchain_extensions.data();
            }
            require_success(vkCreateDevice(physical_device_, &device_info,
                                nullptr, &device_),
                "vkCreateDevice");
            VmaAllocatorCreateInfo allocator_info { };
            allocator_info.physicalDevice = physical_device_;
            allocator_info.device = device_;
            allocator_info.instance = instance_;
            allocator_info.vulkanApiVersion = VK_API_VERSION_1_0;
            allocator_info.preferredLargeHeapBlockSize =
                render_target_pool_budget;
            require_success(
                vmaCreateAllocator(&allocator_info, &image_allocator_),
                "vmaCreateAllocator");
            create_color_image_pool();
            vkGetDeviceQueue(device_, queue_family_, 0, &queue_);
            auto host_sampler_info = make_vulkan_structure<VkSamplerCreateInfo>(
                VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO);
            host_sampler_info.magFilter = VK_FILTER_NEAREST;
            host_sampler_info.minFilter = VK_FILTER_NEAREST;
            host_sampler_info.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
            host_sampler_info.addressModeU =
                VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            host_sampler_info.addressModeV =
                VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            host_sampler_info.addressModeW =
                VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            host_sampler_info.maxAnisotropy = 1.0F;
            host_sampler_info.minLod = 0.0F;
            host_sampler_info.maxLod = 0.0F;
            require_success(vkCreateSampler(device_, &host_sampler_info,
                                nullptr, &host_clamp_sampler_),
                "vkCreateSampler(host clamp)");
            if (presentation_surface_ != VK_NULL_HANDLE)
                static_cast<void>(create_presentation_swapchain());

            const auto cache_data = read_pipeline_cache(pipeline_cache_path_);
            auto pipeline_cache_info =
                make_vulkan_structure<VkPipelineCacheCreateInfo>(
                    VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO);
            pipeline_cache_info.initialDataSize = cache_data.size();
            pipeline_cache_info.pInitialData =
                cache_data.empty() ? nullptr : cache_data.data();
            auto cache_result = vkCreatePipelineCache(
                device_, &pipeline_cache_info, nullptr, &pipeline_cache_);
            if (cache_result != VK_SUCCESS && !cache_data.empty()) {
                pipeline_cache_info.initialDataSize = 0;
                pipeline_cache_info.pInitialData = nullptr;
                cache_result = vkCreatePipelineCache(
                    device_, &pipeline_cache_info, nullptr, &pipeline_cache_);
            }
            require_success(cache_result, "vkCreatePipelineCache");

            auto command_pool_info =
                make_vulkan_structure<VkCommandPoolCreateInfo>(
                    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO);
            command_pool_info.flags =
                VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
            command_pool_info.queueFamilyIndex = queue_family_;
            require_success(vkCreateCommandPool(device_, &command_pool_info,
                                nullptr, &command_pool_),
                "vkCreateCommandPool");
            auto command_info =
                make_vulkan_structure<VkCommandBufferAllocateInfo>(
                    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO);
            command_info.commandPool = command_pool_;
            command_info.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            command_info.commandBufferCount =
                static_cast<std::uint32_t>(command_ring_size);
            std::array<VkCommandBuffer, command_ring_size> command_buffers { };
            require_success(vkAllocateCommandBuffers(
                                device_, &command_info, command_buffers.data()),
                "vkAllocateCommandBuffers");
            auto fence_info = make_vulkan_structure<VkFenceCreateInfo>(
                VK_STRUCTURE_TYPE_FENCE_CREATE_INFO);
            auto semaphore_info = make_vulkan_structure<VkSemaphoreCreateInfo>(
                VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO);
            for (std::size_t index = 0; index < command_slots_.size();
                ++index) {
                auto& slot = command_slots_[index];
                slot.command = command_buffers[index];
                require_success(
                    vkCreateFence(device_, &fence_info, nullptr, &slot.fence),
                    "vkCreateFence");
                require_success(vkCreateSemaphore(device_, &semaphore_info,
                                    nullptr, &slot.image_available),
                    "vkCreateSemaphore(image available)");
            }

            VkAttachmentDescription attachment { };
            attachment.format = color_format;
            attachment.samples = VK_SAMPLE_COUNT_1_BIT;
            attachment.loadOp = VK_ATTACHMENT_LOAD_OP_LOAD;
            attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
            attachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
            attachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
            attachment.initialLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            attachment.finalLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            VkAttachmentReference color_reference { 0,
                VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL };
            VkSubpassDescription subpass { };
            subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
            subpass.colorAttachmentCount = 1;
            subpass.pColorAttachments = &color_reference;
            VkSubpassDependency dependency { };
            dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
            dependency.dstSubpass = 0;
            dependency.srcStageMask =
                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            dependency.dstStageMask =
                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            dependency.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                       VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            auto render_pass_info =
                make_vulkan_structure<VkRenderPassCreateInfo>(
                    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
            render_pass_info.attachmentCount = 1U;
            render_pass_info.pAttachments = &attachment;
            render_pass_info.subpassCount = 1;
            render_pass_info.pSubpasses = &subpass;
            render_pass_info.dependencyCount = 1;
            render_pass_info.pDependencies = &dependency;
            require_success(vkCreateRenderPass(device_, &render_pass_info,
                                nullptr, &render_pass_),
                "vkCreateRenderPass");

            std::array<VkAttachmentDescription, 2> stencil_attachments { };
            stencil_attachments[0] = attachment;
            auto& stencil_attachment = stencil_attachments[1];
            stencil_attachment.format = stencil_format_;
            stencil_attachment.samples = VK_SAMPLE_COUNT_1_BIT;
            stencil_attachment.loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
            stencil_attachment.storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
            stencil_attachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
            stencil_attachment.stencilStoreOp =
                VK_ATTACHMENT_STORE_OP_DONT_CARE;
            stencil_attachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
            stencil_attachment.finalLayout =
                VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
            VkAttachmentReference stencil_reference { 1,
                VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL };
            subpass.pDepthStencilAttachment = &stencil_reference;
            dependency.srcStageMask |=
                VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;
            dependency.dstStageMask |=
                VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT |
                VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;
            dependency.srcAccessMask |=
                VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
            dependency.dstAccessMask |=
                VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT |
                VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
            render_pass_info.attachmentCount =
                static_cast<std::uint32_t>(stencil_attachments.size());
            render_pass_info.pAttachments = stencil_attachments.data();
            require_success(vkCreateRenderPass(device_, &render_pass_info,
                                nullptr, &stencil_render_pass_),
                "vkCreateRenderPass(stencil)");

            std::array<VkDescriptorSetLayoutBinding, 1 + gles_abi::texture_unit_count> bindings { };
            bindings[0].binding = 0;
            bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            bindings[0].descriptorCount = 1;
            bindings[0].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
            for (std::uint32_t binding = 1; binding < bindings.size();
                ++binding) {
                bindings[binding].binding = binding;
                bindings[binding].descriptorType =
                    VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
                bindings[binding].descriptorCount = 1;
                bindings[binding].stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
            }
            auto descriptor_layout_info =
                make_vulkan_structure<VkDescriptorSetLayoutCreateInfo>(
                    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO);
            descriptor_layout_info.bindingCount =
                static_cast<std::uint32_t>(bindings.size());
            descriptor_layout_info.pBindings = bindings.data();
            require_success(
                vkCreateDescriptorSetLayout(device_, &descriptor_layout_info,
                    nullptr, &descriptor_layout_),
                "vkCreateDescriptorSetLayout");
            auto pipeline_layout_info =
                make_vulkan_structure<VkPipelineLayoutCreateInfo>(
                    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO);
            pipeline_layout_info.setLayoutCount = 1;
            pipeline_layout_info.pSetLayouts = &descriptor_layout_;
            require_success(
                vkCreatePipelineLayout(
                    device_, &pipeline_layout_info, nullptr, &pipeline_layout_),
                "vkCreatePipelineLayout");

            std::array<VkDescriptorPoolSize, 2> pool_sizes { };
            pool_sizes[0] = { VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                static_cast<std::uint32_t>(
                    maximum_batch_draws * command_ring_size) };
            pool_sizes[1] = { VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                static_cast<std::uint32_t>(maximum_batch_draws *
                                           command_ring_size *
                                           gles_abi::texture_unit_count) };
            auto descriptor_pool_info =
                make_vulkan_structure<VkDescriptorPoolCreateInfo>(
                    VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO);
            descriptor_pool_info.maxSets = static_cast<std::uint32_t>(
                maximum_batch_draws * command_ring_size);
            descriptor_pool_info.poolSizeCount =
                static_cast<std::uint32_t>(pool_sizes.size());
            descriptor_pool_info.pPoolSizes = pool_sizes.data();
            require_success(
                vkCreateDescriptorPool(
                    device_, &descriptor_pool_info, nullptr, &descriptor_pool_),
                "vkCreateDescriptorPool");
            auto descriptor_info =
                make_vulkan_structure<VkDescriptorSetAllocateInfo>(
                    VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO);
            descriptor_info.descriptorPool = descriptor_pool_;
            std::array<VkDescriptorSetLayout,
                maximum_batch_draws * command_ring_size>
                layouts;
            layouts.fill(descriptor_layout_);
            descriptor_info.descriptorSetCount =
                static_cast<std::uint32_t>(layouts.size());
            descriptor_info.pSetLayouts = layouts.data();
            std::array<VkDescriptorSet, maximum_batch_draws * command_ring_size>
                descriptors { };
            require_success(vkAllocateDescriptorSets(
                                device_, &descriptor_info, descriptors.data()),
                "vkAllocateDescriptorSets");
            for (std::size_t index = 0; index < command_slots_.size();
                ++index) {
                std::copy_n(
                    descriptors.begin() + static_cast<std::ptrdiff_t>(
                                              index * maximum_batch_draws),
                    maximum_batch_draws,
                    command_slots_[index].descriptors.begin());
            }

            vertex_shader_ = create_shader_module(vertex_shader_code);
            fragment_shader_ = create_shader_module(fragment_shader_code);
        } catch (...) {
            destroy();
            throw;
        }
    }

    VulkanGlesRenderer::~VulkanGlesRenderer() { destroy(); }

    bool VulkanGlesRenderer::create_presentation_swapchain()
    {
        if (device_ == VK_NULL_HANDLE ||
            presentation_surface_ == VK_NULL_HANDLE) {
            return false;
        }
        VkSurfaceCapabilitiesKHR capabilities { };
        if (vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device_,
                presentation_surface_, &capabilities) != VK_SUCCESS ||
            (capabilities.supportedUsageFlags &
                VK_IMAGE_USAGE_TRANSFER_DST_BIT) == 0) {
            return false;
        }
        std::uint32_t format_count { };
        if (vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device_,
                presentation_surface_, &format_count, nullptr) != VK_SUCCESS ||
            format_count == 0) {
            return false;
        }
        std::vector<VkSurfaceFormatKHR> formats(format_count);
        if (vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device_,
                presentation_surface_, &format_count,
                formats.data()) != VK_SUCCESS) {
            return false;
        }
        auto selected = formats.front();
        if (const auto preferred = std::find_if(formats.begin(), formats.end(),
                [](const auto& format) {
                    return format.format == color_format &&
                           format.colorSpace ==
                               VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
                });
            preferred != formats.end()) {
            selected = *preferred;
        }

        VkExtent2D extent = capabilities.currentExtent;
        if (extent.width == std::numeric_limits<std::uint32_t>::max()) {
            const auto requested =
                presenter_.drawable_size
                    ? presenter_.drawable_size()
                    : std::pair<std::uint32_t, std::uint32_t> { 1, 1 };
            extent.width = std::clamp(std::max(1U, requested.first),
                capabilities.minImageExtent.width,
                capabilities.maxImageExtent.width);
            extent.height = std::clamp(std::max(1U, requested.second),
                capabilities.minImageExtent.height,
                capabilities.maxImageExtent.height);
        }
        auto image_count = capabilities.minImageCount + 1U;
        if (capabilities.maxImageCount != 0)
            image_count = std::min(image_count, capabilities.maxImageCount);
        VkCompositeAlphaFlagBitsKHR composite_alpha =
            VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        constexpr std::array composite_candidates {
            VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR,
            VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR,
            VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR
        };
        for (const auto candidate : composite_candidates) {
            if ((capabilities.supportedCompositeAlpha & candidate) != 0) {
                composite_alpha = candidate;
                break;
            }
        }

        auto info = make_vulkan_structure<VkSwapchainCreateInfoKHR>(
            VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
        info.surface = presentation_surface_;
        info.minImageCount = image_count;
        info.imageFormat = selected.format;
        info.imageColorSpace = selected.colorSpace;
        info.imageExtent = extent;
        info.imageArrayLayers = 1;
        info.imageUsage = VK_IMAGE_USAGE_TRANSFER_DST_BIT;
        info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        info.preTransform = capabilities.currentTransform;
        info.compositeAlpha = composite_alpha;
        // FIFO preserves every queued image until its display turn. MAILBOX may
        // replace an older queued image with a newer one, which violates the
        // emulator's no-dropped-animation-frame presentation contract.
        info.presentMode = VK_PRESENT_MODE_FIFO_KHR;
        info.clipped = VK_TRUE;
        info.oldSwapchain = presentation_swapchain_;
        VkSwapchainKHR swapchain { };
        if (vkCreateSwapchainKHR(device_, &info, nullptr, &swapchain) !=
            VK_SUCCESS) {
            return false;
        }
        std::uint32_t swapchain_image_count { };
        if (vkGetSwapchainImagesKHR(device_, swapchain, &swapchain_image_count,
                nullptr) != VK_SUCCESS ||
            swapchain_image_count == 0) {
            vkDestroySwapchainKHR(device_, swapchain, nullptr);
            return false;
        }
        std::vector<VkImage> images(swapchain_image_count);
        if (vkGetSwapchainImagesKHR(device_, swapchain, &swapchain_image_count,
                images.data()) != VK_SUCCESS) {
            vkDestroySwapchainKHR(device_, swapchain, nullptr);
            return false;
        }
        images.resize(swapchain_image_count);
        std::vector<VkSemaphore> render_finished(swapchain_image_count);
        auto semaphore_info = make_vulkan_structure<VkSemaphoreCreateInfo>(
            VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO);
        for (auto& semaphore : render_finished) {
            if (vkCreateSemaphore(device_, &semaphore_info, nullptr,
                    &semaphore) != VK_SUCCESS) {
                for (const auto created : render_finished) {
                    if (created != VK_NULL_HANDLE)
                        vkDestroySemaphore(device_, created, nullptr);
                }
                vkDestroySwapchainKHR(device_, swapchain, nullptr);
                return false;
            }
        }
        destroy_presentation_swapchain();
        presentation_swapchain_ = swapchain;
        presentation_format_ = selected.format;
        presentation_extent_ = extent;
        presentation_images_ = std::move(images);
        presentation_render_finished_ = std::move(render_finished);
        presentation_layouts_.assign(
            swapchain_image_count, VK_IMAGE_LAYOUT_UNDEFINED);
        if (renderer_name_.find("present-mode=") == std::string::npos) {
            renderer_name_ += "; present-mode=fifo";
        }
        return true;
    }

    bool VulkanGlesRenderer::recreate_presentation_surface()
    {
        if (!presenter_.create_surface || instance_ == VK_NULL_HANDLE ||
            device_ == VK_NULL_HANDLE) {
            return false;
        }
        require_success(vkDeviceWaitIdle(device_), "vkDeviceWaitIdle");
        destroy_presentation_swapchain();
        if (presentation_surface_ != VK_NULL_HANDLE) {
            vkDestroySurfaceKHR(instance_, presentation_surface_, nullptr);
            presentation_surface_ = VK_NULL_HANDLE;
        }
        presentation_surface_ =
            reinterpret_cast<VkSurfaceKHR>(presenter_.create_surface(
                reinterpret_cast<std::uintptr_t>(instance_)));
        return presentation_surface_ != VK_NULL_HANDLE &&
               create_presentation_swapchain();
    }

    void VulkanGlesRenderer::destroy_presentation_swapchain() noexcept
    {
        if (device_ != VK_NULL_HANDLE) {
            for (const auto semaphore : presentation_render_finished_) {
                if (semaphore != VK_NULL_HANDLE)
                    vkDestroySemaphore(device_, semaphore, nullptr);
            }
        }
        presentation_render_finished_.clear();
        presentation_images_.clear();
        presentation_layouts_.clear();
        presentation_extent_ = { };
        presentation_format_ = VK_FORMAT_UNDEFINED;
        if (device_ != VK_NULL_HANDLE &&
            presentation_swapchain_ != VK_NULL_HANDLE) {
            vkDestroySwapchainKHR(device_, presentation_swapchain_, nullptr);
        }
        presentation_swapchain_ = VK_NULL_HANDLE;
    }

    void VulkanGlesRenderer::destroy() noexcept
    {
        if (device_ != VK_NULL_HANDLE) {
            vkDeviceWaitIdle(device_);
            destroy_presentation_swapchain();
            if (pipeline_cache_ != VK_NULL_HANDLE &&
                !pipeline_cache_path_.empty()) {
                std::size_t cache_size { };
                if (vkGetPipelineCacheData(device_, pipeline_cache_,
                        &cache_size, nullptr) == VK_SUCCESS &&
                    cache_size != 0 &&
                    cache_size <= maximum_pipeline_cache_bytes) {
                    std::vector<std::byte> cache_data(cache_size);
                    if (vkGetPipelineCacheData(device_, pipeline_cache_,
                            &cache_size, cache_data.data()) == VK_SUCCESS) {
                        cache_data.resize(cache_size);
                        write_pipeline_cache(pipeline_cache_path_, cache_data);
                    }
                }
            }
            for (auto& [key, target] : targets_) {
                static_cast<void>(key);
                destroy_target_framebuffers(target);
            }
            targets_.clear();
            for (auto& [dimensions, pooled] : target_pool_) {
                static_cast<void>(dimensions);
                destroy_target_framebuffers(pooled.target);
            }
            target_pool_.clear();
            target_pool_bytes_ = 0;
            texture_cache_.clear();
            texture_cache_bytes_ = 0;
            if (color_image_pool_ != nullptr) {
                vmaDestroyPool(image_allocator_, color_image_pool_);
                color_image_pool_ = nullptr;
            }
            if (image_allocator_ != nullptr) {
                vmaDestroyAllocator(image_allocator_);
                image_allocator_ = nullptr;
            }
            for (auto& slot : command_slots_) {
                slot.staging = { };
                slot.vertex = { };
                slot.uniform = { };
                slot.in_flight = false;
            }
            render_pass_target_.reset();
            for (const auto& [key, value] : pipelines_) {
                static_cast<void>(key);
                vkDestroyPipeline(device_, value, nullptr);
            }
            pipelines_.clear();
            for (const auto& [state, sampler] : texture_samplers_) {
                static_cast<void>(state);
                vkDestroySampler(device_, sampler, nullptr);
            }
            texture_samplers_.clear();
            if (fragment_shader_ != VK_NULL_HANDLE) {
                vkDestroyShaderModule(device_, fragment_shader_, nullptr);
            }
            if (vertex_shader_ != VK_NULL_HANDLE) {
                vkDestroyShaderModule(device_, vertex_shader_, nullptr);
            }
            if (descriptor_pool_ != VK_NULL_HANDLE) {
                vkDestroyDescriptorPool(device_, descriptor_pool_, nullptr);
            }
            if (host_clamp_sampler_ != VK_NULL_HANDLE) {
                vkDestroySampler(device_, host_clamp_sampler_, nullptr);
                host_clamp_sampler_ = VK_NULL_HANDLE;
            }
            if (pipeline_layout_ != VK_NULL_HANDLE) {
                vkDestroyPipelineLayout(device_, pipeline_layout_, nullptr);
            }
            if (descriptor_layout_ != VK_NULL_HANDLE) {
                vkDestroyDescriptorSetLayout(
                    device_, descriptor_layout_, nullptr);
            }
            if (render_pass_ != VK_NULL_HANDLE) {
                vkDestroyRenderPass(device_, render_pass_, nullptr);
            }
            if (stencil_render_pass_ != VK_NULL_HANDLE) {
                vkDestroyRenderPass(device_, stencil_render_pass_, nullptr);
            }
            if (pipeline_cache_ != VK_NULL_HANDLE) {
                vkDestroyPipelineCache(device_, pipeline_cache_, nullptr);
                pipeline_cache_ = VK_NULL_HANDLE;
            }
            for (auto& slot : command_slots_) {
                if (slot.image_available != VK_NULL_HANDLE) {
                    vkDestroySemaphore(device_, slot.image_available, nullptr);
                    slot.image_available = VK_NULL_HANDLE;
                }
                if (slot.fence != VK_NULL_HANDLE) {
                    vkDestroyFence(device_, slot.fence, nullptr);
                    slot.fence = VK_NULL_HANDLE;
                }
            }
            if (command_pool_ != VK_NULL_HANDLE) {
                vkDestroyCommandPool(device_, command_pool_, nullptr);
            }
            vkDestroyDevice(device_, nullptr);
        }
        if (instance_ != VK_NULL_HANDLE) {
            if (presentation_surface_ != VK_NULL_HANDLE) {
                vkDestroySurfaceKHR(instance_, presentation_surface_, nullptr);
                presentation_surface_ = VK_NULL_HANDLE;
            }
            vkDestroyInstance(instance_, nullptr);
        }
        device_ = VK_NULL_HANDLE;
        instance_ = VK_NULL_HANDLE;
    }

    std::uint32_t VulkanGlesRenderer::find_memory_type(std::uint32_t candidates,
        VkMemoryPropertyFlags required, VkMemoryPropertyFlags preferred) const
    {
        std::optional<std::uint32_t> fallback;
        for (std::uint32_t index = 0;
            index < memory_properties_.memoryTypeCount; ++index) {
            if ((candidates & (1U << index)) == 0)
                continue;
            const auto flags =
                memory_properties_.memoryTypes[index].propertyFlags;
            if ((flags & required) != required)
                continue;
            if ((flags & preferred) == preferred)
                return index;
            if (!fallback)
                fallback = index;
        }
        if (fallback)
            return *fallback;
        throw std::runtime_error { "Vulkan has no compatible memory type" };
    }

    VulkanGlesRenderer::Buffer VulkanGlesRenderer::create_buffer(
        VkDeviceSize size, VkBufferUsageFlags usage,
        VkMemoryPropertyFlags required, VkMemoryPropertyFlags preferred) const
    {
        Buffer result;
        result.device = device_;
        result.size = size;
        auto buffer_info = make_vulkan_structure<VkBufferCreateInfo>(
            VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO);
        buffer_info.size = size;
        buffer_info.usage = usage;
        buffer_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        require_success(
            vkCreateBuffer(device_, &buffer_info, nullptr, &result.buffer),
            "vkCreateBuffer");
        VkMemoryRequirements requirements { };
        vkGetBufferMemoryRequirements(device_, result.buffer, &requirements);
        const auto memory_type =
            find_memory_type(requirements.memoryTypeBits, required, preferred);
        result.coherent =
            (memory_properties_.memoryTypes[memory_type].propertyFlags &
                VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) != 0;
        auto allocation = make_vulkan_structure<VkMemoryAllocateInfo>(
            VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO);
        allocation.allocationSize = requirements.size;
        allocation.memoryTypeIndex = memory_type;
        require_success(
            vkAllocateMemory(device_, &allocation, nullptr, &result.memory),
            "vkAllocateMemory(buffer)");
        require_success(
            vkBindBufferMemory(device_, result.buffer, result.memory, 0),
            "vkBindBufferMemory");
        require_success(vkMapMemory(device_, result.memory, 0, VK_WHOLE_SIZE, 0,
                            &result.mapped),
            "vkMapMemory(buffer)");
        return result;
    }

    void VulkanGlesRenderer::create_color_image_pool()
    {
        auto image_info = make_vulkan_structure<VkImageCreateInfo>(
            VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO);
        image_info.imageType = VK_IMAGE_TYPE_2D;
        image_info.format = color_format;
        image_info.extent = { 1U, 1U, 1U };
        image_info.mipLevels = 1U;
        image_info.arrayLayers = 1U;
        image_info.samples = VK_SAMPLE_COUNT_1_BIT;
        image_info.tiling = VK_IMAGE_TILING_OPTIMAL;
        image_info.usage =
            VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
            VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
        image_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        image_info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

        VmaAllocationCreateInfo allocation_info { };
        allocation_info.usage = VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE;
        allocation_info.requiredFlags = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        std::uint32_t memory_type { };
        if (vmaFindMemoryTypeIndexForImageInfo(image_allocator_, &image_info,
                &allocation_info, &memory_type) != VK_SUCCESS) {
            return;
        }

        VmaPoolCreateInfo pool_info { };
        pool_info.memoryTypeIndex = memory_type;
        pool_info.blockSize = render_target_pool_budget;
        pool_info.minBlockCount = 1U;
        static_cast<void>(
            vmaCreatePool(image_allocator_, &pool_info, &color_image_pool_));
    }

    VulkanGlesRenderer::Image VulkanGlesRenderer::create_image(
        std::uint32_t width, std::uint32_t height, VkImageUsageFlags usage,
        bool sampled, bool rectangle, VkFormat format,
        VkImageAspectFlags aspect) const
    {
        Image result;
        result.allocator = image_allocator_;
        result.device = device_;
        result.width = width;
        result.height = height;
        result.rectangle = rectangle;
        auto image_info = make_vulkan_structure<VkImageCreateInfo>(
            VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO);
        image_info.imageType = VK_IMAGE_TYPE_2D;
        image_info.format = format;
        image_info.extent = { width, height, 1 };
        image_info.mipLevels = 1;
        image_info.arrayLayers = 1;
        image_info.samples = VK_SAMPLE_COUNT_1_BIT;
        image_info.tiling = VK_IMAGE_TILING_OPTIMAL;
        image_info.usage = usage;
        image_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        image_info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        VmaAllocationCreateInfo allocation_info { };
        allocation_info.usage = VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE;
        allocation_info.requiredFlags = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
        if (format == color_format)
            allocation_info.pool = color_image_pool_;
        VmaAllocationInfo allocated { };
        require_success(
            vmaCreateImage(image_allocator_, &image_info, &allocation_info,
                &result.image, &result.allocation, &allocated),
            "vmaCreateImage");
        result.allocation_size = allocated.size;

        auto view_info = make_vulkan_structure<VkImageViewCreateInfo>(
            VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
        view_info.image = result.image;
        view_info.viewType = VK_IMAGE_VIEW_TYPE_2D;
        view_info.format = format;
        view_info.components = { VK_COMPONENT_SWIZZLE_IDENTITY,
            VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY,
            VK_COMPONENT_SWIZZLE_IDENTITY };
        view_info.subresourceRange.aspectMask = aspect;
        view_info.subresourceRange.levelCount = 1;
        view_info.subresourceRange.layerCount = 1;
        require_success(
            vkCreateImageView(device_, &view_info, nullptr, &result.view),
            "vkCreateImageView");

        if (sampled) {
            auto sampler_info = make_vulkan_structure<VkSamplerCreateInfo>(
                VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO);
            sampler_info.magFilter = VK_FILTER_NEAREST;
            sampler_info.minFilter = VK_FILTER_NEAREST;
            sampler_info.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
            sampler_info.addressModeU =
                rectangle ? VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
                          : VK_SAMPLER_ADDRESS_MODE_REPEAT;
            sampler_info.addressModeV = sampler_info.addressModeU;
            sampler_info.addressModeW = sampler_info.addressModeU;
            sampler_info.maxAnisotropy = 1.0F;
            sampler_info.minLod = 0.0F;
            sampler_info.maxLod = 0.0F;
            require_success(vkCreateSampler(device_, &sampler_info, nullptr,
                                &result.sampler),
                "vkCreateSampler");
        }
        return result;
    }

    VkSampler VulkanGlesRenderer::texture_sampler(const GlesSamplerState& state)
    {
        if (const auto found = texture_samplers_.find(state);
            found != texture_samplers_.end())
            return found->second;
        const auto wrap = [](std::uint32_t mode) {
            if (mode == gles_abi::clamp_to_edge)
                return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
            if (mode == gles_abi::mirrored_repeat)
                return VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT;
            return VK_SAMPLER_ADDRESS_MODE_REPEAT;
        };
        auto info = make_vulkan_structure<VkSamplerCreateInfo>(
            VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO);
        info.minFilter = GlesSamplerState::linear_filter(state.min_filter)
                             ? VK_FILTER_LINEAR
                             : VK_FILTER_NEAREST;
        info.magFilter = GlesSamplerState::linear_filter(state.mag_filter)
                             ? VK_FILTER_LINEAR
                             : VK_FILTER_NEAREST;
        info.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
        info.addressModeU = wrap(state.wrap_s);
        info.addressModeV = wrap(state.wrap_t);
        info.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        info.maxAnisotropy = 1.0F;
        // The resource upload path currently publishes level zero only.
        info.maxLod = 0.0F;
        VkSampler sampler { };
        require_success(vkCreateSampler(device_, &info, nullptr, &sampler),
            "vkCreateSampler(texture)");
        texture_samplers_.emplace(state, sampler);
        return sampler;
    }

    void VulkanGlesRenderer::ensure_buffer(
        Buffer& buffer, VkDeviceSize size, VkBufferUsageFlags usage) const
    {
        if (buffer.buffer != VK_NULL_HANDLE && buffer.size >= size)
            return;
        const auto capacity = std::bit_ceil(std::max<VkDeviceSize>(size, 4096));
        buffer =
            create_buffer(capacity, usage, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
                VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    }

    VulkanGlesRenderer::Target& VulkanGlesRenderer::ensure_target(
        GlesRenderTargetKey key, std::uint32_t width, std::uint32_t height)
    {
        auto found = targets_.find(key);
        if (found != targets_.end() &&
            found->second.image.image != VK_NULL_HANDLE &&
            found->second.image.width == width &&
            found->second.image.height == height) {
            return found->second;
        }
        // Recorded draws may still reference the old image and framebuffer.
        // Submission includes a fence wait, so only retire them after the
        // command buffer can no longer access either object.
        if (found != targets_.end() &&
            found->second.image.image != VK_NULL_HANDLE) {
            if (command_recording_)
                submit_commands(false, PerfSubmitReason::ResourceLifetime);
            wait_for_all_slots();
            auto retired = std::move(found->second);
            targets_.erase(found);
            pool_target(std::move(retired));
        } else if (found != targets_.end()) {
            targets_.erase(found);
        }

        if (auto pooled = take_pooled_target(width, height)) {
            pooled->cpu_generation = 0;
            pooled->kind = PerfSurfaceKind::GlesRenderTarget;
            pooled->valid = false;
            pooled->dirty.reset();
            const auto [reused, inserted] =
                targets_.emplace(key, std::move(*pooled));
            static_cast<void>(inserted);
            return reused->second;
        }

        Target target;
        target.image = create_image(width, height,
            VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                VK_IMAGE_USAGE_SAMPLED_BIT,
            true, false);
        auto framebuffer_info = make_vulkan_structure<VkFramebufferCreateInfo>(
            VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO);
        framebuffer_info.renderPass = render_pass_;
        framebuffer_info.attachmentCount = 1U;
        framebuffer_info.pAttachments = &target.image.view;
        framebuffer_info.width = width;
        framebuffer_info.height = height;
        framebuffer_info.layers = 1;
        require_success(vkCreateFramebuffer(device_, &framebuffer_info, nullptr,
                            &target.framebuffer),
            "vkCreateFramebuffer");
        target.valid = false;
        target.dirty.reset();
        target.cpu_generation = 0;
        target.layout = VK_IMAGE_LAYOUT_UNDEFINED;
        auto [created, inserted] = targets_.emplace(key, std::move(target));
        static_cast<void>(inserted);
        return created->second;
    }

    std::optional<VulkanGlesRenderer::Target>
    VulkanGlesRenderer::take_pooled_target(
        std::uint32_t width, std::uint32_t height)
    {
        const auto range = target_pool_.equal_range({ width, height });
        if (range.first == range.second)
            return std::nullopt;
        auto selected = range.first;
        for (auto candidate = std::next(range.first); candidate != range.second;
            ++candidate) {
            if (candidate->second.last_used > selected->second.last_used)
                selected = candidate;
        }
        Target result = std::move(selected->second.target);
        target_pool_bytes_ -=
            std::min(target_pool_bytes_, selected->second.allocation_size);
        target_pool_.erase(selected);
        return result;
    }

    void VulkanGlesRenderer::pool_target(Target&& target)
    {
        if (target.image.image == VK_NULL_HANDLE)
            return;
        target.cpu_generation = 0;
        target.valid = false;
        target.dirty.reset();
        const auto allocation_size = target_allocation_size(target);
        if (allocation_size > render_target_pool_budget) {
            destroy_target_framebuffers(target);
            return;
        }
        const auto dimensions =
            std::pair { target.image.width, target.image.height };
        target_pool_bytes_ += allocation_size;
        target_pool_.emplace(
            dimensions, PooledTarget { std::move(target), allocation_size,
                            ++target_pool_use_sequence_ });
        trim_target_pool();
    }

    void VulkanGlesRenderer::trim_target_pool()
    {
        while (target_pool_bytes_ > render_target_pool_budget ||
               target_pool_.size() > maximum_render_target_pool_entries) {
            const auto oldest = std::ranges::min_element(target_pool_, { },
                [](const auto& entry) { return entry.second.last_used; });
            if (oldest == target_pool_.end())
                break;
            target_pool_bytes_ -=
                std::min(target_pool_bytes_, oldest->second.allocation_size);
            destroy_target_framebuffers(oldest->second.target);
            target_pool_.erase(oldest);
        }
    }

    void VulkanGlesRenderer::destroy_target_framebuffers(
        Target& target) noexcept
    {
        if (target.framebuffer != VK_NULL_HANDLE) {
            vkDestroyFramebuffer(device_, target.framebuffer, nullptr);
            target.framebuffer = VK_NULL_HANDLE;
        }
        if (target.stencil_framebuffer != VK_NULL_HANDLE) {
            vkDestroyFramebuffer(device_, target.stencil_framebuffer, nullptr);
            target.stencil_framebuffer = VK_NULL_HANDLE;
        }
    }

    VkDeviceSize VulkanGlesRenderer::target_allocation_size(
        const Target& target)
    {
        constexpr auto maximum = std::numeric_limits<VkDeviceSize>::max();
        if (target.image.allocation_size >
            maximum - target.stencil.allocation_size) {
            return maximum;
        }
        const auto images =
            target.image.allocation_size + target.stencil.allocation_size;
        return images > maximum - target.download.size
                   ? maximum
                   : images + target.download.size;
    }

    std::uint64_t VulkanGlesRenderer::resource_bytes() const noexcept
    {
        std::lock_guard lock { mutex_ };
        std::uint64_t total { };
        const auto add = [&total](VkDeviceSize bytes) {
            const auto value = static_cast<std::uint64_t>(bytes);
            total = value > std::numeric_limits<std::uint64_t>::max() - total
                        ? std::numeric_limits<std::uint64_t>::max()
                        : total + value;
        };
        add(texture_cache_bytes_);
        add(target_pool_bytes_);
        for (const auto& [key, target] : targets_) {
            static_cast<void>(key);
            add(target_allocation_size(target));
        }
        for (const auto& slot : command_slots_) {
            add(slot.staging.size);
            add(slot.vertex.size);
            add(slot.uniform.size);
        }
        return total;
    }

    void VulkanGlesRenderer::ensure_stencil_framebuffer(Target& target)
    {
        if (target.stencil_framebuffer != VK_NULL_HANDLE)
            return;
        target.stencil = create_image(target.image.width, target.image.height,
            VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, false, false,
            stencil_format_, stencil_aspect(stencil_format_));
        const std::array attachments { target.image.view, target.stencil.view };
        auto framebuffer_info = make_vulkan_structure<VkFramebufferCreateInfo>(
            VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO);
        framebuffer_info.renderPass = stencil_render_pass_;
        framebuffer_info.attachmentCount =
            static_cast<std::uint32_t>(attachments.size());
        framebuffer_info.pAttachments = attachments.data();
        framebuffer_info.width = target.image.width;
        framebuffer_info.height = target.image.height;
        framebuffer_info.layers = 1U;
        require_success(vkCreateFramebuffer(device_, &framebuffer_info, nullptr,
                            &target.stencil_framebuffer),
            "vkCreateFramebuffer(stencil)");
    }

    void VulkanGlesRenderer::upload(Buffer& buffer, const void* data,
        std::size_t size, VkDeviceSize offset, PerfSurfaceKind surface) const
    {
        if (offset > buffer.size || size > buffer.size - offset) {
            throw std::runtime_error {
                "Vulkan buffer upload exceeds allocation"
            };
        }
        std::memcpy(
            static_cast<std::byte*>(buffer.mapped) + offset, data, size);
        performance_counters().record_upload(size, surface);
        if (!buffer.coherent) {
            auto range = make_vulkan_structure<VkMappedMemoryRange>(
                VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE);
            range.memory = buffer.memory;
            range.offset = 0;
            range.size = VK_WHOLE_SIZE;
            require_success(vkFlushMappedMemoryRanges(device_, 1, &range),
                "vkFlushMappedMemoryRanges");
        }
    }

    void VulkanGlesRenderer::download(Buffer& buffer, void* destination,
        std::size_t size, PerfSurfaceKind surface) const
    {
        if (size > buffer.size) {
            throw std::runtime_error {
                "Vulkan buffer download exceeds allocation"
            };
        }
        if (!buffer.coherent) {
            auto range = make_vulkan_structure<VkMappedMemoryRange>(
                VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE);
            range.memory = buffer.memory;
            range.offset = 0;
            range.size = VK_WHOLE_SIZE;
            require_success(vkInvalidateMappedMemoryRanges(device_, 1, &range),
                "vkInvalidateMappedMemoryRanges");
        }
        std::memcpy(destination, buffer.mapped, size);
        performance_counters().record_readback(size, surface);
    }

    void VulkanGlesRenderer::begin_commands()
    {
        if (command_recording_)
            return;
        auto& slot = command_slot();
        wait_for_slot(slot);
        require_success(
            vkResetCommandBuffer(slot.command, 0), "vkResetCommandBuffer");
        auto begin = make_vulkan_structure<VkCommandBufferBeginInfo>(
            VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO);
        begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        require_success(
            vkBeginCommandBuffer(slot.command, &begin), "vkBeginCommandBuffer");
        command_recording_ = true;
        render_pass_open_ = false;
    }

    void VulkanGlesRenderer::wait_for_slot(CommandSlot& slot)
    {
        if (!slot.in_flight)
            return;
        const auto measure_wait = performance_counters().enabled();
        const auto wait_start = measure_wait
                                    ? std::chrono::steady_clock::now()
                                    : std::chrono::steady_clock::time_point { };
        const auto wait_result = vkWaitForFences(
            device_, 1, &slot.fence, VK_TRUE, fence_timeout_nanoseconds);
        if (measure_wait) {
            const auto elapsed = std::chrono::steady_clock::now() - wait_start;
            performance_counters().record_fence_wait(static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed)
                    .count()));
        }
        require_success(wait_result, "vkWaitForFences");
        slot.in_flight = false;
    }

    void VulkanGlesRenderer::wait_for_all_slots()
    {
        for (auto& slot : command_slots_)
            wait_for_slot(slot);
    }

    void VulkanGlesRenderer::end_render_pass()
    {
        if (!render_pass_open_)
            return;
        vkCmdEndRenderPass(command_slot().command);
        render_pass_open_ = false;
        render_pass_target_.reset();
    }

    void VulkanGlesRenderer::submit_commands(bool wait, PerfSubmitReason reason,
        VkSemaphore wait_semaphore, VkPipelineStageFlags wait_stage,
        VkSemaphore signal_semaphore)
    {
        if (!command_recording_) {
            if (wait)
                wait_for_all_slots();
            return;
        }
        auto& submitted = command_slot();
        end_render_pass();
        require_success(
            vkEndCommandBuffer(submitted.command), "vkEndCommandBuffer");
        command_recording_ = false;
        require_success(
            vkResetFences(device_, 1, &submitted.fence), "vkResetFences");
        auto submit =
            make_vulkan_structure<VkSubmitInfo>(VK_STRUCTURE_TYPE_SUBMIT_INFO);
        if (wait_semaphore != VK_NULL_HANDLE) {
            submit.waitSemaphoreCount = 1;
            submit.pWaitSemaphores = &wait_semaphore;
            submit.pWaitDstStageMask = &wait_stage;
        }
        submit.commandBufferCount = 1;
        submit.pCommandBuffers = &submitted.command;
        if (signal_semaphore != VK_NULL_HANDLE) {
            submit.signalSemaphoreCount = 1;
            submit.pSignalSemaphores = &signal_semaphore;
        }
        require_success(vkQueueSubmit(queue_, 1, &submit, submitted.fence),
            "vkQueueSubmit");
        submitted.in_flight = true;
        performance_counters().record_submit(reason);
        submitted.draw_count = 0;
        submitted.staging_bytes_used = 0;
        submitted.vertex_bytes_used = 0;
        if (++batch_sequence_ == 0)
            batch_sequence_ = 1;
        command_slot_index_ =
            (command_slot_index_ + 1U) % command_slots_.size();
        if (wait)
            wait_for_slot(submitted);
    }

    void VulkanGlesRenderer::discard_commands() noexcept
    {
        for (auto& slot : command_slots_) {
            if (slot.in_flight) {
                static_cast<void>(vkWaitForFences(device_, 1, &slot.fence,
                    VK_TRUE, fence_timeout_nanoseconds));
                slot.in_flight = false;
            }
        }
        for (auto& [key, texture] : texture_cache_) {
            static_cast<void>(key);
            if (texture.last_upload_batch == batch_sequence_)
                texture.revision = 0;
        }
        if (command_recording_) {
            static_cast<void>(vkResetCommandBuffer(command_slot().command, 0));
            command_recording_ = false;
        }
        render_pass_open_ = false;
        render_pass_target_.reset();
        for (auto& slot : command_slots_) {
            slot.draw_count = 0;
            slot.staging_bytes_used = 0;
            slot.vertex_bytes_used = 0;
        }
        if (++batch_sequence_ == 0)
            batch_sequence_ = 1;
    }

    VkShaderModule VulkanGlesRenderer::create_shader_module(
        std::span<const std::uint32_t> code) const
    {
        auto info = make_vulkan_structure<VkShaderModuleCreateInfo>(
            VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
        info.codeSize = code.size_bytes();
        info.pCode = code.data();
        VkShaderModule module { };
        require_success(vkCreateShaderModule(device_, &info, nullptr, &module),
            "vkCreateShaderModule");
        return module;
    }

    std::optional<VkBlendFactor> VulkanGlesRenderer::blend_factor(
        std::uint32_t factor) const
    {
        switch (factor) {
        case gles_abi::zero:
            return VK_BLEND_FACTOR_ZERO;
        case gles_abi::one:
            return VK_BLEND_FACTOR_ONE;
        case gles_abi::source_alpha:
            return VK_BLEND_FACTOR_SRC_ALPHA;
        case gles_abi::one_minus_source_alpha:
            return VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        case constant_alpha_blend_factor:
            return VK_BLEND_FACTOR_CONSTANT_ALPHA;
        case one_minus_constant_alpha_blend_factor:
            return VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA;
        default:
            return std::nullopt;
        }
    }

    VkPipeline VulkanGlesRenderer::pipeline(const PipelineKey& key)
    {
        if (const auto found = pipelines_.find(key);
            found != pipelines_.end()) {
            return found->second;
        }
        const auto source = blend_factor(key.blend_source);
        const auto destination = blend_factor(key.blend_destination);
        if (key.blend_enabled && (!source || !destination)) {
            return VK_NULL_HANDLE;
        }

        std::array<VkPipelineShaderStageCreateInfo, 2> stages { };
        stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
        stages[0].module = vertex_shader_;
        stages[0].pName = "main";
        stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
        stages[1].module = fragment_shader_;
        stages[1].pName = "main";

        VkVertexInputBindingDescription binding { };
        binding.binding = 0;
        binding.stride = sizeof(GpuVertex);
        binding.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;
        std::array<VkVertexInputAttributeDescription, 2 + gles_abi::texture_unit_count> attributes { };
        attributes[0] = { 0, 0, VK_FORMAT_R32G32B32A32_SFLOAT,
            static_cast<std::uint32_t>(offsetof(GpuVertex, position)) };
        attributes[1] = { 1, 0, VK_FORMAT_R32G32B32A32_SFLOAT,
            static_cast<std::uint32_t>(offsetof(GpuVertex, color)) };
        for (std::uint32_t unit = 0; unit < gles_abi::texture_unit_count; ++unit) {
            attributes[2 + unit] = { 2 + unit, 0, VK_FORMAT_R32G32_SFLOAT,
                static_cast<std::uint32_t>(offsetof(GpuVertex, texture0) +
                                          unit * sizeof(std::array<float, 2>)) };
        }
        auto vertex_input =
            make_vulkan_structure<VkPipelineVertexInputStateCreateInfo>(
                VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO);
        vertex_input.vertexBindingDescriptionCount = 1;
        vertex_input.pVertexBindingDescriptions = &binding;
        vertex_input.vertexAttributeDescriptionCount =
            static_cast<std::uint32_t>(attributes.size());
        vertex_input.pVertexAttributeDescriptions = attributes.data();
        auto assembly =
            make_vulkan_structure<VkPipelineInputAssemblyStateCreateInfo>(
                VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO);
        assembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

        auto viewport =
            make_vulkan_structure<VkPipelineViewportStateCreateInfo>(
                VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO);
        viewport.viewportCount = 1;
        viewport.scissorCount = 1;
        auto rasterization =
            make_vulkan_structure<VkPipelineRasterizationStateCreateInfo>(
                VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO);
        rasterization.polygonMode = VK_POLYGON_MODE_FILL;
        rasterization.cullMode = VK_CULL_MODE_NONE;
        rasterization.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rasterization.lineWidth = 1.0F;
        auto multisample =
            make_vulkan_structure<VkPipelineMultisampleStateCreateInfo>(
                VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO);
        multisample.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
        auto depth_stencil =
            make_vulkan_structure<VkPipelineDepthStencilStateCreateInfo>(
                VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO);
        if (key.stencil_mode != PipelineKey::StencilMode::Disabled) {
            depth_stencil.stencilTestEnable = VK_TRUE;
            VkStencilOpState stencil { };
            stencil.failOp = VK_STENCIL_OP_KEEP;
            stencil.passOp =
                key.stencil_mode == PipelineKey::StencilMode::WriteFirstTriangle
                    ? VK_STENCIL_OP_REPLACE
                    : VK_STENCIL_OP_KEEP;
            stencil.depthFailOp = VK_STENCIL_OP_KEEP;
            stencil.compareOp =
                key.stencil_mode == PipelineKey::StencilMode::WriteFirstTriangle
                    ? VK_COMPARE_OP_ALWAYS
                    : VK_COMPARE_OP_EQUAL;
            stencil.compareMask = 0xffU;
            stencil.writeMask =
                key.stencil_mode == PipelineKey::StencilMode::WriteFirstTriangle
                    ? 0xffU
                    : 0U;
            stencil.reference =
                key.stencil_mode == PipelineKey::StencilMode::WriteFirstTriangle
                    ? 1U
                    : 0U;
            depth_stencil.front = stencil;
            depth_stencil.back = stencil;
        }

        VkPipelineColorBlendAttachmentState blend { };
        blend.blendEnable = key.blend_enabled ? VK_TRUE : VK_FALSE;
        blend.srcColorBlendFactor =
            key.blend_enabled ? *source : VK_BLEND_FACTOR_ONE;
        blend.dstColorBlendFactor =
            key.blend_enabled ? *destination : VK_BLEND_FACTOR_ZERO;
        blend.colorBlendOp = VK_BLEND_OP_ADD;
        // The reference renderer preserves Porter-Duff alpha for the two
        // LayerKit blend modes instead of multiplying source alpha twice.
        const auto constant_alpha_crossfade =
            key.blend_source == constant_alpha_blend_factor &&
            key.blend_destination == one_minus_constant_alpha_blend_factor;
        blend.srcAlphaBlendFactor =
            constant_alpha_crossfade ? *source : VK_BLEND_FACTOR_ONE;
        blend.dstAlphaBlendFactor = constant_alpha_crossfade ? *destination
                                    : key.blend_enabled
                                        ? VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
                                        : VK_BLEND_FACTOR_ZERO;
        blend.alphaBlendOp = VK_BLEND_OP_ADD;
        blend.colorWriteMask = 0;
        if ((key.color_mask & 0x01U) != 0) {
            blend.colorWriteMask |= VK_COLOR_COMPONENT_R_BIT;
        }
        if ((key.color_mask & 0x02U) != 0) {
            blend.colorWriteMask |= VK_COLOR_COMPONENT_G_BIT;
        }
        if ((key.color_mask & 0x04U) != 0) {
            blend.colorWriteMask |= VK_COLOR_COMPONENT_B_BIT;
        }
        if ((key.color_mask & 0x08U) != 0) {
            blend.colorWriteMask |= VK_COLOR_COMPONENT_A_BIT;
        }
        auto blend_state =
            make_vulkan_structure<VkPipelineColorBlendStateCreateInfo>(
                VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO);
        blend_state.attachmentCount = 1;
        blend_state.pAttachments = &blend;
        constexpr std::array dynamic_states { VK_DYNAMIC_STATE_VIEWPORT,
            VK_DYNAMIC_STATE_SCISSOR, VK_DYNAMIC_STATE_BLEND_CONSTANTS };
        auto dynamic = make_vulkan_structure<VkPipelineDynamicStateCreateInfo>(
            VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO);
        dynamic.dynamicStateCount =
            static_cast<std::uint32_t>(dynamic_states.size());
        dynamic.pDynamicStates = dynamic_states.data();

        auto info = make_vulkan_structure<VkGraphicsPipelineCreateInfo>(
            VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO);
        info.stageCount = static_cast<std::uint32_t>(stages.size());
        info.pStages = stages.data();
        info.pVertexInputState = &vertex_input;
        info.pInputAssemblyState = &assembly;
        info.pViewportState = &viewport;
        info.pRasterizationState = &rasterization;
        info.pMultisampleState = &multisample;
        info.pDepthStencilState = &depth_stencil;
        info.pColorBlendState = &blend_state;
        info.pDynamicState = &dynamic;
        info.layout = pipeline_layout_;
        info.renderPass = key.stencil_mode == PipelineKey::StencilMode::Disabled
                              ? render_pass_
                              : stencil_render_pass_;
        info.subpass = 0;
        VkPipeline created { };
        require_success(vkCreateGraphicsPipelines(device_, pipeline_cache_, 1,
                            &info, nullptr, &created),
            "vkCreateGraphicsPipelines");
        pipelines_.emplace(key, created);
        return created;
    }

    std::vector<GpuVertex> VulkanGlesRenderer::expand_vertices(
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
        const GlesRasterState& state) const
    {
        std::vector<GpuVertex> result;
        result.reserve(vertices.size() * 3U);
        const auto emit = [&](std::size_t a, std::size_t b, std::size_t c) {
            const std::array indices { a, b, c };
            std::array<std::array<float, 2>, 3> normalized { };
            for (std::size_t index = 0; index < indices.size(); ++index) {
                const auto& position = vertices[indices[index]].position;
                if (position[3] == 0.0F)
                    return;
                normalized[index] = { position[0] / position[3],
                    position[1] / position[3] };
            }
            const auto area = (normalized[1][0] - normalized[0][0]) *
                                  (normalized[2][1] - normalized[0][1]) -
                              (normalized[1][1] - normalized[0][1]) *
                                  (normalized[2][0] - normalized[0][0]);
            if (std::abs(area) < 1.0e-6F)
                return;
            const auto front_facing =
                state.front_face == gles_abi::counter_clockwise ? area > 0.0F
                                                                : area < 0.0F;
            if (state.cull_enabled &&
                (state.cull_mode == gles_abi::front_and_back ||
                    (state.cull_mode == gles_abi::front && front_facing) ||
                    (state.cull_mode == gles_abi::back && !front_facing))) {
                return;
            }
            for (const auto index : indices) {
                const auto& vertex = vertices[index];
                auto position = vertex.position;
                if (state.render_target_inverted_vertical)
                    position[1] = -position[1];
                result.push_back(GpuVertex { position, vertex.color,
                    vertex.texture[0], vertex.texture[1], vertex.texture[2],
                    vertex.texture[3] });
            }
        };
        if (mode == gles_abi::triangles) {
            for (std::size_t index = 0; index + 2U < vertices.size();
                index += 3U) {
                emit(index, index + 1U, index + 2U);
            }
        } else if (mode == gles_abi::triangle_strip) {
            for (std::size_t index = 0; index + 2U < vertices.size(); ++index) {
                if ((index & 1U) == 0) {
                    emit(index, index + 1U, index + 2U);
                } else {
                    emit(index + 1U, index, index + 2U);
                }
            }
        } else if (mode == gles_abi::triangle_fan) {
            for (std::size_t index = 1; index + 1U < vertices.size(); ++index) {
                emit(0, index, index + 1U);
            }
        }
        return result;
    }

    GpuFixedFunctionState VulkanGlesRenderer::fixed_function_state(
        const GlesRasterState& state) const
    {
        GpuFixedFunctionState result;
        for (std::size_t index = 0; index < state.texture_units.size();
            ++index) {
            const auto& source = state.texture_units[index];
            auto& destination = result.units[index];
            const auto& environment = source.environment;
            destination.mode_combine_enabled = { static_cast<std::int32_t>(
                                                     environment.mode),
                static_cast<std::int32_t>(environment.combine_rgb),
                static_cast<std::int32_t>(environment.combine_alpha),
                source.enabled ? 1 : 0 };
            destination.color = environment.color;
            for (std::size_t argument = 0; argument < 3; ++argument) {
                destination.rgb_sources[argument] = static_cast<std::int32_t>(
                    environment.rgb_sources[argument]);
                destination.alpha_sources[argument] = static_cast<std::int32_t>(
                    environment.alpha_sources[argument]);
                destination.rgb_operands[argument] = static_cast<std::int32_t>(
                    environment.rgb_operands[argument]);
                destination.alpha_operands[argument] =
                    static_cast<std::int32_t>(
                        environment.alpha_operands[argument]);
            }
            destination.scales_rectangle = { environment.rgb_scale,
                environment.alpha_scale, source.rectangle ? 1.0F : 0.0F, 0.0F };
        }
        result.target_flags[0] =
            state.render_target_premultiplied && !state.blend_enabled ? 1 : 0;
        return result;
    }

    void VulkanGlesRenderer::transition_image(VkCommandBuffer command,
        VkImage image, VkImageLayout old_layout, VkImageLayout new_layout,
        VkPipelineStageFlags source_stage,
        VkPipelineStageFlags destination_stage, VkAccessFlags source_access,
        VkAccessFlags destination_access) const
    {
        auto barrier = make_vulkan_structure<VkImageMemoryBarrier>(
            VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER);
        barrier.srcAccessMask = source_access;
        barrier.dstAccessMask = destination_access;
        barrier.oldLayout = old_layout;
        barrier.newLayout = new_layout;
        barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.image = image;
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier.subresourceRange.levelCount = 1;
        barrier.subresourceRange.layerCount = 1;
        vkCmdPipelineBarrier(command, source_stage, destination_stage, 0, 0,
            nullptr, 0, nullptr, 1, &barrier);
    }

    bool VulkanGlesRenderer::synchronize(DisplayFrame& frame,
        GlesRenderTargetKey target,
        std::optional<HostRectangle>* readback_damage)
    {
        if (readback_damage != nullptr)
            readback_damage->reset();
        std::lock_guard lock { mutex_ };
        last_failure_reason_.store(
            PerfFallbackReason::None, std::memory_order_relaxed);
        const auto found = targets_.find(target);
        if (found == targets_.end() || !found->second.valid ||
            !found->second.dirty) {
            return true;
        }
        auto& surface = found->second;
        if (frame.width != surface.image.width ||
            frame.height != surface.image.height ||
            frame.pixels.size() !=
                static_cast<std::size_t>(frame.width) * frame.height) {
            last_failure_reason_.store(
                PerfFallbackReason::InvalidTarget, std::memory_order_relaxed);
            return false;
        }

        try {
            const auto damage = *surface.dirty;
            if (readback_damage != nullptr)
                *readback_damage = damage;
            const auto damage_pixels =
                static_cast<std::size_t>(damage.width) * damage.height;
            const auto damage_bytes = static_cast<VkDeviceSize>(damage_pixels) *
                                      sizeof(std::uint32_t);
            ensure_buffer(surface.download, damage_bytes,
                VK_BUFFER_USAGE_TRANSFER_DST_BIT);
            begin_commands();
            end_render_pass();
            auto& commands = command_slot();
            if (surface.layout != VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
                VkPipelineStageFlags source_stage =
                    VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
                VkAccessFlags source_access { };
                if (surface.layout ==
                    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                    source_stage =
                        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                    source_access = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
                } else if (surface.layout ==
                               VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL ||
                           surface.layout ==
                               VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
                    source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
                    source_access =
                        surface.layout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
                            ? VK_ACCESS_TRANSFER_WRITE_BIT
                            : VK_ACCESS_TRANSFER_READ_BIT;
                } else if (surface.layout ==
                           VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                    source_stage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
                    source_access = VK_ACCESS_SHADER_READ_BIT;
                }
                transition_image(commands.command, surface.image.image,
                    surface.layout, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                    source_stage, VK_PIPELINE_STAGE_TRANSFER_BIT, source_access,
                    VK_ACCESS_TRANSFER_READ_BIT);
            }
            VkBufferImageCopy copy { };
            copy.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            copy.imageSubresource.layerCount = 1;
            copy.imageOffset = { damage.x, damage.y, 0 };
            copy.imageExtent = { damage.width, damage.height, 1 };
            vkCmdCopyImageToBuffer(commands.command, surface.image.image,
                VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, surface.download.buffer,
                1, &copy);
            auto host_barrier = make_vulkan_structure<VkBufferMemoryBarrier>(
                VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER);
            host_barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            host_barrier.dstAccessMask = VK_ACCESS_HOST_READ_BIT;
            host_barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            host_barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            host_barrier.buffer = surface.download.buffer;
            host_barrier.size = VK_WHOLE_SIZE;
            vkCmdPipelineBarrier(commands.command,
                VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_HOST_BIT, 0,
                0, nullptr, 1, &host_barrier, 0, nullptr);
            submit_commands(true, PerfSubmitReason::CpuReadback);
            std::vector<std::uint32_t> pixels(damage_pixels);
            download(surface.download, pixels.data(),
                static_cast<std::size_t>(damage_bytes), surface.kind);
            for (std::uint32_t row = 0; row < damage.height; ++row) {
                std::copy_n(pixels.begin() +
                                static_cast<std::size_t>(row) * damage.width,
                    damage.width,
                    frame.pixels.begin() +
                        static_cast<std::size_t>(
                            static_cast<std::uint32_t>(damage.y) + row) *
                            frame.width +
                        static_cast<std::uint32_t>(damage.x));
            }
            surface.layout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
            surface.dirty.reset();
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            vkDeviceWaitIdle(device_);
            discard_commands();
            for (auto& [key, texture] : texture_cache_) {
                static_cast<void>(key);
                texture.revision = 0;
            }
            surface.valid = false;
            surface.dirty.reset();
            return false;
        }
    }

    bool VulkanGlesRenderer::flush(GlesRenderTargetKey target)
    {
        std::lock_guard lock { mutex_ };
        last_failure_reason_.store(
            PerfFallbackReason::None, std::memory_order_relaxed);
        if (!targets_.contains(target))
            return true;
        try {
            submit_commands(false, PerfSubmitReason::GlesSync);
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            vkDeviceWaitIdle(device_);
            discard_commands();
            if (const auto found = targets_.find(target);
                found != targets_.end()) {
                found->second.valid = false;
                found->second.dirty.reset();
            }
            return false;
        }
    }

    bool VulkanGlesRenderer::finish(GlesRenderTargetKey target)
    {
        std::lock_guard lock { mutex_ };
        last_failure_reason_.store(
            PerfFallbackReason::None, std::memory_order_relaxed);
        if (!targets_.contains(target))
            return true;
        try {
            submit_commands(true, PerfSubmitReason::GlesSync);
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return false;
        }
    }

    void VulkanGlesRenderer::invalidate(GlesRenderTargetKey target)
    {
        std::lock_guard lock { mutex_ };
        const auto found = targets_.find(target);
        if (found == targets_.end())
            return;
        if (command_recording_)
            submit_commands(false, PerfSubmitReason::ResourceLifetime);
        wait_for_all_slots();
        found->second.valid = false;
        found->second.dirty.reset();
    }

    void VulkanGlesRenderer::release(
        std::span<const GlesRenderTargetKey> targets)
    {
        const PerformanceLatencyScope latency {
            PerfLatencyKind::GlesTargetRelease
        };
        std::lock_guard lock { mutex_ };
        const auto has_target = std::ranges::any_of(targets,
            [this](const auto target) { return targets_.contains(target); });
        if (!has_target)
            return;
        if (command_recording_)
            submit_commands(false, PerfSubmitReason::ResourceLifetime);
        wait_for_all_slots();
        for (const auto target : targets) {
            const auto found = targets_.find(target);
            if (found == targets_.end())
                continue;
            auto retired = std::move(found->second);
            targets_.erase(found);
            pool_target(std::move(retired));
        }
    }

    void VulkanGlesRenderer::release_owner(std::uint64_t owner)
    {
        if (owner == 0)
            return;
        const PerformanceLatencyScope latency {
            PerfLatencyKind::GlesTargetRelease
        };
        std::lock_guard lock { mutex_ };
        const auto owns_target = [owner](const auto& entry) {
            return entry.first.owner == owner;
        };
        const auto owns_texture = [owner](const auto& entry) {
            return entry.first.owner == owner;
        };
        const auto has_target = std::ranges::any_of(targets_, owns_target);
        const auto has_texture =
            std::ranges::any_of(texture_cache_, owns_texture);
        if (!has_target && !has_texture) {
            return;
        }
        // Recorded descriptors and render passes can still reference both maps.
        // Submit once and wait once before retiring the complete process batch.
        try {
            if (command_recording_)
                submit_commands(false, PerfSubmitReason::ResourceLifetime);
            wait_for_all_slots();
        } catch (...) {
            // Resource release is reached from process teardown and OpenGLES
            // reset paths, both of which are noexcept from the guest's point of
            // view. Leave the owner entries for the renderer-wide destructor
            // after recording has been discarded rather than terminating the
            // emulator while unwinding an exiting task.
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return;
        }
        for (auto target = targets_.begin(); target != targets_.end();) {
            if (target->first.owner != owner) {
                ++target;
                continue;
            }
            auto retired = std::move(target->second);
            target = targets_.erase(target);
            pool_target(std::move(retired));
        }
        for (auto texture = texture_cache_.begin();
            texture != texture_cache_.end();) {
            if (texture->first.owner != owner) {
                ++texture;
                continue;
            }
            texture_cache_bytes_ -= std::min(
                texture_cache_bytes_, texture->second.image.allocation_size);
            texture = texture_cache_.erase(texture);
        }
    }

    HostGraphicsDevice::PresentResult VulkanGlesRenderer::present_target(
        Target& target)
    {
        // A presentation attempt is also a command-stream flush, even when the
        // host swapchain is temporarily unavailable. Encoder::submit relies on
        // this boundary while presentation owns the renderer mutex.
        submit_commands(false, PerfSubmitReason::Presentation);
        if (presentation_swapchain_ == VK_NULL_HANDLE ||
            presentation_images_.empty()) {
            last_failure_reason_.store(PerfFallbackReason::VulkanUnavailable,
                std::memory_order_relaxed);
            return PresentResult::Failed;
        }
        // DZN and other translation layers may retain a presented image beyond
        // the render fence. Keep presentation in the next ring slot so
        // compositor and presentation semaphore lifetimes cannot alias.
        auto* slot = &command_slot();
        wait_for_slot(*slot);

        std::uint32_t image_index { };
        const auto acquire_next_image = [&] {
            const PerformanceLatencyScope latency { PerfLatencyKind::Acquire };
            return vkAcquireNextImageKHR(device_, presentation_swapchain_,
                acquire_timeout_nanoseconds, slot->image_available,
                VK_NULL_HANDLE, &image_index);
        };
        auto acquired = acquire_next_image();
        if (acquired == VK_ERROR_SURFACE_LOST_KHR) {
            if (!recreate_presentation_surface()) {
                last_failure_reason_.store(PerfFallbackReason::BackendFailure,
                    std::memory_order_relaxed);
                return PresentResult::Failed;
            }
            slot = &command_slot();
            wait_for_slot(*slot);
            acquired = acquire_next_image();
        }
        if (acquired == VK_ERROR_OUT_OF_DATE_KHR) {
            require_success(vkDeviceWaitIdle(device_), "vkDeviceWaitIdle");
            if (!create_presentation_swapchain()) {
                last_failure_reason_.store(PerfFallbackReason::BackendFailure,
                    std::memory_order_relaxed);
                return PresentResult::Failed;
            }
            slot = &command_slot();
            wait_for_slot(*slot);
            acquired = acquire_next_image();
        }
        if (acquired == VK_TIMEOUT || acquired == VK_NOT_READY)
            return PresentResult::Skipped;
        if (acquired != VK_SUCCESS && acquired != VK_SUBOPTIMAL_KHR) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            return PresentResult::Failed;
        }
        if (image_index >= presentation_images_.size()) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            return PresentResult::Failed;
        }

        begin_commands();
        end_render_pass();
        auto& commands = command_slot();
        if (target.layout != VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
            VkPipelineStageFlags source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
            VkAccessFlags source_access =
                target.layout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
                    ? VK_ACCESS_TRANSFER_WRITE_BIT
                    : VK_ACCESS_TRANSFER_READ_BIT;
            if (target.layout == VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                source_stage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                source_access = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            } else if (target.layout ==
                       VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                source_stage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
                source_access = VK_ACCESS_SHADER_READ_BIT;
            }
            transition_image(commands.command, target.image.image,
                target.layout, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                source_stage, VK_PIPELINE_STAGE_TRANSFER_BIT, source_access,
                VK_ACCESS_TRANSFER_READ_BIT);
            target.layout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        }
        const auto previous_layout = presentation_layouts_[image_index];
        transition_image(commands.command, presentation_images_[image_index],
            previous_layout, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            previous_layout == VK_IMAGE_LAYOUT_UNDEFINED
                ? VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
                : VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            VK_PIPELINE_STAGE_TRANSFER_BIT, 0, VK_ACCESS_TRANSFER_WRITE_BIT);
        const auto viewport =
            fit_display_viewport({ target.image.width, target.image.height },
                { presentation_extent_.width, presentation_extent_.height });
        if (viewport.x != 0 || viewport.y != 0 ||
            viewport.width != presentation_extent_.width ||
            viewport.height != presentation_extent_.height) {
            const VkClearColorValue black { { 0.0F, 0.0F, 0.0F, 1.0F } };
            const VkImageSubresourceRange full_color {
                VK_IMAGE_ASPECT_COLOR_BIT, 0U, 1U, 0U, 1U
            };
            vkCmdClearColorImage(commands.command,
                presentation_images_[image_index],
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &black, 1U, &full_color);
        }
        VkImageBlit blit { };
        blit.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        blit.srcSubresource.layerCount = 1;
        blit.srcOffsets[1] = { static_cast<std::int32_t>(target.image.width),
            static_cast<std::int32_t>(target.image.height), 1 };
        blit.dstSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        blit.dstSubresource.layerCount = 1;
        blit.dstOffsets[0] = { viewport.x, viewport.y, 0 };
        blit.dstOffsets[1] = { viewport.x +
                                   static_cast<std::int32_t>(viewport.width),
            viewport.y + static_cast<std::int32_t>(viewport.height), 1 };
        vkCmdBlitImage(commands.command, target.image.image,
            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            presentation_images_[image_index],
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &blit,
            presentation_filter_);
        transition_image(commands.command, presentation_images_[image_index],
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, VK_ACCESS_TRANSFER_WRITE_BIT,
            0);
        presentation_layouts_[image_index] = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        const auto image_available = slot->image_available;
        if (image_index >= presentation_render_finished_.size()) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            discard_commands();
            return PresentResult::Failed;
        }
        const auto render_finished = presentation_render_finished_[image_index];
        submit_commands(false, PerfSubmitReason::Presentation, image_available,
            VK_PIPELINE_STAGE_TRANSFER_BIT, render_finished);

        auto present = make_vulkan_structure<VkPresentInfoKHR>(
            VK_STRUCTURE_TYPE_PRESENT_INFO_KHR);
        present.waitSemaphoreCount = 1;
        present.pWaitSemaphores = &render_finished;
        present.swapchainCount = 1;
        present.pSwapchains = &presentation_swapchain_;
        present.pImageIndices = &image_index;
        VkResult result { };
        {
            const PerformanceLatencyScope latency {
                PerfLatencyKind::QueuePresent
            };
            result = vkQueuePresentKHR(queue_, &present);
        }
        if (result == VK_ERROR_SURFACE_LOST_KHR) {
            if (!recreate_presentation_surface()) {
                last_failure_reason_.store(PerfFallbackReason::BackendFailure,
                    std::memory_order_relaxed);
                return PresentResult::Failed;
            }
            return present_target(target);
        }
        if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_SUBOPTIMAL_KHR ||
            acquired == VK_SUBOPTIMAL_KHR) {
            require_success(vkDeviceWaitIdle(device_), "vkDeviceWaitIdle");
            const auto recreated = create_presentation_swapchain();
            if (!recreated) {
                last_failure_reason_.store(PerfFallbackReason::BackendFailure,
                    std::memory_order_relaxed);
            }
            // VK_SUBOPTIMAL_KHR still accepted this frame. Report that outcome
            // even if preparing the next swapchain fails.
            return result == VK_SUCCESS || result == VK_SUBOPTIMAL_KHR
                       ? PresentResult::Queued
                       : PresentResult::Failed;
        }
        if (result != VK_SUCCESS) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            return PresentResult::Failed;
        }
        return PresentResult::Queued;
    }

    VulkanGlesRenderer::Target& VulkanGlesRenderer::prepare_host_surface(
        HostSurface& surface, const DisplayFrame& cpu_frame,
        std::uint64_t cpu_generation, std::uint64_t gpu_generation,
        std::vector<HostRectangle> cpu_damage)
    {
        const auto descriptor = surface.descriptor();
        auto& target =
            ensure_target(surface.key(), descriptor.width, descriptor.height);
        target.kind = descriptor.kind;
        if (target.valid && cpu_generation <= target.cpu_generation)
            return target;
        if (target.valid && gpu_generation != 0 &&
            cpu_generation == gpu_generation) {
            return target;
        }
        // A stale CPU shadow must never overwrite a newer native image.
        if (cpu_generation < gpu_generation ||
            cpu_frame.width != descriptor.width ||
            cpu_frame.height != descriptor.height ||
            cpu_frame.pixels.size() !=
                static_cast<std::size_t>(descriptor.width) *
                    descriptor.height) {
            return target;
        }
        const auto full_rectangle =
            HostRectangle { 0, 0, descriptor.width, descriptor.height };
        std::vector<HostRectangle> upload_rectangles { full_rectangle };
        if (target.valid && target.cpu_generation != 0) {
            const auto valid_rectangle = [&descriptor](
                                             HostRectangle rectangle) {
                return rectangle.x >= 0 && rectangle.y >= 0 &&
                       rectangle.width != 0 && rectangle.height != 0 &&
                       rectangle.width <= descriptor.width &&
                       rectangle.height <= descriptor.height &&
                       static_cast<std::uint32_t>(rectangle.x) <=
                           descriptor.width - rectangle.width &&
                       static_cast<std::uint32_t>(rectangle.y) <=
                           descriptor.height - rectangle.height;
            };
            if (!cpu_damage.empty() &&
                std::ranges::all_of(cpu_damage, valid_rectangle)) {
                upload_rectangles = std::move(cpu_damage);
            }
        }
        const auto full_upload = upload_rectangles.size() == 1 &&
                                 upload_rectangles.front() == full_rectangle;
        std::size_t upload_pixel_count { };
        for (const auto rectangle : upload_rectangles) {
            const auto rectangle_pixels =
                static_cast<std::size_t>(rectangle.width) * rectangle.height;
            if (rectangle_pixels >
                std::numeric_limits<std::size_t>::max() - upload_pixel_count) {
                return target;
            }
            upload_pixel_count += rectangle_pixels;
        }
        std::vector<std::uint32_t> upload_pixels;
        const std::uint32_t* upload_source = cpu_frame.pixels.data();
        if (!full_upload) {
            upload_pixels.reserve(upload_pixel_count);
            for (const auto rectangle : upload_rectangles) {
                for (std::uint32_t row = 0; row < rectangle.height; ++row) {
                    const auto begin =
                        cpu_frame.pixels.begin() +
                        static_cast<std::size_t>(
                            static_cast<std::uint32_t>(rectangle.y) + row) *
                            descriptor.width +
                        static_cast<std::uint32_t>(rectangle.x);
                    upload_pixels.insert(
                        upload_pixels.end(), begin, begin + rectangle.width);
                }
            }
            upload_source = upload_pixels.data();
        }
        const auto byte_count = static_cast<VkDeviceSize>(upload_pixel_count) *
                                sizeof(std::uint32_t);
        const auto align_staging = [](VkDeviceSize value) {
            return (value + staging_alignment - 1U) & ~(staging_alignment - 1U);
        };
        auto required_end =
            align_staging(command_slot().staging_bytes_used) + byte_count;
        if (command_recording_ &&
            command_slot().staging.buffer != VK_NULL_HANDLE &&
            required_end > command_slot().staging.size) {
            submit_commands(false, PerfSubmitReason::StagingCapacity);
            required_end = byte_count;
        }
        wait_for_slot(command_slot());
        auto& commands = command_slot();
        ensure_buffer(commands.staging,
            std::max(required_end, minimum_staging_arena_bytes),
            VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
        const auto staging_offset = align_staging(commands.staging_bytes_used);
        upload(commands.staging, upload_source,
            static_cast<std::size_t>(byte_count), staging_offset,
            descriptor.kind);
        commands.staging_bytes_used = staging_offset + byte_count;

        begin_commands();
        end_render_pass();
        VkPipelineStageFlags source_stage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        VkAccessFlags source_access { };
        if (target.layout == VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
            source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
            source_access = VK_ACCESS_TRANSFER_READ_BIT;
        } else if (target.layout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
            source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
            source_access = VK_ACCESS_TRANSFER_WRITE_BIT;
        } else if (target.layout == VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
            source_stage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            source_access = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                            VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        }
        transition_image(commands.command, target.image.image, target.layout,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, source_stage,
            VK_PIPELINE_STAGE_TRANSFER_BIT, source_access,
            VK_ACCESS_TRANSFER_WRITE_BIT);
        std::vector<VkBufferImageCopy> copies;
        copies.reserve(upload_rectangles.size());
        VkDeviceSize copy_offset = staging_offset;
        for (const auto rectangle : upload_rectangles) {
            VkBufferImageCopy copy { };
            copy.bufferOffset = copy_offset;
            copy.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            copy.imageSubresource.layerCount = 1;
            copy.imageOffset = { rectangle.x, rectangle.y, 0 };
            copy.imageExtent = { rectangle.width, rectangle.height, 1 };
            copies.push_back(copy);
            copy_offset += static_cast<VkDeviceSize>(rectangle.width) *
                           rectangle.height * sizeof(std::uint32_t);
        }
        vkCmdCopyBufferToImage(commands.command, commands.staging.buffer,
            target.image.image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            static_cast<std::uint32_t>(copies.size()), copies.data());
        target.layout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        target.cpu_generation = cpu_generation;
        target.valid = true;
        // A partial CPU upload preserves newer GPU pixels outside the uploaded
        // rectangle. Keep their conservative damage so a later CPU map can
        // still refresh the shadow; a full upload makes the CPU frame
        // authoritative.
        if (full_upload)
            target.dirty.reset();
        return target;
    }

    VulkanGlesRenderer::SurfacePreparation
    VulkanGlesRenderer::capture_surface_preparation(HostSurface& surface)
    {
        SurfacePreparation preparation;
        preparation.cpu_generation = surface.cpu_generation();
        preparation.gpu_generation = surface.gpu_generation();

        bool needs_cpu_frame = true;
        {
            std::lock_guard lock { mutex_ };
            const auto target = targets_.find(surface.key());
            if (target != targets_.end() && target->second.valid &&
                (preparation.cpu_generation <= target->second.cpu_generation ||
                    (preparation.gpu_generation != 0 &&
                        preparation.cpu_generation ==
                            preparation.gpu_generation))) {
                needs_cpu_frame = false;
            }
        }
        if (preparation.cpu_generation < preparation.gpu_generation)
            needs_cpu_frame = false;
        if (!needs_cpu_frame)
            return preparation;

        {
            auto mapping = surface.map_cpu(false, PerfCpuMapReason::HostUpload);
            preparation.cpu_frame = mapping.frame();
        }
        if (preparation.cpu_generation > preparation.gpu_generation)
            preparation.cpu_damage = surface.cpu_damage_rectangles();
        return preparation;
    }

    bool VulkanGlesRenderer::encode_fill(HostSurface& destination,
        HostRectangle rectangle, std::uint32_t argb, HostCompositeMode mode,
        std::uint8_t global_alpha)
    {
        const auto descriptor = destination.descriptor();
        if (rectangle.x < 0 || rectangle.y < 0 || rectangle.width == 0 ||
            rectangle.height == 0 || rectangle.width > descriptor.width ||
            rectangle.height > descriptor.height ||
            static_cast<std::uint32_t>(rectangle.x) >
                descriptor.width - rectangle.width ||
            static_cast<std::uint32_t>(rectangle.y) >
                descriptor.height - rectangle.height) {
            return false;
        }

        if (mode != HostCompositeMode::Copy) {
            const auto left = static_cast<float>(rectangle.x);
            const auto top = static_cast<float>(rectangle.y);
            const auto right = left + static_cast<float>(rectangle.width);
            const auto bottom = top + static_cast<float>(rectangle.height);
            const std::array<HostPoint, 4> positions { {
                { left, top },
                { right, top },
                { right, bottom },
                { left, bottom },
            } };
            return encode_fill_quad(
                destination, positions, rectangle, argb, mode, global_alpha);
        }

        auto destination_preparation = capture_surface_preparation(destination);
        try {
            {
                std::lock_guard lock { mutex_ };
                auto& target = prepare_host_surface(destination,
                    destination_preparation.cpu_frame,
                    destination_preparation.cpu_generation,
                    destination_preparation.gpu_generation,
                    std::move(destination_preparation.cpu_damage));
                if (!target.valid)
                    return false;
                begin_commands();
                if (render_pass_open_ &&
                    render_pass_target_ != destination.key()) {
                    end_render_pass();
                }
                if (target.layout != VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                    end_render_pass();
                    VkPipelineStageFlags source_stage =
                        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
                    VkAccessFlags source_access { };
                    if (target.layout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
                        source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
                        source_access = VK_ACCESS_TRANSFER_WRITE_BIT;
                    } else if (target.layout ==
                               VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
                        source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
                        source_access = VK_ACCESS_TRANSFER_READ_BIT;
                    }
                    transition_image(command_slot().command, target.image.image,
                        target.layout, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                        source_stage,
                        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                        source_access,
                        VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                            VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);
                    target.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
                }
                if (!render_pass_open_) {
                    auto begin = make_vulkan_structure<VkRenderPassBeginInfo>(
                        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
                    begin.renderPass = render_pass_;
                    begin.framebuffer = target.framebuffer;
                    begin.renderArea.extent = { descriptor.width,
                        descriptor.height };
                    vkCmdBeginRenderPass(command_slot().command, &begin,
                        VK_SUBPASS_CONTENTS_INLINE);
                    render_pass_open_ = true;
                    render_pass_target_ = destination.key();
                }
                VkClearAttachment attachment { };
                attachment.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
                attachment.colorAttachment = 0;
                attachment.clearValue.color.float32[0] =
                    static_cast<float>((argb >> 16U) & 0xffU) / 255.0F;
                attachment.clearValue.color.float32[1] =
                    static_cast<float>((argb >> 8U) & 0xffU) / 255.0F;
                attachment.clearValue.color.float32[2] =
                    static_cast<float>(argb & 0xffU) / 255.0F;
                attachment.clearValue.color.float32[3] =
                    static_cast<float>((argb >> 24U) & 0xffU) / 255.0F;
                VkClearRect clear { };
                clear.rect.offset = { rectangle.x, rectangle.y };
                clear.rect.extent = { rectangle.width, rectangle.height };
                clear.layerCount = 1;
                vkCmdClearAttachments(
                    command_slot().command, 1, &attachment, 1, &clear);
                add_damage(target.dirty, rectangle);
            }
            destination.mark_gpu_synchronized(
                destination_preparation.cpu_generation);
            static_cast<void>(destination.mark_gpu_write(rectangle));
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            std::lock_guard lock { mutex_ };
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return false;
        }
    }

    bool VulkanGlesRenderer::encode_fill_triangles(HostSurface& destination,
        std::span<const HostPoint> positions, HostRectangle scissor,
        std::uint32_t argb, HostCompositeMode mode, std::uint8_t global_alpha)
    {
        const auto descriptor = destination.descriptor();
        if (scissor.x < 0 || scissor.y < 0 || scissor.width == 0 ||
            scissor.height == 0 || scissor.width > descriptor.width ||
            scissor.height > descriptor.height ||
            static_cast<std::uint32_t>(scissor.x) >
                descriptor.width - scissor.width ||
            static_cast<std::uint32_t>(scissor.y) >
                descriptor.height - scissor.height ||
            positions.size() < 3 || positions.size() % 3 != 0 ||
            std::ranges::any_of(positions, [](const HostPoint& point) {
                return !std::isfinite(point.x) || !std::isfinite(point.y);
            })) {
            return false;
        }

        const auto channel = [argb](std::uint32_t shift) {
            return static_cast<float>((argb >> shift) & 0xffU) / 255.0F;
        };
        const auto global = static_cast<float>(global_alpha) / 255.0F;
        const auto crossfade =
            mode == HostCompositeMode::ConstantAlphaCrossfade;
        const auto premultiplied =
            mode == HostCompositeMode::PremultipliedSourceOver;
        const std::array<float, 4> color {
            channel(16) * (premultiplied ? global : 1.0F),
            channel(8) * (premultiplied ? global : 1.0F),
            channel(0) * (premultiplied ? global : 1.0F),
            channel(24) *
                (mode == HostCompositeMode::Copy || crossfade ? 1.0F : global)
        };
        std::vector<GlesRasterVertex> vertices(positions.size());
        for (std::size_t index = 0; index < vertices.size(); ++index) {
            vertices[index].position = { 2.0F * positions[index].x /
                                                 static_cast<float>(
                                                     descriptor.width) -
                                             1.0F,
                1.0F - 2.0F * positions[index].y /
                           static_cast<float>(descriptor.height),
                0.0F, 1.0F };
            vertices[index].color = color;
        }
        GlesRasterState state;
        state.viewport_width = descriptor.width;
        state.viewport_height = descriptor.height;
        state.scissor_enabled = true;
        state.scissor_box = { scissor.x,
            static_cast<std::int32_t>(
                descriptor.height -
                (static_cast<std::uint32_t>(scissor.y) + scissor.height)),
            static_cast<std::int32_t>(scissor.width),
            static_cast<std::int32_t>(scissor.height) };
        state.blend_enabled = mode != HostCompositeMode::Copy;
        state.blend_source = crossfade       ? constant_alpha_blend_factor
                             : premultiplied ? gles_abi::one
                                             : gles_abi::source_alpha;
        state.blend_destination = crossfade
                                      ? one_minus_constant_alpha_blend_factor
                                      : gles_abi::one_minus_source_alpha;
        state.blend_constant = { global, global, global, global };

        const auto cpu_generation = destination.cpu_generation();
        const auto gpu_generation = destination.gpu_generation();
        DisplayFrame cpu_frame;
        {
            auto mapping =
                destination.map_cpu(false, PerfCpuMapReason::HostUpload);
            cpu_frame = mapping.frame();
        }
        auto cpu_damage = cpu_generation > gpu_generation
                              ? destination.cpu_damage_rectangles()
                              : std::vector<HostRectangle> { };
        try {
            std::lock_guard lock { mutex_ };
            if (!prepare_host_surface(destination, cpu_frame, cpu_generation,
                    gpu_generation, std::move(cpu_damage))
                    .valid) {
                return false;
            }
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            std::lock_guard lock { mutex_ };
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return false;
        }
        if (!draw(cpu_frame, destination.key(), vertices, gles_abi::triangles,
                state)) {
            return false;
        }
        destination.mark_gpu_synchronized(cpu_generation);
        static_cast<void>(destination.mark_gpu_write(scissor));
        return true;
    }

    bool VulkanGlesRenderer::encode_fill_quad(HostSurface& destination,
        std::span<const HostPoint> positions, HostRectangle scissor,
        std::uint32_t argb, HostCompositeMode mode, std::uint8_t global_alpha)
    {
        const auto descriptor = destination.descriptor();
        const auto valid_scissor = scissor.x >= 0 && scissor.y >= 0 &&
                                   scissor.width != 0 && scissor.height != 0 &&
                                   scissor.width <= descriptor.width &&
                                   scissor.height <= descriptor.height &&
                                   static_cast<std::uint32_t>(scissor.x) <=
                                       descriptor.width - scissor.width &&
                                   static_cast<std::uint32_t>(scissor.y) <=
                                       descriptor.height - scissor.height;
        if (!valid_scissor || !valid_host_quad(positions) ||
            std::ranges::any_of(positions,
                [](const HostPoint point) {
                    return !std::isfinite(point.x) || !std::isfinite(point.y);
                }) ||
            !quad_white_surface_) {
            return false;
        }

        const auto channel = [argb](std::uint32_t shift) {
            return static_cast<float>((argb >> shift) & 0xffU) / 255.0F;
        };
        const auto alpha = static_cast<float>(global_alpha) / 255.0F;
        const auto crossfade =
            mode == HostCompositeMode::ConstantAlphaCrossfade;
        const auto premultiplied =
            mode == HostCompositeMode::PremultipliedSourceOver;
        const std::array<float, 4> color { channel(16) *
                                               (premultiplied ? alpha : 1.0F),
            channel(8) * (premultiplied ? alpha : 1.0F),
            channel(0) * (premultiplied ? alpha : 1.0F),
            channel(24) *
                (mode == HostCompositeMode::Copy || crossfade ? 1.0F : alpha) };
        constexpr std::array<std::array<std::size_t, 3>, 2> triangles { {
            { 0, 1, 2 },
            { 0, 2, 3 },
        } };
        std::array<GpuVertex, 6> vertices { };
        std::size_t output { };
        for (const auto& triangle : triangles) {
            for (std::size_t vertex = 0; vertex < triangle.size(); ++vertex) {
                const auto position =
                    expand_quad_triangle_vertex(positions, triangle, vertex);
                vertices[output++] = {
                    { 2.0F * position.x / static_cast<float>(descriptor.width) -
                            1.0F,
                        1.0F - 2.0F * position.y /
                                   static_cast<float>(descriptor.height),
                        0.0F, 1.0F },
                    color, { 0.5F, 0.5F }, { }
                };
            }
        }

        auto white_preparation =
            capture_surface_preparation(*quad_white_surface_);
        auto destination_preparation = capture_surface_preparation(destination);
        try {
            {
                std::lock_guard lock { mutex_ };
                auto& white_target = prepare_host_surface(*quad_white_surface_,
                    white_preparation.cpu_frame,
                    white_preparation.cpu_generation,
                    white_preparation.gpu_generation,
                    std::move(white_preparation.cpu_damage));
                auto& destination_target = prepare_host_surface(destination,
                    destination_preparation.cpu_frame,
                    destination_preparation.cpu_generation,
                    destination_preparation.gpu_generation,
                    std::move(destination_preparation.cpu_damage));
                if (!white_target.valid || !destination_target.valid ||
                    !draw_host_texture(white_target, destination_target,
                        destination.key(), descriptor, vertices,
                        { 0, 0, descriptor.width, descriptor.height }, scissor,
                        mode, global_alpha, true)) {
                    return false;
                }
                add_damage(destination_target.dirty, scissor);
            }
            quad_white_surface_->mark_gpu_synchronized(
                white_preparation.cpu_generation);
            destination.mark_gpu_synchronized(
                destination_preparation.cpu_generation);
            static_cast<void>(destination.mark_gpu_write(scissor));
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            std::lock_guard lock { mutex_ };
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return false;
        }
    }

    bool VulkanGlesRenderer::encode_copy_quad(HostSurface& source,
        HostSurface& destination,
        std::span<const HostTexturedVertex> host_vertices,
        HostRectangle source_rectangle, HostRectangle scissor,
        HostCompositeMode mode, std::uint8_t global_alpha, HostFilter filter)
    {
        if (source.key() == destination.key() ||
            filter != HostFilter::Nearest || host_vertices.size() != 4) {
            return false;
        }
        const auto source_descriptor = source.descriptor();
        const auto destination_descriptor = destination.descriptor();
        const auto valid_source =
            source_rectangle.x >= 0 && source_rectangle.y >= 0 &&
            source_rectangle.width != 0 && source_rectangle.height != 0 &&
            source_rectangle.width <= source_descriptor.width &&
            source_rectangle.height <= source_descriptor.height &&
            static_cast<std::uint32_t>(source_rectangle.x) <=
                source_descriptor.width - source_rectangle.width &&
            static_cast<std::uint32_t>(source_rectangle.y) <=
                source_descriptor.height - source_rectangle.height;
        const auto full_source =
            source_rectangle.x == 0 && source_rectangle.y == 0 &&
            source_rectangle.width == source_descriptor.width &&
            source_rectangle.height == source_descriptor.height;
        const auto valid_scissor =
            scissor.x >= 0 && scissor.y >= 0 && scissor.width != 0 &&
            scissor.height != 0 &&
            scissor.width <= destination_descriptor.width &&
            scissor.height <= destination_descriptor.height &&
            static_cast<std::uint32_t>(scissor.x) <=
                destination_descriptor.width - scissor.width &&
            static_cast<std::uint32_t>(scissor.y) <=
                destination_descriptor.height - scissor.height;
        std::array<HostPoint, 4> positions { };
        std::array<HostPoint, 4> texture { };
        for (std::size_t index = 0; index < host_vertices.size(); ++index) {
            positions[index] = host_vertices[index].position;
            texture[index] = host_vertices[index].texture;
        }
        if (!valid_source || !valid_scissor || source_descriptor.width == 0 ||
            source_descriptor.height == 0 ||
            destination_descriptor.width == 0 ||
            destination_descriptor.height == 0 || !valid_host_quad(positions) ||
            std::ranges::any_of(
                host_vertices, [](const HostTexturedVertex vertex) {
                    return !std::isfinite(vertex.position.x) ||
                           !std::isfinite(vertex.position.y) ||
                           !std::isfinite(vertex.texture.x) ||
                           !std::isfinite(vertex.texture.y) ||
                           !std::isfinite(vertex.perspective) ||
                           std::abs(vertex.perspective) <= 1.0e-6F;
                })) {
            return false;
        }

        const auto alpha = static_cast<float>(global_alpha) / 255.0F;
        const auto crossfade =
            mode == HostCompositeMode::ConstantAlphaCrossfade;
        const auto rgb =
            mode == HostCompositeMode::PremultipliedSourceOver ? alpha : 1.0F;
        const std::array<float, 4> color { rgb, rgb, rgb,
            mode == HostCompositeMode::Copy || crossfade ? 1.0F : alpha };
        constexpr std::array<std::array<std::size_t, 3>, 2> triangles { {
            { 0, 1, 2 },
            { 0, 2, 3 },
        } };
        std::array<GpuVertex, 6> vertices { };
        std::size_t output { };
        for (const auto& triangle : triangles) {
            for (std::size_t vertex = 0; vertex < triangle.size(); ++vertex) {
                const auto position =
                    expand_quad_triangle_vertex(positions, triangle, vertex);
                const auto coordinate =
                    expand_quad_triangle_vertex(texture, triangle, vertex);
                const auto perspective =
                    host_vertices[triangle[vertex]].perspective;
                const auto normalized_x =
                    2.0F * position.x /
                        static_cast<float>(destination_descriptor.width) -
                    1.0F;
                const auto normalized_y =
                    1.0F -
                    2.0F * position.y /
                        static_cast<float>(destination_descriptor.height);
                const std::array<float, 2> gpu_coordinate =
                    full_source ? std::array { coordinate.x /
                                                   static_cast<float>(
                                                       source_descriptor.width),
                        coordinate.y /
                            static_cast<float>(source_descriptor.height) }
                                : std::array { coordinate.x, coordinate.y };
                vertices[output++] = { { normalized_x * perspective,
                                           normalized_y * perspective, 0.0F,
                                           perspective },
                    color, gpu_coordinate, { } };
            }
        }

        auto source_preparation = capture_surface_preparation(source);
        auto destination_preparation = capture_surface_preparation(destination);
        try {
            {
                std::lock_guard lock { mutex_ };
                auto& source_target =
                    prepare_host_surface(source, source_preparation.cpu_frame,
                        source_preparation.cpu_generation,
                        source_preparation.gpu_generation,
                        std::move(source_preparation.cpu_damage));
                auto& destination_target = prepare_host_surface(destination,
                    destination_preparation.cpu_frame,
                    destination_preparation.cpu_generation,
                    destination_preparation.gpu_generation,
                    std::move(destination_preparation.cpu_damage));
                if (!source_target.valid || !destination_target.valid ||
                    !draw_host_texture(source_target, destination_target,
                        destination.key(), destination_descriptor, vertices,
                        { 0, 0, destination_descriptor.width,
                            destination_descriptor.height },
                        scissor, mode, global_alpha, true,
                        full_source ? std::optional<HostRectangle> { }
                                    : std::optional { source_rectangle })) {
                    return false;
                }
                add_damage(destination_target.dirty, scissor);
            }
            source.mark_gpu_synchronized(source_preparation.cpu_generation);
            destination.mark_gpu_synchronized(
                destination_preparation.cpu_generation);
            static_cast<void>(destination.mark_gpu_write(scissor));
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            std::lock_guard lock { mutex_ };
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return false;
        }
    }

    bool VulkanGlesRenderer::draw_host_texture(Target& source,
        Target& destination, HostSurfaceKey destination_key,
        HostSurfaceDescriptor destination_descriptor,
        std::span<const GpuVertex> vertices, HostRectangle viewport,
        HostRectangle scissor, HostCompositeMode mode,
        std::uint8_t global_alpha, bool ordered_quad,
        std::optional<HostRectangle> source_clamp)
    {
        if (vertices.size() < 3 || (ordered_quad && vertices.size() != 6) ||
            vertices.size() >
                std::numeric_limits<VkDeviceSize>::max() / sizeof(GpuVertex)) {
            return false;
        }
        const auto crossfade =
            mode == HostCompositeMode::ConstantAlphaCrossfade;
        auto pipeline_key = PipelineKey { mode != HostCompositeMode::Copy,
            mode == HostCompositeMode::Copy ? gles_abi::one
            : crossfade                     ? constant_alpha_blend_factor
            : mode == HostCompositeMode::PremultipliedSourceOver
                ? gles_abi::one
                : gles_abi::source_alpha,
            mode == HostCompositeMode::Copy ? gles_abi::zero
            : crossfade ? one_minus_constant_alpha_blend_factor
                        : gles_abi::one_minus_source_alpha,
            0x0fU };
        const auto selected_pipeline = pipeline(pipeline_key);
        if (selected_pipeline == VK_NULL_HANDLE)
            return false;
        VkPipeline first_triangle_pipeline { };
        VkPipeline outside_first_triangle_pipeline { };
        if (ordered_quad) {
            pipeline_key.stencil_mode =
                PipelineKey::StencilMode::WriteFirstTriangle;
            first_triangle_pipeline = pipeline(pipeline_key);
            pipeline_key.stencil_mode =
                PipelineKey::StencilMode::TestOutsideFirstTriangle;
            outside_first_triangle_pipeline = pipeline(pipeline_key);
            if (first_triangle_pipeline == VK_NULL_HANDLE ||
                outside_first_triangle_pipeline == VK_NULL_HANDLE) {
                return false;
            }
        }
        if (command_slot().draw_count == maximum_batch_draws)
            submit_commands(false, PerfSubmitReason::BatchCapacity);
        wait_for_slot(command_slot());
        const auto vertex_bytes =
            static_cast<VkDeviceSize>(vertices.size()) * sizeof(GpuVertex);
        if (command_slot().vertex.buffer != VK_NULL_HANDLE &&
            (vertex_bytes > command_slot().vertex.size ||
                command_slot().vertex_bytes_used >
                    command_slot().vertex.size - vertex_bytes)) {
            submit_commands(false, PerfSubmitReason::BatchCapacity);
            wait_for_slot(command_slot());
        }
        ensure_buffer(command_slot().vertex,
            std::max(minimum_vertex_arena_bytes, vertex_bytes),
            VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
        auto& commands = command_slot();
        ensure_buffer(commands.uniform, uniform_stride_ * maximum_batch_draws,
            VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
        const auto vertex_offset = commands.vertex_bytes_used;
        const auto uniform_offset =
            uniform_stride_ * static_cast<VkDeviceSize>(commands.draw_count);
        GlesRasterState texture_state;
        texture_state.texture_units[0].enabled = true;
        texture_state.texture_units[0].environment.mode = gles_abi::modulate;
        texture_state.texture_units[0].rectangle = source_clamp.has_value();
        auto uniforms = fixed_function_state(texture_state);
        if (source_clamp) {
            auto& unit = uniforms.units[0];
            unit.scales_rectangle[3] = 1.0F;
            unit.clamp_rectangle = { static_cast<float>(source_clamp->x),
                static_cast<float>(source_clamp->y),
                static_cast<float>(static_cast<std::int64_t>(source_clamp->x) +
                                   source_clamp->width - 1),
                static_cast<float>(static_cast<std::int64_t>(source_clamp->y) +
                                   source_clamp->height - 1) };
        }
        upload(commands.vertex, vertices.data(),
            static_cast<std::size_t>(vertex_bytes), vertex_offset);
        upload(commands.uniform, &uniforms, sizeof(uniforms), uniform_offset);

        const auto descriptor = commands.descriptors[commands.draw_count];
        VkDescriptorBufferInfo uniform_info { commands.uniform.buffer,
            uniform_offset, sizeof(GpuFixedFunctionState) };
        const VkDescriptorImageInfo image_info { host_clamp_sampler_,
            source.image.view, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL };
        std::array<VkWriteDescriptorSet, 1 + gles_abi::texture_unit_count> writes { };
        writes[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writes[0].dstSet = descriptor;
        writes[0].dstBinding = 0;
        writes[0].descriptorCount = 1;
        writes[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        writes[0].pBufferInfo = &uniform_info;
        for (std::uint32_t binding = 1; binding < writes.size(); ++binding) {
            writes[binding].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writes[binding].dstSet = descriptor;
            writes[binding].dstBinding = binding;
            writes[binding].descriptorCount = 1;
            writes[binding].descriptorType =
                VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            writes[binding].pImageInfo = &image_info;
        }
        vkUpdateDescriptorSets(device_,
            static_cast<std::uint32_t>(writes.size()), writes.data(), 0,
            nullptr);

        begin_commands();
        end_render_pass();
        if (source.layout != VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
            VkPipelineStageFlags source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
            VkAccessFlags source_access =
                source.layout == VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
                    ? VK_ACCESS_TRANSFER_READ_BIT
                    : VK_ACCESS_TRANSFER_WRITE_BIT;
            if (source.layout == VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                source_stage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                source_access = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            }
            transition_image(commands.command, source.image.image,
                source.layout, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                source_stage, VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                source_access, VK_ACCESS_SHADER_READ_BIT);
            source.layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        }
        if (destination.layout != VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
            VkPipelineStageFlags source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
            VkAccessFlags source_access =
                destination.layout == VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
                    ? VK_ACCESS_TRANSFER_READ_BIT
                    : VK_ACCESS_TRANSFER_WRITE_BIT;
            if (destination.layout ==
                VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                source_stage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
                source_access = VK_ACCESS_SHADER_READ_BIT;
            }
            transition_image(commands.command, destination.image.image,
                destination.layout, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                source_stage, VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                source_access,
                VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);
            destination.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        }
        if (ordered_quad)
            ensure_stencil_framebuffer(destination);
        auto render_begin = make_vulkan_structure<VkRenderPassBeginInfo>(
            VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
        render_begin.renderPass =
            ordered_quad ? stencil_render_pass_ : render_pass_;
        render_begin.framebuffer = ordered_quad
                                       ? destination.stencil_framebuffer
                                       : destination.framebuffer;
        render_begin.renderArea.extent = { destination_descriptor.width,
            destination_descriptor.height };
        vkCmdBeginRenderPass(
            commands.command, &render_begin, VK_SUBPASS_CONTENTS_INLINE);
        render_pass_open_ = true;
        render_pass_target_ = destination_key;

        vkCmdBindPipeline(commands.command, VK_PIPELINE_BIND_POINT_GRAPHICS,
            ordered_quad ? first_triangle_pipeline : selected_pipeline);
        vkCmdBindVertexBuffers(
            commands.command, 0, 1, &commands.vertex.buffer, &vertex_offset);
        vkCmdBindDescriptorSets(commands.command,
            VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout_, 0, 1,
            &descriptor, 0, nullptr);
        VkViewport vulkan_viewport { };
        vulkan_viewport.x = static_cast<float>(viewport.x);
        vulkan_viewport.y = static_cast<float>(viewport.y);
        vulkan_viewport.width = static_cast<float>(viewport.width);
        vulkan_viewport.height = static_cast<float>(viewport.height);
        vulkan_viewport.minDepth = 0.0F;
        vulkan_viewport.maxDepth = 1.0F;
        vkCmdSetViewport(commands.command, 0, 1, &vulkan_viewport);
        VkRect2D vulkan_scissor { };
        vulkan_scissor.offset = { scissor.x, scissor.y };
        vulkan_scissor.extent = { scissor.width, scissor.height };
        vkCmdSetScissor(commands.command, 0, 1, &vulkan_scissor);
        const auto alpha = static_cast<float>(global_alpha) / 255.0F;
        const std::array blend_constant { alpha, alpha, alpha, alpha };
        vkCmdSetBlendConstants(commands.command, blend_constant.data());
        if (ordered_quad) {
            VkClearAttachment stencil_clear { };
            stencil_clear.aspectMask = VK_IMAGE_ASPECT_STENCIL_BIT;
            stencil_clear.clearValue.depthStencil.stencil = 0U;
            VkClearRect clear_rectangle { };
            clear_rectangle.rect = vulkan_scissor;
            clear_rectangle.layerCount = 1U;
            vkCmdClearAttachments(
                commands.command, 1U, &stencil_clear, 1U, &clear_rectangle);
            vkCmdDraw(commands.command, 3U, 1U, 0U, 0U);
            vkCmdBindPipeline(commands.command, VK_PIPELINE_BIND_POINT_GRAPHICS,
                outside_first_triangle_pipeline);
            vkCmdDraw(commands.command, 3U, 1U, 3U, 0U);
        } else {
            vkCmdDraw(commands.command,
                static_cast<std::uint32_t>(vertices.size()), 1U, 0U, 0U);
        }
        ++commands.draw_count;
        commands.vertex_bytes_used += vertex_bytes;
        return true;
    }

    bool VulkanGlesRenderer::encode_copy(HostSurface& source,
        HostSurface& destination, HostRectangle source_rectangle,
        HostRectangle destination_rectangle, HostCompositeMode mode,
        std::uint8_t global_alpha, HostFilter filter, HostRotation rotation,
        std::optional<HostRectangle> clip)
    {
        if (source.key() == destination.key() ||
            ((mode != HostCompositeMode::Copy ||
                 rotation != HostRotation::Identity) &&
                filter == HostFilter::Linear)) {
            return false;
        }
        const auto source_descriptor = source.descriptor();
        const auto destination_descriptor = destination.descriptor();
        const auto valid = [](HostSurfaceDescriptor descriptor,
                               HostRectangle rectangle) {
            return rectangle.x >= 0 && rectangle.y >= 0 &&
                   rectangle.width != 0 && rectangle.height != 0 &&
                   rectangle.width <= descriptor.width &&
                   rectangle.height <= descriptor.height &&
                   static_cast<std::uint32_t>(rectangle.x) <=
                       descriptor.width - rectangle.width &&
                   static_cast<std::uint32_t>(rectangle.y) <=
                       descriptor.height - rectangle.height;
        };
        if (!valid(source_descriptor, source_rectangle) ||
            !valid(destination_descriptor, destination_rectangle) ||
            (clip && !valid(destination_descriptor, *clip))) {
            return false;
        }
        const auto right = [](HostRectangle rectangle) {
            return static_cast<std::int64_t>(rectangle.x) + rectangle.width;
        };
        const auto bottom = [](HostRectangle rectangle) {
            return static_cast<std::int64_t>(rectangle.y) + rectangle.height;
        };
        auto scissor_rectangle = clip.value_or(destination_rectangle);
        const auto scissor_left =
            std::max(scissor_rectangle.x, destination_rectangle.x);
        const auto scissor_top =
            std::max(scissor_rectangle.y, destination_rectangle.y);
        const auto scissor_right =
            std::min(right(scissor_rectangle), right(destination_rectangle));
        const auto scissor_bottom =
            std::min(bottom(scissor_rectangle), bottom(destination_rectangle));
        if (scissor_right <= scissor_left || scissor_bottom <= scissor_top) {
            return true;
        }
        scissor_rectangle = { scissor_left, scissor_top,
            static_cast<std::uint32_t>(scissor_right - scissor_left),
            static_cast<std::uint32_t>(scissor_bottom - scissor_top) };

        auto source_preparation = capture_surface_preparation(source);
        auto destination_preparation = capture_surface_preparation(destination);

        try {
            {
                std::lock_guard lock { mutex_ };
                auto& source_target =
                    prepare_host_surface(source, source_preparation.cpu_frame,
                        source_preparation.cpu_generation,
                        source_preparation.gpu_generation,
                        std::move(source_preparation.cpu_damage));
                auto& destination_target = prepare_host_surface(destination,
                    destination_preparation.cpu_frame,
                    destination_preparation.cpu_generation,
                    destination_preparation.gpu_generation,
                    std::move(destination_preparation.cpu_damage));
                if (!source_target.valid || !destination_target.valid)
                    return false;
                if (mode != HostCompositeMode::Copy ||
                    rotation != HostRotation::Identity ||
                    scissor_rectangle != destination_rectangle) {
                    if (command_slot().draw_count == maximum_batch_draws)
                        submit_commands(false, PerfSubmitReason::BatchCapacity);
                    wait_for_slot(command_slot());
                    constexpr auto vertex_count = 6U;
                    constexpr auto vertex_bytes =
                        vertex_count * sizeof(GpuVertex);
                    if (command_slot().vertex.buffer != VK_NULL_HANDLE &&
                        (vertex_bytes > command_slot().vertex.size ||
                            command_slot().vertex_bytes_used >
                                command_slot().vertex.size - vertex_bytes)) {
                        submit_commands(false, PerfSubmitReason::BatchCapacity);
                        wait_for_slot(command_slot());
                    }
                    ensure_buffer(command_slot().vertex,
                        minimum_vertex_arena_bytes,
                        VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
                    auto& commands = command_slot();
                    ensure_buffer(commands.uniform,
                        uniform_stride_ * maximum_batch_draws,
                        VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
                    const auto vertex_offset = commands.vertex_bytes_used;
                    const auto uniform_offset =
                        uniform_stride_ *
                        static_cast<VkDeviceSize>(commands.draw_count);
                    const auto u0 = static_cast<float>(source_rectangle.x) /
                                    static_cast<float>(source_descriptor.width);
                    const auto v0 =
                        static_cast<float>(source_rectangle.y) /
                        static_cast<float>(source_descriptor.height);
                    const auto u1 =
                        static_cast<float>(
                            source_rectangle.x +
                            static_cast<std::int32_t>(source_rectangle.width)) /
                        static_cast<float>(source_descriptor.width);
                    const auto v1 =
                        static_cast<float>(
                            source_rectangle.y + static_cast<std::int32_t>(
                                                     source_rectangle.height)) /
                        static_cast<float>(source_descriptor.height);
                    const auto alpha =
                        static_cast<float>(global_alpha) / 255.0F;
                    const auto crossfade =
                        mode == HostCompositeMode::ConstantAlphaCrossfade;
                    const auto rgb =
                        mode == HostCompositeMode::PremultipliedSourceOver
                            ? alpha
                            : 1.0F;
                    const std::array<float, 4> color { rgb, rgb, rgb,
                        mode == HostCompositeMode::Copy || crossfade ? 1.0F
                                                                     : alpha };
                    std::array<std::array<float, 2>, 4> texture { {
                        { u0, v0 },
                        { u1, v0 },
                        { u0, v1 },
                        { u1, v1 },
                    } };
                    if (rotation == HostRotation::Clockwise90) {
                        texture = { {
                            { u0, v1 },
                            { u0, v0 },
                            { u1, v1 },
                            { u1, v0 },
                        } };
                    } else if (rotation == HostRotation::Rotate180) {
                        texture = { {
                            { u1, v1 },
                            { u0, v1 },
                            { u1, v0 },
                            { u0, v0 },
                        } };
                    } else if (rotation == HostRotation::Clockwise270) {
                        texture = { {
                            { u1, v0 },
                            { u1, v1 },
                            { u0, v0 },
                            { u0, v1 },
                        } };
                    }
                    const std::array<GpuVertex, vertex_count> vertices {
                        GpuVertex { { -1.0F, 1.0F, 0.0F, 1.0F }, color,
                            texture[0], { } },
                        GpuVertex { { 1.0F, 1.0F, 0.0F, 1.0F }, color,
                            texture[1], { } },
                        GpuVertex { { -1.0F, -1.0F, 0.0F, 1.0F }, color,
                            texture[2], { } },
                        GpuVertex { { -1.0F, -1.0F, 0.0F, 1.0F }, color,
                            texture[2], { } },
                        GpuVertex { { 1.0F, 1.0F, 0.0F, 1.0F }, color,
                            texture[1], { } },
                        GpuVertex { { 1.0F, -1.0F, 0.0F, 1.0F }, color,
                            texture[3], { } }
                    };
                    GlesRasterState composite_state;
                    composite_state.texture_units[0].enabled = true;
                    composite_state.texture_units[0].environment.mode =
                        gles_abi::modulate;
                    const auto uniforms = fixed_function_state(composite_state);
                    upload(commands.vertex, vertices.data(), vertex_bytes,
                        vertex_offset);
                    upload(commands.uniform, &uniforms, sizeof(uniforms),
                        uniform_offset);

                    const auto descriptor =
                        commands.descriptors[commands.draw_count];
                    VkDescriptorBufferInfo uniform_info {
                        commands.uniform.buffer, uniform_offset,
                        sizeof(GpuFixedFunctionState)
                    };
                    const VkDescriptorImageInfo image_info {
                        source_target.image.sampler, source_target.image.view,
                        VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
                    };
                    std::array<VkWriteDescriptorSet, 1 + gles_abi::texture_unit_count> writes { };
                    writes[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
                    writes[0].dstSet = descriptor;
                    writes[0].dstBinding = 0;
                    writes[0].descriptorCount = 1;
                    writes[0].descriptorType =
                        VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
                    writes[0].pBufferInfo = &uniform_info;
                    for (std::uint32_t binding = 1; binding < writes.size();
                        ++binding) {
                        writes[binding].sType =
                            VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
                        writes[binding].dstSet = descriptor;
                        writes[binding].dstBinding = binding;
                        writes[binding].descriptorCount = 1;
                        writes[binding].descriptorType =
                            VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
                        writes[binding].pImageInfo = &image_info;
                    }
                    vkUpdateDescriptorSets(device_,
                        static_cast<std::uint32_t>(writes.size()),
                        writes.data(), 0, nullptr);

                    begin_commands();
                    end_render_pass();
                    if (source_target.layout !=
                        VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                        VkPipelineStageFlags source_stage =
                            VK_PIPELINE_STAGE_TRANSFER_BIT;
                        VkAccessFlags source_access =
                            source_target.layout ==
                                    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
                                ? VK_ACCESS_TRANSFER_READ_BIT
                                : VK_ACCESS_TRANSFER_WRITE_BIT;
                        if (source_target.layout ==
                            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                            source_stage =
                                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                            source_access =
                                VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
                        }
                        transition_image(commands.command,
                            source_target.image.image, source_target.layout,
                            VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                            source_stage, VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                            source_access, VK_ACCESS_SHADER_READ_BIT);
                        source_target.layout =
                            VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
                    }
                    if (destination_target.layout !=
                        VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                        VkPipelineStageFlags source_stage =
                            VK_PIPELINE_STAGE_TRANSFER_BIT;
                        VkAccessFlags source_access =
                            destination_target.layout ==
                                    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
                                ? VK_ACCESS_TRANSFER_READ_BIT
                                : VK_ACCESS_TRANSFER_WRITE_BIT;
                        if (destination_target.layout ==
                            VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                            source_stage =
                                VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
                            source_access = VK_ACCESS_SHADER_READ_BIT;
                        }
                        transition_image(commands.command,
                            destination_target.image.image,
                            destination_target.layout,
                            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                            source_stage,
                            VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                            source_access,
                            VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);
                        destination_target.layout =
                            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
                    }
                    auto render_begin =
                        make_vulkan_structure<VkRenderPassBeginInfo>(
                            VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
                    render_begin.renderPass = render_pass_;
                    render_begin.framebuffer = destination_target.framebuffer;
                    render_begin.renderArea.extent = {
                        destination_descriptor.width,
                        destination_descriptor.height
                    };
                    vkCmdBeginRenderPass(commands.command, &render_begin,
                        VK_SUBPASS_CONTENTS_INLINE);
                    render_pass_open_ = true;
                    render_pass_target_ = destination.key();
                    const auto selected_pipeline =
                        pipeline(PipelineKey { mode != HostCompositeMode::Copy,
                            mode == HostCompositeMode::Copy ? gles_abi::one
                            : crossfade ? constant_alpha_blend_factor
                            : mode == HostCompositeMode::PremultipliedSourceOver
                                ? gles_abi::one
                                : gles_abi::source_alpha,
                            mode == HostCompositeMode::Copy ? gles_abi::zero
                            : crossfade ? one_minus_constant_alpha_blend_factor
                                        : gles_abi::one_minus_source_alpha,
                            0x0fU });
                    vkCmdBindPipeline(commands.command,
                        VK_PIPELINE_BIND_POINT_GRAPHICS, selected_pipeline);
                    vkCmdBindVertexBuffers(commands.command, 0, 1,
                        &commands.vertex.buffer, &vertex_offset);
                    vkCmdBindDescriptorSets(commands.command,
                        VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout_, 0, 1,
                        &descriptor, 0, nullptr);
                    VkViewport viewport { };
                    viewport.x = static_cast<float>(destination_rectangle.x);
                    viewport.y = static_cast<float>(destination_rectangle.y);
                    viewport.width =
                        static_cast<float>(destination_rectangle.width);
                    viewport.height =
                        static_cast<float>(destination_rectangle.height);
                    viewport.minDepth = 0.0F;
                    viewport.maxDepth = 1.0F;
                    vkCmdSetViewport(commands.command, 0, 1, &viewport);
                    VkRect2D scissor { };
                    scissor.offset = { scissor_rectangle.x,
                        scissor_rectangle.y };
                    scissor.extent = { scissor_rectangle.width,
                        scissor_rectangle.height };
                    vkCmdSetScissor(commands.command, 0, 1, &scissor);
                    const std::array blend_constant { alpha, alpha, alpha,
                        alpha };
                    vkCmdSetBlendConstants(
                        commands.command, blend_constant.data());
                    vkCmdDraw(commands.command, vertex_count, 1, 0, 0);
                    ++commands.draw_count;
                    commands.vertex_bytes_used += vertex_bytes;
                } else {
                    begin_commands();
                    end_render_pass();
                    if (source_target.layout !=
                        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
                        VkPipelineStageFlags source_stage =
                            VK_PIPELINE_STAGE_TRANSFER_BIT;
                        VkAccessFlags source_access =
                            source_target.layout ==
                                    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
                                ? VK_ACCESS_TRANSFER_WRITE_BIT
                                : VK_ACCESS_TRANSFER_READ_BIT;
                        if (source_target.layout ==
                            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                            source_stage =
                                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                            source_access =
                                VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
                        } else if (source_target.layout ==
                                   VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                            source_stage =
                                VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
                            source_access = VK_ACCESS_SHADER_READ_BIT;
                        }
                        transition_image(command_slot().command,
                            source_target.image.image, source_target.layout,
                            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, source_stage,
                            VK_PIPELINE_STAGE_TRANSFER_BIT, source_access,
                            VK_ACCESS_TRANSFER_READ_BIT);
                        source_target.layout =
                            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
                    }
                    if (destination_target.layout !=
                        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
                        VkPipelineStageFlags source_stage =
                            VK_PIPELINE_STAGE_TRANSFER_BIT;
                        VkAccessFlags source_access =
                            destination_target.layout ==
                                    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
                                ? VK_ACCESS_TRANSFER_READ_BIT
                                : VK_ACCESS_TRANSFER_WRITE_BIT;
                        if (destination_target.layout ==
                            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                            source_stage =
                                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                            source_access =
                                VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
                        } else if (destination_target.layout ==
                                   VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                            source_stage =
                                VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
                            source_access = VK_ACCESS_SHADER_READ_BIT;
                        }
                        transition_image(command_slot().command,
                            destination_target.image.image,
                            destination_target.layout,
                            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, source_stage,
                            VK_PIPELINE_STAGE_TRANSFER_BIT, source_access,
                            VK_ACCESS_TRANSFER_WRITE_BIT);
                        destination_target.layout =
                            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
                    }

                    // Exact whole-resource copies remain the cheapest transfer.
                    // For partial copies, use a nearest blit: translated Vulkan
                    // drivers can otherwise expose source-image tiling
                    // artifacts when the resources have different extents.
                    const auto whole_resource_copy =
                        source_rectangle.x == 0 && source_rectangle.y == 0 &&
                        destination_rectangle.x == 0 &&
                        destination_rectangle.y == 0 &&
                        source_rectangle.width == source_descriptor.width &&
                        source_rectangle.height == source_descriptor.height &&
                        destination_rectangle.width ==
                            destination_descriptor.width &&
                        destination_rectangle.height ==
                            destination_descriptor.height &&
                        source_descriptor.width ==
                            destination_descriptor.width &&
                        source_descriptor.height ==
                            destination_descriptor.height;
                    if (whole_resource_copy) {
                        VkImageCopy copy { };
                        copy.srcSubresource.aspectMask =
                            VK_IMAGE_ASPECT_COLOR_BIT;
                        copy.srcSubresource.layerCount = 1;
                        copy.srcOffset = { source_rectangle.x,
                            source_rectangle.y, 0 };
                        copy.dstSubresource.aspectMask =
                            VK_IMAGE_ASPECT_COLOR_BIT;
                        copy.dstSubresource.layerCount = 1;
                        copy.dstOffset = { destination_rectangle.x,
                            destination_rectangle.y, 0 };
                        copy.extent = { source_rectangle.width,
                            source_rectangle.height, 1 };
                        vkCmdCopyImage(command_slot().command,
                            source_target.image.image,
                            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                            destination_target.image.image,
                            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copy);
                    } else {
                        VkImageBlit blit { };
                        blit.srcSubresource.aspectMask =
                            VK_IMAGE_ASPECT_COLOR_BIT;
                        blit.srcSubresource.layerCount = 1;
                        blit.srcOffsets[0] = { source_rectangle.x,
                            source_rectangle.y, 0 };
                        blit.srcOffsets[1] = { source_rectangle.x +
                                                   static_cast<std::int32_t>(
                                                       source_rectangle.width),
                            source_rectangle.y + static_cast<std::int32_t>(
                                                     source_rectangle.height),
                            1 };
                        blit.dstSubresource.aspectMask =
                            VK_IMAGE_ASPECT_COLOR_BIT;
                        blit.dstSubresource.layerCount = 1;
                        blit.dstOffsets[0] = { destination_rectangle.x,
                            destination_rectangle.y, 0 };
                        blit.dstOffsets[1] = {
                            destination_rectangle.x +
                                static_cast<std::int32_t>(
                                    destination_rectangle.width),
                            destination_rectangle.y +
                                static_cast<std::int32_t>(
                                    destination_rectangle.height),
                            1
                        };
                        vkCmdBlitImage(command_slot().command,
                            source_target.image.image,
                            VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                            destination_target.image.image,
                            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &blit,
                            filter == HostFilter::Linear ? VK_FILTER_LINEAR
                                                         : VK_FILTER_NEAREST);
                    }
                }
                add_damage(destination_target.dirty, scissor_rectangle);
            }
            source.mark_gpu_synchronized(source_preparation.cpu_generation);
            destination.mark_gpu_synchronized(
                destination_preparation.cpu_generation);
            static_cast<void>(destination.mark_gpu_write(scissor_rectangle));
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            std::lock_guard lock { mutex_ };
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return false;
        }
    }

    bool VulkanGlesRenderer::encode_copy_triangles(HostSurface& source,
        HostSurface& destination,
        std::span<const HostTexturedVertex> host_vertices,
        HostRectangle scissor, HostCompositeMode mode,
        std::uint8_t global_alpha, HostFilter filter)
    {
        if (source.key() == destination.key() ||
            filter != HostFilter::Nearest) {
            return false;
        }
        const auto source_descriptor = source.descriptor();
        const auto destination_descriptor = destination.descriptor();
        const auto valid_scissor =
            scissor.x >= 0 && scissor.y >= 0 && scissor.width != 0 &&
            scissor.height != 0 &&
            scissor.width <= destination_descriptor.width &&
            scissor.height <= destination_descriptor.height &&
            static_cast<std::uint32_t>(scissor.x) <=
                destination_descriptor.width - scissor.width &&
            static_cast<std::uint32_t>(scissor.y) <=
                destination_descriptor.height - scissor.height;
        const auto valid_positions = std::ranges::all_of(
            host_vertices, [](const HostTexturedVertex& vertex) {
                return std::isfinite(vertex.position.x) &&
                       std::isfinite(vertex.position.y);
            });
        const auto valid_texture = std::ranges::all_of(
            host_vertices, [](const HostTexturedVertex& vertex) {
                return std::isfinite(vertex.texture.x) &&
                       std::isfinite(vertex.texture.y);
            });
        if (!valid_scissor || !valid_positions || !valid_texture ||
            host_vertices.size() < 3 || host_vertices.size() % 3 != 0 ||
            source_descriptor.width == 0 || source_descriptor.height == 0 ||
            destination_descriptor.width == 0 ||
            destination_descriptor.height == 0) {
            return false;
        }

        const auto alpha = static_cast<float>(global_alpha) / 255.0F;
        const auto crossfade =
            mode == HostCompositeMode::ConstantAlphaCrossfade;
        const auto rgb =
            mode == HostCompositeMode::PremultipliedSourceOver ? alpha : 1.0F;
        const std::array<float, 4> color { rgb, rgb, rgb,
            mode == HostCompositeMode::Copy || crossfade ? 1.0F : alpha };
        std::vector<GpuVertex> vertices(host_vertices.size());
        for (std::size_t index = 0; index < vertices.size(); ++index) {
            vertices[index] = GpuVertex {
                { 2.0F * host_vertices[index].position.x /
                            static_cast<float>(destination_descriptor.width) -
                        1.0F,
                    1.0F -
                        2.0F * host_vertices[index].position.y /
                            static_cast<float>(destination_descriptor.height),
                    0.0F, 1.0F },
                color,
                { host_vertices[index].texture.x /
                        static_cast<float>(source_descriptor.width),
                    host_vertices[index].texture.y /
                        static_cast<float>(source_descriptor.height) },
                { }
            };
        }

        auto source_preparation = capture_surface_preparation(source);
        auto destination_preparation = capture_surface_preparation(destination);

        try {
            {
                std::lock_guard lock { mutex_ };
                auto& source_target =
                    prepare_host_surface(source, source_preparation.cpu_frame,
                        source_preparation.cpu_generation,
                        source_preparation.gpu_generation,
                        std::move(source_preparation.cpu_damage));
                auto& destination_target = prepare_host_surface(destination,
                    destination_preparation.cpu_frame,
                    destination_preparation.cpu_generation,
                    destination_preparation.gpu_generation,
                    std::move(destination_preparation.cpu_damage));
                if (!source_target.valid || !destination_target.valid ||
                    !draw_host_texture(source_target, destination_target,
                        destination.key(), destination_descriptor, vertices,
                        { 0, 0, destination_descriptor.width,
                            destination_descriptor.height },
                        scissor, mode, global_alpha)) {
                    return false;
                }
                add_damage(destination_target.dirty, scissor);
            }
            source.mark_gpu_synchronized(source_preparation.cpu_generation);
            destination.mark_gpu_synchronized(
                destination_preparation.cpu_generation);
            static_cast<void>(destination.mark_gpu_write(scissor));
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            std::lock_guard lock { mutex_ };
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return false;
        }
    }

    HostNativeImage VulkanGlesRenderer::native_image(
        const HostSurface& surface) const
    {
        const auto gpu_generation = surface.gpu_generation();
        std::lock_guard lock { mutex_ };
        const auto found = targets_.find(surface.key());
        if (found == targets_.end() || !found->second.valid)
            return { };
        return HostNativeImage { HostNativeImage::Api::Vulkan,
            reinterpret_cast<std::uintptr_t>(device_),
            reinterpret_cast<std::uintptr_t>(found->second.image.image),
            static_cast<std::uint32_t>(found->second.layout),
            surface.descriptor(), gpu_generation };
    }

    std::unique_ptr<CommandEncoder> VulkanGlesRenderer::create_command_encoder()
    {
        return std::make_unique<Encoder>(*this);
    }

    HostGraphicsDevice::PresentResult VulkanGlesRenderer::present(
        const std::shared_ptr<HostSurface>& surface)
    {
        if (!surface)
            return PresentResult::Failed;
        last_failure_reason_.store(
            PerfFallbackReason::None, std::memory_order_relaxed);
        const auto cpu_generation = surface->cpu_generation();
        const auto gpu_generation = surface->gpu_generation();
        DisplayFrame cpu_frame;
        if (cpu_generation >= gpu_generation) {
            auto mapping =
                surface->map_cpu(false, PerfCpuMapReason::NativePresent);
            cpu_frame = mapping.frame();
        }
        auto cpu_damage = cpu_generation > gpu_generation
                              ? surface->cpu_damage_rectangles()
                              : std::vector<HostRectangle> { };
        try {
            auto presented = PresentResult::Failed;
            {
                std::lock_guard lock { mutex_ };
                presentation_submissions_pending_.fetch_add(
                    1U, std::memory_order_release);
                struct PendingPresentationSubmission {
                    std::atomic<std::uint32_t>& count;
                    ~PendingPresentationSubmission()
                    {
                        count.fetch_sub(1U, std::memory_order_release);
                    }
                } pending_submission { presentation_submissions_pending_ };
                auto& target = prepare_host_surface(*surface, cpu_frame,
                    cpu_generation, gpu_generation, std::move(cpu_damage));
                if (!target.valid) {
                    // Preserve the submission guarantee published above even if
                    // this particular surface cannot be presented.
                    submit_commands(false, PerfSubmitReason::Presentation);
                    return PresentResult::Failed;
                }
                presented = present_target(target);
            }
            if (presented != PresentResult::Failed)
                surface->mark_gpu_synchronized(cpu_generation);
            return presented;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            std::lock_guard lock { mutex_ };
            static_cast<void>(vkDeviceWaitIdle(device_));
            discard_commands();
            return PresentResult::Failed;
        }
    }

    bool VulkanGlesRenderer::refresh_presentation_surface()
    {
        if (!presenter_.create_surface || instance_ == VK_NULL_HANDLE ||
            device_ == VK_NULL_HANDLE) {
            return false;
        }
        try {
            std::lock_guard lock { mutex_ };
            return recreate_presentation_surface();
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            return false;
        }
    }

    bool VulkanGlesRenderer::release_presentation_surface()
    {
        std::lock_guard lock { mutex_ };
        if (device_ != VK_NULL_HANDLE &&
            vkDeviceWaitIdle(device_) != VK_SUCCESS) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
        }
        destroy_presentation_swapchain();
        if (presentation_surface_ != VK_NULL_HANDLE &&
            instance_ != VK_NULL_HANDLE) {
            vkDestroySurfaceKHR(instance_, presentation_surface_, nullptr);
        }
        presentation_surface_ = VK_NULL_HANDLE;
        return true;
    }

    bool VulkanGlesRenderer::draw(DisplayFrame& frame,
        GlesRenderTargetKey target, std::span<const GlesRasterVertex> vertices,
        std::uint32_t mode, const GlesRasterState& state)
    {
        // CPU readback takes HostSurface before the renderer mutex.  Resolve
        // the inverse dependency here before serializing Vulkan state so
        // texture selection cannot deadlock a concurrent readback.
        std::optional<SurfacePreparation> target_surface_preparation;
        if (frame.host_surface && frame.host_surface->key() == target) {
            target_surface_preparation =
                capture_surface_preparation(*frame.host_surface);
        }
        std::array<std::shared_ptr<HostSurface>, gles_abi::texture_unit_count>
            gpu_newer_host_surfaces { };
        for (std::size_t index = 0; index < gpu_newer_host_surfaces.size();
            ++index) {
            const auto& unit = state.texture_units[index];
            if (!unit.enabled || unit.texture == 0 ||
                state.resources == nullptr)
                continue;
            const auto* texture = state.resources->texture(unit.texture);
            if (!texture)
                continue;
            const auto level = texture->levels.find(0);
            if (level == texture->levels.end() || !level->second.host_surface ||
                level->second.host_surface->key() == target) {
                continue;
            }
            const auto& surface = *level->second.host_surface;
            if (surface.gpu_generation() > surface.cpu_generation())
                gpu_newer_host_surfaces[index] = level->second.host_surface;
        }
        std::lock_guard lock { mutex_ };
        last_failure_reason_.store(
            PerfFallbackReason::None, std::memory_order_relaxed);
        const auto cpu_frame_valid =
            frame.pixels.size() ==
            static_cast<std::size_t>(frame.width) * frame.height;
        if (frame.width == 0 || frame.height == 0 ||
            (!target_surface_preparation && !cpu_frame_valid) ||
            state.viewport_width == 0 || state.viewport_height == 0) {
            last_failure_reason_.store(
                PerfFallbackReason::InvalidTarget, std::memory_order_relaxed);
            return false;
        }
        if (!GlesPrimitiveAssembler::supports(mode)) {
            last_failure_reason_.store(PerfFallbackReason::UnsupportedPrimitive,
                std::memory_order_relaxed);
            return false;
        }
        if (std::any_of(vertices.begin(), vertices.end(),
                [](const GlesRasterVertex& vertex) {
                    return vertex.position[3] == 0.0F;
                })) {
            last_failure_reason_.store(
                PerfFallbackReason::InvalidVertex, std::memory_order_relaxed);
            return false;
        }
        const auto primitive =
            GlesPrimitiveAssembler::assemble(vertices, mode, state);
        if (!primitive) {
            last_failure_reason_.store(
                PerfFallbackReason::InvalidVertex, std::memory_order_relaxed);
            return false;
        }
        const auto primitive_vertices = primitive->vertices();
        if (primitive_vertices.empty())
            return true;
        auto primitive_state = state;
        if (primitive->ignores_culling())
            primitive_state.cull_enabled = false;
        if (state.blend_enabled &&
            (!blend_factor(state.blend_source) ||
                !blend_factor(state.blend_destination))) {
            last_failure_reason_.store(PerfFallbackReason::UnsupportedBlend,
                std::memory_order_relaxed);
            return false;
        }

        std::int64_t scissor_left = 0;
        std::int64_t scissor_bottom = 0;
        std::int64_t scissor_right = frame.width;
        std::int64_t scissor_top = frame.height;
        if (state.scissor_enabled) {
            const auto requested_left =
                static_cast<std::int64_t>(state.scissor_box[0]);
            const auto requested_bottom =
                static_cast<std::int64_t>(state.scissor_box[1]);
            const auto requested_right =
                requested_left +
                std::max<std::int64_t>(0, state.scissor_box[2]);
            const auto requested_top =
                requested_bottom +
                std::max<std::int64_t>(0, state.scissor_box[3]);
            scissor_left =
                std::clamp<std::int64_t>(requested_left, 0, frame.width);
            scissor_bottom =
                std::clamp<std::int64_t>(requested_bottom, 0, frame.height);
            scissor_right =
                std::clamp<std::int64_t>(requested_right, 0, frame.width);
            scissor_top =
                std::clamp<std::int64_t>(requested_top, 0, frame.height);
            if (scissor_right <= scissor_left ||
                scissor_top <= scissor_bottom) {
                return true;
            }
        }

        auto expanded = expand_vertices(
            primitive_vertices, primitive->mode(), primitive_state);
        if (expanded.empty())
            return true;
        PipelineKey pipeline_key;
        pipeline_key.blend_enabled = state.blend_enabled;
        pipeline_key.blend_source = state.blend_source;
        pipeline_key.blend_destination = state.blend_destination;
        for (std::size_t component = 0; component < state.color_mask.size();
            ++component) {
            if (state.color_mask[component]) {
                pipeline_key.color_mask |=
                    static_cast<std::uint8_t>(1U << component);
            }
        }
        try {
            const auto selected_pipeline = pipeline(pipeline_key);
            if (selected_pipeline == VK_NULL_HANDLE) {
                last_failure_reason_.store(
                    PerfFallbackReason::PipelineUnavailable,
                    std::memory_order_relaxed);
                return false;
            }

            const auto frame_bytes =
                static_cast<VkDeviceSize>(frame.width) * frame.height *
                sizeof(std::uint32_t);
            const auto vertex_bytes =
                static_cast<VkDeviceSize>(expanded.size()) * sizeof(GpuVertex);
            auto& gpu_target = target_surface_preparation
                                   ? prepare_host_surface(*frame.host_surface,
                                         target_surface_preparation->cpu_frame,
                                         target_surface_preparation
                                             ->cpu_generation,
                                         target_surface_preparation
                                             ->gpu_generation,
                                         std::move(target_surface_preparation
                                                       ->cpu_damage))
                                   : ensure_target(
                                         target, frame.width, frame.height);
            if (target_surface_preparation && !gpu_target.valid) {
                last_failure_reason_.store(
                    PerfFallbackReason::InvalidTarget,
                    std::memory_order_relaxed);
                return false;
            }

            const auto texture_cache_over_budget = [&] {
                return texture_cache_bytes_ > texture_cache_budget_bytes_ ||
                       texture_cache_.size() > maximum_texture_cache_entries;
            };
            if (texture_cache_over_budget() && command_recording_) {
                submit_commands(false, PerfSubmitReason::TextureHazard);
            }
            if (texture_cache_over_budget()) {
                wait_for_all_slots();
            }
            while (texture_cache_over_budget()) {
                const auto oldest = std::min_element(texture_cache_.begin(),
                    texture_cache_.end(),
                    [](const auto& left, const auto& right) {
                        return left.second.last_used < right.second.last_used;
                    });
                if (oldest == texture_cache_.end())
                    break;
                texture_cache_bytes_ -= std::min(
                    texture_cache_bytes_, oldest->second.image.allocation_size);
                texture_cache_.erase(oldest);
            }

            constexpr std::array<std::uint32_t, 1> white_pixel { 0xffffffffU };
            std::array<bool, gles_abi::texture_unit_count> texture_changed { };
            std::array<CachedTexture*, gles_abi::texture_unit_count>
                selected_textures { };
            std::array<Target*, gles_abi::texture_unit_count>
                selected_surface_targets { };
            std::array<VkDeviceSize, gles_abi::texture_unit_count>
                selected_upload_offsets { };
            std::array<const std::uint32_t*, gles_abi::texture_unit_count>
                selected_pixels { };
            std::array<VkDeviceSize, gles_abi::texture_unit_count>
                selected_byte_counts { };
            std::array<std::uint64_t, gles_abi::texture_unit_count>
                texture_revisions { };
            for (std::size_t index = 0; index < selected_textures.size();
                ++index) {
                const auto& unit = state.texture_units[index];
                const GlesResourceStore::TextureLevel* level { };
                if (unit.enabled && unit.texture != 0 &&
                    state.resources != nullptr) {
                    if (const auto* texture =
                            state.resources->texture(unit.texture)) {
                        const auto found = texture->levels.find(0);
                        if (found != texture->levels.end() &&
                            found->second.width != 0 &&
                            found->second.height != 0 &&
                            (found->second.host_surface != nullptr ||
                                found->second.argb.size() ==
                                    static_cast<std::size_t>(
                                        found->second.width) *
                                        found->second.height)) {
                            level = &found->second;
                        }
                    }
                }
                const auto width = level ? level->width : 1U;
                const auto height = level ? level->height : 1U;
                if (level && level->host_surface &&
                    level->host_surface->key() != target &&
                    gpu_newer_host_surfaces[index] == level->host_surface) {
                    const auto native =
                        targets_.find(level->host_surface->key());
                    if (native != targets_.end() && native->second.valid &&
                        native->second.image.width == width &&
                        native->second.image.height == height) {
                        selected_surface_targets[index] = &native->second;
                        texture_revisions[index] = level->host_generation;
                        continue;
                    }
                }
                if (level && level->argb.size() !=
                                 static_cast<std::size_t>(width) * height) {
                    last_failure_reason_.store(PerfFallbackReason::TargetBusy,
                        std::memory_order_relaxed);
                    return false;
                }
                const auto* pixels =
                    level ? level->argb.data() : white_pixel.data();
                const auto byte_count = static_cast<VkDeviceSize>(width) *
                                        height * sizeof(std::uint32_t);
                TextureKey key;
                key.owner = level ? state.resource_owner : 0;
                key.rectangle = unit.rectangle;
                if (level && level->host_surface) {
                    // CoreSurface is the pixel resource. GLES texture names are
                    // transient views and older firmware routinely deletes and
                    // recreates those names while retaining the same surface.
                    key.surface = level->host_surface->key();
                    key.uses_surface = true;
                } else {
                    key.name = level ? unit.texture : 0;
                }
                auto& cached = texture_cache_[key];
                cached.last_used = ++texture_use_sequence_;
                if (cached.image.image == VK_NULL_HANDLE ||
                    cached.image.width != width ||
                    cached.image.height != height) {
                    if (cached.image.image != VK_NULL_HANDLE) {
                        submit_commands(
                            false, PerfSubmitReason::ResourceLifetime);
                        wait_for_all_slots();
                    }
                    auto replacement = create_image(width, height,
                        VK_IMAGE_USAGE_TRANSFER_DST_BIT |
                            VK_IMAGE_USAGE_SAMPLED_BIT,
                        true, unit.rectangle);
                    texture_cache_bytes_ -= std::min(
                        texture_cache_bytes_, cached.image.allocation_size);
                    texture_cache_bytes_ += replacement.allocation_size;
                    cached.image = std::move(replacement);
                    cached.revision = 0;
                }
                selected_textures[index] = &cached;
                selected_pixels[index] = pixels;
                selected_byte_counts[index] = byte_count;
                texture_revisions[index] = level ? level->revision : 1;
                texture_changed[index] =
                    cached.revision != texture_revisions[index];
                if (texture_changed[index] &&
                    cached.last_upload_batch == batch_sequence_) {
                    submit_commands(false, PerfSubmitReason::TextureHazard);
                }
                for (std::size_t previous = 0; previous < index; ++previous) {
                    if (selected_textures[previous] == &cached) {
                        texture_changed[index] = false;
                        break;
                    }
                }
            }

            if (texture_cache_over_budget()) {
                if (command_recording_)
                    submit_commands(false, PerfSubmitReason::TextureHazard);
                wait_for_all_slots();
                while (texture_cache_over_budget()) {
                    auto oldest = texture_cache_.end();
                    for (auto candidate = texture_cache_.begin();
                        candidate != texture_cache_.end(); ++candidate) {
                        const auto selected =
                            std::find(selected_textures.begin(),
                                selected_textures.end(), &candidate->second);
                        if (selected != selected_textures.end())
                            continue;
                        if (oldest == texture_cache_.end() ||
                            candidate->second.last_used <
                                oldest->second.last_used) {
                            oldest = candidate;
                        }
                    }
                    // Textures needed by this draw are allowed to exceed the
                    // budget temporarily; there is no correct eviction
                    // candidate.
                    if (oldest == texture_cache_.end())
                        break;
                    texture_cache_bytes_ -= std::min(texture_cache_bytes_,
                        oldest->second.image.allocation_size);
                    texture_cache_.erase(oldest);
                }
            }

            if (command_slot().draw_count == maximum_batch_draws) {
                submit_commands(false, PerfSubmitReason::BatchCapacity);
            }
            wait_for_slot(command_slot());
            if (command_slot().vertex.buffer != VK_NULL_HANDLE &&
                (vertex_bytes > command_slot().vertex.size ||
                    command_slot().vertex_bytes_used >
                        command_slot().vertex.size - vertex_bytes)) {
                submit_commands(false, PerfSubmitReason::BatchCapacity);
                wait_for_slot(command_slot());
            }
            const auto align_staging = [](VkDeviceSize value) {
                return (value + staging_alignment - 1U) &
                       ~(staging_alignment - 1U);
            };
            auto staging_end = command_slot().staging_bytes_used;
            if (!gpu_target.valid)
                staging_end = align_staging(staging_end) + frame_bytes;
            for (std::size_t index = 0; index < selected_textures.size();
                ++index) {
                if (texture_changed[index]) {
                    staging_end = align_staging(staging_end) +
                                  selected_byte_counts[index];
                }
            }
            if (command_slot().staging.buffer != VK_NULL_HANDLE &&
                staging_end > command_slot().staging.size) {
                if (command_recording_)
                    submit_commands(false, PerfSubmitReason::StagingCapacity);
                wait_for_slot(command_slot());
                staging_end = 0;
                if (!gpu_target.valid)
                    staging_end = frame_bytes;
                for (std::size_t index = 0; index < selected_textures.size();
                    ++index) {
                    if (texture_changed[index]) {
                        staging_end = align_staging(staging_end) +
                                      selected_byte_counts[index];
                    }
                }
            }
            ensure_buffer(command_slot().staging,
                std::max(staging_end, minimum_staging_arena_bytes),
                VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
            // The staging-capacity check may submit the current batch and
            // rotate to another command slot. Allocate per-slot draw buffers
            // only after that final rotation decision.
            ensure_buffer(command_slot().vertex,
                std::max(vertex_bytes, minimum_vertex_arena_bytes),
                VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
            auto& commands = command_slot();
            ensure_buffer(commands.uniform,
                uniform_stride_ * maximum_batch_draws,
                VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
            const auto vertex_offset = commands.vertex_bytes_used;
            const auto uniform_offset =
                uniform_stride_ *
                static_cast<VkDeviceSize>(commands.draw_count);
            upload(commands.vertex, expanded.data(),
                static_cast<std::size_t>(vertex_bytes), vertex_offset);
            const auto uniforms = fixed_function_state(state);
            upload(
                commands.uniform, &uniforms, sizeof(uniforms), uniform_offset);
            VkDeviceSize target_upload_offset { };
            if (!gpu_target.valid) {
                target_upload_offset =
                    align_staging(commands.staging_bytes_used);
                upload(commands.staging, frame.pixels.data(),
                    static_cast<std::size_t>(frame_bytes), target_upload_offset,
                    gpu_target.kind);
                commands.staging_bytes_used =
                    target_upload_offset + frame_bytes;
            }
            for (std::size_t index = 0; index < selected_textures.size();
                ++index) {
                if (!texture_changed[index])
                    continue;
                const auto byte_count = selected_byte_counts[index];
                const auto offset = align_staging(commands.staging_bytes_used);
                upload(commands.staging, selected_pixels[index],
                    static_cast<std::size_t>(byte_count), offset);
                commands.staging_bytes_used = offset + byte_count;
                selected_upload_offsets[index] = offset;
            }

            const auto descriptor = commands.descriptors[commands.draw_count];
            VkDescriptorBufferInfo uniform_info { commands.uniform.buffer,
                uniform_offset, sizeof(GpuFixedFunctionState) };
            std::array<VkDescriptorImageInfo, gles_abi::texture_unit_count>
                image_infos { };
            for (std::size_t index = 0; index < image_infos.size(); ++index) {
                const auto& image = selected_surface_targets[index]
                                        ? selected_surface_targets[index]->image
                                        : selected_textures[index]->image;
                auto sampler = image.sampler;
                const auto& unit = state.texture_units[index];
                if (unit.enabled && state.resources) {
                    if (const auto* texture =
                            state.resources->texture(unit.texture)) {
                        sampler =
                            texture_sampler(GlesSamplerState::from_parameters(
                                texture->parameters, unit.rectangle));
                    }
                }
                image_infos[index] = { sampler, image.view,
                    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL };
            }
            std::array<VkWriteDescriptorSet, 1 + gles_abi::texture_unit_count> writes { };
            writes[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writes[0].dstSet = descriptor;
            writes[0].dstBinding = 0;
            writes[0].descriptorCount = 1;
            writes[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            writes[0].pBufferInfo = &uniform_info;
            for (std::uint32_t index = 0; index < image_infos.size(); ++index) {
                auto& write = writes[index + 1U];
                write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
                write.dstSet = descriptor;
                write.dstBinding = index + 1U;
                write.descriptorCount = 1;
                write.descriptorType =
                    VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
                write.pImageInfo = &image_infos[index];
            }
            vkUpdateDescriptorSets(device_,
                static_cast<std::uint32_t>(writes.size()), writes.data(), 0,
                nullptr);

            begin_commands();
            if (render_pass_open_ && render_pass_target_ != target)
                end_render_pass();
            if (!gpu_target.valid ||
                gpu_target.layout != VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL ||
                std::any_of(texture_changed.begin(), texture_changed.end(),
                    [](bool changed) { return changed; }) ||
                std::any_of(selected_surface_targets.begin(),
                    selected_surface_targets.end(), [](const Target* source) {
                        return source != nullptr &&
                               source->layout !=
                                   VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
                    })) {
                end_render_pass();
            }
            if (!gpu_target.valid) {
                auto source_stage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
                VkAccessFlags source_access { };
                if (gpu_target.layout == VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
                    source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
                    source_access = VK_ACCESS_TRANSFER_READ_BIT;
                } else if (gpu_target.layout ==
                           VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                    source_stage =
                        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                    source_access = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
                }
                transition_image(commands.command, gpu_target.image.image,
                    gpu_target.layout, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    source_stage, VK_PIPELINE_STAGE_TRANSFER_BIT, source_access,
                    VK_ACCESS_TRANSFER_WRITE_BIT);
                VkBufferImageCopy target_copy { };
                target_copy.bufferOffset = target_upload_offset;
                target_copy.imageSubresource.aspectMask =
                    VK_IMAGE_ASPECT_COLOR_BIT;
                target_copy.imageSubresource.layerCount = 1;
                target_copy.imageExtent = { frame.width, frame.height, 1 };
                vkCmdCopyBufferToImage(commands.command,
                    commands.staging.buffer, gpu_target.image.image,
                    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &target_copy);
                transition_image(commands.command, gpu_target.image.image,
                    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    VK_PIPELINE_STAGE_TRANSFER_BIT,
                    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    VK_ACCESS_TRANSFER_WRITE_BIT,
                    VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                        VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);
                gpu_target.valid = true;
                gpu_target.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            } else if (gpu_target.layout !=
                       VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                transition_image(commands.command, gpu_target.image.image,
                    gpu_target.layout, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    VK_PIPELINE_STAGE_TRANSFER_BIT,
                    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    VK_ACCESS_TRANSFER_READ_BIT,
                    VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                        VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);
                gpu_target.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            }
            for (auto* source : selected_surface_targets) {
                if (source == nullptr ||
                    source->layout ==
                        VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
                    continue;
                }
                VkPipelineStageFlags source_stage =
                    VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
                VkAccessFlags source_access { };
                if (source->layout ==
                    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL) {
                    source_stage =
                        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                    source_access = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                    VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
                } else if (source->layout ==
                           VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
                    source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
                    source_access = VK_ACCESS_TRANSFER_WRITE_BIT;
                } else if (source->layout ==
                           VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL) {
                    source_stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
                    source_access = VK_ACCESS_TRANSFER_READ_BIT;
                }
                transition_image(commands.command, source->image.image,
                    source->layout, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    source_stage, VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                    source_access, VK_ACCESS_SHADER_READ_BIT);
                source->layout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            }
            for (std::size_t index = 0; index < selected_textures.size();
                ++index) {
                if (!texture_changed[index])
                    continue;
                auto& texture = *selected_textures[index];
                auto& image = texture.image;
                transition_image(commands.command, image.image,
                    texture.revision != 0
                        ? VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
                        : VK_IMAGE_LAYOUT_UNDEFINED,
                    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    texture.revision != 0
                        ? VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
                        : VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                    VK_PIPELINE_STAGE_TRANSFER_BIT,
                    texture.revision != 0 ? VK_ACCESS_SHADER_READ_BIT : 0,
                    VK_ACCESS_TRANSFER_WRITE_BIT);
                VkBufferImageCopy copy { };
                copy.bufferOffset = selected_upload_offsets[index];
                copy.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
                copy.imageSubresource.layerCount = 1;
                copy.imageExtent = { image.width, image.height, 1 };
                vkCmdCopyBufferToImage(commands.command,
                    commands.staging.buffer, image.image,
                    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copy);
                transition_image(commands.command, image.image,
                    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    VK_PIPELINE_STAGE_TRANSFER_BIT,
                    VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                    VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_SHADER_READ_BIT);
                texture.revision = texture_revisions[index];
                texture.last_upload_batch = batch_sequence_;
            }

            auto render_begin = make_vulkan_structure<VkRenderPassBeginInfo>(
                VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
            render_begin.renderPass = render_pass_;
            render_begin.framebuffer = gpu_target.framebuffer;
            render_begin.renderArea.extent = { frame.width, frame.height };
            if (!render_pass_open_) {
                vkCmdBeginRenderPass(commands.command, &render_begin,
                    VK_SUBPASS_CONTENTS_INLINE);
                render_pass_open_ = true;
                render_pass_target_ = target;
            }
            vkCmdBindPipeline(commands.command, VK_PIPELINE_BIND_POINT_GRAPHICS,
                selected_pipeline);
            vkCmdBindVertexBuffers(commands.command, 0, 1,
                &commands.vertex.buffer, &vertex_offset);
            vkCmdBindDescriptorSets(commands.command,
                VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout_, 0, 1,
                &descriptor, 0, nullptr);
            VkViewport viewport { };
            viewport.x = static_cast<float>(state.viewport_x);
            viewport.y = state.render_target_inverted_vertical
                             ? static_cast<float>(state.viewport_y)
                             : static_cast<float>(frame.height) -
                                   static_cast<float>(state.viewport_y) -
                                   static_cast<float>(state.viewport_height);
            viewport.width = static_cast<float>(state.viewport_width);
            viewport.height = static_cast<float>(state.viewport_height);
            viewport.minDepth = 0.0F;
            viewport.maxDepth = 1.0F;
            vkCmdSetViewport(commands.command, 0, 1, &viewport);
            VkRect2D scissor { };
            scissor.offset.x = static_cast<std::int32_t>(scissor_left);
            scissor.offset.y = static_cast<std::int32_t>(
                state.render_target_inverted_vertical
                    ? scissor_bottom
                    : static_cast<std::int64_t>(frame.height) - scissor_top);
            scissor.extent.width =
                static_cast<std::uint32_t>(scissor_right - scissor_left);
            scissor.extent.height =
                static_cast<std::uint32_t>(scissor_top - scissor_bottom);
            vkCmdSetScissor(commands.command, 0, 1, &scissor);
            vkCmdSetBlendConstants(
                commands.command, state.blend_constant.data());
            vkCmdDraw(commands.command,
                static_cast<std::uint32_t>(expanded.size()), 1, 0, 0);
            add_damage(gpu_target.dirty,
                HostRectangle { static_cast<std::int32_t>(scissor_left),
                    static_cast<std::int32_t>(
                        state.render_target_inverted_vertical
                            ? scissor_bottom
                            : static_cast<std::int64_t>(frame.height) -
                                  scissor_top),
                    static_cast<std::uint32_t>(scissor_right - scissor_left),
                    static_cast<std::uint32_t>(scissor_top - scissor_bottom) });
            gpu_target.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            for (auto* texture : selected_textures) {
                if (texture != nullptr)
                    texture->last_draw_batch = batch_sequence_;
            }
            ++commands.draw_count;
            commands.vertex_bytes_used += vertex_bytes;
            return true;
        } catch (...) {
            last_failure_reason_.store(
                PerfFallbackReason::BackendFailure, std::memory_order_relaxed);
            vkDeviceWaitIdle(device_);
            discard_commands();
            if (const auto found = targets_.find(target);
                found != targets_.end()) {
                found->second.valid = false;
                found->second.dirty.reset();
            }
            return false;
        }
    }

} // namespace

std::unique_ptr<GlesRenderer> create_vulkan_gles_renderer(
    const std::filesystem::path& pipeline_cache,
    const VulkanPresenterConfiguration* presenter,
    GlesDeviceSelection selection,
    std::string* failure) noexcept
{
    try {
        auto renderer =
            std::make_unique<VulkanGlesRenderer>(pipeline_cache, presenter, selection);
        std::clog << "[gles-renderer] selected " << renderer->name() << "\n";
        return renderer;
    } catch (const std::exception& error) {
        if (failure != nullptr)
            *failure = error.what();
        std::clog << "[gles-renderer] Vulkan unavailable: " << error.what()
                  << "\n";
        return { };
    } catch (...) {
        if (failure != nullptr)
            *failure = "unknown error";
        std::clog << "[gles-renderer] Vulkan unavailable: unknown error\n";
        return { };
    }
}

} // namespace shade
