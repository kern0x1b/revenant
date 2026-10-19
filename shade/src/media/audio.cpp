// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest audio playback, PCM timelines and host audio sink
// coordination.

#include "media/audio.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cctype>
#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <span>
#include <string>
#include <utility>

#if defined(SHADE_HAS_LIBPLIST)
#include <plist/plist.h>
#endif

namespace shade {
namespace {

    constexpr std::array<std::byte, 4> caf_signature { std::byte { 'c' },
        std::byte { 'a' }, std::byte { 'f' }, std::byte { 'f' } };
    constexpr std::array<std::byte, 4> description_chunk { std::byte { 'd' },
        std::byte { 'e' }, std::byte { 's' }, std::byte { 'c' } };
    constexpr std::array<std::byte, 4> data_chunk { std::byte { 'd' },
        std::byte { 'a' }, std::byte { 't' }, std::byte { 'a' } };
    constexpr std::array<std::byte, 4> linear_pcm_format { std::byte { 'l' },
        std::byte { 'p' }, std::byte { 'c' }, std::byte { 'm' } };
    constexpr std::size_t caf_header_size = 8;
    constexpr std::size_t caf_chunk_header_size = 12;
    constexpr std::size_t caf_description_size = 32;
    constexpr std::size_t caf_data_edit_count_size = 4;
    constexpr std::uint32_t signed_little_endian_pcm_flags = 2;
    constexpr std::uint32_t supported_bits_per_channel = 16;

    std::uint32_t read_big_endian_u32(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        return (std::to_integer<std::uint32_t>(bytes[offset]) << 24U) |
               (std::to_integer<std::uint32_t>(bytes[offset + 1U]) << 16U) |
               (std::to_integer<std::uint32_t>(bytes[offset + 2U]) << 8U) |
               std::to_integer<std::uint32_t>(bytes[offset + 3U]);
    }

    std::uint64_t read_big_endian_u64(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint64_t value = 0;
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            value = (value << 8U) |
                    std::to_integer<std::uint64_t>(bytes[offset + index]);
        }
        return value;
    }

    double read_big_endian_f64(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        return std::bit_cast<double>(read_big_endian_u64(bytes, offset));
    }

    bool equal_tag(std::span<const std::byte> bytes, std::size_t offset,
        const std::array<std::byte, 4>& tag)
    {
        return offset <= bytes.size() && tag.size() <= bytes.size() - offset &&
               std::equal(tag.begin(), tag.end(),
                   bytes.begin() + static_cast<std::ptrdiff_t>(offset));
    }

    std::optional<std::vector<std::byte>> read_file(
        const std::filesystem::path& path)
    {
        std::ifstream stream { path, std::ios::binary | std::ios::ate };
        if (!stream)
            return std::nullopt;
        const auto end = stream.tellg();
        if (end < 0)
            return std::nullopt;
        const auto size = static_cast<std::uint64_t>(end);
        if (size > std::numeric_limits<std::size_t>::max())
            return std::nullopt;
        std::vector<std::byte> bytes(static_cast<std::size_t>(size));
        stream.seekg(0);
        if (!bytes.empty() &&
            !stream.read(reinterpret_cast<char*>(bytes.data()),
                static_cast<std::streamsize>(bytes.size()))) {
            return std::nullopt;
        }
        return bytes;
    }

    std::optional<AudioBuffer> decode_linear_pcm_caf(
        std::span<const std::byte> bytes)
    {
        if (bytes.size() < caf_header_size ||
            !equal_tag(bytes, 0, caf_signature))
            return std::nullopt;

        std::optional<std::uint32_t> sample_rate;
        std::optional<std::uint32_t> channel_count;
        std::optional<std::uint32_t> bytes_per_packet;
        std::span<const std::byte> sample_bytes;
        std::size_t cursor = caf_header_size;
        while (cursor <= bytes.size() &&
               caf_chunk_header_size <= bytes.size() - cursor) {
            const auto chunk_size_u64 = read_big_endian_u64(bytes, cursor + 4U);
            cursor += caf_chunk_header_size;
            if (chunk_size_u64 > bytes.size() - cursor)
                return std::nullopt;
            const auto chunk_size = static_cast<std::size_t>(chunk_size_u64);
            const auto payload = bytes.subspan(cursor, chunk_size);

            if (equal_tag(
                    bytes, cursor - caf_chunk_header_size, description_chunk)) {
                if (payload.size() < caf_description_size ||
                    !equal_tag(payload, 8U, linear_pcm_format) ||
                    read_big_endian_u32(payload, 12U) !=
                        signed_little_endian_pcm_flags ||
                    read_big_endian_u32(payload, 28U) !=
                        supported_bits_per_channel) {
                    return std::nullopt;
                }
                const auto rate = read_big_endian_f64(payload, 0U);
                const auto channels = read_big_endian_u32(payload, 24U);
                const auto packet_bytes = read_big_endian_u32(payload, 16U);
                if (!std::isfinite(rate) || rate < 1.0 ||
                    rate > static_cast<double>(
                               std::numeric_limits<std::uint32_t>::max()) ||
                    channels == 0 ||
                    channels > std::numeric_limits<std::uint16_t>::max() ||
                    packet_bytes != channels * sizeof(std::int16_t)) {
                    return std::nullopt;
                }
                sample_rate = static_cast<std::uint32_t>(std::lround(rate));
                channel_count = channels;
                bytes_per_packet = packet_bytes;
            } else if (equal_tag(
                           bytes, cursor - caf_chunk_header_size, data_chunk)) {
                if (payload.size() < caf_data_edit_count_size)
                    return std::nullopt;
                sample_bytes = payload.subspan(caf_data_edit_count_size);
            }
            cursor += chunk_size;
        }

        if (!sample_rate || !channel_count || !bytes_per_packet ||
            sample_bytes.empty() ||
            sample_bytes.size() % sizeof(std::int16_t) != 0 ||
            sample_bytes.size() % *bytes_per_packet != 0) {
            return std::nullopt;
        }
        std::vector<std::int16_t> samples;
        samples.reserve(sample_bytes.size() / sizeof(std::int16_t));
        for (std::size_t index = 0; index < sample_bytes.size();
            index += sizeof(std::int16_t)) {
            const auto value = static_cast<std::uint16_t>(
                std::to_integer<std::uint16_t>(sample_bytes[index]) |
                (std::to_integer<std::uint16_t>(sample_bytes[index + 1U])
                    << 8U));
            samples.push_back(std::bit_cast<std::int16_t>(value));
        }
        return AudioBuffer { *sample_rate,
            static_cast<std::uint16_t>(*channel_count), std::move(samples) };
    }

} // namespace

AudioService::AudioService(std::filesystem::path rootfs)
    : rootfs_ { std::move(rootfs) }
{
    load_category_aliases();
    load_system_volume_state();
}

void AudioService::set_sink(std::shared_ptr<AudioSink> sink)
{
    std::lock_guard lock { mutex_ };
    sink_ = std::move(sink);
}

void AudioService::set_decoder(std::shared_ptr<AudioDecoder> decoder)
{
    std::lock_guard lock { mutex_ };
    decoder_ = std::move(decoder);
}

AudioPlayResult AudioService::play_audio_file(
    const std::filesystem::path& guest_path, bool replace_current,
    float device_volume)
{
    float gain = 1.0F;
    {
        std::lock_guard lock { mutex_ };
        gain = category_volumes_["Ringtone"] *
               std::clamp(device_volume, 0.0F, 1.0F);
    }
    return play_audio_file_with_gain(guest_path, replace_current, gain);
}

AudioPlayResult AudioService::play_audio_file_with_gain(
    const std::filesystem::path& guest_path, bool replace_current, float gain,
    AudioStopMode replacement_mode)
{
    std::shared_ptr<AudioSink> sink;
    std::optional<AudioBuffer> buffer;
    AudioPlayResult result;
    {
        std::lock_guard lock { mutex_ };
        buffer = load_file_locked(guest_path, result);
        sink = sink_;
    }
    if (!buffer)
        return result;
    result.applied_gain = std::clamp(gain, 0.0F, 1.0F);
    if (!sink) {
        result.status = AudioPlayStatus::NoSink;
        result.detail = "no host audio sink";
        return result;
    }
    if (replace_current)
        sink->stop(replacement_mode);
    sink->set_gain(result.applied_gain);
    if (!sink->play(*buffer)) {
        result.status = AudioPlayStatus::SinkError;
        result.detail = sink->last_error();
        return result;
    }
    result.status = AudioPlayStatus::Queued;
    return result;
}

AudioPlayResult AudioService::queue_pcm(AudioBuffer buffer, float device_volume)
{
    AudioPlayResult result;
    if (buffer.sample_rate == 0 || buffer.channel_count == 0 ||
        buffer.empty()) {
        result.status = AudioPlayStatus::UnsupportedResource;
        result.detail = "invalid PCM buffer";
        return result;
    }
    // Firmware mediaserverd has already applied its category gain to this PCM.
    // The backend contributes only the emulated physical-device scalar.
    const auto gain = std::clamp(device_volume, 0.0F, 1.0F);
    result.applied_gain = gain;
    // A queued SDL device naturally renders silence when it underruns.
    // Enqueuing every silent hardware period only creates latency when guest
    // virtual time advances faster than host playback time, potentially hiding
    // the next audible buffer behind stale silence.
    const auto silent = std::visit(
        [](const auto& samples) {
            return std::ranges::none_of(
                samples, [](const auto sample) { return sample != 0; });
        },
        buffer.samples);
    if (silent) {
        result.status = AudioPlayStatus::Queued;
        return result;
    }
    std::shared_ptr<AudioSink> sink;
    {
        std::lock_guard lock { mutex_ };
        sink = sink_;
    }
    if (!sink) {
        result.status = AudioPlayStatus::NoSink;
        result.detail = "no host audio sink";
        return result;
    }
    sink->set_gain(gain);
    if (!sink->play(buffer)) {
        result.status = AudioPlayStatus::SinkError;
        result.detail = sink->last_error();
        return result;
    }
    result.status = AudioPlayStatus::Queued;
    return result;
}

void AudioService::stop_playback(AudioStopMode mode)
{
    std::shared_ptr<AudioSink> sink;
    {
        std::lock_guard lock { mutex_ };
        sink = sink_;
        playing_service_source_id_.reset();
        playing_service_source_.reset();
    }
    if (sink)
        sink->stop(mode);
}

void AudioService::observe_service_source_create_request(
    std::uint32_t reply_object, std::filesystem::path guest_path)
{
    if (reply_object == 0 || !guest_path.is_absolute())
        return;
    std::lock_guard lock { mutex_ };
    pending_service_source_creates_[reply_object].push_back(
        std::move(guest_path));
}

std::optional<std::filesystem::path>
AudioService::observe_service_source_create_reply(
    std::uint32_t reply_object, std::uint32_t source)
{
    std::optional<std::filesystem::path> path;
    std::shared_ptr<AudioSink> sink;
    AudioStopMode stop_mode = AudioStopMode::Immediate;
    {
        std::lock_guard lock { mutex_ };
        const auto pending = pending_service_source_creates_.find(reply_object);
        if (source == 0 || pending == pending_service_source_creates_.end() ||
            pending->second.empty()) {
            return std::nullopt;
        }
        path = std::move(pending->second.front());
        pending->second.pop_front();
        if (pending->second.empty())
            pending_service_source_creates_.erase(pending);

        const auto previous = service_sources_.find(source);
        const auto changed = previous == service_sources_.end() ||
                             previous->second.path != *path;
        const auto previous_stop_mode = previous == service_sources_.end()
                                            ? service_output_stop_mode_
                                            : previous->second.stop_mode;
        service_sources_.insert_or_assign(
            source, ServiceSource {
                        *path, std::nullopt, 0.0F, service_output_stop_mode_ });
        latest_service_source_id_ = source;
        // Some clients reuse the same server object for successive previews. A
        // create reply begins a new generation: stale rate/volume state from
        // the previous path must not start the replacement before its own
        // rate=1.
        if (changed && playing_service_source_id_ == source) {
            stop_mode = previous_stop_mode;
            playing_service_source_id_.reset();
            playing_service_source_.reset();
            sink = sink_;
        }
    }
    if (sink)
        sink->stop(stop_mode);
    return path;
}

bool AudioService::observe_service_source_property(
    std::optional<std::uint32_t> source, std::string_view property, float value)
{
    if ((source && *source == 0) || !std::isfinite(value))
        return false;
    std::shared_ptr<AudioSink> sink;
    std::optional<std::filesystem::path> path;
    std::optional<float> gain;
    std::optional<std::uint32_t> source_id;
    bool stop = false;
    AudioStopMode stop_mode = AudioStopMode::Immediate;
    AudioStopMode replacement_mode = AudioStopMode::Immediate;
    {
        std::lock_guard lock { mutex_ };
        retire_finished_service_source_locked();
        const auto resolved_source = source ? source : latest_service_source_id_;
        if (!resolved_source)
            return false;
        const auto current = service_sources_.find(*resolved_source);
        if (current == service_sources_.end())
            return false;
        source_id = *resolved_source;
        auto& state = current->second;
        if (property == "uservolume") {
            state.user_volume = std::clamp(value, 0.0F, 1.0F);
            if (playing_service_source_id_ == *source_id) {
                sink = sink_;
                gain = *state.user_volume;
            }
        } else if (property == "rate") {
            state.rate = value;
            if (value <= 0.0F) {
                if (playing_service_source_id_ == *source_id) {
                    stop_mode = state.stop_mode;
                    playing_service_source_id_.reset();
                    playing_service_source_.reset();
                    sink = sink_;
                    stop = true;
                }
            } else if (!state.path.empty() &&
                       playing_service_source_id_ != *source_id) {
                if (playing_service_source_id_) {
                    const auto active =
                        service_sources_.find(*playing_service_source_id_);
                    if (active != service_sources_.end())
                        replacement_mode = active->second.stop_mode;
                } else {
                    replacement_mode = state.stop_mode;
                }
                playing_service_source_id_ = *source_id;
                playing_service_source_ = state.path;
                path = state.path;
                gain =
                    state.user_volume.value_or(category_volumes_["Ringtone"]);
            }
        } else {
            return false;
        }
    }
    if (stop) {
        if (sink)
            sink->stop(stop_mode);
        return true;
    }
    if (path) {
        const auto result =
            play_audio_file_with_gain(*path, true, *gain, replacement_mode);
        if (result.status != AudioPlayStatus::Queued) {
            std::lock_guard lock { mutex_ };
            if (playing_service_source_id_ == source_id) {
                playing_service_source_id_.reset();
                playing_service_source_.reset();
            }
        }
    } else if (sink && gain) {
        sink->set_gain(*gain);
    }
    return true;
}

void AudioService::observe_service_output_stop_mode(AudioStopMode mode)
{
    std::lock_guard lock { mutex_ };
    retire_finished_service_source_locked();
    service_output_stop_mode_ = mode;
    if (latest_service_source_id_) {
        const auto latest = service_sources_.find(*latest_service_source_id_);
        if (latest != service_sources_.end())
            latest->second.stop_mode = mode;
    }
    if (playing_service_source_id_ &&
        playing_service_source_id_ != latest_service_source_id_) {
        const auto active = service_sources_.find(*playing_service_source_id_);
        if (active != service_sources_.end())
            active->second.stop_mode = mode;
    }
}

bool AudioService::service_source_playing()
{
    std::lock_guard lock { mutex_ };
    retire_finished_service_source_locked();
    return playing_service_source_id_.has_value();
}

void AudioService::observe_category_volume(std::string category, float value)
{
    if (category.empty() || !std::isfinite(value))
        return;
    std::shared_ptr<AudioSink> sink;
    std::optional<float> gain;
    {
        std::lock_guard lock { mutex_ };
        const auto canonical = canonical_category_locked(category);
        category_volumes_[canonical] = std::clamp(value, 0.0F, 1.0F);
        if (canonical == "Ringtone" && playing_service_source_id_) {
            const auto active =
                service_sources_.find(*playing_service_source_id_);
            if (active != service_sources_.end() &&
                !active->second.user_volume) {
                sink = sink_;
                gain = category_volumes_[canonical];
            }
        }
    }
    if (sink && gain)
        sink->set_gain(*gain);
}

float AudioService::category_volume(std::string_view category) const
{
    std::lock_guard lock { mutex_ };
    const auto found =
        category_volumes_.find(canonical_category_locked(category));
    return found == category_volumes_.end() ? 1.0F : found->second;
}

void AudioService::initialize_player(
    AudioClientObject player, AudioClientObject queue)
{
    std::lock_guard lock { mutex_ };
    players_[player] = PlayerState { queue, 0.0F, 0 };
}

void AudioService::set_player_queue(
    AudioClientObject player, AudioClientObject queue)
{
    std::lock_guard lock { mutex_ };
    players_[player].queue = queue;
}

AudioClientObject AudioService::player_queue(AudioClientObject player) const
{
    std::lock_guard lock { mutex_ };
    const auto current = players_.find(player);
    return current == players_.end() ? AudioClientObject { }
                                     : current->second.queue;
}

AudioPlayResult AudioService::set_player_rate(
    AudioClientObject player, float rate)
{
    if (!std::isfinite(rate) || rate <= 0.0F) {
        stop_player(player);
        AudioPlayResult result;
        result.status = AudioPlayStatus::Queued;
        return result;
    }

    std::optional<std::filesystem::path> path;
    {
        std::lock_guard lock { mutex_ };
        const auto current = players_.find(player);
        if (current != players_.end()) {
            const auto queue = queues_.find(current->second.queue);
            if (queue != queues_.end() && !queue->second.empty()) {
                const auto item = items_.find(queue->second.back());
                if (item != items_.end())
                    path = item->second;
            }
        }
    }

    AudioPlayResult result;
    if (path) {
        result = play_audio_file(*path, true);
    } else {
        result.status = AudioPlayStatus::ResourceUnavailable;
        result.detail = "audio service player has no playable item";
    }
    {
        std::lock_guard lock { mutex_ };
        players_[player].rate =
            result.status == AudioPlayStatus::Queued ? rate : 0.0F;
    }
    return result;
}

float AudioService::player_rate(AudioClientObject player) const
{
    std::lock_guard lock { mutex_ };
    const auto current = players_.find(player);
    return current == players_.end() ? 0.0F : current->second.rate;
}

void AudioService::stop_player(AudioClientObject player)
{
    {
        std::lock_guard lock { mutex_ };
        players_[player].rate = 0.0F;
    }
    stop_playback();
}

void AudioService::set_player_repeat_mode(
    AudioClientObject player, std::uint32_t mode)
{
    std::lock_guard lock { mutex_ };
    players_[player].repeat_mode = mode;
}

std::uint32_t AudioService::player_repeat_mode(AudioClientObject player) const
{
    std::lock_guard lock { mutex_ };
    const auto current = players_.find(player);
    return current == players_.end() ? 0U : current->second.repeat_mode;
}

void AudioService::initialize_queue(AudioClientObject queue)
{
    std::lock_guard lock { mutex_ };
    queues_.try_emplace(queue);
}

void AudioService::clear_queue(AudioClientObject queue)
{
    std::lock_guard lock { mutex_ };
    queues_[queue].clear();
}

bool AudioService::append_queue_item(
    AudioClientObject queue, AudioClientObject item)
{
    std::lock_guard lock { mutex_ };
    if (!items_.contains(item))
        return false;
    queues_[queue].push_back(item);
    return true;
}

void AudioService::set_item_path(
    AudioClientObject item, std::filesystem::path path)
{
    std::lock_guard lock { mutex_ };
    items_[item] = std::move(path);
}

std::optional<std::filesystem::path> AudioService::item_path(
    AudioClientObject item) const
{
    std::lock_guard lock { mutex_ };
    const auto path = items_.find(item);
    return path == items_.end() ? std::nullopt : std::optional { path->second };
}

std::optional<AudioBuffer> AudioService::load_file_locked(
    const std::filesystem::path& guest_path, AudioPlayResult& result)
{
    if (!guest_path.is_absolute()) {
        result.status = AudioPlayStatus::ResourceUnavailable;
        result.detail = "audio path is not guest-absolute";
        return std::nullopt;
    }
    const auto relative = guest_path.relative_path().lexically_normal();
    for (const auto& component : relative) {
        if (component == "..") {
            result.status = AudioPlayStatus::ResourceUnavailable;
            result.detail = "audio path escapes the guest root";
            return std::nullopt;
        }
    }
    result.guest_path = std::filesystem::path { "/" } / relative;
    if (const auto cached = decoded_files_.find(result.guest_path);
        cached != decoded_files_.end()) {
        return cached->second;
    }
    const auto host_path = rootfs_ / relative;
    if (!std::filesystem::is_regular_file(host_path)) {
        result.status = AudioPlayStatus::ResourceUnavailable;
        result.detail = "audio resource is unavailable";
        return std::nullopt;
    }

    if (const auto bytes = read_file(host_path)) {
        if (auto decoded = decode_linear_pcm_caf(*bytes)) {
            auto [entry, inserted] =
                decoded_files_.emplace(result.guest_path, std::move(*decoded));
            static_cast<void>(inserted);
            return entry->second;
        }
    }
    if (!decoder_) {
        result.status = AudioPlayStatus::UnsupportedResource;
        result.detail = "no decoder accepts this audio resource";
        return std::nullopt;
    }
    auto decoded = decoder_->decode(host_path);
    if (!decoded) {
        result.status = AudioPlayStatus::UnsupportedResource;
        result.detail = decoder_->last_error();
        return std::nullopt;
    }
    auto [entry, inserted] =
        decoded_files_.emplace(result.guest_path, std::move(*decoded));
    static_cast<void>(inserted);
    return entry->second;
}

void AudioService::load_category_aliases()
{
#if defined(SHADE_HAS_LIBPLIST)
    const auto path = rootfs_ / "System/Library/Frameworks/Celestial.framework/"
                                "CategoriesThatShareVolumes.plist";
    const auto bytes = read_file(path);
    if (!bytes || bytes->empty() ||
        bytes->size() > std::numeric_limits<std::uint32_t>::max()) {
        return;
    }

    plist_t root = nullptr;
    plist_format_t format = PLIST_FORMAT_NONE;
    const auto parsed =
        plist_from_memory(reinterpret_cast<const char*>(bytes->data()),
            static_cast<std::uint32_t>(bytes->size()), &root, &format);
    if (parsed != PLIST_ERR_SUCCESS || root == nullptr)
        return;

    plist_dict_iter iterator = nullptr;
    plist_dict_new_iter(root, &iterator);
    while (iterator != nullptr) {
        char* alias = nullptr;
        plist_t target_node = nullptr;
        plist_dict_next_item(root, iterator, &alias, &target_node);
        if (target_node == nullptr) {
            std::free(alias);
            break;
        }
        std::uint64_t target_length { };
        const auto* target = plist_get_string_ptr(target_node, &target_length);
        if (alias != nullptr && target != nullptr && target_length != 0) {
            category_aliases_.insert_or_assign(
                alias, std::string {
                           target, static_cast<std::size_t>(target_length) });
        }
        std::free(alias);
    }
    std::free(iterator);
    plist_free(root);
#endif
}

std::string AudioService::canonical_category_locked(
    std::string_view category) const
{
    std::string result { category };
    for (std::size_t depth = 0; depth <= category_aliases_.size(); ++depth) {
        const auto alias = category_aliases_.find(result);
        if (alias == category_aliases_.end() || alias->second == result)
            break;
        result = alias->second;
    }
    return result;
}

void AudioService::retire_finished_service_source_locked()
{
    if (!playing_service_source_id_ || (sink_ && sink_->has_pending_audio())) {
        return;
    }

    // A host-decoded fallback is finite even if the retired Fig client leaves
    // its rate positive. Once the sink consumes the final sample, retire only
    // the fallback ownership. The firmware IOProc can then resume supplying
    // PCM, and a later positive rate for the same service object can queue it
    // again.
    playing_service_source_id_.reset();
    playing_service_source_.reset();
}

void AudioService::load_system_volume_state()
{
#if defined(SHADE_HAS_LIBPLIST)
    const auto path =
        rootfs_ / "var/root/Library/Preferences/com.apple.celestial.plist";
    const auto bytes = read_file(path);
    if (!bytes || bytes->empty() ||
        bytes->size() > std::numeric_limits<std::uint32_t>::max()) {
        return;
    }

    plist_t root = nullptr;
    plist_format_t format = PLIST_FORMAT_NONE;
    const auto parsed =
        plist_from_memory(reinterpret_cast<const char*>(bytes->data()),
            static_cast<std::uint32_t>(bytes->size()), &root, &format);
    if (parsed != PLIST_ERR_SUCCESS || root == nullptr)
        return;

    const auto volumes = plist_dict_get_item(root, "volumes");
    const auto broadcast = volumes == nullptr
                               ? nullptr
                               : plist_dict_get_item(volumes, "broadcast");
    const auto ringtone = broadcast == nullptr
                              ? nullptr
                              : plist_dict_get_item(broadcast, "Ringtone");
    if (ringtone != nullptr) {
        double value { };
        plist_get_real_val(ringtone, &value);
        if (std::isfinite(value)) {
            category_volumes_["Ringtone"] =
                std::clamp(static_cast<float>(value), 0.0F, 1.0F);
        }
    }
    plist_free(root);
#endif
}

} // namespace shade
