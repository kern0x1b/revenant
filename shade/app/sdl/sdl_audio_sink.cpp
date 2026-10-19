// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Deliver emulator PCM audio to the SDL audio device.

#include "app/sdl_audio_sink.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <list>
#include <mutex>
#include <type_traits>
#include <utility>
#include <vector>

#if defined(SHADE_HAS_SDL2)
#include <SDL.h>
#endif

namespace shade {

struct SdlAudioSink::Impl {
    mutable std::mutex control_mutex;
    mutable std::mutex queue_mutex;
    std::string error;
#if defined(SHADE_HAS_SDL2)
    struct QueuedChunk {
        std::vector<std::int16_t> samples;
        std::size_t next_sample { };
    };

    SDL_AudioDeviceID device { };
    SDL_AudioSpec format { };
    SDL_AudioStream* streaming_converter { };
    std::uint32_t streaming_sample_rate { };
    std::uint16_t streaming_channel_count { };
    SDL_AudioFormat streaming_sample_format { };
    bool owns_audio_subsystem { };
    bool device_started { };
    std::list<QueuedChunk> queued_chunks;
    // The callback only splices completed nodes here. Their storage is released
    // later by a producer/control call, outside the real-time callback.
    std::list<QueuedChunk> retired_chunks;
    std::size_t queued_sample_count { };
    std::size_t output_channel_count { 1U };
    // CoreAudio produces one hardware period at a time. Keep a short, bounded
    // device lead at the start of a streaming run so the independently timed
    // host callback does not race the producer's first adjacent buffers. Three
    // periods cover normal guest/host scheduling jitter without making effects
    // audibly late or allowing an unbounded audio queue to grow.
    static constexpr std::size_t streaming_lead_periods = 3U;
    std::size_t lead_silence_sample_count { };
    bool streaming_needs_lead { true };
    std::size_t fade_frames_remaining { };
    std::size_t fade_frames_total { };
    float gain { 1.0F };

    void retire_all_locked()
    {
        retired_chunks.splice(retired_chunks.end(), queued_chunks);
        queued_sample_count = 0;
        lead_silence_sample_count = 0;
        fade_frames_remaining = 0;
        fade_frames_total = 0;
    }

    void trim_pending_samples_locked(std::size_t sample_count)
    {
        sample_count = std::min(sample_count, queued_sample_count);
        auto keep = sample_count;
        for (auto chunk = queued_chunks.begin();
            chunk != queued_chunks.end();) {
            const auto available = chunk->samples.size() - chunk->next_sample;
            if (keep >= available) {
                keep -= available;
                ++chunk;
                continue;
            }
            if (keep != 0) {
                chunk->samples.resize(chunk->next_sample + keep);
                ++chunk;
            }
            retired_chunks.splice(retired_chunks.end(), queued_chunks, chunk,
                queued_chunks.end());
            break;
        }
        queued_sample_count = sample_count;
    }

    static void consume(void* userdata, Uint8* output, int byte_count)
    {
        if (userdata == nullptr || output == nullptr || byte_count <= 0)
            return;
        std::memset(output, 0, static_cast<std::size_t>(byte_count));
        auto& state = *static_cast<Impl*>(userdata);
        std::lock_guard lock { state.queue_mutex };
        const auto output_samples =
            static_cast<std::size_t>(byte_count) / sizeof(std::int16_t);
        auto* samples = reinterpret_cast<std::int16_t*>(output);
        const auto channels = state.output_channel_count;
        auto output_offset = std::size_t { };
        const auto lead_samples =
            std::min(output_samples, state.lead_silence_sample_count);
        state.lead_silence_sample_count -= lead_samples;
        output_offset += lead_samples;
        while (output_offset < output_samples && !state.queued_chunks.empty()) {
            auto& chunk = state.queued_chunks.front();
            const auto available = chunk.samples.size() - chunk.next_sample;
            const auto count =
                std::min(output_samples - output_offset, available);
            auto copied = std::size_t { };

            const auto fade_frames =
                std::min(state.fade_frames_remaining, count / channels);
            const auto fade_samples = fade_frames * channels;
            for (std::size_t frame = 0; frame < fade_frames; ++frame) {
                const auto remaining = state.fade_frames_remaining - frame;
                const auto envelope =
                    state.fade_frames_total > 1U
                        ? static_cast<float>(remaining - 1U) /
                              static_cast<float>(state.fade_frames_total - 1U)
                        : 0.0F;
                for (std::size_t channel = 0; channel < channels; ++channel) {
                    const auto index = frame * channels + channel;
                    const auto scaled = std::lround(
                        static_cast<float>(
                            chunk.samples[chunk.next_sample + index]) *
                        state.gain * envelope);
                    samples[output_offset + index] =
                        static_cast<std::int16_t>(std::clamp<long>(scaled,
                            std::numeric_limits<std::int16_t>::min(),
                            std::numeric_limits<std::int16_t>::max()));
                }
            }
            copied += fade_samples;
            state.fade_frames_remaining -= fade_frames;
            if (state.fade_frames_remaining == 0)
                state.fade_frames_total = 0;

            if (state.gain == 1.0F) {
                std::memcpy(samples + output_offset + copied,
                    chunk.samples.data() + chunk.next_sample + copied,
                    (count - copied) * sizeof(std::int16_t));
            } else {
                for (; copied < count; ++copied) {
                    const auto scaled = std::lround(
                        static_cast<float>(
                            chunk.samples[chunk.next_sample + copied]) *
                        state.gain);
                    samples[output_offset + copied] =
                        static_cast<std::int16_t>(std::clamp<long>(scaled,
                            std::numeric_limits<std::int16_t>::min(),
                            std::numeric_limits<std::int16_t>::max()));
                }
            }

            chunk.next_sample += count;
            state.queued_sample_count -= count;
            output_offset += count;
            if (chunk.next_sample == chunk.samples.size()) {
                state.retired_chunks.splice(state.retired_chunks.end(),
                    state.queued_chunks, state.queued_chunks.begin());
            }
        }
        if (state.queued_chunks.empty()) {
            state.fade_frames_remaining = 0;
            state.fade_frames_total = 0;
        }
    }
#endif
};

SdlAudioSink::SdlAudioSink()
    : impl_ { std::make_unique<Impl>() }
{
}

SdlAudioSink::~SdlAudioSink()
{
#if defined(SHADE_HAS_SDL2)
    SDL_AudioDeviceID device = 0;
    SDL_AudioStream* streaming_converter = nullptr;
    bool owns_audio_subsystem = false;
    {
        std::lock_guard lock { impl_->control_mutex };
        device = std::exchange(impl_->device, 0);
        streaming_converter =
            std::exchange(impl_->streaming_converter, nullptr);
        owns_audio_subsystem =
            std::exchange(impl_->owns_audio_subsystem, false);
    }
    if (streaming_converter != nullptr)
        SDL_FreeAudioStream(streaming_converter);
    if (device != 0)
        SDL_CloseAudioDevice(device);
    if (owns_audio_subsystem)
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
#endif
}

bool SdlAudioSink::available()
{
#if defined(SHADE_HAS_SDL2)
    return true;
#else
    return false;
#endif
}

bool SdlAudioSink::play(const AudioBuffer& buffer)
{
#if defined(SHADE_HAS_SDL2)
    std::unique_lock control_lock { impl_->control_mutex };
    if (buffer.sample_rate == 0 || buffer.channel_count == 0 ||
        buffer.empty()) {
        impl_->error = "invalid empty audio buffer";
        return false;
    }
    struct SourceView {
        SDL_AudioFormat format;
        const void* data;
        std::size_t byte_count;
    };
    const auto source = std::visit(
        [](const auto& samples) {
            using Sample = typename std::decay_t<decltype(samples)>::value_type;
            constexpr auto format =
                std::is_same_v<Sample, std::int16_t> ? AUDIO_S16SYS :
                std::is_same_v<Sample, std::int32_t> ? AUDIO_S32SYS :
                                                       AUDIO_F32SYS;
            return SourceView { format, samples.data(),
                samples.size() * sizeof(Sample) };
        },
        buffer.samples);
    if (impl_->device == 0) {
        if ((SDL_WasInit(SDL_INIT_AUDIO) & SDL_INIT_AUDIO) == 0U) {
            if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
                impl_->error = SDL_GetError();
                return false;
            }
            impl_->owns_audio_subsystem = true;
        }
        SDL_AudioSpec requested { };
        requested.freq = 44100;
        requested.format = AUDIO_S16SYS;
        requested.channels = 2;
        requested.samples = 1024;
        requested.callback = &Impl::consume;
        requested.userdata = impl_.get();
        impl_->device =
            SDL_OpenAudioDevice(nullptr, 0, &requested, &impl_->format, 0);
        if (impl_->device == 0) {
            impl_->error = SDL_GetError();
            return false;
        }
        {
            std::lock_guard queue_lock { impl_->queue_mutex };
            impl_->output_channel_count =
                std::max<std::size_t>(1U, impl_->format.channels);
        }
    }

    SDL_AudioStream* owned_stream = nullptr;
    SDL_AudioStream* stream = nullptr;
    if (buffer.streaming) {
        if (impl_->streaming_converter != nullptr &&
            (impl_->streaming_sample_rate != buffer.sample_rate ||
                impl_->streaming_channel_count != buffer.channel_count ||
                impl_->streaming_sample_format != source.format)) {
            SDL_FreeAudioStream(impl_->streaming_converter);
            impl_->streaming_converter = nullptr;
        }
        if (impl_->streaming_converter == nullptr) {
            impl_->streaming_converter = SDL_NewAudioStream(source.format,
                static_cast<Uint8>(buffer.channel_count),
                static_cast<int>(buffer.sample_rate), impl_->format.format,
                impl_->format.channels, impl_->format.freq);
            impl_->streaming_sample_rate = buffer.sample_rate;
            impl_->streaming_channel_count = buffer.channel_count;
            impl_->streaming_sample_format = source.format;
        }
        stream = impl_->streaming_converter;
    } else {
        owned_stream = SDL_NewAudioStream(source.format,
            static_cast<Uint8>(buffer.channel_count),
            static_cast<int>(buffer.sample_rate), impl_->format.format,
            impl_->format.channels, impl_->format.freq);
        stream = owned_stream;
    }
    if (stream == nullptr) {
        impl_->error = SDL_GetError();
        return false;
    }
    if (source.byte_count >
            static_cast<std::size_t>(std::numeric_limits<int>::max()) ||
        SDL_AudioStreamPut(stream, source.data,
            static_cast<int>(source.byte_count)) != 0 ||
        (!buffer.streaming && SDL_AudioStreamFlush(stream) != 0)) {
        impl_->error = SDL_GetError();
        if (owned_stream != nullptr)
            SDL_FreeAudioStream(owned_stream);
        return false;
    }
    const auto converted_size = SDL_AudioStreamAvailable(stream);
    if (converted_size < 0) {
        impl_->error = SDL_GetError();
        if (owned_stream != nullptr)
            SDL_FreeAudioStream(owned_stream);
        return false;
    }
    if (converted_size == 0) {
        if (owned_stream != nullptr)
            SDL_FreeAudioStream(owned_stream);
        impl_->error.clear();
        return true;
    }
    const auto output_frame_bytes =
        sizeof(std::int16_t) *
        std::max<std::size_t>(1U, impl_->format.channels);
    if (converted_size % static_cast<int>(output_frame_bytes) != 0) {
        impl_->error = "audio conversion is not frame-aligned";
        if (owned_stream != nullptr)
            SDL_FreeAudioStream(owned_stream);
        return false;
    }
    std::vector<std::int16_t> converted(
        static_cast<std::size_t>(converted_size) / sizeof(std::int16_t));
    const auto received =
        SDL_AudioStreamGet(stream, converted.data(), converted_size);
    if (owned_stream != nullptr)
        SDL_FreeAudioStream(owned_stream);
    if (received != converted_size) {
        impl_->error = SDL_GetError();
        return false;
    }

    std::list<Impl::QueuedChunk> incoming;
    incoming.push_back({ std::move(converted), 0 });
    std::list<Impl::QueuedChunk> retired;
    bool start_device = false;
    {
        std::lock_guard queue_lock { impl_->queue_mutex };
        retired.splice(retired.end(), impl_->retired_chunks);
        if (buffer.streaming && impl_->streaming_needs_lead) {
            // A queued fade or other predecessor already provides device lead.
            // Prepending global silence in that case would put the delay before
            // the older samples and reverse the intended stop/replacement
            // ordering.
            if (impl_->queued_sample_count == 0 &&
                impl_->lead_silence_sample_count == 0) {
                impl_->lead_silence_sample_count =
                    static_cast<std::size_t>(impl_->format.samples) *
                    impl_->output_channel_count * Impl::streaming_lead_periods;
            }
            impl_->streaming_needs_lead = false;
        }
        impl_->queued_sample_count += incoming.front().samples.size();
        impl_->queued_chunks.splice(
            impl_->queued_chunks.end(), incoming, incoming.begin());
        if (!impl_->device_started) {
            impl_->device_started = true;
            start_device = true;
        }
    }
    impl_->error.clear();
    if (start_device)
        SDL_PauseAudioDevice(impl_->device, 0);
    return true;
#else
    std::lock_guard lock { impl_->control_mutex };
    static_cast<void>(buffer);
    impl_->error = "SDL2 audio support was not built";
    return false;
#endif
}

bool SdlAudioSink::has_pending_audio() const
{
#if defined(SHADE_HAS_SDL2)
    std::lock_guard lock { impl_->queue_mutex };
    return impl_->queued_sample_count != 0;
#else
    return false;
#endif
}

void SdlAudioSink::set_gain(float gain)
{
#if defined(SHADE_HAS_SDL2)
    std::lock_guard lock { impl_->queue_mutex };
    impl_->gain = std::clamp(gain, 0.0F, 1.0F);
#else
    static_cast<void>(gain);
#endif
}

void SdlAudioSink::stop(AudioStopMode mode)
{
#if defined(SHADE_HAS_SDL2)
    std::unique_lock control_lock { impl_->control_mutex };
    if (impl_->streaming_converter != nullptr)
        SDL_AudioStreamClear(impl_->streaming_converter);
    std::list<Impl::QueuedChunk> retired;
    {
        std::lock_guard queue_lock { impl_->queue_mutex };
        retired.splice(retired.end(), impl_->retired_chunks);
        impl_->lead_silence_sample_count = 0;
        impl_->streaming_needs_lead = true;
        if (mode == AudioStopMode::FadeOut && impl_->device != 0 &&
            impl_->queued_sample_count != 0) {
            const auto channels = impl_->output_channel_count;
            if (impl_->fade_frames_remaining != 0) {
                impl_->trim_pending_samples_locked(
                    impl_->fade_frames_remaining * channels);
                retired.splice(retired.end(), impl_->retired_chunks);
                return;
            }
            constexpr std::size_t fade_duration_milliseconds = 40;
            const auto available_frames = impl_->queued_sample_count / channels;
            const auto requested_frames =
                static_cast<std::size_t>(impl_->format.freq) *
                fade_duration_milliseconds / 1000U;
            const auto fade_frames =
                std::min(available_frames, requested_frames);
            if (fade_frames != 0) {
                impl_->trim_pending_samples_locked(fade_frames * channels);
                impl_->fade_frames_remaining = fade_frames;
                impl_->fade_frames_total = fade_frames;
                retired.splice(retired.end(), impl_->retired_chunks);
                return;
            }
        }
        impl_->retire_all_locked();
        retired.splice(retired.end(), impl_->retired_chunks);
    }
#else
    static_cast<void>(mode);
#endif
}

std::string SdlAudioSink::last_error() const
{
    std::lock_guard lock { impl_->control_mutex };
    return impl_->error;
}

} // namespace shade
