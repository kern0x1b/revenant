// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "network/host_readiness.hpp"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <unistd.h>

#include <chrono>
#include <cstdio>
#include <ctime>
#include <vector>

#include <poll.h>

namespace {

constexpr int window_seconds = 10;
constexpr int counts[] = {1, 8, 32};

int listening_socket()
{
    const auto fd = ::socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in address {};
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    ::bind(fd, reinterpret_cast<sockaddr*>(&address), sizeof address);
    ::listen(fd, 4);
    return fd;
}

double cpu_seconds()
{
    rusage usage {};
    getrusage(RUSAGE_SELF, &usage);
    return static_cast<double>(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) +
           static_cast<double>(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6;
}

int per_socket_pass(const std::vector<int>& descriptors)
{
    int ready = 0;
    for (const auto descriptor : descriptors) {
        pollfd entry { descriptor, POLLIN, 0 };
        if (::poll(&entry, 1, 0) > 0 &&
            (entry.revents & (POLLIN | POLLHUP | POLLERR)) != 0) {
            ++ready;
        }
    }
    return ready;
}

int batched_pass(const std::vector<int>& descriptors)
{
    emulator::HostReadinessProbe probe;
    for (const auto descriptor : descriptors) {
        probe.request_readable(descriptor);
    }
    probe.run();
    int ready = 0;
    for (const auto descriptor : descriptors) {
        if (probe.readable(descriptor).value_or(false)) {
            ++ready;
        }
    }
    return ready;
}

void measure(const char* mode, int count, const std::vector<int>& descriptors,
    int (*pass)(const std::vector<int>&))
{
    const auto started_epoch = std::time(nullptr);
    const auto cpu_start = cpu_seconds();
    const auto start = std::chrono::steady_clock::now();
    long passes = 0;
    long ready = 0;
    for (;;) {
        ready += pass(descriptors);
        ++passes;
        const auto elapsed = std::chrono::steady_clock::now() - start;
        if (elapsed >= std::chrono::seconds(window_seconds)) {
            break;
        }
        timespec interval { 0, 1000000 };
        nanosleep(&interval, nullptr);
    }
    const auto seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - start).count();
    const auto cpu = cpu_seconds() - cpu_start;
    std::printf("host_readiness_bench sockets=%d mode=%s window_start=%ld seconds=%.2f "
                "passes=%ld passes_per_second=%.1f ready_per_pass=%.2f cpu_ms_per_second=%.1f\n",
        count, mode, static_cast<long>(started_epoch), seconds, passes,
        static_cast<double>(passes) / seconds,
        static_cast<double>(ready) / static_cast<double>(passes),
        cpu * 1000.0 / seconds);
    std::fflush(stdout);
}

}

int main()
{
    for (const auto count : counts) {
        std::vector<int> descriptors;
        for (int index = 0; index < count; index++) {
            descriptors.push_back(listening_socket());
        }
        const auto client = ::socket(AF_INET, SOCK_STREAM, 0);
        sockaddr_in address {};
        socklen_t length = sizeof address;
        getsockname(descriptors.front(), reinterpret_cast<sockaddr*>(&address), &length);
        address.sin_len = sizeof address;
        ::connect(client, reinterpret_cast<sockaddr*>(&address), sizeof address);
        measure("per_socket", count, descriptors, per_socket_pass);
        measure("batched", count, descriptors, batched_pass);
        ::close(client);
        for (const auto descriptor : descriptors) {
            ::close(descriptor);
        }
    }
    return 0;
}
