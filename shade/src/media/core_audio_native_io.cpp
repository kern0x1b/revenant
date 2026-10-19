// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Configure host-scheduled IOProcs from the firmware HAL's output format.

#include "media/core_audio_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <string>

namespace shade {
namespace {
    constexpr std::uint32_t parameter_error = 0xffffffce;
    constexpr std::uint32_t unsupported_format = 0x666d743f; // 'fmt?'
    constexpr std::uint32_t stream_format_size = 40;
    constexpr std::uint32_t audio_timestamp_size = 64;
    constexpr std::uint32_t audio_buffer_list_size = 16;
    constexpr std::uint32_t callback_stack_size = 4096;
    constexpr std::uint32_t maximum_buffer_frame_size = 16384;
}

void CoreAudioHle::start_native_io(UserlandHleCall& call)
{
    auto found = native_io_procs_.find(call.argument(1));
    if (found == native_io_procs_.end()) {
        found = std::find_if(native_io_procs_.begin(), native_io_procs_.end(),
            [&](const auto& entry) {
                return entry.second.process_id == call.process_id() &&
                       entry.second.device == call.argument(0) &&
                       entry.second.callback == call.argument(1);
            });
    }
    if (found == native_io_procs_.end() ||
        found->second.process_id != call.process_id() ||
        found->second.device != call.argument(0)) {
        call.set_return(parameter_error);
        return;
    }
    query_native_io_format(call, found->first, NativeFormatQuery::OutputStream);
}

void CoreAudioHle::query_native_io_format(
    UserlandHleCall& call, std::uint32_t io_proc_id, NativeFormatQuery query, std::uint32_t stream)
{
    const bool frame_count = query == NativeFormatQuery::FrameCount;
    auto& state = native_io_procs_.at(io_proc_id);
    if (state.format_query == 0)
        state.format_query = call.allocate_data(stream_format_size + 16U, 8U);
    const auto data = state.format_query;
    const auto size = data + stream_format_size;
    const auto property_address = size + 4U;
    const auto property = frame_count ? 0x6673697aU :
        query == NativeFormatQuery::OutputStream ? 0x73746d23U : 0x73666d74U;
    const auto saved = call.cpu().registers();
    if (data == 0 ||
        !call.write32(size, frame_count ? 4U : stream_format_size) ||
        !call.write32(property_address, property) ||
        !call.write32(property_address + 4U, query == NativeFormatQuery::OutputStream ? 0x6f757470U : 0x676c6f62U) ||
        !call.write32(property_address + 8U, 0U) ||
        !call.write32(saved[13] - 8U, size) ||
        !call.write32(saved[13] - 4U, data)) {
        call.set_return(parameter_error);
        return;
    }
    auto& registers = call.cpu().registers();
    registers[13] -= 8U;
    registers[0] = query == NativeFormatQuery::StreamFormat ? stream : state.device;
    registers[1] = property_address;
    registers[2] = 0U;
    registers[3] = 0U;
    if (!call.call_guest_function("_AudioObjectGetPropertyData",
            [this, io_proc_id, query, frame_count, data, size, saved](
                UserlandHleCall& completed) {
                const auto result = completed.argument(0);
                completed.cpu().registers() = saved;
                if (result != 0) {
                    completed.set_return(result);
                    return;
                }
                const auto found = native_io_procs_.find(io_proc_id);
                if (found == native_io_procs_.end()) {
                    completed.set_return(parameter_error);
                    return;
                }
                auto& format = found->second;
                auto& memory = completed.memory();
                if (query == NativeFormatQuery::OutputStream) {
                    if (memory.read32(size).value_or(0) != 4U || memory.read32(data).value_or(0) == 0) {
                        completed.set_return(unsupported_format);
                        return;
                    }
                    query_native_io_format(completed, io_proc_id, NativeFormatQuery::StreamFormat, memory.read32(data).value_or(0));
                    return;
                }
                if (frame_count) {
                    const auto frames = memory.read32(data).value_or(0);
                    if (memory.read32(size).value_or(0) < 4U || frames == 0 ||
                        frames > maximum_buffer_frame_size) {
                        completed.set_return(parameter_error);
                        return;
                    }
                    format.buffer_frame_size = frames;
                    configure_native_io(completed, io_proc_id);
                    return;
                }
                const auto rate =
                    std::bit_cast<double>(memory.read64(data).value_or(0));
                const auto tag = memory.read32(data + 8U).value_or(0);
                const auto flags = memory.read32(data + 12U).value_or(0);
                const auto packet_bytes = memory.read32(data + 16U).value_or(0);
                const auto packet_frames =
                    memory.read32(data + 20U).value_or(0);
                const auto frame_bytes = memory.read32(data + 24U).value_or(0);
                const auto channels = memory.read32(data + 28U).value_or(0);
                const auto bits = memory.read32(data + 32U).value_or(0);
                const auto sample_format = PcmSampleFormat::from_lpcm(flags, bits);
                if (memory.read32(size).value_or(0) < stream_format_size ||
                    !std::isfinite(rate) || rate < 4000.0 || rate > 192000.0 ||
                    tag != 0x6c70636dU || !sample_format ||
                    ((flags & 32U) != 0 && channels != 1U) ||
                    channels == 0 ||
                    channels > 32U || packet_frames != 1U ||
                    frame_bytes != channels * (bits / 8U) ||
                    packet_bytes != frame_bytes) {
                    completed.set_return(unsupported_format);
                    return;
                }
                format.sample_rate =
                    static_cast<std::uint32_t>(std::llround(rate));
                format.channel_count = channels;
                format.sample_format = *sample_format;
                query_native_io_format(completed, io_proc_id, NativeFormatQuery::FrameCount);
            })) {
        call.cpu().registers() = saved;
        call.set_return(unsupported_format);
    }
}

void CoreAudioHle::configure_native_io(
    UserlandHleCall& call, std::uint32_t io_proc_id)
{
    auto& state = native_io_procs_.at(io_proc_id);
    const auto sample_bytes =
        state.buffer_frame_size * state.channel_count * state.sample_format.bytes_per_sample();
    if (state.callback_return == 0)
        state.callback_return =
            registry_.prepare_thread_callback_return(call.cpu()).value_or(0);
    if (state.timestamp == 0)
        state.timestamp = call.allocate_data(audio_timestamp_size, 8U);
    if (state.output_buffers == 0)
        state.output_buffers = call.allocate_data(audio_buffer_list_size, 4U);
    if (state.output_samples == 0 ||
        state.output_sample_bytes != sample_bytes) {
        state.output_samples = call.allocate_data(sample_bytes, 16U);
        state.output_sample_bytes = sample_bytes;
        state.zero_output_samples.assign(sample_bytes, std::byte { });
        state.captured_output_samples.resize(sample_bytes);
    }
    if (state.stack == 0)
        state.stack = call.allocate_data(callback_stack_size, 16U);
    if (state.callback_return == 0 || state.timestamp == 0 ||
        state.output_buffers == 0 || state.output_samples == 0 ||
        state.stack == 0) {
        call.set_return(parameter_error);
        return;
    }
    state.thread_r9 = call.cpu().registers()[9];
    state.cthread_self = call.cpu().cthread_self();
    state.running = true;
    state.in_flight = false;
    state.next_deadline = 0;
    state.sample_time = 0;
    state.callback_count = 0;
    state.peak_since_report = 0;
    call.output().line("[coreaudio-device] native-io-proc start pid=" +
                       std::to_string(call.process_id()) +
                       " device=" + std::to_string(state.device) +
                       " id=" + std::to_string(io_proc_id) +
                       " frames=" + std::to_string(state.buffer_frame_size) +
                       " bytes=" + std::to_string(state.output_sample_bytes) +
                       " rate=" + std::to_string(state.sample_rate) +
                       " channels=" + std::to_string(state.channel_count));
    call.set_return(0);
}

} // namespace shade
