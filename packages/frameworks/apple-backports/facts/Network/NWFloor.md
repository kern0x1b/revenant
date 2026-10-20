# Why Network's floor is iOS 6.0

Every type of Network's C API is an `OS_OBJECT` type: `nw_endpoint_t`, `nw_connection_t`,
`nw_parameters_t` and the rest are `OS_OBJECT_DECL`, which `nw_object.h:32` defines in terms of
`OS_OBJECT_DECL` - a protocol plus a typedef of `NSObject` to that protocol. The port's objects are
`NSObject`s that adopt those protocols, so a release where the object types are not Objective-C
objects has nothing for them to be.

The release decides that, and the SDK says so itself in `usr/include/os/object.h:67`:

```c
#elif TARGET_OS_IOS && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
#  define OS_OBJECT_HAVE_OBJC_SUPPORT 0
```

and `OS_OBJECT_USE_OBJC` follows it (`object.h:81-93`): with no Objective-C support the whole family
is 0, so under a deployment target below iOS 6.0 `nw_endpoint_t` is not an `NSObject` protocol
type at all. That is the same measured reason ARKit, Vision and CoreML already sit at 6.0 on this
port.

So **every entry in `registry/Network/` carries `minimum: 6.0`**, the 4.3 band leaves the library
out with the usual note, and nothing of Network is compiled for 4.3 - including the connection
object api-upstreams brought, which is told the same in the delivery note.

`SSLCreateContext` being iOS 5.0 API is therefore moot for this port: the TLS of a connection is
never reached on a release that has no Network.

## The 4.3 gate's failing compile: what is measured, and what is not

**Retracted**: the claim that "a 6.0 band's header set is not carrying Network's own protocols" was
not measured, and the coordinator reproduced the same compile three ways with zero errors - raw clang at
armv7-apple-ios6.0 against each of the fifteen installed 16.4 SDKs including the gate's own, the gate's
full flag set, and through ccache with the gate's own CCACHE_DIR, BASEDIR and NOHASHDIR. The first
11:49 run that seemed to show it was on a tree marked `dirty yes`.

What is measured since, on the **clean** tree with the registry-spelling fix applied:

- the 4.3 gate is still red, and the compile it fails is the one at `armv7-apple-ios6.0`, not at 4.3 -
  the 4.3 band stages every band up to the highest minimum, and nothing of Network is compiled for 4.3
  itself, which the gate's own build directory shows;
- the full argv of the failing compile is

      ccache …/llvm/23.1.1/…/bin/clang -target armv7-apple-ios6.0 -isysroot …/iPhoneOS16.4.sdk
      -fobjc-arc -Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability
      -Werror=objc-missing-property-synthesis -c …/Network/nw26-path.m -o …/objects-6.0/Network/nw26-path.o

  which is the same command the coordinator ran by hand and the same compiler, sysroot and flags - so the
  difference is not the command line;
- it is not ccache: with `CCACHE_DISABLE=1` in the gate's environment the same twenty errors come back.

So the remaining difference is the *environment* the gate sets around that compile rather than the
command: an include-path variable ahead of the sysroot (`CPATH`, `OBJC_INCLUDE_PATH`, …) pointing at
the port's header copy, which would leave `<Network/Network.h>` resolving to nothing while `-isysroot` still
names the installed one. Printing the environment of the failing compile, or running that exact command
with the gate's own `env`, is the one measurement left; nothing in this band is changed on the strength
of a guess, and no row of mine is at fault so far as anything here can show.
