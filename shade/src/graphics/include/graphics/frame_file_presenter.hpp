// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Write headless display frames atomically to image files.

#pragma once

#include <atomic>
#include <filesystem>
#include <mutex>

namespace shade {

struct DisplayFrame;

// Headless display sink that atomically replaces a PNG, BMP, or portable
// pixmap with the most recently presented frame. The suffix selects PNG/BMP;
// other suffixes retain the original PPM output for compatibility.
class FrameFilePresenter {
public:
    explicit FrameFilePresenter(std::filesystem::path path);

    void present(const DisplayFrame& frame);
    void set_enabled(bool enabled) noexcept;
    bool enabled() const noexcept;

private:
    std::filesystem::path path_;
    std::mutex mutex_;
    std::atomic_bool enabled_ { true };
};

} // namespace shade
