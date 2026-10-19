// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "extensions.hpp"
#include "foundation/address_space.hpp"
#include <array>
#include <span>

namespace shade::bsd::sandbox {
namespace {
    constexpr std::uint32_t issue = 5U;
    constexpr std::uint32_t consume = 6U;
    constexpr std::uint32_t release = 7U;
    constexpr std::uint32_t maximum_token_size = 2048U;
    constexpr std::size_t maximum_grants = 16384U;
    constexpr std::size_t maximum_process_handles = 16384U;
}

CallResult Extensions::dispatch(AddressSpace& memory, std::uint32_t pid,
    std::uint32_t operation, std::uint32_t argument)
{
    if (operation != issue && operation != consume && operation != release)
        return CallResult::Unsupported;
    // The handle-based ABI uses 64-bit slots even in an ARM32 task. The older
    // string-only extension interface has a different layout and dispatcher.
    const auto count = operation == issue ? 5U : 3U;
    if (argument == 0U || argument > UINT32_MAX - count * 8U + 1U)
        return CallResult::BadAddress;
    std::array<std::uint64_t, 5> args { };
    for (std::uint32_t i = 0; i < count; ++i) {
        const auto value = memory.read64(argument + i * 8U);
        if (!value)
            return CallResult::BadAddress;
        args[i] = *value;
    }
    const auto read_string = [&](std::uint64_t pointer, std::uint32_t limit) {
        return pointer != 0U && pointer <= UINT32_MAX
            ? memory.read_c_string(static_cast<std::uint32_t>(pointer), limit)
            : std::optional<std::string> { };
    };
    if (operation == issue) {
        const auto class_name = read_string(args[0], 256U);
        const auto resource = read_string(args[2], 1024U);
        if (!class_name || !resource || args[4] == 0U || args[4] > UINT32_MAX)
            return CallResult::BadAddress;
        if (class_name->empty() || resource->empty() || args[1] > 1U ||
            (args[1] == 0U && resource->front() != '/'))
            return CallResult::InvalidArgument;
        const Grant grant { *class_name, *resource, args[1], args[3] };
        const auto found = grants_.find(grant);
        if (found == grants_.end() && grants_.size() >= maximum_grants)
            return CallResult::NoMemory;
        const auto id = found == grants_.end() ? grants_.size() + 1U : found->second;
        const auto token = "shade.sandbox." + std::to_string(id);
        const auto bytes = std::as_bytes(std::span { token.c_str(), token.size() + 1U });
        if (!memory.copy_in(static_cast<std::uint32_t>(args[4]), bytes))
            return CallResult::BadAddress;
        grants_.try_emplace(grant, id);
        tokens_.try_emplace(token, id);
        return CallResult::Success;
    }
    if (operation == consume) {
        if (args[1] == 0U || args[1] > maximum_token_size || args[2] == 0U ||
            args[2] > UINT32_MAX || !memory.accessible(
                static_cast<std::uint32_t>(args[2]), 8U, MemoryPermission::Write))
            return CallResult::BadAddress;
        const auto token = read_string(args[0], static_cast<std::uint32_t>(args[1]));
        if (!token)
            return CallResult::BadAddress;
        const auto grant = tokens_.find(*token);
        if (grant == tokens_.end())
            return CallResult::InvalidArgument;
        auto& handles = handles_[pid];
        if (handles.size() >= maximum_process_handles || next_handle_ == 0U)
            return CallResult::NoMemory;
        const auto handle = next_handle_++;
        if (!memory.write64(static_cast<std::uint32_t>(args[2]), handle))
            return CallResult::BadAddress;
        handles.emplace(handle, grant->second);
        return CallResult::Success;
    }
    if (args[1] != 0U)
        return CallResult::InvalidArgument;
    const auto process = handles_.find(pid);
    if (args[2] == 0U) {
        if (process == handles_.end() || process->second.erase(args[0]) == 0U)
            return CallResult::InvalidArgument;
    } else {
        const auto path = read_string(args[2], 1024U);
        if (!path)
            return CallResult::BadAddress;
        if (args[0] != 0U || path->empty())
            return CallResult::InvalidArgument;
        if (process != handles_.end()) {
            for (const auto& [grant, id] : grants_) {
                if (grant.kind == 0U && grant.resource == *path)
                    std::erase_if(process->second,
                        [id](const auto& handle) { return handle.second == id; });
            }
        }
    }
    return CallResult::Success;
}

void Extensions::fork_process(std::uint32_t parent, std::uint32_t child)
{
    if (const auto found = handles_.find(parent); found != handles_.end())
        handles_[child] = found->second;
}

void Extensions::exit_process(std::uint32_t pid)
{
    handles_.erase(pid);
}

} // namespace shade::bsd::sandbox
