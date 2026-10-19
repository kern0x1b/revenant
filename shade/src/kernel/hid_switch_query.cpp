// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Supply virtual switch samples through firmware-owned HID event objects.

#include "hid_switch_query.hpp"

#include "foundation/cpu.hpp"
#include "foundation/userland_hle.hpp"

#include <memory>
#include <utility>

namespace shade {
namespace {

    constexpr std::uint32_t keyboard_event = 3U;
    constexpr std::uint32_t keyboard_usage_page = keyboard_event << 16U;
    constexpr std::uint32_t keyboard_usage = keyboard_usage_page + 1U;
    constexpr std::uint32_t keyboard_down = keyboard_usage_page + 2U;
    // The Hall sensor is represented by the embedded HID keyboard usage
    // page 0xff, usage 10. An unattached magnetic cover leaves it open.
    constexpr std::uint32_t embedded_usage_page = 0xffU;
    constexpr std::uint32_t hall_sensor_usage = 10U;
    constexpr auto get_integer = "_IOHIDEventGetIntegerValue";
    constexpr auto create_copy = "_IOHIDEventCreateCopy";
    constexpr auto set_integer = "_IOHIDEventSetIntegerValue";

    class SwitchQuery : public std::enable_shared_from_this<SwitchQuery> {
    public:
        explicit SwitchQuery(std::uint32_t matching) : matching_ { matching } { }

        void start(UserlandHleCall& call)
        {
            if (!call.symbol_address(get_integer) ||
                !call.symbol_address(create_copy) ||
                !call.symbol_address(set_integer)) {
                call.set_return(0U);
                return;
            }
            read_field(call, keyboard_usage_page, embedded_usage_page,
                [self = shared_from_this()](UserlandHleCall& next) {
                    self->read_field(next, keyboard_usage, hall_sensor_usage,
                        [self](UserlandHleCall& sample) { self->copy(sample); });
                });
        }

    private:
        void read_field(UserlandHleCall& call, std::uint32_t field,
            std::uint32_t expected, UserlandHleCall::Continuation next)
        {
            call.cpu().registers()[0] = matching_;
            call.cpu().registers()[1] = field;
            if (!call.call_guest_function(get_integer,
                    [expected, next = std::move(next)](UserlandHleCall& value) {
                        if (value.argument(0) == expected)
                            next(value);
                        else
                            value.set_return(0U);
                    })) {
                call.set_return(0U);
            }
        }

        void copy(UserlandHleCall& call)
        {
            call.cpu().registers()[0] = 0U;
            call.cpu().registers()[1] = matching_;
            if (!call.call_guest_function(create_copy,
                    [](UserlandHleCall& copied) {
                        const auto event = copied.argument(0);
                        if (event == 0U)
                            return;
                        copied.cpu().registers()[1] = keyboard_down;
                        copied.cpu().registers()[2] = 0U;
                        if (!copied.call_guest_function(set_integer,
                                [event](UserlandHleCall& updated) {
                                    updated.set_return(event);
                                })) {
                            copied.cpu().registers()[0] = event;
                            if (!copied.call_guest_function(
                                "_CFRelease", [](UserlandHleCall& released) {
                                    released.set_return(0U);
                                })) {
                                copied.set_return(0U);
                            }
                        }
                    })) {
                call.set_return(0U);
            }
        }

        std::uint32_t matching_;
    };

} // namespace

void register_hid_switch_queries(UserlandHleRegistry& registry)
{
    for (const auto symbol : { get_integer, create_copy, set_integer })
        registry.register_guest_function("/IOKit", symbol);
    registry.register_function("/IOKit", "_IOHIDEventSystemCopyEvent",
        [](UserlandHleCall& call) {
            const auto type = call.argument(1);
            const auto matching = call.argument(2);
            call.resume_original_persistently(
                [type, matching](UserlandHleCall& completed) {
                    if (completed.argument(0) == 0U &&
                        type == keyboard_event && matching != 0U) {
                        std::make_shared<SwitchQuery>(matching)->start(completed);
                    }
                });
        });
}

} // namespace shade
