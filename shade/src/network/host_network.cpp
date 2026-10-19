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

#include "network/host_network.hpp"

#include "foundation/darwin_errno.hpp"
#include "network/darwin_socket_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "network/virtual_network.hpp"

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstring>
#include <fstream>
#include <limits>
#include <sstream>
#include <string>

#include <arpa/inet.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

namespace shade {
namespace {

    constexpr std::uint32_t darwin_socket_stream = 1;
    constexpr std::uint32_t darwin_socket_datagram = 2;
    constexpr std::uint32_t darwin_error_permission_denied = 13;
    constexpr std::uint32_t darwin_error_invalid_argument = 22;
    constexpr std::uint32_t darwin_error_would_block = 35;
    constexpr std::uint32_t darwin_error_in_progress = 36;
    constexpr std::uint32_t darwin_error_address_family_unsupported = 47;
    constexpr std::uint32_t darwin_error_host_unreachable = 65;

    struct HostAddress {
        sockaddr_storage storage { };
        socklen_t length { };
    };

    struct HostInterface {
        std::uint32_t index { };
        in_addr ipv4_address { };
        bool has_ipv4_address { };
        bool loopback { };
    };

    std::optional<HostInterface> find_host_interface(
        HostNetworkPolicy policy, int family, bool guest_loopback)
    {
        ifaddrs* interfaces = nullptr;
        if (::getifaddrs(&interfaces) != 0)
            return std::nullopt;
        const bool want_loopback =
            policy == HostNetworkPolicy::Loopback || guest_loopback;
        std::optional<HostInterface> fallback;
        for (auto* current = interfaces; current != nullptr;
            current = current->ifa_next) {
            if (current->ifa_addr == nullptr || current->ifa_name == nullptr ||
                current->ifa_addr->sa_family != family ||
                (current->ifa_flags & IFF_UP) == 0) {
                continue;
            }
            const bool loopback = (current->ifa_flags & IFF_LOOPBACK) != 0;
            HostInterface candidate;
            candidate.index = ::if_nametoindex(current->ifa_name);
            candidate.loopback = loopback;
            if (family == AF_INET) {
                candidate.ipv4_address =
                    reinterpret_cast<const sockaddr_in*>(current->ifa_addr)
                        ->sin_addr;
                candidate.has_ipv4_address = true;
            }
            if (candidate.index == 0)
                continue;
            if (loopback == want_loopback &&
                (loopback || (current->ifa_flags & IFF_MULTICAST) != 0)) {
                ::freeifaddrs(interfaces);
                return candidate;
            }
            if (!fallback || (fallback->loopback && !loopback)) {
                fallback = candidate;
            }
        }
        ::freeifaddrs(interfaces);
        return want_loopback ? std::nullopt : fallback;
    }

    bool host_interface_is_loopback(std::uint32_t index)
    {
        ifaddrs* interfaces = nullptr;
        if (::getifaddrs(&interfaces) != 0)
            return false;
        bool result = false;
        for (auto* current = interfaces; current != nullptr;
            current = current->ifa_next) {
            if (current->ifa_name != nullptr &&
                ::if_nametoindex(current->ifa_name) == index) {
                result = (current->ifa_flags & IFF_LOOPBACK) != 0;
                break;
            }
        }
        ::freeifaddrs(interfaces);
        return result;
    }

    std::uint32_t to_darwin_interface_index(
        HostNetworkPolicy policy, std::uint32_t host_index)
    {
        return policy == HostNetworkPolicy::Loopback ||
                       host_interface_is_loopback(host_index)
                   ? 1U
                   : 2U;
    }

    std::optional<std::uint32_t> read_u32(std::span<const std::byte> bytes)
    {
        if (bytes.size() < sizeof(std::uint32_t))
            return std::nullopt;
        std::uint32_t result = 0;
        std::memcpy(&result, bytes.data(), sizeof(result));
        return result;
    }

    std::uint32_t translate_error(int error)
    {
        switch (error) {
        case 0:
            return 0;
        case EPERM:
            return 1;
        case ENOENT:
            return 2;
        case EINTR:
            return 4;
        case EIO:
            return 5;
        case EBADF:
            return 9;
        case EACCES:
            return darwin_error_permission_denied;
        case EFAULT:
            return 14;
        case EINVAL:
            return darwin_error_invalid_argument;
        case EPIPE:
            return darwin::error::broken_pipe;
        case EMFILE:
            return 24;
        case ENFILE:
            return 23;
        case EAGAIN:
            return darwin_error_would_block;
        case EINPROGRESS:
            return darwin_error_in_progress;
        case EALREADY:
            return 37;
        case ENOTSOCK:
            return 38;
        case EDESTADDRREQ:
            return 39;
        case EMSGSIZE:
            return 40;
        case EPROTOTYPE:
            return 41;
        case ENOPROTOOPT:
            return 42;
        case EPROTONOSUPPORT:
            return 43;
        case ESOCKTNOSUPPORT:
            return 44;
        case EOPNOTSUPP:
            return 45;
        case EPFNOSUPPORT:
            return 46;
        case EAFNOSUPPORT:
            return darwin_error_address_family_unsupported;
        case EADDRINUSE:
            return 48;
        case EADDRNOTAVAIL:
            return 49;
        case ENETDOWN:
            return 50;
        case ENETUNREACH:
            return 51;
        case ENETRESET:
            return 52;
        case ECONNABORTED:
            return 53;
        case ECONNRESET:
            return 54;
        case ENOBUFS:
            return 55;
        case EISCONN:
            return 56;
        case ENOTCONN:
            return 57;
        case ESHUTDOWN:
            return 58;
        case ETIMEDOUT:
            return 60;
        case ECONNREFUSED:
            return 61;
        case ELOOP:
            return 62;
        case ENAMETOOLONG:
            return 63;
#ifdef EHOSTDOWN
        case EHOSTDOWN:
            return 64;
#endif
        case EHOSTUNREACH:
            return darwin_error_host_unreachable;
        default:
            return 5; // EIO for host errors without a Darwin 8 equivalent.
        }
    }

    HostSocketResult error_result(int error)
    {
        HostSocketResult result;
        if (error == EAGAIN || error == EWOULDBLOCK || error == EINPROGRESS ||
            error == EALREADY) {
            result.status = HostSocketStatus::WouldBlock;
        } else {
            result.status = HostSocketStatus::Error;
        }
        result.darwin_error = translate_error(error);
        return result;
    }

    HostSocketResult darwin_error_result(std::uint32_t error)
    {
        HostSocketResult result;
        result.status = HostSocketStatus::Error;
        result.darwin_error = error;
        return result;
    }

    bool configure_socket_descriptor(int descriptor)
    {
        const auto descriptor_flags = ::fcntl(descriptor, F_GETFD);
        const auto status_flags = ::fcntl(descriptor, F_GETFL);
        if (descriptor_flags < 0 || status_flags < 0 ||
            ::fcntl(descriptor, F_SETFD, descriptor_flags | FD_CLOEXEC) != 0 ||
            ::fcntl(descriptor, F_SETFL, status_flags | O_NONBLOCK) != 0) {
            return false;
        }
#if defined(SO_NOSIGPIPE)
        const int suppress_sigpipe = 1;
        if (::setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE,
                &suppress_sigpipe, sizeof(suppress_sigpipe)) != 0) {
            return false;
        }
#endif
        return true;
    }

    bool is_ipv4_loopback(in_addr address)
    {
        return (ntohl(address.s_addr) & 0xff00'0000U) == 0x7f00'0000U;
    }

    std::optional<in_addr> host_ipv4_resolver()
    {
        static const auto resolver = []() -> std::optional<in_addr> {
            std::ifstream configuration { "/etc/resolv.conf" };
            if (!configuration)
                return std::nullopt;
            const std::string text { std::istreambuf_iterator<char> {
                                         configuration },
                std::istreambuf_iterator<char> { } };
            const auto parsed = parse_host_ipv4_resolver(text);
            if (!parsed)
                return std::nullopt;
            in_addr result { };
            std::memcpy(&result, parsed->data(), parsed->size());
            return result;
        }();
        return resolver;
    }

    std::optional<HostAddress> to_host_address(std::span<const std::byte> bytes,
        HostNetworkPolicy policy, bool binding, std::uint32_t& error,
        bool* dns_redirected = nullptr,
        bool* local_address_redirected = nullptr)
    {
        if (dns_redirected)
            *dns_redirected = false;
        if (local_address_redirected)
            *local_address_redirected = false;
        if (bytes.size() < 2) {
            error = darwin_error_invalid_argument;
            return std::nullopt;
        }
        // XNU's getsockaddr() overwrites sa_len with the syscall-supplied
        // length after copying the user buffer. The span already represents
        // that length, so an uninitialized or stale user sa_len byte must not
        // reject an otherwise valid sockaddr.
        const auto declared_length = bytes.size();
        const auto family = std::to_integer<std::uint8_t>(bytes[1]);

        HostAddress result;
        if (family == darwin::network::address_family_inet) {
            if (declared_length < 16 || bytes.size() < 16) {
                error = darwin_error_invalid_argument;
                return std::nullopt;
            }
            sockaddr_in address { };
            address.sin_family = AF_INET;
            std::memcpy(
                &address.sin_port, bytes.data() + 2, sizeof(address.sin_port));
            std::memcpy(
                &address.sin_addr, bytes.data() + 4, sizeof(address.sin_addr));
            const auto guest_client_address = std::equal(bytes.begin() + 4,
                bytes.begin() + 8, virtual_network::client_address.begin());
            if (binding && policy == HostNetworkPolicy::Host &&
                guest_client_address) {
                address.sin_addr.s_addr = htonl(INADDR_ANY);
                if (local_address_redirected)
                    *local_address_redirected = true;
            } else if (!binding && policy == HostNetworkPolicy::Host &&
                       ntohs(address.sin_port) == virtual_network::dns_port &&
                       std::equal(bytes.begin() + 4, bytes.begin() + 8,
                           virtual_network::dns_proxy_address.begin())) {
                if (const auto resolver = host_ipv4_resolver()) {
                    address.sin_addr = *resolver;
                    if (dns_redirected)
                        *dns_redirected = true;
                }
            }
            if (policy == HostNetworkPolicy::Loopback) {
                if (binding && address.sin_addr.s_addr == htonl(INADDR_ANY)) {
                    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
                } else if (!is_ipv4_loopback(address.sin_addr) &&
                           !IN_MULTICAST(ntohl(address.sin_addr.s_addr))) {
                    error = darwin_error_host_unreachable;
                    return std::nullopt;
                }
            }
            std::memcpy(&result.storage, &address, sizeof(address));
            result.length = sizeof(address);
            return result;
        }
        if (family == darwin::network::address_family_inet6) {
            if (declared_length < 28 || bytes.size() < 28) {
                error = darwin_error_invalid_argument;
                return std::nullopt;
            }
            sockaddr_in6 address { };
            address.sin6_family = AF_INET6;
            std::memcpy(&address.sin6_port, bytes.data() + 2,
                sizeof(address.sin6_port));
            std::memcpy(&address.sin6_flowinfo, bytes.data() + 4,
                sizeof(address.sin6_flowinfo));
            std::memcpy(&address.sin6_addr, bytes.data() + 8,
                sizeof(address.sin6_addr));
            std::memcpy(&address.sin6_scope_id, bytes.data() + 24,
                sizeof(address.sin6_scope_id));
            const bool multicast = IN6_IS_ADDR_MULTICAST(&address.sin6_addr);
            if (policy == HostNetworkPolicy::Loopback) {
                if (binding && IN6_IS_ADDR_UNSPECIFIED(&address.sin6_addr)) {
                    address.sin6_addr = in6addr_loopback;
                } else if (!IN6_IS_ADDR_LOOPBACK(&address.sin6_addr) &&
                           !multicast) {
                    error = darwin_error_host_unreachable;
                    return std::nullopt;
                }
            }
            if (address.sin6_scope_id != 0 || multicast) {
                const bool guest_loopback = address.sin6_scope_id == 1;
                if (const auto interface =
                        find_host_interface(policy, AF_INET6, guest_loopback)) {
                    address.sin6_scope_id = interface->index;
                } else if (multicast) {
                    error = darwin_error_host_unreachable;
                    return std::nullopt;
                }
            }
            std::memcpy(&result.storage, &address, sizeof(address));
            result.length = sizeof(address);
            return result;
        }
        error = darwin_error_address_family_unsupported;
        return std::nullopt;
    }

    std::vector<std::byte> to_darwin_address(
        const sockaddr_storage& storage, socklen_t length)
    {
        if (storage.ss_family == AF_INET && length >= sizeof(sockaddr_in)) {
            const auto& address = reinterpret_cast<const sockaddr_in&>(storage);
            std::vector<std::byte> result(16);
            result[0] = std::byte { 16 };
            result[1] =
                static_cast<std::byte>(darwin::network::address_family_inet);
            std::memcpy(
                result.data() + 2, &address.sin_port, sizeof(address.sin_port));
            std::memcpy(
                result.data() + 4, &address.sin_addr, sizeof(address.sin_addr));
            return result;
        }
        if (storage.ss_family == AF_INET6 && length >= sizeof(sockaddr_in6)) {
            const auto& address =
                reinterpret_cast<const sockaddr_in6&>(storage);
            std::vector<std::byte> result(28);
            result[0] = std::byte { 28 };
            result[1] =
                static_cast<std::byte>(darwin::network::address_family_inet6);
            std::memcpy(result.data() + 2, &address.sin6_port,
                sizeof(address.sin6_port));
            std::memcpy(result.data() + 4, &address.sin6_flowinfo,
                sizeof(address.sin6_flowinfo));
            std::memcpy(result.data() + 8, &address.sin6_addr,
                sizeof(address.sin6_addr));
            std::memcpy(result.data() + 24, &address.sin6_scope_id,
                sizeof(address.sin6_scope_id));
            return result;
        }
        return { };
    }

    HostSocketResult socket_address_result(int result, int error,
        const sockaddr_storage& address, socklen_t length)
    {
        if (result != 0)
            return error_result(error);
        HostSocketResult output;
        output.address = to_darwin_address(address, length);
        if (output.address.empty()) {
            output.status = HostSocketStatus::Error;
            output.darwin_error = darwin_error_address_family_unsupported;
        }
        return output;
    }

} // namespace

std::optional<HostNetworkPolicy> parse_host_network_policy(
    std::string_view value)
{
    if (value == "isolated")
        return HostNetworkPolicy::Isolated;
    if (value == "loopback")
        return HostNetworkPolicy::Loopback;
    if (value == "host")
        return HostNetworkPolicy::Host;
    return std::nullopt;
}

std::optional<std::array<std::byte, 4>> parse_host_ipv4_resolver(
    std::string_view configuration)
{
    std::istringstream lines { std::string { configuration } };
    std::string line;
    while (std::getline(lines, line)) {
        const auto comment = line.find_first_of("#;");
        if (comment != std::string::npos)
            line.resize(comment);
        std::istringstream fields { line };
        std::string directive;
        std::string address;
        fields >> directive >> address;
        if (directive != "nameserver" || address.empty())
            continue;
        in_addr parsed { };
        if (::inet_pton(AF_INET, address.c_str(), &parsed) != 1)
            continue;
        std::array<std::byte, 4> result { };
        std::memcpy(result.data(), &parsed, result.size());
        return result;
    }
    return std::nullopt;
}

std::string_view host_network_policy_name(HostNetworkPolicy policy)
{
    switch (policy) {
    case HostNetworkPolicy::Isolated:
        return "isolated";
    case HostNetworkPolicy::Loopback:
        return "loopback";
    case HostNetworkPolicy::Host:
        return "host";
    }
    return "isolated";
}

HostSocketCreateResult HostSocket::create(HostNetworkPolicy policy,
    std::uint32_t darwin_family, std::uint32_t darwin_type,
    std::uint32_t protocol)
{
    if (policy == HostNetworkPolicy::Isolated) {
        return { { }, darwin_error_address_family_unsupported };
    }
    const auto family =
        darwin_family == darwin::network::address_family_inet    ? AF_INET
        : darwin_family == darwin::network::address_family_inet6 ? AF_INET6
                                                                 : -1;
    const auto type = darwin_type == darwin_socket_stream     ? SOCK_STREAM
                      : darwin_type == darwin_socket_datagram ? SOCK_DGRAM
                                                              : -1;
    if (family < 0)
        return { { }, darwin_error_address_family_unsupported };
    if (type < 0)
        return { { }, 44 }; // ESOCKTNOSUPPORT
    if (protocol != 0 && protocol != IPPROTO_TCP && protocol != IPPROTO_UDP) {
        return { { }, 43 }; // EPROTONOSUPPORT
    }
    const auto descriptor = ::socket(family, type, static_cast<int>(protocol));
    if (descriptor < 0)
        return { { }, translate_error(errno) };
    if (!configure_socket_descriptor(descriptor)) {
        const auto error = errno;
        ::close(descriptor);
        return { { }, translate_error(error) };
    }
    return { std::shared_ptr<HostSocket> { new HostSocket {
                 descriptor, policy, darwin_family, darwin_type } },
        0 };
}

HostSocket::HostSocket(int descriptor, HostNetworkPolicy policy,
    std::uint32_t darwin_family, std::uint32_t darwin_type,
    StreamState stream_state)
    : descriptor_ { descriptor }
    , policy_ { policy }
    , darwin_family_ { darwin_family }
    , darwin_type_ { darwin_type }
    , stream_state_ { stream_state }
{
}

HostSocket::~HostSocket()
{
    if (descriptor_ >= 0)
        ::close(descriptor_);
}

HostSocketResult HostSocket::connect(std::span<const std::byte> darwin_address)
{
    std::uint32_t address_error = 0;
    bool dns_redirected = false;
    const auto address = to_host_address(
        darwin_address, policy_, false, address_error, &dns_redirected);
    if (!address)
        return darwin_error_result(address_error);
    presented_peer_address_ =
        dns_redirected
            ? std::optional<std::vector<std::byte>> { std::vector<std::byte> {
                  darwin_address.begin(), darwin_address.end() } }
            : std::nullopt;
    if (::connect(descriptor_,
            reinterpret_cast<const sockaddr*>(&address->storage),
            address->length) == 0) {
        if (darwin_type_ == darwin_socket_stream) {
            stream_state_.store(
                StreamState::Connected, std::memory_order_relaxed);
        }
        return { };
    }
    if (errno == EISCONN) {
        if (darwin_type_ == darwin_socket_stream) {
            stream_state_.store(
                StreamState::Connected, std::memory_order_relaxed);
        }
        return { };
    }
    const auto result = error_result(errno);
    if (darwin_type_ == darwin_socket_stream) {
        stream_state_.store(result.status == HostSocketStatus::WouldBlock
                                ? StreamState::Connecting
                                : StreamState::Initial,
            std::memory_order_relaxed);
    }
    return result;
}

HostSocketResult HostSocket::finish_connect()
{
    int socket_error = 0;
    socklen_t size = sizeof(socket_error);
    if (::getsockopt(descriptor_, SOL_SOCKET, SO_ERROR, &socket_error, &size) !=
        0) {
        return error_result(errno);
    }
    const auto result =
        socket_error == 0 ? HostSocketResult { } : error_result(socket_error);
    if (darwin_type_ == darwin_socket_stream &&
        stream_state_.load(std::memory_order_relaxed) ==
            StreamState::Connecting &&
        result.status != HostSocketStatus::WouldBlock) {
        stream_state_.store(result.status == HostSocketStatus::Success
                                ? StreamState::Connected
                                : StreamState::Initial,
            std::memory_order_relaxed);
    }
    return result;
}

HostSocketResult HostSocket::bind(std::span<const std::byte> darwin_address)
{
    std::uint32_t address_error = 0;
    bool local_address_redirected = false;
    const auto address = to_host_address(darwin_address, policy_, true,
        address_error, nullptr, &local_address_redirected);
    if (!address)
        return darwin_error_result(address_error);
    if (::bind(descriptor_,
            reinterpret_cast<const sockaddr*>(&address->storage),
            address->length) != 0) {
        return error_result(errno);
    }
    presents_virtual_local_ipv4_address_ = local_address_redirected;
    return { };
}

HostSocketResult HostSocket::listen(std::uint32_t backlog)
{
    const auto host_backlog = static_cast<int>(std::min<std::uint32_t>(
        backlog, static_cast<std::uint32_t>(std::numeric_limits<int>::max())));
    if (::listen(descriptor_, host_backlog) != 0)
        return error_result(errno);
    if (darwin_type_ == darwin_socket_stream) {
        stream_state_.store(StreamState::Listening, std::memory_order_relaxed);
    }
    return { };
}

HostSocketResult HostSocket::accept()
{
    sockaddr_storage address { };
    socklen_t length = sizeof(address);
    const auto accepted =
        ::accept(descriptor_, reinterpret_cast<sockaddr*>(&address), &length);
    if (accepted < 0)
        return error_result(errno);
    if (!configure_socket_descriptor(accepted)) {
        const auto error = errno;
        ::close(accepted);
        return error_result(error);
    }
    HostSocketResult result;
    result.address = to_darwin_address(address, length);
    result.accepted_socket =
        std::shared_ptr<HostSocket> { new HostSocket { accepted, policy_,
            darwin_family_, darwin_type_, StreamState::Connected } };
    return result;
}

HostSocketResult HostSocket::send(std::span<const std::byte> bytes,
    std::span<const std::byte> darwin_destination)
{
    ssize_t transferred = -1;
    constexpr int send_flags =
#ifdef MSG_NOSIGNAL
        MSG_NOSIGNAL;
#else
        0;
#endif
    if (darwin_destination.empty()) {
        transferred =
            ::send(descriptor_, bytes.data(), bytes.size(), send_flags);
    } else {
        std::uint32_t address_error = 0;
        bool dns_redirected = false;
        const auto address = to_host_address(
            darwin_destination, policy_, false, address_error, &dns_redirected);
        if (!address)
            return darwin_error_result(address_error);
        presented_peer_address_ =
            dns_redirected
                ? std::optional<
                      std::vector<std::byte>> { std::vector<std::byte> {
                      darwin_destination.begin(), darwin_destination.end() } }
                : std::nullopt;
        transferred = ::sendto(descriptor_, bytes.data(), bytes.size(),
            send_flags, reinterpret_cast<const sockaddr*>(&address->storage),
            address->length);
    }
    if (transferred < 0)
        return error_result(errno);
    HostSocketResult result;
    result.transferred = static_cast<std::size_t>(transferred);
    return result;
}

HostSocketResult HostSocket::receive(std::size_t capacity)
{
    HostSocketResult result;
    result.bytes.resize(capacity);
    sockaddr_storage address { };
    std::array<std::byte, 256> ancillary { };
    iovec vector { result.bytes.data(), result.bytes.size() };
    msghdr message { };
    message.msg_name = &address;
    message.msg_namelen = sizeof(address);
    message.msg_iov = &vector;
    message.msg_iovlen = 1;
    message.msg_control = ancillary.data();
    message.msg_controllen = ancillary.size();
    const auto transferred = ::recvmsg(descriptor_, &message, 0);
    if (transferred < 0)
        return error_result(errno);
    result.transferred = static_cast<std::size_t>(transferred);
    result.bytes.resize(result.transferred);
    result.address = to_darwin_address(address, message.msg_namelen);
    if (presented_peer_address_)
        result.address = *presented_peer_address_;
    for (auto* control = CMSG_FIRSTHDR(&message); control != nullptr;
        control = CMSG_NXTHDR(&message, control)) {
#if defined(IP_PKTINFO)
        if (control->cmsg_level == IPPROTO_IP &&
            control->cmsg_type == IP_PKTINFO &&
            control->cmsg_len >= CMSG_LEN(sizeof(in_pktinfo))) {
            const auto* info =
                reinterpret_cast<const in_pktinfo*>(CMSG_DATA(control));
            result.destination_address.resize(sizeof(info->ipi_addr));
            std::memcpy(result.destination_address.data(), &info->ipi_addr,
                sizeof(info->ipi_addr));
            result.interface_index = to_darwin_interface_index(
                policy_, static_cast<std::uint32_t>(info->ipi_ifindex));
        }
#endif
#if defined(IP_TTL)
        if (control->cmsg_level == IPPROTO_IP && control->cmsg_type == IP_TTL &&
            control->cmsg_len >= CMSG_LEN(sizeof(int))) {
            int value = 0;
            std::memcpy(&value, CMSG_DATA(control), sizeof(value));
            result.hop_limit =
                static_cast<std::uint32_t>(std::clamp(value, 0, 255));
        }
#endif
#if defined(IPV6_PKTINFO)
        if (control->cmsg_level == IPPROTO_IPV6 &&
            control->cmsg_type == IPV6_PKTINFO &&
            control->cmsg_len >= CMSG_LEN(sizeof(in6_pktinfo))) {
            const auto* info =
                reinterpret_cast<const in6_pktinfo*>(CMSG_DATA(control));
            result.destination_address.resize(sizeof(info->ipi6_addr));
            std::memcpy(result.destination_address.data(), &info->ipi6_addr,
                sizeof(info->ipi6_addr));
            result.interface_index = to_darwin_interface_index(
                policy_, static_cast<std::uint32_t>(info->ipi6_ifindex));
        }
#endif
#if defined(IPV6_HOPLIMIT)
        if (control->cmsg_level == IPPROTO_IPV6 &&
            control->cmsg_type == IPV6_HOPLIMIT &&
            control->cmsg_len >= CMSG_LEN(sizeof(int))) {
            int value = 0;
            std::memcpy(&value, CMSG_DATA(control), sizeof(value));
            result.hop_limit =
                static_cast<std::uint32_t>(std::clamp(value, 0, 255));
        }
#endif
    }
    if (receive_destination_address_ && result.destination_address.empty()) {
        sockaddr_storage local { };
        socklen_t local_length = sizeof(local);
        if (::getsockname(descriptor_, reinterpret_cast<sockaddr*>(&local),
                &local_length) == 0) {
            if (local.ss_family == AF_INET) {
                const auto& inet = reinterpret_cast<const sockaddr_in&>(local);
                result.destination_address.resize(sizeof(inet.sin_addr));
                std::memcpy(result.destination_address.data(), &inet.sin_addr,
                    sizeof(inet.sin_addr));
            } else if (local.ss_family == AF_INET6) {
                const auto& inet6 =
                    reinterpret_cast<const sockaddr_in6&>(local);
                result.destination_address.resize(sizeof(inet6.sin6_addr));
                std::memcpy(result.destination_address.data(), &inet6.sin6_addr,
                    sizeof(inet6.sin6_addr));
            }
        }
    }
    if (presents_virtual_local_ipv4_address_ &&
        result.destination_address.size() ==
            virtual_network::client_address.size()) {
        std::copy(virtual_network::client_address.begin(),
            virtual_network::client_address.end(),
            result.destination_address.begin());
    }
    if (!result.interface_index && receive_interface_) {
        result.interface_index =
            policy_ == HostNetworkPolicy::Loopback ? 1U : 2U;
    }
    return result;
}

HostSocketResult HostSocket::set_option(std::uint32_t darwin_level,
    std::uint32_t darwin_option, std::span<const std::byte> value)
{
    int integer_value = 0;
    if (!value.empty()) {
        std::memcpy(&integer_value, value.data(),
            std::min(value.size(), sizeof(integer_value)));
    }
    const int enabled = integer_value != 0;
    const auto set_host_option = [&](int level, int option, const void* data,
                                     socklen_t size) {
        return ::setsockopt(descriptor_, level, option, data, size) == 0
                   ? HostSocketResult { }
                   : error_result(errno);
    };
    const auto guest_ipv4_loopback = [&](std::size_t offset) {
        if (value.size() < offset + sizeof(in_addr))
            return false;
        in_addr address { };
        std::memcpy(&address, value.data() + offset, sizeof(address));
        return is_ipv4_loopback(address);
    };
    const auto selected_interface = [&](int family, bool guest_loopback) {
        return find_host_interface(policy_, family, guest_loopback);
    };

    if (darwin_level == darwin::socket::option_level &&
        darwin_option == darwin::socket::option_reuse_address) {
        return set_host_option(
            SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));
    }
    if (darwin_level == darwin::socket::option_level &&
        darwin_option == darwin::socket::option_reuse_port) {
        const auto address_reuse = set_host_option(
            SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));
        if (address_reuse.status != HostSocketStatus::Success) {
            return address_reuse;
        }
#if defined(SO_REUSEPORT)
        return set_host_option(
            SOL_SOCKET, SO_REUSEPORT, &enabled, sizeof(enabled));
#else
        return { };
#endif
    }
    if (darwin_level == darwin::network::protocol_ip &&
        (darwin_option == darwin::network::ip_receive_destination_address ||
            darwin_option == darwin::network::ip_receive_interface)) {
        if (darwin_option == darwin::network::ip_receive_destination_address) {
            receive_destination_address_ = enabled != 0;
        } else {
            receive_interface_ = enabled != 0;
        }
#if defined(IP_PKTINFO)
        const int packet_info =
            receive_destination_address_ || receive_interface_ ? 1 : 0;
        if (::setsockopt(descriptor_, IPPROTO_IP, IP_PKTINFO, &packet_info,
                sizeof(packet_info)) != 0) {
            return error_result(errno);
        }
#endif
        return { };
    }
    if (darwin_level == darwin::network::protocol_ip &&
        darwin_option == darwin::network::ip_receive_ttl) {
        receive_hop_limit_ = enabled != 0;
#if defined(IP_RECVTTL)
        if (::setsockopt(descriptor_, IPPROTO_IP, IP_RECVTTL, &enabled,
                sizeof(enabled)) != 0) {
            return error_result(errno);
        }
#endif
        return { };
    }
    if (darwin_level == darwin::network::protocol_ip &&
        (darwin_option == darwin::network::ip_type_of_service ||
            darwin_option == darwin::network::ip_time_to_live)) {
        if (value.empty())
            return darwin_error_result(22); // EINVAL
        const auto host_option =
            darwin_option == darwin::network::ip_type_of_service ? IP_TOS
                                                                 : IP_TTL;
        return set_host_option(
            IPPROTO_IP, host_option, &integer_value, sizeof(integer_value));
    }
    if (darwin_level == darwin::network::protocol_ip &&
        (darwin_option == darwin::network::ip_multicast_ttl ||
            darwin_option == darwin::network::ip_multicast_loop)) {
        if (value.empty())
            return darwin_error_result(22); // EINVAL
        const auto byte_value = static_cast<unsigned char>(integer_value);
        const auto host_option =
            darwin_option == darwin::network::ip_multicast_ttl
                ? IP_MULTICAST_TTL
                : IP_MULTICAST_LOOP;
        return set_host_option(
            IPPROTO_IP, host_option, &byte_value, sizeof(byte_value));
    }
    if (darwin_level == darwin::network::protocol_ip &&
        darwin_option == darwin::network::ip_multicast_interface) {
        if (value.size() < sizeof(in_addr)) {
            return darwin_error_result(22); // EINVAL
        }
        const auto interface =
            selected_interface(AF_INET, guest_ipv4_loopback(0));
        if (!interface || !interface->has_ipv4_address) {
            return darwin_error_result(49); // EADDRNOTAVAIL
        }
        return set_host_option(IPPROTO_IP, IP_MULTICAST_IF,
            &interface->ipv4_address, sizeof(interface->ipv4_address));
    }
    if (darwin_level == darwin::network::protocol_ip &&
        (darwin_option == darwin::network::ip_add_membership ||
            darwin_option == darwin::network::ip_drop_membership)) {
        if (value.size() < darwin::network::ipv4_membership_size) {
            return darwin_error_result(22); // EINVAL
        }
        ip_mreq membership { };
        std::memcpy(&membership.imr_multiaddr, value.data(),
            sizeof(membership.imr_multiaddr));
        const auto interface =
            selected_interface(AF_INET, guest_ipv4_loopback(sizeof(in_addr)));
        if (!interface || !interface->has_ipv4_address) {
            return darwin_error_result(49); // EADDRNOTAVAIL
        }
        membership.imr_interface = interface->ipv4_address;
        const auto host_option =
            darwin_option == darwin::network::ip_add_membership
                ? IP_ADD_MEMBERSHIP
                : IP_DROP_MEMBERSHIP;
        return set_host_option(
            IPPROTO_IP, host_option, &membership, sizeof(membership));
    }
    if (darwin_level == darwin::network::protocol_ipv6 &&
        darwin_option == darwin::network::ipv6_packet_info) {
        receive_destination_address_ = enabled != 0;
        receive_interface_ = enabled != 0;
#if defined(IPV6_RECVPKTINFO)
        if (::setsockopt(descriptor_, IPPROTO_IPV6, IPV6_RECVPKTINFO, &enabled,
                sizeof(enabled)) != 0) {
            return error_result(errno);
        }
#elif defined(IPV6_PKTINFO)
        if (::setsockopt(descriptor_, IPPROTO_IPV6, IPV6_PKTINFO, &enabled,
                sizeof(enabled)) != 0) {
            return error_result(errno);
        }
#endif
        return { };
    }
    if (darwin_level == darwin::network::protocol_ipv6 &&
        darwin_option == darwin::network::ipv6_hop_limit) {
        receive_hop_limit_ = enabled != 0;
#if defined(IPV6_RECVHOPLIMIT)
        if (::setsockopt(descriptor_, IPPROTO_IPV6, IPV6_RECVHOPLIMIT, &enabled,
                sizeof(enabled)) != 0) {
            return error_result(errno);
        }
#endif
        return { };
    }
    if (darwin_level == darwin::network::protocol_ipv6 &&
        darwin_option == darwin::network::ipv6_only) {
        if (value.empty())
            return darwin_error_result(22); // EINVAL
        return set_host_option(
            IPPROTO_IPV6, IPV6_V6ONLY, &integer_value, sizeof(integer_value));
    }
    if (darwin_level == darwin::network::protocol_ipv6 &&
        (darwin_option == darwin::network::ipv6_unicast_hops ||
            darwin_option == darwin::network::ipv6_multicast_hops ||
            darwin_option == darwin::network::ipv6_multicast_loop)) {
        if (value.empty())
            return darwin_error_result(22); // EINVAL
        const auto host_option =
            darwin_option == darwin::network::ipv6_unicast_hops
                ? IPV6_UNICAST_HOPS
            : darwin_option == darwin::network::ipv6_multicast_hops
                ? IPV6_MULTICAST_HOPS
                : IPV6_MULTICAST_LOOP;
        return set_host_option(
            IPPROTO_IPV6, host_option, &integer_value, sizeof(integer_value));
    }
    if (darwin_level == darwin::network::protocol_ipv6 &&
        darwin_option == darwin::network::ipv6_multicast_interface) {
        const auto guest_index = read_u32(value);
        if (!guest_index)
            return darwin_error_result(22); // EINVAL
        const auto interface = selected_interface(AF_INET6, *guest_index == 1);
        if (!interface)
            return darwin_error_result(49); // EADDRNOTAVAIL
        const auto host_index = interface->index;
        return set_host_option(
            IPPROTO_IPV6, IPV6_MULTICAST_IF, &host_index, sizeof(host_index));
    }
    if (darwin_level == darwin::network::protocol_ipv6 &&
        (darwin_option == darwin::network::ipv6_join_group ||
            darwin_option == darwin::network::ipv6_leave_group)) {
        if (value.size() < darwin::network::ipv6_membership_size) {
            return darwin_error_result(22); // EINVAL
        }
        const auto guest_index = read_u32(value.subspan(16));
        if (!guest_index)
            return darwin_error_result(22); // EINVAL
        const auto interface = selected_interface(AF_INET6, *guest_index == 1);
        if (!interface)
            return darwin_error_result(49); // EADDRNOTAVAIL
        ipv6_mreq membership { };
        std::memcpy(&membership.ipv6mr_multiaddr, value.data(),
            sizeof(membership.ipv6mr_multiaddr));
        membership.ipv6mr_interface = interface->index;
        const auto host_option =
            darwin_option == darwin::network::ipv6_join_group
                ? IPV6_JOIN_GROUP
                : IPV6_LEAVE_GROUP;
        return set_host_option(
            IPPROTO_IPV6, host_option, &membership, sizeof(membership));
    }
    return { };
}

HostSocketResult HostSocket::local_address() const
{
    sockaddr_storage address { };
    socklen_t length = sizeof(address);
    const auto result = ::getsockname(
        descriptor_, reinterpret_cast<sockaddr*>(&address), &length);
    auto output = socket_address_result(result, errno, address, length);
    if (output.status == HostSocketStatus::Success &&
        presents_virtual_local_ipv4_address_ && output.address.size() >= 8) {
        std::copy(virtual_network::client_address.begin(),
            virtual_network::client_address.end(), output.address.begin() + 4);
    }
    return output;
}

HostSocketResult HostSocket::peer_address() const
{
    if (presented_peer_address_) {
        HostSocketResult result;
        result.address = *presented_peer_address_;
        return result;
    }
    sockaddr_storage address { };
    socklen_t length = sizeof(address);
    const auto result = ::getpeername(
        descriptor_, reinterpret_cast<sockaddr*>(&address), &length);
    return socket_address_result(result, errno, address, length);
}

HostSocketResult HostSocket::pending_bytes() const
{
    int count = 0;
    if (::ioctl(descriptor_, FIONREAD, &count) != 0) {
        return error_result(errno);
    }
    HostSocketResult result;
    result.transferred = static_cast<std::size_t>(std::max(count, 0));
    return result;
}

HostSocketResult HostSocket::socket_error()
{
    int socket_error = 0;
    socklen_t size = sizeof(socket_error);
    if (::getsockopt(descriptor_, SOL_SOCKET, SO_ERROR, &socket_error, &size) !=
        0) {
        return error_result(errno);
    }
    HostSocketResult result;
    result.darwin_error = translate_error(socket_error);
    if (darwin_type_ == darwin_socket_stream &&
        stream_state_.load(std::memory_order_relaxed) ==
            StreamState::Connecting) {
        stream_state_.store(
            socket_error == 0 ? StreamState::Connected : StreamState::Initial,
            std::memory_order_relaxed);
    }
    return result;
}

HostSocketResult HostSocket::shutdown(std::uint32_t how)
{
    if (how > 2) {
        return darwin_error_result(darwin_error_invalid_argument);
    }
    return ::shutdown(descriptor_, static_cast<int>(how)) == 0
               ? HostSocketResult { }
               : error_result(errno);
}

bool HostSocket::readable() const
{
    // Linux projects POLLHUP on a never-connected TCP stream. XNU does not
    // consider that initial connection-required state readable.
    if (darwin_type_ == darwin_socket_stream &&
        stream_state_.load(std::memory_order_relaxed) == StreamState::Initial) {
        return false;
    }
    pollfd descriptor { descriptor_, POLLIN, 0 };
    return ::poll(&descriptor, 1, 0) > 0 &&
           (descriptor.revents & (POLLIN | POLLHUP | POLLERR)) != 0;
}

bool HostSocket::writable() const
{
    if (darwin_type_ == darwin_socket_stream) {
        const auto state = stream_state_.load(std::memory_order_relaxed);
        if (state == StreamState::Initial || state == StreamState::Listening)
            return false;
    }
    pollfd descriptor { descriptor_, POLLOUT, 0 };
    return ::poll(&descriptor, 1, 0) > 0 &&
           (descriptor.revents & (POLLOUT | POLLHUP | POLLERR)) != 0;
}

} // namespace shade
