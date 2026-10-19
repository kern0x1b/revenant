// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle bootstrap-sensitive guest libnotify state calls with native
// fallback.

#pragma once

#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <string_view>

namespace shade {

class UserlandHleCall;
class UserlandHleRegistry;

// Some libnotify generations contact notifyd from image initializers, including
// notifyd's own image initialization. Their bootstrap-aware abi supplies
// process-local check tokens while the server is absent, then returns to the
// firmware service once notifyd has checked in.
enum class DarwinNotifyStateAbi : std::uint8_t {
    NativeServerTokens,
    BootstrapAwareServerTokens,
};

// Adapts host-backed device state to Darwin notify without replacing notifyd.
class DarwinNotifyStateHle {
public:
    using StateProvider = std::function<std::uint64_t()>;
    using NotificationDispatcher = std::function<void(std::uint32_t process_id,
        std::uint32_t port_name, std::uint32_t token)>;
    using NativeServerReadyQuery = std::function<bool()>;
    using NativeServerProviderQuery = std::function<bool()>;

    explicit DarwinNotifyStateHle(UserlandHleRegistry& registry);
    ~DarwinNotifyStateHle();

    void set_abi(DarwinNotifyStateAbi abi);
    void set_native_server_ready_query(NativeServerReadyQuery query);
    void set_native_server_provider_query(NativeServerProviderQuery query);
    void set_provider(std::string name, StateProvider provider);
    void set_notification_dispatcher(NotificationDispatcher dispatcher);
    void inherit_state(const DarwinNotifyStateHle& parent);
    void publish(std::string_view name);
    void reset();

private:
    void initialize(UserlandHleCall& call);
    void register_mach_port(UserlandHleCall& call);
    void register_check(UserlandHleCall& call);
    void check(UserlandHleCall& call);
    void get_state(UserlandHleCall& call);
    void cancel(UserlandHleCall& call);
    void record_registration(std::string name, std::uint32_t token,
        std::uint32_t process_id, std::uint32_t port_name);
    [[nodiscard]] std::uint32_t allocate_virtual_token();
    [[nodiscard]] bool native_server_ready() const;

    using RegistrationKey = std::pair<std::uint32_t, std::uint32_t>;
    struct PublishedRegistration {
        std::string name;
        std::function<void()> notify;
    };
    struct SharedBus {
        std::mutex mutex;
        std::map<RegistrationKey, PublishedRegistration> registrations;
    };

    mutable std::mutex mutex_;
    std::map<std::string, StateProvider, std::less<>> providers_;
    std::map<std::uint32_t, std::string> token_names_;
    std::set<std::uint32_t> virtual_tokens_;
    std::uint32_t next_virtual_token_ { 0x4000'0000U };
    DarwinNotifyStateAbi abi_ {
        DarwinNotifyStateAbi::NativeServerTokens
    };
    NativeServerReadyQuery native_server_ready_query_;
    NativeServerProviderQuery native_server_provider_query_;
    NotificationDispatcher dispatcher_;
    std::shared_ptr<SharedBus> bus_ { std::make_shared<SharedBus>() };
    std::set<RegistrationKey> owned_registrations_;
};

} // namespace shade
