// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Opt-in guest CPU profile: ticks and run counts per translated-run entry
// address, mapped to the guest image that holds the address.

#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <map>
#include <mutex>
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

struct BlockProfileRow {
    std::uint32_t pid { };
    std::uint32_t entry { };
    std::uint64_t ticks { };
    std::uint64_t runs { };
};

struct MappedBlockRow {
    BlockProfileRow row;
    // Empty when the entry lies in no image of its process.
    std::string image;
    std::uint32_t offset { };
};

// Accumulates ticks per (process, run entry address). Recording is a no-op
// unless the profile is enabled, so the default run pays one relaxed load.
// Granularity: one Umbra run chains through many blocks until it halts (an
// SVC, a host yield, the tick budget), and its ticks are charged to the PC the
// run started at. The rows are therefore per run start, not per block.
class GuestBlockProfile {
public:
    void clear();
    void set_enabled(bool enabled)
    {
        enabled_.store(enabled, std::memory_order_release);
    }
    [[nodiscard]] bool enabled() const
    {
        return enabled_.load(std::memory_order_acquire);
    }

    void record_run(
        std::uint32_t pid, std::uint32_t entry, std::uint64_t ticks);
    // Called when a process exits, while its address space still holds the
    // dyld image list. A later table for the same pid replaces the earlier one.
    void record_images(std::uint32_t pid, GuestImageTable images);

    // Rows sorted by ticks, largest first; ties by pid, then entry.
    [[nodiscard]] std::vector<BlockProfileRow> rows() const;
    [[nodiscard]] std::uint64_t total_ticks() const;
    [[nodiscard]] std::uint64_t total_runs() const;
    [[nodiscard]] GuestImageTable image_table(std::uint32_t pid) const;
    [[nodiscard]] std::size_t image_table_count() const;

private:
    std::atomic<bool> enabled_ { false };
    mutable std::mutex mutex_;
    std::map<std::pair<std::uint32_t, std::uint32_t>, BlockProfileRow> runs_;
    std::map<std::uint32_t, GuestImageTable> images_;
    std::uint64_t total_ticks_ { };
    std::uint64_t total_runs_ { };
};

// Every row, mapped to its image through its process's table. The order is
// rows() order.
[[nodiscard]] std::vector<MappedBlockRow> map_block_profile(
    const GuestBlockProfile& profile);

// Tab-separated table with a header line: one line per row.
[[nodiscard]] std::string format_block_profile_table(
    const std::vector<MappedBlockRow>& rows);

// `[perf-block]` totals, then up to `top` `[perf-block-top]` rows and up to
// `top` `[perf-block-image]` per-image totals, largest first.
[[nodiscard]] std::vector<std::string> format_block_profile_summary(
    const GuestBlockProfile& profile, std::size_t top);

} // namespace shade
