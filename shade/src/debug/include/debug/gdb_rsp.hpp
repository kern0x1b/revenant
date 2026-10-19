// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement the GDB remote serial protocol and its emulator target
// interface.

#pragma once

#include <array>
#include <compare>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade {

class Output;

struct GdbThreadId {
    std::uint32_t process { };
    std::uint32_t thread { };

    auto operator<=>(const GdbThreadId&) const = default;
};

inline constexpr std::size_t gdb_arm_core_register_count = 17;
inline constexpr std::size_t gdb_arm_general_register_count = 16;
inline constexpr std::size_t gdb_arm_pc_register = 15;
inline constexpr std::size_t gdb_arm_cpsr_register = 16;
namespace gdb_signal {
    inline constexpr std::uint8_t interrupt = 2;
    inline constexpr std::uint8_t illegal_instruction = 4;
    inline constexpr std::uint8_t trap = 5;
    inline constexpr std::uint8_t segmentation_fault = 11;
} // namespace gdb_signal
using GdbArmRegisters = std::array<std::uint32_t, gdb_arm_core_register_count>;

class GdbTarget {
public:
    virtual ~GdbTarget() = default;

    [[nodiscard]] virtual std::vector<GdbThreadId> threads() const = 0;
    [[nodiscard]] virtual std::optional<GdbThreadId> current_thread() const = 0;
    [[nodiscard]] virtual std::optional<std::string> thread_extra_info(
        GdbThreadId thread) const
    {
        static_cast<void>(thread);
        return std::nullopt;
    }
    [[nodiscard]] virtual std::optional<GdbArmRegisters> read_registers(
        GdbThreadId thread) const = 0;
    virtual bool write_registers(
        GdbThreadId thread, const GdbArmRegisters& registers) = 0;
    [[nodiscard]] virtual std::optional<std::vector<std::byte>> read_memory(
        GdbThreadId thread, std::uint32_t address, std::size_t size) const = 0;
    virtual bool write_memory(GdbThreadId thread, std::uint32_t address,
        std::span<const std::byte> bytes) = 0;
    virtual bool insert_software_breakpoint(
        GdbThreadId thread, std::uint32_t address, std::size_t kind) = 0;
    virtual bool remove_software_breakpoint(
        GdbThreadId thread, std::uint32_t address, std::size_t kind) = 0;
};

enum class GdbResumeKind {
    Continue,
    Step,
    Detach,
    Kill,
};

struct GdbResumeRequest {
    GdbResumeKind kind { GdbResumeKind::Continue };
    std::optional<GdbThreadId> thread;
};

struct GdbPacketResult {
    std::optional<std::string> response;
    std::optional<GdbResumeRequest> resume;
    bool enable_no_ack { };
};

class GdbRspProtocol {
public:
    void set_stop(GdbThreadId thread, std::uint8_t signal = gdb_signal::trap);
    [[nodiscard]] GdbPacketResult handle(
        std::string_view packet, GdbTarget& target);
    [[nodiscard]] std::string stop_reply() const;

private:
    [[nodiscard]] std::optional<GdbThreadId> resolve_general_thread(
        const GdbTarget& target) const;

    std::optional<GdbThreadId> general_thread_;
    std::optional<GdbThreadId> continue_thread_;
    std::optional<GdbThreadId> stop_thread_;
    std::uint8_t stop_signal_ { gdb_signal::trap };
};

class GdbRemoteServer {
public:
    GdbRemoteServer(std::uint16_t port, Output& output);
    ~GdbRemoteServer();
    GdbRemoteServer(const GdbRemoteServer&) = delete;
    GdbRemoteServer& operator=(const GdbRemoteServer&) = delete;

    void listen_and_accept();
    [[nodiscard]] GdbResumeRequest command_loop(GdbTarget& target,
        GdbThreadId stopped_thread, std::uint8_t signal = gdb_signal::trap,
        bool announce_stop = false);
    [[nodiscard]] bool poll_interrupt();
    void detach();

private:
    [[nodiscard]] std::optional<char> read_byte(bool blocking);
    [[nodiscard]] std::optional<std::string> read_packet();
    bool send_all(std::string_view bytes);
    bool send_packet(std::string_view payload);
    void close_client();

    std::uint16_t port_ { };
    Output& output_;
    int listen_fd_ { -1 };
    int client_fd_ { -1 };
    bool no_ack_ { };
    std::vector<char> buffered_input_;
    GdbRspProtocol protocol_;
};

} // namespace shade
