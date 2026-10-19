// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Validate the optional executable-UUID network policy control ABI.
// https://github.com/apple-oss-distributions/xnu/blob/xnu-2422.1.72/bsd/kern/proc_uuid_policy.c

#include "uuid_policy.hpp"

#include "foundation/address_space.hpp"
#include "foundation/darwin_errno.hpp"
#include "kernel/kernel_shared_state.hpp"

#include <algorithm>

namespace shade::kernel_bsd::uuid_policy {

std::uint32_t control(AddressSpace& memory, const ProcessContext& caller,
    std::uint32_t operation, std::uint32_t uuid_address,
    std::uint32_t uuid_length)
{
    if (caller.effective_uid != 0U)
        return darwin::error::operation_not_permitted;
    // No per-executable cellular/flow-divert policy provider is installed.
    // Clearing the empty table is valid and does not inspect the UUID input.
    if (operation == 0U)
        return 0;
    if (operation != 1U && operation != 2U)
        return darwin::error::invalid_argument;
    if (uuid_length != 16U)
        return darwin::error::result_too_large;
    const auto uuid = memory.read_bytes(uuid_address, uuid_length);
    if (uuid_address == 0U || !uuid)
        return darwin::error::bad_address;
    if (std::all_of(uuid->begin(), uuid->end(),
            [](std::byte value) { return value == std::byte { 0 }; }))
        return darwin::error::invalid_argument;
    // Do not acknowledge installing flags that networking cannot enforce.
    return operation == 1U ? darwin::error::not_supported
                           : darwin::error::no_entry;
}

} // namespace shade::kernel_bsd::uuid_policy
