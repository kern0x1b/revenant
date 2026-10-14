// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Opt-in guest CPU profile: ticks per translated block, mapped to the guest
// image that holds the block's first instruction. A profiled run is given a
// budget of one tick, and the JIT is configured without block linking, so a
// run ends after its first block at the dispatcher's tick check. The runs that
// still continue (a fast link, or a short run) are counted apart, so the table
// says how far its attribution holds.
#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <map>
#include <mutex>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

namespace shade {

// One image of the guest's dyld image list: where it is loaded and how far its
// __TEXT segment reaches. The path is the image's install name as dyld records
// it.
struct GuestImage {
    std::string path;
    std::uint32_t load_address { };
    std::uint32_t text_size { };
};

class GuestImageTable {
public:
    GuestImageTable() = default;
    explicit GuestImageTable(std::vector<GuestImage> images);

    // The image whose __TEXT holds `address`, or nullptr when no image does
    // (heap, stack, JIT memory). An image with no recorded __TEXT size extends
    // up to the next image's load address.
    [[nodiscard]] const GuestImage* find(std::uint32_t address) const;

    [[nodiscard]] const std::vector<GuestImage>& images() const
    {
        return images_;
    }

private:
    std::vector<GuestImage> images_; // sorted by load address
};

// How the translator ended a block. A checked link compares the run's
// remaining ticks before it enters the next block; a fast link does not, so a
// run continues through it.
enum class BlockEnd : std::uint8_t {
    Other,
    LinkBlock,
    LinkBlockFast,
};

// What the translator gave one block: the cycle count its emitted code charges
// at each entry, and how it ends.
struct TranslatedBlock {
    std::uint64_t cycles { };
    BlockEnd end { };
};

// The runs that started at one block location, and the ticks they consumed.
// A run is exact when its ticks equal the start block's cycle count: then no
// other block was charged. A chained run consumed more (it went on through
// fast links); a short run consumed less (a failed condition, or a stop inside
// the block). A run whose start block was not translated in this process
// (loaded from an artifact) is unknown.
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
    // Empty when the entry lies in no image of its process.
    std::string image;
    std::uint32_t offset { };
};

// The runs that started at one block and whose guest LR was `caller` when they
// started. For a block that is a function's entry, LR is the return address of
// the call that reached it, so `caller` names the caller one level up. A block
// reached inside its function (not at its entry) carries whatever LR held then,
// so these rows cover the entry blocks, not the whole flat profile.
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
    // The block's image and offset, as in MappedBlockRow.
    std::string image;
    std::uint32_t offset { };
    // The caller's image and offset: empty when LR lies in no image.
    std::string caller_image;
    std::uint32_t caller_offset { };
};

// Accumulates the runs and the ticks they consumed per start block. Off by
// default: nothing is recorded, and the executor keeps its tick budget. While
// it is enabled the executor gives each run a budget of one tick and records
// every run here.
//
// Artifacts are bypassed while the profile is on (neither loaded nor
// published), so every block of a profiled run was translated in this process
// and its cycle count is known. A run whose start block has no translation
// record is still counted as unknown.
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

    // Called when the translator completes a block of process `pid` at the
    // IR location descriptor `location`.
    void record_translation(
        std::uint32_t pid, std::uint64_t location, TranslatedBlock block);

    // Called after each run that started at `location`, which is the block
    // at `entry` (Thumb when `thumb`), with the run's consumed ticks and the
    // guest LR the run started with (`caller`).
    void record_run(std::uint32_t pid, std::uint64_t location,
        std::uint32_t entry, bool thumb, std::uint64_t ticks,
        std::uint32_t caller);

    // Clears runs, callers, translations and images.
    void clear();

    // Called when a process exits, while its address space still holds the
    // dyld image list. A later table for the same pid replaces the earlier one.
    void record_images(std::uint32_t pid, GuestImageTable images);
    [[nodiscard]] GuestImageTable image_table(std::uint32_t pid) const;
    [[nodiscard]] std::size_t image_table_count() const;

    // Rows in no particular order.
    [[nodiscard]] std::vector<BlockRow> rows() const;
    // Caller rows in no particular order.
    [[nodiscard]] std::vector<CallerRow> callers() const;
    [[nodiscard]] std::size_t translation_count() const;

private:
    std::atomic<bool> enabled_ { false };
    mutable std::mutex mutex_;
    std::map<std::pair<std::uint32_t, std::uint64_t>, TranslatedBlock>
        translations_;
    std::map<std::pair<std::uint32_t, std::uint64_t>, BlockRow> rows_;
    std::map<std::tuple<std::uint32_t, std::uint64_t, std::uint32_t>, CallerRow>
        callers_;
    std::map<std::uint32_t, GuestImageTable> images_;
};

// Every row, mapped to its image through its process's table, sorted by ticks,
// largest first; ties by pid, entry, then Thumb after ARM.
[[nodiscard]] std::vector<MappedBlockRow> map_block_rows(
    const GuestBlockProfile& profile);

// Every caller row, mapped to the block's image and to the caller's image
// through its process's table, sorted by ticks, largest first; ties by pid,
// entry, Thumb, then caller.
[[nodiscard]] std::vector<MappedCallerRow> map_caller_rows(
    const GuestBlockProfile& profile);

// Tab-separated table with a header line: one line per row.
[[nodiscard]] std::string format_block_table(
    const std::vector<MappedBlockRow>& rows);

// Tab-separated table with a header line: one line per caller row.
[[nodiscard]] std::string format_caller_table(
    const std::vector<MappedCallerRow>& rows);

// `[perf-block]` totals against the run's cpu ticks, then up to `top`
// `[perf-block-top]` rows and up to `top` `[perf-block-image]` totals.
[[nodiscard]] std::vector<std::string> format_block_summary(
    const GuestBlockProfile& profile, std::uint64_t cpu_ticks, std::size_t top);

} // namespace shade
