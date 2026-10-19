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

namespace emulator {
namespace {

    std::string hex32(std::uint32_t value)
    {
        char text[11];
        std::snprintf(text, sizeof text, "0x%08x", value);
        return text;
    }

    bool in_ranges(const AddressRanges& ranges, std::uint32_t address)
    {
        return std::any_of(ranges.begin(), ranges.end(),
            [address](const auto& range) {
                return address >= range.first && address < range.second;
            });
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

    class ImageLookup {
    public:
        explicit ImageLookup(const GuestBlockProfile& profile)
            : profile_ { profile }
        {
        }

        const GuestImage* find(std::uint32_t pid, std::uint32_t address)
        {
            auto found = tables_.find(pid);
            if (found == tables_.end())
                found = tables_.emplace(pid, profile_.image_table(pid)).first;
            return found->second.find(address);
        }

    private:
        const GuestBlockProfile& profile_;
        std::map<std::uint32_t, GuestImageTable> tables_;
    };

}

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

void GuestBlockProfile::record_translation(
    std::uint32_t pid, std::uint64_t location, TranslatedBlock block)
{
    const std::lock_guard lock { mutex_ };
    translations_[{ pid, location }] = block;
}

void GuestBlockProfile::record_run(std::uint32_t pid, std::uint64_t location,
    std::uint32_t entry, bool thumb, std::uint64_t ticks, std::uint32_t caller)
{
    const std::lock_guard lock { mutex_ };
    auto& row = rows_[{ pid, location }];
    if (row.runs == 0) {
        row.pid = pid;
        row.location = location;
        row.entry = entry;
        row.thumb = thumb;
        if (const auto found = translations_.find({ pid, location });
            found != translations_.end())
            row.cycles = found->second.cycles;
    }
    ++row.runs;
    row.ticks += ticks;

    auto& caller_row = callers_[{ pid, location, caller }];
    if (caller_row.runs == 0) {
        caller_row.pid = pid;
        caller_row.location = location;
        caller_row.entry = entry;
        caller_row.thumb = thumb;
        caller_row.caller = caller;
    }
    ++caller_row.runs;
    caller_row.ticks += ticks;

    const auto found = translations_.find({ pid, location });
    if (found == translations_.end()) {
        ++row.unknown_runs;
    } else if (ticks == found->second.cycles) {
        ++row.exact_runs;
        row.exact_ticks += ticks;
    } else if (ticks > found->second.cycles) {
        ++row.chained_runs;
    } else {
        ++row.short_runs;
    }
}

void GuestBlockProfile::clear()
{
    const std::lock_guard lock { mutex_ };
    translations_.clear();
    rows_.clear();
    callers_.clear();
    stacks_.clear();
    chains_.clear();
    images_.clear();
}

void GuestBlockProfile::record_images(std::uint32_t pid, GuestImageTable images)
{
    const std::lock_guard lock { mutex_ };
    if (!enabled_.load(std::memory_order_acquire))
        return;
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

std::vector<BlockRow> GuestBlockProfile::rows() const
{
    const std::lock_guard lock { mutex_ };
    std::vector<BlockRow> result;
    result.reserve(rows_.size());
    for (const auto& [key, row] : rows_)
        result.push_back(row);
    return result;
}

std::vector<CallerRow> GuestBlockProfile::callers() const
{
    const std::lock_guard lock { mutex_ };
    std::vector<CallerRow> result;
    result.reserve(callers_.size());
    for (const auto& [key, row] : callers_)
        result.push_back(row);
    return result;
}

void GuestBlockProfile::record_stack(
    std::uint32_t pid, StackAttribution attribution, std::uint64_t ticks)
{
    const std::lock_guard lock { mutex_ };
    auto& row = stacks_[{ pid, static_cast<std::uint8_t>(attribution.kind),
        attribution.address }];
    if (row.runs == 0) {
        row.pid = pid;
        row.attribution = attribution;
    }
    ++row.runs;
    row.ticks += ticks;
}

void GuestBlockProfile::record_chain(std::uint32_t pid, std::uint32_t thread,
    std::uint64_t location, std::uint32_t entry, bool thumb,
    std::vector<std::uint32_t> frames, std::uint64_t ticks)
{
    const std::lock_guard lock { mutex_ };
    auto& row = chains_[{ pid, thread, location, frames }];
    if (row.runs == 0) {
        row.pid = pid;
        row.thread = thread;
        row.location = location;
        row.entry = entry;
        row.thumb = thumb;
        row.frames = std::move(frames);
    }
    ++row.runs;
    row.ticks += ticks;
}

void GuestBlockProfile::note_image_info(std::uint32_t pid, std::uint32_t address)
{
    const std::lock_guard lock { mutex_ };
    image_info_[pid] = address;
}

std::uint32_t GuestBlockProfile::image_info_address(std::uint32_t pid) const
{
    const std::lock_guard lock { mutex_ };
    const auto found = image_info_.find(pid);
    return found == image_info_.end() ? 0U : found->second;
}

std::vector<StackRow> GuestBlockProfile::stacks() const
{
    const std::lock_guard lock { mutex_ };
    std::vector<StackRow> result;
    result.reserve(stacks_.size());
    for (const auto& [key, row] : stacks_)
        result.push_back(row);
    return result;
}

std::vector<ChainRow> GuestBlockProfile::chains() const
{
    const std::lock_guard lock { mutex_ };
    std::vector<ChainRow> result;
    result.reserve(chains_.size());
    for (const auto& [key, row] : chains_)
        result.push_back(row);
    return result;
}

std::size_t GuestBlockProfile::translation_count() const
{
    const std::lock_guard lock { mutex_ };
    return translations_.size();
}

std::vector<MappedBlockRow> map_block_rows(const GuestBlockProfile& profile)
{
    ImageLookup images { profile };
    std::vector<MappedBlockRow> result;
    for (const auto& row : profile.rows()) {
        MappedBlockRow mapped;
        mapped.row = row;
        if (const auto* image = images.find(row.pid, row.entry)) {
            mapped.image = image->path;
            mapped.offset = row.entry - image->load_address;
        }
        result.push_back(std::move(mapped));
    }
    std::stable_sort(result.begin(), result.end(),
        [](const MappedBlockRow& left, const MappedBlockRow& right) {
            if (left.row.ticks != right.row.ticks)
                return left.row.ticks > right.row.ticks;
            if (left.row.pid != right.row.pid)
                return left.row.pid < right.row.pid;
            if (left.row.entry != right.row.entry)
                return left.row.entry < right.row.entry;
            return left.row.thumb < right.row.thumb;
        });
    return result;
}

std::vector<MappedCallerRow> map_caller_rows(const GuestBlockProfile& profile)
{
    ImageLookup images { profile };
    std::vector<MappedCallerRow> result;
    for (const auto& row : profile.callers()) {
        MappedCallerRow mapped;
        mapped.row = row;
        if (const auto* image = images.find(row.pid, row.entry)) {
            mapped.image = image->path;
            mapped.offset = row.entry - image->load_address;
        }
        const auto returns_to = row.caller & ~1U;
        if (const auto* image = images.find(row.pid, returns_to)) {
            mapped.caller_image = image->path;
            mapped.caller_offset = returns_to - image->load_address;
        }
        result.push_back(std::move(mapped));
    }
    std::stable_sort(result.begin(), result.end(),
        [](const MappedCallerRow& left, const MappedCallerRow& right) {
            if (left.row.ticks != right.row.ticks)
                return left.row.ticks > right.row.ticks;
            if (left.row.pid != right.row.pid)
                return left.row.pid < right.row.pid;
            if (left.row.entry != right.row.entry)
                return left.row.entry < right.row.entry;
            if (left.row.thumb != right.row.thumb)
                return left.row.thumb < right.row.thumb;
            return left.row.caller < right.row.caller;
        });
    return result;
}

std::string format_caller_table(const std::vector<MappedCallerRow>& rows)
{
    std::string text =
        "pid\tentry\tthumb\timage\toffset\tcaller\tcaller_image\t"
        "caller_offset\truns\tticks\n";
    for (const auto& mapped : rows) {
        const auto& row = mapped.row;
        text += std::to_string(row.pid) + "\t" + hex32(row.entry) + "\t" +
                (row.thumb ? "1" : "0") + "\t" +
                (mapped.image.empty() ? std::string { "-" } : mapped.image) +
                "\t" +
                (mapped.image.empty() ? std::string { "-" }
                                      : hex32(mapped.offset)) +
                "\t" + hex32(row.caller) + "\t" +
                (mapped.caller_image.empty() ? std::string { "-" }
                                             : mapped.caller_image) +
                "\t" +
                (mapped.caller_image.empty() ? std::string { "-" }
                                             : hex32(mapped.caller_offset)) +
                "\t" + std::to_string(row.runs) + "\t" +
                std::to_string(row.ticks) + "\n";
    }
    return text;
}

std::string format_block_table(const std::vector<MappedBlockRow>& rows)
{
    std::string text =
        "pid\tentry\tthumb\tcycles\truns\tticks\texact_runs\texact_ticks\t"
        "chained_runs\tshort_runs\tunknown_runs\timage\toffset\n";
    for (const auto& mapped : rows) {
        const auto& row = mapped.row;
        text +=
            std::to_string(row.pid) + "\t" + hex32(row.entry) + "\t" +
            (row.thumb ? "1" : "0") + "\t" + std::to_string(row.cycles) + "\t" +
            std::to_string(row.runs) + "\t" + std::to_string(row.ticks) + "\t" +
            std::to_string(row.exact_runs) + "\t" +
            std::to_string(row.exact_ticks) + "\t" +
            std::to_string(row.chained_runs) + "\t" +
            std::to_string(row.short_runs) + "\t" +
            std::to_string(row.unknown_runs) + "\t" +
            (mapped.image.empty() ? std::string { "-" } : mapped.image) + "\t" +
            (mapped.image.empty() ? std::string { "-" }
                                  : hex32(mapped.offset)) +
            "\n";
    }
    return text;
}

AddressRanges own_text_ranges(const GuestImageTable& images)
{
    AddressRanges ranges;
    for (const auto& image : images.images()) {
        if (image.text_size == 0 ||
            image.path.compare(0, own_image_prefix.size(), own_image_prefix) !=
                0)
            continue;
        ranges.emplace_back(image.load_address,
            image.load_address + image.text_size);
    }
    return ranges;
}

StackAttribution attribute_stack(std::uint32_t pc, std::uint32_t lr,
    std::uint32_t frame, const AddressRanges& own, const GuestReader& read32,
    std::size_t max_frames)
{
    if (in_ranges(own, pc))
        return { StackAttribution::Kind::Self, pc };
    const auto returns_to = lr & ~1U;
    if (in_ranges(own, returns_to))
        return { StackAttribution::Kind::Caller, returns_to };

    StackAttribution outermost { StackAttribution::Kind::System, pc };
    std::uint32_t current = frame;
    for (std::size_t depth = 0; depth < max_frames; ++depth) {
        if (current == 0U || current % 4U != 0U)
            break;
        const auto next = read32(current);
        const auto saved_lr = read32(current + 4U);
        if (!next || !saved_lr)
            break;
        const auto caller = *saved_lr & ~1U;
        if (in_ranges(own, caller))
            return { StackAttribution::Kind::Caller, caller };
        outermost.address = caller;
        if (*next <= current)
            break;
        current = *next;
    }
    return outermost;
}

std::vector<std::uint32_t> capture_stack_chain(std::uint32_t pc,
    std::uint32_t lr, std::uint32_t frame, const GuestReader& read32,
    std::size_t max_frames)
{
    std::vector<std::uint32_t> frames { pc, lr & ~1U };
    std::uint32_t current = frame;
    for (std::size_t depth = 0; depth < max_frames; ++depth) {
        if (current == 0U || current % 4U != 0U)
            break;
        const auto next = read32(current);
        const auto saved_lr = read32(current + 4U);
        if (!next || !saved_lr)
            break;
        frames.push_back(*saved_lr & ~1U);
        if (*next <= current)
            break;
        current = *next;
    }
    return frames;
}

std::vector<MappedStackRow> map_stack_rows(const GuestBlockProfile& profile)
{
    ImageLookup images { profile };
    std::vector<MappedStackRow> result;
    for (const auto& row : profile.stacks()) {
        MappedStackRow mapped;
        mapped.row = row;
        if (const auto* image = images.find(row.pid, row.attribution.address)) {
            mapped.image = image->path;
            mapped.offset = row.attribution.address - image->load_address;
        }
        result.push_back(std::move(mapped));
    }
    std::stable_sort(result.begin(), result.end(),
        [](const MappedStackRow& left, const MappedStackRow& right) {
            if (left.row.ticks != right.row.ticks)
                return left.row.ticks > right.row.ticks;
            if (left.row.pid != right.row.pid)
                return left.row.pid < right.row.pid;
            if (left.row.attribution.kind != right.row.attribution.kind)
                return left.row.attribution.kind < right.row.attribution.kind;
            return left.row.attribution.address < right.row.attribution.address;
        });
    return result;
}

namespace {

    const char* kind_name(StackAttribution::Kind kind)
    {
        switch (kind) {
        case StackAttribution::Kind::Self:
            return "self";
        case StackAttribution::Kind::Caller:
            return "caller";
        case StackAttribution::Kind::System:
            return "system";
        }
        return "system";
    }

}

std::string format_stack_table(const std::vector<MappedStackRow>& rows)
{
    std::string text =
        "pid\tkind\taddress\timage\toffset\truns\tticks\n";
    for (const auto& mapped : rows) {
        const auto& row = mapped.row;
        text += std::to_string(row.pid) + "\t" +
                kind_name(row.attribution.kind) + "\t" +
                hex32(row.attribution.address) + "\t" +
                (mapped.image.empty() ? std::string { "-" } : mapped.image) +
                "\t" +
                (mapped.image.empty() ? std::string { "-" }
                                      : hex32(mapped.offset)) +
                "\t" + std::to_string(row.runs) + "\t" +
                std::to_string(row.ticks) + "\n";
    }
    return text;
}

std::vector<std::string> format_thread_summary(const GuestBlockProfile& profile)
{
    std::map<std::pair<std::uint32_t, std::uint32_t>,
        std::pair<std::uint64_t, std::uint64_t>>
        totals;
    std::uint64_t all_ticks { };
    for (const auto& row : profile.chains()) {
        auto& [runs, ticks] = totals[{ row.pid, row.thread }];
        runs += row.runs;
        ticks += row.ticks;
        all_ticks += row.ticks;
    }
    std::vector<std::string> lines;
    for (const auto& [key, value] : totals) {
        lines.push_back("[perf-block-thread] pid=" + std::to_string(key.first) +
                        " thread=" + std::to_string(key.second) +
                        " runs=" + std::to_string(value.first) +
                        " ticks=" + std::to_string(value.second) +
                        " share=" + share_text(value.second, all_ticks));
    }
    return lines;
}

std::string format_stack_summary(const GuestBlockProfile& profile)
{
    std::uint64_t self_ticks { };
    std::uint64_t caller_ticks { };
    std::uint64_t system_ticks { };
    for (const auto& row : profile.stacks()) {
        switch (row.attribution.kind) {
        case StackAttribution::Kind::Self:
            self_ticks += row.ticks;
            break;
        case StackAttribution::Kind::Caller:
            caller_ticks += row.ticks;
            break;
        case StackAttribution::Kind::System:
            system_ticks += row.ticks;
            break;
        }
    }
    return "[perf-block-stack] self-ticks=" + std::to_string(self_ticks) +
           " caller-ticks=" + std::to_string(caller_ticks) +
           " system-ticks=" + std::to_string(system_ticks) +
           " total-ticks=" +
           std::to_string(self_ticks + caller_ticks + system_ticks);
}

std::vector<std::string> format_block_summary(
    const GuestBlockProfile& profile, std::uint64_t cpu_ticks, std::size_t top)
{
    const auto rows = map_block_rows(profile);
    std::uint64_t total_ticks { };
    std::uint64_t total_runs { };
    std::uint64_t exact_runs { };
    std::uint64_t exact_ticks { };
    std::uint64_t chained_runs { };
    std::uint64_t short_runs { };
    std::uint64_t unknown_runs { };
    std::uint64_t unmapped_ticks { };
    std::map<std::string, std::pair<std::uint64_t, std::uint64_t>> by_image;
    for (const auto& mapped : rows) {
        const auto& row = mapped.row;
        total_ticks += row.ticks;
        total_runs += row.runs;
        exact_runs += row.exact_runs;
        exact_ticks += row.exact_ticks;
        chained_runs += row.chained_runs;
        short_runs += row.short_runs;
        unknown_runs += row.unknown_runs;
        if (mapped.image.empty()) {
            unmapped_ticks += row.ticks;
            continue;
        }
        auto& [ticks, runs] = by_image[mapped.image];
        ticks += row.ticks;
        runs += row.runs;
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
        "[perf-block] rows=" + std::to_string(rows.size()) +
        " runs=" + std::to_string(total_runs) +
        " ticks=" + std::to_string(total_ticks) +
        " cpu-ticks=" + std::to_string(cpu_ticks) +
        " difference=" + std::to_string(difference) +
        " exact-runs=" + std::to_string(exact_runs) +
        " exact-ticks=" + std::to_string(exact_ticks) +
        " exact-share=" + share_text(exact_ticks, total_ticks) +
        " chained-runs=" + std::to_string(chained_runs) +
        " short-runs=" + std::to_string(short_runs) +
        " unknown-runs=" + std::to_string(unknown_runs) +
        " translations=" + std::to_string(profile.translation_count()) +
        " image-tables=" + std::to_string(profile.image_table_count()) +
        " unmapped-ticks=" + std::to_string(unmapped_ticks) +
        " unmapped-share=" + share_text(unmapped_ticks, total_ticks));
    for (std::size_t index = 0; index < rows.size() && index < top; ++index) {
        const auto& mapped = rows[index];
        const auto& row = mapped.row;
        lines.push_back(
            "[perf-block-top] rank=" + std::to_string(index + 1) +
            " pid=" + std::to_string(row.pid) +
            " entry=" + hex32(row.entry) +
            " thumb=" + (row.thumb ? "1" : "0") +
            " cycles=" + std::to_string(row.cycles) +
            " runs=" + std::to_string(row.runs) +
            " ticks=" + std::to_string(row.ticks) +
            " exact-runs=" + std::to_string(row.exact_runs) +
            " share=" + share_text(row.ticks, total_ticks) + " image=" +
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
                        " runs=" + std::to_string(totals.second) +
                        " share=" + share_text(totals.first, total_ticks));
    }
    return lines;
}

std::string format_chain_table(
    const GuestBlockProfile& profile, std::size_t max_rows)
{
    auto rows = profile.chains();
    std::stable_sort(rows.begin(), rows.end(),
        [](const ChainRow& left, const ChainRow& right) {
            if (left.ticks != right.ticks)
                return left.ticks > right.ticks;
            if (left.pid != right.pid)
                return left.pid < right.pid;
            if (left.thread != right.thread)
                return left.thread < right.thread;
            if (left.location != right.location)
                return left.location < right.location;
            return left.frames < right.frames;
        });
    if (rows.size() > max_rows)
        rows.resize(max_rows);
    ImageLookup images { profile };
    std::string text =
        "pid\tthread\tlocation\tentry\tthumb\truns\tticks\tdepth\tframes\n";
    for (const auto& row : rows) {
        std::string frames;
        for (const auto address : row.frames) {
            if (!frames.empty())
                frames += ' ';
            const auto* image = images.find(row.pid, address);
            frames += image ? image->path + "+" +
                                  hex32(address - image->load_address)
                            : hex32(address);
        }
        char location[24];
        std::snprintf(location, sizeof location, "0x%016llx",
            static_cast<unsigned long long>(row.location));
        text += std::to_string(row.pid) + "\t" + std::to_string(row.thread) +
                "\t" + location + "\t" +
                hex32(row.entry) + "\t" + (row.thumb ? "1" : "0") + "\t" +
                std::to_string(row.runs) + "\t" + std::to_string(row.ticks) +
                "\t" + std::to_string(row.frames.size()) + "\t" + frames +
                "\n";
    }
    return text;
}

}
