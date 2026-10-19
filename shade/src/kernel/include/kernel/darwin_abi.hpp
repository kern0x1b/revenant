// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define guest Darwin syscall constants and ARM32 data layouts used
// by the kernel boundary.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/syscalls.master
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/aio.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mig_errors.h

#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

#include "foundation/darwin_errno.hpp"
#include "network/darwin_socket_abi.hpp"

namespace shade::darwin {

// Darwin 8 / iPhoneOS 1.0 ABI values used at the compatibility boundary.
// Keep these names here instead of scattering host-incompatible literals
// throughout syscall implementations.


namespace aio {
    // Darwin 8 ARM32 struct aiocb. off_t is 64-bit but only 4-byte aligned for
    // this target, while pointers and size_t remain 32-bit.
    inline constexpr std::uint32_t descriptor_offset = 0;
    inline constexpr std::uint32_t file_offset_offset = 4;
    inline constexpr std::uint32_t buffer_offset = 12;
    inline constexpr std::uint32_t byte_count_offset = 16;
    inline constexpr std::uint32_t request_priority_offset = 20;
    inline constexpr std::uint32_t notification_offset = 24;
    inline constexpr std::uint32_t signal_offset = 28;
    inline constexpr std::uint32_t signal_value_offset = 32;
    inline constexpr std::uint32_t notification_function_offset = 36;
    inline constexpr std::uint32_t notification_attributes_offset = 40;
    inline constexpr std::uint32_t list_opcode_offset = 44;
    inline constexpr std::uint32_t control_block_size = 48;

    inline constexpr std::uint32_t notify_none = 0;
    inline constexpr std::uint32_t notify_signal = 1;
    inline constexpr std::uint32_t notify_thread = 3;
    inline constexpr std::uint32_t all_done = 1;
    inline constexpr std::uint32_t canceled = 2;
    inline constexpr std::uint32_t not_canceled = 4;
    inline constexpr std::uint32_t list_no_operation = 0;
    inline constexpr std::uint32_t list_read = 1;
    inline constexpr std::uint32_t list_write = 2;
    inline constexpr std::uint32_t list_nowait = 1;
    inline constexpr std::uint32_t list_wait = 2;
    inline constexpr std::uint32_t synchronize = 0x0080;
    inline constexpr std::uint32_t maximum_requests_per_process = 16;
} // namespace aio

namespace open_flag {
    inline constexpr std::uint32_t access_mode = 0x0003;
    inline constexpr std::uint32_t read_only = 0x0000;
    inline constexpr std::uint32_t write_only = 0x0001;
    inline constexpr std::uint32_t read_write = 0x0002;
    inline constexpr std::uint32_t non_block = 0x0004;
    inline constexpr std::uint32_t append = 0x0008;
    inline constexpr std::uint32_t create = 0x0200;
    inline constexpr std::uint32_t truncate = 0x0400;
    inline constexpr std::uint32_t exclusive = 0x0800;
} // namespace open_flag

namespace path_configuration {
    // Darwin 8 sys/unistd.h.  This is the value applications store in termios
    // control-character slots to disable the corresponding function.
    inline constexpr std::uint32_t disabled_control_character = 9;
    inline constexpr std::uint32_t disabled_control_character_value = 0xff;
} // namespace path_configuration

namespace memory_advice {
    inline constexpr std::uint32_t normal = 0;
    inline constexpr std::uint32_t random = 1;
    inline constexpr std::uint32_t sequential = 2;
    inline constexpr std::uint32_t will_need = 3;
    inline constexpr std::uint32_t do_not_need = 4;
    inline constexpr std::uint32_t free = 5;
    inline constexpr std::uint32_t zero_wired_pages = 6;
    inline constexpr std::uint32_t free_reusable = 7;
    inline constexpr std::uint32_t free_reuse = 8;
    inline constexpr std::uint32_t can_reuse = 9;
} // namespace memory_advice

namespace fcntl_command {
    inline constexpr std::uint32_t get_descriptor_flags = 1;
    inline constexpr std::uint32_t set_descriptor_flags = 2;
    inline constexpr std::uint32_t get_status_flags = 3;
    inline constexpr std::uint32_t set_status_flags = 4;
    inline constexpr std::uint32_t get_record_lock = 7;
    inline constexpr std::uint32_t set_record_lock = 8;
    inline constexpr std::uint32_t set_record_lock_wait = 9;
    // Darwin file-cache hints. They affect kernel read strategy, not descriptor
    // data or persistence, so the compatibility VFS may accept them as
    // advisory.
    inline constexpr std::uint32_t set_read_ahead = 45;
    inline constexpr std::uint32_t set_no_cache = 48;
    inline constexpr std::uint32_t get_path = 50;
    inline constexpr std::uint32_t add_detached_signatures = 59;
    // F_ADDFILESIGS registers the code signature embedded in the same file.
    // Older dyld uses it when validating the dyld shared cache before mapping
    // its logical library images.
    inline constexpr std::uint32_t add_file_signatures = 61;
    // F_GETPROTECTIONCLASS reports the data-protection class associated with a
    // file descriptor. The emulated data volume has no protection metadata,
    // so the descriptor layer reports the unprotected class.
    inline constexpr std::uint32_t get_protection_class = 63;
} // namespace fcntl_command

namespace ptrace_request {
    inline constexpr std::uint32_t trace_me = 0;
    inline constexpr std::uint32_t attach = 10;
    inline constexpr std::uint32_t deny_attach = 31;
} // namespace ptrace_request

namespace record_lock {
    inline constexpr std::uint16_t read = 1;
    inline constexpr std::uint16_t unlock = 2;
    inline constexpr std::uint16_t write = 3;

    // Darwin 8 ARM32 struct flock. off_t remains 64-bit while pid_t and
    // pointers are 32-bit on the target firmware.
    inline constexpr std::uint32_t start_offset = 0;
    inline constexpr std::uint32_t length_offset = 8;
    inline constexpr std::uint32_t pid_offset = 16;
    inline constexpr std::uint32_t type_offset = 20;
    inline constexpr std::uint32_t whence_offset = 22;
    inline constexpr std::uint32_t size = 24;
} // namespace record_lock



namespace mach {
    inline constexpr std::uint32_t success = 0;
    inline constexpr std::uint32_t invalid_address = 1;
    inline constexpr std::uint32_t no_space = 3;
    inline constexpr std::uint32_t invalid_argument = 4;
    inline constexpr std::uint32_t failure = 5;
    inline constexpr std::uint32_t resource_shortage = 6;
    inline constexpr std::uint32_t name_exists = 13;
    inline constexpr std::uint32_t aborted = 14;
    inline constexpr std::uint32_t invalid_name = 15;
    inline constexpr std::uint32_t invalid_task = 16;
    inline constexpr std::uint32_t invalid_right = 17;
    inline constexpr std::uint32_t invalid_value = 18;
    inline constexpr std::uint32_t user_references_overflow = 19;
    inline constexpr std::uint32_t invalid_capability = 20;
    inline constexpr std::uint32_t right_exists = 21;
    inline constexpr std::uint32_t terminated = 37;
    inline constexpr std::uint32_t operation_timed_out = 49;
    inline constexpr std::uint32_t vm_flags_anywhere = 1;
    inline constexpr std::uint32_t vm_flags_overwrite = 0x4000U;
} // namespace mach

namespace mig {
    // Darwin 8 osfmk/mach/mig_errors.h. Keep the signed MIG value in its exact
    // 32-bit wire representation.
    inline constexpr std::uint32_t bad_id = 0xffff'fed1U; // -303
} // namespace mig

namespace mach_message {
    inline constexpr std::uint32_t option_send = 0x0000'0001U;
    inline constexpr std::uint32_t option_receive = 0x0000'0002U;
    inline constexpr std::uint32_t option_send_timeout = 0x0000'0010U;
    inline constexpr std::uint32_t option_send_notify = 0x0000'0080U;
    inline constexpr std::uint32_t option_receive_large = 0x0000'0004U;
    inline constexpr std::uint32_t option_receive_timeout = 0x0000'0100U;
    inline constexpr std::uint32_t type_copy_send = 19U;
    inline constexpr std::uint32_t type_make_send = 20U;
    inline constexpr std::uint32_t type_make_send_once = 21U;
    inline constexpr std::uint32_t bits_complex = 0x8000'0000U;
    inline constexpr std::uint32_t send_invalid_right = 0x1000'000AU;
    inline constexpr std::uint32_t send_no_buffer = 0x1000'000DU;
    inline constexpr std::uint32_t send_invalid_destination = 0x1000'0003U;
    inline constexpr std::uint32_t send_timed_out = 0x1000'0004U;
    inline constexpr std::uint32_t receive_invalid_name = 0x1000'4002U;
    inline constexpr std::uint32_t receive_timed_out = 0x1000'4003U;
    inline constexpr std::uint32_t receive_too_large = 0x1000'4004U;
    inline constexpr std::uint32_t receive_port_changed = 0x1000'4006U;
    inline constexpr std::uint32_t receive_invalid_data = 0x1000'4008U;
    inline constexpr std::uint32_t receive_in_set = 0x1000'400AU;
    inline constexpr std::uint32_t header_size = 24U;

    [[nodiscard]] constexpr std::uint32_t bits(
        std::uint32_t remote, std::uint32_t local = 0, bool complex = false)
    {
        return remote | (local << 8U) | (complex ? bits_complex : 0U);
    }
} // namespace mach_message

namespace arm_fast_trap {
    inline constexpr std::uint32_t syscall_number = 0x80000000U;
    inline constexpr std::uint32_t instruction_cache_invalidate = 0;
    inline constexpr std::uint32_t data_cache_flush = 1;
    inline constexpr std::uint32_t thread_set_cthread_self = 2;
    inline constexpr std::uint32_t thread_get_cthread_self = 3;
} // namespace arm_fast_trap

namespace syscall {
    inline constexpr std::uint32_t read = 3;
    inline constexpr std::uint32_t write = 4;
    inline constexpr std::uint32_t open = 5;
    inline constexpr std::uint32_t close = 6;
    inline constexpr std::uint32_t poll = 230;
    inline constexpr std::uint32_t set_user_id = 23;
    inline constexpr std::uint32_t ptrace = 26;
    inline constexpr std::uint32_t kill = 37;
    inline constexpr std::uint32_t get_process_group = 81;
    // gettid(2) reports a thread's temporary credential override, rather than
    // returning a numeric thread identifier.
    inline constexpr std::uint32_t get_thread_identity = 286;
    inline constexpr std::uint32_t get_priority = 100;
    inline constexpr std::uint32_t unlink = 10;
    inline constexpr std::uint32_t change_mode = 15;
    inline constexpr std::uint32_t change_owner = 16;
    inline constexpr std::uint32_t change_flags = 34;
    inline constexpr std::uint32_t change_flags_fd = 35;
    inline constexpr std::uint32_t revoke = 56;
    inline constexpr std::uint32_t change_owner_fd = 123;
    inline constexpr std::uint32_t change_owner_link = 364;
    inline constexpr std::uint32_t change_mode_fd = 124;
    inline constexpr std::uint32_t flock = 131;
    inline constexpr std::uint32_t receive_message = 27;
    inline constexpr std::uint32_t send_message = 28;
    inline constexpr std::uint32_t receive_from = 29;
    inline constexpr std::uint32_t accept = 30;
    inline constexpr std::uint32_t get_peer_name = 31;
    inline constexpr std::uint32_t get_socket_name = 32;
    inline constexpr std::uint32_t ioctl = 54;
    inline constexpr std::uint32_t get_resource_usage = 117;
    inline constexpr std::uint32_t memory_synchronize = 65;
    inline constexpr std::uint32_t memory_protect = 74;
    inline constexpr std::uint32_t memory_advise = 75;
    inline constexpr std::uint32_t set_groups = 80;
    inline constexpr std::uint32_t get_descriptor_table_size = 89;
    inline constexpr std::uint32_t duplicate_to = 90;
    inline constexpr std::uint32_t fcntl = 92;
    inline constexpr std::uint32_t select = 93;
    inline constexpr std::uint32_t synchronize_file = 95;
    inline constexpr std::uint32_t socket = 97;
    inline constexpr std::uint32_t connect = 98;
    inline constexpr std::uint32_t bind = 104;
    inline constexpr std::uint32_t set_socket_option = 105;
    inline constexpr std::uint32_t listen = 106;
    inline constexpr std::uint32_t get_socket_option = 118;
    inline constexpr std::uint32_t write_vector = 121;
    inline constexpr std::uint32_t set_time_of_day = 122;
    inline constexpr std::uint32_t set_real_effective_user_id = 126;
    inline constexpr std::uint32_t set_real_effective_group_id = 127;
    inline constexpr std::uint32_t send_to = 133;
    inline constexpr std::uint32_t shutdown = 134;
    inline constexpr std::uint32_t socket_pair = 135;
    inline constexpr std::uint32_t get_host_uuid = 142;
    inline constexpr std::uint32_t update_file_times = 138;
    inline constexpr std::uint32_t update_file_times_fd = 139;
    inline constexpr std::uint32_t code_signing_operations = 169;
    inline constexpr std::uint32_t code_signing_audit_operations = 170;
    inline constexpr std::uint32_t set_group_id = 181;
    inline constexpr std::uint32_t set_effective_group_id = 182;
    inline constexpr std::uint32_t set_effective_user_id = 183;
    inline constexpr std::uint32_t get_resource_limit = 194;
    inline constexpr std::uint32_t set_resource_limit = 195;
    inline constexpr std::uint32_t file_descriptor_path_configuration = 192;
    inline constexpr std::uint32_t get_extended_attribute = 234;
    inline constexpr std::uint32_t get_extended_attribute_fd = 235;
    inline constexpr std::uint32_t set_extended_attribute = 236;
    inline constexpr std::uint32_t set_extended_attribute_fd = 237;
    inline constexpr std::uint32_t remove_extended_attribute = 238;
    inline constexpr std::uint32_t remove_extended_attribute_fd = 239;
    inline constexpr std::uint32_t list_extended_attributes = 240;
    inline constexpr std::uint32_t list_extended_attributes_fd = 241;
    inline constexpr std::uint32_t filesystem_control = 242;
    inline constexpr std::uint32_t init_groups = 243;
    inline constexpr std::uint32_t change_mode_extended = 282;
    inline constexpr std::uint32_t change_mode_extended_fd = 283;
    inline constexpr std::uint32_t aio_synchronize = 313;
    inline constexpr std::uint32_t aio_return = 314;
    inline constexpr std::uint32_t aio_suspend = 315;
    inline constexpr std::uint32_t aio_cancel = 316;
    inline constexpr std::uint32_t aio_error = 317;
    inline constexpr std::uint32_t aio_read = 318;
    inline constexpr std::uint32_t aio_write = 319;
    inline constexpr std::uint32_t aio_list = 320;
    inline constexpr std::uint32_t pthread_kill = 328;
    inline constexpr std::uint32_t pthread_sigmask = 329;
    inline constexpr std::uint32_t disable_thread_signal = 331;
    inline constexpr std::uint32_t semaphore_wait_signal = 334;
    // iPhone OS 3.0's libSystem uses the pre-inline-timespec semwait ABI at
    // syscall 370: the fifth argument points to an ARM32 {tv_sec,tv_nsec} pair.
    // Keep this separate from syscall 334, whose sixth argument carries
    // tv_nsec.
    inline constexpr std::uint32_t semaphore_wait_signal_timespec = 370;
    inline constexpr std::uint32_t get_audit_address = 357;
    inline constexpr std::uint32_t kqueue = 362;
    inline constexpr std::uint32_t kevent = 363;
    inline constexpr std::uint32_t mac_syscall = 381;
    inline constexpr std::uint32_t audit_session_self = 428;
    inline constexpr std::uint32_t audit_session_join = 429;
    inline constexpr std::uint32_t fileport_makeport = 430;
    inline constexpr std::uint32_t fileport_makefd = 431;
    inline constexpr std::uint32_t audit_session_port = 432;
    inline constexpr std::uint32_t pid_suspend = 433;
    inline constexpr std::uint32_t pid_resume = 434;
    inline constexpr std::uint32_t pid_hibernate = 435;
    inline constexpr std::uint32_t pid_shutdown_sockets = 436;
    inline constexpr std::uint32_t posix_semaphore_open = 268;
    inline constexpr std::uint32_t posix_semaphore_close = 269;
    inline constexpr std::uint32_t posix_semaphore_unlink = 270;
    inline constexpr std::uint32_t posix_semaphore_wait = 271;
    inline constexpr std::uint32_t posix_semaphore_try_wait = 272;
    inline constexpr std::uint32_t posix_semaphore_post = 273;
    inline constexpr std::uint32_t posix_semaphore_get_value = 274;
} // namespace syscall

namespace filesystem_control {
    // Darwin ARM32's package_ext_info is a pointer followed by two uint32_t
    // fields. The ioctl request carries that 12-byte wire size in bits 16..28.
    inline constexpr std::uint32_t set_package_extensions = 0x800c4102U;
    inline constexpr std::uint32_t package_strings_offset = 0;
    inline constexpr std::uint32_t package_entry_count_offset = 4;
    inline constexpr std::uint32_t package_maximum_width_offset = 8;
    inline constexpr std::uint32_t package_info_size = 12;
    inline constexpr std::uint32_t maximum_package_entries = 1'024;
    inline constexpr std::uint32_t maximum_package_width = 255;
    inline constexpr std::uint32_t option_no_follow = 0x0000'0001U;
} // namespace filesystem_control

namespace poll {
    // Darwin's ARM32 pollfd is the native 8-byte {int fd, short events,
    // short revents} layout. Keep the wire offsets explicit at the
    // compatibility boundary instead of using the host's pollfd definition.
    inline constexpr std::uint32_t fd_offset = 0;
    inline constexpr std::uint32_t events_offset = 4;
    inline constexpr std::uint32_t revents_offset = 6;
    inline constexpr std::uint32_t pollfd_size = 8;

    inline constexpr std::uint16_t in = 0x0001;
    inline constexpr std::uint16_t priority = 0x0002;
    inline constexpr std::uint16_t out = 0x0004;
    inline constexpr std::uint16_t error = 0x0008;
    inline constexpr std::uint16_t hangup = 0x0010;
    inline constexpr std::uint16_t invalid = 0x0020;
    inline constexpr std::uint16_t read_normal = 0x0040;
    inline constexpr std::uint16_t read_band = 0x0080;
    inline constexpr std::uint16_t write_band = 0x0100;
    inline constexpr std::uint16_t write_normal = out;
} // namespace poll

namespace flock_operation {
    inline constexpr std::uint32_t shared = 0x01;
    inline constexpr std::uint32_t exclusive = 0x02;
    inline constexpr std::uint32_t non_blocking = 0x04;
    inline constexpr std::uint32_t unlock = 0x08;
} // namespace flock_operation

namespace signal {
    inline constexpr std::uint32_t count = 32;
    inline constexpr std::uint32_t abort = 6;
    inline constexpr std::uint32_t kill = 9;
    inline constexpr std::uint32_t bad_system_call = 12;
    inline constexpr std::uint32_t urgent = 16;
    inline constexpr std::uint32_t stop = 17;
    inline constexpr std::uint32_t terminal_stop = 18;
    inline constexpr std::uint32_t resume = 19;
    inline constexpr std::uint32_t child = 20;
    inline constexpr std::uint32_t terminal_input = 21;
    inline constexpr std::uint32_t terminal_output = 22;
    inline constexpr std::uint32_t io = 23;
    inline constexpr std::uint32_t window_change = 28;
    inline constexpr std::uint32_t information = 29;
    inline constexpr std::uint32_t default_action = 0;
    inline constexpr std::uint32_t ignore_action = 1;
} // namespace signal

namespace extended_attribute {
    inline constexpr std::uint32_t no_follow = 0x0001;
    inline constexpr std::uint32_t create = 0x0002;
    inline constexpr std::uint32_t replace = 0x0004;
    inline constexpr std::size_t maximum_name_length = 127;
    inline constexpr std::string_view finder_info_name {
        "com.apple.FinderInfo"
    };
    inline constexpr std::string_view resource_fork_name {
        "com.apple.ResourceFork"
    };
} // namespace extended_attribute

namespace io {
    inline constexpr std::uint32_t maximum_vector_count = 1024;
    inline constexpr std::size_t diagnostic_payload_bytes = 48;
} // namespace io

namespace map_flag {
    inline constexpr std::uint32_t shared = 0x0001;
    inline constexpr std::uint32_t private_copy = 0x0002;
    inline constexpr std::uint32_t fixed = 0x0010;
    inline constexpr std::uint32_t anonymous = 0x1000;
} // namespace map_flag

namespace memory_sync_flag {
    inline constexpr std::uint32_t asynchronous = 0x0001;
    inline constexpr std::uint32_t invalidate = 0x0002;
    inline constexpr std::uint32_t kill_pages = 0x0004;
    inline constexpr std::uint32_t deactivate = 0x0008;
    inline constexpr std::uint32_t synchronous = 0x0010;
} // namespace memory_sync_flag

} // namespace shade::darwin
