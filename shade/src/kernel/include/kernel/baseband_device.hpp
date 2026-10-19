// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Model virtual baseband device opens, channels, ioctl state and
// transport lifetimes.

#pragma once

#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "kernel/darwin_tty_abi.hpp"
#include "kernel/offline_baseband_control.hpp"

namespace shade::bsd::baseband_device {

inline constexpr std::string_view path { "/dev/h5.baseband" };
// Darwin 9/early iPhoneOS CommCenter probes the legacy serial node before
// selecting the H5 transport. It is the same emulated baseband endpoint, not
// a second transport or a firmware-specific success result.
inline constexpr std::string_view legacy_path { "/dev/cu.baseband" };
inline constexpr std::string_view spi_mux_path { "/dev/mux.spi-baseband" };
inline constexpr std::string_view h5_mux_path { "/dev/mux.h5.baseband" };
inline constexpr std::string_view directory_name { "h5.baseband" };
inline constexpr std::string_view spi_mux_directory_name { "mux.spi-baseband" };
inline constexpr std::string_view h5_mux_directory_name { "mux.h5.baseband" };
inline constexpr std::string_view descriptor_kind { "baseband" };
inline constexpr unsigned device_minor = 3;
// Offline devices with a fixed endpoint retain the finite logical channel
// table expected by stock CommCenter. These channels are not backed by a
// modem and never synthesize receive data.
inline constexpr std::uint32_t offline_mux_channel_capacity = 16;
// Keep the firmware's modem setup asynchronous even when no physical or
// replay peer is attached. A real multiplexed serial modem cannot complete an
// arbitrary number of commands in the same scheduler turn.
inline constexpr auto offline_control_response_interval =
    std::chrono::milliseconds { 25 };
// In-memory capture is a test/embedding diagnostic, not the production
// transport. Keep it bounded even when a caller explicitly enables it; the
// application uses the streaming sink for unbounded captures.
inline constexpr std::size_t transmit_capture_capacity = 1U * 1024U * 1024U;
inline constexpr std::size_t maximum_receive_threshold = 64U * 1024U;

class State;

enum class IoctlResult {
    success,
    permission_denied,
    unsupported,
};

struct OpenDescriptionLifetime {
    State* state { };
};

struct OpenDescription {
    OpenDescription(const OpenDescription&) = delete;
    OpenDescription& operator=(const OpenDescription&) = delete;

    ~OpenDescription();

    [[nodiscard]] std::vector<std::byte> receive(std::size_t maximum) const;
    [[nodiscard]] std::size_t pending_receive_bytes() const;
    [[nodiscard]] bool receive_eof() const;
    [[nodiscard]] std::size_t write(std::span<const std::byte> bytes) const;
    [[nodiscard]] bool writable() const;
    [[nodiscard]] bool transmit_sink_failed() const;
    [[nodiscard]] IoctlResult ioctl(std::uint32_t command) const;
    void flush_buffers(std::uint32_t what) const;

private:
    friend class State;

    OpenDescription(std::shared_ptr<OpenDescriptionLifetime> lifetime,
        std::uint32_t channel, std::uint64_t token, std::uint32_t process_id)
        : lifetime_ { std::move(lifetime) }
        , channel_ { channel }
        , token_ { token }
        , process_id_ { process_id }
    {
    }

    std::shared_ptr<OpenDescriptionLifetime> lifetime_;
    std::uint32_t channel_ { };
    std::uint64_t token_ { };
    std::uint32_t process_id_ { };
};

class State {
public:
    using TransmitSink = std::function<bool(std::span<const std::byte>)>;

    State();
    ~State();

    [[nodiscard]] std::shared_ptr<OpenDescription> open_description(
        std::string_view candidate, std::uint32_t process_id);

    [[nodiscard]] bool available() const;
    void set_available(bool available);
    // This is the guest-to-device tty transmit queue, not modem availability.
    [[nodiscard]] bool transmit_queue_writable() const;
    void set_transmit_queue_writable(bool writable);
    // Whether the profile supports guest-visible DLCI setup nodes. Offline
    // devices may expose bounded logical channels without a modem peer.
    [[nodiscard]] bool dynamic_channels_available() const;
    void set_dynamic_channels_available(bool available);
    // Direct /dev/dlci.*.<unit> opens use the same bounded logical channel
    // table as ASMIOCNEWDLCI.  Keep the path validation in the device state so
    // filesystem, stat, and access do not grow separate capacity rules.
    [[nodiscard]] bool mux_channel_path_available(
        std::string_view candidate) const;
    [[nodiscard]] bool may_open(bool privileged) const;
    [[nodiscard]] IoctlResult ioctl(std::uint32_t command);
    [[nodiscard]] bool receive_eof() const;
    void set_receive_eof(bool eof);
    [[nodiscard]] bool exclusive() const;
    [[nodiscard]] darwin::tty::Arm32Attributes attributes() const;
    void set_attributes(const darwin::tty::Arm32Attributes& attributes);
    [[nodiscard]] bool h5_transport_mode() const;
    void set_h5_transport_mode(bool enabled);
    [[nodiscard]] std::size_t minimum_receive_bytes() const;
    void set_minimum_receive_bytes(std::size_t bytes);
    [[nodiscard]] std::uint32_t modem_control_bits() const;
    void set_modem_control_bits(std::uint32_t bits);
    void update_modem_control_bits(std::uint32_t bits, bool enabled);
    // IOAOS_RECEIVE_QUEUE installs a fixed-size driver queue descriptor. The
    // offline endpoint records the bounded descriptor for state inspection but
    // never dereferences guest pointers or creates synthetic receive bytes.
    [[nodiscard]] bool configure_receive_queue(
        std::span<const std::byte> configuration);
    [[nodiscard]] bool receive_queue_configured() const;
    // TIOCFLUSH clears the software receive queue. Writes are synchronous, so
    // there is no pending transmit queue to retain or fabricate.
    void flush_buffers(std::uint32_t what);
    // A zero capacity preserves the virtual/replay transport's dynamic channel
    // allocation. Offline transport bounds both its anonymous slots and its
    // named logical-channel registry; named channels use the same logical
    // unit table as the stock serial-mux ABI.
    void set_mux_channel_capacity(std::uint32_t capacity);
    // Offline transports retain the modem's small command/control handshake
    // while omitting radio state and unsolicited traffic.
    void set_offline_control_enabled(bool enabled);
    [[nodiscard]] std::uint32_t register_mux_channel(std::string_view name,
        std::optional<std::uint32_t> requested_unit = std::nullopt);
    [[nodiscard]] std::string mux_channel_device_path(std::uint32_t unit) const;
    [[nodiscard]] bool configure_mux_network_interface(
        std::uint32_t unit, std::string_view name);
    [[nodiscard]] std::optional<std::uint32_t> mux_channel(
        std::string_view name) const;
    void enqueue_receive(std::span<const std::byte> bytes);
    void enqueue_receive(
        std::uint32_t channel, std::span<const std::byte> bytes);
    [[nodiscard]] std::vector<std::byte> receive(std::size_t maximum);
    [[nodiscard]] std::size_t pending_receive_bytes() const;
    [[nodiscard]] std::size_t write(std::span<const std::byte> bytes);
    [[nodiscard]] std::vector<std::byte> take_transmitted();
    // Capture is opt-in. The application installs either a null sink or a
    // streaming sink, and tests/embedding callers explicitly enable bounded
    // in-memory capture when they need to inspect recent bytes.
    void set_transmit_capture_enabled(bool enabled);
    // A sink receives one complete guest write while the device state is
    // serialized. Returning false makes that write fail instead of reporting a
    // partial fixed-node write.
    void set_transmit_sink(TransmitSink sink);
    [[nodiscard]] bool transmit_sink_failed() const;

private:
    struct ScheduledReceive {
        std::chrono::steady_clock::time_point ready_at;
        std::vector<std::byte> bytes;
    };

    struct ChannelState {
        std::deque<std::byte> receive_queue;
        std::deque<ScheduledReceive> scheduled_receive_queue;
        std::size_t minimum_receive_bytes { };
    };

    struct OpenOwner {
        std::uint64_t token { };
        std::uint32_t process_id { };
    };

    friend struct OpenDescription;

    [[nodiscard]] IoctlResult ioctl_for_owner(
        std::uint32_t command, std::uint64_t token, std::uint32_t process_id);
    [[nodiscard]] std::vector<std::byte> receive_channel(
        std::uint32_t channel, std::size_t maximum);
    [[nodiscard]] std::size_t pending_receive_channel(
        std::uint32_t channel) const;
    [[nodiscard]] bool receive_eof_channel(std::uint32_t channel) const;
    [[nodiscard]] std::size_t write_channel(
        std::uint32_t channel, std::span<const std::byte> bytes);
    [[nodiscard]] bool writable_channel(std::uint32_t channel) const;
    [[nodiscard]] bool sink_failed_channel(std::uint32_t channel) const;
    void promote_ready_receive(ChannelState& channel);
    void flush_channel(std::uint32_t channel, std::uint32_t what);
    void release_description(const OpenDescription& description);

    mutable std::mutex mutex_;
    bool available_ { true };
    bool transmit_queue_writable_ { true };
    bool dynamic_channels_available_ { true };
    bool exclusive_ { };
    std::optional<OpenOwner> exclusive_owner_;
    std::uint64_t next_open_token_ { 1 };
    bool h5_transport_mode_ { };
    std::uint32_t modem_control_bits_ { };
    std::array<std::byte, darwin::tty::receive_queue_configuration_size>
        receive_queue_configuration_ { };
    bool receive_queue_configured_ { };
    std::uint32_t anonymous_mux_channel_capacity_ { };
    std::uint32_t next_anonymous_mux_channel_ { 1 };
    std::map<std::string, std::uint32_t> mux_channels_;
    std::map<std::uint32_t, std::string> mux_network_interfaces_;
    std::uint32_t next_mux_channel_ { 1 };
    darwin::tty::Arm32Attributes attributes_ {
        darwin::tty::default_attributes()
    };
    std::map<std::uint32_t, ChannelState> channels_;
    bool receive_eof_ { };
    std::vector<std::byte> transmitted_;
    TransmitSink transmit_sink_;
    bool transmit_capture_enabled_ { };
    bool transmit_sink_failed_ { };
    bool offline_control_enabled_ { };
    OfflineControlPlane offline_control_;
    std::chrono::steady_clock::time_point offline_response_deadline_ { };
    std::shared_ptr<OpenDescriptionLifetime> lifetime_;
};

[[nodiscard]] bool is_path(std::string_view candidate);
[[nodiscard]] bool is_mux_channel_path(std::string_view candidate);
[[nodiscard]] bool is_mux_path(std::string_view candidate);

inline State::State()
    : lifetime_ { std::make_shared<OpenDescriptionLifetime>() }
{
    lifetime_->state = this;
    channels_.emplace(0U, ChannelState { });
}

inline State::~State()
{
    if (lifetime_)
        lifetime_->state = nullptr;
}

} // namespace shade::bsd::baseband_device
