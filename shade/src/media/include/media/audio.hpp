// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest audio playback, PCM timelines and host audio sink
// coordination.

#pragma once

#include <cstdint>
#include <deque>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

namespace shade {

using AudioSamples = std::variant<std::vector<std::int16_t>,
    std::vector<std::int32_t>, std::vector<float>>;

struct AudioBuffer {
    std::uint32_t sample_rate { };
    std::uint16_t channel_count { };
    AudioSamples samples { std::vector<std::int16_t> { } };
    // Hardware callbacks are adjacent pieces of one PCM timeline. Backends may
    // retain converter history between these buffers; decoded files remain
    // self-contained and flush their converter at the end.
    bool streaming { };

    [[nodiscard]] bool empty() const
    {
        return std::visit(
            [](const auto& values) { return values.empty(); }, samples);
    }
};

enum class AudioStopMode {
    Immediate,
    FadeOut,
};

class AudioSink {
public:
    virtual ~AudioSink() = default;
    [[nodiscard]] virtual bool play(const AudioBuffer& buffer) = 0;
    // Reports whether the host backend still owns samples that have not reached
    // the output device. Guest service state uses this completion boundary to
    // hand control back to its normal PCM path after a decoded fallback ends.
    [[nodiscard]] virtual bool has_pending_audio() const = 0;
    virtual void set_gain(float gain) = 0;
    virtual void stop(AudioStopMode mode = AudioStopMode::Immediate) = 0;
    [[nodiscard]] virtual std::string last_error() const = 0;
};

class AudioDecoder {
public:
    virtual ~AudioDecoder() = default;
    [[nodiscard]] virtual std::optional<AudioBuffer> decode(
        const std::filesystem::path& path) = 0;
    [[nodiscard]] virtual std::string last_error() const = 0;
};

enum class AudioPlayStatus {
    Queued,
    UnknownSound,
    ResourceUnavailable,
    UnsupportedResource,
    NoSink,
    SinkError,
};

struct AudioPlayResult {
    AudioPlayStatus status { AudioPlayStatus::UnknownSound };
    std::filesystem::path guest_path;
    std::string detail;
    float applied_gain { 1.0F };
};

struct AudioClientObject {
    std::uint32_t client { };
    std::uint32_t object { };

    bool operator==(const AudioClientObject&) const = default;
    auto operator<=>(const AudioClientObject&) const = default;
};

class AudioService {
public:
    explicit AudioService(std::filesystem::path rootfs);

    void set_sink(std::shared_ptr<AudioSink> sink);
    void set_decoder(std::shared_ptr<AudioDecoder> decoder);
    [[nodiscard]] AudioPlayResult play_audio_file(
        const std::filesystem::path& guest_path, bool replace_current = false,
        float device_volume = 1.0F);
    [[nodiscard]] AudioPlayResult queue_pcm(
        AudioBuffer buffer, float device_volume = 1.0F);
    void stop_playback(AudioStopMode mode = AudioStopMode::Immediate);

    // The guest FigMovie service is the source-of-truth for source selection.
    // A create request's path is correlated with its reply through the Mach
    // reply-port object; subsequent properties address the returned movie ID.
    void observe_service_source_create_request(
        std::uint32_t reply_object, std::filesystem::path guest_path);
    [[nodiscard]] std::optional<std::filesystem::path>
    observe_service_source_create_reply(
        std::uint32_t reply_object, std::uint32_t source);
    [[nodiscard]] bool observe_service_source_property(
        std::optional<std::uint32_t> source, std::string_view property,
        float value);
    void observe_service_output_stop_mode(AudioStopMode mode);
    [[nodiscard]] bool service_source_playing();

    void observe_category_volume(std::string category, float value);
    [[nodiscard]] float category_volume(std::string_view category) const;

    void initialize_player(AudioClientObject player, AudioClientObject queue);
    void set_player_queue(AudioClientObject player, AudioClientObject queue);
    [[nodiscard]] AudioClientObject player_queue(
        AudioClientObject player) const;
    [[nodiscard]] AudioPlayResult set_player_rate(
        AudioClientObject player, float rate);
    [[nodiscard]] float player_rate(AudioClientObject player) const;
    void stop_player(AudioClientObject player);
    void set_player_repeat_mode(AudioClientObject player, std::uint32_t mode);
    [[nodiscard]] std::uint32_t player_repeat_mode(
        AudioClientObject player) const;

    void initialize_queue(AudioClientObject queue);
    void clear_queue(AudioClientObject queue);
    [[nodiscard]] bool append_queue_item(
        AudioClientObject queue, AudioClientObject item);
    void set_item_path(AudioClientObject item, std::filesystem::path path);
    [[nodiscard]] std::optional<std::filesystem::path> item_path(
        AudioClientObject item) const;

private:
    [[nodiscard]] std::optional<AudioBuffer> load_file_locked(
        const std::filesystem::path& guest_path, AudioPlayResult& result);
    void load_category_aliases();
    void load_system_volume_state();
    [[nodiscard]] std::string canonical_category_locked(
        std::string_view category) const;
    void retire_finished_service_source_locked();
    [[nodiscard]] AudioPlayResult play_audio_file_with_gain(
        const std::filesystem::path& guest_path, bool replace_current,
        float gain, AudioStopMode replacement_mode = AudioStopMode::Immediate);

    std::filesystem::path rootfs_;
    mutable std::mutex mutex_;
    std::shared_ptr<AudioSink> sink_;
    std::shared_ptr<AudioDecoder> decoder_;
    std::map<std::filesystem::path, AudioBuffer> decoded_files_;
    struct ServiceSource {
        std::filesystem::path path;
        std::optional<float> user_volume;
        float rate { };
        AudioStopMode stop_mode { AudioStopMode::Immediate };
    };
    std::map<std::uint32_t, std::deque<std::filesystem::path>>
        pending_service_source_creates_;
    std::map<std::uint32_t, ServiceSource> service_sources_;
    std::optional<std::uint32_t> latest_service_source_id_;
    std::optional<std::uint32_t> playing_service_source_id_;
    std::optional<std::filesystem::path> playing_service_source_;
    AudioStopMode service_output_stop_mode_ { AudioStopMode::Immediate };
    struct PlayerState {
        AudioClientObject queue;
        float rate { };
        std::uint32_t repeat_mode { };
    };
    std::map<AudioClientObject, PlayerState> players_;
    std::map<AudioClientObject, std::vector<AudioClientObject>> queues_;
    std::map<AudioClientObject, std::filesystem::path> items_;
    std::map<std::string, std::string, std::less<>> category_aliases_;
    std::map<std::string, float, std::less<>> category_volumes_ { { "Ringtone",
        0.5F } };
};

} // namespace shade
