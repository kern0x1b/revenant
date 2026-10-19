# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_kernel_api INTERFACE)
add_library(Shade::kernel_api ALIAS shade_kernel_api)
target_include_directories(shade_kernel_api INTERFACE
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>")
target_link_libraries(shade_kernel_api INTERFACE
    Shade::device_state
    Shade::foundation
    Shade::mach
    Shade::filesystem
    Shade::network
    Shade::storage
    Shade::telephony
    Shade::media
    Shade::bluetooth
    Shade::crypto
    Shade::graphics
    Shade::xnu_adapter)

add_library(shade_kernel STATIC
    kernel.cpp
    commpage.cpp
    hid_event_system_hle.cpp
    hid_event_transaction.cpp
    hid_switch_query.cpp
    clock.cpp
    iokit.cpp
    iokit/diagnostic_data.cpp
    vnode_watch.cpp
    kevent_timer.cpp
    network.cpp)
add_library(Shade::kernel ALIAS shade_kernel)
shade_configure_module(shade_kernel)

add_library(shade_kernel_graphics STATIC
    graphics/core_surface_hle.cpp
    graphics/layerkit_hle.cpp
    graphics/mbx2d_hle.cpp
    graphics/mbx3d_quad_hle.cpp
    graphics/mbx_client_surface.cpp
    graphics/mbx_swapchain.cpp
    graphics/mobile_framebuffer_hle.cpp
    graphics/mobile_framebuffer_devices.cpp
    graphics/opengles_hle.cpp
    graphics/opengles_dispatch_hle.cpp
    graphics/core_animation_software_hle.cpp
    graphics/opengles_programmable.cpp
    graphics/opengles_shaded.cpp
    graphics/mbx_connect_hle.cpp)
add_library(Shade::kernel_graphics ALIAS shade_kernel_graphics)
shade_configure_module(shade_kernel_graphics)

add_library(shade_kernel_bsd_baseband_device STATIC
    bsd/device/baseband/device.cpp
    bsd/device/baseband/offline_control.cpp
    bsd/device/baseband/replay.cpp)
add_library(Shade::kernel_bsd_baseband_device ALIAS
    shade_kernel_bsd_baseband_device)
shade_configure_module(shade_kernel_bsd_baseband_device)
target_link_libraries(shade_kernel_bsd_baseband_device PRIVATE
    Shade::foundation)

add_library(shade_kernel_bsd_debug STATIC
    bsd/debug/tracing.cpp)
add_library(Shade::kernel_bsd_debug ALIAS
    shade_kernel_bsd_debug)
shade_configure_module(shade_kernel_bsd_debug)
target_link_libraries(shade_kernel_bsd_debug PRIVATE
    Shade::foundation)

add_library(shade_kernel_bsd_sysctl STATIC
    bsd/sysctl/hardware_values.cpp
    bsd/sysctl/name_resolver.cpp
    bsd/sysctl/process_arguments.cpp)
add_library(Shade::kernel_bsd_sysctl ALIAS
    shade_kernel_bsd_sysctl)
shade_configure_module(shade_kernel_bsd_sysctl)

add_library(shade_kernel_bsd_signal STATIC
    bsd/signal/frame.cpp
    bsd/signal/signal.cpp)
add_library(Shade::kernel_bsd_signal ALIAS
    shade_kernel_bsd_signal)
shade_configure_module(shade_kernel_bsd_signal)
target_link_libraries(shade_kernel_bsd_signal PRIVATE
    Shade::foundation)

add_library(shade_kernel_bsd_filesystem_control STATIC
    bsd/filesystem/control.cpp)
add_library(Shade::kernel_bsd_filesystem_control ALIAS
    shade_kernel_bsd_filesystem_control)
shade_configure_module(shade_kernel_bsd_filesystem_control)
target_link_libraries(shade_kernel_bsd_filesystem_control PRIVATE
    Shade::filesystem
    Shade::foundation)

add_library(shade_kernel_bsd_filesystem_ownership STATIC
    bsd/filesystem/ownership.cpp)
add_library(Shade::kernel_bsd_filesystem_ownership ALIAS
    shade_kernel_bsd_filesystem_ownership)
shade_configure_module(shade_kernel_bsd_filesystem_ownership)
target_link_libraries(shade_kernel_bsd_filesystem_ownership PRIVATE
    Shade::filesystem
    Shade::foundation)

add_library(shade_kernel_bsd_filesystem_locking STATIC
    bsd/filesystem/locking.cpp)
add_library(Shade::kernel_bsd_filesystem_locking ALIAS
    shade_kernel_bsd_filesystem_locking)
shade_configure_module(shade_kernel_bsd_filesystem_locking)
target_link_libraries(shade_kernel_bsd_filesystem_locking PRIVATE
    Shade::filesystem
    Shade::foundation)

add_library(shade_kernel_bsd_filesystem_persistence STATIC
    bsd/filesystem/persistence.cpp)
add_library(Shade::kernel_bsd_filesystem_persistence ALIAS
    shade_kernel_bsd_filesystem_persistence)
shade_configure_module(shade_kernel_bsd_filesystem_persistence)
target_link_libraries(shade_kernel_bsd_filesystem_persistence PRIVATE
    Shade::filesystem
    Shade::foundation)

add_library(shade_kernel_bsd_filesystem_timestamps STATIC
    bsd/filesystem/timestamps.cpp)
add_library(Shade::kernel_bsd_filesystem_timestamps ALIAS
    shade_kernel_bsd_filesystem_timestamps)
shade_configure_module(shade_kernel_bsd_filesystem_timestamps)
target_link_libraries(shade_kernel_bsd_filesystem_timestamps PRIVATE
    Shade::filesystem
    Shade::foundation)

add_library(shade_kernel_bsd_control STATIC
    bsd/network/control/control.cpp
    bsd/network/control/syscalls.cpp)
add_library(Shade::kernel_bsd_control ALIAS
    shade_kernel_bsd_control)
shade_configure_module(shade_kernel_bsd_control)
target_link_libraries(shade_kernel_bsd_control PRIVATE
    Shade::foundation)

add_library(shade_kernel_bsd_virtual_udp STATIC
    bsd/network/virtual_udp.cpp)
add_library(Shade::kernel_bsd_virtual_udp ALIAS
    shade_kernel_bsd_virtual_udp)
shade_configure_module(shade_kernel_bsd_virtual_udp)
target_link_libraries(shade_kernel_bsd_virtual_udp PRIVATE
    Shade::foundation)

add_library(shade_kernel_bsd_virtual_udp_syscalls STATIC
    bsd/network/virtual_udp_syscalls.cpp)
add_library(Shade::kernel_bsd_virtual_udp_syscalls ALIAS
    shade_kernel_bsd_virtual_udp_syscalls)
shade_configure_module(shade_kernel_bsd_virtual_udp_syscalls)
target_link_libraries(shade_kernel_bsd_virtual_udp_syscalls PRIVATE
    Shade::kernel_bsd_virtual_udp
    Shade::foundation)

add_library(shade_kernel_bsd_process STATIC
    bsd/process/credentials.cpp
    bsd/process/diagnostics.cpp
    bsd/process/information.cpp
    bsd/process/interval_timer.cpp
    bsd/process/memorystatus.cpp
    bsd/process/policy.cpp
    bsd/process/resource_monitor.cpp
    bsd/process/uuid_policy.cpp
    bsd/process/spawn.cpp)
add_library(Shade::kernel_bsd_process ALIAS
    shade_kernel_bsd_process)
shade_configure_module(shade_kernel_bsd_process)
target_link_libraries(shade_kernel_bsd_process PRIVATE
    Shade::foundation)

add_library(shade_kernel_bsd_security STATIC
    bsd/security/code_signing.cpp
    bsd/security/extensions.cpp
    bsd/security/mac.cpp
    bsd/security/sandbox.cpp)
add_library(Shade::kernel_bsd_security ALIAS
    shade_kernel_bsd_security)
shade_configure_module(shade_kernel_bsd_security)
target_link_libraries(shade_kernel_bsd_security PRIVATE
    Shade::foundation)

add_library(shade_kernel_bsd_vm_shared_region STATIC
    bsd/vm/shared_region.cpp)
add_library(Shade::kernel_bsd_vm_shared_region ALIAS
    shade_kernel_bsd_vm_shared_region)
shade_configure_module(shade_kernel_bsd_vm_shared_region)
target_link_libraries(shade_kernel_bsd_vm_shared_region PRIVATE
    Shade::foundation)

target_sources(shade_kernel PRIVATE
    bsd/dispatch.cpp
    bsd/platform.cpp
    bsd/pthread_runtime.cpp
    bsd/psynch_runtime.cpp
    bsd/psynch.cpp
    bsd/aio.cpp
    bsd/audit_session.cpp
    bsd/guarded_file.cpp
    bsd/fileport.cpp
    bsd/process.cpp
    bsd/posix_semaphore.cpp
    bsd/filesystem.cpp
    bsd/descriptor_lifecycle.cpp
    bsd/descriptor_memory.cpp
    bsd/bpf.cpp
    bsd/socket.cpp
    bsd/network/process_sockets.cpp
    bsd/events.cpp
    bsd/kqueue.cpp
    bsd/device/offline_serial.cpp
    bsd/support.cpp)
target_link_libraries(shade_kernel PRIVATE
    Shade::kernel_bsd_baseband_device
    Shade::kernel_bsd_control
    Shade::kernel_bsd_debug
    Shade::kernel_bsd_filesystem_control
    Shade::kernel_bsd_filesystem_persistence
    Shade::kernel_bsd_filesystem_timestamps
    Shade::kernel_bsd_filesystem_locking
    Shade::kernel_bsd_filesystem_ownership
    Shade::kernel_bsd_virtual_udp_syscalls
    Shade::kernel_bsd_virtual_udp
    Shade::kernel_bsd_process
    Shade::kernel_bsd_security
    Shade::kernel_bsd_vm_shared_region
    Shade::kernel_bsd_signal
    Shade::kernel_bsd_sysctl)

add_library(shade_kernel_iokit_audio STATIC
    iokit/audio/device_catalog.cpp
    iokit/audio/abi.cpp
    iokit/audio/property_notifications.cpp
    iokit/audio/service.cpp)
add_library(Shade::kernel_iokit_audio ALIAS
    shade_kernel_iokit_audio)
shade_configure_module(shade_kernel_iokit_audio)
target_link_libraries(shade_kernel_iokit_audio PRIVATE
    Shade::foundation)

add_library(shade_kernel_iokit_baseband STATIC
    iokit/baseband/ip_appender.cpp
    iokit/baseband/service.cpp)
add_library(Shade::kernel_iokit_baseband ALIAS
    shade_kernel_iokit_baseband)
shade_configure_module(shade_kernel_iokit_baseband)
target_link_libraries(shade_kernel_iokit_baseband PRIVATE
    Shade::foundation)

add_library(shade_kernel_iokit_camera STATIC
    iokit/camera/service.cpp)
add_library(Shade::kernel_iokit_camera ALIAS
    shade_kernel_iokit_camera)
shade_configure_module(shade_kernel_iokit_camera)
target_link_libraries(shade_kernel_iokit_camera PRIVATE
    Shade::foundation)

add_library(shade_kernel_iokit_display STATIC
    iokit/display/backlight.cpp
    iokit/display/vsync.cpp)
add_library(Shade::kernel_iokit_display ALIAS
    shade_kernel_iokit_display)
shade_configure_module(shade_kernel_iokit_display)
target_link_libraries(shade_kernel_iokit_display PRIVATE
    Shade::foundation)
if(TARGET PkgConfig::PLIST)
    target_link_libraries(shade_kernel_iokit_display PRIVATE PkgConfig::PLIST)
    target_compile_definitions(shade_kernel_iokit_display PRIVATE SHADE_HAS_LIBPLIST=1)
endif()

add_library(shade_kernel_iokit_graphics STATIC
    iokit/graphics/service.cpp)
add_library(Shade::kernel_iokit_graphics ALIAS
    shade_kernel_iokit_graphics)
shade_configure_module(shade_kernel_iokit_graphics)
target_link_libraries(shade_kernel_iokit_graphics PRIVATE
    Shade::foundation)

add_library(shade_kernel_iokit_hid STATIC
    iokit/hid/service.cpp)
add_library(Shade::kernel_iokit_hid ALIAS
    shade_kernel_iokit_hid)
shade_configure_module(shade_kernel_iokit_hid)
target_link_libraries(shade_kernel_iokit_hid PRIVATE
    Shade::foundation)

add_library(shade_kernel_iokit_jpeg STATIC
    iokit/jpeg/service.cpp)
add_library(Shade::kernel_iokit_jpeg ALIAS
    shade_kernel_iokit_jpeg)
shade_configure_module(shade_kernel_iokit_jpeg)
target_link_libraries(shade_kernel_iokit_jpeg PRIVATE
    Shade::foundation
    Shade::graphics
    Shade::media)

add_library(shade_kernel_iokit_keybag STATIC
    iokit/keybag/service.cpp)
add_library(Shade::kernel_iokit_keybag ALIAS
    shade_kernel_iokit_keybag)
shade_configure_module(shade_kernel_iokit_keybag)
target_link_libraries(shade_kernel_iokit_keybag PRIVATE
    Shade::foundation Shade::crypto)

add_library(shade_kernel_iokit_mbx STATIC
    iokit/mbx/service.cpp)
add_library(Shade::kernel_iokit_mbx ALIAS
    shade_kernel_iokit_mbx)
shade_configure_module(shade_kernel_iokit_mbx)
target_link_libraries(shade_kernel_iokit_mbx PRIVATE
    Shade::foundation)

add_library(shade_kernel_iokit_mobile_file_integrity STATIC
    iokit/mobile_file_integrity/service.cpp)
add_library(Shade::kernel_iokit_mobile_file_integrity ALIAS
    shade_kernel_iokit_mobile_file_integrity)
shade_configure_module(shade_kernel_iokit_mobile_file_integrity)
target_link_libraries(shade_kernel_iokit_mobile_file_integrity PRIVATE
    Shade::foundation)

add_library(shade_kernel_iokit_power STATIC
    iokit/battery.cpp
    iokit/environment.cpp
    iokit/power.cpp)
add_library(Shade::kernel_iokit_power ALIAS
    shade_kernel_iokit_power)
shade_configure_module(shade_kernel_iokit_power)
target_link_libraries(shade_kernel_iokit_power PRIVATE
    Shade::foundation)

add_library(shade_kernel_mach_transport STATIC
    mach/transport/descriptor.cpp
    mach/transport/kernel_mach_ipc.cpp)
add_library(Shade::kernel_mach_transport ALIAS
    shade_kernel_mach_transport)
shade_configure_module(shade_kernel_mach_transport)

add_library(shade_kernel_mach_port STATIC
    mach/port/context.cpp
    mach/port/enumeration.cpp
    mach/port/kernel_rpc.cpp
    mach/port/guarded.cpp
    mach/port/limits.cpp
    mach/port/membership.cpp)
add_library(Shade::kernel_mach_port ALIAS
    shade_kernel_mach_port)
shade_configure_module(shade_kernel_mach_port)
target_link_libraries(shade_kernel_mach_port PRIVATE
    Shade::foundation)

add_library(shade_kernel_mach_processor STATIC
    mach/processor/processor_set.cpp)
add_library(Shade::kernel_mach_processor ALIAS
    shade_kernel_mach_processor)
shade_configure_module(shade_kernel_mach_processor)
target_link_libraries(shade_kernel_mach_processor PRIVATE
    Shade::foundation
    Shade::mach)

add_library(shade_kernel_mach_task STATIC
    mach/task/identity.cpp
    mach/task/info.cpp
    mach/task/enumeration.cpp
    mach/task/exception_ports.cpp)
add_library(Shade::kernel_mach_task ALIAS
    shade_kernel_mach_task)
shade_configure_module(shade_kernel_mach_task)
target_link_libraries(shade_kernel_mach_task PRIVATE
    Shade::foundation
    Shade::mach)

add_library(shade_kernel_mach_thread STATIC
    mach/thread/creation.cpp
    mach/thread/lifecycle.cpp
    mach/thread/self.cpp
    mach/thread/state.cpp)
add_library(Shade::kernel_mach_thread ALIAS
    shade_kernel_mach_thread)
shade_configure_module(shade_kernel_mach_thread)
target_link_libraries(shade_kernel_mach_thread PRIVATE
    Shade::foundation
    Shade::mach)

add_library(shade_kernel_mach_vm STATIC
    mach/vm/allocate.cpp
    mach/vm/copy.cpp
    mach/vm/deallocate.cpp
    mach/vm/inherit.cpp
    mach/vm/kernel_rpc.cpp
    mach/vm/map.cpp
    mach/vm/memory_entry.cpp
    mach/vm/protect.cpp
    mach/vm/purgable.cpp
    mach/vm/read.cpp
    mach/vm/remap.cpp
    mach/vm/region.cpp)
add_library(Shade::kernel_mach_vm ALIAS
    shade_kernel_mach_vm)
shade_configure_module(shade_kernel_mach_vm)
target_link_libraries(shade_kernel_mach_vm PRIVATE
    Shade::foundation)

add_library(shade_kernel_mach_input STATIC
    mach/input/graphics_services.cpp
    mach/input/graphics_services_input_abi.cpp)
add_library(Shade::kernel_mach_input ALIAS shade_kernel_mach_input)
shade_configure_module(shade_kernel_mach_input)
target_link_libraries(shade_kernel_mach_input PUBLIC
    Shade::foundation
    Shade::mach)

target_sources(shade_kernel PRIVATE
    mach/support.cpp
    mach/ipc.cpp
    mach/kevent_receive.cpp
    mach/semaphore.cpp
    mach/message.cpp
    mach/host_message.cpp
    mach/port_message.cpp
    mach/task_vm_message.cpp
    mach/rights_message.cpp
    mach/notification_message.cpp
    mach/send_possible.cpp
    mach/traps.cpp)
target_link_libraries(shade_kernel PRIVATE
    Shade::kernel_mach_transport
    Shade::kernel_mach_port
    Shade::kernel_mach_processor
    Shade::kernel_mach_task
    Shade::kernel_mach_thread
    Shade::kernel_mach_vm
    Shade::kernel_mach_input)

target_link_libraries(shade_kernel PRIVATE
    Shade::kernel_graphics
    Shade::device_state
    Shade::kernel_iokit_audio
    Shade::kernel_iokit_baseband
    Shade::kernel_iokit_camera
    Shade::kernel_iokit_power
    Shade::kernel_iokit_display
    Shade::kernel_iokit_graphics
    Shade::kernel_iokit_hid
    Shade::kernel_iokit_jpeg
    Shade::kernel_iokit_keybag
    Shade::kernel_iokit_mbx
    Shade::kernel_iokit_mobile_file_integrity)
