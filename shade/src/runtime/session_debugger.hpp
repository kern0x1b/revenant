// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt session process and CPU state to the GDB debugger target
// interface.

#pragma once

#include "debug/gdb_rsp.hpp"
#include "process.hpp"

namespace shade::runtime_detail {

class BootGdbTarget final : public GdbTarget {
public:
    explicit BootGdbTarget(std::vector<std::unique_ptr<Runtime>>& runtimes)
        : runtimes_ { runtimes }
    {
    }

    [[nodiscard]] std::vector<GdbThreadId> threads() const override
    {
        std::vector<GdbThreadId> result;
        for (const auto& runtime : runtimes_) {
            for (std::size_t processor = 0;
                processor < runtime->allocated.size(); ++processor) {
                if (runtime->allocated[processor]) {
                    result.push_back(
                        GdbThreadId { runtime->kernel->process().pid,
                            static_cast<std::uint32_t>(processor + 1U) });
                }
            }
        }
        return result;
    }

    [[nodiscard]] std::optional<GdbThreadId> current_thread() const override
    {
        return current_thread_;
    }

    void set_current_thread(GdbThreadId thread) { current_thread_ = thread; }

    [[nodiscard]] std::optional<std::string> thread_extra_info(
        GdbThreadId thread) const override
    {
        const auto selected = find_thread(thread);
        if (!selected)
            return std::nullopt;
        return "pid " + std::to_string(thread.process) + " thread " +
               std::to_string(thread.thread) + " wait=" +
               selected->first->kernel->wait_reason(selected->second);
    }

    [[nodiscard]] std::optional<GdbArmRegisters> read_registers(
        GdbThreadId thread) const override
    {
        const auto selected = find_thread(thread);
        if (!selected)
            return std::nullopt;
        GdbArmRegisters result { };
        const auto& cpu = selected->first->cpus->cpu(selected->second);
        std::copy(
            cpu.registers().begin(), cpu.registers().end(), result.begin());
        result[gdb_arm_cpsr_register] = cpu.cpsr();
        return result;
    }

    bool write_registers(
        GdbThreadId thread, const GdbArmRegisters& registers) override
    {
        const auto selected = find_thread(thread);
        if (!selected)
            return false;
        auto& cpu = selected->first->cpus->cpu(selected->second);
        std::copy_n(registers.begin(), gdb_arm_general_register_count,
            cpu.registers().begin());
        cpu.set_cpsr(registers[gdb_arm_cpsr_register]);
        return true;
    }

    [[nodiscard]] std::optional<std::vector<std::byte>> read_memory(
        GdbThreadId thread, std::uint32_t address,
        std::size_t size) const override
    {
        const auto selected = find_thread(thread);
        return selected ? selected->first->memory->read_bytes(address, size)
                        : std::nullopt;
    }

    bool write_memory(GdbThreadId thread, std::uint32_t address,
        std::span<const std::byte> bytes) override
    {
        const auto selected = find_thread(thread);
        if (!selected || !selected->first->memory->copy_in(address, bytes))
            return false;
        clear_process_cache(*selected->first);
        return true;
    }

    bool insert_software_breakpoint(
        GdbThreadId thread, std::uint32_t address, std::size_t kind) override
    {
        const auto selected = find_thread(thread);
        if (!selected ||
            (kind != arm_thumb_breakpoint_size &&
                kind != arm_breakpoint_size) ||
            (address & static_cast<std::uint32_t>(kind - 1U)) != 0) {
            return false;
        }
        const auto key = std::pair { thread.process, address };
        if (const auto existing = breakpoints_.find(key);
            existing != breakpoints_.end()) {
            return existing->second.kind == kind;
        }
        const auto original =
            selected->first->memory->read_bytes(address, kind);
        if (!original)
            return false;
        static constexpr std::array<std::byte, arm_thumb_breakpoint_size>
            thumb_breakpoint { std::byte { 0x00 }, std::byte { 0xbe } };
        static constexpr std::array<std::byte, arm_breakpoint_size>
            arm_breakpoint { std::byte { 0x70 }, std::byte { 0x00 },
                std::byte { 0x20 }, std::byte { 0xe1 } };
        const auto instruction =
            kind == arm_thumb_breakpoint_size
                ? std::span<const std::byte> { thumb_breakpoint }
                : std::span<const std::byte> { arm_breakpoint };
        if (!selected->first->memory->copy_in(address, instruction))
            return false;
        breakpoints_.emplace(
            key, BreakpointRecord { kind, std::move(*original) });
        clear_process_cache(*selected->first);
        return true;
    }

    bool remove_software_breakpoint(
        GdbThreadId thread, std::uint32_t address, std::size_t kind) override
    {
        const auto selected = find_thread(thread);
        const auto breakpoint = breakpoints_.find({ thread.process, address });
        if (!selected || breakpoint == breakpoints_.end() ||
            breakpoint->second.kind != kind ||
            !selected->first->memory->copy_in(
                address, breakpoint->second.original)) {
            return false;
        }
        breakpoints_.erase(breakpoint);
        clear_process_cache(*selected->first);
        return true;
    }

    void prepare_fork_child(
        std::uint32_t parent_pid, AddressSpace& child_memory) const
    {
        for (const auto& [key, breakpoint] : breakpoints_) {
            if (key.first == parent_pid) {
                static_cast<void>(
                    child_memory.copy_in(key.second, breakpoint.original));
            }
        }
    }

    void notify_exec(std::uint32_t process)
    {
        std::erase_if(breakpoints_, [process](const auto& item) {
            return item.first.first == process;
        });
    }

    void remove_all_breakpoints()
    {
        for (const auto& [key, breakpoint] : breakpoints_) {
            for (const auto& runtime : runtimes_) {
                if (runtime->kernel->process().pid == key.first) {
                    static_cast<void>(runtime->memory->copy_in(
                        key.second, breakpoint.original));
                    clear_process_cache(*runtime);
                    break;
                }
            }
        }
        breakpoints_.clear();
    }

private:
    struct BreakpointRecord {
        std::size_t kind { };
        std::vector<std::byte> original;
    };

    [[nodiscard]] std::optional<std::pair<Runtime*, std::size_t>> find_thread(
        GdbThreadId thread) const
    {
        if (thread.thread == 0)
            return std::nullopt;
        const auto processor = static_cast<std::size_t>(thread.thread - 1U);
        for (const auto& runtime : runtimes_) {
            if (runtime->kernel->process().pid == thread.process &&
                processor < runtime->allocated.size() &&
                runtime->allocated[processor]) {
                return std::pair { runtime.get(), processor };
            }
        }
        return std::nullopt;
    }

    static void clear_process_cache(Runtime& runtime)
    {
        for (std::size_t processor = 0; processor < runtime.cpus->size();
            ++processor) {
            runtime.cpus->cpu(processor).clear_cache();
        }
    }

    std::vector<std::unique_ptr<Runtime>>& runtimes_;
    std::optional<GdbThreadId> current_thread_;
    std::map<std::pair<std::uint32_t, std::uint32_t>, BreakpointRecord>
        breakpoints_;
};

} // namespace shade::runtime_detail
