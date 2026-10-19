// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Decode audio files into emulator PCM buffers using FFmpeg.

#include "host/ffmpeg_audio_decoder.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <memory>
#include <mutex>
#include <string>

#if defined(SHADE_HAS_FFMPEG)
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
}
#endif

namespace shade {
namespace {

#if defined(SHADE_HAS_FFMPEG)
    std::string ffmpeg_error(int status)
    {
        std::array<char, AV_ERROR_MAX_STRING_SIZE> text { };
        if (av_strerror(status, text.data(), text.size()) < 0)
            return "unknown FFmpeg error";
        return text.data();
    }

    struct FormatCloser {
        void operator()(AVFormatContext* context) const
        {
            avformat_close_input(&context);
        }
    };

    struct CodecCloser {
        void operator()(AVCodecContext* context) const
        {
            avcodec_free_context(&context);
        }
    };

    struct PacketCloser {
        void operator()(AVPacket* packet) const { av_packet_free(&packet); }
    };

    struct FrameCloser {
        void operator()(AVFrame* frame) const { av_frame_free(&frame); }
    };

    struct ResamplerCloser {
        void operator()(SwrContext* context) const { swr_free(&context); }
    };
#endif

} // namespace

struct FfmpegAudioDecoder::Impl {
    mutable std::mutex mutex;
    std::string error;
};

FfmpegAudioDecoder::FfmpegAudioDecoder()
    : impl_ { std::make_unique<Impl>() }
{
}

FfmpegAudioDecoder::~FfmpegAudioDecoder() = default;

bool FfmpegAudioDecoder::available()
{
#if defined(SHADE_HAS_FFMPEG)
    return true;
#else
    return false;
#endif
}

std::optional<AudioBuffer> FfmpegAudioDecoder::decode(
    const std::filesystem::path& path)
{
    std::lock_guard lock { impl_->mutex };
#if defined(SHADE_HAS_FFMPEG)
    AVFormatContext* raw_format = nullptr;
    auto status =
        avformat_open_input(&raw_format, path.c_str(), nullptr, nullptr);
    if (status < 0) {
        impl_->error = ffmpeg_error(status);
        return std::nullopt;
    }
    std::unique_ptr<AVFormatContext, FormatCloser> format { raw_format };
    status = avformat_find_stream_info(format.get(), nullptr);
    if (status < 0) {
        impl_->error = ffmpeg_error(status);
        return std::nullopt;
    }
    const auto stream_index = av_find_best_stream(
        format.get(), AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (stream_index < 0) {
        impl_->error = ffmpeg_error(stream_index);
        return std::nullopt;
    }
    const auto* parameters = format->streams[stream_index]->codecpar;
    const auto* codec = avcodec_find_decoder(parameters->codec_id);
    if (codec == nullptr) {
        impl_->error = "no FFmpeg decoder for audio codec";
        return std::nullopt;
    }
    std::unique_ptr<AVCodecContext, CodecCloser> codec_context {
        avcodec_alloc_context3(codec)
    };
    if (!codec_context) {
        impl_->error = "failed to allocate FFmpeg codec context";
        return std::nullopt;
    }
    status = avcodec_parameters_to_context(codec_context.get(), parameters);
    if (status < 0 ||
        (status = avcodec_open2(codec_context.get(), codec, nullptr)) < 0) {
        impl_->error = ffmpeg_error(status);
        return std::nullopt;
    }
    if (codec_context->sample_rate <= 0 ||
        codec_context->ch_layout.nb_channels <= 0) {
        impl_->error = "invalid decoded audio format";
        return std::nullopt;
    }

    AVChannelLayout output_layout { };
    av_channel_layout_default(&output_layout, 2);
    SwrContext* raw_resampler = nullptr;
    status =
        swr_alloc_set_opts2(&raw_resampler, &output_layout, AV_SAMPLE_FMT_S16,
            codec_context->sample_rate, &codec_context->ch_layout,
            codec_context->sample_fmt, codec_context->sample_rate, 0, nullptr);
    av_channel_layout_uninit(&output_layout);
    if (status < 0 || raw_resampler == nullptr) {
        impl_->error = status < 0 ? ffmpeg_error(status)
                                  : "failed to allocate FFmpeg resampler";
        return std::nullopt;
    }
    std::unique_ptr<SwrContext, ResamplerCloser> resampler { raw_resampler };
    status = swr_init(resampler.get());
    if (status < 0) {
        impl_->error = ffmpeg_error(status);
        return std::nullopt;
    }

    std::unique_ptr<AVPacket, PacketCloser> packet { av_packet_alloc() };
    std::unique_ptr<AVFrame, FrameCloser> frame { av_frame_alloc() };
    if (!packet || !frame) {
        impl_->error = "failed to allocate FFmpeg decode buffers";
        return std::nullopt;
    }
    AudioBuffer result { static_cast<std::uint32_t>(codec_context->sample_rate),
        2, { } };
    auto& samples = std::get<std::vector<std::int16_t>>(result.samples);
    const auto append_frame = [&]() -> bool {
        const auto capacity =
            swr_get_out_samples(resampler.get(), frame->nb_samples);
        if (capacity < 0 ||
            static_cast<std::uint64_t>(capacity) * result.channel_count >
                std::numeric_limits<std::size_t>::max() -
                    samples.size()) {
            impl_->error = capacity < 0 ? ffmpeg_error(capacity)
                                        : "decoded audio is too large";
            return false;
        }
        const auto original_size = samples.size();
        samples.resize(
            original_size +
            static_cast<std::size_t>(capacity) * result.channel_count);
        auto* output = reinterpret_cast<std::uint8_t*>(
            samples.data() + static_cast<std::ptrdiff_t>(original_size));
        const auto converted = swr_convert(resampler.get(), &output, capacity,
            const_cast<const std::uint8_t**>(frame->extended_data),
            frame->nb_samples);
        if (converted < 0) {
            impl_->error = ffmpeg_error(converted);
            return false;
        }
        samples.resize(
            original_size +
            static_cast<std::size_t>(converted) * result.channel_count);
        return true;
    };
    const auto receive_frames = [&]() -> bool {
        while (true) {
            const auto receive =
                avcodec_receive_frame(codec_context.get(), frame.get());
            if (receive == AVERROR(EAGAIN) || receive == AVERROR_EOF)
                return true;
            if (receive < 0) {
                impl_->error = ffmpeg_error(receive);
                return false;
            }
            if (!append_frame())
                return false;
            av_frame_unref(frame.get());
        }
    };

    while ((status = av_read_frame(format.get(), packet.get())) >= 0) {
        if (packet->stream_index == stream_index) {
            status = avcodec_send_packet(codec_context.get(), packet.get());
            if (status < 0 || !receive_frames()) {
                if (status < 0)
                    impl_->error = ffmpeg_error(status);
                return std::nullopt;
            }
        }
        av_packet_unref(packet.get());
    }
    if (status != AVERROR_EOF) {
        impl_->error = ffmpeg_error(status);
        return std::nullopt;
    }
    status = avcodec_send_packet(codec_context.get(), nullptr);
    if (status < 0 || !receive_frames()) {
        if (status < 0)
            impl_->error = ffmpeg_error(status);
        return std::nullopt;
    }
    if (samples.empty()) {
        impl_->error = "FFmpeg decoded no audio samples";
        return std::nullopt;
    }
    impl_->error.clear();
    return result;
#else
    static_cast<void>(path);
    impl_->error = "FFmpeg audio support was not built";
    return std::nullopt;
#endif
}

std::string FfmpegAudioDecoder::last_error() const
{
    std::lock_guard lock { impl_->mutex };
    return impl_->error;
}

} // namespace shade
