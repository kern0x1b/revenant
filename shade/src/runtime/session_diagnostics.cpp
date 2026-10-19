// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Format live process, scheduler, renderer and translation
// diagnostics.

#include "session_diagnostics.hpp"

#include <algorithm>
#include <charconv>
#include <iomanip>
#include <sstream>
#include <system_error>

#include <umbra/interface/A32/disassembler.h>

#include "foundation/output.hpp"
#include "graphics/display_presenter.hpp"
#include "kernel/process_snapshot.hpp"
#include "process.hpp"

namespace shade::runtime_detail {
namespace {

bool matches(const ProcessSnapshot& process, std::string_view filter)
{
    if (filter.empty())
        return true;
    if (std::all_of(filter.begin(), filter.end(),
            [](char value) { return value >= '0' && value <= '9'; })) {
        std::uint32_t pid { };
        const auto [end, error] =
            std::from_chars(filter.data(), filter.data() + filter.size(), pid);
        return error == std::errc { } && end == filter.data() + filter.size() &&
               process.pid == pid;
    }
    return process.command.find(filter) != std::string::npos ||
           process.executable_path.find(filter) != std::string::npos;
}

std::string_view state_name(XnuThreadState state)
{
    switch (state) {
    case XnuThreadState::Runnable: return "runnable";
    case XnuThreadState::Running: return "running";
    case XnuThreadState::Waiting: return "waiting";
    }
    return "unknown";
}

} // namespace

SessionDiagnostics::SessionDiagnostics(Runtime& initial,
    const std::vector<std::unique_ptr<Runtime>>& runtimes,
    const XnuScheduler& scheduler, DisplayPresenter* presenter, Output& output)
    : initial_ { initial }
    , runtimes_ { runtimes }
    , scheduler_ { scheduler }
    , presenter_ { presenter }
    , output_ { output }
{
}

Runtime* SessionDiagnostics::find_runtime(std::uint32_t pid) const
{
    for (const auto& runtime : runtimes_) {
        if (runtime->kernel->process().pid == pid)
            return runtime.get();
    }
    return nullptr;
}

void SessionDiagnostics::status() const
{
    const auto submitted_frame = initial_.kernel->display_submitted_frames();
    const auto frame =
        presenter_ ? presenter_->presented_frames() : submitted_frame;
    const auto active_process = initial_.kernel->active_client_process_id();
    output_.marker("[control] status frame=" + std::to_string(frame) +
        " submitted-frame=" + std::to_string(submitted_frame) +
        " processes=" + std::to_string(runtimes_.size()) +
        " threads=" + std::to_string(scheduler_.thread_count()) +
        " runnable=" + std::to_string(scheduler_.runnable_count()) +
        " active-process=" +
        (active_process ? std::to_string(*active_process) : "none") +
        " display-power=" + (initial_.kernel->display_powered_on() ? "on" : "off"));
}

void SessionDiagnostics::processes(std::string_view filter) const
{
    std::ostringstream reply;
    std::size_t matched { };
    reply << "[control] processes filter=" << std::quoted(std::string { filter });
    for (const auto& process : initial_.kernel->process_snapshots()) {
        if (!matches(process, filter))
            continue;
        ++matched;
        const auto runnable = scheduler_.process_runnable_count(process.pid);
        const auto state = process.exited ? "exited"
            : process.signal_stopped ? "signal-stopped"
            : process.pid_suspended ? "suspended"
            : runnable != 0 ? "runnable" : "waiting";
        reply << "\n[control] process pid=" << process.pid
              << " ppid=" << process.parent_pid << " state=" << state
              << " runnable=" << runnable
              << " pid-suspended=" << process.pid_suspended
              << " signal-stopped=" << process.signal_stopped
              << " exit=" << process.exit_status
              << " signal=" << process.termination_signal
              << " name=" << std::quoted(process.command)
              << " path=" << std::quoted(process.executable_path);
    }
    reply << "\n[control] processes matches=" << matched;
    output_.marker(reply.str());
}

void SessionDiagnostics::threads(std::string_view filter) const
{
    std::ostringstream reply;
    std::size_t matched { };
    reply << "[control] threads filter=" << std::quoted(std::string { filter });
    for (const auto& process : initial_.kernel->process_snapshots()) {
        if (!matches(process, filter))
            continue;
        ++matched;
        const auto* runtime = find_runtime(process.pid);
        if (!runtime) {
            reply << "\n[control] threads pid=" << process.pid
                  << " runtime=retired exited=" << process.exited;
            continue;
        }
        for (std::size_t index = 0; index < runtime->allocated.size(); ++index) {
            if (!runtime->allocated[index])
                continue;
            const auto info = scheduler_.info(
                XnuThreadId { process.pid, static_cast<std::uint32_t>(index) });
            reply << "\n[control] thread pid=" << process.pid
                  << " thread=" << index + 1U << " cpu=" << index
                  << " state=" << (info ? state_name(info->state) : "unregistered")
                  << " priority=" << (info ? info->scheduled_priority : -1)
                  << " pid-suspended=" << process.pid_suspended
                  << " signal-stopped=" << process.signal_stopped
                  << " wait=" << std::quoted(runtime->kernel->wait_reason(index));
            if (const auto id = runtime->kernel->guest_thread_id(index))
                reply << " tid=0x" << std::hex << *id << std::dec;
            const auto& registers = runtime->cpus->cpu(index).registers();
            reply << std::hex << " r0=0x" << registers[0]
                  << " r1=0x" << registers[1] << " r2=0x" << registers[2]
                  << " r3=0x" << registers[3] << " pc=0x" << registers[15]
                  << " lr=0x" << registers[14]
                  << " sp=0x" << registers[13] << " frames=";
            auto frame = registers[7];
            for (unsigned depth = 0; depth < 16; ++depth) {
                if ((frame & 3U) != 0 || frame < registers[13] ||
                    frame - registers[13] > 1024U * 1024U)
                    break;
                const auto next = runtime->memory->read32(frame);
                const auto link = runtime->memory->read32(frame + 4U);
                if (!next || !link)
                    break;
                if (depth != 0)
                    reply << ',';
                reply << "0x" << *link;
                if (*next <= frame)
                    break;
                frame = *next;
            }
            reply << std::dec;
        }
    }
    reply << "\n[control] threads matched-processes=" << matched;
    output_.marker(reply.str());
}

void SessionDiagnostics::stopped(std::uint32_t stopped_pid,
    std::size_t stopped_cpu, std::uint64_t consumed_ticks,
    const CpuRunResult& stopped_result) const
{
    const auto checked_in_services =
        initial_.kernel->bootstrap_checked_in_service_count();
    output_.line("[boot] milestone=service-check-in service-state=" +
                std::string { checked_in_services == 0 ? "waiting" : "ready" } +
                " checked-in-services=" + std::to_string(checked_in_services));
    std::size_t allocated_count = 0;
    std::size_t runnable_count = 0;
    std::size_t waiting_count = 0;
    std::size_t mapped_pages = 0;
    std::size_t resident_pages = 0;
    std::size_t shared_page_mappings = 0;
    std::size_t cached_file_mappings = 0;
    std::size_t mapping_regions = 0;
    Runtime* stopped_runtime = &initial_;
    for (auto& runtime : runtimes_) {
        mapped_pages += runtime->memory->mapped_page_count();
        resident_pages += runtime->memory->resident_page_count();
        shared_page_mappings += runtime->memory->shared_page_count();
        cached_file_mappings += runtime->memory->cached_file_mapping_count();
        mapping_regions += runtime->memory->mapping_region_count();
        allocated_count += std::count(
            runtime->allocated.begin(), runtime->allocated.end(), true);
        std::size_t process_runnable = 0;
        std::size_t process_waiting = 0;
        for (std::size_t processor = 0; processor < runtime->allocated.size();
            ++processor) {
            if (!runtime->allocated[processor])
                continue;
            const auto scheduling_info =
                scheduler_.info(XnuThreadId { runtime->kernel->process().pid,
                    static_cast<std::uint32_t>(processor) });
            if (!scheduling_info)
                continue;
            process_runnable +=
                scheduling_info->state == XnuThreadState::Runnable ||
                scheduling_info->state == XnuThreadState::Running;
            process_waiting +=
                scheduling_info->state == XnuThreadState::Waiting;
        }
        runnable_count += process_runnable;
        waiting_count += process_waiting;
        runtime->kernel->process().waiting_for_events =
            process_runnable == 0 && process_waiting != 0;
        if (!runtime->kernel->process().exited) {
            for (std::size_t processor = 0;
                processor < runtime->allocated.size(); ++processor) {
                if (!runtime->allocated[processor])
                    continue;
                const auto scheduling_info =
                    scheduler_.info(XnuThreadId { runtime->kernel->process().pid,
                        static_cast<std::uint32_t>(processor) });
                const auto runnable =
                    scheduling_info &&
                    (scheduling_info->state == XnuThreadState::Runnable ||
                        scheduling_info->state == XnuThreadState::Running);
                const auto waiting =
                    scheduling_info &&
                    scheduling_info->state == XnuThreadState::Waiting;
                output_.line(
                    "[scheduler] pid=" +
                    std::to_string(runtime->kernel->process().pid) +
                    " cpu=" + std::to_string(processor) +
                    " runnable=" + std::to_string(runnable) +
                    " waiting=" + std::to_string(waiting) + " priority=" +
                    std::to_string(scheduling_info
                                       ? scheduling_info->scheduled_priority
                                       : -1) +
                    " wait=" + runtime->kernel->wait_reason(processor));
            }
        }
        if (runtime->kernel->process().pid == stopped_pid)
            stopped_runtime = runtime.get();
    }
    std::ostringstream message;
    message << "[cpu] stopped pid=" << stopped_pid << " cpu=" << stopped_cpu
            << " pc=0x" << std::hex
            << stopped_runtime->cpus->cpu(stopped_cpu).registers()[15]
            << std::dec << " ticks=" << consumed_ticks
            << " processes=" << runtimes_.size()
            << " threads=" << allocated_count << " runnable=" << runnable_count
            << " mapped-pages=" << mapped_pages
            << " resident-pages=" << resident_pages
            << " mapping-regions=" << mapping_regions
            << " shared-page-mappings=" << shared_page_mappings
            << " cached-file-mappings=" << cached_file_mappings
            << " cached-file-pages="
            << initial_.memory->cached_file_page_count();
    const auto& stopped_registers =
        stopped_runtime->cpus->cpu(stopped_cpu).registers();
    if (const auto instruction = stopped_runtime->memory->read32(
            stopped_registers[15], MemoryPermission::Execute)) {
        message << " insn=0x" << std::hex << *instruction << "("
                << Umbra::A32::DisassembleArm(*instruction) << ")"
                << " lr=0x" << stopped_registers[14] << std::dec;
    }
    if (stopped_result.fault) {
        message << " fault=0x" << std::hex << stopped_result.fault->address
                << " access="
                << static_cast<unsigned>(stopped_result.fault->access)
                << " size=0x" << stopped_result.fault->size;
        for (std::size_t index = 0; index < 14; ++index) {
            message << " r" << std::dec << index << "=0x" << std::hex
                    << stopped_registers[index];
        }
        message << " stack=";
        for (std::size_t index = 0; index < fault_stack_word_count; ++index) {
            const auto address =
                stopped_registers[13] +
                static_cast<std::uint32_t>(index * sizeof(std::uint32_t));
            const auto word = stopped_runtime->memory->read32(address);
            if (!word)
                break;
            if (index != 0)
                message << ',';
            message << "0x" << *word;
        }
        message << " code=";
        const auto code_base =
            stopped_registers[15] - 8U * sizeof(std::uint32_t);
        for (std::size_t index = 0; index < 16; ++index) {
            const auto word = stopped_runtime->memory->read32(
                code_base + static_cast<std::uint32_t>(index * 4U));
            if (!word)
                break;
            if (index != 0)
                message << ',';
            message << "0x" << *word;
        }
        message << std::dec;
    }
    if (!stopped_result.exception.empty()) {
        message << " exception=" << stopped_result.exception;
    }
    if (initial_.kernel->process().exited) {
        message << " exit=" << initial_.kernel->process().exit_status;
    }
    if (runnable_count == 0 && waiting_count != 0) {
        message << " state=waiting-for-events";
    }
    output_.line(message.str());
}

} // namespace shade::runtime_detail
