// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Opt-in guest CPU profile: executions and ticks per translated block, mapped
// to the guest image that holds the block's first instruction.

#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
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

// One translated block: where its first instruction is, the cycle count the
// translator gave it (what the emitted code charges per execution), and how
// often it was entered.
struct BlockCounter {
    std::uint32_t pid { };
    std::uint32_t entry { };
    bool thumb { };
    std::uint64_t cycles { };
    std::uint64_t executions { };
};

struct MappedBlockCounter {
    BlockCounter counter;
    // executions x cycles: the ticks the block's cycle count charges.
    std::uint64_t ticks { };
    // Empty when the entry lies in no image of its process.
    std::string image;
    std::uint32_t offset { };
};

// Counts block executions and the ticks they charge. Off by default: the
// translator emits no counter, and nothing here is reserved. When enabled, the
// translator gives every block a slot (allocate_counter), the emitted code
// counts entries into it (count_execution), and the translator reports the
// block's cycle count when its emission completes (set_counter_cycles).
//
// Artifacts are not used while the profile is on: an artifact is compiled
// without the counter, so a loaded block would not be counted.
class GuestBlockProfile {
public:
    // Reserves `capacity` slots. Blocks translated after the table is full are
    // not counted and are reported as dropped.
    void reserve_counters(std::size_t capacity);
    // The slot for a block about to be emitted, or nullopt when no table is
    // reserved or the table is full.
    [[nodiscard]] std::optional<std::uint64_t> allocate_counter(
        std::uint32_t pid, std::uint32_t entry, bool thumb);
    void set_counter_cycles(std::uint64_t slot, std::uint64_t cycles);
    // Called by the emitted code at every entry of the block in `slot`.
    void count_execution(std::uint64_t slot) noexcept;

    // Clears counts and images; the reserved slots are kept.
    void clear();
    void set_enabled(bool enabled)
    {
        enabled_.store(enabled, std::memory_order_release);
    }
    [[nodiscard]] bool enabled() const
    {
        return enabled_.load(std::memory_order_acquire);
    }

    // Called when a process exits, while its address space still holds the
    // dyld image list. A later table for the same pid replaces the earlier one.
    void record_images(std::uint32_t pid, GuestImageTable images);
    [[nodiscard]] GuestImageTable image_table(std::uint32_t pid) const;
    [[nodiscard]] std::size_t image_table_count() const;

    // Slots allocated so far, in slot order.
    [[nodiscard]] std::vector<BlockCounter> counters() const;
    [[nodiscard]] std::uint64_t dropped_blocks() const;

private:
    std::atomic<bool> enabled_ { false };
    mutable std::mutex mutex_;
    std::vector<BlockCounter> blocks_; // slot = index; executions are in executions_
    std::unique_ptr<std::atomic<std::uint64_t>[]> executions_;
    std::size_t capacity_ { };
    std::uint64_t dropped_blocks_ { };
    std::map<std::uint32_t, GuestImageTable> images_;
};

// Every counted block, mapped to its image through its process's table, sorted
// by ticks, largest first; ties by pid, entry, then Thumb after ARM.
[[nodiscard]] std::vector<MappedBlockCounter> map_block_counters(
    const GuestBlockProfile& profile);

// Tab-separated table with a header line: one line per counted block.
[[nodiscard]] std::string format_block_counter_table(
    const std::vector<MappedBlockCounter>& rows);

// `[perf-block]` totals against the run's cpu ticks, then up to `top`
// `[perf-block-top]` rows and up to `top` `[perf-block-image]` totals.
[[nodiscard]] std::vector<std::string> format_block_counter_summary(
    const GuestBlockProfile& profile, std::uint64_t cpu_ticks, std::size_t top);

} // namespace shade
