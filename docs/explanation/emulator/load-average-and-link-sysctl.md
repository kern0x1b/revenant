# Load average and interface records

Two sysctl reads now answer from the emulator's own state instead of falling through to
`[sysctl] unsupported mib`: `vm.loadavg` (`getloadavg`) and `net.link.generic.ifdata` (what `getifaddrs`
reads). The reference is XNU `xnu-2050.22.13`, the closest device-era tag; the device kernel build is inferred.

## Load average

- `foundation/load_average.hpp` is XNU's `compute_averunnable` (`bsd/kern/kern_synch.c`): fixed-point
  `FSHIFT` 11, decay constants `exp(-1/12)`, `exp(-1/60)` and `exp(-1/180)` times `FSCALE` truncated to
  1884, 2014 and 2036.
- `CompatibilityKernel::sample_load_average` takes one step per five guest seconds (`sched_average.c`
  samples on a five-second period). The session passes `XnuScheduler::runnable_count()` each time it
  synchronises scheduler time. A call that finds several periods elapsed applies one step per period with
  the count observed at that call; that is an approximation, because the emulator does not record the
  count at each period.
- `vm.loadavg` returns `struct user32_loadavg` (`sysctl_loadavg` in `bsd/kern/kern_sysctl.c`): `ldavg[3]`
  then a 32-bit `fscale`, 16 bytes. The emulator has no 64-bit guest on this path.
- The arithmetic is tested against the constants and against a settled value for three runnable threads
  (`emulator/tests/unit/load_average_test.cpp`).

## Interface records

- `net.link.generic.system.ifcount` (`IFMIB_SYSTEM`, `IFMIB_IFCOUNT`) returns the highest interface index,
  as XNU returns `if_index`.
- `net.link.generic.ifdata` (`IFMIB_IFDATA`, index, `IFDATA_GENERAL`) returns `struct ifmibdata` from
  `bsd/net/if_mib.h` and `bsd/net/if_var.h`: 180 bytes for the 32-bit guest, with the 8-byte timeval of
  `if_data64`. `make_ifmibdata` in `network/darwin_network_abi.cpp` fills the fields the interface model
  has: name, flags, type, address length, header length, MTU, and the baud rate that the route record
  already reports (10 Mb/s for `en0`, 0 for `lo0`).
- Packet and byte counters, the timing fields and the last-change time are zero, because the model does not
  track them.
- `IFDATA_LINKSPECIFIC` returns zero bytes: the model has no link-specific MIB, and XNU returns the empty
  `if_linkmib` the same way.
- An index that is not in the model, including 0, returns `ENOENT`, as `sysctl_ifdata` does.
- The model has two interfaces, `lo0` (index 1) and `en0` (index 2), and nothing creates others, so index 5
  always answers `ENOENT`. The emulator code does not show which guest code asks for index 5. Find the caller
  with a guest run that logs the request before the answer.
