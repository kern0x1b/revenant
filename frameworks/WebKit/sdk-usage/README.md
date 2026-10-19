# What this port reads from Apple's SDKs

Measured, not guessed: every compile and every link of every piece this port
builds was run with the compiler and the linker reporting each file they opened,
and the lists here are what came back. They are paths, not Apple's files. Nothing
of Apple's is committed to this repository or redistributed by it; the SDK
itself comes from [theos/sdks](https://github.com/theos/sdks).

| File | SDK | Paths |
| --- | --- | --- |
| `iPhoneOS13.7.sdk.txt` | the target SDK | 1663 of 5320 files, 22.5 of 89.6 MB |
| `MacOSX.sdk.txt` | the Command Line Tools' macOS SDK | 7 files |

## iPhoneOS 13.7

54 of the SDK's 1523 `.tbd` stubs are loaded by a linker; the rest of the list is
headers. 47 of 125 public frameworks and 12 of 1037 private ones are touched at
all, whether named directly or reached through another header.

| Consumer | Files it reads | Beyond the ones above it |
| --- | --- | --- |
| the engine (`charon.toml`, all three frameworks and `jsc`) | 1637 - 1586 headers, 51 stubs | |
| `libios6compat.a` | 1021 headers | none |
| the tweak dylibs (`platform/`) | 4 headers, 11 stubs | `usr/include/AvailabilityVersions.h` |
| the libraries in `recipes/` and `libcxx` | 339 headers, 7 stubs | 25 headers, mostly `usr/include` and `libxml2` |

## macOS

`mig` is the only thing that reads it: WTF's `MachExceptions.defs` includes
`mach/mach_exc.defs`, which pulls in five more definitions and a thread-state
header. The ld64 package reads far more of it while it is being built, but that
is the build of a host tool against the host's own SDK, not something the port
depends on.

## What runs from the Command Line Tools

The compilers (`clang`, `clang++`) with their own headers and the armv7 slice of
`libclang_rt.ios.a`; `libtool`, `ar` and `ranlib` for archives; `mig`; and
`install_name_tool`, `strip`, `otool` and `nm` in the layout and inspection
scripts. Nothing is linked by the Command Line Tools' linker: the engine, the
standalone application and the tweak dylibs all go through the `ld64` package
with `-B`, because that linker stamps every armv7 dylib with an
`LC_ENCRYPTION_INFO` load command iOS 6 refuses in a tweak. Signing is
`/usr/bin/codesign` and `ldid`.

## Not measured in this pass

The prefixed engine and the standalone application (`VARIANT=prefixed`) were not
built for it.

## Measuring again

The recording costs one rebuild with two variables set for the compiler and
three for the linker. `tools/sdk-usage.py` in Charon turns the logs into
the list:

    export CC_PRINT_HEADERS=1 CC_PRINT_HEADERS_FILE=/tmp/headers.txt
    export LD_TRACE_DYLIBS=1 LD_TRACE_ARCHIVES=1 LD_TRACE_FILE=/tmp/links.txt
    # rebuild what is being measured, with ccache out of the way

    python3 <charon toolchain>/tools/sdk-usage.py --sdk "$(charon where tool:iphoneos-sdk)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS13.7.sdk" \
        --ninja build/system --headers /tmp/headers.txt --links /tmp/links.txt \
        --out sdk-usage/iPhoneOS13.7.sdk.txt

ccache replays a compile without running the compiler, so a cached compile logs
nothing; `--ninja` reads the engine's includes from ninja's dependency log
instead, which ccache does keep. The linker is always really run, so link traces
need no special care: everything armv7, the tweak dylibs included, links through
the `ld64` package with `-B` from the profile.
