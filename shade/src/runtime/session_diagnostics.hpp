// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Format live process, scheduler, renderer and translation
// diagnostics.

#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string_view>
#include <vector>

namespace shade {
class DisplayPresenter;
class Output;
class XnuScheduler;
struct CpuRunResult;

namespace runtime_detail {
struct Runtime;

// Queried at a guest-safe boundary; no background polling or live code-cache
// inspection is needed to explain process/thread and display state.
class SessionDiagnostics {
public:
    SessionDiagnostics(Runtime& initial,
        const std::vector<std::unique_ptr<Runtime>>& runtimes,
        const XnuScheduler& scheduler, DisplayPresenter* presenter,
        Output& output);

    void status() const;
    void processes(std::string_view filter) const;
    void threads(std::string_view filter) const;
    void stopped(std::uint32_t pid, std::size_t cpu,
        std::uint64_t consumed_ticks, const CpuRunResult& result) const;

private:
    [[nodiscard]] Runtime* find_runtime(std::uint32_t pid) const;

    Runtime& initial_;
    const std::vector<std::unique_ptr<Runtime>>& runtimes_;
    const XnuScheduler& scheduler_;
    DisplayPresenter* presenter_;
    Output& output_;
};

} // namespace runtime_detail
} // namespace shade
