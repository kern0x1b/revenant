// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/darwin_kqueue_abi.hpp"
#include "kernel/kernel.hpp"
#include "kernel/kevent_wire.hpp"
#include "support.hpp"
#include <algorithm>
#include <limits>
#include <mutex>
#include <string>

namespace shade {
void CompatibilityKernel::dispatch_bsd_kqueue(Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    switch (number) {
    case 362: { // kqueue
        const auto fd = allocate_file_descriptor();
        if (!fd) {
            bsd_error(cpu, 24); // EMFILE
            return;
        }
        virtual_descriptors_.emplace(*fd, "kqueue");
        kqueues_.emplace(*fd, std::vector<KeventRegistration> { });
        bsd_success(cpu, *fd);
        return;
    }
    case 363: // kevent
    case 369: { // kevent64
        const bool extended = number == 369U;
        const KeventWireFormat wire { extended };
        const auto timeout_address = registers[extended ? 6U : 5U];
        const auto fd = registers[0];
        const auto queue = kqueues_.find(fd);
        if (queue == kqueues_.end() || registers[2] > 4096 ||
            registers[4] > 4096) {
            bsd_error(cpu, queue == kqueues_.end()
                               ? bsd_support::bad_file_descriptor
                               : bsd_support::invalid_argument);
            return;
        }
        const auto valid_range = [&](std::uint32_t address, std::uint32_t count,
                                     MemoryPermission permission) {
            const auto bytes = static_cast<std::uint64_t>(count) * wire.size();
            return count == 0U ||
                   (address != 0U &&
                       static_cast<std::uint64_t>(address) + bytes <=
                           (1ULL << 32U) &&
                       memory_.accessible(address,
                           static_cast<std::uint32_t>(bytes), permission));
        };
        if (!valid_range(registers[1], registers[2], MemoryPermission::Read) ||
            !valid_range(registers[3], registers[4], MemoryPermission::Write)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (registers[2] != 0U)
            shared_state_->note_io_event_transition();
        std::uint32_t receipts_written = 0;
        const auto write_receipt = [&](KeventValue value) {
            if (receipts_written >= registers[4] || registers[3] == 0)
                return false;
            value.flags |= darwin::kqueue::event_error;
            value.data = 0;
            if (!wire.write(memory_,
                    registers[3] + receipts_written * wire.size(), value))
                return false;
            ++receipts_written;
            return true;
        };
        for (std::uint32_t index = 0; index < registers[2]; ++index) {
            const auto value =
                wire.read(memory_, registers[1] + index * wire.size());
            if (!value) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto ident = value->ident;
            const auto flags = value->flags;
            const auto filter_flags = value->filter_flags;
            const auto data = value->data;
            const auto user_data = value->user_data;
            const auto signed_filter = value->filter;
            // File descriptors, task IDs and Mach names remain natural-sized.
            // Timer/user identifiers and opaque cookies retain all 64 bits.
            if (signed_filter != darwin::kqueue::filter_user &&
                signed_filter != darwin::kqueue::filter_timer &&
                ident > UINT32_MAX) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            auto found = std::find_if(queue->second.begin(),
                queue->second.end(), [&](const auto& registration) {
                    return registration.ident == ident &&
                           registration.filter == signed_filter;
                });
            if ((flags & darwin::kqueue::event_delete) != 0) {
                if (found != queue->second.end())
                    queue->second.erase(found);
                if ((flags & darwin::kqueue::event_receipt) != 0 &&
                    !write_receipt(*value)) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                continue;
            }
            if ((flags & darwin::kqueue::event_add) != 0) {
                KeventRegistration registration {
                    ident,
                    signed_filter,
                    flags,
                    filter_flags,
                    data,
                    user_data,
                };
                registration.extension = value->extension;
                if (signed_filter == darwin::kqueue::filter_timer) {
                    registration.timer = KeventTimer::create(
                        data, filter_flags, shared_state_->clock,
                        (flags & darwin::kqueue::event_one_shot) != 0U);
                    if (!registration.timer) {
                        bsd_error(cpu, bsd_support::invalid_argument);
                        return;
                    }
                    registration.flags |= darwin::kqueue::event_clear;
                    if ((filter_flags & darwin::kqueue::timer_note_absolute) != 0U)
                        registration.flags |= darwin::kqueue::event_one_shot;
                }
                registration.enabled =
                    (flags & darwin::kqueue::event_disable) == 0U;
                if (signed_filter == darwin::kqueue::filter_vnode) {
                    if (found != queue->second.end()) {
                        registration.vnode_watch = found->vnode_watch;
                    } else if (const auto file = file_descriptors_.find(
                                   static_cast<std::uint32_t>(ident));
                        file != file_descriptors_.end()) {
                        registration.vnode_watch.emplace(file->second,
                            *shared_state_->guest_file_generation_registry);
                    }
                }
                if (signed_filter == darwin::kqueue::filter_user) {
                    registration.user_triggered =
                        (flags & darwin::kqueue::event_trigger) != 0U ||
                        (filter_flags & darwin::kqueue::user_note_trigger) !=
                            0U;
                    registration.filter_flags =
                        filter_flags & darwin::kqueue::user_note_flags_mask;
                }
                if (signed_filter == darwin::kqueue::filter_process) {
                    std::uint64_t current_exec_generation = 0;
                    std::uint64_t current_exit_generation = 0;
                    {
                        std::lock_guard lock { shared_state_->mach_mutex };
                        const auto process =
                            shared_state_->process_kevent_states.find(
                                static_cast<std::uint32_t>(ident));
                        if (process !=
                            shared_state_->process_kevent_states.end()) {
                            current_exec_generation =
                                process->second.exec_generation;
                            current_exit_generation =
                                process->second.exit_generation;
                        }
                    }
                    if (found != queue->second.end()) {
                        // EV_ADD modifies an existing knote. Preserve the
                        // consumed position of notes that remain selected so an
                        // edge arriving before the update remains pending. A
                        // newly selected note starts at the current generation
                        // and does not synthesize historical activity.
                        const auto retains_exec_note =
                            (found->filter_flags &
                                darwin::kqueue::process_note_exec) != 0U &&
                            (filter_flags &
                                darwin::kqueue::process_note_exec) != 0U;
                        const auto retains_exit_note =
                            (found->filter_flags &
                                darwin::kqueue::process_note_exit) != 0U &&
                            (filter_flags &
                                darwin::kqueue::process_note_exit) != 0U;
                        registration.process_exec_generation =
                            retains_exec_note ? found->process_exec_generation
                                              : current_exec_generation;
                        registration.process_exit_generation =
                            retains_exit_note ? found->process_exit_generation
                                              : current_exit_generation;
                    } else {
                        registration.process_exec_generation =
                            current_exec_generation;
                        registration.process_exit_generation =
                            current_exit_generation;
                    }
                }
                if (found == queue->second.end()) {
                    queue->second.push_back(registration);
                } else {
                    *found = registration;
                }
            } else if (found != queue->second.end()) {
                if (signed_filter == darwin::kqueue::filter_user) {
                    if ((flags & darwin::kqueue::event_trigger) != 0U ||
                        (filter_flags & darwin::kqueue::user_note_trigger) !=
                            0U) {
                        found->user_triggered = true;
                        // EV_CLEAR consumes a user event's current trigger,
                        // not future NOTE_TRIGGER edges with identical data.
                        found->clear_delivered = false;
                    }
                    const auto operand =
                        filter_flags & darwin::kqueue::user_note_flags_mask;
                    switch (filter_flags &
                            darwin::kqueue::user_note_ff_control_mask) {
                    case darwin::kqueue::user_note_ff_and:
                        found->filter_flags &= operand;
                        break;
                    case darwin::kqueue::user_note_ff_or:
                        found->filter_flags |= operand;
                        break;
                    case darwin::kqueue::user_note_ff_copy:
                        found->filter_flags = operand;
                        break;
                    default:
                        break;
                    }
                    found->data = data;
                    found->user_data = user_data;
                }
                if ((flags & darwin::kqueue::event_disable) != 0) {
                    found->enabled = false;
                    found->flags |= darwin::kqueue::event_disable;
                } else if ((flags & darwin::kqueue::event_enable) != 0) {
                    found->enabled = true;
                    found->flags &= ~darwin::kqueue::event_disable;
                }
            }
            if ((flags & darwin::kqueue::event_receipt) != 0 &&
                !write_receipt(*value)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
        }
        if (receipts_written != 0) {
            bsd_success(cpu, receipts_written);
            return;
        }
        std::optional<std::uint64_t> timeout_deadline;
        bool poll_only = false;
        if (timeout_address != 0) {
            const auto seconds_word =
                memory_.read32(timeout_address +
                               darwin::kqueue::arm32_timespec::seconds_offset);
            const auto nanoseconds_word = memory_.read32(
                timeout_address +
                darwin::kqueue::arm32_timespec::nanoseconds_offset);
            if (!seconds_word || !nanoseconds_word) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto seconds = static_cast<std::int32_t>(*seconds_word);
            const auto nanoseconds =
                static_cast<std::int32_t>(*nanoseconds_word);
            if (seconds < 0 || nanoseconds < 0 ||
                static_cast<std::uint64_t>(nanoseconds) >=
                    darwin::kqueue::nanoseconds_per_second) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto duration = static_cast<std::uint64_t>(seconds) *
                                      darwin::kqueue::nanoseconds_per_second +
                                  static_cast<std::uint64_t>(nanoseconds);
            poll_only = duration == 0;
            const auto now = shared_state_->clock.now();
            timeout_deadline =
                duration > std::numeric_limits<std::uint64_t>::max() - now
                    ? std::numeric_limits<std::uint64_t>::max()
                    : now + duration;
        }
        if (registers[4] != 0) {
            const auto ready =
                collect_ready_kevents(cpu.processor_id(), fd, registers[3], registers[4], extended);
            if (!ready) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (*ready != 0) {
                bsd_success(cpu, *ready);
                return;
            }
        }
        if (registers[4] == 0) {
            bsd_success(cpu, 0);
            return;
        }
        if (poll_only) {
            bsd_success(cpu, 0);
            return;
        }
        process_.waiting_for_events = true;
        pending_kevents_[cpu.processor_id()] = PendingKevent { fd, registers[3],
            registers[4], cpu.processor_id(), timeout_deadline, extended };
        output_.write(
            "[network] kevent wait pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) +
            " registrations=" + std::to_string(queue->second.size()) + "\n");
        bsd_success(cpu, 0);
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return;
    }
    }
}
} // namespace shade
