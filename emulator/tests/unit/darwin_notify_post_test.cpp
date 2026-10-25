// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
#include "foundation/darwin_notify_state_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"

#include <cstdint>
#include <cstdio>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

using namespace emulator;

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "darwin_notify_post_test.cpp:%d: check failed: %s\n",
        line, expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

}

int main()
{
    AddressSpace memory;
    std::ostringstream stream;
    Output output { stream };
    UserlandHleRegistry registry { memory, output };
    DarwinNotifyStateHle notify { registry };

    std::vector<std::pair<std::string, std::uint32_t>> posts;
    notify.observe_post("com.apple.springboard.finishedstartup", 7U);
    CHECK(posts.empty());

    notify.set_post_observer(
        [&posts](std::string_view name, std::uint32_t process_id) {
            posts.emplace_back(std::string { name }, process_id);
        });
    notify.observe_post("com.apple.springboard.finishedstartup", 7U);
    notify.observe_post("com.apple.system.ringerstate", 3U);
    CHECK(posts.size() == 2U);
    CHECK(posts[0] ==
          std::make_pair(
              std::string { "com.apple.springboard.finishedstartup" }, 7U));
    CHECK(posts[1] ==
          std::make_pair(std::string { "com.apple.system.ringerstate" }, 3U));

    notify.set_post_observer({});
    notify.observe_post("com.apple.springboard.finishedstartup", 7U);
    CHECK(posts.size() == 2U);

    if (failures == 0)
        std::puts("darwin_notify_post_test: ok");
    return failures == 0 ? 0 : 1;
}
