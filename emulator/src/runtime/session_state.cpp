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

void save_session_state(snapshot::Writer& out,
    runtime_detail::Runtime& initial, std::size_t runtime_count,
    const XnuScheduler& scheduler, const LoopCarriedState& loop_state,
    std::uint32_t next_pid)
{
    if (runtime_count != 1)
        throw snapshot::RefusedError { "runtime.children" };
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

}
