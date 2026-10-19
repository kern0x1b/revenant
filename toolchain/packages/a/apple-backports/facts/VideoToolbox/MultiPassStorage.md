# VTMultiPassStorage: a real file, and the two answers the host corrected

`VTMultiPassStorage9_0.m` carries the three functions SDK 26.2 declares and the 6.1.3 release exports
nothing of. From `tools/corpus/dump-cache.lua` over `$HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7`,
2026-10-03: zero hits for `_VTMultiPassStorageCreate`, `_VTMultiPassStorageClose`,
`_VTMultiPassStorageGetTypeID`.

## The CF type is the tree's mechanism, reused

The tree already carries a CF type the 16.4 SDK does not, and does it the same way twice -
`AVFoundation/CMTaggedBufferGroup17.m` and `Graphics/CVMetalTexture80.m` bridge a `Charon`-prefixed NSObject
class to an opaque CF ref and answer `GetTypeID` with `(CFTypeID)objc_getClass(...)`. So does this. The class
is **not** called `VTMultiPassStorage`: a class with Apple's name collides with the host's own class in any
differential compiled against the host's SDK, and this library has to compile in both places.

Apple's own `VTMultiPassStorageGetTypeID` answers **75** on this host, and 75 is not copied: a `CFTypeID` is
a slot in a process-wide table, and a literal would claim another type's slot in every process that loads
this library. The class pointer is unique, stable, and cannot collide. Measured stable across calls on the
host, which is the property a caller compares it for.

## Every answer below is measured against the host, and two of them were wrong before it was asked

`VTMultiPassStorage.h` makes the whole of the documented behaviour the file:

| case | Apple's own answer, measured 2026-10-03 | what this port does |
| --- | --- | --- |
| a fresh path, no options | `0`, a session, the file created and **20 bytes** long | `0`, a session, the file created, **empty** - see below |
| the same, `kVTMultiPassStorageCreationOption_DoNotDelete` = true | `0`; the file **survives** `CFRelease` | the same |
| a path whose file **already exists** | `-12214` `kVTMultiPassStorageInvalidErr`, no session | the same, and the file is left untouched |
| `fileURL` = NULL | `0`, a session | `0`, a session, a unique name in the temporary directory |
| a path whose parent directory does not exist | `-17913`, no file created | `-17913`, the measured value |
| `Close` a second time | `-12214` `kVTMultiPassStorageInvalidErr` | the same |

**Two of this file's answers were wrong before the host was asked, and the measurements are what fixed
them:**

1. It accepted a file that already existed, reading the header's "if the file did not exist when the storage
   was created" as a mood. Apple refuses that case outright with `kVTMultiPassStorageInvalidErr` (-12214),
   so the header describes a case that cannot arise and the port now answers the same way.
2. It answered `kVTInvalidSessionErr` (-12903) for a second `Close`. The release has a code for exactly this
   object being invalid - `kVTMultiPassStorageInvalidErr`, `VTErrors.h:54`, - and the host answers -12214.
   -12903 was the generic wrong answer.

## What this object deliberately does NOT do

**It writes no private header into the file.** Apple's writes 20 bytes at `Create`, and `VTMultiPassStorage.h`
says "The data stored in the `VTMultiPassStorage` is **private to the video encoder**". So:

- a file this port writes is not readable by a real encoder, because the format is Apple's and private;
- nothing in this port reads it either - the 6.1.3 encoder never sees a multi-pass storage at all, because
  `kVTCompressionPropertyKey_MultiPassStorage` arrived with iOS 9 and
  `VTSessionMultiPass7_0.m`'s three functions answer `kVTParameterErr` because the property is not there.

Reproducing 20 bytes of a format whose definition is private would be inventing data. What this port
implements is the file's **lifecycle**, because that is what the header specifies and what a caller can
observe; the contents are Apple's, and they are not reproduced. A caller that hands this object to a real
encoder will find the encoder does not read the file, and that is stated here rather than discovered.

## `-17913` is measured, and no header here names it

A path whose parent directory does not exist gives **`-17913`** on the host. An earlier version of this file
answered `kVTAllocationFailedErr` (-10803) there and said it was guessing; the coordinator's answer is that a
literal is native when it is the measured value with its source named next to it, and answering a different
code where the oracle says otherwise is a divergence. So the port answers `-17913`, as
`kCharonVTMultiPassStorageDirectoryMissing` in `VTMultiPassStorage9_0.m`, with the measurement in the comment
above the constant.

**The framework that owns -17913 could not be identified, and is recorded as not identified.**
`grep -rn 17913` over every framework's headers in the 16.4 SDK, the iPhoneOS 26.2 SDK and the macOS SDK
finds nothing: it is not in `VTErrors.h` and it is not in any other header on this machine. Naming a framework
for it would be a guess, so the facts say "not named anywhere here" instead.

**The parent directory is checked on its own**, before the file is created, so `-17913` answers the one
condition it was measured giving and is not stretched over create failures nobody measured - a file that cannot
be created for some other reason still answers `kVTAllocationFailedErr`. Apple's single code covers all of them
because that is what Apple's implementation does; scoping the port's answer to the measured condition keeps it
from claiming a mapping it has not seen.

## How this was checked

```
$ clang -fsyntax-only -fobjc-arc -Wall -Werror=objc-missing-property-synthesis \
      -target armv7-apple-ios6.0 -isysroot "$(cat /tmp/land/sdkpath)" \
      -Ipackages/a/apple-backports -Ipackages/a/apple-backports/VideoToolbox \
      packages/a/apple-backports/VideoToolbox/VTMultiPassStorage9_0.m
(no output)
$ nm -gU .../VTMPS.o
_T VTMultiPassStorageClose
_T VTMultiPassStorageCreate
_T VTMultiPassStorageGetTypeID
_S _OBJC_CLASS_$_CharonVTMultiPassStorage
```

and the host readings above come from `.agent-work/v-audio/probe-mps.m`, which asks Apple's own
`VTMultiPassStorage` the six questions in the table and prints what it answered. The port's half was not run
on a device this turn: the failures being corrected are in the status codes and the file lifecycle, both of
which the host is the oracle for, and the armv7 objects were checked for the symbols and the class.

`VTFrameSilo` is the same family and does **not** have this property - its file is a container the port both
writes and reads, so the frame data in it is the port's own and not Apple's private format.