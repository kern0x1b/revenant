// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest CoreAudio device properties and callbacks to the
// emulated audio hardware.

#pragma once

#include "media/pcm_sample_format.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <vector>

namespace shade {

class AudioService;
class AddressSpace;
class Output;
class UserlandHleCall;
class UserlandHleRegistry;

// CoreAudio's firmware HAL remains in the guest. This adapter supplies the
// one physical output device that an emulator has in place of iPhone hardware.
class CoreAudioHle {
public:
    struct ScheduledIoProc {
        std::uint32_t process_id { };
        bool native { };
        std::uint32_t io_proc_id { };
        std::optional<std::size_t> processor;
        std::array<std::uint32_t, 16> registers { };
        std::uint32_t cpsr { };
        std::optional<std::uint32_t> cthread_self;
        std::function<void(UserlandHleCall&)> completion;
    };

    CoreAudioHle(
        UserlandHleRegistry& registry, std::shared_ptr<AudioService> service);

    void set_service(std::shared_ptr<AudioService> service);
    void reset();
    [[nodiscard]] std::optional<std::uint64_t> next_io_proc_deadline() const;
    [[nodiscard]] std::optional<ScheduledIoProc> take_due_io_proc(
        std::uint64_t now);
    void io_proc_thread_scheduled(std::uint32_t process_id, bool native,
        std::uint32_t io_proc_id, std::size_t processor);
    void io_proc_schedule_failed(
        std::uint32_t process_id, bool native, std::uint32_t io_proc_id);
    [[nodiscard]] std::vector<std::size_t> take_retired_io_proc_threads();

private:
    void device_property_info(UserlandHleCall& call);
    void device_property(UserlandHleCall& call);
    void device_set_property(UserlandHleCall& call);
    void stream_property_info(UserlandHleCall& call);
    void stream_property(UserlandHleCall& call);
    void stream_set_property(UserlandHleCall& call);
    void object_property(UserlandHleCall& call);
    void object_set_property(UserlandHleCall& call);
    void property_listener(UserlandHleCall& call);
    void create_native_io_proc(UserlandHleCall& call);
    void record_native_io_proc(UserlandHleCall& call, std::uint32_t device,
        std::uint32_t callback, std::uint32_t client_data,
        std::uint32_t io_proc_id);
    void destroy_native_io_proc(UserlandHleCall& call);
    void start_native_io_at_time(UserlandHleCall& call);
    void add_io_proc(UserlandHleCall& call);
    void remove_io_proc(UserlandHleCall& call);
    void start_io(UserlandHleCall& call);
    void start_native_io(UserlandHleCall& call);
    enum class NativeFormatQuery { OutputStream, StreamFormat, FrameCount };
    void query_native_io_format(UserlandHleCall& call,
        std::uint32_t io_proc_id, NativeFormatQuery query, std::uint32_t stream = 0);
    void configure_native_io(UserlandHleCall& call, std::uint32_t io_proc_id);
    void stop_io(UserlandHleCall& call);
    void complete_io_proc(UserlandHleCall& call, std::uint32_t process_id,
        bool native, std::uint32_t io_proc_id);
    [[nodiscard]] float device_output_gain(std::uint32_t device) const;
    [[nodiscard]] double device_sample_rate(std::uint32_t device) const;
    [[nodiscard]] std::uint32_t device_channel_count(
        std::uint32_t device) const;

    struct IoProcRegistration {
        bool native { };
        std::uint32_t process_id { };
        std::uint32_t io_proc_id { };
        std::uint32_t callback { };
        std::uint32_t client_data { };
        std::uint32_t device { };
        AddressSpace* memory { };
        Output* output { };
        std::uint32_t callback_return { };
        std::uint32_t timestamp { };
        std::uint32_t output_buffers { };
        std::uint32_t output_samples { };
        std::uint32_t output_sample_bytes { };
        std::uint32_t sample_rate { 44100 };
        std::uint32_t channel_count { 2 };
        std::uint32_t buffer_frame_size { 1024 };
        PcmSampleFormat sample_format;
        std::uint32_t format_query { };
        std::vector<std::byte> zero_output_samples;
        std::vector<std::byte> captured_output_samples;
        std::uint32_t stack { };
        std::uint32_t thread_r9 { };
        std::optional<std::uint32_t> cthread_self;
        std::uint64_t next_deadline { };
        std::uint64_t sample_time { };
        std::uint64_t callback_count { };
        std::uint32_t peak_since_report { };
        std::optional<std::size_t> processor;
        bool running { };
        bool in_flight { };
    };

    UserlandHleRegistry& registry_;
    std::shared_ptr<AudioService> service_;
    std::uint32_t buffer_frame_size_ { 1024 };
    struct StreamFormatState {
        double sample_rate { };
        std::uint32_t channel_count { };
    };
    std::map<std::uint32_t, StreamFormatState> stream_formats_;
    std::map<std::uint32_t, float> device_volumes_;
    std::map<std::uint64_t, std::uint32_t> hardware_control_states_;
    std::map<std::uint32_t, IoProcRegistration> io_procs_;
    // Native HAL IOProc IDs are opaque per-process objects. They are kept
    // separate from the legacy one-proc-per-process compatibility path so
    // older firmware continues to use its existing adapter unchanged.
    std::map<std::uint32_t, IoProcRegistration> native_io_procs_;
    std::uint32_t next_native_io_proc_id_ { 0x70000000U };
    std::vector<std::size_t> retired_io_proc_threads_;
};

} // namespace shade
