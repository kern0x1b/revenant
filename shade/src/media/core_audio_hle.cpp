// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest CoreAudio device properties and callbacks to the
// emulated audio hardware.

#include "media/core_audio_hle.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <limits>
#include <span>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#include "foundation/address_space.hpp"
#include "media/audio.hpp"
#include "foundation/cpu.hpp"
#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view core_audio_image {
        "/CoreAudio.framework/CoreAudio"
    };
    constexpr std::uint32_t wolfson_device = 2;
    constexpr std::uint32_t wolfson_stream = 3;
    constexpr std::uint32_t baseband_output_device = 4;
    constexpr std::uint32_t baseband_output_stream = 5;
    constexpr std::uint32_t baseband_input_device = 6;
    constexpr std::uint32_t baseband_input_stream = 7;
    constexpr std::uint32_t device_name_property = 0x6e616d65; // 'name'
    constexpr std::uint32_t device_streams_property = 0x73746d23; // 'stm#'
    constexpr std::uint32_t nominal_sample_rate_property = 0x6e737274; // 'nsrt'
    constexpr std::uint32_t available_sample_rates_property =
        0x6e737223; // 'nsr#'
    constexpr std::uint32_t buffer_frame_size_property = 0x6673697a; // 'fsiz'
    constexpr std::uint32_t volume_scalar_property = 0x766f6c6d; // 'volm'
    constexpr std::uint32_t device_is_running_property = 0x676f696e; // 'goin'
    constexpr std::uint32_t physical_format_property = 0x70667420; // 'pft '
    constexpr std::uint32_t available_physical_formats_property =
        0x70667461; // 'pfta'
    constexpr std::uint32_t jack_connected_property = 0x6a61636b; // 'jack'
    constexpr std::uint32_t device_mute_property = 0x646d7574; // 'dmut'
    constexpr std::uint32_t mute_property = 0x6d757465; // 'mute'
    constexpr std::uint32_t solo_property = 0x736f6c6f; // 'solo'
    constexpr std::uint32_t unsupported_property = 0x77686f3f; // 'who?'
    constexpr std::uint32_t parameter_error = 0xffffffce; // -50
    constexpr std::string_view virtual_device_name {
        "WM8758 Output Device audio0"
    };
    constexpr std::string_view baseband_output_name { "Baseband Output" };
    constexpr std::string_view baseband_input_name { "Baseband Input" };
    constexpr double media_sample_rate = 44100.0;
    constexpr double telephony_sample_rate = 8000.0;
    constexpr std::uint32_t linear_pcm_format = 0x6c70636d; // 'lpcm'
    constexpr std::uint32_t linear_pcm_flags = 0xc; // signed integer, packed
    constexpr std::uint32_t stream_format_size = 40;
    constexpr std::uint32_t ranged_stream_format_size = 56;
    constexpr std::uint32_t audio_timestamp_size = 64;
    constexpr std::uint32_t audio_timestamp_flags_offset = 56;
    constexpr std::uint32_t audio_timestamp_sample_time_valid = 1U << 0U;
    constexpr std::uint32_t audio_timestamp_host_time_valid = 1U << 1U;
    constexpr std::uint32_t audio_timestamp_rate_scalar_valid = 1U << 2U;
    constexpr std::uint32_t audio_buffer_list_size = 16;
    constexpr std::uint32_t callback_stack_size = 4096;
    constexpr std::uint32_t callback_stack_argument_space = 16;
    constexpr std::uint32_t maximum_buffer_frame_size = 16384;
    constexpr std::uint64_t virtual_time_units_per_second = 1'000'000'000ULL;
    constexpr std::uint32_t arm_user_mode = 0x10U;
    constexpr std::uint32_t arm_thumb_state_bit = 1U << 5U;

    struct DeviceDescription {
        std::uint32_t identifier;
        std::uint32_t stream;
        std::string_view name;
        bool input;
        double default_sample_rate;
        std::uint32_t default_channel_count;
        AudioStopMode stop_mode;
    };

    constexpr std::array devices {
        DeviceDescription { wolfson_device, wolfson_stream, virtual_device_name,
            false, media_sample_rate, 2U, AudioStopMode::Immediate },
        DeviceDescription { baseband_output_device, baseband_output_stream,
            baseband_output_name, false, media_sample_rate, 2U,
            AudioStopMode::FadeOut },
        DeviceDescription { baseband_input_device, baseband_input_stream,
            baseband_input_name, true, telephony_sample_rate, 1U,
            AudioStopMode::Immediate },
    };

    const DeviceDescription* find_device(std::uint32_t identifier)
    {
        const auto result = std::ranges::find(
            devices, identifier, &DeviceDescription::identifier);
        return result == devices.end() ? nullptr : &*result;
    }

    const DeviceDescription* find_stream(std::uint32_t identifier)
    {
        const auto result =
            std::ranges::find(devices, identifier, &DeviceDescription::stream);
        return result == devices.end() ? nullptr : &*result;
    }

    double default_device_sample_rate(const DeviceDescription& device)
    {
        return device.default_sample_rate;
    }

    std::uint32_t default_device_channel_count(const DeviceDescription& device)
    {
        return device.default_channel_count;
    }

    bool is_route_property(std::uint32_t property)
    {
        // The first-generation CoreAudio driver represents hardware crosspoints
        // as printable four-character source-to-destination selectors (for
        // example, "bb2w"). Treat the family as virtual routing state,
        // independent of any particular source or codec name.
        const std::array characters {
            static_cast<unsigned char>(property >> 24U),
            static_cast<unsigned char>(property >> 16U),
            static_cast<unsigned char>(property >> 8U),
            static_cast<unsigned char>(property),
        };
        const auto printable = std::ranges::all_of(characters,
            [](const auto value) { return value >= 0x20U && value <= 0x7eU; });
        const auto separator = static_cast<unsigned char>('2');
        return printable && characters.front() != separator &&
               characters.back() != separator &&
               std::ranges::count(characters, separator) == 1;
    }

    bool is_boolean_hardware_control(std::uint32_t property)
    {
        return is_route_property(property) ||
               property == device_mute_property || property == mute_property ||
               property == solo_property;
    }

    std::string property_name(std::uint32_t property)
    {
        std::array<char, 5> text { };
        text[0] = static_cast<char>((property >> 24U) & 0xffU);
        text[1] = static_cast<char>((property >> 16U) & 0xffU);
        text[2] = static_cast<char>((property >> 8U) & 0xffU);
        text[3] = static_cast<char>(property & 0xffU);
        return text.data();
    }

    void log_property(UserlandHleCall& call, std::string_view operation,
        std::uint32_t property, std::uint32_t status)
    {
        std::ostringstream message;
        message << "[coreaudio-device] " << operation
                << " pid=" << call.process_id()
                << " property=" << std::quoted(property_name(property))
                << " id=0x" << std::hex << property << " status=0x" << status;
        call.output().line(message.str());
    }

    bool write_sized_data(UserlandHleCall& call, std::uint32_t size_address,
        std::uint32_t data_address, std::span<const std::byte> data)
    {
        const auto capacity = call.memory().read32(size_address).value_or(0);
        return capacity >= data.size() &&
               (data.empty() || call.memory().copy_in(data_address, data)) &&
               call.write32(
                   size_address, static_cast<std::uint32_t>(data.size()));
    }

    void store32(
        std::span<std::byte> data, std::size_t offset, std::uint32_t value)
    {
        std::memcpy(data.data() + offset, &value, sizeof(value));
    }

    void store64(
        std::span<std::byte> data, std::size_t offset, std::uint64_t value)
    {
        std::memcpy(data.data() + offset, &value, sizeof(value));
    }

    std::optional<double> read_double(
        AddressSpace& memory, std::uint32_t address)
    {
        const auto low = memory.read32(address);
        const auto high = memory.read32(address + sizeof(std::uint32_t));
        if (!low || !high)
            return std::nullopt;
        const auto encoded = static_cast<std::uint64_t>(*low) |
                             (static_cast<std::uint64_t>(*high) << 32U);
        return std::bit_cast<double>(encoded);
    }

    std::array<std::byte, stream_format_size> stream_format(
        double sample_rate, std::uint32_t channels)
    {
        std::array<std::byte, stream_format_size> result { };
        const auto bytes_per_frame =
            channels * static_cast<std::uint32_t>(sizeof(std::int16_t));
        store64(result, 0, std::bit_cast<std::uint64_t>(sample_rate));
        store32(result, 8, linear_pcm_format);
        store32(result, 12, linear_pcm_flags);
        store32(result, 16, bytes_per_frame); // bytes per packet
        store32(result, 20, 1); // frames per packet
        store32(result, 24, bytes_per_frame);
        store32(result, 28, channels);
        store32(result, 32, 16); // bits per channel
        return result;
    }

    std::array<std::byte, sizeof(double) * 2> sample_rate_range(
        double sample_rate)
    {
        std::array<std::byte, sizeof(double) * 2> result { };
        const auto encoded = std::bit_cast<std::uint64_t>(sample_rate);
        store64(result, 0, encoded);
        store64(result, sizeof(double), encoded);
        return result;
    }

    std::array<std::byte, ranged_stream_format_size> ranged_stream_format(
        double sample_rate, std::uint32_t channels)
    {
        std::array<std::byte, ranged_stream_format_size> result { };
        const auto format = stream_format(sample_rate, channels);
        const auto range = sample_rate_range(sample_rate);
        std::ranges::copy(format, result.begin());
        std::ranges::copy(range, result.begin() + stream_format_size);
        return result;
    }

    bool write_timestamp(AddressSpace& memory, std::uint32_t address,
        std::uint64_t sample_time, std::uint64_t host_time)
    {
        std::array<std::byte, audio_timestamp_size> timestamp { };
        store64(timestamp, 0,
            std::bit_cast<std::uint64_t>(static_cast<double>(sample_time)));
        store64(timestamp, 8, host_time);
        store64(timestamp, 16, std::bit_cast<std::uint64_t>(1.0));
        store32(timestamp, audio_timestamp_flags_offset,
            audio_timestamp_sample_time_valid |
                audio_timestamp_host_time_valid |
                audio_timestamp_rate_scalar_valid);
        return memory.copy_in(address, timestamp);
    }

} // namespace

CoreAudioHle::CoreAudioHle(
    UserlandHleRegistry& registry, std::shared_ptr<AudioService> service)
    : registry_ { registry }
    , service_ { std::move(service) }
{
    const auto register_function = [&](std::string symbol, auto handler) {
        registry.register_function(std::string { core_audio_image },
            std::move(symbol),
            [this, handler](UserlandHleCall& call) { (this->*handler)(call); });
    };
    register_function(
        "_AudioDeviceGetPropertyInfo", &CoreAudioHle::device_property_info);
    register_function(
        "_AudioDeviceGetProperty", &CoreAudioHle::device_property);
    register_function(
        "_AudioDeviceSetProperty", &CoreAudioHle::device_set_property);
    register_function(
        "_AudioStreamGetPropertyInfo", &CoreAudioHle::stream_property_info);
    register_function(
        "_AudioStreamGetProperty", &CoreAudioHle::stream_property);
    register_function(
        "_AudioStreamSetProperty", &CoreAudioHle::stream_set_property);
    register_function(
        "_AudioObjectGetPropertyData", &CoreAudioHle::object_property);
    register_function(
        "_AudioObjectSetPropertyData", &CoreAudioHle::object_set_property);
    register_function(
        "_AudioDeviceCreateIOProcID", &CoreAudioHle::create_native_io_proc);
    register_function(
        "_AudioDeviceDestroyIOProcID", &CoreAudioHle::destroy_native_io_proc);
    register_function("_AudioDeviceAddIOProc", &CoreAudioHle::add_io_proc);
    register_function(
        "_AudioDeviceRemoveIOProc", &CoreAudioHle::remove_io_proc);
    register_function("_AudioDeviceStart", &CoreAudioHle::start_io);
    register_function("_AudioDeviceStop", &CoreAudioHle::stop_io);
    register_function(
        "_AudioDeviceStartAtTime", &CoreAudioHle::start_native_io_at_time);

    for (const auto* symbol : { "_AudioDeviceAddPropertyListener",
             "_AudioDeviceRemovePropertyListener",
             "_AudioObjectAddPropertyListener",
             "_AudioObjectRemovePropertyListener" }) {
        register_function(symbol, &CoreAudioHle::property_listener);
    }
    for (const auto* symbol : { "_AudioHardwareAddPropertyListener",
             "_AudioHardwareRemovePropertyListener" }) {
        registry.register_function(std::string { core_audio_image }, symbol,
            [](UserlandHleCall& call) { call.set_return(0); });
    }
}

void CoreAudioHle::set_service(std::shared_ptr<AudioService> service)
{
    service_ = std::move(service);
}

void CoreAudioHle::reset()
{
    io_procs_.clear();
    native_io_procs_.clear();
    next_native_io_proc_id_ = 0x70000000U;
    retired_io_proc_threads_.clear();
    stream_formats_.clear();
}

float CoreAudioHle::device_output_gain(std::uint32_t device) const
{
    const auto volume = device_volumes_.find(device);
    const auto gain = volume == device_volumes_.end() ? 1.0F : volume->second;
    for (const auto property : { device_mute_property, mute_property }) {
        const auto key = (static_cast<std::uint64_t>(device) << 32U) | property;
        const auto control = hardware_control_states_.find(key);
        if (control != hardware_control_states_.end() && control->second != 0)
            return 0.0F;
    }
    return gain;
}

double CoreAudioHle::device_sample_rate(std::uint32_t device) const
{
    if (const auto configured = stream_formats_.find(device);
        configured != stream_formats_.end()) {
        return configured->second.sample_rate;
    }
    const auto* description = find_device(device);
    return description == nullptr ? 0.0
                                  : default_device_sample_rate(*description);
}

std::uint32_t CoreAudioHle::device_channel_count(std::uint32_t device) const
{
    if (const auto configured = stream_formats_.find(device);
        configured != stream_formats_.end()) {
        return configured->second.channel_count;
    }
    const auto* description = find_device(device);
    return description == nullptr ? 0U
                                  : default_device_channel_count(*description);
}

std::optional<std::uint64_t> CoreAudioHle::next_io_proc_deadline() const
{
    std::optional<std::uint64_t> deadline;
    for (const auto& [process_id, registration] : io_procs_) {
        static_cast<void>(process_id);
        if (!registration.running || registration.in_flight)
            continue;
        if (!deadline || registration.next_deadline < *deadline)
            deadline = registration.next_deadline;
    }
    for (const auto& [io_proc_id, registration] : native_io_procs_) {
        static_cast<void>(io_proc_id);
        if (!registration.running || registration.in_flight)
            continue;
        if (!deadline || registration.next_deadline < *deadline)
            deadline = registration.next_deadline;
    }
    return deadline;
}

std::optional<CoreAudioHle::ScheduledIoProc> CoreAudioHle::take_due_io_proc(
    std::uint64_t now)
{
    const auto selected = std::find_if(
        io_procs_.begin(), io_procs_.end(), [now](const auto& entry) {
            const auto& registration = entry.second;
            return registration.running && !registration.in_flight &&
                   registration.next_deadline <= now;
        });
    const auto selected_native = std::find_if(native_io_procs_.begin(),
        native_io_procs_.end(), [now](const auto& entry) {
            const auto& registration = entry.second;
            return registration.running && !registration.in_flight &&
                   registration.next_deadline <= now;
        });
    const bool use_native = selected == io_procs_.end() ||
                            (selected_native != native_io_procs_.end() &&
                                selected_native->second.next_deadline <
                                    selected->second.next_deadline);
    if (use_native && selected_native == native_io_procs_.end())
        return std::nullopt;
    if (!use_native && selected == io_procs_.end())
        return std::nullopt;

    auto& registration =
        use_native ? selected_native->second : selected->second;
    const auto* device =
        registration.native ? nullptr : find_device(registration.device);
    if ((!registration.native && device == nullptr) ||
        registration.memory == nullptr || registration.callback_return == 0 ||
        registration.output_buffers == 0 || registration.output_samples == 0 ||
        registration.stack == 0) {
        registration.running = false;
        return std::nullopt;
    }

    const auto stack_pointer = registration.stack + callback_stack_size -
                               callback_stack_argument_space;
    const auto memory_ready =
        registration.memory->copy_in(
            registration.output_samples, registration.zero_output_samples) &&
        registration.memory->write32(registration.output_buffers, 1U) &&
        registration.memory->write32(registration.output_buffers + 4U,
            registration.native ? registration.channel_count
                                : device_channel_count(device->identifier)) &&
        registration.memory->write32(registration.output_buffers + 8U,
            registration.output_sample_bytes) &&
        registration.memory->write32(
            registration.output_buffers + 12U, registration.output_samples) &&
        write_timestamp(*registration.memory, registration.timestamp,
            registration.sample_time, now) &&
        registration.memory->write32(
            stack_pointer, registration.output_buffers) &&
        registration.memory->write32(
            stack_pointer + 4U, registration.timestamp) &&
        registration.memory->write32(
            stack_pointer + 8U, registration.client_data);
    if (!memory_ready) {
        registration.running = false;
        return std::nullopt;
    }

    ScheduledIoProc callback;
    callback.process_id = registration.process_id;
    callback.native = registration.native;
    callback.io_proc_id = registration.io_proc_id;
    callback.processor = registration.processor;
    callback.registers[0] = registration.device;
    callback.registers[1] = registration.timestamp;
    callback.registers[2] =
        0; // no emulated input buffers on this output device
    callback.registers[3] = 0;
    // A host-scheduled callback does not pass through libpthread's usual thread
    // entry trampoline. Early firmware reads its pthread base directly from r9;
    // later libSystem reads the CP15 user thread pointer. Preserve both pieces
    // of the owning firmware thread context without selecting a build version.
    callback.registers[9] = registration.thread_r9;
    callback.cthread_self = registration.cthread_self;
    callback.registers[13] = stack_pointer;
    callback.registers[14] = registration.callback_return;
    callback.registers[15] = registration.callback & ~1U;
    callback.cpsr =
        arm_user_mode |
        ((registration.callback & 1U) != 0 ? arm_thumb_state_bit : 0U);
    callback.completion = [this, process_id = registration.process_id,
                              native = registration.native,
                              io_proc_id = registration.io_proc_id](
                              UserlandHleCall& call) {
        complete_io_proc(call, process_id, native, io_proc_id);
    };

    const auto sample_rate = static_cast<std::uint64_t>(std::llround(
        registration.native ? registration.sample_rate
                            : device_sample_rate(device->identifier)));
    const auto period = std::max<std::uint64_t>(
        1U, static_cast<std::uint64_t>(registration.native
                                      ? registration.buffer_frame_size
                                      : buffer_frame_size_) *
                virtual_time_units_per_second / sample_rate);
    registration.next_deadline =
        std::max(now, registration.next_deadline) + period;
    registration.in_flight = true;
    if (registration.output != nullptr && registration.callback_count < 2U) {
        registration.output->line(
            "[coreaudio-device] io-proc schedule pid=" +
            std::to_string(registration.process_id) +
            " sequence=" + std::to_string(registration.callback_count + 1U) +
            " now=" + std::to_string(now) +
            " next=" + std::to_string(registration.next_deadline));
    }
    return callback;
}

void CoreAudioHle::io_proc_schedule_failed(
    std::uint32_t process_id, bool native, std::uint32_t io_proc_id)
{
    if (native) {
        if (const auto registration = native_io_procs_.find(io_proc_id);
            registration != native_io_procs_.end() &&
            registration->second.process_id == process_id) {
            registration->second.in_flight = false;
            registration->second.processor.reset();
        }
        return;
    }
    if (const auto registration = io_procs_.find(process_id);
        registration != io_procs_.end()) {
        registration->second.in_flight = false;
        registration->second.processor.reset();
    }
}

void CoreAudioHle::io_proc_thread_scheduled(std::uint32_t process_id,
    bool native, std::uint32_t io_proc_id, std::size_t processor)
{
    if (native) {
        if (const auto registration = native_io_procs_.find(io_proc_id);
            registration != native_io_procs_.end() &&
            registration->second.process_id == process_id) {
            registration->second.processor = processor;
        }
        return;
    }
    if (const auto registration = io_procs_.find(process_id);
        registration != io_procs_.end()) {
        registration->second.processor = processor;
    }
}

std::vector<std::size_t> CoreAudioHle::take_retired_io_proc_threads()
{
    auto result = std::move(retired_io_proc_threads_);
    retired_io_proc_threads_.clear();
    return result;
}

void CoreAudioHle::complete_io_proc(UserlandHleCall& call,
    std::uint32_t process_id, bool native, std::uint32_t io_proc_id)
{
    IoProcRegistration* registration = nullptr;
    if (native) {
        const auto found = native_io_procs_.find(io_proc_id);
        if (found == native_io_procs_.end() ||
            found->second.process_id != process_id)
            return;
        registration = &found->second;
    } else {
        const auto found = io_procs_.find(process_id);
        if (found == io_procs_.end())
            return;
        registration = &found->second;
    }
    const auto* device = native ? nullptr : find_device(registration->device);
    if (!native && device == nullptr)
        return;

    const auto produced =
        call.memory().read32(registration->output_buffers + 8U).value_or(0);
    const auto sample_bytes = registration->sample_format.bytes_per_sample();
    const auto byte_count =
        std::min(produced, registration->output_sample_bytes) &
        ~(sample_bytes - 1U);
    AudioPlayResult result;
    std::uint32_t peak = 0;
    const auto applied_gain =
        native ? 1.0F : device_output_gain(registration->device);
    if (byte_count != 0) {
        auto bytes = std::span { registration->captured_output_samples }.first(
            byte_count);
        if (call.memory().copy_out(registration->output_samples, bytes)) {
            const auto audible = std::any_of(bytes.begin(), bytes.end(),
                [](std::byte value) { return value != std::byte { }; });
            const auto service_source_active =
                service_ && service_->service_source_playing();
            if (!audible) {
                result.status = AudioPlayStatus::Queued;
            } else {
                AudioBuffer buffer;
                buffer.sample_rate =
                    native ? registration->sample_rate
                           : static_cast<std::uint32_t>(std::llround(
                                 device_sample_rate(device->identifier)));
                buffer.channel_count =
                    native ? static_cast<std::uint16_t>(
                                 registration->channel_count)
                           : static_cast<std::uint16_t>(
                                 device_channel_count(device->identifier));
                buffer.streaming = true;
                buffer.samples = registration->sample_format.decode(bytes, peak);
                if (service_source_active || !service_) {
                    result.status = AudioPlayStatus::Queued;
                } else {
                    result =
                        service_->queue_pcm(std::move(buffer), applied_gain);
                }
            }
        }
    }
    ++registration->callback_count;
    registration->peak_since_report =
        std::max(registration->peak_since_report, peak);
    registration->sample_time +=
        native ? registration->buffer_frame_size : buffer_frame_size_;
    registration->in_flight = false;
    if (registration->callback_count == 1U ||
        registration->callback_count % 32U == 0U ||
        result.status == AudioPlayStatus::SinkError) {
        call.output().line(
            "[coreaudio-device] io-proc pid=" + std::to_string(process_id) +
            " callbacks=" + std::to_string(registration->callback_count) +
            " bytes=" + std::to_string(byte_count) +
            " peak=" + std::to_string(registration->peak_since_report) +
            " gain=" + std::to_string(applied_gain) +
            " status=" + std::to_string(static_cast<unsigned>(result.status)) +
            (result.detail.empty() ? std::string { }
                                   : " detail=" + result.detail));
        registration->peak_since_report = 0;
    }
}

void CoreAudioHle::device_property_info(UserlandHleCall& call)
{
    const auto* device = find_device(call.argument(0));
    if (device == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto property = call.argument(3);
    std::uint32_t size = 0;
    bool writable = false;
    switch (property) {
    case device_name_property:
        size = static_cast<std::uint32_t>(device->name.size() + 1U);
        break;
    case device_streams_property:
        size = sizeof(std::uint32_t);
        break;
    case nominal_sample_rate_property:
        size = sizeof(double);
        writable = true;
        break;
    case available_sample_rates_property:
        size = sizeof(double) * 2U;
        break;
    case buffer_frame_size_property:
        size = sizeof(std::uint32_t);
        writable = true;
        break;
    case volume_scalar_property:
        size = sizeof(float);
        writable = true;
        break;
    case device_is_running_property:
        size = sizeof(std::uint32_t);
        break;
    default:
        log_property(call, "get-info", property, unsupported_property);
        call.set_return(unsupported_property);
        return;
    }
    {
        const auto written =
            call.write32(call.argument(4), size) &&
            (call.argument(5) == 0 ||
                call.memory().write8(call.argument(5), writable));
        call.set_return(written ? 0U : unsupported_property);
    }
}

void CoreAudioHle::device_property(UserlandHleCall& call)
{
    const auto* device = find_device(call.argument(0));
    if (device == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto property = call.argument(3);
    if (property == device_streams_property) {
        // The legacy API scopes each device's stream list using isInput.
        if ((call.argument(2) != 0) != device->input) {
            const std::array<std::byte, 0> empty { };
            call.set_return(write_sized_data(
                                call, call.argument(4), call.argument(5), empty)
                                ? 0U
                                : unsupported_property);
            return;
        }
        std::array<std::byte, sizeof(std::uint32_t)> data { };
        store32(data, 0, device->stream);
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : unsupported_property);
        return;
    }
    if (property == device_name_property) {
        const auto capacity =
            call.memory().read32(call.argument(4)).value_or(0);
        const auto required =
            static_cast<std::uint32_t>(device->name.size() + 1U);
        if (capacity < required ||
            !call.memory().copy_in(call.argument(5),
                std::as_bytes(std::span { device->name.data(), required })) ||
            !call.write32(call.argument(4), required)) {
            call.set_return(unsupported_property);
            return;
        }
        call.set_return(0);
        return;
    }
    if (property == nominal_sample_rate_property) {
        std::array<std::byte, sizeof(double)> data { };
        store64(data, 0,
            std::bit_cast<std::uint64_t>(
                device_sample_rate(device->identifier)));
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : unsupported_property);
        return;
    }
    if (property == available_sample_rates_property) {
        const auto data =
            sample_rate_range(device_sample_rate(device->identifier));
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : unsupported_property);
        return;
    }
    if (property == buffer_frame_size_property) {
        std::array<std::byte, sizeof(std::uint32_t)> data { };
        store32(data, 0, buffer_frame_size_);
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : unsupported_property);
        return;
    }
    if (property == volume_scalar_property) {
        std::array<std::byte, sizeof(float)> data { };
        const auto value = device_volumes_.find(call.argument(0));
        const auto volume =
            value == device_volumes_.end() ? 1.0F : value->second;
        store32(data, 0, std::bit_cast<std::uint32_t>(volume));
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : unsupported_property);
        return;
    }
    if (property == device_is_running_property) {
        const auto registration = io_procs_.find(call.process_id());
        std::array<std::byte, sizeof(std::uint32_t)> data { };
        store32(data, 0,
            registration != io_procs_.end() && registration->second.running
                ? 1U
                : 0U);
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : unsupported_property);
        return;
    }
    log_property(call, "get", property, unsupported_property);
    call.set_return(unsupported_property);
}

void CoreAudioHle::device_set_property(UserlandHleCall& call)
{
    const auto* device = find_device(call.argument(0));
    if (device == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto property = call.argument(4);
    if (property == buffer_frame_size_property && call.argument(5) >= 4U) {
        if (const auto value = call.memory().read32(call.argument(6))) {
            buffer_frame_size_ = *value;
        }
    } else if (property == nominal_sample_rate_property &&
               call.argument(5) >= sizeof(double)) {
        if (const auto sample_rate =
                read_double(call.memory(), call.argument(6));
            sample_rate && std::isfinite(*sample_rate) &&
            *sample_rate >= 4'000.0 && *sample_rate <= 192'000.0) {
            stream_formats_[device->identifier] =
                StreamFormatState { *sample_rate,
                    device_channel_count(device->identifier) };
        } else {
            log_property(call, "set", property, parameter_error);
            call.set_return(parameter_error);
            return;
        }
    } else if (property == volume_scalar_property &&
               call.argument(5) >= sizeof(float)) {
        if (const auto encoded = call.memory().read32(call.argument(6))) {
            const auto value = std::bit_cast<float>(*encoded);
            if (std::isfinite(value)) {
                device_volumes_[call.argument(0)] =
                    std::clamp(value, 0.0F, 1.0F);
            }
        }
    }
    log_property(call, "set", property, 0);
    call.set_return(0);
}

void CoreAudioHle::stream_property_info(UserlandHleCall& call)
{
    if (find_stream(call.argument(0)) == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto property = call.argument(2);
    std::uint32_t size = 0;
    bool writable = false;
    if (property == physical_format_property) {
        size = stream_format_size;
        writable = true;
    } else if (property == available_physical_formats_property) {
        size = ranged_stream_format_size;
    } else {
        log_property(call, "stream-get-info", property, unsupported_property);
        call.set_return(unsupported_property);
        return;
    }
    const auto written = call.write32(call.argument(3), size) &&
                         (call.argument(4) == 0 ||
                             call.memory().write8(call.argument(4), writable));
    call.set_return(written ? 0U : unsupported_property);
}

void CoreAudioHle::stream_property(UserlandHleCall& call)
{
    const auto* device = find_stream(call.argument(0));
    if (device == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto property = call.argument(2);
    if (property == physical_format_property) {
        const auto data = stream_format(device_sample_rate(device->identifier),
            device_channel_count(device->identifier));
        call.set_return(
            write_sized_data(call, call.argument(3), call.argument(4), data)
                ? 0U
                : unsupported_property);
        return;
    }
    if (property == available_physical_formats_property) {
        const auto data =
            ranged_stream_format(device_sample_rate(device->identifier),
                device_channel_count(device->identifier));
        call.set_return(
            write_sized_data(call, call.argument(3), call.argument(4), data)
                ? 0U
                : unsupported_property);
        return;
    }
    log_property(call, "stream-get", property, unsupported_property);
    call.set_return(unsupported_property);
}

void CoreAudioHle::stream_set_property(UserlandHleCall& call)
{
    const auto* device = find_stream(call.argument(0));
    if (device == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto property = call.argument(3);
    if (property != physical_format_property) {
        log_property(call, "stream-set", property, unsupported_property);
        call.set_return(unsupported_property);
        return;
    }
    if (call.argument(4) < stream_format_size || call.argument(5) == 0) {
        call.set_return(parameter_error);
        return;
    }
    const auto address = call.argument(5);
    const auto sample_rate = read_double(call.memory(), address);
    const auto format = call.memory().read32(address + 8U);
    const auto flags = call.memory().read32(address + 12U);
    const auto bytes_per_packet = call.memory().read32(address + 16U);
    const auto frames_per_packet = call.memory().read32(address + 20U);
    const auto bytes_per_frame = call.memory().read32(address + 24U);
    const auto channels = call.memory().read32(address + 28U);
    const auto bits_per_channel = call.memory().read32(address + 32U);
    const auto valid =
        sample_rate && format && flags && bytes_per_packet &&
        frames_per_packet && bytes_per_frame && channels && bits_per_channel &&
        std::isfinite(*sample_rate) && *sample_rate >= 4'000.0 &&
        *sample_rate <= 192'000.0 && *format == linear_pcm_format &&
        (*flags & linear_pcm_flags) == linear_pcm_flags && *channels >= 1U &&
        *channels <= 8U && *bits_per_channel == 16U &&
        *frames_per_packet != 0U &&
        *bytes_per_frame == *channels * sizeof(std::int16_t) &&
        *bytes_per_packet == *bytes_per_frame * *frames_per_packet;
    if (!valid) {
        call.output().line("[coreaudio-device] stream-format pid=" +
                           std::to_string(call.process_id()) +
                           " device=" + std::to_string(device->identifier) +
                           " status=unsupported");
        call.set_return(unsupported_property);
        return;
    }
    stream_formats_[device->identifier] =
        StreamFormatState { *sample_rate, *channels };
    call.output().line("[coreaudio-device] stream-format pid=" +
                       std::to_string(call.process_id()) +
                       " device=" + std::to_string(device->identifier) +
                       " rate=" + std::to_string(*sample_rate) +
                       " channels=" + std::to_string(*channels) + " bits=" +
                       std::to_string(*bits_per_channel) + " status=0");
    call.set_return(0);
}

void CoreAudioHle::object_property(UserlandHleCall& call)
{
    // The firmware owns the HAL system object and its plug-in object tree.
    // In particular, device UID translation must reach that native registry.
    if (find_device(call.argument(0)) == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto address = call.argument(1);
    const auto property = call.memory().read32(address).value_or(0);
    if (property == jack_connected_property) {
        std::array<std::byte, sizeof(std::uint32_t)> data { };
        store32(data, 0, 0); // The emulator has no wired headset attached.
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : parameter_error);
        return;
    }
    if (is_boolean_hardware_control(property)) {
        std::array<std::byte, sizeof(std::uint32_t)> data { };
        const auto key =
            (static_cast<std::uint64_t>(call.argument(0)) << 32U) | property;
        store32(data, 0, hardware_control_states_[key]);
        call.set_return(
            write_sized_data(call, call.argument(4), call.argument(5), data)
                ? 0U
                : parameter_error);
        return;
    }
    log_property(call, "object-get", property, unsupported_property);
    call.set_return(unsupported_property);
}

void CoreAudioHle::object_set_property(UserlandHleCall& call)
{
    if (find_device(call.argument(0)) == nullptr) {
        call.resume_original_persistently();
        return;
    }
    const auto property = call.memory().read32(call.argument(1)).value_or(0);
    if (is_boolean_hardware_control(property) &&
        call.argument(4) >= sizeof(std::uint32_t)) {
        const auto value = call.memory().read32(call.argument(5));
        if (value) {
            const auto key =
                (static_cast<std::uint64_t>(call.argument(0)) << 32U) |
                property;
            hardware_control_states_[key] = *value != 0 ? 1U : 0U;
            log_property(call, "control-set", property, 0);
            call.set_return(0);
            return;
        }
    }
    log_property(call, "object-set", property, unsupported_property);
    call.set_return(unsupported_property);
}

void CoreAudioHle::property_listener(UserlandHleCall& call)
{
    // The adapter owns only its synthetic compatibility objects. Listeners for
    // the firmware HAL's object tree must remain native: plug-ins use the
    // system object's initialization transition to perform their deferred
    // setup.
    if (find_device(call.argument(0)) == nullptr &&
        find_stream(call.argument(0)) == nullptr) {
        call.resume_original_persistently();
        return;
    }
    call.set_return(0);
}

void CoreAudioHle::create_native_io_proc(UserlandHleCall& call)
{
    const auto device = call.argument(0);
    const auto callback = call.argument(1);
    const auto client_data = call.argument(2);
    const auto output_id = call.argument(3);
    if (callback == 0 || output_id == 0) {
        call.set_return(parameter_error);
        return;
    }
    // HAL objects retain their native IOProc registration: route and stream
    // usage queries depend on it. The host only schedules the saved callback.
    if (find_device(device) == nullptr) {
        call.resume_original_persistently(
            [this, device, callback, client_data, output_id](
                UserlandHleCall& completed) {
                if (completed.argument(0) != 0)
                    return;
                const auto io_proc_id =
                    completed.memory().read32(output_id).value_or(0);
                if (io_proc_id != 0)
                    record_native_io_proc(completed, device, callback,
                        client_data, io_proc_id);
            });
        return;
    }
    auto io_proc_id = next_native_io_proc_id_++;
    if (io_proc_id == 0)
        io_proc_id = next_native_io_proc_id_++;
    if (!call.write32(output_id, io_proc_id)) {
        call.set_return(parameter_error);
        return;
    }
    record_native_io_proc(call, device, callback, client_data, io_proc_id);
    call.set_return(0);
}

void CoreAudioHle::record_native_io_proc(UserlandHleCall& call,
    std::uint32_t device, std::uint32_t callback, std::uint32_t client_data,
    std::uint32_t io_proc_id)
{
    IoProcRegistration registration;
    registration.native = true;
    registration.process_id = call.process_id();
    registration.io_proc_id = io_proc_id;
    registration.device = device;
    registration.callback = callback;
    registration.client_data = client_data;
    registration.memory = &call.memory();
    registration.output = &call.output();
    native_io_procs_.emplace(io_proc_id, std::move(registration));
    call.output().line("[coreaudio-device] native-io-proc create pid=" +
                       std::to_string(call.process_id()) +
                       " device=" + std::to_string(device) +
                       " id=" + std::to_string(io_proc_id));
}

void CoreAudioHle::destroy_native_io_proc(UserlandHleCall& call)
{
    const auto io_proc_id = call.argument(1);
    if (find_device(call.argument(0)) == nullptr) {
        call.resume_original_persistently(
            [this, io_proc_id](UserlandHleCall& completed) {
                if (completed.argument(0) != 0)
                    return;
                const auto found = native_io_procs_.find(io_proc_id);
                if (found == native_io_procs_.end())
                    return;
                if (found->second.processor)
                    retired_io_proc_threads_.push_back(*found->second.processor);
                native_io_procs_.erase(found);
            });
        return;
    }
    const auto found = native_io_procs_.find(io_proc_id);
    if (found == native_io_procs_.end() ||
        found->second.process_id != call.process_id() ||
        found->second.device != call.argument(0)) {
        call.set_return(parameter_error);
        return;
    }
    if (found->second.processor)
        retired_io_proc_threads_.push_back(*found->second.processor);
    native_io_procs_.erase(found);
    call.set_return(0);
}

void CoreAudioHle::start_native_io_at_time(UserlandHleCall& call)
{
    // The first-generation HAL's start-at-time path is equivalent to an
    // immediate start when no hardware clock is present. Reuse the same
    // registration and callback buffer setup as AudioDeviceStart.
    start_io(call);
}

void CoreAudioHle::add_io_proc(UserlandHleCall& call)
{
    const auto device_id = call.argument(0);
    if (find_device(device_id) == nullptr) {
        const auto callback = call.argument(1);
        const auto client_data = call.argument(2);
        call.resume_original_persistently(
            [this, device_id, callback, client_data](UserlandHleCall& completed) {
                if (completed.argument(0) == 0)
                    record_native_io_proc(completed, device_id, callback,
                        client_data, callback);
            });
        return;
    }
    if (call.argument(1) == 0) {
        call.set_return(parameter_error);
        return;
    }
    IoProcRegistration registration;
    registration.process_id = call.process_id();
    registration.callback = call.argument(1);
    registration.client_data = call.argument(2);
    registration.device = call.argument(0);
    registration.memory = &call.memory();
    registration.output = &call.output();
    io_procs_[call.process_id()] = registration;
    call.output().line("[coreaudio-device] io-proc add pid=" +
                       std::to_string(call.process_id()) +
                       " device=" + std::to_string(call.argument(0)));
    call.set_return(0);
}

void CoreAudioHle::remove_io_proc(UserlandHleCall& call)
{
    const auto registration = io_procs_.find(call.process_id());
    if (find_device(call.argument(0)) == nullptr) {
        const auto callback = call.argument(1);
        call.resume_original_persistently(
            [this, callback](UserlandHleCall& completed) {
                if (completed.argument(0) != 0)
                    return;
                const auto found = native_io_procs_.find(callback);
                if (found == native_io_procs_.end())
                    return;
                if (found->second.processor)
                    retired_io_proc_threads_.push_back(*found->second.processor);
                native_io_procs_.erase(found);
            });
        return;
    }
    if (registration == io_procs_.end() ||
        registration->second.callback != call.argument(1)) {
        call.set_return(parameter_error);
        return;
    }
    call.output().line("[coreaudio-device] io-proc remove pid=" +
                       std::to_string(call.process_id()) + " callbacks=" +
                       std::to_string(registration->second.callback_count));
    if (registration->second.processor)
        retired_io_proc_threads_.push_back(*registration->second.processor);
    io_procs_.erase(registration);
    call.set_return(0);
}

void CoreAudioHle::start_io(UserlandHleCall& call)
{
    const auto device_id = call.argument(0);
    if (find_device(device_id) == nullptr) {
        start_native_io(call);
        return;
    }
    const auto registration = io_procs_.find(call.process_id());
    if (registration == io_procs_.end() ||
        registration->second.callback != call.argument(1) ||
        buffer_frame_size_ == 0 ||
        buffer_frame_size_ > maximum_buffer_frame_size) {
        call.set_return(parameter_error);
        return;
    }
    auto& state = registration->second;
    const auto* device = find_device(state.device);
    const auto sample_bytes =
        device == nullptr
            ? 0U
            : buffer_frame_size_ * device_channel_count(device->identifier) *
                  static_cast<std::uint32_t>(sizeof(std::int16_t));
    if (state.callback_return == 0) {
        state.callback_return =
            registry_.prepare_thread_callback_return(call.cpu()).value_or(0);
    }
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
    if (service_ && device != nullptr)
        service_->observe_service_output_stop_mode(device->stop_mode);
    call.output().line(
        "[coreaudio-device] io-proc start pid=" +
        std::to_string(call.process_id()) +
        " frames=" + std::to_string(buffer_frame_size_) +
        " bytes=" + std::to_string(state.output_sample_bytes) + " rate=" +
        std::to_string(device_sample_rate(device->identifier)) + " channels=" +
        std::to_string(device_channel_count(device->identifier)));
    call.set_return(0);
}

void CoreAudioHle::stop_io(UserlandHleCall& call)
{
    const auto device_id = call.argument(0);
    if (find_device(device_id) == nullptr) {
        auto registration = native_io_procs_.find(call.argument(1));
        if (registration == native_io_procs_.end()) {
            registration = std::find_if(native_io_procs_.begin(),
                native_io_procs_.end(), [&](const auto& entry) {
                    return entry.second.process_id == call.process_id() &&
                           entry.second.device == device_id &&
                           entry.second.callback == call.argument(1);
                });
        }
        if (registration == native_io_procs_.end() ||
            registration->second.process_id != call.process_id() ||
            registration->second.device != device_id) {
            call.set_return(parameter_error);
            return;
        }
        registration->second.running = false;
        if (registration->second.processor) {
            retired_io_proc_threads_.push_back(*registration->second.processor);
            registration->second.processor.reset();
        }
        call.output().line("[coreaudio-device] native-io-proc stop pid=" +
                           std::to_string(call.process_id()) + " id=" +
                           std::to_string(call.argument(1)) + " callbacks=" +
                           std::to_string(registration->second.callback_count));
        call.set_return(0);
        return;
    }
    const auto registration = io_procs_.find(call.process_id());
    if (registration == io_procs_.end() ||
        registration->second.callback != call.argument(1)) {
        call.set_return(parameter_error);
        return;
    }
    registration->second.running = false;
    if (registration->second.processor) {
        retired_io_proc_threads_.push_back(*registration->second.processor);
        registration->second.processor.reset();
    }
    call.output().line("[coreaudio-device] io-proc stop pid=" +
                       std::to_string(call.process_id()) + " callbacks=" +
                       std::to_string(registration->second.callback_count));
    call.set_return(0);
}

} // namespace shade
