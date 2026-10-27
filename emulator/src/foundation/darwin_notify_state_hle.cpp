// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle bootstrap-sensitive guest libnotify state calls with native
// fallback.

#include "foundation/darwin_notify_state_hle.hpp"

#include <algorithm>
#include <utility>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/userland_hle.hpp"

namespace emulator {
namespace {

    constexpr std::string_view libsystem_notify_image {
        "/usr/lib/system/libsystem_notify.dylib"
    };
    constexpr std::uint32_t notify_status_failed = 1'000'000U;

}

DarwinNotifyStateHle::DarwinNotifyStateHle(UserlandHleRegistry& registry)
{
    registry.register_function(std::string { libsystem_notify_image },
        "__notify_lib_init",
        [this](UserlandHleCall& call) { initialize(call); });
    registry.register_function(std::string { libsystem_notify_image },
        "_notify_register_mach_port",
        [this](UserlandHleCall& call) { register_mach_port(call); });
    registry.register_function(std::string { libsystem_notify_image },
        "_notify_register_check",
        [this](UserlandHleCall& call) { register_check(call); });
    registry.register_function(std::string { libsystem_notify_image },
        "_notify_check", [this](UserlandHleCall& call) { check(call); });
    registry.register_function(std::string { libsystem_notify_image },
        "_notify_get_state",
        [this](UserlandHleCall& call) { get_state(call); });
    registry.register_function(std::string { libsystem_notify_image },
        "_notify_cancel", [this](UserlandHleCall& call) { cancel(call); });
    registry.register_function(std::string { libsystem_notify_image },
        "_notify_post", [this](UserlandHleCall& call) { post(call); });
}

DarwinNotifyStateHle::~DarwinNotifyStateHle() { reset(); }

void DarwinNotifyStateHle::set_abi(DarwinNotifyStateAbi abi)
{
    std::lock_guard lock { mutex_ };
    abi_ = abi;
}

void DarwinNotifyStateHle::set_native_server_ready_query(
    NativeServerReadyQuery query)
{
    std::lock_guard lock { mutex_ };
    native_server_ready_query_ = std::move(query);
}

void DarwinNotifyStateHle::set_native_server_provider_query(
    NativeServerProviderQuery query)
{
    std::lock_guard lock { mutex_ };
    native_server_provider_query_ = std::move(query);
}

void DarwinNotifyStateHle::set_provider(
    std::string name, StateProvider provider)
{
    if (name.empty() || !provider)
        return;
    std::lock_guard lock { mutex_ };
    providers_.insert_or_assign(std::move(name), std::move(provider));
}

void DarwinNotifyStateHle::set_notification_dispatcher(
    NotificationDispatcher dispatcher)
{
    std::lock_guard lock { mutex_ };
    dispatcher_ = std::move(dispatcher);
}

void DarwinNotifyStateHle::set_post_observer(PostObserver observer)
{
    std::lock_guard lock { mutex_ };
    post_observer_ = std::move(observer);
}

void DarwinNotifyStateHle::inherit_state(const DarwinNotifyStateHle& parent)
{
    std::scoped_lock lock { mutex_, parent.mutex_ };
    bus_ = parent.bus_;
}

void DarwinNotifyStateHle::publish(std::string_view name)
{
    std::vector<std::function<void()>> notifications;
    {
        std::lock_guard lock { bus_->mutex };
        for (const auto& [key, registration] : bus_->registrations) {
            static_cast<void>(key);
            if (registration.name == name && registration.notify)
                notifications.push_back(registration.notify);
        }
    }
    for (const auto& notify : notifications)
        notify();
}

void DarwinNotifyStateHle::observe_post(
    std::string_view name, std::uint32_t process_id)
{
    PostObserver observer;
    {
        std::lock_guard lock { mutex_ };
        observer = post_observer_;
    }
    if (observer)
        observer(name, process_id);
}

void DarwinNotifyStateHle::reset()
{
    std::scoped_lock lock { mutex_, bus_->mutex };
    for (const auto& key : owned_registrations_)
        bus_->registrations.erase(key);
    owned_registrations_.clear();
    token_names_.clear();
    virtual_tokens_.clear();
    next_virtual_token_ = 0x4000'0000U;
}

const std::array<snapshot::Member<DarwinNotifyStateHle>, 7>&
DarwinNotifyStateHle::snapshot_members()
{
    static constexpr std::array<snapshot::Member<DarwinNotifyStateHle>, 7> members {{
        {"notify.providers_",
            [](const DarwinNotifyStateHle& notify) {
                return snapshot::is_default(notify.providers_);
            },
            [](snapshot::Writer& out, const DarwinNotifyStateHle& notify) {
                std::vector<std::string> provider_names;
                for (const auto& [name, provider] : notify.providers_) {
                    static_cast<void>(provider);
                    provider_names.push_back(name);
                }
                snapshot::save(out, provider_names);
            },
            [](snapshot::Reader& in, DarwinNotifyStateHle& notify) {
                std::vector<std::string> provider_names;
                snapshot::load(in, provider_names);
                if (!std::equal(provider_names.begin(), provider_names.end(),
                        notify.providers_.begin(), notify.providers_.end(),
                        [](const std::string& name, const auto& provider) {
                            return name == provider.first;
                        })) {
                    throw snapshot::FormatError { "notify providers differ from the wiring" };
                }
            }},
        {"notify.abi_",
            [](const DarwinNotifyStateHle& notify) { return snapshot::is_default(notify.abi_); },
            [](snapshot::Writer& out, const DarwinNotifyStateHle& notify) {
                snapshot::save(out, notify.abi_);
            },
            [](snapshot::Reader& in, DarwinNotifyStateHle& notify) {
                DarwinNotifyStateAbi abi { };
                snapshot::load(in, abi);
                if (abi != notify.abi_)
                    throw snapshot::FormatError { "notify ABI differs from the wiring" };
            }},
        {"notify.token_names_",
            [](const DarwinNotifyStateHle& notify) {
                return snapshot::is_default(notify.token_names_);
            },
            [](snapshot::Writer& out, const DarwinNotifyStateHle& notify) {
                snapshot::save(out, notify.token_names_);
            },
            [](snapshot::Reader& in, DarwinNotifyStateHle& notify) {
                snapshot::load(in, notify.token_names_);
            }},
        {"notify.virtual_tokens_",
            [](const DarwinNotifyStateHle& notify) {
                return snapshot::is_default(notify.virtual_tokens_);
            },
            [](snapshot::Writer& out, const DarwinNotifyStateHle& notify) {
                snapshot::save(out, notify.virtual_tokens_);
            },
            [](snapshot::Reader& in, DarwinNotifyStateHle& notify) {
                snapshot::load(in, notify.virtual_tokens_);
            }},
        {"notify.next_virtual_token_",
            [](const DarwinNotifyStateHle& notify) {
                return snapshot::is_default(notify.next_virtual_token_);
            },
            [](snapshot::Writer& out, const DarwinNotifyStateHle& notify) {
                snapshot::save(out, notify.next_virtual_token_);
            },
            [](snapshot::Reader& in, DarwinNotifyStateHle& notify) {
                snapshot::load(in, notify.next_virtual_token_);
            }},
        {"notify.owned_registrations_",
            [](const DarwinNotifyStateHle& notify) {
                return snapshot::is_default(notify.owned_registrations_);
            },
            [](snapshot::Writer& out, const DarwinNotifyStateHle& notify) {
                snapshot::save(out, notify.owned_registrations_);
            },
            [](snapshot::Reader& in, DarwinNotifyStateHle& notify) {
                for (const auto& key : notify.owned_registrations_)
                    notify.bus_->registrations.erase(key);
                snapshot::load(in, notify.owned_registrations_);
            }},
        {"bus.registrations",
            [](const DarwinNotifyStateHle& notify) {
                return !notify.bus_ || snapshot::is_default(notify.bus_->registrations);
            },
            [](snapshot::Writer& out, const DarwinNotifyStateHle& notify) {
                snapshot::save(out, static_cast<std::uint64_t>(notify.bus_->registrations.size()));
                for (const auto& [key, registration] : notify.bus_->registrations) {
                    if (!notify.owned_registrations_.contains(key))
                        throw snapshot::RefusedError { "notify.foreign_registration" };
                    snapshot::save(out, key);
                    snapshot::save(out, registration.name);
                    snapshot::save(out, registration.port_name);
                }
            },
            [](snapshot::Reader& in, DarwinNotifyStateHle& notify) {
                std::uint64_t registration_count { };
                snapshot::load(in, registration_count);
                std::vector<std::pair<RegistrationKey, PublishedRegistration>> published;
                for (std::uint64_t index = 0; index < registration_count; ++index) {
                    RegistrationKey key { };
                    PublishedRegistration registration;
                    snapshot::load(in, key);
                    snapshot::load(in, registration.name);
                    snapshot::load(in, registration.port_name);
                    if (!notify.owned_registrations_.contains(key))
                        throw snapshot::FormatError { "notify registration is not owned" };
                    published.emplace_back(key, std::move(registration));
                }
                if (!published.empty() && !notify.dispatcher_)
                    throw snapshot::FormatError { "notify registrations need a dispatcher" };
                for (auto& [key, registration] : published) {
                    notify.publish_registration_locked(std::move(registration.name), key.first,
                        registration.port_name, key.second);
                }
            }},
    }};
    return members;
}

void DarwinNotifyStateHle::save(snapshot::Writer& out) const
{
    std::scoped_lock lock { mutex_, bus_->mutex };
    snapshot::save_members(out, *this, snapshot_members());
}

void DarwinNotifyStateHle::load(snapshot::Reader& in)
{
    std::scoped_lock lock { mutex_, bus_->mutex };
    snapshot::restore_members(in, *this, snapshot_members());
}

void DarwinNotifyStateHle::initialize(UserlandHleCall& call)
{
    NativeServerProviderQuery provider_query;
    {
        std::lock_guard lock { mutex_ };
        provider_query = native_server_provider_query_;
    }
    if (!native_server_ready() && provider_query && provider_query()) {
        call.set_return(notify_status_failed);
        return;
    }
    call.resume_original_persistently();
}

void DarwinNotifyStateHle::post(UserlandHleCall& call)
{
    if (const auto name = call.string_argument(0))
        observe_post(*name, call.process_id());
    call.resume_original_persistently();
}

void DarwinNotifyStateHle::register_mach_port(UserlandHleCall& call)
{
    const auto name = call.string_argument(0);
    const auto port_address = call.argument(1);
    const auto token_address = call.argument(3);
    if (!name || port_address == 0 || token_address == 0) {
        call.resume_original_persistently();
        return;
    }
    bool has_provider = false;
    bool bootstrap_aware = false;
    {
        std::lock_guard lock { mutex_ };
        has_provider = providers_.contains(*name);
        bootstrap_aware =
            abi_ == DarwinNotifyStateAbi::BootstrapAwareServerTokens;
    }
    const auto server_ready = native_server_ready();
    if (bootstrap_aware && !server_ready) {
        call.set_return(notify_status_failed);
        return;
    }
    if (!has_provider) {
        call.resume_original_persistently();
        return;
    }
    call.resume_original_persistently(
        [this, name = *name, port_address, token_address](
            UserlandHleCall& completed) {
            if (completed.argument(0) != 0)
                return;
            const auto port_name = completed.memory().read32(port_address);
            const auto token = completed.memory().read32(token_address);
            if (port_name && token)
                record_registration(
                    name, *token, completed.process_id(), *port_name);
        });
}

void DarwinNotifyStateHle::register_check(UserlandHleCall& call)
{
    const auto name = call.string_argument(0);
    const auto token_address = call.argument(1);
    if (!name || token_address == 0) {
        call.resume_original_persistently();
        return;
    }
    bool has_provider = false;
    bool bootstrap_aware = false;
    {
        std::lock_guard lock { mutex_ };
        has_provider = providers_.contains(*name);
        bootstrap_aware =
            abi_ == DarwinNotifyStateAbi::BootstrapAwareServerTokens;
    }
    const auto server_ready = native_server_ready();
    if (bootstrap_aware && !server_ready) {
        if (!has_provider) {
            call.set_return(notify_status_failed);
            return;
        }
        const auto token = allocate_virtual_token();
        if (!call.write32(token_address, token)) {
            std::lock_guard lock { mutex_ };
            virtual_tokens_.erase(token);
            call.set_return(notify_status_failed);
            return;
        }
        record_registration(*name, token, call.process_id(), 0);
        call.set_return(0);
        return;
    }
    if (!has_provider) {
        call.resume_original_persistently();
        return;
    }
    call.resume_original_persistently(
        [this, name = *name, token_address](UserlandHleCall& completed) {
            if (completed.argument(0) != 0)
                return;
            const auto token = completed.memory().read32(token_address);
            if (token)
                record_registration(name, *token, completed.process_id(), 0);
        });
}

void DarwinNotifyStateHle::get_state(UserlandHleCall& call)
{
    const auto token = call.argument(0);
    const auto state_address = call.argument(1);
    StateProvider provider;
    bool virtual_token = false;
    {
        std::lock_guard lock { mutex_ };
        const auto registered = token_names_.find(token);
        if (registered != token_names_.end()) {
            const auto found = providers_.find(registered->second);
            if (found != providers_.end())
                provider = found->second;
        }
        virtual_token = virtual_tokens_.contains(token);
    }
    if (virtual_token) {
        const auto state = provider ? provider() : 0U;
        call.set_return(
            state_address != 0 &&
                    call.write32(
                        state_address, static_cast<std::uint32_t>(state)) &&
                    call.write32(state_address + sizeof(std::uint32_t),
                        static_cast<std::uint32_t>(state >> 32U))
                ? 0U
                : notify_status_failed);
        return;
    }
    if (!provider || state_address == 0) {
        call.resume_original_persistently();
        return;
    }

    call.resume_original_persistently(
        [provider = std::move(provider), state_address](
            UserlandHleCall& completed) {
            const auto state = provider();
            if (!completed.write32(
                    state_address, static_cast<std::uint32_t>(state)) ||
                !completed.write32(state_address + sizeof(std::uint32_t),
                    static_cast<std::uint32_t>(state >> 32U))) {
                return;
            }
            completed.set_return(0);
        });
}

void DarwinNotifyStateHle::check(UserlandHleCall& call)
{
    const auto token = call.argument(0);
    const auto changed_address = call.argument(1);
    bool virtual_token = false;
    {
        std::lock_guard lock { mutex_ };
        virtual_token = virtual_tokens_.contains(token);
    }
    if (!virtual_token) {
        call.resume_original_persistently();
        return;
    }
    call.set_return(
        changed_address != 0 && call.write32(changed_address, 0U)
            ? 0U
            : notify_status_failed);
}

void DarwinNotifyStateHle::cancel(UserlandHleCall& call)
{
    const auto token = call.argument(0);
    const auto key = RegistrationKey { call.process_id(), token };
    bool virtual_token = false;
    {
        std::scoped_lock lock { mutex_, bus_->mutex };
        virtual_token = virtual_tokens_.erase(token) != 0;
        token_names_.erase(token);
        owned_registrations_.erase(key);
        bus_->registrations.erase(key);
    }
    if (virtual_token) {
        call.set_return(0);
        return;
    }
    call.resume_original_persistently();
}

void DarwinNotifyStateHle::record_registration(std::string name,
    std::uint32_t token, std::uint32_t process_id, std::uint32_t port_name)
{
    std::scoped_lock lock { mutex_, bus_->mutex };
    token_names_.insert_or_assign(token, name);
    if (port_name == 0 || !dispatcher_)
        return;
    publish_registration_locked(std::move(name), process_id, port_name, token);
    owned_registrations_.insert(RegistrationKey { process_id, token });
}

void DarwinNotifyStateHle::publish_registration_locked(std::string name,
    std::uint32_t process_id, std::uint32_t port_name, std::uint32_t token)
{
    const auto dispatcher = dispatcher_;
    bus_->registrations.insert_or_assign(
        RegistrationKey { process_id, token },
        PublishedRegistration { std::move(name), port_name,
            [dispatcher, process_id, port_name, token] {
                dispatcher(process_id, port_name, token);
            } });
}

std::uint32_t DarwinNotifyStateHle::allocate_virtual_token()
{
    std::lock_guard lock { mutex_ };
    std::uint32_t token { };
    do {
        token = next_virtual_token_++;
    } while (token == 0 || token_names_.contains(token));
    virtual_tokens_.insert(token);
    return token;
}

bool DarwinNotifyStateHle::native_server_ready() const
{
    NativeServerReadyQuery query;
    {
        std::lock_guard lock { mutex_ };
        query = native_server_ready_query_;
    }
    return !query || query();
}

}
