# The registry paths and the main port of IOKit, iOS 9.0 and 15.0

IOKit's registry is a tree of entries, each in a plane (`IOService:`, `IODeviceTree:`, …), and a path
is the name of that plane followed by the `/`-separated names from the root down to the entry. Four
names arrived after the release this port runs on:

| name | release | what it is |
| --- | --- | --- |
| `IORegistryEntryCopyFromPath(mainPort, CFStringRef)` | 9.0 | the release's `IORegistryEntryFromPath`, with a `CFStringRef` path |
| `IORegistryEntryCopyPath(entry, plane)` | 9.0 | the release's `IORegistryEntryGetPath`, returning the path as a `CFString` |
| `kIOMainPortDefault` | 15.0 | the default main port, `MACH_PORT_NULL` |
| `IOMainPort(bootstrapPort, mainPort)` | 15.0 | asks the system for the main port |

The armv7 shared cache of iOS 6.1.3 exports `_IORegistryEntryFromPath`, `_IORegistryEntryGetPath` and
`IOObjectRelease` from its `IOKit`, and none of these four. So the two functions of iOS 9 are written
over the two the release has, and the two names of iOS 15 over what the header itself says they mean.

## What the port answers

- `kIOMainPortDefault` is `MACH_PORT_NULL`, which is 0. That is not a guess: the IOKit header says
  "the NULL argument indicates 'use the default'. This is a synonym for NULL", and the host's own
  `kIOMainPortDefault` prints 0.
- `IOMainPort(bootstrapPort, mainPort)` returns `KERN_SUCCESS` and sets `*mainPort` to
  `kIOMainPortDefault`. This release has no separate IOKit main port: the release's IOKit is reached
  through the task's own port, and `MACH_PORT_NULL` is what every IOKit function of the release
  already reads as "the default". So the value handed back is the one the release itself treats as
  the default, and the caller's next IOKit call behaves exactly as it would have without it.
- `IORegistryEntryCopyFromPath` converts the `CFString` path to UTF-8 and calls the release's own
  `IORegistryEntryFromPath`, whose result is +1 exactly as the name `Copy…` promises. A path that is
  nil, or one that does not fit `io_string_t`, is answered `MACH_PORT_NULL`, and so is a path no entry
  has — which is what the release's own function answers.
- `IORegistryEntryCopyPath` calls the release's own `IORegistryEntryGetPath` into an `io_string_t` and
  returns a `CFString` of what it wrote (+1, as the name promises). An entry of 0, and any entry the
  release cannot give a path for, is answered `NULL` — again the release's own answer.

## What the ladder measures

The two objects are placed by the release the armv7 cache ladder measures each symbol first appearing
in, read with `dyld.first_releases` over the held ladder:

| symbol | the header annotates | the ladder measures |
| --- | --- | --- |
| `IORegistryEntryCopyFromPath`, `IORegistryEntryCopyPath` | 9.0 | 9.0 |
| `kIOMainPortDefault`, `IOMainPort` | 15.0 | **16.0** — nothing between 12.0 and 16.0 is held, so an upper bound |

Hence `IORegistryPaths9.c` and `IOMainPort15.c`, one release each, as an object must be.

## Where the port answers where the host does not

The host crashes on two of these, and an API of this port never crashes the caller:

- `IOMainPort(MACH_PORT_NULL, NULL)` — the host reads through the out-parameter and dies with SIGSEGV;
  the port answers `KERN_INVALID_ARGUMENT`.
- `IORegistryEntryCopyFromPath(kIOMainPortDefault, NULL)` — the host dies the same way; the port
  answers `MACH_PORT_NULL`.

Both divergences are recorded here on purpose: they are the only places where the port's answer is
not the host's, and the reason is a rule of this project, not a reading of the system.

## What was measured on the host

- `kIOMainPortDefault` prints 0.
- `IOMainPort(MACH_PORT_NULL, &main)` returns `KERN_SUCCESS` and a non-null port; `IOMainPort(…, NULL)`
  crashes.
- `IORegistryEntryCopyFromPath(kIOMainPortDefault, "IOService:/")` returns an entry;
  `"NoSuchPlane:/nope"` and `"garbage"` return `MACH_PORT_NULL`; a nil path crashes.
- `IORegistryEntryCopyPath(0, kIOServicePlane)` returns nil, and the root entry of the host's
  `IOService` plane has no path there either: `IORegistryEntryGetPath` fails with `kIORegistryError`
  and leaves the buffer alone. So nil is the answer for an entry the system cannot give a path for,
  and the port's `NULL` is that answer.

## What is not verified

The two functions have not been run on a release this port targets. In particular the release's
`IORegistryEntryGetPath` is called here with three arguments — entry, plane, buffer — as the SDK
header declares it and as the macOS 12 implementation of the same source takes it, while the armv7
cache's symbol table says nothing about a signature. The emulator call test at 6.1.3 is what settles
it; until that runs, these two rows are device-unverified.
