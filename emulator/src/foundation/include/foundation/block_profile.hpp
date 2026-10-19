// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Opt-in guest CPU profile: ticks per translated block, mapped to the guest
// image that holds the block's first instruction. The JIT is configured without
// block linking and is called once per block, each call with a budget of one
// tick; the executor repeats the call until the slice's own budget is spent, so
// the scheduler sees the same slice as an unprofiled run and only observes.
// Each call is one profiled run. The runs that still continue (a fast link, or
// a short run) are counted apart, so the table says how far its attribution
// holds.
#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <tuple>
#include <utility>
#include <vector>

namespace shade {

struct GuestImage {
    std::string path;
    std::uint32_t load_address { };
    std::uint32_t text_size { };
};

class GuestImageTable {
public:
    GuestImageTable() = default;
    explicit GuestImageTable(std::vector<GuestImage> images);

    [[nodiscard]] const GuestImage* find(std::uint32_t address) const;

    [[nodiscard]] const std::vector<GuestImage>& images() const
    {
        return images_;
    }

private:
    std::vector<GuestImage> images_;
};

enum class BlockEnd : std::uint8_t {
    Other,
    LinkBlock,
    LinkBlockFast,
};

struct TranslatedBlock {
    std::uint64_t cycles { };
    BlockEnd end { };
};

struct BlockRow {
    std::uint32_t pid { };
    std::uint64_t location { };
    std::uint32_t entry { };
    bool thumb { };
    std::uint64_t cycles { };
    std::uint64_t runs { };
    std::uint64_t ticks { };
    std::uint64_t exact_runs { };
    std::uint64_t exact_ticks { };
    std::uint64_t chained_runs { };
    std::uint64_t short_runs { };
    std::uint64_t unknown_runs { };
};

struct MappedBlockRow {
    BlockRow row;
    std::string image;
    std::uint32_t offset { };
};

struct CallerRow {
    std::uint32_t pid { };
    std::uint64_t location { };
    std::uint32_t entry { };
    bool thumb { };
    std::uint32_t caller { };
    std::uint64_t runs { };
    std::uint64_t ticks { };
};

struct MappedCallerRow {
    CallerRow row;
    std::string image;
    std::uint32_t offset { };
    std::string caller_image;
    std::uint32_t caller_offset { };
};

inline constexpr std::string_view own_image_prefix { "/usr/lib/charon/" };

using AddressRanges = std::vector<std::pair<std::uint32_t, std::uint32_t>>;
[[nodiscard]] AddressRanges own_text_ranges(const GuestImageTable& images);

struct StackAttribution {
    enum class Kind : std::uint8_t {
        Self,
        Caller,
        System,
    };
    Kind kind { Kind::Self };
    std::uint32_t address { };
};

using GuestReader = std::function<std::optional<std::uint32_t>(std::uint32_t)>;

[[nodiscard]] StackAttribution attribute_stack(std::uint32_t pc,
    std::uint32_t lr, std::uint32_t frame, const AddressRanges& own,
    const GuestReader& read32, std::size_t max_frames = 32);

[[nodiscard]] std::vector<std::uint32_t> capture_stack_chain(std::uint32_t pc,
    std::uint32_t lr, std::uint32_t frame, const GuestReader& read32,
    std::size_t max_frames = 16);

struct ChainRow {
    std::uint32_t pid { };
    std::uint32_t thread { };
    std::uint64_t location { };
    std::uint32_t entry { };
    bool thumb { };
    std::vector<std::uint32_t> frames;
    std::uint64_t runs { };
    std::uint64_t ticks { };
};

struct StackRow {
    std::uint32_t pid { };
    StackAttribution attribution { };
    std::uint64_t runs { };
    std::uint64_t ticks { };
};

struct MappedStackRow {
    StackRow row;
    std::string image;
    std::uint32_t offset { };
};

class GuestBlockProfile {
public:
    void set_enabled(bool enabled)
    {
        enabled_.store(enabled, std::memory_order_release);
    }

    [[nodiscard]] bool enabled() const
    {
        return enabled_.load(std::memory_order_acquire);
    }

    void record_translation(
        std::uint32_t pid, std::uint64_t location, TranslatedBlock block);

    void record_run(std::uint32_t pid, std::uint64_t location,
        std::uint32_t entry, bool thumb, std::uint64_t ticks,
        std::uint32_t caller);

    void record_stack(
        std::uint32_t pid, StackAttribution attribution, std::uint64_t ticks);

    void record_chain(std::uint32_t pid, std::uint32_t thread,
        std::uint64_t location, std::uint32_t entry, bool thumb,
        std::vector<std::uint32_t> frames, std::uint64_t ticks);

    void note_image_info(std::uint32_t pid, std::uint32_t address);
    [[nodiscard]] std::uint32_t image_info_address(std::uint32_t pid) const;

    void clear();

    void record_images(std::uint32_t pid, GuestImageTable images);
    [[nodiscard]] GuestImageTable image_table(std::uint32_t pid) const;
    [[nodiscard]] std::size_t image_table_count() const;

    [[nodiscard]] std::vector<BlockRow> rows() const;
    [[nodiscard]] std::vector<CallerRow> callers() const;
    [[nodiscard]] std::vector<StackRow> stacks() const;
    [[nodiscard]] std::vector<ChainRow> chains() const;
    [[nodiscard]] std::size_t translation_count() const;

private:
    std::atomic<bool> enabled_ { false };
    mutable std::mutex mutex_;
    std::map<std::pair<std::uint32_t, std::uint64_t>, TranslatedBlock>
        translations_;
    std::map<std::pair<std::uint32_t, std::uint64_t>, BlockRow> rows_;
    std::map<std::tuple<std::uint32_t, std::uint64_t, std::uint32_t>, CallerRow>
        callers_;
    std::map<std::tuple<std::uint32_t, std::uint8_t, std::uint32_t>, StackRow>
        stacks_;
    std::map<std::tuple<std::uint32_t, std::uint32_t, std::uint64_t,
                 std::vector<std::uint32_t>>,
        ChainRow>
        chains_;
    std::map<std::uint32_t, GuestImageTable> images_;
    std::map<std::uint32_t, std::uint32_t> image_info_;
};

[[nodiscard]] std::vector<MappedBlockRow> map_block_rows(
    const GuestBlockProfile& profile);

[[nodiscard]] std::vector<MappedCallerRow> map_caller_rows(
    const GuestBlockProfile& profile);

[[nodiscard]] std::vector<MappedStackRow> map_stack_rows(
    const GuestBlockProfile& profile);

[[nodiscard]] std::string format_stack_table(
    const std::vector<MappedStackRow>& rows);

inline constexpr std::size_t chain_table_row_limit { 10'000 };

[[nodiscard]] std::string format_chain_table(const GuestBlockProfile& profile,
    std::size_t max_rows = chain_table_row_limit);

[[nodiscard]] std::vector<std::string> format_thread_summary(
    const GuestBlockProfile& profile);

[[nodiscard]] std::string format_stack_summary(
    const GuestBlockProfile& profile);

[[nodiscard]] std::string format_block_table(
    const std::vector<MappedBlockRow>& rows);

[[nodiscard]] std::string format_caller_table(
    const std::vector<MappedCallerRow>& rows);

[[nodiscard]] std::vector<std::string> format_block_summary(
    const GuestBlockProfile& profile, std::uint64_t cpu_ticks, std::size_t top);

}
