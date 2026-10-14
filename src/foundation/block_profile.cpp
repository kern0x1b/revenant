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

void GuestBlockProfile::clear()
{
    const std::lock_guard lock { mutex_ };
    runs_.clear();
    images_.clear();
    total_ticks_ = 0;
    total_runs_ = 0;
}

void GuestBlockProfile::record_run(
    std::uint32_t pid, std::uint32_t entry, std::uint64_t ticks)
{
    if (!enabled())
        return;
    const std::lock_guard lock { mutex_ };
    auto& row = runs_[{ pid, entry }];
    row.pid = pid;
    row.entry = entry;
    row.ticks += ticks;
    ++row.runs;
    total_ticks_ += ticks;
    ++total_runs_;
}

void GuestBlockProfile::record_images(std::uint32_t pid, GuestImageTable images)
{
    if (!enabled())
        return;
    const std::lock_guard lock { mutex_ };
    images_[pid] = std::move(images);
}

std::vector<BlockProfileRow> GuestBlockProfile::rows() const
{
    std::vector<BlockProfileRow> result;
    {
        const std::lock_guard lock { mutex_ };
        result.reserve(runs_.size());
        for (const auto& [key, row] : runs_)
            result.push_back(row);
    }
    std::sort(result.begin(), result.end(),
        [](const BlockProfileRow& left, const BlockProfileRow& right) {
            if (left.ticks != right.ticks)
                return left.ticks > right.ticks;
            if (left.pid != right.pid)
                return left.pid < right.pid;
            return left.entry < right.entry;
        });
    return result;
}

std::uint64_t GuestBlockProfile::total_ticks() const
{
    const std::lock_guard lock { mutex_ };
    return total_ticks_;
}

std::uint64_t GuestBlockProfile::total_runs() const
{
    const std::lock_guard lock { mutex_ };
    return total_runs_;
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

std::vector<MappedBlockRow> map_block_profile(const GuestBlockProfile& profile)
{
    std::map<std::uint32_t, GuestImageTable> tables;
    std::vector<MappedBlockRow> result;
    for (const auto& row : profile.rows()) {
        auto found = tables.find(row.pid);
        if (found == tables.end())
            found = tables.emplace(row.pid, profile.image_table(row.pid)).first;
        MappedBlockRow mapped { row, { }, 0 };
        if (const auto* image = found->second.find(row.entry)) {
            mapped.image = image->path;
            mapped.offset = row.entry - image->load_address;
        }
        result.push_back(std::move(mapped));
    }
    return result;
}

std::string format_block_profile_table(const std::vector<MappedBlockRow>& rows)
{
    std::string text = "pid\tentry\tticks\truns\timage\toffset\n";
    for (const auto& mapped : rows) {
        text +=
            std::to_string(mapped.row.pid) + "\t" + hex32(mapped.row.entry) +
            "\t" + std::to_string(mapped.row.ticks) + "\t" +
            std::to_string(mapped.row.runs) + "\t" +
            (mapped.image.empty() ? std::string { "-" } : mapped.image) + "\t" +
            (mapped.image.empty() ? std::string { "-" }
                                  : hex32(mapped.offset)) +
            "\n";
    }
    return text;
}

std::vector<std::string> format_block_profile_summary(
    const GuestBlockProfile& profile, std::size_t top)
{
    const auto rows = map_block_profile(profile);
    const auto total_ticks = profile.total_ticks();
    std::uint64_t unmapped_ticks { };
    std::map<std::string, BlockProfileRow> by_image;
    for (const auto& mapped : rows) {
        if (mapped.image.empty()) {
            unmapped_ticks += mapped.row.ticks;
            continue;
        }
        auto& total = by_image[mapped.image];
        total.ticks += mapped.row.ticks;
        total.runs += mapped.row.runs;
    }
    std::vector<std::pair<std::string, BlockProfileRow>> images(
        by_image.begin(), by_image.end());
    std::stable_sort(
        images.begin(), images.end(), [](const auto& left, const auto& right) {
            return left.second.ticks > right.second.ticks;
        });

    std::vector<std::string> lines;
    lines.push_back(
        "[perf-block] runs=" + std::to_string(profile.total_runs()) +
        " ticks=" + std::to_string(total_ticks) +
        " entries=" + std::to_string(rows.size()) +
        " image-tables=" + std::to_string(profile.image_table_count()) +
        " unmapped-ticks=" + std::to_string(unmapped_ticks) +
        " unmapped-share=" + share_text(unmapped_ticks, total_ticks));
    for (std::size_t index = 0; index < rows.size() && index < top; ++index) {
        const auto& mapped = rows[index];
        lines.push_back(
            "[perf-block-top] rank=" + std::to_string(index + 1) +
            " pid=" + std::to_string(mapped.row.pid) +
            " entry=" + hex32(mapped.row.entry) +
            " ticks=" + std::to_string(mapped.row.ticks) +
            " runs=" + std::to_string(mapped.row.runs) +
            " share=" + share_text(mapped.row.ticks, total_ticks) + " image=" +
            (mapped.image.empty() ? std::string { "-" } : mapped.image) +
            " offset=" +
            (mapped.image.empty() ? std::string { "-" }
                                  : hex32(mapped.offset)));
    }
    for (std::size_t index = 0; index < images.size() && index < top; ++index) {
        const auto& [path, total] = images[index];
        lines.push_back("[perf-block-image] rank=" + std::to_string(index + 1) +
                        " image=" + path +
                        " ticks=" + std::to_string(total.ticks) +
                        " runs=" + std::to_string(total.runs) +
                        " share=" + share_text(total.ticks, total_ticks));
    }
    return lines;
}

} // namespace shade
