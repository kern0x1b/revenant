// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement the GDB remote serial protocol and its emulator target
// interface.

#include "debug/gdb_rsp.hpp"

#include "foundation/output.hpp"

#include <algorithm>
#include <array>
#include <cerrno>
#include <charconv>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <system_error>
#include <utility>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

namespace shade {
namespace {

    constexpr std::size_t maximum_gdb_memory_transfer = 1024U * 1024U;
    constexpr std::string_view target_xml {
        R"(<?xml version="1.0"?>
<!DOCTYPE target SYSTEM "gdb-target.dtd">
<target version="1.0">
  <architecture>arm</architecture>
  <feature name="org.gnu.gdb.arm.core">
    <reg name="r0" bitsize="32" type="uint32"/>
    <reg name="r1" bitsize="32" type="uint32"/>
    <reg name="r2" bitsize="32" type="uint32"/>
    <reg name="r3" bitsize="32" type="uint32"/>
    <reg name="r4" bitsize="32" type="uint32"/>
    <reg name="r5" bitsize="32" type="uint32"/>
    <reg name="r6" bitsize="32" type="uint32"/>
    <reg name="r7" bitsize="32" type="uint32"/>
    <reg name="r8" bitsize="32" type="uint32"/>
    <reg name="r9" bitsize="32" type="uint32"/>
    <reg name="r10" bitsize="32" type="uint32"/>
    <reg name="r11" bitsize="32" type="uint32"/>
    <reg name="r12" bitsize="32" type="uint32"/>
    <reg name="sp" bitsize="32" type="data_ptr"/>
    <reg name="lr" bitsize="32" type="code_ptr"/>
    <reg name="pc" bitsize="32" type="code_ptr"/>
    <reg name="cpsr" bitsize="32" type="uint32"/>
  </feature>
</target>)"
    };

    constexpr char hex_digit(unsigned value)
    {
        return "0123456789abcdef"[value & 0xfU];
    }

    std::optional<unsigned> decode_hex_digit(char value)
    {
        if (value >= '0' && value <= '9')
            return static_cast<unsigned>(value - '0');
        if (value >= 'a' && value <= 'f')
            return static_cast<unsigned>(value - 'a' + 10);
        if (value >= 'A' && value <= 'F')
            return static_cast<unsigned>(value - 'A' + 10);
        return std::nullopt;
    }

    template <typename T> std::optional<T> parse_hex(std::string_view text)
    {
        if (text.empty())
            return std::nullopt;
        T value { };
        const auto [end, error] =
            std::from_chars(text.data(), text.data() + text.size(), value, 16);
        if (error != std::errc { } || end != text.data() + text.size()) {
            return std::nullopt;
        }
        return value;
    }

    std::string encode_u32(std::uint32_t value)
    {
        std::string result;
        result.reserve(8);
        for (unsigned byte = 0; byte < 4; ++byte) {
            const auto current = static_cast<unsigned>(value >> (byte * 8U));
            result.push_back(hex_digit(current >> 4U));
            result.push_back(hex_digit(current));
        }
        return result;
    }

    std::optional<std::uint32_t> decode_u32(std::string_view text)
    {
        if (text.size() != 8)
            return std::nullopt;
        std::uint32_t result = 0;
        for (unsigned byte = 0; byte < 4; ++byte) {
            const auto high = decode_hex_digit(text[byte * 2U]);
            const auto low = decode_hex_digit(text[byte * 2U + 1U]);
            if (!high || !low)
                return std::nullopt;
            result |= static_cast<std::uint32_t>((*high << 4U) | *low)
                      << (byte * 8U);
        }
        return result;
    }

    std::string encode_bytes(std::span<const std::byte> bytes)
    {
        std::string result;
        result.reserve(bytes.size() * 2U);
        for (const auto byte : bytes) {
            const auto value = std::to_integer<unsigned>(byte);
            result.push_back(hex_digit(value >> 4U));
            result.push_back(hex_digit(value));
        }
        return result;
    }

    std::optional<std::vector<std::byte>> decode_bytes(std::string_view text)
    {
        if ((text.size() & 1U) != 0)
            return std::nullopt;
        std::vector<std::byte> result;
        result.reserve(text.size() / 2U);
        for (std::size_t index = 0; index < text.size(); index += 2U) {
            const auto high = decode_hex_digit(text[index]);
            const auto low = decode_hex_digit(text[index + 1U]);
            if (!high || !low)
                return std::nullopt;
            result.push_back(static_cast<std::byte>((*high << 4U) | *low));
        }
        return result;
    }

    std::string encode_thread_id(GdbThreadId id)
    {
        std::array<char, 32> buffer { };
        const auto process = std::to_chars(
            buffer.data() + 1, buffer.data() + buffer.size(), id.process, 16);
        if (process.ec != std::errc { })
            return { };
        buffer[0] = 'p';
        *process.ptr = '.';
        const auto thread = std::to_chars(
            process.ptr + 1, buffer.data() + buffer.size(), id.thread, 16);
        if (thread.ec != std::errc { })
            return { };
        return { buffer.data(), thread.ptr };
    }

    std::optional<GdbThreadId> parse_thread_id(
        std::string_view text, std::optional<std::uint32_t> default_process)
    {
        if (text.starts_with('p')) {
            const auto separator = text.find('.');
            if (separator == std::string_view::npos)
                return std::nullopt;
            const auto process =
                parse_hex<std::uint32_t>(text.substr(1, separator - 1));
            const auto thread =
                parse_hex<std::uint32_t>(text.substr(separator + 1));
            if (!process || !thread || *process == 0 || *thread == 0)
                return std::nullopt;
            return GdbThreadId { *process, *thread };
        }
        const auto thread = parse_hex<std::uint32_t>(text);
        if (!thread || *thread == 0 || !default_process)
            return std::nullopt;
        return GdbThreadId { *default_process, *thread };
    }

    bool has_thread(const GdbTarget& target, GdbThreadId id)
    {
        const auto threads = target.threads();
        return std::find(threads.begin(), threads.end(), id) != threads.end();
    }

    std::optional<std::pair<std::uint32_t, std::size_t>> parse_address_size(
        std::string_view text)
    {
        const auto comma = text.find(',');
        if (comma == std::string_view::npos)
            return std::nullopt;
        const auto address = parse_hex<std::uint32_t>(text.substr(0, comma));
        const auto size = parse_hex<std::size_t>(text.substr(comma + 1));
        if (!address || !size || *size > maximum_gdb_memory_transfer ||
            (*size != 0 &&
                *size - 1U >
                    std::numeric_limits<std::uint32_t>::max() - *address)) {
            return std::nullopt;
        }
        return std::pair { *address, *size };
    }

    std::string encode_ascii(std::string_view text)
    {
        return encode_bytes(
            std::as_bytes(std::span { text.data(), text.size() }));
    }

} // namespace

void GdbRspProtocol::set_stop(GdbThreadId thread, std::uint8_t signal)
{
    stop_thread_ = thread;
    stop_signal_ = signal;
    if (!general_thread_)
        general_thread_ = thread;
}

std::string GdbRspProtocol::stop_reply() const
{
    std::string result { "T" };
    result.push_back(hex_digit(stop_signal_ >> 4U));
    result.push_back(hex_digit(stop_signal_));
    if (stop_thread_) {
        result += "thread:";
        result += encode_thread_id(*stop_thread_);
        result.push_back(';');
    }
    return result;
}

std::optional<GdbThreadId> GdbRspProtocol::resolve_general_thread(
    const GdbTarget& target) const
{
    if (general_thread_ && has_thread(target, *general_thread_)) {
        return general_thread_;
    }
    if (stop_thread_ && has_thread(target, *stop_thread_))
        return stop_thread_;
    const auto current = target.current_thread();
    if (current && has_thread(target, *current))
        return current;
    const auto threads = target.threads();
    return threads.empty() ? std::nullopt
                           : std::optional<GdbThreadId> { threads.front() };
}

GdbPacketResult GdbRspProtocol::handle(
    std::string_view packet, GdbTarget& target)
{
    if (packet == "?")
        return { stop_reply(), std::nullopt, false };
    if (packet.starts_with("qSupported")) {
        return { "PacketSize=4000;QStartNoAckMode+;multiprocess+;"
                 "qXfer:features:read+;vContSupported+;swbreak+",
            std::nullopt, false };
    }
    if (packet == "QStartNoAckMode")
        return { "OK", std::nullopt, true };
    if (packet == "qAttached")
        return { "1", std::nullopt, false };
    if (packet == "qC") {
        const auto thread = resolve_general_thread(target);
        return { thread ? "QC" + encode_thread_id(*thread) : "E01",
            std::nullopt, false };
    }
    if (packet == "qfThreadInfo") {
        const auto threads = target.threads();
        if (threads.empty())
            return { "l", std::nullopt, false };
        std::string response { "m" };
        for (std::size_t index = 0; index < threads.size(); ++index) {
            if (index != 0)
                response.push_back(',');
            response += encode_thread_id(threads[index]);
        }
        return { std::move(response), std::nullopt, false };
    }
    if (packet == "qsThreadInfo") {
        return { "l", std::nullopt, false };
    }
    if (packet.starts_with("qThreadExtraInfo,")) {
        const auto fallback = resolve_general_thread(target);
        const auto thread = parse_thread_id(packet.substr(17),
            fallback ? std::optional { fallback->process } : std::nullopt);
        if (!thread || !has_thread(target, *thread))
            return { "E01", std::nullopt, false };
        const auto fallback_description =
            "pid " + std::to_string(thread->process) + " thread " +
            std::to_string(thread->thread);
        return { encode_ascii(target.thread_extra_info(*thread).value_or(
                     fallback_description)),
            std::nullopt, false };
    }
    if (packet.starts_with("qXfer:features:read:target.xml:")) {
        const auto request = parse_address_size(packet.substr(31));
        if (!request)
            return { "E01", std::nullopt, false };
        const auto [offset, requested] = *request;
        if (offset >= target_xml.size())
            return { "l", std::nullopt, false };
        const auto size = std::min(requested, target_xml.size() - offset);
        const auto marker = offset + size < target_xml.size() ? 'm' : 'l';
        return { std::string { marker } +
                     std::string { target_xml.substr(offset, size) },
            std::nullopt, false };
    }
    if (packet == "qOffsets")
        return { "Text=0;Data=0;Bss=0", std::nullopt, false };
    if (packet == "qSymbol::" || packet == "QThreadEvents:1" ||
        packet == "QThreadEvents:0" || packet == "!") {
        return { "OK", std::nullopt, false };
    }
    if (packet == "qTStatus" || packet.starts_with("qRcmd,")) {
        return { "", std::nullopt, false };
    }
    if (packet.starts_with('H') && packet.size() >= 3) {
        const auto operation = packet[1];
        const auto id = packet.substr(2);
        // GDB uses Hc0 before a normal all-stop `c`: thread id zero asks the
        // target to pick any thread, rather than selecting the current thread
        // as the only runnable one.  Keep both wildcard forms unscoped so the
        // guest system can schedule every process needed to service the
        // continued thread.
        if (operation == 'c' && (id == "-1" || id == "0")) {
            continue_thread_.reset();
            return { "OK", std::nullopt, false };
        }
        const auto fallback = resolve_general_thread(target);
        if (id == "0" && fallback) {
            if (operation == 'g')
                general_thread_ = fallback;
            else if (operation == 'c')
                continue_thread_ = fallback;
            else
                return { "E01", std::nullopt, false };
            return { "OK", std::nullopt, false };
        }
        const auto thread = parse_thread_id(
            id, fallback ? std::optional { fallback->process } : std::nullopt);
        if (!thread || !has_thread(target, *thread))
            return { "E01", std::nullopt, false };
        if (operation == 'g')
            general_thread_ = thread;
        else if (operation == 'c')
            continue_thread_ = thread;
        else
            return { "E01", std::nullopt, false };
        return { "OK", std::nullopt, false };
    }
    if (packet.starts_with('T')) {
        const auto fallback = resolve_general_thread(target);
        const auto thread = parse_thread_id(packet.substr(1),
            fallback ? std::optional { fallback->process } : std::nullopt);
        return { thread && has_thread(target, *thread) ? "OK" : "E01",
            std::nullopt, false };
    }

    const auto thread = resolve_general_thread(target);
    if (packet == "g") {
        if (!thread)
            return { "E01", std::nullopt, false };
        const auto registers = target.read_registers(*thread);
        if (!registers)
            return { "E01", std::nullopt, false };
        std::string response;
        response.reserve(registers->size() * 8U);
        for (const auto value : *registers)
            response += encode_u32(value);
        return { std::move(response), std::nullopt, false };
    }
    if (packet.starts_with('G')) {
        if (!thread || packet.size() != 1U + gdb_arm_core_register_count * 8U) {
            return { "E01", std::nullopt, false };
        }
        GdbArmRegisters registers { };
        for (std::size_t index = 0; index < registers.size(); ++index) {
            const auto value = decode_u32(packet.substr(1U + index * 8U, 8));
            if (!value)
                return { "E01", std::nullopt, false };
            registers[index] = *value;
        }
        return { target.write_registers(*thread, registers) ? "OK" : "E01",
            std::nullopt, false };
    }
    if (packet.starts_with('p')) {
        if (!thread)
            return { "E01", std::nullopt, false };
        const auto index = parse_hex<std::size_t>(packet.substr(1));
        const auto registers = target.read_registers(*thread);
        if (!index || !registers || *index >= registers->size()) {
            return { "E01", std::nullopt, false };
        }
        return { encode_u32((*registers)[*index]), std::nullopt, false };
    }
    if (packet.starts_with('P')) {
        if (!thread)
            return { "E01", std::nullopt, false };
        const auto equals = packet.find('=');
        if (equals == std::string_view::npos)
            return { "E01", std::nullopt, false };
        const auto index = parse_hex<std::size_t>(packet.substr(1, equals - 1));
        const auto value = decode_u32(packet.substr(equals + 1));
        auto registers = target.read_registers(*thread);
        if (!index || !value || !registers || *index >= registers->size()) {
            return { "E01", std::nullopt, false };
        }
        (*registers)[*index] = *value;
        return { target.write_registers(*thread, *registers) ? "OK" : "E01",
            std::nullopt, false };
    }
    if (packet.starts_with('m')) {
        if (!thread)
            return { "E01", std::nullopt, false };
        const auto request = parse_address_size(packet.substr(1));
        if (!request)
            return { "E01", std::nullopt, false };
        const auto bytes =
            target.read_memory(*thread, request->first, request->second);
        return { bytes ? encode_bytes(*bytes) : "E01", std::nullopt, false };
    }
    if (packet.starts_with('M')) {
        if (!thread)
            return { "E01", std::nullopt, false };
        const auto colon = packet.find(':');
        if (colon == std::string_view::npos)
            return { "E01", std::nullopt, false };
        const auto request = parse_address_size(packet.substr(1, colon - 1));
        const auto bytes = decode_bytes(packet.substr(colon + 1));
        if (!request || !bytes || bytes->size() != request->second) {
            return { "E01", std::nullopt, false };
        }
        return { target.write_memory(*thread, request->first, *bytes) ? "OK"
                                                                      : "E01",
            std::nullopt, false };
    }
    if ((packet.starts_with("Z0,") || packet.starts_with("z0,")) && thread) {
        const auto request = parse_address_size(packet.substr(3));
        if (!request)
            return { "E01", std::nullopt, false };
        const auto ok = packet[0] == 'Z'
                            ? target.insert_software_breakpoint(
                                  *thread, request->first, request->second)
                            : target.remove_software_breakpoint(
                                  *thread, request->first, request->second);
        return { ok ? "OK" : "E01", std::nullopt, false };
    }
    if (packet == "vCont?")
        return { "vCont;c;s", std::nullopt, false };
    if (packet.starts_with("vCont;")) {
        const auto action = packet.substr(6);
        if (action.starts_with('s')) {
            std::optional<GdbThreadId> selected = continue_thread_;
            if (action.size() > 2 && action[1] == ':') {
                selected = parse_thread_id(action.substr(2),
                    thread ? std::optional { thread->process } : std::nullopt);
            }
            if (!selected)
                selected = thread;
            return { std::nullopt,
                GdbResumeRequest { GdbResumeKind::Step, selected }, false };
        }
        if (action.starts_with('c')) {
            std::optional<GdbThreadId> selected = continue_thread_;
            if (action.size() > 2 && action[1] == ':') {
                selected = parse_thread_id(action.substr(2),
                    thread ? std::optional { thread->process } : std::nullopt);
            }
            return { std::nullopt,
                GdbResumeRequest { GdbResumeKind::Continue, selected }, false };
        }
        return { "E01", std::nullopt, false };
    }
    if (packet.starts_with('c') || packet.starts_with('s')) {
        const auto stepping = packet[0] == 's';
        auto selected = stepping
                            ? (continue_thread_ ? continue_thread_ : thread)
                            : continue_thread_;
        const auto register_thread = selected ? selected : thread;
        if (stepping && !selected)
            return { "E01", std::nullopt, false };
        if (packet.size() > 1) {
            const auto address = parse_hex<std::uint32_t>(packet.substr(1));
            if (!register_thread)
                return { "E01", std::nullopt, false };
            auto registers = target.read_registers(*register_thread);
            if (!address || !registers)
                return { "E01", std::nullopt, false };
            (*registers)[gdb_arm_pc_register] = *address;
            if (!target.write_registers(*register_thread, *registers)) {
                return { "E01", std::nullopt, false };
            }
        }
        return { std::nullopt,
            GdbResumeRequest {
                stepping ? GdbResumeKind::Step : GdbResumeKind::Continue,
                selected },
            false };
    }
    if (packet.starts_with('D')) {
        return { "OK", GdbResumeRequest { GdbResumeKind::Detach, std::nullopt },
            false };
    }
    if (packet == "k") {
        return { std::nullopt,
            GdbResumeRequest { GdbResumeKind::Kill, std::nullopt }, false };
    }
    return { "", std::nullopt, false };
}

GdbRemoteServer::GdbRemoteServer(std::uint16_t port, Output& output)
    : port_ { port }
    , output_ { output }
{
}

GdbRemoteServer::~GdbRemoteServer()
{
    close_client();
    if (listen_fd_ >= 0)
        ::close(listen_fd_);
}

void GdbRemoteServer::listen_and_accept()
{
    listen_fd_ = ::socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd_ < 0) {
        throw std::system_error { errno, std::generic_category(),
            "GDB socket" };
    }
    const int enabled = 1;
    static_cast<void>(::setsockopt(
        listen_fd_, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled)));
    sockaddr_in address { };
    address.sin_family = AF_INET;
    address.sin_port = htons(port_);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (::bind(listen_fd_, reinterpret_cast<const sockaddr*>(&address),
            sizeof(address)) < 0) {
        throw std::system_error { errno, std::generic_category(), "GDB bind" };
    }
    if (::listen(listen_fd_, 1) < 0) {
        throw std::system_error { errno, std::generic_category(),
            "GDB listen" };
    }
    output_.line("[gdb] listening on 127.0.0.1:" + std::to_string(port_));
    client_fd_ = ::accept(listen_fd_, nullptr, nullptr);
    if (client_fd_ < 0) {
        throw std::system_error { errno, std::generic_category(),
            "GDB accept" };
    }
    output_.line("[gdb] debugger connected");
}

std::optional<char> GdbRemoteServer::read_byte(bool blocking)
{
    if (!buffered_input_.empty()) {
        const auto value = buffered_input_.front();
        buffered_input_.erase(buffered_input_.begin());
        return value;
    }
    char value { };
    const auto flags = blocking ? 0 : MSG_DONTWAIT;
    while (true) {
        const auto count = ::recv(client_fd_, &value, 1, flags);
        if (count == 1)
            return value;
        if (count == 0)
            return std::nullopt;
        if (errno == EINTR)
            continue;
        if (!blocking && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            return std::nullopt;
        }
        return std::nullopt;
    }
}

std::optional<std::string> GdbRemoteServer::read_packet()
{
    while (client_fd_ >= 0) {
        const auto start = read_byte(true);
        if (!start)
            return std::nullopt;
        if (*start == '+' || *start == '-')
            continue;
        if (*start == '\x03')
            return std::string { "?" };
        if (*start != '$')
            continue;
        std::string payload;
        unsigned checksum = 0;
        while (true) {
            const auto value = read_byte(true);
            if (!value)
                return std::nullopt;
            if (*value == '#')
                break;
            payload.push_back(*value);
            checksum = (checksum + static_cast<unsigned char>(*value)) & 0xffU;
        }
        const auto high_character = read_byte(true);
        const auto low_character = read_byte(true);
        if (!high_character || !low_character)
            return std::nullopt;
        const auto high = decode_hex_digit(*high_character);
        const auto low = decode_hex_digit(*low_character);
        if (!high || !low || checksum != ((*high << 4U) | *low)) {
            if (!no_ack_)
                static_cast<void>(send_all("-"));
            continue;
        }
        if (!no_ack_)
            static_cast<void>(send_all("+"));
        return payload;
    }
    return std::nullopt;
}

bool GdbRemoteServer::send_all(std::string_view bytes)
{
    std::size_t sent = 0;
    while (sent < bytes.size()) {
        const auto count = ::send(
            client_fd_, bytes.data() + sent, bytes.size() - sent, MSG_NOSIGNAL);
        if (count > 0) {
            sent += static_cast<std::size_t>(count);
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        return false;
    }
    return true;
}

bool GdbRemoteServer::send_packet(std::string_view payload)
{
    unsigned checksum = 0;
    for (const auto value : payload) {
        checksum = (checksum + static_cast<unsigned char>(value)) & 0xffU;
    }
    std::string packet;
    packet.reserve(payload.size() + 4U);
    packet.push_back('$');
    packet.append(payload);
    packet.push_back('#');
    packet.push_back(hex_digit(checksum >> 4U));
    packet.push_back(hex_digit(checksum));
    return send_all(packet);
}

GdbResumeRequest GdbRemoteServer::command_loop(GdbTarget& target,
    GdbThreadId stopped_thread, std::uint8_t signal, bool announce_stop)
{
    protocol_.set_stop(stopped_thread, signal);
    if (announce_stop && !send_packet(protocol_.stop_reply())) {
        throw std::runtime_error { "failed to send GDB stop notification" };
    }
    while (true) {
        const auto packet = read_packet();
        if (!packet) {
            throw std::runtime_error { "GDB client disconnected" };
        }
        auto result = protocol_.handle(*packet, target);
        if (result.response && !send_packet(*result.response)) {
            throw std::runtime_error { "failed to send GDB response" };
        }
        if (result.enable_no_ack)
            no_ack_ = true;
        if (result.resume)
            return *result.resume;
    }
}

bool GdbRemoteServer::poll_interrupt()
{
    if (client_fd_ < 0)
        return false;
    std::array<char, 256> buffer { };
    bool interrupted = false;
    while (true) {
        const auto count =
            ::recv(client_fd_, buffer.data(), buffer.size(), MSG_DONTWAIT);
        if (count > 0) {
            for (std::ptrdiff_t index = 0; index < count; ++index) {
                if (buffer[static_cast<std::size_t>(index)] == '\x03') {
                    interrupted = true;
                } else {
                    buffered_input_.push_back(
                        buffer[static_cast<std::size_t>(index)]);
                }
            }
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        break;
    }
    return interrupted;
}

void GdbRemoteServer::close_client()
{
    if (client_fd_ >= 0) {
        ::close(client_fd_);
        client_fd_ = -1;
    }
}

void GdbRemoteServer::detach()
{
    output_.line("[gdb] debugger detached");
    close_client();
}

} // namespace shade
