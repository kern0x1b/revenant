// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage virtual baseband open descriptions, logical channels and
// transport state.

#include "kernel/baseband_device.hpp"

#include "kernel/darwin_tty_abi.hpp"

#include <algorithm>
#include <array>
#include <charconv>
#include <cstdint>
#include <iterator>
#include <mutex>
#include <optional>
#include <utility>
#include <vector>

namespace shade::bsd::baseband_device {

namespace {

    std::optional<std::uint32_t> numeric_suffix(std::string_view candidate)
    {
        constexpr std::array<std::string_view, 2> prefixes {
            "/dev/dlci.spi-baseband.", "/dev/dlci.h5.baseband."
        };
        for (const auto prefix : prefixes) {
            if (!candidate.starts_with(prefix)) {
                continue;
            }
            const auto suffix = candidate.substr(prefix.size());
            if (suffix.empty()) {
                return std::nullopt;
            }
            std::uint32_t value { };
            const auto result = std::from_chars(
                suffix.data(), suffix.data() + suffix.size(), value, 10);
            if (result.ec != std::errc { } ||
                result.ptr != suffix.data() + suffix.size() || value == 0) {
                return std::nullopt;
            }
            return value;
        }
        return std::nullopt;
    }

    std::uint32_t channel_for_path(std::string_view candidate)
    {
        return numeric_suffix(candidate).value_or(0U);
    }

} // namespace

std::shared_ptr<OpenDescription> State::open_description(
    std::string_view candidate, std::uint32_t process_id)
{
    const auto channel = channel_for_path(candidate);
    const auto is_channel = is_mux_channel_path(candidate);
    const std::lock_guard lock { mutex_ };
    if (!available_ || exclusive_owner_.has_value() ||
        (is_channel && (!dynamic_channels_available_ ||
                           (anonymous_mux_channel_capacity_ != 0 &&
                               channel > anonymous_mux_channel_capacity_)))) {
        return { };
    }
    channels_.try_emplace(channel);
    const auto token = next_open_token_++;
    return std::shared_ptr<OpenDescription>(
        new OpenDescription { lifetime_, channel, token, process_id });
}

OpenDescription::~OpenDescription()
{
    if (lifetime_ && lifetime_->state)
        lifetime_->state->release_description(*this);
}

std::vector<std::byte> OpenDescription::receive(std::size_t maximum) const
{
    return lifetime_ && lifetime_->state
               ? lifetime_->state->receive_channel(channel_, maximum)
               : std::vector<std::byte> { };
}

std::size_t OpenDescription::pending_receive_bytes() const
{
    return lifetime_ && lifetime_->state
               ? lifetime_->state->pending_receive_channel(channel_)
               : 0U;
}

bool OpenDescription::receive_eof() const
{
    return lifetime_ && lifetime_->state
               ? lifetime_->state->receive_eof_channel(channel_)
               : true;
}

std::size_t OpenDescription::write(std::span<const std::byte> bytes) const
{
    return lifetime_ && lifetime_->state
               ? lifetime_->state->write_channel(channel_, bytes)
               : 0U;
}

bool OpenDescription::writable() const
{
    return lifetime_ && lifetime_->state
               ? lifetime_->state->writable_channel(channel_)
               : false;
}

bool OpenDescription::transmit_sink_failed() const
{
    return lifetime_ && lifetime_->state
               ? lifetime_->state->sink_failed_channel(channel_)
               : true;
}

IoctlResult OpenDescription::ioctl(std::uint32_t command) const
{
    return lifetime_ && lifetime_->state
               ? lifetime_->state->ioctl_for_owner(command, token_, process_id_)
               : IoctlResult::unsupported;
}

void OpenDescription::flush_buffers(std::uint32_t what) const
{
    if (lifetime_ && lifetime_->state)
        lifetime_->state->flush_channel(channel_, what);
}

bool State::available() const
{
    const std::lock_guard lock { mutex_ };
    return available_;
}

void State::set_available(bool available)
{
    const std::lock_guard lock { mutex_ };
    available_ = available;
}

bool State::transmit_queue_writable() const
{
    const std::lock_guard lock { mutex_ };
    return transmit_queue_writable_ && !transmit_sink_failed_;
}

void State::set_transmit_queue_writable(bool writable)
{
    const std::lock_guard lock { mutex_ };
    transmit_queue_writable_ = writable;
}

bool State::dynamic_channels_available() const
{
    const std::lock_guard lock { mutex_ };
    return dynamic_channels_available_;
}

void State::set_dynamic_channels_available(bool available)
{
    const std::lock_guard lock { mutex_ };
    dynamic_channels_available_ = available;
}

bool State::mux_channel_path_available(std::string_view candidate) const
{
    const auto unit = numeric_suffix(candidate);
    if (!unit) {
        return false;
    }
    const std::lock_guard lock { mutex_ };
    if (!dynamic_channels_available_) {
        return false;
    }
    return anonymous_mux_channel_capacity_ == 0 ||
           *unit <= anonymous_mux_channel_capacity_;
}

bool State::may_open(bool privileged) const
{
    static_cast<void>(privileged);
    const std::lock_guard lock { mutex_ };
    return available_ && !exclusive_owner_.has_value();
}

IoctlResult State::ioctl(std::uint32_t command)
{
    return ioctl_for_owner(command, 0U, 0U);
}

IoctlResult State::ioctl_for_owner(
    std::uint32_t command, std::uint64_t token, std::uint32_t process_id)
{
    const std::lock_guard lock { mutex_ };
    switch (command) {
    case darwin::tty::set_exclusive:
        if (exclusive_owner_ &&
            (exclusive_owner_->token != token ||
                exclusive_owner_->process_id != process_id)) {
            return IoctlResult::permission_denied;
        }
        exclusive_ = true;
        exclusive_owner_ = OpenOwner { token, process_id };
        return IoctlResult::success;
    case darwin::tty::clear_exclusive:
        if (token != 0U &&
            (!exclusive_owner_ || exclusive_owner_->token != token ||
                exclusive_owner_->process_id != process_id)) {
            return IoctlResult::permission_denied;
        }
        exclusive_ = false;
        exclusive_owner_.reset();
        return IoctlResult::success;
    default:
        return IoctlResult::unsupported;
    }
}

bool State::exclusive() const
{
    const std::lock_guard lock { mutex_ };
    return exclusive_;
}

darwin::tty::Arm32Attributes State::attributes() const
{
    const std::lock_guard lock { mutex_ };
    return attributes_;
}

void State::set_attributes(const darwin::tty::Arm32Attributes& attributes)
{
    const std::lock_guard lock { mutex_ };
    attributes_ = attributes;
    channels_[0U].minimum_receive_bytes = std::min<std::size_t>(
        attributes.control_characters[darwin::tty::minimum_bytes_index],
        maximum_receive_threshold);
}

bool State::receive_eof() const
{
    const std::lock_guard lock { mutex_ };
    return receive_eof_;
}

void State::set_receive_eof(bool eof)
{
    const std::lock_guard lock { mutex_ };
    receive_eof_ = eof;
}

bool State::h5_transport_mode() const
{
    const std::lock_guard lock { mutex_ };
    return h5_transport_mode_;
}

void State::set_h5_transport_mode(bool enabled)
{
    const std::lock_guard lock { mutex_ };
    h5_transport_mode_ = enabled;
}

std::size_t State::minimum_receive_bytes() const
{
    const std::lock_guard lock { mutex_ };
    const auto channel = channels_.find(0U);
    return channel == channels_.end() ? 0U
                                      : channel->second.minimum_receive_bytes;
}

void State::set_minimum_receive_bytes(std::size_t bytes)
{
    const std::lock_guard lock { mutex_ };
    const auto bounded = std::min(bytes, maximum_receive_threshold);
    channels_[0U].minimum_receive_bytes = bounded;
    attributes_.control_characters[darwin::tty::minimum_bytes_index] =
        static_cast<std::uint8_t>(std::min<std::size_t>(bounded, 0xffU));
}

std::uint32_t State::modem_control_bits() const
{
    const std::lock_guard lock { mutex_ };
    return modem_control_bits_;
}

void State::set_modem_control_bits(std::uint32_t bits)
{
    const std::lock_guard lock { mutex_ };
    modem_control_bits_ = bits;
}

void State::update_modem_control_bits(std::uint32_t bits, bool enabled)
{
    const std::lock_guard lock { mutex_ };
    if (enabled) {
        modem_control_bits_ |= bits;
    } else {
        modem_control_bits_ &= ~bits;
    }
}

bool State::configure_receive_queue(std::span<const std::byte> configuration)
{
    if (configuration.size() != receive_queue_configuration_.size()) {
        return false;
    }
    const std::lock_guard lock { mutex_ };
    std::copy(configuration.begin(), configuration.end(),
        receive_queue_configuration_.begin());
    receive_queue_configured_ = true;
    return true;
}

bool State::receive_queue_configured() const
{
    const std::lock_guard lock { mutex_ };
    return receive_queue_configured_;
}

void State::flush_buffers(std::uint32_t what) { flush_channel(0U, what); }

void State::set_mux_channel_capacity(std::uint32_t capacity)
{
    const std::lock_guard lock { mutex_ };
    anonymous_mux_channel_capacity_ = capacity;
    next_anonymous_mux_channel_ = 1;
}

void State::set_offline_control_enabled(bool enabled)
{
    const std::lock_guard lock { mutex_ };
    offline_control_enabled_ = enabled;
    offline_control_.reset();
    offline_response_deadline_ = { };
}

std::uint32_t State::register_mux_channel(
    std::string_view name, std::optional<std::uint32_t> requested_unit)
{
    const std::lock_guard lock { mutex_ };
    if (!name.empty()) {
        const auto key = std::string { name };
        if (const auto found = mux_channels_.find(key);
            found != mux_channels_.end()) {
            return found->second;
        }
        if (anonymous_mux_channel_capacity_ != 0 &&
            mux_channels_.size() >= anonymous_mux_channel_capacity_) {
            // Keep the finite logical-channel table bounded; otherwise an
            // offline CommCenter retry loop could grow this map indefinitely.
            return 0;
        }
        if (requested_unit && *requested_unit != 0U) {
            if (anonymous_mux_channel_capacity_ != 0 &&
                *requested_unit > anonymous_mux_channel_capacity_) {
                return 0;
            }
            const auto occupied = std::any_of(mux_channels_.begin(),
                mux_channels_.end(), [requested_unit](const auto& entry) {
                    return entry.second == *requested_unit;
                });
            if (occupied)
                return 0;
            mux_channels_.emplace(key, *requested_unit);
            if (anonymous_mux_channel_capacity_ != 0) {
                next_mux_channel_ = *requested_unit ==
                        anonymous_mux_channel_capacity_
                    ? 1U
                    : *requested_unit + 1U;
            }
            return *requested_unit;
        }
        if (anonymous_mux_channel_capacity_ != 0) {
            auto unit = next_mux_channel_;
            if (unit == 0 || unit > anonymous_mux_channel_capacity_)
                unit = 1;
            const auto first = unit;
            do {
                const auto occupied = std::any_of(
                    mux_channels_.begin(), mux_channels_.end(),
                    [unit](const auto& entry) { return entry.second == unit; });
                if (!occupied) {
                    next_mux_channel_ =
                        unit == anonymous_mux_channel_capacity_ ? 1U : unit + 1U;
                    mux_channels_.emplace(key, unit);
                    return unit;
                }
                unit = unit == anonymous_mux_channel_capacity_ ? 1U : unit + 1U;
            } while (unit != first);
            return 0;
        }
        const auto unit = next_mux_channel_++;
        mux_channels_.emplace(key, unit);
        return unit;
    }
    if (requested_unit && *requested_unit != 0U) {
        if (anonymous_mux_channel_capacity_ != 0 &&
            *requested_unit > anonymous_mux_channel_capacity_) {
            return 0;
        }
        return *requested_unit;
    }
    if (anonymous_mux_channel_capacity_ != 0) {
        const auto unit = next_anonymous_mux_channel_;
        next_anonymous_mux_channel_ =
            unit == anonymous_mux_channel_capacity_ ? 1U : unit + 1U;
        return unit;
    }
    return next_mux_channel_++;
}

std::optional<std::uint32_t> State::mux_channel(std::string_view name) const
{
    const std::lock_guard lock { mutex_ };
    if (name.empty()) {
        return std::nullopt;
    }
    const auto found = mux_channels_.find(std::string { name });
    if (found == mux_channels_.end()) {
        return std::nullopt;
    }
    return found->second;
}

std::string State::mux_channel_device_path(std::uint32_t unit) const
{
    const std::lock_guard lock { mutex_ };
    const auto prefix = h5_transport_mode_ ? "/dev/dlci.h5.baseband."
                                           : "/dev/dlci.spi-baseband.";
    return prefix + std::to_string(unit);
}

bool State::configure_mux_network_interface(
    std::uint32_t unit, std::string_view name)
{
    if (unit == 0U || name.empty() ||
        name.size() >= darwin::tty::asm_network_interface_name_capacity ||
        !std::all_of(name.begin(), name.end(), [](unsigned char character) {
            return character >= 0x20U && character <= 0x7eU;
        })) {
        return false;
    }
    const std::lock_guard lock { mutex_ };
    const auto registered =
        std::any_of(mux_channels_.begin(), mux_channels_.end(),
            [unit](const auto& entry) { return entry.second == unit; });
    if (!registered)
        return false;
    mux_network_interfaces_[unit] = std::string { name };
    return true;
}

void State::enqueue_receive(std::span<const std::byte> bytes)
{
    enqueue_receive(0U, bytes);
}

void State::enqueue_receive(
    std::uint32_t channel_number, std::span<const std::byte> bytes)
{
    const std::lock_guard lock { mutex_ };
    auto& channel = channels_[channel_number];
    channel.receive_queue.insert(
        channel.receive_queue.end(), bytes.begin(), bytes.end());
}

std::vector<std::byte> State::receive(std::size_t maximum)
{
    return receive_channel(0U, maximum);
}

std::vector<std::byte> State::receive_channel(
    std::uint32_t channel_number, std::size_t maximum)
{
    const std::lock_guard lock { mutex_ };
    const auto channel = channels_.find(channel_number);
    if (channel == channels_.end())
        return { };
    promote_ready_receive(channel->second);
    const auto& state = channel->second;
    if (state.minimum_receive_bytes != 0 &&
        state.receive_queue.size() < state.minimum_receive_bytes &&
        !receive_eof_) {
        return { };
    }
    const auto count = std::min(maximum, state.receive_queue.size());
    std::vector<std::byte> bytes;
    bytes.reserve(count);
    for (std::size_t index = 0; index < count; ++index) {
        bytes.push_back(channel->second.receive_queue.front());
        channel->second.receive_queue.pop_front();
    }
    return bytes;
}

std::size_t State::pending_receive_bytes() const
{
    return pending_receive_channel(0U);
}

std::size_t State::pending_receive_channel(std::uint32_t channel_number) const
{
    const std::lock_guard lock { mutex_ };
    const auto channel = channels_.find(channel_number);
    if (channel == channels_.end())
        return 0U;
    const auto now = std::chrono::steady_clock::now();
    auto available = channel->second.receive_queue.size();
    for (const auto& scheduled : channel->second.scheduled_receive_queue) {
        if (scheduled.ready_at > now)
            break;
        available += scheduled.bytes.size();
    }
    if (channel->second.minimum_receive_bytes != 0 &&
        available < channel->second.minimum_receive_bytes && !receive_eof_) {
        return 0U;
    }
    return available;
}

bool State::receive_eof_channel(std::uint32_t channel_number) const
{
    const std::lock_guard lock { mutex_ };
    return receive_eof_ && channels_.contains(channel_number);
}

std::size_t State::write(std::span<const std::byte> bytes)
{
    return write_channel(0U, bytes);
}

std::size_t State::write_channel(
    std::uint32_t channel_number, std::span<const std::byte> bytes)
{
    const std::lock_guard lock { mutex_ };
    if (!transmit_queue_writable_ || transmit_sink_failed_)
        return 0U;
    if (offline_control_enabled_ && !transmit_sink_ &&
        !transmit_capture_enabled_) {
        const auto response = offline_control_.consume(channel_number, bytes);
        if (!response.empty()) {
            const auto now = std::chrono::steady_clock::now();
            const auto response_base =
                std::max(now, offline_response_deadline_);
            offline_response_deadline_ =
                response_base + offline_control_response_interval;
            channels_[channel_number].scheduled_receive_queue.push_back(
                ScheduledReceive { offline_response_deadline_, response });
        }
        return bytes.size();
    }
    // Logical DLCI endpoints are real bounded endpoints, but Offline has no
    // modem peer. Their successful writes terminate at this null sink and do
    // not share the fixed TTY's capture history.
    if (channel_number != 0U)
        return bytes.size();
    if (transmit_sink_) {
        if (!transmit_sink_(bytes)) {
            transmit_sink_failed_ = true;
            return 0;
        }
        return bytes.size();
    }
    if (!transmit_capture_enabled_)
        return bytes.size();
    // Retain only the newest diagnostic bytes. Device write semantics remain
    // synchronous and successful, while the in-memory inspection path cannot
    // grow with an offline CommCenter retry loop.
    if (bytes.size() >= transmit_capture_capacity) {
        transmitted_.assign(bytes.end() - static_cast<std::ptrdiff_t>(
                                              transmit_capture_capacity),
            bytes.end());
        return bytes.size();
    }
    const auto retained_room = transmit_capture_capacity - bytes.size();
    if (transmitted_.size() > retained_room) {
        transmitted_.erase(transmitted_.begin(),
            transmitted_.begin() + static_cast<std::ptrdiff_t>(
                                       transmitted_.size() - retained_room));
    }
    transmitted_.insert(transmitted_.end(), bytes.begin(), bytes.end());
    return bytes.size();
}

bool State::writable_channel(std::uint32_t channel_number) const
{
    static_cast<void>(channel_number);
    const std::lock_guard lock { mutex_ };
    return transmit_queue_writable_ && !transmit_sink_failed_;
}

bool State::sink_failed_channel(std::uint32_t channel_number) const
{
    const std::lock_guard lock { mutex_ };
    return channel_number == 0U && transmit_sink_failed_;
}

void State::flush_channel(std::uint32_t channel_number, std::uint32_t what)
{
    const std::lock_guard lock { mutex_ };
    // Darwin's TIOCFLUSH treats zero as both FREAD and FWRITE. The offline
    // endpoint has no asynchronous transmit queue; only its receive side can
    // contain bytes that need to be discarded here.
    if (what == 0 || (what & 0x1U) != 0) {
        channels_[channel_number].receive_queue.clear();
        channels_[channel_number].scheduled_receive_queue.clear();
        const auto any_scheduled = std::any_of(
            channels_.begin(), channels_.end(), [](const auto& entry) {
                return !entry.second.scheduled_receive_queue.empty();
            });
        if (!any_scheduled)
            offline_response_deadline_ = { };
    }
    if (what == 0 || (what & 0x2U) != 0)
        offline_control_.reset(channel_number);
}

void State::promote_ready_receive(ChannelState& channel)
{
    const auto now = std::chrono::steady_clock::now();
    while (!channel.scheduled_receive_queue.empty() &&
           channel.scheduled_receive_queue.front().ready_at <= now) {
        auto response =
            std::move(channel.scheduled_receive_queue.front().bytes);
        channel.scheduled_receive_queue.pop_front();
        channel.receive_queue.insert(channel.receive_queue.end(),
            std::make_move_iterator(response.begin()),
            std::make_move_iterator(response.end()));
    }
}

void State::release_description(const OpenDescription& description)
{
    const std::lock_guard lock { mutex_ };
    if (exclusive_owner_ && exclusive_owner_->token == description.token_ &&
        exclusive_owner_->process_id == description.process_id_) {
        exclusive_owner_.reset();
        exclusive_ = false;
    }
}

std::vector<std::byte> State::take_transmitted()
{
    const std::lock_guard lock { mutex_ };
    auto bytes = std::move(transmitted_);
    transmitted_.clear();
    return bytes;
}

void State::set_transmit_capture_enabled(bool enabled)
{
    const std::lock_guard lock { mutex_ };
    transmit_capture_enabled_ = enabled;
    transmit_sink_ = { };
    transmit_sink_failed_ = false;
    if (!enabled)
        transmitted_.clear();
}

void State::set_transmit_sink(TransmitSink sink)
{
    const std::lock_guard lock { mutex_ };
    transmit_sink_ = std::move(sink);
    transmit_capture_enabled_ = false;
    transmit_sink_failed_ = false;
    transmitted_.clear();
}

bool State::transmit_sink_failed() const
{
    const std::lock_guard lock { mutex_ };
    return transmit_sink_failed_;
}

bool is_mux_channel_path(std::string_view candidate)
{
    return numeric_suffix(candidate).has_value();
}

bool is_mux_path(std::string_view candidate)
{
    return candidate == spi_mux_path || candidate == h5_mux_path ||
           is_mux_channel_path(candidate);
}

bool is_path(std::string_view candidate)
{
    return candidate == path || candidate == legacy_path ||
           is_mux_path(candidate);
}

} // namespace shade::bsd::baseband_device
