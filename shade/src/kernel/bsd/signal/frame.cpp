// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Run guest signal handlers: the ARM signal frame, sigreturn, the
// alternate signal stack, and the signals a CPU fault raises.
//
// The frame is the 32-bit Darwin one - struct __darwin_ucontext, the
// 340-byte __darwin_mcontext (exception state, thread state, VFP state) and
// a 64-byte siginfo - and the handler is entered the way libsystem's
// _sigtramp expects: r0 the handler, r1 the info style, r2 the signal, r3
// the siginfo and the ucontext's address at [sp]. _sigtramp calls
// sigreturn(uctx, UC_FLAVOR) when the handler returns.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_sig.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/uxkern/ux_exception.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include <array>
#include <cstdint>
#include <optional>

#include "../support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t action_on_stack = 0x0001U;    // SA_ONSTACK
    constexpr std::uint32_t action_reset_hand = 0x0004U;  // SA_RESETHAND
    constexpr std::uint32_t action_no_defer = 0x0010U;    // SA_NODEFER
    constexpr std::uint32_t action_siginfo = 0x0040U;     // SA_SIGINFO
    constexpr std::uint32_t info_style_traditional = 1U;  // UC_TRAD
    constexpr std::uint32_t info_style_flavor = 30U;      // UC_FLAVOR
    constexpr std::uint32_t stack_on = 0x0001U;           // SS_ONSTACK
    constexpr std::uint32_t stack_disable = 0x0004U;      // SS_DISABLE
    constexpr std::uint32_t minimum_signal_stack = 32768U; // MINSIGSTKSZ

    constexpr std::uint32_t signal_illegal = 4U;
    constexpr std::uint32_t signal_trap = 5U;
    constexpr std::uint32_t signal_bus = 10U;
    constexpr std::uint32_t signal_segmentation = 11U;

    constexpr std::uint32_t exception_state_bytes = 3U * 4U;
    constexpr std::uint32_t thread_state_bytes = 17U * 4U;
    constexpr std::uint32_t vfp_state_bytes = 65U * 4U;
    constexpr std::uint32_t mcontext_bytes =
        exception_state_bytes + thread_state_bytes + vfp_state_bytes;
    static_assert(mcontext_bytes == 340U);
    constexpr std::uint32_t ucontext_bytes = 32U;
    constexpr std::uint32_t siginfo_bytes = 64U;

    constexpr std::uint32_t thumb_bit = 1U << 5U;
    constexpr std::uint32_t if_then_bits = 0x0600fc00U;
    constexpr std::uint32_t user_mode = 0x10U;
    constexpr std::uint32_t unblockable =
        (1U << (darwin::signal::kill - 1U)) |
        (1U << (darwin::signal::stop - 1U));

    constexpr std::uint32_t align_down(std::uint32_t value, std::uint32_t to)
    {
        return value & ~(to - 1U);
    }

    // The fault status a data or prefetch abort reports: a translation fault
    // for an unmapped page, a permission fault for a mapped one, and the
    // write bit of the data fault status register.
    std::uint32_t fault_status(bool mapped, bool write)
    {
        return (mapped ? 0x0fU : 0x07U) | (write ? 0x800U : 0U);
    }

} // namespace

bool CompatibilityKernel::send_signal_frame(
    Cpu& cpu, std::uint32_t signal, const GuestSignalInfo& info)
{
    auto& action = signal_actions_[signal];
    const auto handler = action[0];
    const auto trampoline = action[1];
    const auto flags = action[3];
    if (handler == darwin::signal::default_action ||
        handler == darwin::signal::ignore_action || trampoline == 0U) {
        return false;
    }

    auto& registers = cpu.registers();
    auto& signal_mask_ = signal_mask(cpu.processor_id());
    auto& alternate = alternate_signal_stacks_[cpu.processor_id()];
    const bool was_on_alternate = alternate.active;
    std::uint32_t top = registers[13];
    bool enters_alternate = false;
    if ((flags & action_on_stack) != 0U && !alternate.disabled &&
        !alternate.active) {
        top = alternate.base + alternate.size;
        enters_alternate = true;
    }

    const auto mcontext = align_down(top - mcontext_bytes, 16U);
    const auto siginfo = mcontext - siginfo_bytes;
    const auto ucontext = siginfo - ucontext_bytes;
    const auto frame = align_down(ucontext - 4U, 8U);

    std::array<std::uint32_t, mcontext_bytes / 4U> machine { };
    std::size_t word = 0;
    for (const auto value : info.exception_state)
        machine[word++] = value;
    for (std::size_t index = 0; index < 16; ++index)
        machine[word++] = registers[index];
    machine[word++] = cpu.cpsr();
    for (const auto value : cpu.extension_registers())
        machine[word++] = value;
    machine[word++] = cpu.fpscr();

    const std::array<std::uint32_t, ucontext_bytes / 4U> user {
        was_on_alternate ? 1U : 0U,
        signal_mask_,
        was_on_alternate || enters_alternate ? alternate.base : registers[13],
        was_on_alternate || enters_alternate ? alternate.size : 0U,
        alternate.disabled ? stack_disable
                           : (was_on_alternate ? stack_on : 0U),
        0U, // uc_link
        mcontext_bytes,
        mcontext,
    };
    const std::array<std::uint32_t, siginfo_bytes / 4U> signal_info {
        signal,
        0U, // si_errno
        static_cast<std::uint32_t>(info.code),
        info.sender,
        info.sender_uid,
        0U, // si_status
        info.address,
    };

    const auto store = [this](std::uint32_t address, const auto& words) {
        for (std::size_t index = 0; index < words.size(); ++index) {
            if (!memory_.write32(
                    address + static_cast<std::uint32_t>(index * 4U),
                    words[index])) {
                return false;
            }
        }
        return true;
    };
    if (!store(mcontext, machine) || !store(siginfo, signal_info) ||
        !store(ucontext, user) || !memory_.write32(frame, ucontext)) {
        output_.write("[signal] no-frame pid=" + std::to_string(process_.pid) +
                      " signal=" + std::to_string(signal) + " sp=" +
                      std::to_string(top) + "\n");
        return false;
    }

    alternate.active = was_on_alternate || enters_alternate;
    signal_mask_ |= action[2];
    if ((flags & action_no_defer) == 0U)
        signal_mask_ |= 1U << (signal - 1U);
    signal_mask_ &= ~unblockable;
    if ((flags & action_reset_hand) != 0U && signal != signal_illegal &&
        signal != signal_trap) {
        action[0] = darwin::signal::default_action;
        action[3] &= ~action_siginfo;
    }

    registers[0] = handler;
    registers[1] = (flags & action_siginfo) != 0U ? info_style_flavor
                                                  : info_style_traditional;
    registers[2] = signal;
    registers[3] = siginfo;
    registers[13] = frame;
    registers[14] = 0U;
    registers[15] = trampoline & ~1U;
    auto status = cpu.cpsr() & ~(thumb_bit | if_then_bits);
    if ((trampoline & 1U) != 0U)
        status |= thumb_bit;
    cpu.set_cpsr(status);
    output_.write("[signal] handler pid=" + std::to_string(process_.pid) +
                  " cpu=" + std::to_string(cpu.processor_id()) +
                  " signal=" + std::to_string(signal) + "\n");
    return true;
}

void CompatibilityKernel::dispatch_sigreturn(Cpu& cpu)
{
    auto& registers = cpu.registers();
    const auto ucontext = registers[0];
    const auto style = registers[1];
    const auto on_stack = memory_.read32(ucontext);
    const auto mask = memory_.read32(ucontext + 4U);
    const auto size = memory_.read32(ucontext + 24U);
    const auto mcontext = memory_.read32(ucontext + 28U);
    if (!on_stack || !mask || !size || !mcontext) {
        bsd_error(cpu, bsd_support::bad_address);
        return;
    }
    std::array<std::uint32_t, 17> thread { };
    const auto thread_base = *mcontext + exception_state_bytes;
    for (std::size_t index = 0; index < thread.size(); ++index) {
        const auto value = memory_.read32(
            thread_base + static_cast<std::uint32_t>(index * 4U));
        if (!value) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        thread[index] = *value;
    }
    if (style == info_style_flavor && *size >= mcontext_bytes) {
        const auto vfp_base = thread_base + thread_state_bytes;
        auto& extension = cpu.extension_registers();
        for (std::size_t index = 0; index < extension.size(); ++index) {
            const auto value = memory_.read32(
                vfp_base + static_cast<std::uint32_t>(index * 4U));
            if (!value) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            extension[index] = *value;
        }
        if (const auto fpscr = memory_.read32(vfp_base + 64U * 4U))
            cpu.set_fpscr(*fpscr);
    }
    for (std::size_t index = 0; index < 16; ++index)
        registers[index] = thread[index];
    // Whatever the frame says, the thread goes back to user mode with
    // interrupts enabled.
    cpu.set_cpsr((thread[16] & ~0x1ffU) | (thread[16] & thumb_bit) |
                 user_mode);
    alternate_signal_stacks_[cpu.processor_id()].active =
        (*on_stack & 1U) != 0U;
    signal_mask(cpu.processor_id()) = *mask & ~unblockable;
    // No return value: the registers are the interrupted thread's again.
}

void CompatibilityKernel::dispatch_sigaltstack(Cpu& cpu)
{
    auto& registers = cpu.registers();
    auto& alternate = alternate_signal_stacks_[cpu.processor_id()];
    if (registers[1] != 0U) {
        const std::array<std::uint32_t, 3> previous {
            alternate.base,
            alternate.size,
            (alternate.disabled ? stack_disable : 0U) |
                (alternate.active ? stack_on : 0U),
        };
        for (std::size_t index = 0; index < previous.size(); ++index) {
            if (!memory_.write32(
                    registers[1] + static_cast<std::uint32_t>(index * 4U),
                    previous[index])) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
    }
    if (registers[0] != 0U) {
        const auto base = memory_.read32(registers[0]);
        const auto size = memory_.read32(registers[0] + 4U);
        const auto flags = memory_.read32(registers[0] + 8U);
        if (!base || !size || !flags) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (alternate.active) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return;
        }
        if ((*flags & ~stack_disable) != 0U) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        if ((*flags & stack_disable) != 0U) {
            alternate.disabled = true;
        } else {
            if (*size < minimum_signal_stack) {
                bsd_error(cpu, darwin::error::no_memory);
                return;
            }
            alternate.base = *base;
            alternate.size = *size;
            alternate.disabled = false;
        }
    }
    bsd_success(cpu, 0);
}

std::optional<std::uint32_t> CompatibilityKernel::deliver_fault_signal(
    Cpu& cpu, const GuestFault& fault)
{
    GuestSignalInfo info;
    std::uint32_t signal = signal_illegal;
    const bool mapped = memory_.mapped(fault.address);
    switch (fault.kind) {
    case GuestFault::Kind::DataAccess:
    case GuestFault::Kind::InstructionFetch:
        // ux_exception: EXC_BAD_ACCESS is SIGSEGV for an address with nothing
        // mapped (KERN_INVALID_ADDRESS) and SIGBUS for a protection failure.
        signal = mapped ? signal_bus : signal_segmentation;
        info.code = mapped ? 2 /* BUS_ADRERR */ : 1 /* SEGV_MAPERR */;
        info.address = fault.address;
        info.exception_state = {
            fault.kind == GuestFault::Kind::InstructionFetch ? 3U : 4U,
            fault_status(mapped, fault.write),
            fault.address,
        };
        break;
    case GuestFault::Kind::Undefined:
        signal = signal_illegal;
        info.code = 1; // ILL_ILLOPC
        info.address = fault.pc;
        break;
    case GuestFault::Kind::Breakpoint:
        signal = signal_trap;
        info.code = 1; // TRAP_BRKPT
        info.address = fault.pc;
        break;
    }
    info.sender = process_.pid;
    info.sender_uid = process_.uid;

    // The interrupted context resumes at the faulting instruction, so a
    // handler that repairs the cause and returns runs it again.
    cpu.registers()[15] = fault.pc;
    const bool blocked =
        (signal_mask(cpu.processor_id()) & (1U << (signal - 1U))) != 0U;
    // A synchronous fault cannot wait: blocked, ignored or defaulted, the
    // process takes the default action.
    if (blocked || !send_signal_frame(cpu, signal, info))
        return signal;
    return std::nullopt;
}

void CompatibilityKernel::deliver_pending_signals(Cpu& cpu)
{
    if (process_.exited)
        return;
    const auto processor = cpu.processor_id();
    auto& own = thread_pending_signals_[processor];
    const auto mask = signal_mask(processor);
    // The thread's own signals first, then the process's.
    auto* source = (own & ~mask) != 0U ? &own : &pending_signals_;
    const auto deliverable = *source & ~mask;
    if (deliverable == 0U)
        return;
    std::uint32_t signal = 1;
    while ((deliverable & (1U << (signal - 1U))) == 0U)
        ++signal;
    *source &= ~(1U << (signal - 1U));
    GuestSignalInfo info;
    info.sender = process_.pid;
    info.sender_uid = process_.uid;
    const auto handler = signal_actions_[signal][0];
    if (handler != darwin::signal::default_action &&
        handler != darwin::signal::ignore_action) {
        // A handler with no room for its frame: XNU's sendsig gives up and
        // the process dies of SIGILL.
        if (!send_signal_frame(cpu, signal, info))
            exit_process(0, signal_illegal);
    } else {
        // The disposition changed while it was pending: take it as it is now.
        static_cast<void>(deliver_signal(signal));
    }
    // One frame per return to user mode; the next one stacks on it when the
    // thread comes back.
}

void CompatibilityKernel::start_thread_signals(std::size_t processor,
    std::optional<std::size_t> creator, bool workqueue)
{
    // kern_sig.c: the signals a thread raises itself, which a workqueue thread
    // still takes; every other one is blocked for it.
    constexpr std::uint32_t synchronous =
        (1U << (4U - 1U)) | (1U << (5U - 1U)) | (1U << (6U - 1U)) |
        (1U << (7U - 1U)) | (1U << (8U - 1U)) | (1U << (10U - 1U)) |
        (1U << (11U - 1U)) | (1U << (12U - 1U)) | (1U << (13U - 1U));
    std::uint32_t mask = 0;
    if (workqueue) {
        mask = ~(synchronous | unblockable);
    } else if (creator) {
        mask = signal_mask(*creator);
    }
    thread_signal_masks_[processor] = mask;
    thread_pending_signals_.erase(processor);
    alternate_signal_stacks_.erase(processor);
}

void CompatibilityKernel::end_thread_signals(std::size_t processor)
{
    thread_signal_masks_.erase(processor);
    thread_pending_signals_.erase(processor);
    alternate_signal_stacks_.erase(processor);
}

} // namespace shade
