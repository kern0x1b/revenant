-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_kernel_api")
    set_kind("phony")
    add_deps("emulator_device_state", "emulator_foundation", "emulator_mach", "emulator_filesystem", "emulator_network",
             "emulator_storage", "emulator_telephony", "emulator_media", "emulator_bluetooth", "emulator_crypto",
             "emulator_graphics", "emulator_xnu_adapter", {public = true})

local function library(name, files, deps, opt)
    target(name)
        set_kind("static")
        add_files(files)
        add_deps("emulator_kernel_api", {public = true})
        if deps then
            add_deps(deps)
        end
        if opt and opt.plist then
            add_packages("libplist")
            add_defines("REVENANT_EMULATOR_HAS_LIBPLIST=1")
        end
    target_end()
end

library("emulator_kernel_graphics", {"graphics/core_surface_hle.cpp", "graphics/layerkit_hle.cpp",
        "graphics/mbx2d_hle.cpp", "graphics/mbx3d_quad_hle.cpp", "graphics/mbx_client_surface.cpp",
        "graphics/mbx_swapchain.cpp", "graphics/mobile_framebuffer_hle.cpp",
        "graphics/mobile_framebuffer_devices.cpp", "graphics/opengles_hle.cpp", "graphics/opengles_dispatch_hle.cpp",
        "graphics/core_animation_software_hle.cpp", "graphics/opengles_programmable.cpp",
        "graphics/opengles_shaded.cpp", "graphics/mbx_connect_hle.cpp"})

library("emulator_kernel_bsd_baseband_device", {"bsd/device/baseband/device.cpp", "bsd/device/baseband/offline_control.cpp",
        "bsd/device/baseband/replay.cpp"}, {"emulator_foundation"})
library("emulator_kernel_bsd_debug", {"bsd/debug/tracing.cpp"}, {"emulator_foundation"})
library("emulator_kernel_bsd_sysctl", {"bsd/sysctl/hardware_values.cpp", "bsd/sysctl/name_resolver.cpp",
        "bsd/sysctl/process_arguments.cpp"})
library("emulator_kernel_bsd_signal", {"bsd/signal/frame.cpp", "bsd/signal/signal.cpp"}, {"emulator_foundation"})
library("emulator_kernel_bsd_filesystem_control", {"bsd/filesystem/control.cpp"}, {"emulator_filesystem", "emulator_foundation"})
library("emulator_kernel_bsd_filesystem_ownership", {"bsd/filesystem/ownership.cpp"}, {"emulator_filesystem", "emulator_foundation"})
library("emulator_kernel_bsd_filesystem_locking", {"bsd/filesystem/locking.cpp"}, {"emulator_filesystem", "emulator_foundation"})
library("emulator_kernel_bsd_filesystem_persistence", {"bsd/filesystem/persistence.cpp"}, {"emulator_filesystem", "emulator_foundation"})
library("emulator_kernel_bsd_filesystem_timestamps", {"bsd/filesystem/timestamps.cpp"}, {"emulator_filesystem", "emulator_foundation"})
library("emulator_kernel_bsd_control", {"bsd/network/control/control.cpp", "bsd/network/control/syscalls.cpp"},
        {"emulator_foundation"})
library("emulator_kernel_bsd_virtual_udp", {"bsd/network/virtual_udp.cpp"}, {"emulator_foundation"})
library("emulator_kernel_bsd_virtual_udp_syscalls", {"bsd/network/virtual_udp_syscalls.cpp"},
        {"emulator_kernel_bsd_virtual_udp", "emulator_foundation"})
library("emulator_kernel_bsd_process", {"bsd/process/credentials.cpp", "bsd/process/diagnostics.cpp",
        "bsd/process/information.cpp", "bsd/process/interval_timer.cpp", "bsd/process/memorystatus.cpp",
        "bsd/process/policy.cpp", "bsd/process/resource_monitor.cpp", "bsd/process/uuid_policy.cpp",
        "bsd/process/spawn.cpp"}, {"emulator_foundation"})
library("emulator_kernel_bsd_security", {"bsd/security/code_signing.cpp", "bsd/security/extensions.cpp",
        "bsd/security/mac.cpp", "bsd/security/sandbox.cpp"}, {"emulator_foundation"})
library("emulator_kernel_bsd_vm_shared_region", {"bsd/vm/shared_region.cpp"}, {"emulator_foundation"})

library("emulator_kernel_iokit_audio", {"iokit/audio/device_catalog.cpp", "iokit/audio/abi.cpp",
        "iokit/audio/property_notifications.cpp", "iokit/audio/service.cpp"}, {"emulator_foundation"})
library("emulator_kernel_iokit_baseband", {"iokit/baseband/ip_appender.cpp", "iokit/baseband/service.cpp"},
        {"emulator_foundation"})
library("emulator_kernel_iokit_camera", {"iokit/camera/service.cpp"}, {"emulator_foundation"})
library("emulator_kernel_iokit_display", {"iokit/display/backlight.cpp", "iokit/display/vsync.cpp"}, {"emulator_foundation"},
        {plist = true})
library("emulator_kernel_iokit_graphics", {"iokit/graphics/service.cpp"}, {"emulator_foundation"})
library("emulator_kernel_iokit_hid", {"iokit/hid/service.cpp"}, {"emulator_foundation"})
library("emulator_kernel_iokit_jpeg", {"iokit/jpeg/service.cpp"}, {"emulator_foundation", "emulator_graphics", "emulator_media"})
library("emulator_kernel_iokit_keybag", {"iokit/keybag/service.cpp"}, {"emulator_foundation", "emulator_crypto"})
library("emulator_kernel_iokit_mbx", {"iokit/mbx/service.cpp"}, {"emulator_foundation"})
library("emulator_kernel_iokit_mobile_file_integrity", {"iokit/mobile_file_integrity/service.cpp"}, {"emulator_foundation"})
library("emulator_kernel_iokit_power", {"iokit/battery.cpp", "iokit/environment.cpp", "iokit/power.cpp"},
        {"emulator_foundation"})

library("emulator_kernel_mach_transport", {"mach/transport/descriptor.cpp", "mach/transport/kernel_mach_ipc.cpp"})
library("emulator_kernel_mach_port", {"mach/port/context.cpp", "mach/port/enumeration.cpp", "mach/port/kernel_rpc.cpp",
        "mach/port/guarded.cpp", "mach/port/limits.cpp", "mach/port/membership.cpp"}, {"emulator_foundation"})
library("emulator_kernel_mach_processor", {"mach/processor/processor_set.cpp"}, {"emulator_foundation", "emulator_mach"})
library("emulator_kernel_mach_task", {"mach/task/identity.cpp", "mach/task/info.cpp", "mach/task/enumeration.cpp",
        "mach/task/exception_ports.cpp"}, {"emulator_foundation", "emulator_mach"})
library("emulator_kernel_mach_thread", {"mach/thread/creation.cpp", "mach/thread/lifecycle.cpp", "mach/thread/self.cpp",
        "mach/thread/state.cpp"}, {"emulator_foundation", "emulator_mach"})
library("emulator_kernel_mach_vm", {"mach/vm/allocate.cpp", "mach/vm/copy.cpp", "mach/vm/deallocate.cpp",
        "mach/vm/inherit.cpp", "mach/vm/kernel_rpc.cpp", "mach/vm/map.cpp", "mach/vm/memory_entry.cpp",
        "mach/vm/protect.cpp", "mach/vm/purgable.cpp", "mach/vm/read.cpp", "mach/vm/remap.cpp", "mach/vm/region.cpp"},
        {"emulator_foundation"})

target("emulator_kernel_mach_input")
    set_kind("static")
    add_files("mach/input/graphics_services.cpp", "mach/input/graphics_services_input_abi.cpp")
    add_deps("emulator_kernel_api", "emulator_foundation", "emulator_mach", {public = true})

target("emulator_kernel")
    set_kind("static")
    add_files("kernel.cpp", "commpage.cpp", "hid_event_system_hle.cpp", "hid_event_transaction.cpp",
              "hid_switch_query.cpp", "clock.cpp", "iokit.cpp", "iokit/diagnostic_data.cpp", "vnode_watch.cpp",
              "kevent_timer.cpp", "network.cpp")
    add_files("bsd/dispatch.cpp", "bsd/platform.cpp", "bsd/pthread_runtime.cpp", "bsd/psynch_runtime.cpp",
              "bsd/psynch.cpp", "bsd/aio.cpp", "bsd/audit_session.cpp", "bsd/guarded_file.cpp", "bsd/fileport.cpp",
              "bsd/process.cpp", "bsd/posix_semaphore.cpp", "bsd/filesystem.cpp", "bsd/descriptor_lifecycle.cpp",
              "bsd/descriptor_memory.cpp", "bsd/bpf.cpp", "bsd/socket.cpp", "bsd/network/process_sockets.cpp",
              "bsd/events.cpp", "bsd/kqueue.cpp", "bsd/device/offline_serial.cpp", "bsd/support.cpp")
    add_files("mach/support.cpp", "mach/ipc.cpp", "mach/kevent_receive.cpp", "mach/semaphore.cpp",
              "mach/message.cpp", "mach/host_message.cpp", "mach/port_message.cpp", "mach/task_vm_message.cpp",
              "mach/rights_message.cpp", "mach/notification_message.cpp", "mach/send_possible.cpp", "mach/traps.cpp")
    add_deps("emulator_kernel_api", {public = true})
    add_deps("emulator_kernel_bsd_baseband_device", "emulator_kernel_bsd_control", "emulator_kernel_bsd_debug",
             "emulator_kernel_bsd_filesystem_control", "emulator_kernel_bsd_filesystem_persistence",
             "emulator_kernel_bsd_filesystem_timestamps", "emulator_kernel_bsd_filesystem_locking",
             "emulator_kernel_bsd_filesystem_ownership", "emulator_kernel_bsd_virtual_udp_syscalls",
             "emulator_kernel_bsd_virtual_udp", "emulator_kernel_bsd_process", "emulator_kernel_bsd_security",
             "emulator_kernel_bsd_vm_shared_region", "emulator_kernel_bsd_signal", "emulator_kernel_bsd_sysctl")
    add_deps("emulator_kernel_mach_transport", "emulator_kernel_mach_port", "emulator_kernel_mach_processor",
             "emulator_kernel_mach_task", "emulator_kernel_mach_thread", "emulator_kernel_mach_vm", "emulator_kernel_mach_input")
    add_deps("emulator_kernel_graphics", "emulator_device_state", "emulator_kernel_iokit_audio", "emulator_kernel_iokit_baseband",
             "emulator_kernel_iokit_camera", "emulator_kernel_iokit_power", "emulator_kernel_iokit_display",
             "emulator_kernel_iokit_graphics", "emulator_kernel_iokit_hid", "emulator_kernel_iokit_jpeg",
             "emulator_kernel_iokit_keybag", "emulator_kernel_iokit_mbx", "emulator_kernel_iokit_mobile_file_integrity")
