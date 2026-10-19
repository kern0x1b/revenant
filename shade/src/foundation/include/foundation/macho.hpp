// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse ARM Mach-O images, sections, symbols, relocations and
// embedded entitlements.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/EXTERNAL_HEADERS/mach-o/loader.h

#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/arm_cpu_model.hpp"
#include "foundation/content_identity.hpp"

namespace shade {

struct MachSection {
    std::string name;
    std::string segment;
    std::uint32_t address { };
    std::uint32_t size { };
    std::uint32_t file_offset { };
    std::uint32_t flags { };
    std::uint32_t reserved1 { };
    std::uint32_t reserved2 { };
};

struct MachStub {
    std::uint32_t address { };
    std::uint32_t size { };
    std::string symbol;
};

struct MachSegment {
    std::string name;
    std::uint32_t vm_address { };
    std::uint32_t vm_size { };
    std::uint32_t file_offset { };
    std::uint32_t file_size { };
    std::int32_t max_protection { };
    std::int32_t initial_protection { };
    std::uint32_t flags { };
    std::vector<MachSection> sections;
};

struct MachDylibVersion {
    std::uint32_t current { };
    std::uint32_t compatibility { };
};

struct MachDylib {
    std::string path;
    std::uint32_t command { };
    bool prebound { };
    // LC_PREBOUND_DYLIB has no version fields. Keep absence distinct from a
    // dylib command whose explicitly encoded version is zero.
    std::optional<MachDylibVersion> version;
};

struct MachSymbol {
    std::string name;
    std::uint32_t value { };
    std::uint8_t type { };
    std::uint8_t section { };
    std::uint16_t description { };

    [[nodiscard]] bool thumb_definition() const
    {
        // Mach-O ARM N_ARM_THUMB_DEF in nlist::n_desc.
        return (description & 0x0008U) != 0;
    }
};

struct MachSymbolFileLocation {
    std::uint32_t symbol_index { };
    std::uint64_t file_offset { };
};

class MachOImage {
public:
    using VmStringResolver =
        std::function<std::optional<std::string>(std::uint32_t)>;
    static MachOImage parse(const std::filesystem::path& path,
        ArmArchitectureVersion architecture = ArmArchitectureVersion::Armv6K,
        std::optional<ContentIdentity> known_identity = std::nullopt,
        ImmutableSnapshotKind snapshot_kind = ImmutableSnapshotKind::RuntimeHot,
        // A dyld shared-cache image keeps its Mach-O header and linkedit
        // offsets in the cache container. Standalone images use the default
        // zero offset; cache callers provide the file offset of the image
        // header while retaining the container's absolute file offsets.
        std::optional<std::uint64_t> image_header_offset = std::nullopt,
        std::shared_ptr<const std::vector<std::byte>> immutable_snapshot = { },
        std::optional<GuestFileGeneration> known_generation = std::nullopt,
        std::shared_ptr<const ImmutableFileView> immutable_file_view = { });

    [[nodiscard]] const std::filesystem::path& path() const { return path_; }
    [[nodiscard]] std::uint32_t cpu_type() const { return cpu_type_; }
    [[nodiscard]] std::uint32_t cpu_subtype() const { return cpu_subtype_; }
    [[nodiscard]] std::uint32_t file_type() const { return file_type_; }
    [[nodiscard]] std::uint32_t flags() const { return flags_; }
    [[nodiscard]] std::uint32_t command_count() const { return command_count_; }
    [[nodiscard]] const ContentIdentity& content_identity() const
    {
        return content_identity_;
    }
    [[nodiscard]] std::uint64_t file_size() const noexcept
    {
        return bytes_                 ? bytes_->size()
               : immutable_file_view_ ? immutable_file_view_->size()
                                      : 0U;
    }
    [[nodiscard]] const std::optional<std::array<std::byte, 16>>& uuid() const
    {
        return uuid_;
    }
    [[nodiscard]] bool fat_container() const { return fat_container_; }
    [[nodiscard]] const std::vector<MachSegment>& segments() const
    {
        return segments_;
    }
    [[nodiscard]] const std::vector<MachDylib>& dylibs() const
    {
        return dylibs_;
    }
    [[nodiscard]] const MachDylib* dylib_identity() const;
    [[nodiscard]] const std::vector<MachSymbol>& symbols() const
    {
        return symbols_;
    }
    [[nodiscard]] const std::vector<MachSymbolFileLocation>&
    symbol_file_locations() const
    {
        return symbol_file_locations_;
    }
    [[nodiscard]] const std::vector<MachStub>& stubs() const { return stubs_; }
    // Linkers emit a compact, content-addressed function boundary table for
    // stripped images. The parser keeps only bounded, image-local starts so
    // callers can seed cold translation without treating every text byte as
    // an entry point.
    [[nodiscard]] const std::vector<std::uint32_t>& function_starts() const
    {
        return function_starts_;
    }
    [[nodiscard]] const std::optional<std::string>& dynamic_linker() const
    {
        return dynamic_linker_;
    }
    [[nodiscard]] const std::optional<std::uint32_t>& entry_point() const
    {
        return entry_point_;
    }
    [[nodiscard]] std::span<const std::byte> code_signature_entitlements() const
    {
        return code_signature_entitlements_;
    }
    [[nodiscard]] const std::vector<std::uint32_t>& unknown_commands() const
    {
        return unknown_commands_;
    }

    [[nodiscard]] const MachSymbol* find_symbol(std::string_view name) const;
    [[nodiscard]] const MachStub* find_stub(std::uint32_t address) const;
    [[nodiscard]] std::optional<std::uint16_t> read_vm_u16(
        std::uint32_t address) const;
    [[nodiscard]] std::optional<std::uint32_t> read_vm_u32(
        std::uint32_t address) const;
    // Resolve Objective-C method implementations from the image's runtime
    // metadata. This covers stripped firmware methods without relying on a
    // version-specific virtual address.
    [[nodiscard]] std::optional<std::uint32_t> find_objc_instance_method(
        std::string_view class_name, std::string_view selector,
        VmStringResolver external_string = { }) const;
    [[nodiscard]] std::optional<std::uint32_t> find_objc_class_method(
        std::string_view class_name, std::string_view selector,
        VmStringResolver external_string = { }) const;

    void map_into(AddressSpace& memory,
        FileMappingBatchContext* batch_context = nullptr) const;

private:
    [[nodiscard]] std::optional<std::uint32_t> find_objc_method(
        std::string_view class_name, std::string_view selector,
        bool class_method, const VmStringResolver& external_string) const;
    [[nodiscard]] std::span<const std::byte> byte_span() const noexcept;

    std::filesystem::path path_;
    // Parsing owns one immutable byte snapshot. File-backed executable pages
    // share it so delayed faults cannot observe later in-place host writes.
    std::shared_ptr<const std::vector<std::byte>> bytes_;
    // Shared-cache images prefer a content-addressed, read-only mmap. Keeping
    // this owner alive makes lazy parser reads and guest page faults observe
    // exactly the generation that produced the metadata.
    std::shared_ptr<const ImmutableFileView> immutable_file_view_;
    std::uint32_t cpu_type_ { };
    std::uint32_t cpu_subtype_ { };
    std::uint32_t file_type_ { };
    std::uint32_t flags_ { };
    std::uint32_t command_count_ { };
    ContentIdentity content_identity_;
    // The parser and the later lazy file-backed mapping must agree on the
    // opened vnode/file generation. If it changed, map_into copies this
    // parsed snapshot instead of admitting a newer pathname generation.
    std::optional<GuestFileGeneration> file_generation_;
    std::optional<std::array<std::byte, 16>> uuid_;
    bool fat_container_ { };
    std::vector<MachSegment> segments_;
    std::vector<MachDylib> dylibs_;
    std::vector<MachSymbol> symbols_;
    std::vector<MachSymbolFileLocation> symbol_file_locations_;
    std::vector<MachStub> stubs_;
    std::vector<std::uint32_t> function_starts_;
    std::optional<std::string> dynamic_linker_;
    std::optional<std::uint32_t> entry_point_;
    std::vector<std::byte> code_signature_entitlements_;
    std::vector<std::uint32_t> unknown_commands_;
};

[[nodiscard]] std::string mach_file_type_name(std::uint32_t file_type);
[[nodiscard]] std::string mach_cpu_name(
    std::uint32_t cpu_type, std::uint32_t cpu_subtype);

} // namespace shade
