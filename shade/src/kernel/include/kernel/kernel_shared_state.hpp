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

namespace shade {

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
    // Darwin 9.3/10.0's iopolicysys(2) keeps the disk policy separately for
    // the process and current thread. These are the old four-policy values;
    // later XNU iotypes and policy values are intentionally not represented in
    // this Guest ABI state.
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
    // EVFILT_MACHPORT readiness is immutable while the shared Mach queue
    // generation is unchanged. Cache only a negative observation; positive
    // readiness is always re-evaluated so consuming a message cannot leave a
    // stale ready result.
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
    // mach_msg resolves the task-local name when the receive starts, then
    // blocks on the ipc object. Cache that object after the first resolution so
    // scheduler polling does not repeatedly walk the task namespace.
    std::optional<std::uint32_t> receive_object;
    // Preserve whether the initial lookup selected a port set. A direct waiter
    // that later joins a set remains attached to its port object, whereas a
    // waiter that started on a port set continues to use that set object after
    // its name is renamed.
    bool receive_is_port_set { };
    // The shared queue generation observed while this receive last found no
    // message. A new enqueue or a port-set addition advances the generation,
    // while an unchanged value proves another locked tree walk cannot succeed.
    std::uint64_t observed_queue_generation { };
    // XNU places a blocked receiver into a FIFO wait queue. Keep the insertion
    // order so a port linked to more than one port set wakes the same waiter
    // that ipc_mqueue_post would select, rather than whichever emulated CPU is
    // polled first.
    std::uint64_t wait_queue_sequence { };
    // When the receive started, so a run can say how long a thread has been
    // waiting for a reply that never came, and, when the receive follows the
    // send of the same mach_msg, which request it is waiting on. A daemon
    // parked on its service port waits forever by design; a thread waiting for
    // a reply to a request it sent is a stall.
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

// A local stream endpoint is an open file description, not an fd.  dup(2),
// fork(2), and SCM_RIGHTS all retain the same description; the peer observes
// close/EOF only after the final reference has gone away.
struct SocketPairLifetime {
    std::array<std::atomic_bool, 2> read_open { true, true };
    std::array<std::atomic_bool, 2> write_open { true, true };
    // Absolute receive positions are protected by KernelSharedState's socket
    // mutex. They bind SOCK_STREAM ancillary records to the byte that carried
    // them even while ordinary and recvmsg reads are interleaved.
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
            // Literal MACH_PORT_DEAD elements carry no capability. Null
            // elements are implicit; live rights use PortTransfer instead.
            std::vector<std::uint32_t> dead_elements;
        };

        std::vector<std::byte> bytes;
        std::uint32_t destination { };
        std::uint32_t sender_pid { };
        std::uint32_t sender_identity_version { };
        // Set only for Guest-originated messages while CPU diagnostics are
        // enabled. This is host monotonic time, deliberately separate from the
        // Guest mach_absolute_time domain used by the probe.
        std::uint64_t host_enqueue_nanoseconds { };
        std::uint32_t sender_uid { };
        std::uint32_t sender_gid { };
        std::uint64_t graphics_input_sequence { };
        GraphicsInputKind graphics_input_kind { GraphicsInputKind::None };
        std::optional<TouchPhase> graphics_touch_phase;
        // Kernel-originated display notifications can share one Mach receive
        // port across successive or concurrent IOUserClient registrations. Keep
        // their host-only origin separate from the guest payload so coalescing
        // and cancellation affect only the registration that produced them.
        std::optional<std::uint32_t> display_vsync_connection_object;
        std::uint64_t display_vsync_registration_generation { };
        // Host-only identity of the exact notification instance. It never
        // enters the Mach payload and exists only to join a successful receive
        // to the firmware callback that follows it.
        std::uint64_t display_vsync_sequence { };
        std::vector<OolPayload> ool_payloads;
        std::vector<OolPortArray> ool_port_arrays;
        std::optional<std::uint32_t> reply_object;
        std::optional<xnu::ipc::Right> reply_right;
        // A MOVE_SEND used as the message's remote port has no sender ipc_entry
        // after copyin, but the queued message still keeps the destination port
        // alive until receive/discard. Record that hold explicitly.
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
        // Host scheduler state is kept outside the process record; this flag
        // only records the Darwin pid-level suspension requested by guest
        // process control so repeated resume operations remain observable.
        bool pid_suspended { };
        // Job-control suspension is an independent scheduler hold. SIGCONT
        // must release this hold without undoing a concurrent pid_suspend.
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
        // A PID can be reused after its zombie record is reaped. Keep a
        // monotonic product-internal identity so transition observations never
        // join facts from two different processes that share a PID.
        std::uint64_t incarnation { };
        std::uint64_t parent_incarnation { };
        std::uint64_t start_wall_nanoseconds { };
        std::array<std::byte, 16> executable_uuid { };
        // Audit tokens distinguish both PID reuse and replacement by exec.
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
        // Connection object named by IOConnectAddClient.  The SGX shared
        // connection and its context connection use separate user-client ports,
        // while selector 4 resolves the context's shared mapping through this
        // task-local relationship.
        std::uint32_t shared_connection_object { };
        // Opaque four-byte result returned by the firmware's shared-resource
        // method. It identifies the connection-local namespace; it is not a
        // host pointer and is never dereferenced by the emulator.
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
        // Host-only observation of the guest thread that most recently entered
        // the real framebuffer notification callback. It is used only to choose
        // a bounded scheduler lease; it is not exposed to the guest and does
        // not affect VSync messages, deadlines, or callback semantics.
        std::optional<std::uint32_t> last_callback_processor;
        // The receive can complete synchronously inside mach_msg while its
        // Guest thread is already running, bypassing the host polling wake
        // path. Retain that exact processor and notification sequence until
        // NotifyFunc consumes it so the scheduler can continue the real
        // callback dependency chain.
        std::optional<std::uint32_t> last_receiver_processor;
        std::uint64_t receiver_sequence { };
        // Host-only completion watermark for queued VSync notifications. The
        // sequence advances only when a real Mach message is enqueued, and this
        // watermark catches up when firmware enters NotifyFunc. Their
        // difference identifies an actual callback handoff that still needs
        // Guest CPU time; it is never exposed in the notification payload.
        std::uint64_t callback_sequence { };
        // SwapEnd retires the callback work begun at NotifyFunc. Keeping this
        // separate from callback_sequence lets the host scheduler follow the
        // real callback processor through frame assembly without extending the
        // queued Mach-message lifetime or changing any Guest-visible
        // notification state.
        std::uint64_t swap_sequence { };
        // Guest-visible frame time of the last notification actually queued.
        // Timer scheduling may skip overdue physical pulses to avoid a busy
        // catch-up loop, but an animation client must still receive adjacent
        // frame times when it is slower than the emulated panel.
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
        // A physical Lock is held, but the guest has not yet asked the panel to
        // turn off. Keep the panel visible so SpringBoard can present its
        // native power-down controller for a long press.
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
        // A foreground App can ask SpringBoard to open another App without an
        // icon touch. Keep that transaction distinct from an ordinary desktop
        // launch so the firmware's handoff animation runs exactly once.
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
        // A Lock transaction owns the exact resident scene that was foreground
        // when the barrier was raised. Unlike the general suspension slot, this
        // identity survives asynchronous UIKit lifecycle notifications until
        // the matching unlock transaction consumes it.
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
    // Dead-name and send-possible requests share one ipc_entry notification
    // slot, so replacement, rename and right teardown use the same lifecycle.
    struct MachDeadNameNotificationRequest {
        std::uint32_t target_object { };
        std::uint32_t notify_object { };
        std::uint32_t sync { };
        bool send_possible { };
        bool armed { };
    };
    // The caller must hold mach_mutex. This allocates a global ipc_port object
    // identifier, never a task-local Mach name. The stride keeps synthetic
    // object identifiers distinct from the fixed early-boot objects while
    // task-local names remain exclusively owned by MachNamespaceTable.
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
    // Global ipc_port objects. Per-task names and rights live exclusively in
    // MachNamespaceTable and resolve to keys in this table.
    xnu::ipc::PortObjectTable mach_port_objects;
    // XNU exposes an opaque context value on receive rights. The value
    // follows the ipc_port object when its receive right moves between tasks.
    std::map<std::uint32_t, std::uint64_t> mach_port_contexts;
    // Audit sessions expose stable kernel-owned receive objects. Processes
    // hold ordinary Send names and can use those capabilities to join.
    std::map<std::uint32_t, std::uint32_t> audit_session_port_objects;
    // XNU's mach_ports_register stash is inherited by forked tasks and exposed
    // as fresh Send rights by mach_ports_lookup. These are kernel-held object
    // references, not task-local names.
    std::map<std::uint32_t, std::array<std::uint32_t, 3>> mach_registered_ports;
    // Send rights captured by queued messages count as extant for no-senders
    // even though they no longer need a sender-local ipc_entry.
    std::map<std::uint32_t, std::uint32_t> mach_inflight_send_rights;
    // Kernel-owned task metadata (for example task special ports) retains a
    // Send-like reference independently of every guest ipc_space. Keep that
    // reference visible to no-senders and transient-object reclaimers.
    std::map<std::uint32_t, std::uint32_t> mach_kernel_send_rights;
    // Port teardown can discard a queued right that points back to the same
    // object. Keep removal idempotent while that recursive ipc_right path is
    // unwinding; otherwise the queue sidecar is visited after its owner has
    // already been moved out and freed.
    std::set<std::uint32_t> mach_ports_being_removed;
    struct MachPortSetLink {
        std::uint32_t set_object { };
        std::uint64_t wait_queue_sequence { };
    };
    std::map<std::uint32_t, std::vector<std::uint32_t>> mach_port_sets;
    // XNU links a port's wait queue to every containing port-set wait
    // queue. The links share FIFO order with direct receive waiters, so the
    // reverse topology and its insertion sequence are semantic state rather
    // than a derived lookup cache.
    std::map<std::uint32_t, std::vector<MachPortSetLink>>
        mach_port_set_links_by_member;
    // XNU keeps a prepost queue for each port set. A member is linked
    // while its message queue is non-empty and is moved to the tail after a
    // receive, so a busy timer port cannot starve an input port in the same
    // set. Keep this ready-member order separate from the membership order
    // returned by mach_port_get_set_status.
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
    // These maps are keyed by global IPC object identifiers, never by a
    // caller's task-local Mach name. Keep task identity separate from generic
    // receive ownership so pid_for_task cannot mistake a service for a task.
    std::map<std::uint32_t, std::uint32_t> task_port_pids;
    // XNU exposes itk_nself as a distinct, read-only task-name capability.
    // Keeping it separate prevents task_name_for_pid from accidentally
    // granting task-control MIG operations through an identity-only port.
    std::map<std::uint32_t, std::uint32_t> task_name_port_pids;
    // Global thread-port objects indexed by task PID and that task's logical
    // thread slot. Task-local names are produced only when a caller receives
    // task_threads(), preserving ipc_space separation.
    std::map<std::uint32_t, std::map<std::uint32_t, std::uint32_t>>
        task_thread_port_objects;
    std::map<std::uint32_t, std::map<std::uint32_t, std::uint32_t>>
        task_special_ports;
    // XNU stores exception actions on the task object, not in the caller's
    // task-local IPC namespace. Port fields therefore use global IPC objects.
    std::map<std::uint32_t, TaskExceptionActions> task_exception_actions;
    std::map<std::uint32_t, std::deque<MachMessage>> mach_queues;
    // Queue producers may run on host input/device threads while guest kernels
    // poll from the scheduler. Keep the cheap readiness snapshot lock-free;
    // the queue and every generation transition remain serialized by
    // mach_mutex.
    std::atomic_uint64_t mach_queue_generation { 1 };
    // Timer/deadline topology can change at any Guest kernel entry. Keep this
    // conservative generation separate from descriptor readiness: ordinary
    // syscalls must not invalidate every unrelated blocked kqueue.
    std::atomic_uint64_t kernel_event_generation { 1 };
    // Process-local deadline trees are cached by their owning kernel. The
    // shared half is computed once per conservative generation instead of
    // making every process rescan the same Mach/device timer collections.
    // These cache fields are protected by mach_mutex.
    std::uint64_t shared_timer_deadline_cache_generation { };
    std::optional<std::uint64_t> shared_timer_deadline_cache;
    bool shared_timer_deadline_cache_valid { };
    // Non-Mach readiness producers advance this generation at the mutation
    // boundary. Asynchronous host descriptors remain protected by their
    // bounded wall-clock probe cadence.
    std::atomic_uint64_t io_event_generation { 1 };

    // The caller holds mach_mutex. Centralizing enqueue makes it impossible for
    // a new message source to publish data without also waking cached empty
    // receives on the next scheduler pass.
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

    // The caller holds mach_mutex. Deliver armed name notifications when a
    // destination can accept another message.
    void notify_send_possible_locked(std::uint32_t destination);

    // Remove empty members from every prepost queue after delivery/discard.
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

    // Adding a populated port to a set can make an already queued message
    // newly visible without enqueueing another message.
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
    // launchd remains the authority for the bootstrap namespace. These caches
    // only remember replies already observed on the emulated Mach IPC path so
    // host devices can address the same global ipc_port objects.
    // A Mach reply port can carry more than one outstanding bootstrap request.
    // Replies preserve queue order, so retain every lookup/check-in instead of
    // letting a later request overwrite the service and expected right kind.
    std::map<std::uint32_t, std::deque<PendingBootstrapServiceRequest>>
        pending_bootstrap_service_requests;
    // An on-demand application's event service is still owned by launchd when
    // SpringBoard receives its lookup reply. Preserve that exact lookup intent
    // on the global port until the firmware event is consumed by the process
    // that ultimately checks in the receive right.
    std::map<std::uint32_t, PendingApplicationEventLaunch>
        pending_application_event_launches;
    std::map<std::string, std::uint32_t> bootstrap_service_objects;
    // A failed bootstrap lookup is commonly followed by a bounded polling
    // sleep while launchd starts an on-demand provider. Track the precise
    // service condition so registration can wake that retry without waiting
    // for an unrelated fixed timeout.
    std::map<std::uint32_t, PendingTimer::BootstrapRetry>
        pending_bootstrap_retries;
    std::map<std::string, std::uint64_t> bootstrap_service_generations;
    // A successful bootstrap_check_in is an observable guest boot milestone:
    // launchd accepted a service provider and transferred its receive right.
    // Keep names only to deduplicate retries; status reporting exposes a count
    // and does not depend on any firmware-specific service name.
    std::set<std::string> bootstrap_checked_in_services;
    // Provider identity comes from the firmware's launchd job declarations.
    // Load it once per emulated boot so every process observes the same
    // bootstrap namespace without rescanning plists during each lookup.
    std::once_flag launchd_job_catalog_once;
    std::optional<LaunchdJobCatalog> launchd_job_catalog;
    // A Purple application registers a bootstrap service backed by its own
    // receive right. When SpringBoard resolves that service, retain the global
    // port object so host touch input can follow Purple's foreground routing.
    std::uint32_t pending_application_event_object { };
    std::uint32_t active_application_event_object { };
    // Lifecycle delivery proves the exact UIKit event receive right even when a
    // later Home/alert transition clears the semantic foreground pointer. Keep
    // the PID-bound identity until process retirement so a completed display
    // transaction can resolve the visible producer without guessing a service.
    std::map<std::uint32_t, std::uint32_t> application_event_objects_by_process;
    bool application_touch_suspended { };
    ApplicationSuspensionReason application_suspension_reason {
        ApplicationSuspensionReason::None
    };
    std::optional<std::uint32_t> suspended_application_scene_process_id;
    std::uint64_t next_graphics_input_sequence { 1 };
    // A single-touch contact keeps one receiver and coordinate space from Down
    // through its terminal event, even if presentation changes mid-gesture.
    std::optional<GraphicsTouchRoute> active_graphics_touch_route;
    std::uint64_t springboard_last_consumed_touch_sequence { };
    // Launch causality belongs to the gesture that selected an icon, not its
    // final Up delivery. Home cancels that gesture; Lock only holds it until a
    // successful unlock.
    std::uint64_t springboard_active_touch_begin_sequence { };
    std::uint64_t springboard_last_touch_begin_sequence { };
    // At most one SpringBoard gesture may nominate the next foreground App.
    // Bootstrap lookups and spawn consume this exact sequence; historical
    // touches must never turn unrelated resident-service probes into launches.
    std::uint64_t springboard_pending_launch_touch_sequence { };
    // Input can be waiting in SpringBoard's Mach queue when a host Lock/Home
    // command arrives. Keep the host-enqueue gesture boundary as well as the
    // receive-side boundary above so a loaded guest cannot lose launch
    // causality merely because it has not drained the touch message yet.
    std::uint64_t springboard_enqueued_active_touch_begin_sequence { };
    std::uint64_t springboard_enqueued_last_touch_begin_sequence { };
    std::uint64_t springboard_enqueued_last_touch_end_sequence { };
    float springboard_enqueued_last_touch_end_x { };
    float springboard_enqueued_last_touch_end_y { };
    // The first SpringBoard-directed gesture after Home wakes a locked display
    // is the unlock gesture, not an application-launch intent. Retain its exact
    // sequence range so service lookups caused by unlock cannot revive a held
    // launch attempt.
    bool springboard_unlock_touch_pending { };
    bool springboard_unlock_touch_active { };
    // LCD power-off is also used for idle dimming. Retain the firmware's own
    // answer so a wake does not turn the next desktop tap into an unlock drag.
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
    // One active immutable observation is sufficient for the current
    // foreground handoff. Replacing it is explicit and bounded; no event path
    // may grow an unbounded trace buffer or use this state to make a decision.
    std::optional<ForegroundTransitionSnapshot> foreground_transition_snapshot;
    // Host control can finish a gesture before the guest creates the PID-bound
    // launch attempt. Keep only that one latest boundary so a late snapshot can
    // still report the real input-complete timestamp without retaining a trace.
    std::optional<ForegroundTransitionTimestamp>
        pending_foreground_transition_input_completion;
    std::optional<ApplicationLaunchBarrier> application_launch_barrier;
    // Home is a cancellation watermark independent of the latest Lock barrier.
    // Keeping it monotonic prevents a later Lock from reviving an older launch.
    std::uint64_t last_home_launch_barrier_sequence { };
    // Every attempt is bound to an exact PID and a reliable SpringBoard target
    // event. Scene/lifecycle callbacks may observe an attempt but never create
    // one, so an old callback cannot consume a newer foreground intent.
    std::map<std::uint32_t, ApplicationLaunchAttempt>
        application_launch_attempts;
    std::optional<std::uint32_t> foreground_application_attempt_process_id;
    // A Lock holds one exact foreground launch. The token may initially contain
    // only the selecting gesture; a later spawn or service lookup binds its
    // PID. Unlock records completion but activation remains owned by the
    // firmware's subsequent lifecycle/scene commit.
    std::optional<HeldApplicationLaunch> held_application_launch;
    // Lock can preempt an already-running Home exit after SpringBoard has
    // committed only a partial desktop transform. A deliberate unlock then
    // requests one final Home redraw, even if the outgoing App has exited.
    std::optional<std::uint64_t> interrupted_home_exit_lock_sequence;
    // IOSurface transports send a kernel-owned Mach port instead of exposing a
    // process-local client pointer. Keep the object-to-surface association in
    // shared kernel state so a receiving task can import the same backing.
    std::map<std::uint32_t, std::uint32_t> surface_transport_port_surfaces;
    std::map<std::uint32_t, std::uint32_t> surface_transport_surface_ports;
    std::map<std::uint32_t, std::shared_ptr<SurfaceTransportLease>>
        surface_transport_port_leases;
    // CoreSurface publication sequences are immutable even if a transport ID
    // or PID is later reused. Track only full-screen application publications:
    // SpringBoard's home-screen icons also retain application provenance and
    // must never be hidden merely because that application was interrupted.
    std::map<std::uint32_t, std::set<std::uint64_t>>
        application_fullscreen_surface_publications;
    // While a launch is causally interrupted, new full-screen publications
    // from that producer are suppressed as well as the ones already known.
    std::set<std::uint32_t>
        suppress_future_application_fullscreen_surface_processes;
    std::set<std::pair<std::uint32_t, std::uint64_t>>
        suppressed_application_fullscreen_surface_publications;
    std::atomic_bool application_fullscreen_surface_suppression_active {
        false
    };
    // A physical Lock is only a pending host transaction until the firmware's
    // IOKit power request arrives. Once a wake begins, the trailing panel-off
    // request from the preceding Lock must not turn the newly woken display
    // black. Keep the power transaction separate from the guest-visible Home
    // and Lock events.
    HostDisplayIntent host_display_intent {
        HostDisplayIntent::GuestControlled
    };
    // Each Lock Down starts one asynchronous SpringBoard panel-off request.
    // Keep all unresolved generations: under load an older request can arrive
    // several seconds after a later wake/lock cycle has already begun.
    std::deque<std::uint64_t> host_display_pending_lock_power_off_sequences;
    std::uint64_t host_display_current_lock_down_sequence { };
    std::uint64_t host_display_wake_after_lock_sequence { };
    bool host_display_wake_power_on_acknowledged { };
    // Physical Home and Sleep/Wake own the hardware power domain. They may
    // reveal the retained lock scene before SpringBoard catches up, but never
    // change the identity of the event delivered to the guest.
    bool host_display_hardware_wake_pending { };
    std::map<std::pair<std::uint32_t, std::uint32_t>, std::uint32_t>
        application_scene_context_owners;
    std::map<std::uint32_t, ApplicationTouchTransform>
        application_scene_transforms;
    std::optional<PendingApplicationSceneTransform>
        latest_application_scene_transform;
    std::optional<ActiveApplicationScene> active_application_scene;
    // A normal App-to-App handoff can deliver willResignActive before
    // SpringBoard spawns the replacement. Retain that one process identity
    // across the route teardown so the replacement spawn remains a foreground
    // intent without borrowing an unrelated touch sequence.
    std::optional<std::uint32_t> pending_application_handoff_process_id;
    // SpringBoard's firmware separates alerts handled by the lock scene from
    // ordinary modal overlays. Preserve that presentation as well as activation
    // order: a lock-scene item retained underneath an App cannot intercept the
    // App, while a newer application overlay can. Object identity keeps nested
    // and repeated callbacks balanced.
    std::uint64_t next_foreground_layer_sequence { 1 };
    std::uint64_t active_application_layer_sequence { };
    std::map<std::uint32_t, SpringBoardAlertLayer>
        active_springboard_alert_items;
    std::deque<PendingGraphicsInput> pending_graphics_inputs;
    std::map<std::uint32_t, MachSemaphore> mach_semaphores;
    // POSIX named semaphores use file descriptors in Darwin userland while
    // sharing the same kernel semaphore primitive underneath.
    std::map<std::string, std::uint32_t> posix_named_semaphore_objects;
    std::map<std::uint32_t, MachTimer> mach_timers;
    std::map<std::uint32_t, ProcessIntervalTimer> process_interval_timers;
    // XNU named-memory entries are kernel ipc_port objects. The per-task Mach
    // namespace carries rights; this table carries the referenced VM object.
    std::map<std::uint32_t, MachMemoryEntry> mach_memory_entries;
    // BSD fileports are send-only Mach objects whose payload is a transferable
    // open-file description. The key is the global object identifier; callers
    // hold mach_mutex while accessing this table.
    std::map<std::uint32_t, DescriptorTransfer> mach_fileports;
    std::map<std::uint64_t, ClockAlarm> clock_alarms;
    std::uint64_t next_clock_alarm { 1 };
    std::map<std::pair<std::uint32_t, std::uint32_t>, MachNotificationRequest>
        mach_notifications;
    std::map<std::pair<std::uint32_t, std::uint32_t>,
        MachDeadNameNotificationRequest>
        mach_dead_name_notifications;
    // A conservative index: cancellation can leave an entry until its next
    // dequeue. This avoids scanning all name notifications on ordinary IPC.
    std::set<std::uint32_t> mach_send_possible_armed_destinations;
    std::set<std::pair<std::uint32_t, std::uint32_t>> semaphore_wakeups;
    // Destruction wakes semaphore waiters with KERN_TERMINATED rather than as a
    // successful signal. Keep that result distinct from ordinary wakeups while
    // the owning CompatibilityKernel instances finish their blocked traps.
    std::set<std::pair<std::uint32_t, std::uint32_t>> semaphore_terminations;
    std::map<std::uint32_t, std::deque<std::uint32_t>> iokit_iterators;
    std::map<std::uint32_t, IOKitService> iokit_services;
    std::uint32_t iokit_registry_root_object {
        mach_task_identity::initial_io_registry_options_name
    };
    std::map<std::uint32_t, IOKitConnection> iokit_connections;
    std::map<std::uint32_t, IOKitInterestNotification>
        iokit_interest_notifications;
    // Keyed by the global IOUserClient connection object. The notification
    // port is also a global ipc_port object, never a task-local Mach name.
    std::map<std::uint32_t, IOKitDisplayVSync> iokit_display_vsync;
    std::uint64_t iokit_display_vsync_registration_generation { };
    // Enabled registrations are indexed by their next timer deadline so the
    // kernel deadline path does not scan every display connection.
    std::set<std::pair<std::uint64_t, std::uint32_t>>
        iokit_display_vsync_deadlines;
    // Monotonic product-internal display pulse attribution. This is diagnostic
    // state only; it does not participate in the guest-visible VSync message
    // sequence or in deadline selection.
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
    // The physical panel has one power state even though GraphicsServices and
    // LayerKit can open separate IOMobileFramebuffer user clients.
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
    // IOAudio2 publishes independent Codec/Baseband-style endpoints. Key by
    // firmware-facing UID so a released service can be recreated independently.
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
    // A pathname is a registry entry, not an owner. The listening open file
    // description is retained by duplicated/inherited/transferred guest fds.
    std::map<std::string, std::weak_ptr<UnixListener>> unix_listeners;
    // bind(2) creates an AF_UNIX namespace node. Closing the socket does not
    // unlink that node; the guest must remove it explicitly, just as on XNU.
    std::set<std::string> unix_socket_nodes;
    std::uint32_t next_shared_memory_object { 1 };
    std::map<std::string, std::filesystem::path> shared_memory_objects;
    // POSIX shared-memory objects use host files only as volatile pager
    // storage. Keep their backing identity after shm_unlink so inherited/open
    // descriptors never acquire ordinary-file persistence by accident.
    std::set<std::filesystem::path> volatile_shared_memory_backings;
    // File-backed MAP_SHARED mappings use one physical page cache across tasks.
    // Guest stores become immediately visible through every mapping of the same
    // file identity, and dirty pages are persisted when mappings are released.
    std::shared_ptr<GuestFileGenerationRegistry>
        guest_file_generation_registry {
            std::make_shared<GuestFileGenerationRegistry>()
        };
    std::shared_ptr<FilePageCache> shared_mapping_page_cache {
        std::make_shared<FilePageCache>(
            FilePageCacheLimits { }, guest_file_generation_registry)
    };
    // Hard links have distinct catalog IDs but share one HFS file record.
    // Metadata mutations therefore follow the permanent inode identity.
    std::map<std::uint32_t, hfs::MetadataOverride> hfs_metadata_overrides;
    // A disengaged value is a guest-side removal tombstone hiding an
    // attribute preserved in the immutable extracted firmware tree.
    std::map<std::uint32_t,
        std::map<std::string, std::optional<std::vector<std::byte>>>>
        hfs_named_attribute_overrides;
    // LaunchServices installs this global XNU VFS table through
    // FSIOC_SET_PACKAGE_EXTS. HFS search/path-package operations consult the
    // extension names independently of the process that registered them.
    std::vector<std::string> package_extensions;
    std::map<std::uint32_t, ProcessRecord> processes;
    // EVFILT_PROC is edge-triggered and may outlive the process-table zombie.
    // Retain compact per-PID generations so an exec/exit between kevent
    // registration and the next scheduler poll cannot be lost.
    std::map<std::uint32_t, ProcessKeventState> process_kevent_states;
    std::shared_ptr<bsd::AdvisoryFileLockRegistry> advisory_file_locks {
        std::make_shared<bsd::AdvisoryFileLockRegistry>()
    };
    std::shared_ptr<DarwinPsynchRuntime> psynch_runtime {
        std::make_shared<DarwinPsynchRuntime>()
    };

    // The caller holds mach_mutex. Observe only the boundary executed by the
    // firmware callback; no host-generated callback or payload interpretation
    // participates in this bookkeeping.
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
            // Prefer the exact successfully received notification. A later
            // pulse may already be queued after this message left the Mach
            // queue; retiring registration.sequence here would hide that newer
            // callback dependency.
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

    // The caller holds mach_mutex. Some framebuffer callbacks proceed directly
    // from their Mach receive to frame construction without querying the
    // notification count. SwapBegin is then the first common firmware boundary
    // that proves the already-received notification entered its callback. Do
    // not consume a merely queued pulse here: only the receive watermark may
    // advance callback ownership.
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

    // The caller holds mach_mutex. Observe only a successful Mach copyout of a
    // real kernel-generated VSync message. Registration generation prevents a
    // stale queued message from attaching to a replacement IOUserClient.
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

    // The caller holds mach_mutex. Retire only callback work that has reached
    // the firmware's real SwapEnd boundary; a newer queued notification remains
    // represented by registration.sequence and is unaffected.
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

    std::mutex mach_mutex;
    std::shared_ptr<bsd::sandbox::Extensions> sandbox_extensions;
    mutable std::mutex socket_mutex;
    mutable std::mutex filesystem_mutex;
};

// The caller must hold mach_mutex. A remote application may own cached scene
// state while suspended, and a prelaunched application may publish a scene
// before SpringBoard promotes its event port. Only the intersection with a
// currently active semantic scene is the visible App allowed to write the
// panel. A disengaged migrated_scene_committed retains the legacy transform
// fallback.
[[nodiscard]] inline bool active_application_owns_display_locked(
    const KernelSharedState& state, std::uint32_t process_id,
    std::optional<bool> migrated_scene_committed = std::nullopt)
{
    // The outgoing App remains sampleable as a texture for SpringBoard's native
    // shrink animation, but suspension immediately revokes direct panel
    // ownership. Conflating the two lets a late first App frame flash
    // fullscreen after Home.
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

} // namespace shade
