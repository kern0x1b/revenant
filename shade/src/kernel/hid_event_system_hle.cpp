// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest IOHIDEventSystem calls to emulator input services.

#include "kernel/hid_event_system_hle.hpp"
#include "hid_event_transaction.hpp"
#include "hid_switch_query.hpp"

#include "foundation/cpu.hpp"
#include "foundation/userland_hle.hpp"
#include "kernel/kernel_shared_state.hpp"

#include <string>

namespace shade {

HidEventSystemHle::HidEventSystemHle(UserlandHleRegistry& registry)
    : registry_ { registry }
{
    register_hid_switch_queries(registry_);
    registry_.register_function(
        "/IOKit", "_IOHIDEventSystemOpen", [this](UserlandHleCall& call) {
            HidEventQueue::Consumer consumer { call.process_id(),
                call.cpu().processor_id(), call.argument(0) };
            consumer.keyboard_events =
                call.symbol_address("_IOHIDEventCreateKeyboardEvent")
                    .has_value();
            call.resume_original_persistently([this, consumer](
                                                  UserlandHleCall& completed) {
                // Opening the event system establishes the hardware event
                // consumer even when its callback is installed later.
                // Native dispatch owns callback and client routing.
                if (!state_ || completed.argument(0) == 0U ||
                    !state_->user_interface_geometry.valid())
                    return;
                for (const auto symbol : { "_IOHIDEventCreateDigitizerEvent",
                         "_IOHIDEventAppendEvent",
                         "__IOHIDEventSystemDispatchEvent", "_CFRelease" }) {
                    if (!completed.symbol_address(symbol)) {
                        return;
                    }
                }
                consumer_process_ = consumer.process;
                consumer_processor_ = consumer.processor;
                state_->hid_event_queue.open(consumer);
                accelerometer_.stop();
                if (completed.symbol_address(
                        "_IOHIDEventCreateAccelerometerEvent"))
                    accelerometer_.start(state_->clock.now());
                state_->note_kernel_event_transition();
            });
        });
    registry_.register_function(
        "/IOKit", "_IOHIDEventSystemClose", [this](UserlandHleCall& call) {
            reset(call.process_id());
            call.resume_original_persistently();
        });
    for (const auto symbol :
        { "_IOHIDEventCreateDigitizerEvent", "_IOHIDEventCreateKeyboardEvent",
            "_IOHIDEventAppendEvent", "__IOHIDEventSystemDispatchEvent",
            "_IOHIDEventCreateAccelerometerEvent" }) {
        registry_.register_guest_function("/IOKit", symbol);
    }
    registry_.register_guest_function("/CoreFoundation", "_CFRelease");
}

void HidEventSystemHle::set_shared_state(
    std::shared_ptr<KernelSharedState> state)
{
    state_ = std::move(state);
}

void HidEventSystemHle::reset(std::uint32_t process)
{
    if (state_)
        state_->hid_event_queue.close(process);
    consumer_process_ = 0U;
    delivering_ = false;
    accelerometer_.stop();
    if (state_)
        state_->note_kernel_event_transition();
}

bool HidEventSystemHle::prepare_pending_event(
    Cpu& cpu, std::uint32_t process, std::uint32_t svc_immediate)
{
    if (consumer_process_ != process ||
        consumer_processor_ != cpu.processor_id() || !state_ || delivering_ ||
        svc_immediate != 0x80U ||
        static_cast<std::int32_t>(cpu.registers()[12]) != -31 ||
        cpu.registers()[2] != 0U || (cpu.registers()[1] & 2U) == 0U)
        return false;
    const auto consumer = state_->hid_event_queue.consumer();
    auto event = state_->hid_event_queue.take(process, cpu.processor_id());
    if (consumer && !event) {
        event = accelerometer_.sample(state_->clock.now());
        if (event)
            state_->note_kernel_event_transition();
    }
    if (!consumer || !event)
        return false;
    delivering_ = HidEventTransaction::enqueue(registry_, *consumer, *event,
        state_->user_interface_geometry, state_->darwin_abi.hid_digitizer,
        [this] { delivering_ = false; });
    return delivering_;
}

} // namespace shade
