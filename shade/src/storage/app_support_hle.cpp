// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt legacy AppSupport database entry points while retaining
// firmware-owned behavior.

#include "storage/app_support_hle.hpp"

#include <array>
#include <cstdint>
#include <string>
#include <string_view>

#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view app_support_image {
        "/AppSupport.framework/AppSupport"
    };
    constexpr std::uint32_t sqlite_error = 1U;

    constexpr std::array<std::string_view, 3> transaction_operations {
        "_CPSqliteConnectionBegin",
        "_CPSqliteConnectionCommit",
        "_CPSqliteConnectionRollback",
    };

} // namespace

void register_app_support_hle(UserlandHleRegistry& registry)
{
    for (const auto operation : transaction_operations) {
        registry.register_function(std::string { app_support_image },
            std::string { operation }, [](UserlandHleCall& call) {
                if (call.argument(0) == 0) {
                    // Calendar's alarm-engine boot path can legitimately have
                    // no readable database connection on a freshly extracted
                    // firmware filesystem. The original AppSupport routine
                    // dereferences it unconditionally; report SQLITE_ERROR so
                    // the framework treats the calendar as empty instead.
                    call.set_return(sqlite_error);
                } else {
                    call.resume_original();
                }
            });
    }
}

} // namespace shade
