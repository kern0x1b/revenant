// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Route emulator lifecycle messages, traces and command output to
// configured sinks.

#include "foundation/output.hpp"

#include <chrono>
#include <stdexcept>

namespace emulator {

std::uint64_t host_unix_milliseconds() noexcept
{
    return static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch())
            .count());
}

namespace {

    bool concise_prefix(std::string_view text)
    {
        constexpr std::string_view prefixes[] {
            "[control]",
            "[device-state]",
            "[loader]",
            "[clock]",
            "[process]",
            "[cpu] fatal",
            "[time]",
            "[signal]",
            "[mach] stalled",
            "[display]",
            "[baseband]",
            "[watch]",
            "[gles]",
            "[perf]",
            "[perf-display]",
            "[perf-clock]",
            "[perf-artifact]",
            "[perf-artifact-validation]",
            "[perf-jit-profile]",
            "[perf-memory-pages]",
            "[perf-block]",
            "[perf-block-top]",
            "[perf-block-image]",
            "[perf-block-stack]",
            "[perf-block-thread]",
            "[perf-block-file]",
            "[precompile]",
            "[precompile-outcomes]",
            "[precompile-schedule]",
            "[boot]",
            "[benchmark]",
            "[transition]",
            "[transition-snapshot]",
            "[display-attribution]",
        };
        for (const auto prefix : prefixes) {
            if (text.starts_with(prefix))
                return true;
        }
        return false;
    }

}

Output::Output(std::ostream& stream)
    : stream_ { &stream }
{
}

Output::Output(const std::filesystem::path& path)
    : file_ { std::make_unique<std::ofstream>(
          path, std::ios::binary | std::ios::trunc) }
    , stream_ { file_.get() }
    , flush_each_write_ { false }
{
    if (!*file_) {
        throw std::runtime_error { "cannot open output file: " +
                                   path.string() };
    }
}

void Output::write(std::string_view text)
{
    if (!should_emit(text))
        return;
    std::lock_guard lock { mutex_ };
    stream_->write(text.data(), static_cast<std::streamsize>(text.size()));
    if (flush_each_write_)
        stream_->flush();
}

void Output::line(std::string_view text)
{
    if (!should_emit(text))
        return;
    std::lock_guard lock { mutex_ };
    stream_->write(text.data(), static_cast<std::streamsize>(text.size()));
    stream_->put('\n');
    if (flush_each_write_ || text.starts_with("[perf-display]"))
        stream_->flush();
}

void Output::marker(std::string_view text)
{
    if (!should_emit(text))
        return;
    std::lock_guard lock { mutex_ };
    stream_->write(text.data(), static_cast<std::streamsize>(text.size()));
    stream_->put('\n');
    stream_->flush();
}

bool Output::should_emit(std::string_view text) const
{
    return verbose_ || text.empty() || text.front() != '[' ||
           concise_prefix(text);
}

}
