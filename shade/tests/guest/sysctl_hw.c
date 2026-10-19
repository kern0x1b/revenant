// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// sysctl_hw.c: guest test of the hw.* processor nodes.
//
// A device answers hw.activecpu, hw.physicalcpu(_max), hw.logicalcpu(_max), hw.cpufrequency(_max) and
// hw.busfrequency(_max) next to hw.ncpu, each as an int on armv7. The OpenCL runtime reads them to
// describe its CPU device (compute units, clock); when sysctlbyname fails it keeps whatever its stack
// held, and a one-dimensional kernel then gets a work-group size it refuses. Core Image's Gaussian
// blur runs such kernels.
//
// The processor count the kernel reports through host_info is the oracle for the counts.
//
// One line per case, "ok" or "FAIL <why>"; exits with the number of failures.
#include <mach/mach.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/sysctl.h>

static int failures;

static void check(const char *name, int good, const char *why)
{
    if (good) {
        printf("ok   %s\n", name);
    } else {
        printf("FAIL %s: %s\n", name, why);
        failures++;
    }
}

static int node(const char *name, int *value)
{
    size_t size = sizeof *value;
    *value = -1;
    return sysctlbyname(name, value, &size, NULL, 0) == 0 && size == sizeof *value;
}

static void count(const char *name, int expected)
{
    int value;
    check(name, node(name, &value) && value == expected, "missing, or not the processor count host_info reports");
}

static void frequency(const char *name, int *value)
{
    check(name, node(name, value) && *value > 0, "missing or zero");
}

int main(void)
{
    host_basic_info_data_t info;
    mach_msg_type_number_t size = HOST_BASIC_INFO_COUNT;
    kern_return_t result = host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&info, &size);
    check("host_info", result == KERN_SUCCESS && info.max_cpus > 0, "host_info failed");

    count("hw.ncpu", info.max_cpus);
    count("hw.activecpu", info.avail_cpus);
    count("hw.logicalcpu", info.logical_cpu);
    count("hw.logicalcpu_max", info.logical_cpu_max);
    count("hw.physicalcpu", info.physical_cpu);
    count("hw.physicalcpu_max", info.physical_cpu_max);

    int cpu, cpu_max, bus, bus_max;
    frequency("hw.cpufrequency", &cpu);
    frequency("hw.cpufrequency_max", &cpu_max);
    frequency("hw.busfrequency", &bus);
    frequency("hw.busfrequency_max", &bus_max);
    check("frequencies agree", cpu == cpu_max && bus == bus_max && cpu > bus, "current and maximum differ, or the bus is faster than the core");

    // sysctl.name2oid then sysctl by number, the path sysctlbyname takes, must land on the same value.
    int mib[CTL_MAXNAME];
    size_t length = CTL_MAXNAME;
    int by_number = -1;
    size_t value_size = sizeof by_number;
    int ok = sysctlnametomib("hw.cpufrequency", mib, &length) == 0 &&
             sysctl(mib, (u_int)length, &by_number, &value_size, NULL, 0) == 0;
    check("hw.cpufrequency by number", ok && by_number == cpu, "the number name2oid gave does not read the same value");

    printf("failures=%d\n", failures);
    return failures;
}
