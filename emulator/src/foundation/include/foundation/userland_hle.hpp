// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Register and dispatch guest userland call adapters with access to
// native fallback paths.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <string_view>
#include <tuple>
#include <utility>
#include <vector>

#include "foundation/arm_cpu_model.hpp"
#include "foundation/content_identity.hpp"

namespace shade {

class AddressSpace;
class Cpu;
class DyldSharedCache;
class ImmutableArtifactView;
class MachOImage;
class Output;

inline constexpr std::uint32_t userland_hle_svc_namespace = 0x00fa0000U;
inline constexpr std::uint32_t userland_hle_svc_namespace_mask = 0x00ff0000U;
inline constexpr std::uint32_t userland_hle_call_mask = 0x0000ffffU;
inline constexpr std::uint32_t userland_hle_thumb_svc = 0x000000faU;

class UserlandHleRegistry;

class UserlandHleCall {
public:
    using Continuation = std::function<void(UserlandHleCall&)>;

    [[nodiscard]] std::uint32_t argument(std::size_t index) const;
    [[nodiscard]] std::optional<std::uint32_t> prefix_argument(
        std::size_t index) const;
    [[nodiscard]] std::vector<std::string> installed_functions(
        std::string_view prefix) const;
    [[nodiscard]] std::optional<std::vector<std::byte>> original_function_code(
        std::string_view symbol, std::size_t size) const;
    [[nodiscard]] std::optional<std::uint32_t> callable_alias(
        std::string_view symbol, std::uint8_t prefix_arguments);
    [[nodiscard]] std::optional<std::uint32_t> callable_handler(
        std::string_view image_suffix, std::string_view symbol,
        std::uint8_t prefix_arguments);
    [[nodiscard]] std::optional<std::string> string_argument(
        std::size_t index, std::size_t maximum_size = 4096) const;
    [[nodiscard]] std::optional<std::string> objc_string_argument(
        std::size_t index, std::size_t maximum_size = 4096) const;
    [[nodiscard]] bool write32(std::uint32_t address, std::uint32_t value);
    [[nodiscard]] std::uint32_t intern_string(std::string_view value);
    [[nodiscard]] std::uint32_t allocate_data(
        std::size_t size, std::size_t alignment = alignof(std::max_align_t));
    [[nodiscard]] std::optional<std::uint32_t> symbol_address(
        std::string_view symbol) const;
    [[nodiscard]] bool image_loaded(std::string_view image_suffix) const;
    [[nodiscard]] bool image_loaded_beneath(std::string_view directory) const;
    void set_return(std::uint32_t value);
    [[nodiscard]] bool tail_call_registered(std::string_view symbol);
    [[nodiscard]] bool call_guest_function(
        std::string_view symbol, Continuation continuation);
    [[nodiscard]] bool defer_guest_function(std::string_view symbol,
        Continuation setup, Continuation completion = { });
    [[nodiscard]] bool continue_deferred_guest_function(std::string_view symbol,
        Continuation setup, Continuation completion = { });
    void resume_original();
    void resume_original_persistently();
    void resume_original_persistently(Continuation continuation);

    [[nodiscard]] Cpu& cpu() const { return cpu_; }
    [[nodiscard]] AddressSpace& memory() const { return memory_; }
    [[nodiscard]] Output& output() const { return output_; }
    [[nodiscard]] std::uint32_t process_id() const { return process_id_; }
    [[nodiscard]] std::string_view symbol() const { return symbol_; }

private:
    friend class UserlandHleRegistry;
    UserlandHleCall(UserlandHleRegistry& registry, Cpu& cpu,
        AddressSpace& memory, Output& output, std::uint32_t process_id,
        std::string_view symbol, std::uint8_t prefix_arguments = 0U);
    [[nodiscard]] std::optional<std::uint32_t> callable_entry(
        std::uint16_t id, std::string_view symbol,
        std::uint8_t prefix_arguments);

    UserlandHleRegistry& registry_;
    Cpu& cpu_;
    AddressSpace& memory_;
    Output& output_;
    std::uint32_t process_id_ { };
    std::string_view symbol_;
    std::array<std::uint32_t, 4> prefix_arguments_ { };
    std::uint8_t prefix_argument_count_ { };
    bool resume_original_ { };
    bool resume_original_persistently_ { };
    std::optional<std::uint32_t> tail_call_address_;
    Continuation original_continuation_;
};

class UserlandHleRegistry {
public:
    using Handler = std::function<void(UserlandHleCall&)>;

    UserlandHleRegistry(AddressSpace& memory, Output& output);

    void register_function(
        std::string image_suffix, std::string symbol, Handler handler);
    void register_prefix(
        std::string image_suffix, std::string symbol_prefix, Handler handler);
    void register_guest_function(std::string image_suffix, std::string symbol);
    void register_guest_data_symbol(
        std::string image_suffix, std::string symbol);
    [[nodiscard]] bool queue_guest_function(std::string_view symbol,
        std::size_t processor, Handler setup, Handler completion = { });
    void register_objc_instance_method(std::string image_suffix,
        std::string class_name, std::string selector,
        std::string diagnostic_name, Handler handler);
    void register_objc_class_method(std::string image_suffix,
        std::string class_name, std::string selector,
        std::string diagnostic_name, Handler handler);
    void register_address(std::string image_suffix,
        std::uint32_t virtual_address, std::string diagnostic_name,
        Handler handler);

    [[nodiscard]] bool needs_image_metadata(std::string_view image_path) const;
    [[nodiscard]] bool needs_data_symbol_mapping(
        std::string_view image_path) const;

    void prepare_shared_cache_plan(const DyldSharedCache& cache,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K);

    [[nodiscard]] std::size_t install_mapped_image(Cpu& cpu,
        std::uint32_t process_id, const std::filesystem::path& image_path,
        std::uint32_t mapping_address, std::uint32_t mapping_size,
        std::uint64_t file_offset,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K);

    [[nodiscard]] std::size_t install_mapped_shared_cache_image(Cpu& cpu,
        std::uint32_t process_id, std::string_view image_path,
        const std::filesystem::path& cache_path,
        std::uint64_t image_header_offset, std::uint32_t mapping_address,
        std::uint32_t mapping_size, std::uint64_t file_offset,
        const ContentIdentity& cache_identity,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K,
        std::shared_ptr<const MachOImage> parsed_image = { },
        std::optional<std::uint32_t> cache_file_index = { },
        std::optional<std::uint32_t> cache_image_index = { });

    [[nodiscard]] std::size_t resolve_mapped_shared_cache_data_symbols(
        const std::filesystem::path& cache_path, std::uint32_t mapping_address,
        std::uint32_t mapping_size, std::uint64_t file_offset);

    [[nodiscard]] bool dispatch(
        Cpu& cpu, std::uint32_t process_id, std::uint32_t svc_immediate);

    [[nodiscard]] std::uint32_t intern_string(std::string_view value);
    [[nodiscard]] std::uint32_t allocate_data(
        std::size_t size, std::size_t alignment = alignof(std::max_align_t));
    [[nodiscard]] std::optional<std::uint32_t> symbol_address(
        std::string_view symbol) const;
    [[nodiscard]] bool image_loaded(std::string_view image_suffix) const;
    [[nodiscard]] bool image_loaded_beneath(std::string_view directory) const;
    void record_loaded_image(std::string image_path);

    [[nodiscard]] std::optional<std::uint32_t> prepare_thread_callback_return(
        Cpu& cpu);
    [[nodiscard]] std::optional<std::uint32_t> prepare_one_shot_return(
        Cpu& cpu, std::uint32_t return_address, Handler completion);
    [[nodiscard]] bool bind_thread_callback(
        std::size_t processor, Handler completion);
    void unbind_thread_callback(std::size_t processor);

    void reset_mappings();
    void inherit_mappings(const UserlandHleRegistry& parent);

private:
    friend class UserlandHleCall;

    struct Registration {
        std::uint16_t id { };
        std::string image_suffix;
        std::string symbol;
        bool prefix { };
        std::optional<std::uint32_t> virtual_address;
        std::optional<std::pair<std::string, std::string>> objc_instance_method;
        bool objc_class_method { };
        Handler handler;
    };
    struct InstalledCall {
        std::uint16_t id { };
        std::string symbol;
        bool thumb { };
        std::vector<std::byte> original;
        std::uint8_t prefix_arguments { };
    };
    struct CachedMappedSymbol {
        std::uint32_t symbol_index { };
        std::uint64_t file_offset { };
        std::uint16_t registration_id { };
        std::uint8_t patch_size { };
        bool guest_function { };
        bool guest_data_symbol { };
    };
    struct HleRuleKey {
        std::string image_suffix;
        std::string symbol;
        bool prefix { };
        std::optional<std::uint32_t> virtual_address;
        std::optional<std::pair<std::string, std::string>> objc_method;
        bool objc_class_method { };
        bool guest_function { };

        friend bool operator==(const HleRuleKey&, const HleRuleKey&) = default;
    };
    struct SharedHlePatch {
        std::uint32_t image_index { };
        std::uint32_t file_index { };
        std::uint64_t file_offset { };
        std::uint8_t patch_size { };
        bool thumb { };
        bool guest_function { };
        std::string symbol;
        std::optional<HleRuleKey> rule;
    };
    struct HleRuleView {
        std::string_view image_suffix;
        std::string_view symbol;
        bool prefix { };
        std::optional<std::uint32_t> virtual_address;
        std::optional<std::pair<std::string_view, std::string_view>>
            objc_method;
        bool objc_class_method { };
        bool guest_function { };
    };
    struct SharedHlePatchView {
        std::uint32_t image_index { };
        std::uint32_t file_index { };
        std::uint64_t file_offset { };
        std::uint8_t patch_size { };
        bool thumb { };
        bool guest_function { };
        std::string_view symbol;
        std::optional<HleRuleView> rule;
    };
    struct SharedHlePlan {
        ContentIdentity generation_identity;
        ArmArchitectureVersion architecture { };
        std::vector<SharedHlePatch> patches;
        std::map<std::uint32_t, std::pair<std::size_t, std::size_t>>
            file_ranges;

        [[nodiscard]] std::size_t patch_count() const noexcept;
        [[nodiscard]] SharedHlePatchView patch_view(std::size_t index) const;
        [[nodiscard]] std::optional<std::pair<std::size_t, std::size_t>>
        file_range(std::uint32_t file_index) const;
        void build_image_patch_index();
        [[nodiscard]] const std::vector<std::size_t>* patches_for_image(
            std::uint32_t file_index, std::uint32_t image_index) const;

    private:
        friend class UserlandHleRegistry;
        std::shared_ptr<const ImmutableArtifactView> artifact_view_;
        std::uint32_t mapped_patch_count_ { };
        std::uint32_t mapped_range_count_ { };
        std::uint64_t mapped_patch_records_offset_ { };
        std::uint64_t mapped_range_records_offset_ { };
        std::uint64_t mapped_string_offset_ { };
        std::uint64_t mapped_string_size_ { };
        std::map<std::pair<std::uint32_t, std::uint32_t>,
            std::vector<std::size_t>>
            image_patch_indices_;
    };

    [[nodiscard]] static std::shared_ptr<const SharedHlePlan>
    load_shared_plan_artifact(std::string_view plan_key,
        const ContentIdentity& generation_identity,
        ArmArchitectureVersion architecture);
    static void publish_shared_plan_artifact(
        std::string_view plan_key, const SharedHlePlan& plan);

    struct ParsedImageCacheEntry {
        ArmArchitectureVersion architecture { };
        ContentIdentity content_identity;
        std::shared_ptr<const MachOImage> image;
        std::uint64_t registration_generation { };
        std::vector<CachedMappedSymbol> mapped_symbols;
    };

    [[nodiscard]] Registration* select_registration(
        std::string_view image_path, std::string_view symbol);
    [[nodiscard]] const Registration* find_registration(std::uint16_t id) const;
    [[nodiscard]] const Registration* find_registration(
        const HleRuleKey& key) const;
    [[nodiscard]] const Registration* find_registration(
        const HleRuleView& key) const;
    [[nodiscard]] HleRuleKey rule_key(const Registration& registration) const;
    [[nodiscard]] static std::string rule_key_text(const HleRuleKey& key);
    [[nodiscard]] ParsedImageCacheEntry& cached_image(
        std::string_view logical_image_path,
        const std::filesystem::path& source_path,
        std::optional<std::uint64_t> image_header_offset,
        std::optional<ContentIdentity> source_identity,
        ArmArchitectureVersion architecture,
        std::shared_ptr<const MachOImage> parsed_image = { });
    [[nodiscard]] std::size_t install_mapped_image_impl(Cpu& cpu,
        std::uint32_t process_id, std::string_view logical_image_path,
        const std::filesystem::path& source_path,
        std::optional<std::uint64_t> image_header_offset,
        std::optional<ContentIdentity> source_identity,
        std::uint32_t mapping_address, std::uint32_t mapping_size,
        std::uint64_t file_offset, ArmArchitectureVersion architecture,
        std::shared_ptr<const MachOImage> parsed_image = { },
        std::optional<std::uint32_t> cache_file_index = { },
        std::optional<std::uint32_t> cache_image_index = { });
    [[nodiscard]] std::uint32_t ensure_string_page();
    [[nodiscard]] std::optional<std::uint32_t> install_continuation(Cpu& cpu,
        std::uint32_t return_address,
        UserlandHleCall::Continuation continuation);
    [[nodiscard]] bool defer_guest_function(std::string_view symbol,
        std::size_t processor_id, bool wait_for_receive_boundary, Handler setup,
        Handler completion);
    [[nodiscard]] bool deliver_deferred_guest_function(
        Cpu& cpu, std::uint32_t process_id, std::uint32_t svc_immediate);

    struct PendingContinuation {
        std::uint32_t return_address { };
        UserlandHleCall::Continuation handler;
    };
    struct DeferredGuestCall {
        std::uint32_t address { };
        std::size_t processor_id { };
        bool wait_for_receive_boundary { };
        bool thumb { };
        Handler setup;
        Handler completion;
    };

    struct SharedCacheDataSymbol {
        std::string cache_path;
        std::uint64_t file_offset { };
        std::string symbol;
    };

    void prepare_shared_cache_data_symbols(
        const DyldSharedCache& cache, ArmArchitectureVersion architecture);

    AddressSpace& memory_;
    Output& output_;
    std::vector<Registration> registrations_;
    std::vector<std::pair<std::string, std::string>> guest_functions_;
    std::vector<std::pair<std::string, std::string>> guest_data_symbols_;
    std::vector<SharedCacheDataSymbol> shared_cache_data_symbols_;
    std::uint64_t registration_generation_ { };
    std::map<std::string, ParsedImageCacheEntry, std::less<>>
        parsed_image_cache_;
    std::shared_ptr<const SharedHlePlan> shared_hle_plan_;
    ContentIdentity shared_hle_plan_generation_identity_;
    ArmArchitectureVersion shared_hle_plan_architecture_ { };
    std::uint64_t shared_hle_plan_registration_generation_ { };
    std::map<std::uint32_t, InstalledCall> installed_calls_;
    std::map<std::tuple<std::uint16_t, std::string, std::uint8_t>, std::uint32_t>
        callable_aliases_;
    std::map<std::string, std::uint32_t, std::less<>> installed_symbols_;
    std::map<std::string, bool, std::less<>> installed_symbol_thumb_;
    std::set<std::string, std::less<>> loaded_images_;
    std::map<std::string, std::uint32_t, std::less<>> interned_strings_;
    std::uint32_t string_page_ { };
    std::uint32_t string_cursor_ { };
    std::set<std::uint32_t> data_pages_;
    std::uint32_t data_cursor_ { };
    std::map<std::uint32_t, std::uint32_t> persistent_trampolines_;
    std::uint32_t persistent_trampoline_cursor_ { 0x60000000U };
    std::map<std::uint32_t, PendingContinuation> pending_continuations_;
    std::deque<DeferredGuestCall> deferred_guest_calls_;
    std::vector<std::uint32_t> available_continuation_trampolines_;
    std::uint32_t continuation_trampoline_cursor_ { 0x61000000U };
    std::uint32_t thread_callback_return_address_ { };
    std::map<std::size_t, Handler> pending_thread_callbacks_;
    std::set<std::string, std::less<>> traced_symbols_;
};

struct UserlandHleStats {
    std::uint64_t generation_plan_builds { };
    std::uint64_t generation_plan_hits { };
    std::uint64_t generation_plan_artifact_builds { };
    std::uint64_t generation_plan_artifact_hits { };
    std::uint64_t image_plan_builds { };
    std::uint64_t image_plan_hits { };
    std::uint64_t relevant_images { };
    std::uint64_t expected_patches { };
    std::uint64_t installed_patches { };
    std::uint64_t batch_applies { };
    std::uint64_t invalidation_ranges { };
    std::uint64_t batch_failures { };
};

[[nodiscard]] UserlandHleStats userland_hle_stats() noexcept;

}
