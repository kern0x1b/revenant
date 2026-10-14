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

// The images whose install name starts with this prefix are the ones this
// project builds (the backports). Every other image is Apple's.
inline constexpr std::string_view own_image_prefix { "/usr/lib/charon/" };

// The [begin, end) address ranges of the __TEXT of the images that
// own_image_prefix names.
using AddressRanges = std::vector<std::pair<std::uint32_t, std::uint32_t>>;
[[nodiscard]] AddressRanges own_text_ranges(const GuestImageTable& images);

// Where one run's ticks go on the guest stack. Self: the run started in one
// of our images, so the address is its PC. Caller: the run started in Apple
// code reached from one of ours, so the address is the return address into
// ours. System: no frame of the run's stack is ours, so the address is the
// outermost frame's (the PC when there is none).
struct StackAttribution {
    enum class Kind : std::uint8_t {
        Self,
        Caller,
        System,
    };
    Kind kind { Kind::Self };
    std::uint32_t address { };
};

// Reads the guest word at an address, or nullopt when it cannot be read.
using GuestReader = std::function<std::optional<std::uint32_t>(std::uint32_t)>;

// Walks a run's guest stack from its start and attributes its ticks. `pc` is
// the run's PC, `lr` its LR and `frame` its r7 (the frame pointer the armv7
// ABI keeps: [frame] is the caller's frame, [frame + 4] the return address
// into the caller). LR is checked first: a leaf that has pushed no frame, and
// a function at its entry, return into its caller through LR. The walk stops
// after `max_frames` frames, at a null, misaligned or non-increasing frame
// pointer, or at an unreadable word.
[[nodiscard]] StackAttribution attribute_stack(std::uint32_t pc,
    std::uint32_t lr, std::uint32_t frame, const AddressRanges& own,
    const GuestReader& read32, std::size_t max_frames = 32);

// The guest stack of a run as the r7 walk sees it, every frame kept: the PC,
// then LR with its Thumb bit dropped (it is the second frame whether or not it
// is a return address), then up to `max_frames` return addresses read from the
// chain of [frame] and [frame + 4]. Unlike attribute_stack the walk does not
// stop at our frames: it goes up to the walk's own end (a null, misaligned or
// non-increasing frame pointer, or an unreadable word), so the frames above
// the first one of ours are visible too.
[[nodiscard]] std::vector<std::uint32_t> capture_stack_chain(std::uint32_t pc,
    std::uint32_t lr, std::uint32_t frame, const GuestReader& read32,
    std::size_t max_frames = 16);

// The runs that started at one block with one guest stack (see
// capture_stack_chain), and the ticks they consumed. `thread` is the guest
// thread the scheduler dispatched for those runs.
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

// The runs of one process attributed to one stack location, and their ticks.
struct StackRow {
    std::uint32_t pid { };
    StackAttribution attribution { };
    std::uint64_t runs { };
    std::uint64_t ticks { };
};

struct MappedStackRow {
    StackRow row;
    // The image and offset of the attributed address; empty when it lies in
    // no image of its process.
    std::string image;
    std::uint32_t offset { };
};

// Accumulates the runs and the ticks they consumed per start block. Off by
// default: nothing is recorded, and the executor keeps its tick budget. While
// it is enabled the executor calls the JIT once per block (a budget of one
// tick each) and records every call here; the slice keeps its whole budget.
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

    // Called after each run that started at `location` in process `pid`, with
    // the stack attribution of its start and its consumed ticks.
    void record_stack(
        std::uint32_t pid, StackAttribution attribution, std::uint64_t ticks);

    // Called after each run that started at `location` in process `pid` on
    // guest thread `thread`, with the frames its guest stack held at its start
    // (capture_stack_chain) and its consumed ticks.
    void record_chain(std::uint32_t pid, std::uint32_t thread,
        std::uint64_t location, std::uint32_t entry, bool thumb,
        std::vector<std::uint32_t> frames, std::uint64_t ticks);

    // The address of the guest's dyld_all_image_info, noted when a process is
    // created, so a run can read the image list while it runs (0 when none).
    void note_image_info(std::uint32_t pid, std::uint32_t address);
    [[nodiscard]] std::uint32_t image_info_address(std::uint32_t pid) const;

    // Clears runs, callers, stacks, chains, translations and images. The image
    // info addresses are kept: they belong to live processes.
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
    // Stack rows in no particular order.
    [[nodiscard]] std::vector<StackRow> stacks() const;
    // Chain rows in no particular order.
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

// Every row, mapped to its image through its process's table, sorted by ticks,
// largest first; ties by pid, entry, then Thumb after ARM.
[[nodiscard]] std::vector<MappedBlockRow> map_block_rows(
    const GuestBlockProfile& profile);

// Every caller row, mapped to the block's image and to the caller's image
// through its process's table, sorted by ticks, largest first; ties by pid,
// entry, Thumb, then caller.
[[nodiscard]] std::vector<MappedCallerRow> map_caller_rows(
    const GuestBlockProfile& profile);

// Every stack row, mapped to the image of its address through its process's
// table, sorted by ticks, largest first; ties by pid, kind, then address.
[[nodiscard]] std::vector<MappedStackRow> map_stack_rows(
    const GuestBlockProfile& profile);

// Tab-separated table with a header line: one line per stack row.
[[nodiscard]] std::string format_stack_table(
    const std::vector<MappedStackRow>& rows);

// The chain table keeps this many rows, the largest ticks first. A row holds up
// to 16 frames of about 70 bytes each, so the table is at most about 11 MB.
// Rows left out are counted in the run's `[perf-block-file]` line; the stacks
// table keeps the exact sums of every run.
inline constexpr std::size_t chain_table_row_limit { 10'000 };

// Tab-separated table with a header line: one line per chain row, largest
// ticks first, at most `max_rows` rows. Each frame is written as its image and
// offset ("path+0xOFFSET"), or as its address ("0xADDRESS") when no image of
// its process holds it.
[[nodiscard]] std::string format_chain_table(const GuestBlockProfile& profile,
    std::size_t max_rows = chain_table_row_limit);

// One `[perf-block-thread]` line per guest thread, in pid and thread order: the
// runs and ticks of all its chain rows. It covers every chain row, not only
// the rows the chain table keeps.
[[nodiscard]] std::vector<std::string> format_thread_summary(
    const GuestBlockProfile& profile);

// One `[perf-block-stack]` line: the ticks of each kind of attribution.
[[nodiscard]] std::string format_stack_summary(
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
