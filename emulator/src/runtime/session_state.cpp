// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "runtime/session_state.hpp"

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "kernel/kernel.hpp"
#include "kernel/snapshot_census.hpp"
#include "process.hpp"

namespace emulator {

void require_single_process(std::size_t runtime_count)
{
    if (runtime_count != 1)
        throw snapshot::RefusedError { "runtime.children" };
}

void save_session_state(snapshot::Writer& out,
    runtime_detail::Runtime& initial, std::size_t runtime_count,
    const XnuScheduler& scheduler, const LoopCarriedState& loop_state,
    std::uint32_t next_pid)
{
    require_single_process(runtime_count);
    if (initial.pending_exec)
        throw snapshot::RefusedError { "runtime.pending_exec" };
    if (!initial.precompile_tasks.empty())
        throw snapshot::RefusedError { "runtime.precompile_tasks" };
    if (initial.execution_prepare_task)
        throw snapshot::RefusedError { "runtime.execution_prepare_task" };
    if (initial.kernel->process().exited)
        throw snapshot::RefusedError { "process.exited" };
    require_covered_members(*initial.kernel, *initial.memory);
    save_loop_carried_state(out, loop_state);
    scheduler.save(out);
    snapshot::save(out, next_pid);
    snapshot::save(out, static_cast<std::uint64_t>(initial.allocated.size()));
    for (const bool slot : initial.allocated)
        snapshot::save(out, slot);
    initial.memory->save(out);
    initial.cpus->save_state(out);
    initial.kernel->save_snapshot(out);
}

void load_session_state(snapshot::Reader& in,
    runtime_detail::Runtime& initial, XnuScheduler& scheduler,
    LoopCarriedState& loop_state, std::uint32_t& next_pid)
{
    loop_state = load_loop_carried_state(in);
    scheduler.load(in);
    snapshot::load(in, next_pid);
    std::uint64_t slot_count { };
    snapshot::load(in, slot_count);
    if (slot_count != initial.allocated.size())
        throw snapshot::FormatError { "snapshot names a different guest thread slot count" };
    for (std::size_t index = 0; index < initial.allocated.size(); ++index) {
        bool allocated { };
        snapshot::load(in, allocated);
        initial.allocated[index] = allocated;
    }
    initial.memory->load(in);
    initial.cpus->load_state(in);
    initial.kernel->load_snapshot(in);
}

}
