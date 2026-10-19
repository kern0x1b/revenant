// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track guest vnode changes and notify registered filesystem
// watchers.

#include "kernel/vnode_watch.hpp"

#include "kernel/darwin_kqueue_abi.hpp"

#include <utility>

namespace shade {

VnodeWatch::VnodeWatch(
    std::filesystem::path path, GuestFileGenerationRegistry& files)
    : path_ { std::move(path) }
{
    mutation_generation_ = files.mutation_generation();
    observed_ = files.observe(path_);
}

std::uint32_t VnodeWatch::pending(GuestFileGenerationRegistry& files) const
{
    const auto generation = files.mutation_generation();
    if (detached_ || generation == mutation_generation_)
        return pending_;
    mutation_generation_ = generation;
    const auto current = files.observe(path_);
    const auto& before = observed_.generation;
    const auto& after = current.generation;
    using namespace darwin::kqueue;
    if (before && (!after || before->device != after->device ||
                             before->inode != after->inode)) {
        pending_ |= current.last_mutation == GuestFileMutationKind::Rename
                        ? vnode_note_rename
                        : vnode_note_delete;
        // Replacing the pathname must not silently retarget an existing knote
        // to the new file object. The client can reopen and register it again.
        detached_ = true;
    } else if (before && after && current.revision != observed_.revision) {
        if (before->file_size != after->file_size ||
            before->modified_seconds != after->modified_seconds ||
            before->modified_nanoseconds != after->modified_nanoseconds ||
            current.last_mutation == GuestFileMutationKind::Write ||
            current.last_mutation == GuestFileMutationKind::SharedWriteback ||
            current.last_mutation == GuestFileMutationKind::Truncate) {
            pending_ |= vnode_note_write;
        }
        if (after->file_size > before->file_size)
            pending_ |= vnode_note_extend;
        if (before->changed_seconds != after->changed_seconds ||
            before->changed_nanoseconds != after->changed_nanoseconds) {
            pending_ |= vnode_note_attrib;
        }
    }
    observed_ = current;
    return pending_;
}

void VnodeWatch::acknowledge(std::uint32_t flags) const
{
    pending_ &= ~flags;
}

} // namespace shade
