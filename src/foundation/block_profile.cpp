// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/block_profile.hpp"

#include <algorithm>
#include <cstdio>
#include <iterator>
#include <limits>
#include <map>
#include <utility>

namespace shade {
namespace {

    std::string hex32(std::uint32_t value)
    {
        char text[11];
        std::snprintf(text, sizeof text, "0x%08x", value);
        return text;
    }

    std::string share_text(std::uint64_t part, std::uint64_t whole)
    {
        char text[32];
        const auto fraction =
            whole == 0 ? 0.0
                       : static_cast<double>(part) / static_cast<double>(whole);
        std::snprintf(text, sizeof text, "%.4f", fraction);
        return text;
    }

} // namespace

GuestImageTable::GuestImageTable(std::vector<GuestImage> images)
    : images_ { std::move(images) }
{
    std::sort(images_.begin(), images_.end(),
        [](const GuestImage& left, const GuestImage& right) {
            return left.load_address < right.load_address;
        });
}

const GuestImage* GuestImageTable::find(std::uint32_t address) const
{
    // The last image loaded at or below the address is the only candidate:
    // dyld never maps two images over each other.
    const auto next = std::upper_bound(images_.begin(), images_.end(), address,
        [](std::uint32_t value, const GuestImage& image) {
            return value < image.load_address;
        });
    if (next == images_.begin())
        return nullptr;
    const auto& candidate = *std::prev(next);
    const std::uint64_t end =
        candidate.text_size != 0
            ? std::uint64_t { candidate.load_address } + candidate.text_size
        : next == images_.end()
            ? std::uint64_t { std::numeric_limits<std::uint32_t>::max() } + 1
            : std::uint64_t { next->load_address };
    return address < end ? &candidate : nullptr;
}

void GuestBlockProfile::reserve_counters(std::size_t capacity)
{
    const std::lock_guard lock { mutex_ };
    if (capacity <= capacity_)
        return;
    auto executions =
        std::make_unique<std::atomic<std::uint64_t>[]>(capacity);
    for (std::size_t slot = 0; slot < capacity_; ++slot)
        executions[slot].store(
            executions_[slot].load(std::memory_order_relaxed),
            std::memory_order_relaxed);
    executions_ = std::move(executions);
    capacity_ = capacity;
    blocks_.reserve(capacity);
}

std::optional<std::uint64_t> GuestBlockProfile::allocate_counter(
    std::uint32_t pid, std::uint32_t entry, bool thumb)
{
    const std::lock_guard lock { mutex_ };
    if (capacity_ == 0)
        return std::nullopt;
    if (blocks_.size() >= capacity_) {
        ++dropped_blocks_;
        return std::nullopt;
    }
    const auto slot = static_cast<std::uint64_t>(blocks_.size());
    BlockCounter counter;
    counter.pid = pid;
    counter.entry = entry;
    counter.thumb = thumb;
    blocks_.push_back(counter);
    return slot;
}

void GuestBlockProfile::set_counter_cycles(
    std::uint64_t slot, std::uint64_t cycles)
{
    const std::lock_guard lock { mutex_ };
    if (slot < blocks_.size())
        blocks_[slot].cycles = cycles;
}

void GuestBlockProfile::count_execution(std::uint64_t slot) noexcept
{
    // Slots are below capacity_ by construction, and executions_ is replaced
    // only by reserve_counters, which runs before any block is translated.
    executions_[slot].fetch_add(1U, std::memory_order_relaxed);
}

void GuestBlockProfile::clear()
{
    const std::lock_guard lock { mutex_ };
    for (std::size_t slot = 0; slot < capacity_; ++slot)
        executions_[slot].store(0U, std::memory_order_relaxed);
    blocks_.clear();
    dropped_blocks_ = 0;
    images_.clear();
}

void GuestBlockProfile::record_images(std::uint32_t pid, GuestImageTable images)
{
    if (!enabled())
        return;
    const std::lock_guard lock { mutex_ };
    images_[pid] = std::move(images);
}

GuestImageTable GuestBlockProfile::image_table(std::uint32_t pid) const
{
    const std::lock_guard lock { mutex_ };
    const auto found = images_.find(pid);
    return found == images_.end() ? GuestImageTable { } : found->second;
}

std::size_t GuestBlockProfile::image_table_count() const
{
    const std::lock_guard lock { mutex_ };
    return images_.size();
}

std::vector<BlockCounter> GuestBlockProfile::counters() const
{
    const std::lock_guard lock { mutex_ };
    auto result = blocks_;
    for (std::size_t slot = 0; slot < result.size(); ++slot)
        result[slot].executions =
            executions_[slot].load(std::memory_order_relaxed);
    return result;
}

std::uint64_t GuestBlockProfile::dropped_blocks() const
{
    const std::lock_guard lock { mutex_ };
    return dropped_blocks_;
}

std::vector<MappedBlockCounter> map_block_counters(
    const GuestBlockProfile& profile)
{
    std::map<std::uint32_t, GuestImageTable> tables;
    std::vector<MappedBlockCounter> result;
    for (const auto& counter : profile.counters()) {
        auto found = tables.find(counter.pid);
        if (found == tables.end())
            found = tables.emplace(counter.pid, profile.image_table(counter.pid))
                        .first;
        MappedBlockCounter mapped;
        mapped.counter = counter;
        mapped.ticks = counter.executions * counter.cycles;
        if (const auto* image = found->second.find(counter.entry)) {
            mapped.image = image->path;
            mapped.offset = counter.entry - image->load_address;
        }
        result.push_back(std::move(mapped));
    }
    std::stable_sort(result.begin(), result.end(),
        [](const MappedBlockCounter& left, const MappedBlockCounter& right) {
            if (left.ticks != right.ticks)
                return left.ticks > right.ticks;
            if (left.counter.pid != right.counter.pid)
                return left.counter.pid < right.counter.pid;
            if (left.counter.entry != right.counter.entry)
                return left.counter.entry < right.counter.entry;
            return left.counter.thumb < right.counter.thumb;
        });
    return result;
}

std::string format_block_counter_table(const std::vector<MappedBlockCounter>& rows)
{
    std::string text =
        "pid\tentry\tthumb\tcycles\texecutions\tticks\timage\toffset\n";
    for (const auto& mapped : rows) {
        const auto& counter = mapped.counter;
        text +=
            std::to_string(counter.pid) + "\t" + hex32(counter.entry) + "\t" +
            (counter.thumb ? "1" : "0") + "\t" +
            std::to_string(counter.cycles) + "\t" +
            std::to_string(counter.executions) + "\t" +
            std::to_string(mapped.ticks) + "\t" +
            (mapped.image.empty() ? std::string { "-" } : mapped.image) + "\t" +
            (mapped.image.empty() ? std::string { "-" }
                                  : hex32(mapped.offset)) +
            "\n";
    }
    return text;
}

std::vector<std::string> format_block_counter_summary(
    const GuestBlockProfile& profile, std::uint64_t cpu_ticks, std::size_t top)
{
    const auto rows = map_block_counters(profile);
    std::uint64_t total_ticks { };
    std::uint64_t total_executions { };
    std::uint64_t unmapped_ticks { };
    std::map<std::string, std::pair<std::uint64_t, std::uint64_t>> by_image;
    for (const auto& mapped : rows) {
        total_ticks += mapped.ticks;
        total_executions += mapped.counter.executions;
        if (mapped.image.empty()) {
            unmapped_ticks += mapped.ticks;
            continue;
        }
        auto& [ticks, executions] = by_image[mapped.image];
        ticks += mapped.ticks;
        executions += mapped.counter.executions;
    }
    std::vector<std::pair<std::string, std::pair<std::uint64_t, std::uint64_t>>>
        images(by_image.begin(), by_image.end());
    std::stable_sort(
        images.begin(), images.end(), [](const auto& left, const auto& right) {
            return left.second.first > right.second.first;
        });

    const auto difference = static_cast<std::int64_t>(total_ticks - cpu_ticks);
    std::vector<std::string> lines;
    lines.push_back(
        "[perf-block] blocks=" + std::to_string(rows.size()) +
        " executions=" + std::to_string(total_executions) +
        " ticks=" + std::to_string(total_ticks) +
        " cpu-ticks=" + std::to_string(cpu_ticks) +
        " difference=" + std::to_string(difference) +
        " dropped-blocks=" + std::to_string(profile.dropped_blocks()) +
        " image-tables=" + std::to_string(profile.image_table_count()) +
        " unmapped-ticks=" + std::to_string(unmapped_ticks) +
        " unmapped-share=" + share_text(unmapped_ticks, total_ticks));
    for (std::size_t index = 0; index < rows.size() && index < top; ++index) {
        const auto& mapped = rows[index];
        const auto& counter = mapped.counter;
        lines.push_back(
            "[perf-block-top] rank=" + std::to_string(index + 1) +
            " pid=" + std::to_string(counter.pid) +
            " entry=" + hex32(counter.entry) +
            " thumb=" + (counter.thumb ? "1" : "0") +
            " cycles=" + std::to_string(counter.cycles) +
            " executions=" + std::to_string(counter.executions) +
            " ticks=" + std::to_string(mapped.ticks) +
            " share=" + share_text(mapped.ticks, total_ticks) + " image=" +
            (mapped.image.empty() ? std::string { "-" } : mapped.image) +
            " offset=" +
            (mapped.image.empty() ? std::string { "-" }
                                  : hex32(mapped.offset)));
    }
    for (std::size_t index = 0; index < images.size() && index < top; ++index) {
        const auto& [path, totals] = images[index];
        lines.push_back("[perf-block-image] rank=" + std::to_string(index + 1) +
                        " image=" + path +
                        " ticks=" + std::to_string(totals.first) +
                        " executions=" + std::to_string(totals.second) +
                        " share=" + share_text(totals.first, total_ticks));
    }
    return lines;
}

} // namespace shade
