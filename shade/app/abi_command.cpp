// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Report the selected firmware ABI and device capabilities from the
// CLI.

#include "app/abi_command.hpp"

#include <initializer_list>
#include <sstream>
#include <string_view>

#include "device_state/darwin_kernel_configuration.hpp"
#include "foundation/output.hpp"

namespace shade {
namespace {

    template <class Enum>
    std::string_view choice(Enum value,
        std::initializer_list<std::string_view> names)
    {
        const auto index = static_cast<std::size_t>(value);
        return index < names.size() ? names.begin()[index] : "unknown";
    }

} // namespace

void inspect_abi(const std::optional<std::filesystem::path>& rootfs,
    const std::optional<std::string>& ios_build, Output& output)
{
    if (!rootfs && !ios_build) {
        output.line("Use --rootfs DIR to inspect the firmware's "
                    "Darwin/ABI configuration.");
        output.line("Use --ios-build CODE (e.g. 9A334) to override "
                    "firmware metadata.");
        output.line("Known Darwin/ABI configurations:");
        for (const auto& entry : darwin_configurations())
            output.line("  " + std::string { entry.name });
        return;
    }
    const auto configuration = resolve_darwin_configuration(
        rootfs.value_or(std::filesystem::path { }), ios_build);
    const auto& abi = configuration.abi;
    const auto& identity = configuration.identity;
    std::ostringstream text;
    text << "abi: " << configuration.abi_name << '\n'
         << "source: " << darwin_abi_source_name(configuration.abi_source)
         << '\n' << "source-detail: " << configuration.abi_source_detail << '\n'
         << "kernel: " << identity.name << '\n'
         << "os-type: " << identity.operating_system_type << '\n'
         << "os-release: " << identity.operating_system_release << '\n'
         << "os-revision: " << identity.operating_system_revision << '\n'
         << "os-version: " << identity.build_version << '\n'
         << "kernel-version: " << identity.version << '\n'
         << "epoch: " << choice(abi.abi_epoch,
                { "unknown", "iphone-os-1", "iphone-os-2", "iphone-os-3",
                    "darwin-10", "darwin-11", "darwin-13", "later" }) << '\n'
         << "pthread: " << choice(abi.pthread_abi,
                { "mach-threads", "bsd-register-v1", "bsd-register-v1-tsd",
                    "bsd-register-v1-tsd-four-priority", "bsd-register-v2" })
         << '\n'
         << "apple80211: " << choice(abi.apple80211_ioctl,
                { "aligned-network-record", "compact-network-record" }) << '\n'
         << "io-connect-method: " << choice(abi.io_connect_method,
                { "natural32-scalar-structure", "natural32-structure-scalar",
                    "mach-vm64-structure-scalar" }) << '\n'
         << "notify-state: " << choice(abi.notify_state_abi,
                { "native-server-tokens", "bootstrap-aware-server-tokens" })
         << '\n'
         << "initial-apple-vector: " << choice(abi.initial_apple_vector_abi,
                { "keyed-path", "legacy-path" }) << '\n'
         << "shared-region: " << choice(abi.shared_region_abi,
                { "relocatable", "fixed-with-slide-info-v1" }) << '\n'
         << "mach-kernel-rpc: " << choice(abi.mach_kernel_rpc,
                { "mig-only", "direct-vm-port-traps-v1" }) << '\n'
         << "arm-commpage: " << choice(abi.arm_commpage,
                { "legacy-address", "high-address" }) << '\n'
         << "psynch: " << choice(abi.psynch_abi,
                { "unsupported", "arm32-generation-v1" }) << '\n'
         << "semaphore-wait: " << choice(abi.semaphore_wait_abi,
                { "inline-seconds32", "inline-seconds64" }) << '\n'
         << "iokit-matching: " << choice(abi.iokit_matching_rpc,
                { "plural-iterator", "inline-single-service-v1",
                    "inline-single-service-after-variable-output" }) << '\n'
         << "sandbox: " << choice(abi.sandbox_abi,
                { "natural32-arguments", "wide64-arguments" }) << '\n'
         << "mach-port-context: " << choice(abi.mach_port_context,
                { "natural32", "wide64" }) << '\n'
         << "activation-hardware-model: " << choice(
                abi.activation_hardware_model_policy,
                { "retail", "development-board" }) << '\n'
         << "mach-vm-address: " << choice(abi.mach_vm_address,
                { "natural32", "wide64" }) << '\n'
         << std::boolalpha
         << "send-sigsys: " << abi.capabilities.send_sigsys << '\n'
         << "cache-trap-grants-execute: "
         << abi.capabilities.arm_cache_trap_grants_execute << '\n';
    output.write(text.str());
}

} // namespace shade
