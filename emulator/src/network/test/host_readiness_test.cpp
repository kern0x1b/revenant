// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Checks the batched host readiness against the per-descriptor poll that
// HostSocket::readable() and writable() make: every answer must match, a
// descriptor that was not requested stays unanswered, and a hangup or a
// closed descriptor is reported the same way.

#include "network/host_readiness.hpp"

#include <cstddef>
#include <iostream>
#include <optional>
#include <string>

#include <poll.h>
#include <unistd.h>

namespace {

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

void expect_answer(std::optional<bool> answer, bool expected,
    const std::string& what)
{
    expect(answer.has_value() && *answer == expected, what);
}

bool single_readable(int descriptor)
{
    pollfd entry { descriptor, POLLIN, 0 };
    return ::poll(&entry, 1, 0) > 0 &&
           (entry.revents & (POLLIN | POLLHUP | POLLERR)) != 0;
}

bool single_writable(int descriptor)
{
    pollfd entry { descriptor, POLLOUT, 0 };
    return ::poll(&entry, 1, 0) > 0 &&
           (entry.revents & (POLLOUT | POLLHUP | POLLERR)) != 0;
}

struct Pipe {
    int read_end { -1 };
    int write_end { -1 };
};

Pipe make_pipe()
{
    int fds[2] { -1, -1 };
    pipe(fds);
    return Pipe { fds[0], fds[1] };
}

void close_pipe(Pipe pipe)
{
    close(pipe.read_end);
    close(pipe.write_end);
}

void batch_matches_one_poll_per_descriptor()
{
    const auto empty = make_pipe();
    const auto filled = make_pipe();
    const char byte = 'x';
    expect(write(filled.write_end, &byte, 1) == 1, "pipe accepts a byte");

    emulator::HostReadinessProbe probe;
    probe.request_readable(empty.read_end);
    probe.request_readable(filled.read_end);
    probe.request_writable(empty.write_end);
    probe.request_readable(empty.read_end);
    probe.run();

    expect_answer(probe.readable(empty.read_end), single_readable(empty.read_end),
        "an empty pipe is not readable in the batch");
    expect_answer(probe.readable(filled.read_end),
        single_readable(filled.read_end),
        "a pipe with a byte is readable in the batch");
    expect_answer(probe.writable(empty.write_end),
        single_writable(empty.write_end),
        "a pipe with room is writable in the batch");
    expect(!probe.readable(empty.read_end).value_or(true),
        "a repeated request is answered as the first one");
    expect(probe.readable(filled.read_end).value_or(false),
        "the batch reports the readable pipe");

    close_pipe(empty);
    close_pipe(filled);
}

void unrequested_descriptors_stay_unanswered()
{
    const auto pipe = make_pipe();
    emulator::HostReadinessProbe probe;
    probe.request_readable(pipe.read_end);
    probe.run();

    expect_answer(probe.readable(pipe.read_end), false,
        "a requested empty read is answered not ready");
    expect(!probe.writable(pipe.read_end).has_value(),
        "a read request does not answer a write question");
    expect(!probe.readable(pipe.write_end).has_value(),
        "an unrequested descriptor has no answer");

    close_pipe(pipe);
}

void hangup_is_ready()
{
    auto pipe = make_pipe();
    close(pipe.write_end);
    pipe.write_end = -1;

    emulator::HostReadinessProbe probe;
    probe.request_readable(pipe.read_end);
    probe.run();
    expect_answer(probe.readable(pipe.read_end), single_readable(pipe.read_end),
        "a pipe whose writer closed matches the single poll");
    expect(probe.readable(pipe.read_end).value_or(false),
        "a pipe whose writer closed is readable");

    close_pipe(pipe);
}

void closed_descriptor_is_not_ready()
{
    const auto pipe = make_pipe();
    close_pipe(pipe);

    emulator::HostReadinessProbe probe;
    probe.request_readable(pipe.read_end);
    probe.request_writable(pipe.write_end);
    probe.run();
    expect_answer(probe.readable(pipe.read_end), single_readable(pipe.read_end),
        "a closed read end matches the single poll");
    expect(!probe.readable(pipe.read_end).value_or(true),
        "a closed read end is not readable");
    expect(!probe.writable(pipe.write_end).value_or(true),
        "a closed write end is not writable");
}

void empty_probe_is_a_no_op()
{
    emulator::HostReadinessProbe probe;
    probe.run();
    expect(!probe.readable(0).has_value(), "an empty probe answers nothing");
}

void drained_pipe_is_no_longer_readable()
{
    const auto pipe = make_pipe();
    const char byte = 'y';
    expect(write(pipe.write_end, &byte, 1) == 1, "pipe accepts a byte");
    char drained = 0;
    expect(read(pipe.read_end, &drained, 1) == 1, "pipe yields the byte");

    emulator::HostReadinessProbe probe;
    probe.request_readable(pipe.read_end);
    probe.run();
    expect(!probe.readable(pipe.read_end).value_or(true),
        "a drained pipe is not readable on the next pass");

    close_pipe(pipe);
}

}

int main()
{
    batch_matches_one_poll_per_descriptor();
    unrequested_descriptors_stay_unanswered();
    hangup_is_ready();
    closed_descriptor_is_not_ready();
    empty_probe_is_a_no_op();
    drained_pipe_is_no_longer_readable();
    if (failures != 0) {
        std::cerr << failures << " host readiness check(s) failed\n";
        return 1;
    }
    std::cout << "host readiness: all checks passed\n";
    return 0;
}
