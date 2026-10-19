// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Translate guest socket operations, addresses and errors to host
// networking APIs.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/uipc_syscalls.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/uipc_socket.c

#pragma once

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade {

enum class HostNetworkPolicy : std::uint8_t {
    Isolated,
    Loopback,
    Host,
};

[[nodiscard]] std::optional<HostNetworkPolicy> parse_host_network_policy(
    std::string_view value);
[[nodiscard]] std::string_view host_network_policy_name(
    HostNetworkPolicy policy);
[[nodiscard]] std::optional<std::array<std::byte, 4>> parse_host_ipv4_resolver(
    std::string_view configuration);

enum class HostSocketStatus : std::uint8_t {
    Success,
    WouldBlock,
    Error,
};

class HostSocket;

struct HostSocketCreateResult {
    std::shared_ptr<HostSocket> socket;
    std::uint32_t darwin_error { };
};

struct HostSocketResult {
    HostSocketStatus status { HostSocketStatus::Success };
    std::uint32_t darwin_error { };
    std::size_t transferred { };
    std::vector<std::byte> bytes;
    std::vector<std::byte> address;
    std::vector<std::byte> destination_address;
    // Virtual Darwin interface index (lo0=1, en0=2), never a host ifindex.
    std::optional<std::uint32_t> interface_index;
    std::optional<std::uint32_t> hop_limit;
    std::shared_ptr<HostSocket> accepted_socket;
};

// Owns a non-blocking host socket while keeping every host ABI detail outside
// the compatibility kernel. Guest addresses are always Darwin sockaddr byte
// sequences; no host sockaddr object crosses this boundary.
class HostSocket {
public:
    static HostSocketCreateResult create(HostNetworkPolicy policy,
        std::uint32_t darwin_family, std::uint32_t darwin_type,
        std::uint32_t protocol);

    ~HostSocket();
    HostSocket(const HostSocket&) = delete;
    HostSocket& operator=(const HostSocket&) = delete;

    [[nodiscard]] HostSocketResult connect(
        std::span<const std::byte> darwin_address);
    [[nodiscard]] HostSocketResult finish_connect();
    [[nodiscard]] HostSocketResult bind(
        std::span<const std::byte> darwin_address);
    [[nodiscard]] HostSocketResult listen(std::uint32_t backlog);
    [[nodiscard]] HostSocketResult accept();
    [[nodiscard]] HostSocketResult send(std::span<const std::byte> bytes,
        std::span<const std::byte> darwin_destination = { });
    [[nodiscard]] HostSocketResult receive(std::size_t capacity);
    [[nodiscard]] HostSocketResult set_option(std::uint32_t darwin_level,
        std::uint32_t darwin_option, std::span<const std::byte> value);
    [[nodiscard]] HostSocketResult local_address() const;
    [[nodiscard]] HostSocketResult peer_address() const;
    [[nodiscard]] HostSocketResult pending_bytes() const;
    [[nodiscard]] HostSocketResult socket_error();
    [[nodiscard]] HostSocketResult shutdown(std::uint32_t how);
    [[nodiscard]] bool readable() const;
    [[nodiscard]] bool writable() const;

    [[nodiscard]] HostNetworkPolicy policy() const { return policy_; }
    [[nodiscard]] std::uint32_t darwin_family() const { return darwin_family_; }
    [[nodiscard]] std::uint32_t darwin_type() const { return darwin_type_; }

private:
    enum class StreamState : std::uint8_t {
        Initial,
        Connecting,
        Connected,
        Listening,
    };

    HostSocket(int descriptor, HostNetworkPolicy policy,
        std::uint32_t darwin_family, std::uint32_t darwin_type,
        StreamState stream_state = StreamState::Initial);

    int descriptor_ { -1 };
    HostNetworkPolicy policy_ { HostNetworkPolicy::Isolated };
    std::uint32_t darwin_family_ { };
    std::uint32_t darwin_type_ { };
    std::atomic<StreamState> stream_state_ { StreamState::Initial };
    std::optional<std::vector<std::byte>> presented_peer_address_;
    bool presents_virtual_local_ipv4_address_ { };
    bool receive_destination_address_ { };
    bool receive_interface_ { };
    bool receive_hop_limit_ { };
};

} // namespace shade
