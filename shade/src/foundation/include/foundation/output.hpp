// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Route emulator lifecycle messages, traces and command output to
// configured sinks.

#pragma once

#include <filesystem>
#include <fstream>
#include <memory>
#include <mutex>
#include <ostream>
#include <string_view>

namespace shade {

class Output {
public:
    explicit Output(std::ostream& stream);
    explicit Output(const std::filesystem::path& path);

    void set_verbose(bool verbose) { verbose_ = verbose; }
    void write(std::string_view text);
    void line(std::string_view text);
    void marker(std::string_view text);

private:
    [[nodiscard]] bool should_emit(std::string_view text) const;

    std::unique_ptr<std::ofstream> file_;
    std::ostream* stream_ { };
    bool flush_each_write_ { true };
    bool verbose_ { true };
    std::mutex mutex_;
};

}
