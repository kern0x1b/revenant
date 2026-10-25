// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Own shared guest processes, descriptors, Mach objects and virtual
// device state.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_port.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/task.h

#pragma once

#include "kernel/hid_event_queue.hpp"
#include "kernel/kevent_timer.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "foundation/arm_cpu_model.hpp"
#include "foundation/application_display.hpp"
#include "kernel/baseband_device.hpp"
#include "filesystem/bsd_file_lock.hpp"
#include "graphics/core_animation_remote_abi.hpp"
#include "device_state/darwin_kernel_identity.hpp"
#include "device_state/darwin_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_psynch_runtime.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "foundation/device_display_profile.hpp"
#include "foundation/device_peripheral_profiles.hpp"
#include "foundation/device_security_profile.hpp"
#include "foundation/display_geometry.hpp"
#include "foundation/file_page_cache.hpp"
#include "foundation/snapshot_io.hpp"
#include "filesystem/hfs_metadata.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_mach_task_identity.hpp"
#include "kernel/darwin_memorystatus_abi.hpp"
#include "kernel/vnode_watch.hpp"
#include "device_state/launchd_job_catalog.hpp"
#include "mach/mach_namespace.hpp"
#include "mach/mach_port_object.hpp"
#include "foundation/touch_input.hpp"
#include "foundation/virtual_clock.hpp"
#include "network/virtual_network.hpp"
#include "network/virtual_udp.hpp"
#include "network/local_socket_credentials.hpp"
#include "mach/xnu_scheduler.hpp"

namespace emulator {

class HostSocket;
class KeyStore;
class SurfaceTransportLease;
namespace bsd::sandbox { class Extensions; }

struct ProcessContext {
    std::uint32_t pid { 1 };
    std::uint32_t parent_pid { };
    std::uint32_t process_group { };
    std::uint32_t session_id { };
    std::uint32_t audit_session_id { 1U };
    std::uint32_t uid { };
    std::uint32_t effective_uid { };
    std::uint32_t gid { };
    std::uint32_t effective_gid { };
    std::uint32_t file_creation_mask { 0022 };
    std::array<darwin::resource::Limit, darwin::resource::limit_count>
        resource_limits { darwin::resource::initial_limits() };
    std::string login_name;
    std::uint32_t task_port { mach_task_identity::initial_task_self_name };
    std::uint32_t thread_port { mach_task_identity::initial_thread_self_name };
    std::uint32_t host_port { mach_task_identity::initial_host_self_name };
    std::uint32_t bootstrap_port { mach_task_identity::initial_bootstrap_name };
    std::uint32_t clock_port { mach_task_identity::initial_clock_name };
    std::uint32_t calendar_clock_port {
        mach_task_identity::initial_calendar_clock_name
    };
    std::uint32_t io_master_port { mach_task_identity::initial_io_master_name };
    std::uint32_t io_registry_options_port {
        mach_task_identity::initial_io_registry_options_name
    };
    std::int32_t thread_base_priority {
        xnu::scheduler::default_base_priority
    };
    std::int32_t nice_value { };
    std::uint32_t disk_io_policy { };
    std::map<std::uint32_t, std::uint32_t> thread_disk_io_policies;
    bool exited { };
    bool waiting_for_events { };
    std::uint32_t exit_status { };
    std::uint32_t termination_signal { };
};

struct KeventRegistration {
    std::uint64_t ident { };
    std::int16_t filter { };
    std::uint16_t flags { };
    std::uint32_t filter_flags { };
    std::int64_t data { };
    std::uint64_t user_data { };
    std::uint64_t process_exec_generation { };
    std::uint64_t process_exit_generation { };
    bool user_triggered { };
    bool enabled { true };
    bool clear_delivered { };
    std::uint32_t clear_available { };
    mutable std::uint64_t empty_mach_queue_generation { };
    std::optional<VnodeWatch> vnode_watch;
    std::array<std::uint64_t, 2> extension { };
    std::optional<KeventTimer> timer;
};

struct PendingWait {
    std::int32_t target_pid { -1 };
    std::uint32_t status_address { };
    std::uint32_t options { };
    std::size_t processor { };
};

struct PendingMachReceive {
    std::uint32_t message_address { };
    std::uint32_t receive_size { };
    std::uint32_t receive_name { };
    std::uint32_t options { };
    std::size_t processor { };
    std::optional<std::uint64_t> deadline;
    std::optional<std::uint32_t> receive_object;
    bool receive_is_port_set { };
    std::uint64_t observed_queue_generation { };
    std::uint64_t wait_queue_sequence { };
    std::uint64_t started { };
    std::optional<std::uint32_t> awaited_request;
};

struct PendingKevent {
    std::uint32_t queue_fd { };
    std::uint32_t event_address { };
    std::uint32_t event_count { };
    std::size_t processor { };
    std::optional<std::uint64_t> deadline;
    bool extended { };
};

struct PendingRecvmsg {
    std::uint32_t fd { };
    std::uint32_t message_address { };
    std::size_t processor { };
};

struct PendingSocketRead {
    std::uint32_t fd { };
    std::uint32_t address { };
    std::uint32_t size { };
    std::uint32_t source_address { };
    std::uint32_t source_length_address { };
    std::size_t processor { };
    std::optional<std::uint64_t> deadline;
};

struct PendingHostConnect {
    std::uint32_t fd { };
    std::size_t processor { };
};

struct PendingHostAccept {
    std::uint32_t fd { };
    std::uint32_t address { };
    std::uint32_t length_address { };
    std::size_t processor { };
};

struct PendingHostWrite {
    std::uint32_t fd { };
    std::shared_ptr<HostSocket> socket;
    std::vector<std::byte> bytes;
    std::vector<std::byte> destination;
};

struct PendingBasebandWrite {
    std::uint32_t fd { };
    std::vector<std::byte> bytes;
};

struct PendingUnixAccept {
    std::uint32_t fd { };
    std::uint32_t address { };
    std::uint32_t length_address { };
    std::size_t processor { };
};

struct PendingFlock {
    std::uint32_t fd { };
    bsd::AdvisoryLockKind kind { bsd::AdvisoryLockKind::Shared };
    std::shared_ptr<bsd::RegularFileOpenDescription> description;
    std::size_t processor { };
};

struct PendingRecordLock {
    std::uint32_t fd { };
    std::uint32_t permanent_file_id { };
    bsd::RecordLockRange range;
    std::size_t processor { };
};

struct PendingSelect {
    std::uint32_t descriptor_count { };
    std::uint32_t read_address { };
    std::uint32_t write_address { };
    std::uint32_t exception_address { };
    std::vector<std::uint32_t> read_words;
    std::vector<std::uint32_t> write_words;
    std::size_t processor { };
    std::optional<std::uint64_t> deadline;
};

struct PendingPollEntry {
    std::int32_t fd { };
    std::uint16_t events { };
};

struct PendingPoll {
    std::uint32_t address { };
    std::vector<PendingPollEntry> entries;
    std::size_t processor { };
    std::optional<std::uint64_t> deadline;
};

struct PendingSemaphoreWait {
    std::uint32_t semaphore { };
    std::size_t processor { };
    std::optional<std::uint64_t> deadline;
    bool bsd_result { };
};

struct PendingPsynchWait {
    std::uint32_t address { };
    DarwinPsynchWaitKind kind { DarwinPsynchWaitKind::Mutex };
    std::size_t processor { };
    std::optional<std::uint64_t> deadline;
};

struct PendingSignalSuspend {
    std::uint32_t mask { };
    bool interrupted { };
};

enum class PendingTimerKind {
    MachWaitUntil,
    ThreadSwitch,
    ClockSleep,
};

struct PendingTimer {
    struct BootstrapRetry {
        std::string service_name;
        std::uint64_t observed_generation { };
    };

    std::uint64_t deadline { };
    PendingTimerKind kind { PendingTimerKind::MachWaitUntil };
    std::optional<std::uint32_t> wakeup_time_address;
    bool calendar_clock { };
    std::optional<BootstrapRetry> bootstrap_retry;
};

struct SocketPairLifetime {
    std::array<std::atomic_bool, 2> read_open { true, true };
    std::array<std::atomic_bool, 2> write_open { true, true };
    std::array<std::uint64_t, 2> read_offsets { };
};

struct SocketPairOpenDescription {
    std::shared_ptr<SocketPairLifetime> lifetime;
    std::uint32_t side { };

    SocketPairOpenDescription(std::shared_ptr<SocketPairLifetime> pair_lifetime,
        std::uint32_t endpoint_side)
        : lifetime { std::move(pair_lifetime) }
        , side { endpoint_side }
    {
    }
    SocketPairOpenDescription(const SocketPairOpenDescription&) = delete;
    SocketPairOpenDescription& operator=(
        const SocketPairOpenDescription&) = delete;

    ~SocketPairOpenDescription()
    {
        if (!lifetime || side >= lifetime->read_open.size())
            return;
        lifetime->read_open[side].store(false, std::memory_order_release);
        lifetime->write_open[side].store(false, std::memory_order_release);
    }
};

struct SocketPairEndpoint {
    std::uint32_t pair { };
    std::uint32_t side { };
    std::shared_ptr<SocketPairOpenDescription> description;
    std::optional<bsd::LocalSocketCredentials> peer_credentials { };

    [[nodiscard]] bool local_read_open() const
    {
        return description && description->lifetime &&
               description->lifetime->read_open[side].load(
                   std::memory_order_acquire);
    }
    [[nodiscard]] bool local_write_open() const
    {
        return description && description->lifetime &&
               description->lifetime->write_open[side].load(
                   std::memory_order_acquire);
    }
    [[nodiscard]] bool peer_read_open() const
    {
        return description && description->lifetime &&
               description->lifetime->read_open[1U - side].load(
                   std::memory_order_acquire);
    }
    [[nodiscard]] bool peer_write_open() const
    {
        return description && description->lifetime &&
               description->lifetime->write_open[1U - side].load(
                   std::memory_order_acquire);
    }
    void shutdown_read() const
    {
        if (description && description->lifetime) {
            description->lifetime->read_open[side].store(
                false, std::memory_order_release);
        }
    }
    void shutdown_write() const
    {
        if (description && description->lifetime) {
            description->lifetime->write_open[side].store(
                false, std::memory_order_release);
        }
    }
};

[[nodiscard]] inline std::pair<SocketPairEndpoint, SocketPairEndpoint>
make_socket_pair_endpoints(std::uint32_t pair)
{
    auto lifetime = std::make_shared<SocketPairLifetime>();
    return { SocketPairEndpoint { pair, 0,
                 std::make_shared<SocketPairOpenDescription>(lifetime, 0) },
        SocketPairEndpoint { pair, 1,
            std::make_shared<SocketPairOpenDescription>(
                std::move(lifetime), 1) } };
}

struct KernelSharedState {
    HidEventQueue hid_event_queue;
    DarwinKernelIdentity darwin_kernel_identity;
    DarwinAbi darwin_abi;
    std::string device_product_type;
    std::string device_board_config;
    std::string device_hardware_model;
    std::string device_model_number;
    std::uint64_t device_ram_bytes { };
    std::vector<std::byte> graphics_services_capability_memory;
    std::uint32_t device_cpu_type { arm_mach_cpu_type };
    std::uint32_t device_cpu_subtype { mach_cpu_subtype_for_architecture(
        ArmArchitectureVersion::Armv6K) };
    GraphicsAcceleratorKind graphics_accelerator {
        GraphicsAcceleratorKind::MbxLite
    };
    std::string graphics_driver_bundle;
    AudioHardwareProfile audio_hardware_profile {
        AudioHardwareProfile::CodecBaseband
    };
    std::string framebuffer_service_class;
    ExternalFramebufferProfile external_framebuffer;
    AmbientLightSensorProfile ambient_light_sensor;
    bool native_hid_touch_events { true };
    bool apple_key_store_available { };
    bool effaceable_storage_available { true };
    bool virtual_effaceable_storage_available { };
    std::array<std::byte, 52> effaceable_storage_blob { };

    struct NetworkInterface {
        std::uint16_t flags { };
        std::uint16_t index { };
        std::uint32_t family { };
        std::uint32_t unit { };
        std::uint32_t mtu { };
        std::uint8_t type { };
        std::array<std::byte, 6> link_address { };
        std::uint8_t link_address_length { };
        bool has_ipv4 { };
        bool has_ipv6 { };
        std::array<std::byte, 16> ipv4_address { };
        std::array<std::byte, 16> ipv4_netmask { };
        std::array<std::byte, 16> ipv4_broadcast { };
        std::array<std::byte, 16> ipv4_gateway { };
        std::array<std::byte, 28> ipv6_address { };
        std::array<std::byte, 28> ipv6_netmask { };
        darwin::network::InterfaceCounters counters;
        std::uint64_t up_time_nanoseconds { };
    };
    struct KernelEvent {
        std::uint32_t identifier { };
        std::uint32_t vendor { };
        std::uint32_t event_class { };
        std::uint32_t event_subclass { };
        std::uint32_t event_code { };
        std::vector<std::byte> bytes;
    };
    struct RouteSocketMessage {
        std::uint32_t identifier { };
        std::vector<std::byte> bytes;
        std::uint8_t family { };
        std::optional<std::uint64_t> receiver_socket;
    };
    struct RouteSocketState {
        std::uint64_t identifier { };
        std::uint32_t next_message_identifier { };
        std::uint32_t protocol { };
    };
    struct MountEntry {
        std::string type;
        std::string path;
        std::string source;
        std::uint32_t flags { };
    };
    struct MachMessage {
        enum class GraphicsInputKind {
            None,
            Touch,
            Home,
            Lock,
            OtherSystem,
        };
        struct ReceivePointerFixup {
            std::uint32_t value_offset { };
            std::uint32_t target_offset { };
        };
        struct OolPayload {
            std::uint32_t descriptor_offset { };
            std::vector<std::byte> bytes;
        };
        struct PortTransfer {
            std::uint32_t descriptor_offset { };
            std::uint32_t sender_name { };
            std::optional<std::uint32_t> array_index;
            std::uint32_t object { };
            xnu::ipc::Right right { xnu::ipc::Right::Send };
            std::uint32_t disposition { };
        };
        struct OolPortArray {
            std::uint32_t descriptor_offset { };
            std::uint32_t count { };
            std::vector<std::uint32_t> dead_elements;
        };

        std::vector<std::byte> bytes;
        std::uint32_t destination { };
        std::uint32_t sender_pid { };
        std::uint32_t sender_identity_version { };
        std::uint64_t host_enqueue_nanoseconds { };
        std::uint32_t sender_uid { };
        std::uint32_t sender_gid { };
        std::uint64_t graphics_input_sequence { };
        GraphicsInputKind graphics_input_kind { GraphicsInputKind::None };
        std::optional<TouchPhase> graphics_touch_phase;
        std::optional<std::uint32_t> display_vsync_connection_object;
        std::uint64_t display_vsync_registration_generation { };
        std::uint64_t display_vsync_sequence { };
        std::vector<OolPayload> ool_payloads;
        std::vector<OolPortArray> ool_port_arrays;
        std::optional<std::uint32_t> reply_object;
        std::optional<xnu::ipc::Right> reply_right;
        std::optional<std::uint32_t> destination_send_object;
        std::vector<PortTransfer> port_transfers;
        std::vector<ReceivePointerFixup> receive_pointer_fixups;
    };
    struct ClockAlarm {
        std::uint64_t deadline { };
        std::uint64_t alarm_time { };
        std::uint32_t alarm_type { };
        std::uint32_t reply_object { };
    };
    struct UnixListener {
        std::uint32_t owner_pid { };
        std::uint32_t owner_fd { };
        std::deque<SocketPairEndpoint> pending_endpoints;
        std::optional<bsd::LocalSocketCredentials> credentials { };
    };
    struct DescriptorTransfer {
        enum class Kind : std::uint8_t { File, Virtual };

        Kind kind { Kind::Virtual };
        std::filesystem::path file_path;
        std::uint64_t file_offset { };
        std::uint32_t file_status_flags { };
        std::shared_ptr<bsd::RegularFileOpenDescription>
            regular_file_open_description;
        std::optional<std::pair<std::uint32_t, bool>> block_device;
        std::string virtual_type;
        std::shared_ptr<bsd::baseband_device::OpenDescription>
            baseband_open_description;
        std::optional<SocketPairEndpoint> socket_endpoint;
        std::shared_ptr<UnixListener> unix_listener_state;
        std::shared_ptr<RouteSocketState> route_socket_state;
        std::shared_ptr<bsd::VirtualUdpSocket> virtual_udp_socket;
        std::string bound_name;
        bool listening { };
        std::vector<KeventRegistration> kqueue_registrations;
    };
    struct SocketAncillaryRecord {
        std::uint64_t byte_offset { };
        std::vector<DescriptorTransfer> transfers;
    };
    enum class GraphicsInputAbi {
        LegacyMouse,
        Darwin9_0,
        Darwin9_3,
        Darwin9_4,
        Darwin11_0,
    };
    struct ProcessRecord {
        std::uint32_t parent_pid { };
        std::uint32_t process_group { };
        std::uint32_t uid { };
        std::uint32_t effective_uid { };
        std::uint32_t gid { };
        std::uint32_t effective_gid { };
        std::int32_t nice_value { };
        std::uint32_t exit_status { };
        std::uint32_t termination_signal { };
        bool exited { };
        bool pid_suspended { };
        bool signal_stopped { };
        std::string command;
        std::string executable_path;
        std::vector<std::string> arguments;
        std::vector<std::string> environment;
        GraphicsInputAbi graphics_input_abi { GraphicsInputAbi::Darwin9_0 };
        std::vector<std::byte> code_signature_entitlements;
        std::optional<CoreAnimationRemoteAbi> core_animation_remote_abi;
        DisplayOrientation display_orientation { DisplayOrientation::Portrait };
        ApplicationDisplay application_display;
        std::uint64_t incarnation { };
        std::uint64_t parent_incarnation { };
        std::uint64_t start_wall_nanoseconds { };
        std::array<std::byte, 16> executable_uuid { };
        std::uint32_t audit_identity_version { };
        darwin::memorystatus::ProcessState memory_status { };
        bool importance_donor { };
        std::uint32_t dyld_all_image_info_address { };
        std::uint32_t dyld_all_image_info_size { };
    };
    struct ProcessKeventState {
        std::uint64_t exec_generation { };
        std::uint64_t exit_generation { };
        std::uint32_t wait_status { };
    };
    struct IOKitNotification {
        std::uint32_t owner_pid { };
        std::uint32_t notification_port { };
        std::string type;
        std::vector<std::byte> matching;
    };
    struct IOKitRegistryProperty {
        enum class Kind {
            String,
            Data,
            Boolean,
            Number,
            Array,
            Dictionary,
        };

        Kind kind { Kind::Data };
        std::vector<std::byte> value;
        std::vector<IOKitRegistryProperty> array_value;
        std::map<std::string, IOKitRegistryProperty> dictionary_value;

        IOKitRegistryProperty() = default;
        IOKitRegistryProperty(
            Kind property_kind, std::vector<std::byte> property_value)
            : kind(property_kind)
            , value(std::move(property_value))
        {
        }
    };
    enum class IOKitUserClientKind {
        None,
        Generic,
        SerialMultiplexer,
        Display,
        CoreSurface,
        Mbx,
        GraphicsAccelerator,
        CameraSensor,
        CameraAccelerator,
        JpegAccelerator,
        Audio,
        MobileFileIntegrity,
        AppleKeyStore,
        AppleEffaceableStorage,
        MultitouchHid,
    };
    struct IOKitService {
        std::string class_name;
        std::vector<std::string> conforms_to;
        std::map<std::string, IOKitRegistryProperty> properties;
        std::string registry_path;
        std::uint32_t parent_object { };
        IOKitUserClientKind user_client_kind {
            IOKitUserClientKind::None
        };

        IOKitService() = default;
        IOKitService(std::string service_class,
            std::vector<std::string> service_conformance,
            std::map<std::string, IOKitRegistryProperty>
                registry_properties = { },
            std::string service_registry_path = { },
            std::uint32_t service_parent_object = 0,
            IOKitUserClientKind service_user_client_kind =
                IOKitUserClientKind::None)
            : class_name(std::move(service_class))
            , conforms_to(std::move(service_conformance))
            , properties(std::move(registry_properties))
            , registry_path(std::move(service_registry_path))
            , parent_object(service_parent_object)
            , user_client_kind(service_user_client_kind)
        {
        }
    };
    struct IOKitConnection {
        std::uint32_t service_port { };
        std::uint32_t owner_pid { };
        std::uint32_t type { };
    };
    struct IOKitMbxConnectionState {
        struct Resource {
            std::uint32_t address { };
            std::uint32_t mapped_size { };
            std::uint32_t exposed_size { };
            std::uint32_t resource_type { };
            std::uint32_t alignment { };
        };
        struct CommandQueue {
            std::uint32_t control_address { };
            std::uint32_t buffer_address { };
            std::uint32_t mapped_size { };
            std::uint32_t buffer_size { };
        };

        std::uint32_t next_resource_handle { 1 };
        std::map<std::uint32_t, Resource> resources;
        std::optional<CommandQueue> command_queue;
    };
    struct IOKitGraphicsConnectionState {
        struct MemoryMapping {
            std::uint32_t address { };
            std::uint32_t mapped_size { };
            std::uint32_t exposed_size { };
        };

        std::map<std::uint32_t, MemoryMapping> memory_mappings;
        bool shared_created { };
        bool context_created { };
        std::uint32_t shared_connection_object { };
        std::uint32_t shared_resource_token { };
    };
    struct IOKitMultitouchHidConnectionState {
        struct MemoryMapping {
            std::uint32_t address { };
            std::uint32_t mapped_size { };
            std::uint32_t exposed_size { };
        };

        std::uint32_t notification_port { };
        std::uint32_t notification_type { };
        std::uint32_t registration_reference { };
        std::map<std::uint32_t, MemoryMapping> memory_mappings;
        bool started { };
    };
    struct IOKitInterestNotification {
        std::uint32_t owner_pid { };
        std::uint32_t wake_port { };
        std::string type;
        std::vector<std::uint32_t> reference;
    };
    struct IOKitDisplayVSync {
        std::uint32_t owner_pid { };
        std::uint32_t notification_port { };
        std::uint32_t notification_type { };
        std::uint32_t registration_reference { };
        std::uint64_t registration_generation { };
        std::array<std::uint32_t, 8> async_reference { };
        std::optional<std::uint32_t> last_callback_processor;
        std::optional<std::uint32_t> last_receiver_processor;
        std::uint64_t receiver_sequence { };
        std::uint64_t callback_sequence { };
        std::uint64_t swap_sequence { };
        std::optional<std::uint64_t> last_notification_frame_time;
        std::optional<std::uint64_t> next_deadline;
        std::uint64_t sequence { };
        std::uint64_t method_call_count { };
        bool enabled { };
    };
    struct IOKitDisplayConnectionState {
        std::uint32_t requested_power_state { };
    };
    struct IOKitAudioConnectionState {
        struct MemoryMapping {
            std::uint32_t address { };
            std::uint32_t mapped_size { };
            std::uint32_t exposed_size { };
        };
        struct StreamState {
            std::vector<std::byte> current_format;
            bool active { };
        };

        std::uint32_t notification_port { };
        std::uint32_t notification_type { };
        std::uint32_t registration_reference { };
        std::map<std::uint32_t, MemoryMapping> memory_mappings;
        std::map<std::uint32_t, StreamState> streams;
        std::map<std::uint32_t, std::uint32_t> control_values;
        std::vector<std::byte> nominal_sample_rate;
        bool running { };
    };
    struct IOKitCameraAcceleratorConnectionState {
        std::uint32_t notification_port { };
        std::uint32_t notification_type { };
        std::uint32_t registration_reference { };
        std::uint64_t capture_sequence { };
        std::optional<std::uint64_t> next_capture_deadline;
    };
    struct IOKitCameraCaptureRequest {
        std::uint32_t connection_object { };
        std::uint32_t callback { };
        std::uint32_t refcon { };
        std::uint32_t pixel_buffer { };
        std::uint32_t surface_id { };
        std::uint64_t sequence { };
        std::uint64_t deadline { };
    };
    struct PendingGraphicsInput {
        enum class Kind {
            Touch,
            SystemEvent,
        };
        Kind kind { Kind::Touch };
        TouchInput touch;
        std::uint32_t system_event_type { };
        std::uint64_t input_sequence { };
        MachMessage::GraphicsInputKind input_kind {
            MachMessage::GraphicsInputKind::None
        };
    };
    struct PendingBootstrapServiceRequest {
        enum class Kind {
            Lookup,
            CheckIn,
        };
        Kind kind { Kind::Lookup };
        std::string service_name;
        std::uint32_t requester_process_id { };
        std::uint64_t origin_touch_sequence { };
        bool application_launch_candidate { };
    };
    struct PendingApplicationEventLaunch {
        std::uint32_t springboard_process_id { };
        std::uint64_t origin_touch_sequence { };
    };
    enum class ApplicationSuspensionReason {
        None,
        Home,
        Lock,
    };
    enum class HostDisplayIntent {
        GuestControlled,
        LockPending,
        LockedOff,
        WakePending,
    };
    enum class ApplicationLaunchOrigin {
        Spawn,
        EventServiceLookup,
        ForegroundLifecycle,
    };
    enum class ApplicationLaunchPhase {
        Launching,
        Active,
        Suspended,
        InterruptedHome,
        HeldLock,
    };
    struct ApplicationLaunchAttempt {
        std::uint64_t token { };
        std::uint64_t origin_touch_sequence { };
        ApplicationLaunchOrigin origin { ApplicationLaunchOrigin::Spawn };
        ApplicationLaunchPhase phase { ApplicationLaunchPhase::Launching };
        bool foreground_handoff { };
        bool handoff_animation_dispatched { };
    };
    struct ForegroundTransitionProcess {
        std::uint32_t process_id { };
        std::uint64_t incarnation { };

        bool operator==(const ForegroundTransitionProcess&) const = default;
    };
    struct ForegroundTransitionTimestamp {
        std::uint64_t device_monotonic_time { };
        std::uint64_t host_steady_nanoseconds { };
    };
    enum class ForegroundTransitionMilestone {
        Spawned,
        EventPortReady,
        Lifecycle,
        SceneCommitted,
        VsyncDisabled,
        VsyncEnabled,
        DestinationFirstFrame,
    };
    enum class ForegroundTransitionTerminalState {
        Pending,
        Stable,
        Cancelled,
        Superseded,
    };
    struct ForegroundTransitionSnapshot {
        std::uint64_t generation { };
        std::uint64_t launch_token { };
        std::uint64_t input_sequence { };
        std::optional<ForegroundTransitionProcess> source;
        std::optional<ForegroundTransitionProcess> destination;
        std::optional<ForegroundTransitionTimestamp> input_completed;
        std::optional<ForegroundTransitionTimestamp> spawned;
        std::optional<ForegroundTransitionTimestamp> event_port_ready;
        std::optional<ForegroundTransitionTimestamp> lifecycle;
        std::optional<ForegroundTransitionTimestamp> scene_committed;
        std::optional<ForegroundTransitionTimestamp> vsync_disabled;
        std::optional<ForegroundTransitionTimestamp> vsync_enabled;
        std::optional<ForegroundTransitionTimestamp> destination_first_frame;
        std::uint64_t destination_first_frame_sequence { };
        std::optional<ForegroundTransitionTimestamp> first_content_change;
        std::optional<ForegroundTransitionTimestamp> last_content_change;
        std::uint64_t first_content_revision { };
        std::uint64_t last_content_revision { };
        ForegroundTransitionTerminalState terminal_state {
            ForegroundTransitionTerminalState::Pending
        };
        std::optional<ForegroundTransitionTimestamp> terminal;
    };
    struct ApplicationLaunchBarrier {
        ApplicationSuspensionReason reason {
            ApplicationSuspensionReason::None
        };
        std::uint64_t input_sequence { };
        std::optional<std::uint32_t> retained_process_id;
    };
    struct HeldApplicationLaunch {
        std::uint64_t origin_touch_sequence { };
        std::uint64_t lock_input_sequence { };
        std::uint32_t process_id { };
        std::uint64_t launch_token { };
        std::uint64_t unlock_up_sequence { };
    };
    struct ApplicationTouchTransform {
        float presentation_offset_x { };
        float presentation_offset_y { };
        float screen_origin_y { };

        bool operator==(const ApplicationTouchTransform&) const = default;
    };
    struct PendingApplicationSceneTransform {
        std::uint32_t process_id { };
        ApplicationTouchTransform transform;
    };
    struct ActiveApplicationScene {
        std::uint32_t process_id { };
        std::uint32_t event_object { };
        std::optional<ApplicationTouchTransform> touch_transform;
    };
    struct GraphicsTouchTransform {
        float xx { 1.0F };
        float xy { };
        float yx { };
        float yy { 1.0F };
        float tx { };
        float ty { };
    };
    struct GraphicsTouchRoute {
        std::uint32_t destination_object { };
        std::uint32_t process_id { };
        std::optional<GraphicsTouchTransform> transform;
        bool application { };
    };
    enum class SpringBoardAlertPresentation {
        Pending,
        LockScreen,
        ApplicationOverlay,
    };
    struct SpringBoardAlertLayer {
        SpringBoardAlertPresentation presentation {
            SpringBoardAlertPresentation::Pending
        };
        std::uint64_t sequence { };
    };
    struct MachSemaphore {
        std::int64_t count { };
        std::uint32_t owner_pid { };
        std::deque<std::pair<std::uint32_t, std::uint32_t>> waiters;
    };
    struct MachTimer {
        std::uint32_t owner_pid { };
        std::optional<std::uint64_t> deadline;
    };
    struct ProcessIntervalTimer {
        std::optional<std::uint64_t> deadline;
        std::uint64_t interval { };
    };
    struct MachMemoryObject {
        std::vector<std::shared_ptr<GuestPageBacking>> pages;
    };
    struct MachMemoryEntry {
        std::shared_ptr<MachMemoryObject> object;
        std::size_t first_page { };
        std::uint64_t size { };
        std::uint32_t protection { };
        bool purgable { };
    };
    struct TaskExceptionAction {
        std::uint32_t port_object { };
        std::uint32_t behavior { };
        std::uint32_t flavor { };

        bool operator==(const TaskExceptionAction&) const = default;
    };
    static constexpr std::size_t task_exception_type_count = 11;
    using TaskExceptionActions =
        std::array<TaskExceptionAction, task_exception_type_count>;
    struct MachNotificationRequest {
        std::uint32_t notify_object { };
        std::uint32_t sync { };
    };
    struct MachDeadNameNotificationRequest {
        std::uint32_t target_object { };
        std::uint32_t notify_object { };
        std::uint32_t sync { };
        bool send_possible { };
        bool armed { };
    };
    static constexpr std::uint32_t first_synthetic_mach_object = 0x10000U;
    static constexpr std::uint32_t synthetic_mach_object_stride = 0x100U;
    [[nodiscard]] std::uint32_t allocate_mach_object()
    {
        const auto object = next_mach_object;
        next_mach_object += synthetic_mach_object_stride;
        return object;
    }

    std::uint32_t desired_vnodes { 65'536 };
    std::atomic<std::int32_t> security_level { };
    std::string hostname { "localhost" };
    std::array<std::uint32_t, 2> task_for_pid_groups { };
    mutable std::mutex network_mutex;
    std::map<std::string, NetworkInterface> network_interfaces {
        { "lo0", { darwin::network::interface_flag_loopback |
                         darwin::network::interface_flag_running,
                     1, darwin::network::interface_family_loopback, 0,
                     darwin::network::default_loopback_mtu,
                     darwin::network::interface_type_loopback, { }, 0 } },
        { "en0", { darwin::network::interface_flag_broadcast |
                         darwin::network::interface_flag_simplex |
                         darwin::network::interface_flag_multicast,
                     2, darwin::network::interface_family_ethernet, 0,
                     darwin::network::default_ethernet_mtu,
                     darwin::network::interface_type_ethernet,
                     virtual_network::interface_mac_address, 6 } },
    };
    std::uint32_t next_kernel_event_identifier { 1 };
    std::deque<KernelEvent> kernel_events;
    darwin::route::Table route_table;
    mutable std::mutex route_socket_mutex;
    std::uint32_t next_route_message_identifier { 1 };
    std::uint64_t next_route_socket_identifier { 1 };
    std::deque<RouteSocketMessage> route_socket_messages;
    std::vector<MountEntry> mounts { { "hfs", "/", "/dev/disk0s1",
        0x00005001U } };
    std::vector<std::byte> nvram_serialized;
    std::uint32_t next_mach_object { first_synthetic_mach_object };
    std::uint32_t default_processor_set_name_object { };
    std::uint32_t default_processor_set_control_object { };
    xnu::ipc::MachNamespaceTable mach_namespaces;
    xnu::ipc::PortObjectTable mach_port_objects;
    std::map<std::uint32_t, std::uint64_t> mach_port_contexts;
    std::map<std::uint32_t, std::uint32_t> audit_session_port_objects;
    std::map<std::uint32_t, std::array<std::uint32_t, 3>> mach_registered_ports;
    std::map<std::uint32_t, std::uint32_t> mach_inflight_send_rights;
    std::map<std::uint32_t, std::uint32_t> mach_kernel_send_rights;
    std::set<std::uint32_t> mach_ports_being_removed;
    struct MachPortSetLink {
        std::uint32_t set_object { };
        std::uint64_t wait_queue_sequence { };
    };
    std::map<std::uint32_t, std::vector<std::uint32_t>> mach_port_sets;
    std::map<std::uint32_t, std::vector<MachPortSetLink>>
        mach_port_set_links_by_member;
    std::map<std::uint32_t, std::vector<std::uint32_t>>
        mach_port_set_preposts;
    std::uint64_t next_mach_wait_queue_sequence { 1 };

    [[nodiscard]] std::uint64_t allocate_mach_wait_queue_sequence_locked()
    {
        auto sequence = next_mach_wait_queue_sequence++;
        if (sequence == 0U) {
            sequence = 1U;
            next_mach_wait_queue_sequence = 2U;
        }
        return sequence;
    }

    [[nodiscard]] bool create_mach_port_set_locked(std::uint32_t set_object)
    {
        return mach_port_sets.try_emplace(set_object).second;
    }

    [[nodiscard]] bool insert_mach_port_set_member_locked(
        std::uint32_t set_object, std::uint32_t member_object)
    {
        const auto set = mach_port_sets.find(set_object);
        if (set == mach_port_sets.end() ||
            std::find(set->second.begin(), set->second.end(), member_object) !=
                set->second.end()) {
            return false;
        }
        set->second.push_back(member_object);
        mach_port_set_links_by_member[member_object].push_back(MachPortSetLink {
            set_object, allocate_mach_wait_queue_sequence_locked() });
        if (const auto queue = mach_queues.find(member_object);
            queue != mach_queues.end() && !queue->second.empty()) {
            mach_port_set_preposts[set_object].push_back(member_object);
        }
        note_mach_queue_topology_change_locked();
        return true;
    }

    [[nodiscard]] bool extract_mach_port_set_member_locked(
        std::uint32_t set_object, std::uint32_t member_object)
    {
        const auto set = mach_port_sets.find(set_object);
        if (set == mach_port_sets.end())
            return false;
        const auto member =
            std::find(set->second.begin(), set->second.end(), member_object);
        if (member == set->second.end())
            return false;
        set->second.erase(member);
        if (const auto links =
                mach_port_set_links_by_member.find(member_object);
            links != mach_port_set_links_by_member.end()) {
            std::erase_if(links->second, [set_object](const auto& link) {
                return link.set_object == set_object;
            });
            if (links->second.empty())
                mach_port_set_links_by_member.erase(links);
        }
        if (const auto preposts = mach_port_set_preposts.find(set_object);
            preposts != mach_port_set_preposts.end()) {
            std::erase(preposts->second, member_object);
            if (preposts->second.empty())
                mach_port_set_preposts.erase(preposts);
        }
        note_mach_queue_topology_change_locked();
        return true;
    }

    [[nodiscard]] bool remove_mach_port_set_member_from_all_locked(
        std::uint32_t member_object)
    {
        const auto links = mach_port_set_links_by_member.find(member_object);
        if (links == mach_port_set_links_by_member.end())
            return false;
        for (const auto& link : links->second) {
            if (const auto set = mach_port_sets.find(link.set_object);
                set != mach_port_sets.end()) {
                std::erase(set->second, member_object);
            }
            if (const auto preposts =
                    mach_port_set_preposts.find(link.set_object);
                preposts != mach_port_set_preposts.end()) {
                std::erase(preposts->second, member_object);
                if (preposts->second.empty())
                    mach_port_set_preposts.erase(preposts);
            }
        }
        mach_port_set_links_by_member.erase(links);
        note_mach_queue_topology_change_locked();
        return true;
    }

    [[nodiscard]] bool erase_mach_port_set_locked(std::uint32_t set_object)
    {
        const auto set = mach_port_sets.find(set_object);
        if (set == mach_port_sets.end())
            return false;
        for (const auto member_object : set->second) {
            if (const auto links =
                    mach_port_set_links_by_member.find(member_object);
                links != mach_port_set_links_by_member.end()) {
                std::erase_if(links->second, [set_object](const auto& link) {
                    return link.set_object == set_object;
                });
                if (links->second.empty())
                    mach_port_set_links_by_member.erase(links);
            }
        }
        mach_port_set_preposts.erase(set_object);
        mach_port_sets.erase(set);
        note_mach_queue_topology_change_locked();
        return true;
    }
    std::map<std::uint32_t, std::uint32_t> task_port_pids;
    std::map<std::uint32_t, std::uint32_t> task_name_port_pids;
    std::map<std::uint32_t, std::map<std::uint32_t, std::uint32_t>>
        task_thread_port_objects;
    struct PinnedDirectory {
        std::filesystem::path guest;
        int host_descriptor { -1 };
    };
    std::map<std::uint32_t, PinnedDirectory> thread_working_directories;
    std::map<std::uint32_t, std::map<std::uint32_t, std::uint32_t>>
        task_special_ports;
    std::map<std::uint32_t, TaskExceptionActions> task_exception_actions;
    std::map<std::uint32_t, std::deque<MachMessage>> mach_queues;
    std::atomic_uint64_t mach_queue_generation { 1 };
    std::atomic_uint64_t kernel_event_generation { 1 };
    std::uint64_t shared_timer_deadline_cache_generation { };
    std::optional<std::uint64_t> shared_timer_deadline_cache;
    bool shared_timer_deadline_cache_valid { };
    std::atomic_uint64_t io_event_generation { 1 };

    void enqueue_mach_message_locked(
        std::uint32_t destination, MachMessage message)
    {
        auto& queue = mach_queues[destination];
        const auto was_empty = queue.empty();
        queue.push_back(std::move(message));
        if (was_empty) {
            if (const auto links =
                    mach_port_set_links_by_member.find(destination);
                links != mach_port_set_links_by_member.end()) {
                for (const auto& link : links->second) {
                    auto& preposts = mach_port_set_preposts[link.set_object];
                    if (std::find(preposts.begin(), preposts.end(), destination) ==
                        preposts.end()) {
                        preposts.push_back(destination);
                    }
                }
            }
        }
        mach_queue_generation.fetch_add(1, std::memory_order_release);
    }

    void notify_send_possible_locked(std::uint32_t destination);

    void note_mach_message_dequeued_locked(std::uint32_t destination)
    {
        notify_send_possible_locked(destination);
        const auto links = mach_port_set_links_by_member.find(destination);
        if (links == mach_port_set_links_by_member.end())
            return;
        for (const auto& link : links->second) {
            const auto preposts = mach_port_set_preposts.find(link.set_object);
            if (preposts == mach_port_set_preposts.end())
                continue;
            const auto queue = mach_queues.find(destination);
            if (queue != mach_queues.end() && !queue->second.empty())
                continue;
            std::erase(preposts->second, destination);
            if (preposts->second.empty())
                mach_port_set_preposts.erase(preposts);
        }
    }

    void note_mach_queue_topology_change_locked()
    {
        mach_queue_generation.fetch_add(1, std::memory_order_release);
    }

    [[nodiscard]] std::uint64_t mach_queue_generation_snapshot() const
    {
        return mach_queue_generation.load(std::memory_order_acquire);
    }

    void note_kernel_event_transition()
    {
        kernel_event_generation.fetch_add(1, std::memory_order_release);
    }

    [[nodiscard]] std::uint64_t kernel_event_generation_snapshot() const
    {
        return kernel_event_generation.load(std::memory_order_acquire);
    }

    void note_io_event_transition()
    {
        io_event_generation.fetch_add(1, std::memory_order_release);
    }

    [[nodiscard]] std::uint64_t io_event_generation_snapshot() const
    {
        return io_event_generation.load(std::memory_order_acquire) +
               guest_file_generation_registry->mutation_generation();
    }
    std::map<std::uint32_t, std::deque<PendingBootstrapServiceRequest>>
        pending_bootstrap_service_requests;
    std::map<std::uint32_t, PendingApplicationEventLaunch>
        pending_application_event_launches;
    std::map<std::string, std::uint32_t> bootstrap_service_objects;
    std::map<std::uint32_t, PendingTimer::BootstrapRetry>
        pending_bootstrap_retries;
    std::map<std::string, std::uint64_t> bootstrap_service_generations;
    std::set<std::string> bootstrap_checked_in_services;
    std::once_flag launchd_job_catalog_once;
    std::optional<LaunchdJobCatalog> launchd_job_catalog;
    std::uint32_t pending_application_event_object { };
    std::uint32_t active_application_event_object { };
    std::map<std::uint32_t, std::uint32_t> application_event_objects_by_process;
    bool application_touch_suspended { };
    ApplicationSuspensionReason application_suspension_reason {
        ApplicationSuspensionReason::None
    };
    std::optional<std::uint32_t> suspended_application_scene_process_id;
    std::uint64_t next_graphics_input_sequence { 1 };
    std::optional<GraphicsTouchRoute> active_graphics_touch_route;
    std::uint64_t springboard_last_consumed_touch_sequence { };
    std::uint64_t springboard_active_touch_begin_sequence { };
    std::uint64_t springboard_last_touch_begin_sequence { };
    std::uint64_t springboard_pending_launch_touch_sequence { };
    std::uint64_t springboard_enqueued_active_touch_begin_sequence { };
    std::uint64_t springboard_enqueued_last_touch_begin_sequence { };
    std::uint64_t springboard_enqueued_last_touch_end_sequence { };
    float springboard_enqueued_last_touch_end_x { };
    float springboard_enqueued_last_touch_end_y { };
    bool springboard_unlock_touch_pending { };
    bool springboard_unlock_touch_active { };
    std::optional<bool> springboard_lock_screen_active;
    std::uint64_t springboard_unlock_touch_begin_sequence { };
    std::uint64_t springboard_unlock_touch_end_sequence { };
    float springboard_unlock_touch_start_x { };
    float springboard_unlock_touch_start_y { };
    float springboard_unlock_touch_end_x { };
    float springboard_unlock_touch_end_y { };
    std::uint64_t next_application_launch_token { 1 };
    std::uint64_t next_process_incarnation { 1 };
    std::uint32_t next_audit_identity_version { 1 };
    std::uint64_t next_foreground_transition_generation { 1 };
    std::optional<ForegroundTransitionSnapshot> foreground_transition_snapshot;
    std::optional<ForegroundTransitionTimestamp>
        pending_foreground_transition_input_completion;
    std::optional<ApplicationLaunchBarrier> application_launch_barrier;
    std::uint64_t last_home_launch_barrier_sequence { };
    std::map<std::uint32_t, ApplicationLaunchAttempt>
        application_launch_attempts;
    std::optional<std::uint32_t> foreground_application_attempt_process_id;
    std::optional<HeldApplicationLaunch> held_application_launch;
    std::optional<std::uint64_t> interrupted_home_exit_lock_sequence;
    std::map<std::uint32_t, std::uint32_t> surface_transport_port_surfaces;
    std::map<std::uint32_t, std::uint32_t> surface_transport_surface_ports;
    std::map<std::uint32_t, std::shared_ptr<SurfaceTransportLease>>
        surface_transport_port_leases;
    std::map<std::uint32_t, std::set<std::uint64_t>>
        application_fullscreen_surface_publications;
    std::set<std::uint32_t>
        suppress_future_application_fullscreen_surface_processes;
    std::set<std::pair<std::uint32_t, std::uint64_t>>
        suppressed_application_fullscreen_surface_publications;
    std::atomic_bool application_fullscreen_surface_suppression_active {
        false
    };
    HostDisplayIntent host_display_intent {
        HostDisplayIntent::GuestControlled
    };
    std::deque<std::uint64_t> host_display_pending_lock_power_off_sequences;
    std::uint64_t host_display_current_lock_down_sequence { };
    std::uint64_t host_display_wake_after_lock_sequence { };
    bool host_display_wake_power_on_acknowledged { };
    bool host_display_hardware_wake_pending { };
    std::map<std::pair<std::uint32_t, std::uint32_t>, std::uint32_t>
        application_scene_context_owners;
    std::map<std::uint32_t, ApplicationTouchTransform>
        application_scene_transforms;
    std::optional<PendingApplicationSceneTransform>
        latest_application_scene_transform;
    std::optional<ActiveApplicationScene> active_application_scene;
    std::optional<std::uint32_t> pending_application_handoff_process_id;
    std::uint64_t next_foreground_layer_sequence { 1 };
    std::uint64_t active_application_layer_sequence { };
    std::map<std::uint32_t, SpringBoardAlertLayer>
        active_springboard_alert_items;
    std::deque<PendingGraphicsInput> pending_graphics_inputs;
    std::map<std::uint32_t, MachSemaphore> mach_semaphores;
    std::map<std::string, std::uint32_t> posix_named_semaphore_objects;
    std::map<std::uint32_t, MachTimer> mach_timers;
    std::map<std::uint32_t, ProcessIntervalTimer> process_interval_timers;
    std::map<std::uint32_t, MachMemoryEntry> mach_memory_entries;
    std::map<std::uint32_t, DescriptorTransfer> mach_fileports;
    std::map<std::uint64_t, ClockAlarm> clock_alarms;
    std::uint64_t next_clock_alarm { 1 };
    std::map<std::pair<std::uint32_t, std::uint32_t>, MachNotificationRequest>
        mach_notifications;
    std::map<std::pair<std::uint32_t, std::uint32_t>,
        MachDeadNameNotificationRequest>
        mach_dead_name_notifications;
    std::set<std::uint32_t> mach_send_possible_armed_destinations;
    std::set<std::pair<std::uint32_t, std::uint32_t>> semaphore_wakeups;
    std::set<std::pair<std::uint32_t, std::uint32_t>> semaphore_terminations;
    std::map<std::uint32_t, std::deque<std::uint32_t>> iokit_iterators;
    std::map<std::uint32_t, IOKitService> iokit_services;
    std::uint32_t iokit_registry_root_object {
        mach_task_identity::initial_io_registry_options_name
    };
    std::map<std::uint32_t, IOKitConnection> iokit_connections;
    std::map<std::uint32_t, IOKitInterestNotification>
        iokit_interest_notifications;
    std::map<std::uint32_t, IOKitDisplayVSync> iokit_display_vsync;
    std::uint64_t iokit_display_vsync_registration_generation { };
    std::set<std::pair<std::uint64_t, std::uint32_t>>
        iokit_display_vsync_deadlines;
    std::uint64_t display_vsync_pulse_count { };
    std::uint64_t display_vsync_last_delivered_deadline { };
    std::map<std::uint32_t, IOKitDisplayConnectionState>
        iokit_display_connections;
    std::map<std::uint32_t, IOKitAudioConnectionState> iokit_audio_connections;
    std::map<std::uint32_t, IOKitCameraAcceleratorConnectionState>
        iokit_camera_accelerator_connections;
    std::deque<IOKitCameraCaptureRequest> iokit_camera_capture_requests;
    std::map<std::uint32_t, IOKitMbxConnectionState> iokit_mbx_connections;
    std::map<std::uint32_t, IOKitGraphicsConnectionState>
        iokit_graphics_connections;
    std::map<std::uint32_t, IOKitMultitouchHidConnectionState>
        iokit_multitouch_hid_connections;
    DisplayGeometry display_geometry { default_display_geometry };
    DisplayGeometry user_interface_geometry { default_display_geometry };
    std::optional<std::uint32_t> requested_display_power_state;
    std::uint32_t baseband_service { };
    std::uint32_t serial_multiplexer_service { };
    std::uint32_t camera_sensor_service { };
    std::map<std::string, std::uint32_t> camera_accelerator_services;
    std::uint32_t jpeg_accelerator_service { };
    std::map<std::uint64_t, std::uint64_t> camera_sensor_variables;
    std::uint32_t mobile_file_integrity_service { };
    std::uint32_t apple_key_store_service { };
    std::uint32_t effaceable_storage_service { };
    std::uint32_t keybag_device_tree_defaults_service { };
    std::uint32_t keybag_device_tree_options_service { };
    std::uint64_t next_keybag_handle { 1 };
    std::uint64_t system_keybag_handle { };
    std::shared_ptr<KeyStore> key_store;
    bsd::baseband_device::State baseband_device_state;
    std::uint32_t mobile_framebuffer_service { };
    std::uint32_t external_framebuffer_service { };
    std::uint32_t multitouch_hid_service { };
    std::map<std::string, std::uint32_t> ioaudio2_services;
    bool wifi_service_available { };
    std::uint32_t wifi_service { };
    std::uint32_t wifi_interface_service { };
    std::vector<IOKitNotification> iokit_notifications;
    VirtualClock clock;
    std::uint32_t next_socket_pair { 1 };
    std::map<std::uint32_t, std::array<std::deque<std::byte>, 2>>
        socket_pair_buffers;
    std::map<std::uint32_t, std::array<std::deque<SocketAncillaryRecord>, 2>>
        socket_pair_ancillary;
    std::shared_ptr<bsd::VirtualUdpNetwork> virtual_udp_network {
        std::make_shared<bsd::VirtualUdpNetwork>()
    };
    std::map<std::string, std::weak_ptr<UnixListener>> unix_listeners;
    std::set<std::string> unix_socket_nodes;
    std::uint32_t next_shared_memory_object { 1 };
    std::map<std::string, std::filesystem::path> shared_memory_objects;
    std::set<std::filesystem::path> volatile_shared_memory_backings;
    std::shared_ptr<GuestFileGenerationRegistry>
        guest_file_generation_registry {
            std::make_shared<GuestFileGenerationRegistry>()
        };
    std::shared_ptr<FilePageCache> shared_mapping_page_cache {
        std::make_shared<FilePageCache>(
            FilePageCacheLimits { }, guest_file_generation_registry)
    };
    std::map<std::uint32_t, hfs::MetadataOverride> hfs_metadata_overrides;
    std::map<std::uint32_t,
        std::map<std::string, std::optional<std::vector<std::byte>>>>
        hfs_named_attribute_overrides;
    std::vector<std::string> package_extensions;
    std::map<std::uint32_t, ProcessRecord> processes;
    std::map<std::uint32_t, ProcessKeventState> process_kevent_states;
    std::shared_ptr<bsd::AdvisoryFileLockRegistry> advisory_file_locks {
        std::make_shared<bsd::AdvisoryFileLockRegistry>()
    };
    std::shared_ptr<DarwinPsynchRuntime> psynch_runtime {
        std::make_shared<DarwinPsynchRuntime>()
    };

    std::optional<std::uint64_t> observe_display_vsync_callback_locked(
        std::uint32_t process_id,
        std::uint32_t framebuffer_refcon, std::uint32_t processor_id)
    {
        std::optional<std::uint64_t> observed_sequence;
        for (auto& [connection_object, registration] : iokit_display_vsync) {
            static_cast<void>(connection_object);
            if (registration.owner_pid != process_id ||
                registration.async_reference
                        [iokit_abi::display_vsync::async_refcon_index] !=
                    framebuffer_refcon) {
                continue;
            }
            registration.last_callback_processor = processor_id;
            const auto completed_sequence =
                registration.receiver_sequence > registration.callback_sequence
                    ? registration.receiver_sequence
                    : registration.sequence;
            registration.callback_sequence = std::min(registration.sequence,
                std::max(registration.callback_sequence, completed_sequence));
            observed_sequence = registration.callback_sequence;
        }
        return observed_sequence;
    }

    std::optional<std::uint64_t> observe_display_vsync_frame_begin_locked(
        std::uint32_t process_id,
        std::uint32_t framebuffer_refcon, std::uint32_t processor_id)
    {
        std::optional<std::uint64_t> advanced_sequence;
        for (auto& [connection_object, registration] : iokit_display_vsync) {
            static_cast<void>(connection_object);
            if (registration.owner_pid != process_id ||
                registration.async_reference
                        [iokit_abi::display_vsync::async_refcon_index] !=
                    framebuffer_refcon) {
                continue;
            }
            if (registration.receiver_sequence <=
                registration.callback_sequence) {
                continue;
            }
            registration.last_callback_processor = processor_id;
            registration.callback_sequence = std::min(registration.sequence,
                registration.receiver_sequence);
            advanced_sequence = registration.callback_sequence;
        }
        return advanced_sequence;
    }

    void observe_display_vsync_receive_locked(std::uint32_t process_id,
        std::uint32_t connection_object, std::uint64_t registration_generation,
        std::uint64_t notification_sequence, std::uint32_t processor_id)
    {
        const auto found = iokit_display_vsync.find(connection_object);
        if (found == iokit_display_vsync.end())
            return;
        auto& registration = found->second;
        if (!registration.enabled || registration.owner_pid != process_id ||
            registration.registration_generation != registration_generation ||
            notification_sequence == 0U ||
            notification_sequence > registration.sequence ||
            notification_sequence <= registration.callback_sequence ||
            notification_sequence < registration.receiver_sequence) {
            return;
        }
        registration.last_receiver_processor = processor_id;
        registration.receiver_sequence = notification_sequence;
    }

    void observe_display_vsync_swap_end_locked(
        std::uint32_t process_id, std::uint32_t framebuffer_refcon)
    {
        for (auto& [connection_object, registration] : iokit_display_vsync) {
            static_cast<void>(connection_object);
            if (registration.owner_pid != process_id ||
                registration.async_reference
                        [iokit_abi::display_vsync::async_refcon_index] !=
                    framebuffer_refcon) {
                continue;
            }
            registration.swap_sequence = std::max(
                registration.swap_sequence, registration.callback_sequence);
        }
    }

    [[nodiscard]] static std::uint64_t
    foreground_transition_host_steady_nanoseconds()
    {
        return static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now().time_since_epoch())
                .count());
    }

    [[nodiscard]] ForegroundTransitionTimestamp
    foreground_transition_timestamp_locked() const
    {
        return ForegroundTransitionTimestamp { clock.now(),
            foreground_transition_host_steady_nanoseconds() };
    }

    [[nodiscard]] std::optional<ForegroundTransitionProcess>
    process_identity_locked(std::uint32_t process_id) const
    {
        const auto process = processes.find(process_id);
        if (process == processes.end())
            return std::nullopt;
        return ForegroundTransitionProcess { process_id,
            process->second.incarnation };
    }

    void begin_foreground_transition_locked(std::uint64_t launch_token,
        std::uint64_t input_sequence,
        std::optional<ForegroundTransitionProcess> source,
        std::optional<ForegroundTransitionProcess> destination)
    {
        if (launch_token == 0U || !destination)
            return;
        if (foreground_transition_snapshot &&
            foreground_transition_snapshot->launch_token == launch_token &&
            foreground_transition_snapshot->destination == destination) {
            if (!foreground_transition_snapshot->input_completed &&
                pending_foreground_transition_input_completion) {
                foreground_transition_snapshot->input_completed =
                    pending_foreground_transition_input_completion;
                pending_foreground_transition_input_completion.reset();
            }
            return;
        }
        if (foreground_transition_snapshot &&
            foreground_transition_snapshot->terminal_state ==
                ForegroundTransitionTerminalState::Pending) {
            foreground_transition_snapshot->terminal_state =
                ForegroundTransitionTerminalState::Superseded;
            foreground_transition_snapshot->terminal =
                foreground_transition_timestamp_locked();
        }
        ForegroundTransitionSnapshot snapshot;
        snapshot.generation = next_foreground_transition_generation++;
        if (snapshot.generation == 0U)
            snapshot.generation = next_foreground_transition_generation++;
        snapshot.launch_token = launch_token;
        snapshot.input_sequence = input_sequence;
        snapshot.source = std::move(source);
        snapshot.destination = std::move(destination);
        if (pending_foreground_transition_input_completion) {
            snapshot.input_completed =
                pending_foreground_transition_input_completion;
            pending_foreground_transition_input_completion.reset();
        }
        foreground_transition_snapshot = std::move(snapshot);
    }

    void mark_foreground_transition_locked(
        ForegroundTransitionMilestone milestone,
        std::optional<std::uint32_t> process_id = std::nullopt,
        std::uint64_t frame_sequence = 0U)
    {
        if (!foreground_transition_snapshot ||
            foreground_transition_snapshot->terminal_state !=
                ForegroundTransitionTerminalState::Pending)
            return;
        if (process_id) {
            if (!foreground_transition_snapshot->destination ||
                foreground_transition_snapshot->destination->process_id !=
                    *process_id) {
                return;
            }
            const auto process = process_identity_locked(*process_id);
            if (!process ||
                *process != *foreground_transition_snapshot->destination)
                return;
        }
        const auto timestamp = foreground_transition_timestamp_locked();
        switch (milestone) {
        case ForegroundTransitionMilestone::Spawned:
            if (!foreground_transition_snapshot->spawned)
                foreground_transition_snapshot->spawned = timestamp;
            break;
        case ForegroundTransitionMilestone::EventPortReady:
            if (!foreground_transition_snapshot->event_port_ready)
                foreground_transition_snapshot->event_port_ready = timestamp;
            break;
        case ForegroundTransitionMilestone::Lifecycle:
            if (!foreground_transition_snapshot->lifecycle)
                foreground_transition_snapshot->lifecycle = timestamp;
            break;
        case ForegroundTransitionMilestone::SceneCommitted:
            if (!foreground_transition_snapshot->scene_committed)
                foreground_transition_snapshot->scene_committed = timestamp;
            break;
        case ForegroundTransitionMilestone::VsyncDisabled:
            if (!foreground_transition_snapshot->vsync_disabled)
                foreground_transition_snapshot->vsync_disabled = timestamp;
            break;
        case ForegroundTransitionMilestone::VsyncEnabled:
            if (!foreground_transition_snapshot->vsync_enabled)
                foreground_transition_snapshot->vsync_enabled = timestamp;
            break;
        case ForegroundTransitionMilestone::DestinationFirstFrame:
            if (!foreground_transition_snapshot->destination_first_frame) {
                foreground_transition_snapshot->destination_first_frame =
                    timestamp;
                foreground_transition_snapshot
                    ->destination_first_frame_sequence = frame_sequence;
            }
            break;
        }
    }

    void mark_foreground_transition_input_complete_locked()
    {
        const auto timestamp = foreground_transition_timestamp_locked();
        if (!foreground_transition_snapshot ||
            foreground_transition_snapshot->terminal_state !=
                ForegroundTransitionTerminalState::Pending) {
            pending_foreground_transition_input_completion = timestamp;
            return;
        }
        if (!foreground_transition_snapshot->input_completed)
            foreground_transition_snapshot->input_completed = timestamp;
    }

    void note_foreground_transition_content_change_locked(
        std::uint32_t process_id, std::uint64_t content_revision)
    {
        if (!foreground_transition_snapshot || process_id == 0U ||
            foreground_transition_snapshot->terminal_state !=
                ForegroundTransitionTerminalState::Pending ||
            !foreground_transition_snapshot->destination ||
            foreground_transition_snapshot->destination->process_id !=
                process_id ||
            process_identity_locked(process_id) !=
                foreground_transition_snapshot->destination ||
            content_revision == 0U ||
            (foreground_transition_snapshot->last_content_change &&
                foreground_transition_snapshot->last_content_revision ==
                    content_revision)) {
            return;
        }
        const auto timestamp = foreground_transition_timestamp_locked();
        if (!foreground_transition_snapshot->first_content_change) {
            foreground_transition_snapshot->first_content_change = timestamp;
            foreground_transition_snapshot->first_content_revision =
                content_revision;
        }
        foreground_transition_snapshot->last_content_change = timestamp;
        foreground_transition_snapshot->last_content_revision =
            content_revision;
    }

    void mark_foreground_transition_stable_locked()
    {
        if (!foreground_transition_snapshot ||
            foreground_transition_snapshot->terminal_state !=
                ForegroundTransitionTerminalState::Pending)
            return;
        foreground_transition_snapshot->terminal_state =
            ForegroundTransitionTerminalState::Stable;
        foreground_transition_snapshot->terminal =
            foreground_transition_timestamp_locked();
    }

    void mark_foreground_transition_cancelled_for_process_locked(
        std::uint32_t process_id)
    {
        if (!foreground_transition_snapshot ||
            foreground_transition_snapshot->terminal_state !=
                ForegroundTransitionTerminalState::Pending ||
            !foreground_transition_snapshot->destination ||
            foreground_transition_snapshot->destination->process_id !=
                process_id ||
            process_identity_locked(process_id) !=
                foreground_transition_snapshot->destination) {
            return;
        }
        foreground_transition_snapshot->terminal_state =
            ForegroundTransitionTerminalState::Cancelled;
        foreground_transition_snapshot->terminal =
            foreground_transition_timestamp_locked();
    }

    void save_scalar_state(snapshot::Writer& out) const;
    void load_scalar_state(snapshot::Reader& in);
    void save_port_and_event_tables(snapshot::Writer& out) const;
    void load_port_and_event_tables(snapshot::Reader& in);
    void save_process_table(snapshot::Writer& out) const;
    void load_process_table(snapshot::Reader& in);
    void save_key_store_identity(snapshot::Writer& out) const;
    void load_key_store_identity(snapshot::Reader& in);
    void save_service_tables(snapshot::Writer& out) const;
    void load_service_tables(snapshot::Reader& in);

    std::mutex mach_mutex;
    std::shared_ptr<bsd::sandbox::Extensions> sandbox_extensions;
    mutable std::mutex socket_mutex;
    mutable std::mutex filesystem_mutex;
};

[[nodiscard]] inline bool active_application_owns_display_locked(
    const KernelSharedState& state, std::uint32_t process_id,
    std::optional<bool> migrated_scene_committed = std::nullopt)
{
    if (state.application_touch_suspended ||
        state.active_application_event_object == 0U ||
        !state.active_application_scene ||
        state.active_application_scene->process_id != process_id ||
        !migrated_scene_committed.value_or(
            state.active_application_scene->touch_transform.has_value())) {
        return false;
    }
    const auto event_port =
        state.mach_port_objects.lookup(state.active_application_event_object);
    return event_port && event_port->receive_owner == process_id;
}

}
