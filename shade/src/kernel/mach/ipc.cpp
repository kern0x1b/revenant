// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Deliver queued Mach messages and coordinate blocked receivers and
// port-set readiness.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/mach_msg.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_mqueue.c

#include "mach/bootstrap_mig_ids.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/graphics_services_input.hpp"
#include "kernel/kernel.hpp"
#include "kernel/kernel_clock.hpp"
#include "kernel/kernel_iokit.hpp"
#include "kernel/kernel_mach_ipc.hpp"
#include "kernel/kernel_network.hpp"
#include "kernel/mach_clock_abi.hpp"
#include "mach/mach_host_mig_ids.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "kernel/mach_scheduler_abi.hpp"
#include "kernel/mach_thread_policy_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "foundation/performance.hpp"
#include "mach/task_mig_ids.hpp"
#include "mach/thread_act_mig_ids.hpp"
#include "mach/vm_map_mig_ids.hpp"
#include "mach/xnu_mig_adapter.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <optional>
#include <span>
#include <string_view>
#include <utility>
#include <vector>

#include "support.hpp"

namespace shade {

using namespace mach_support;

namespace {

    [[nodiscard]] bool task_owns_mach_right_locked(
        const KernelSharedState& state, std::uint32_t task,
        std::uint32_t object, xnu::ipc::Right right)
    {
        return state.mach_namespaces.owns_right(task, object, right);
    }

    [[nodiscard]] bool pending_mach_receive_is_usable_locked(
        const KernelSharedState& state, std::uint32_t task,
        const PendingMachReceive& pending)
    {
        if (!pending.receive_object)
            return false;

        const auto object = *pending.receive_object;
        if (pending.receive_is_port_set) {
            return state.mach_port_sets.contains(object) &&
                   task_owns_mach_right_locked(
                       state, task, object, xnu::ipc::Right::PortSet);
        }

        // A direct receiver remains attached to the cached port object across a
        // rename and later port-set insertion. It must stop only when the
        // receive right is gone or the object is otherwise invalidated.
        return state.mach_port_objects.contains(object) &&
               task_owns_mach_right_locked(
                   state, task, object, xnu::ipc::Right::Receive);
    }

} // namespace

bool CompatibilityKernel::deliver_pending_mach(Cpu& cpu)
{
    std::lock_guard kernel_lock { mutex_ };
    const auto delivered = deliver_pending_mach_if_ready_locked(cpu, true);
    if (delivered)
        note_timer_deadline_transition();
    return delivered;
}

std::optional<std::size_t>
CompatibilityKernel::display_vsync_receiver_processor()
{
    std::lock_guard kernel_lock { mutex_ };
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    for (const auto& [connection_object, registration] :
        shared_state_->iokit_display_vsync) {
        static_cast<void>(connection_object);
        if (!registration.enabled || registration.owner_pid != process_.pid)
            continue;
        if (const auto receiver = preferred_pending_mach_receiver_locked(
                registration.notification_port)) {
            return receiver;
        }
    }
    return std::nullopt;
}

std::optional<std::size_t>
CompatibilityKernel::display_vsync_dependency_processor()
{
    std::lock_guard kernel_lock { mutex_ };
    std::lock_guard mach_lock { shared_state_->mach_mutex };

    std::optional<std::size_t> delivered_receiver;
    for (const auto& [connection_object, registration] :
        shared_state_->iokit_display_vsync) {
        static_cast<void>(connection_object);
        if (!registration.enabled || registration.owner_pid != process_.pid ||
            registration.callback_sequence >= registration.sequence) {
            continue;
        }
        if (const auto receiver = preferred_pending_mach_receiver_locked(
                registration.notification_port)) {
            return receiver;
        }
        if (!delivered_receiver && registration.last_receiver_processor &&
            registration.receiver_sequence > registration.callback_sequence) {
            delivered_receiver =
                static_cast<std::size_t>(*registration.last_receiver_processor);
        }
    }
    return delivered_receiver;
}

std::optional<std::size_t>
CompatibilityKernel::display_vsync_callback_processor()
{
    std::lock_guard kernel_lock { mutex_ };
    std::lock_guard mach_lock { shared_state_->mach_mutex };

    std::optional<std::size_t> fallback;
    for (const auto& [connection_object, registration] :
        shared_state_->iokit_display_vsync) {
        static_cast<void>(connection_object);
        if (!registration.enabled || registration.owner_pid != process_.pid ||
            !registration.last_callback_processor) {
            continue;
        }
        // Prefer the registration whose receive is currently pending. Multiple
        // display connections can coexist during a foreground handoff; this
        // keeps a stale callback observation from winning over the active one.
        if (preferred_pending_mach_receiver_locked(
                registration.notification_port)) {
            return static_cast<std::size_t>(
                *registration.last_callback_processor);
        }
        if (!fallback) {
            fallback =
                static_cast<std::size_t>(*registration.last_callback_processor);
        }
    }
    return fallback;
}

std::optional<std::pair<std::size_t, std::uint64_t>>
CompatibilityKernel::display_vsync_inflight_callback_dependency()
{
    std::lock_guard kernel_lock { mutex_ };
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    for (const auto& [connection_object, registration] :
        shared_state_->iokit_display_vsync) {
        static_cast<void>(connection_object);
        if (registration.enabled && registration.owner_pid == process_.pid &&
            registration.last_callback_processor &&
            registration.swap_sequence < registration.callback_sequence) {
            return std::pair { static_cast<std::size_t>(
                                   *registration.last_callback_processor),
                registration.callback_sequence };
        }
    }
    return std::nullopt;
}

bool CompatibilityKernel::display_vsync_callback_pending()
{
    std::lock_guard kernel_lock { mutex_ };
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    return std::any_of(shared_state_->iokit_display_vsync.begin(),
        shared_state_->iokit_display_vsync.end(), [this](const auto& entry) {
            const auto& registration = entry.second;
            // A queued notification is not callback work yet. Its exact
            // blocked Mach receiver is handled by
            // display_vsync_dependency_processor(); using the previous
            // callback processor before this pulse is received can starve the
            // run-loop dependency that will consume it. The callback becomes
            // pending only after successful Mach copyout establishes the
            // receiver watermark.
            return registration.enabled &&
                   registration.owner_pid == process_.pid &&
                   registration.callback_sequence <
                       registration.receiver_sequence;
        });
}

std::optional<std::size_t> CompatibilityKernel::pending_mach_receiver_processor(
    std::uint32_t object)
{
    std::lock_guard kernel_lock { mutex_ };
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    return preferred_pending_mach_receiver_locked(object);
}

bool CompatibilityKernel::deliver_pending_mach_if_ready_locked(
    Cpu& cpu, bool waking_blocked_receiver)
{
    const auto pending = pending_mach_receives_.find(cpu.processor_id());
    if (pending == pending_mach_receives_.end())
        return false;

    // Every enqueue, receive-right invalidation and port-set topology change
    // advances this generation while holding mach_mutex. If neither it nor the
    // Guest deadline changed, the previous empty-queue result is still valid;
    // avoid taking the global IPC lock and walking the task namespace for every
    // host scheduler pass.
    const auto queue_generation =
        shared_state_->mach_queue_generation_snapshot();
    if (pending->second.receive_object &&
        pending->second.observed_queue_generation == queue_generation &&
        (!pending->second.deadline ||
            shared_state_->clock.now() < *pending->second.deadline)) {
        return false;
    }

    // A blocked receive is attached to the object selected at receive start.
    // XNU wakes it with MACH_RCV_PORT_CHANGED when that queue is destroyed or
    // the receive right is lost; adding a set link keeps the direct waiter on
    // the original object. A later reuse of the original name must never
    // redirect the waiter to a different object.
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    if (!pending_mach_receive_is_usable_locked(
            *shared_state_, process_.pid, pending->second)) {
        cpu.registers()[0] = darwin::mach_message::receive_port_changed;
        pending_mach_receives_.erase(pending);
        process_.waiting_for_events = !pending_mach_receives_.empty();
        cpu.clear_halt();
        return true;
    }
    return deliver_pending_mach_locked(cpu, waking_blocked_receiver);
}

std::optional<std::size_t>
CompatibilityKernel::preferred_pending_mach_receiver_locked(
    std::uint32_t queued_port)
{
    struct Candidate {
        std::uint64_t port_queue_sequence { };
        std::uint64_t receiver_sequence { };
        std::size_t processor { };
    };
    std::optional<Candidate> selected;
    const auto consider = [&](Candidate candidate) {
        if (!selected ||
            candidate.port_queue_sequence < selected->port_queue_sequence ||
            (candidate.port_queue_sequence == selected->port_queue_sequence &&
                candidate.receiver_sequence < selected->receiver_sequence)) {
            selected = candidate;
        }
    };

    // XNU represents a receive port as a compound FIFO wait queue. Direct
    // waiters are queue elements, while each containing port set contributes a
    // persistent link whose own FIFO contains that set's waiters. Posting to
    // the port walks those elements recursively and wakes the first receiver.
    // Reconstruct that choice here so host CPU polling order cannot redirect a
    // shared-port message to a later port set.
    for (auto& [processor, pending] : pending_mach_receives_) {
        if (!pending_mach_receive_is_usable_locked(
                *shared_state_, process_.pid, pending)) {
            continue;
        }
        if (!pending.receive_is_port_set &&
            *pending.receive_object == queued_port) {
            consider(Candidate { pending.wait_queue_sequence,
                pending.wait_queue_sequence, processor });
        }
    }

    if (const auto links =
            shared_state_->mach_port_set_links_by_member.find(queued_port);
        links != shared_state_->mach_port_set_links_by_member.end()) {
        for (const auto& link : links->second) {
            std::optional<Candidate> set_receiver;
            for (const auto& [processor, pending] : pending_mach_receives_) {
                if (!pending.receive_is_port_set || !pending.receive_object ||
                    *pending.receive_object != link.set_object) {
                    continue;
                }
                if (!pending_mach_receive_is_usable_locked(
                        *shared_state_, process_.pid, pending)) {
                    continue;
                }
                const Candidate candidate { link.wait_queue_sequence,
                    pending.wait_queue_sequence, processor };
                if (!set_receiver || candidate.receiver_sequence <
                                         set_receiver->receiver_sequence) {
                    set_receiver = candidate;
                }
            }
            if (set_receiver) {
                consider(*set_receiver);
            }
        }
    }
    if (!selected)
        return std::nullopt;
    return selected->processor;
}

bool CompatibilityKernel::deliver_pending_mach_locked(
    Cpu& cpu, bool waking_blocked_receiver)
{
    const auto pending = pending_mach_receives_.find(cpu.processor_id());
    if (pending == pending_mach_receives_.end())
        return false;
    const auto outcome = receive_mach_message_locked(
        pending->second, true, waking_blocked_receiver);
    if (!outcome)
        return false;
    cpu.registers()[0] = outcome->status;
    pending_mach_receives_.erase(pending);
    process_.waiting_for_events =
        outcome->status == darwin::mach_message::receive_port_changed &&
        !pending_mach_receives_.empty();
    cpu.clear_halt();
    return true;
}

std::optional<CompatibilityKernel::MachReceiveResult>
CompatibilityKernel::receive_mach_message_locked(PendingMachReceive& receive,
    bool queued_receiver, bool waking_blocked_receiver)
{
    MachReceiveResult outcome;
    if (!pending_mach_receive_is_usable_locked(
            *shared_state_, process_.pid, receive)) {
        outcome.status = darwin::mach_message::receive_port_changed;
        return outcome;
    }
    auto queued_port = *receive.receive_object;
    auto queue = shared_state_->mach_queues.end();
    bool has_visible_message = false;
    std::optional<std::uint32_t> selected_port_set;
    const auto select_queue = [&](std::uint32_t candidate_port) {
        const auto candidate = shared_state_->mach_queues.find(candidate_port);
        if (candidate == shared_state_->mach_queues.end() ||
            candidate->second.empty()) {
            return false;
        }
        has_visible_message = true;
        const auto receiver =
            preferred_pending_mach_receiver_locked(candidate_port);
        if (queued_receiver ? (!receiver || *receiver != receive.processor)
                            : receiver.has_value())
            return false;
        queued_port = candidate_port;
        queue = candidate;
        return true;
    };

    if (!select_queue(queued_port)) {
        const auto port_set_object = queued_port;
        if (const auto port_set =
                shared_state_->mach_port_set_preposts.find(port_set_object);
            port_set != shared_state_->mach_port_set_preposts.end()) {
            for (const auto member : port_set->second) {
                if (select_queue(member)) {
                    selected_port_set = port_set_object;
                    break;
                }
            }
        }
    }
    if (queue == shared_state_->mach_queues.end() || queue->second.empty()) {
        if (receive.deadline &&
            shared_state_->clock.now() >= *receive.deadline) {
            outcome.status = darwin::mach_message::receive_timed_out;
            return outcome;
        }
        // If another FIFO waiter owns an already-queued message, do not cache
        // the current generation as empty. Once that waiter consumes the front
        // item, this receiver may become eligible for the next item without an
        // enqueue.
        if (!has_visible_message) {
            receive.observed_queue_generation =
                shared_state_->mach_queue_generation_snapshot();
        }
        return std::nullopt;
    }

    const auto& pending_message = queue->second.front();
    if (selected_port_set) {
        // XNU's prepost linkage is a FIFO. Keep the selected member at the
        // tail while the message is being copied out so the next receive on
        // this set starts at the following ready source.
        const auto preposts =
            shared_state_->mach_port_set_preposts.find(*selected_port_set);
        if (preposts != shared_state_->mach_port_set_preposts.end() &&
            preposts->second.size() > 1U) {
            const auto member = std::find(preposts->second.begin(),
                preposts->second.end(), queued_port);
            if (member != preposts->second.end()) {
                const auto selected_member = *member;
                preposts->second.erase(member);
                preposts->second.push_back(selected_member);
            }
        }
    }
    const auto sequence_number =
        shared_state_->mach_port_objects.sequence_number(queued_port)
            .value_or(0);
    const auto context = shared_state_->mach_port_contexts.find(queued_port);
    auto received = mach_ipc::prepare_received_message(
        pending_message, queued_port, receive.options, sequence_number,
        context != shared_state_->mach_port_contexts.end() ? context->second : 0U,
        shared_state_->darwin_abi.mach_port_context);
    if (!received) {
        auto discarded = std::move(queue->second.front());
        queue->second.pop_front();
        shared_state_->note_mach_message_dequeued_locked(queued_port);
        discard_mach_message_rights_locked(*shared_state_, discarded);
        outcome.status = 0x10004008U; // MACH_RCV_INVALID_DATA
        return outcome;
    }
    outcome.message_size = static_cast<std::uint32_t>(received->message_size);
    if (received->bytes.size() > receive.receive_size) {
        const auto report_only =
            (receive.options &
                darwin::mach_message::option_receive_large) != 0U;
        if (report_only) {
            // MACH_RCV_LARGE leaves the message queued and reports the
            // message-proper size through the fake header's msgh_size field.
            // libdispatch and the old GraphicsServices receiver use that
            // value to grow their buffer before retrying the same message.
            const auto capacity = receive.receive_size;
            if (capacity >=
                    darwin::mig_wire::header_remote_port_offset &&
                !memory_.write32(receive.message_address +
                                     darwin::mig_wire::header_size_offset,
                    static_cast<std::uint32_t>(received->message_size))) {
                outcome.status =
                    darwin::mach_message::receive_invalid_data;
            } else {
                outcome.status = darwin::mach_message::receive_too_large;
            }
        } else {
            // Without MACH_RCV_LARGE XNU consumes and destroys the oversized
            // message, returning only the receive error. Leaving it queued
            // would make a caller retry forever with the same capacity.
            auto discarded = std::move(queue->second.front());
            queue->second.pop_front();
            shared_state_->note_mach_message_dequeued_locked(queued_port);
            discard_mach_message_rights_locked(*shared_state_, discarded);
            outcome.status = darwin::mach_message::receive_too_large;
        }
        return outcome;
    }

    // A queued message keeps the semantic right in its sidecar, but the
    // backing ipc_port may have been retired while the receiver was asleep.
    // Never let copyout recreate a live Send/Receive name for such an object.
    // Send-like rights can still be represented as a dead name (the equivalent
    // of ipc_right_copyout on a dead port); receive rights cannot be recovered
    // once their port object is gone and invalidate the queued message.
    const auto copyout_received_right =
        [&](std::uint32_t object,
            xnu::ipc::Right right) -> std::optional<std::uint32_t> {
        if (object == xnu::ipc::null_name)
            return std::nullopt;
        if (!shared_state_->mach_port_objects.contains(object)) {
            if (right != xnu::ipc::Right::Send &&
                right != xnu::ipc::Right::SendOnce) {
                return std::nullopt;
            }
            // Directly retired legacy objects may not have gone through
            // terminate_receive_object_locked. Normalize any stale namespace
            // send entries before installing the dead-name result so a PID/name
            // reuse cannot observe a resurrected Send right.
            static_cast<void>(
                shared_state_->mach_namespaces.mark_object_dead(object));
            return shared_state_->mach_namespaces.copyout(process_.pid, object,
                xnu::ipc::type_mask(xnu::ipc::Right::DeadName));
        }
        return shared_state_->mach_namespaces.copyout(
            process_.pid, object, xnu::ipc::type_mask(right));
    };

    const auto discard_queued_message = [&] {
        auto discarded = std::move(queue->second.front());
        queue->second.pop_front();
        shared_state_->note_mach_message_dequeued_locked(queued_port);
        discard_mach_message_rights_locked(*shared_state_, discarded);
    };
    const auto fail_receive = [&](std::uint32_t error) {
        discard_queued_message();
        outcome.status = error;
        return outcome;
    };

    if (!shared_state_->mach_port_objects.contains(queued_port)) {
        // A stale queue entry must not be copied out through a dead
        // destination.
        return fail_receive(0x10004008U); // MACH_RCV_INVALID_DATA
    }

    const auto send_bits = read_little_word(pending_message.bytes, 0);
    const auto sender_reply_name = read_little_word(pending_message.bytes, 12);
    std::optional<std::uint32_t> reply_object;
    std::optional<xnu::ipc::Right> reply_right;
    if (sender_reply_name != xnu::ipc::null_name) {
        reply_object = pending_message.reply_object
                           ? pending_message.reply_object
                           : resolve_message_object(*shared_state_,
                                 pending_message.sender_pid, sender_reply_name);
        reply_right = pending_message.reply_right
                          ? pending_message.reply_right
                          : right_for_disposition((send_bits >> 8U) & 0xffU);
        // Preflight receive rights before destination copyout. This keeps a
        // malformed/dead transfer from partially mutating the receiver's
        // namespace and then failing halfway through delivery.
        if (reply_right &&
            ((!reply_object) || (*reply_right == xnu::ipc::Right::Receive &&
                                    !shared_state_->mach_port_objects.contains(
                                        *reply_object)))) {
            return fail_receive(0x10004008U); // MACH_RCV_INVALID_DATA
        }
    }
    for (const auto& transfer : pending_message.port_transfers) {
        if (transfer.right == xnu::ipc::Right::Receive &&
            !shared_state_->mach_port_objects.contains(transfer.object)) {
            return fail_receive(0x10004008U); // MACH_RCV_INVALID_DATA
        }
    }

    const auto destination_name =
        shared_state_->mach_namespaces.copyout(process_.pid, queued_port,
            xnu::ipc::type_mask(xnu::ipc::Right::Receive));
    if (!destination_name) {
        outcome.status = 0x10004008U;
        return outcome;
    }
    // Mach copyout exposes the sender's reply capability in msgh_remote_port;
    // the receive name is returned in msgh_local_port.  This is the wire-level
    // swap that lets a MIG server reply using request.msgh_remote_port.
    write_little_word(received->bytes, 12, *destination_name);

    if (sender_reply_name != xnu::ipc::null_name) {
        if (reply_right) {
            if (!reply_object) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            const auto reply_name =
                copyout_received_right(*reply_object, *reply_right);
            if (!reply_name) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            write_little_word(received->bytes, 8, *reply_name);
            if (*reply_right == xnu::ipc::Right::Send) {
                release_inflight_send_right_locked(
                    *shared_state_, *reply_object);
            }
        }
    }

    // Bootstrap lookup bookkeeping belongs to the launchd reply, not the
    // outgoing request. The destination of this queued response is the global
    // reply-port object recorded with the lookup request; the optional
    // reply_object field describes the reply right carried by the message and
    // is not the lookup destination.
    if (pending_message.sender_pid == 1U) {
        const auto service_resolution =
            graphics_services_input::record_bootstrap_reply_locked(
                *shared_state_, pending_message.destination,
                pending_message.port_transfers, process_.pid);
        if (service_resolution.object != 0 &&
            (service_resolution.application_event_port ||
                service_resolution.service_name ==
                    graphics_services_input::system_event_service)) {
            output_.write(
                "[input] resolved service=" + service_resolution.service_name +
                " object=" + std::to_string(service_resolution.object) +
                " flushed=" +
                std::to_string(service_resolution.flushed_events) +
                (service_resolution.application_event_port
                        ? " application-event-port"
                        : "") +
                "\n");
        }
    }

    if ((send_bits & 0x80000000U) != 0 && pending_message.bytes.size() >= 28U) {
        const auto descriptor_count =
            read_little_word(pending_message.bytes, 24);
        for (std::uint32_t index = 0; index < descriptor_count; ++index) {
            const auto offset = 28U + static_cast<std::size_t>(index) * 12U;
            if (offset + 12U > pending_message.bytes.size())
                break;
            const auto descriptor_word =
                read_little_word(pending_message.bytes, offset + 8U);
            if ((descriptor_word >> darwin::mig_wire::descriptor_type_shift) !=
                0) {
                continue;
            }
            const auto disposition =
                (descriptor_word >>
                    darwin::mig_wire::descriptor_disposition_shift) &
                0xffU;
            const auto sender_name =
                read_little_word(pending_message.bytes, offset);
            if (sender_name == xnu::ipc::null_name ||
                sender_name == xnu::ipc::dead_name) {
                // ipc_kmsg_copyout always exposes a port descriptor using its
                // receive-side type, including descriptors that carry
                // MACH_PORT_NULL or MACH_PORT_DEAD. Neither sentinel owns a
                // capability. MIG validates the descriptor type before
                // looking at the name, so retaining COPY_SEND/MAKE_SEND here
                // incorrectly rejects a valid null result.
                write_little_word(received->bytes, offset + 8U,
                    darwin::mig_wire::replace_descriptor_disposition(
                        descriptor_word,
                        darwin::mig_wire::received_port_disposition(
                            disposition)));
                continue;
            }
            const auto captured =
                std::find_if(pending_message.port_transfers.begin(),
                    pending_message.port_transfers.end(),
                    [&](const auto& transfer) {
                        return transfer.descriptor_offset == offset &&
                               !transfer.array_index;
                    });
            const auto right = captured != pending_message.port_transfers.end()
                                   ? std::optional { captured->right }
                                   : right_for_disposition(disposition);
            if (!right)
                continue;
            const auto object =
                captured != pending_message.port_transfers.end()
                    ? std::optional { captured->object }
                    : resolve_message_object(*shared_state_,
                          pending_message.sender_pid, sender_name);
            if (!object) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            const auto receiver_name = copyout_received_right(*object, *right);
            if (!receiver_name) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            write_little_word(received->bytes, offset, *receiver_name);
            write_little_word(received->bytes, offset + 8U,
                darwin::mig_wire::replace_descriptor_disposition(
                    descriptor_word,
                    darwin::mig_wire::received_port_disposition(disposition)));
            if (*right == xnu::ipc::Right::Send) {
                release_inflight_send_right_locked(*shared_state_, *object);
            }
            if (*right == xnu::ipc::Right::Receive) {
                static_cast<void>(
                    shared_state_->remove_mach_port_set_member_from_all_locked(
                        *object));
                static_cast<void>(
                    shared_state_->mach_port_objects.set_receive_owner(
                        *object, process_.pid));
                if (captured == pending_message.port_transfers.end() &&
                    pending_message.sender_pid != 0) {
                    static_cast<void>(
                        shared_state_->mach_namespaces.remove_type(
                            pending_message.sender_pid, sender_name,
                            xnu::ipc::type_mask(
                                xnu::ipc::Right::Receive)));
                }
            }
        }
    }

    for (const auto& array : pending_message.ool_port_arrays) {
        if (array.descriptor_offset + darwin::mig_wire::descriptor_size >
                received->bytes.size() ||
            array.count > maximum_message_io / darwin::mig_wire::word_size) {
            outcome.status = 0x10004008U;
            return outcome;
        }
        const auto byte_size = array.count * darwin::mig_wire::word_size;
        std::vector<std::byte> names(byte_size);
        for (const auto element : array.dead_elements) {
            if (element >= array.count) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            write_little_word(names, element * darwin::mig_wire::word_size,
                xnu::ipc::dead_name);
        }
        for (const auto& transfer : pending_message.port_transfers) {
            if (transfer.descriptor_offset != array.descriptor_offset ||
                !transfer.array_index) {
                continue;
            }
            if (*transfer.array_index >= array.count) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            const auto receiver_name =
                copyout_received_right(transfer.object, transfer.right);
            if (!receiver_name) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            write_little_word(names,
                *transfer.array_index * darwin::mig_wire::word_size,
                *receiver_name);
            if (transfer.right == xnu::ipc::Right::Send) {
                release_inflight_send_right_locked(
                    *shared_state_, transfer.object);
            } else if (transfer.right == xnu::ipc::Right::Receive) {
                static_cast<void>(
                    shared_state_->remove_mach_port_set_member_from_all_locked(
                        transfer.object));
                static_cast<void>(
                    shared_state_->mach_port_objects.set_receive_owner(
                        transfer.object, process_.pid));
            }
        }
        const auto descriptor_word =
            read_little_word(received->bytes, array.descriptor_offset + 8U);
        const auto disposition =
            (descriptor_word >>
                darwin::mig_wire::descriptor_disposition_shift) &
            0xffU;
        write_little_word(received->bytes, array.descriptor_offset + 8U,
            darwin::mig_wire::replace_descriptor_disposition(descriptor_word,
                darwin::mig_wire::received_port_disposition(disposition)));

        std::uint32_t copied_address = 0;
        if (!names.empty()) {
            const auto mapped_size = static_cast<std::uint32_t>(
                (names.size() + AddressSpace::page_size - 1U) &
                ~(static_cast<std::size_t>(AddressSpace::page_size) - 1U));
            const auto free_region =
                find_free_guest_region(memory_, ool_receive_base, mapped_size);
            if (!free_region ||
                !memory_.map(*free_region, mapped_size,
                    MemoryPermission::Read | MemoryPermission::Write) ||
                !memory_.copy_in(*free_region, names)) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            copied_address = *free_region;
        }
        write_little_word(
            received->bytes, array.descriptor_offset, copied_address);
        output_.write(
            "[mach] ool-ports-copy receiver=" + std::to_string(process_.pid) +
            " count=" + std::to_string(array.count) +
            " address=" + std::to_string(copied_address) + "\n");
    }

    for (const auto& payload : pending_message.ool_payloads) {
        if (payload.descriptor_offset + 4U > received->bytes.size()) {
            outcome.status = 0x10004008U; // MACH_RCV_INVALID_DATA
            return outcome;
        }
        std::uint32_t copied_address = 0;
        if (!payload.bytes.empty()) {
            const auto mapped_size = static_cast<std::uint32_t>(
                (payload.bytes.size() + AddressSpace::page_size - 1U) &
                ~(static_cast<std::size_t>(AddressSpace::page_size) - 1U));
            const auto free_region =
                find_free_guest_region(memory_, ool_receive_base, mapped_size);
            if (!free_region ||
                !memory_.map(*free_region, mapped_size,
                    MemoryPermission::Read | MemoryPermission::Write) ||
                !memory_.copy_in(*free_region, payload.bytes)) {
                outcome.status = 0x10004008U;
                return outcome;
            }
            copied_address = *free_region;
        }
        for (std::size_t byte = 0; byte < 4; ++byte) {
            received->bytes[payload.descriptor_offset + byte] =
                static_cast<std::byte>(copied_address >> (byte * 8U));
        }
        output_.write(
            "[mach] ool-copy receiver=" + std::to_string(process_.pid) +
            " bytes=" + std::to_string(payload.bytes.size()) +
            " address=" + std::to_string(copied_address) + "\n");

    }

    if (!mach_ipc::apply_receive_pointer_fixups(pending_message,
            receive.message_address, received->bytes)) {
        auto discarded = std::move(queue->second.front());
        queue->second.pop_front();
        shared_state_->note_mach_message_dequeued_locked(queued_port);
        discard_mach_message_rights_locked(*shared_state_, discarded);
        outcome.status = 0x10004008U; // MACH_RCV_INVALID_DATA
        return outcome;
    }

    const auto delivered_sender_pid = pending_message.sender_pid;
    const auto delivered_graphics_event_type =
        graphics_services_input::event_type(pending_message.bytes);
    const auto delivered_input_sequence =
        pending_message.graphics_input_sequence;
    const auto delivered_input_kind = pending_message.graphics_input_kind;
    const auto delivered_touch_phase = pending_message.graphics_touch_phase;
    const auto delivered_destination_send_object =
        pending_message.destination_send_object;
    const auto delivered_vsync_connection =
        pending_message.display_vsync_connection_object;
    const auto delivered_vsync_generation =
        pending_message.display_vsync_registration_generation;
    const auto delivered_vsync_sequence =
        pending_message.display_vsync_sequence;
    if (pending_message.host_enqueue_nanoseconds != 0U &&
        performance_counters().cpu_source_diagnostics_configured()) {
        const auto dispatch_nanoseconds = static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now().time_since_epoch())
                .count());
        const auto elapsed =
            dispatch_nanoseconds >= pending_message.host_enqueue_nanoseconds
                ? dispatch_nanoseconds -
                      pending_message.host_enqueue_nanoseconds
                : 0U;
        performance_counters().record_latency(
            PerfLatencyKind::MachMessageSendToReceive, elapsed);
    }
    queue->second.pop_front();
    shared_state_->note_mach_message_dequeued_locked(queued_port);
    if (delivered_destination_send_object) {
        release_inflight_send_right_locked(
            *shared_state_, *delivered_destination_send_object);
    }
    output_.write(
        "[mach] deliver sender=" + std::to_string(delivered_sender_pid) +
        " receiver=" + std::to_string(process_.pid) +
        " port=" + std::to_string(queued_port) +
        " id=" + std::to_string(received->message_id) +
        mig_message_label(received->message_id) +
        " header=" + std::to_string(received->caller_header_size) +
        " bytes=" + std::to_string(received->message_size) +
        " trailer=" + std::to_string(received->trailer_size) + "\n");
    const auto copied =
        memory_.copy_in(receive.message_address, received->bytes);
    if (copied) {
        if (delivered_vsync_connection) {
            shared_state_->observe_display_vsync_receive_locked(process_.pid,
                *delivered_vsync_connection, delivered_vsync_generation,
                delivered_vsync_sequence,
                static_cast<std::uint32_t>(receive.processor));
            performance_counters().record_vsync_receiver(process_.pid,
                static_cast<std::uint32_t>(receive.processor),
                delivered_vsync_sequence);
        }
        if (delivered_input_sequence != 0U &&
            delivered_input_kind !=
                KernelSharedState::MachMessage::GraphicsInputKind::None) {
            const auto entered_at = std::chrono::steady_clock::now();
            performance_counters().record_diagnostic_input_guest(
                delivered_input_sequence, process_.pid,
                static_cast<std::uint32_t>(receive.processor), entered_at);
            if (waking_blocked_receiver) {
                last_delivered_graphics_inputs_[receive.processor] =
                    delivered_input_sequence;
            } else {
                // The receive found a message while this thread was already
                // executing. It has no later Waiting -> Runnable transition;
                // attributing a future host-side delivery to this sequence
                // creates a false input stall.
                performance_counters().record_diagnostic_input_runnable(
                    delivered_input_sequence, process_.pid,
                    static_cast<std::uint32_t>(receive.processor), entered_at);
                performance_counters().record_diagnostic_input_execute(
                    process_.pid,
                    static_cast<std::uint32_t>(receive.processor), entered_at);
            }
        }
        if (delivered_graphics_event_type) {
            if (delivered_input_sequence == 0U) {
                graphics_services_input::record_system_event_delivery_locked(
                    *shared_state_, queued_port, *delivered_graphics_event_type,
                    scene_coordinator_.get());
            }
            // Bootstrap service ports remain owned by launchd while a cold app
            // is starting. Observe lifecycle delivery only after the receive
            // right has reached its real process, so the route is bound to the
            // receiver that actually consumed the firmware event rather than
            // its temporary launchd owner.
            graphics_services_input::record_application_event_delivery_locked(
                *shared_state_, delivered_sender_pid, queued_port,
                *delivered_graphics_event_type, scene_coordinator_.get());
        }
        static_cast<void>(
            shared_state_->mach_port_objects.increment_sequence_number(
                queued_port));
        const auto receiver = shared_state_->processes.find(process_.pid);
        if (delivered_input_sequence != 0U &&
            delivered_input_kind ==
                KernelSharedState::MachMessage::GraphicsInputKind::Touch &&
            receiver != shared_state_->processes.end() &&
            !receiver->second.exited &&
            receiver->second.executable_path.ends_with(
                "/SpringBoard.app/SpringBoard")) {
            shared_state_->springboard_last_consumed_touch_sequence =
                delivered_input_sequence;
            if (delivered_touch_phase == TouchPhase::Down) {
                shared_state_->springboard_active_touch_begin_sequence =
                    delivered_input_sequence;
            } else if (delivered_touch_phase == TouchPhase::Up ||
                       delivered_touch_phase == TouchPhase::Cancel) {
                shared_state_->springboard_last_touch_begin_sequence =
                    shared_state_->springboard_active_touch_begin_sequence != 0U
                        ? shared_state_->springboard_active_touch_begin_sequence
                        : delivered_input_sequence;
                shared_state_->springboard_active_touch_begin_sequence = 0U;
            }
        }
    }
    outcome.status = copied ? 0U : 0x10004008U; // MACH_RCV_INVALID_DATA
    return outcome;
}

} // namespace shade
