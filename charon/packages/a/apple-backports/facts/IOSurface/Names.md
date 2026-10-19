# The property keys IOSurface added from iOS 11.0 to 18.0, and what is left of the framework

iOS 11 gave IOSurface the modern surface: a class, the property keys a surface is made of, the
plane accessors and the attachments. iOS 12, 14, 16 and 18 added four more keys. **The 33 names are
carried here**; the class, its 15 properties, its 19 methods and its 9 functions are the next piece of
this framework and are named at the end of this file rather than left to look like an oversight.

## Where the values come from

Not typed. Each one is read out of the arm64e shared cache of iOS 18.0 through its own symbol with
`tools/corpus/cache-value.lua`:

    the symbol's address in the image's symbol table, the pointer stored there, the __cfstring it
    points at, and the bytes that names

`IOSurfacePropertyKeyBytesPerRow` is `IOSurfaceBytesPerRow`, `IOSurfacePropertyKeyPixelFormat` is
`IOSurfacePixelFormat`, and `kIOSurfaceSubsampling` is `IOSurfaceSubsampling`. The text matters and is
never a spelling of the symbol: a property key is what a surface's properties are looked up by, so a key
carried with the wrong text is a key nothing answers to.

**Two families, two C types, and each is written as its header declares it.** The
`IOSurfaceProperty…` names are `IOSurfacePropertyKey` — an `NSString *` — as `IOSurfaceObjC.h` declares
them; the ten `kIOSurface…` names of `IOSurfaceRef.h` are `const CFStringRef`. The first generator
wrote all 33 as `CFStringRef` and the second as `NSString`, and the compiler said so both times; the
third writes each family with the type its own header gives.

**Checked against a second source**, the host's own IOSurface, which exports all 33:
`tests/backports/host/iosurfacenames` reads each value on both sides and compares.

    33 agreed, 0 differed, and the host has no such key for none of them

**One file per release**, because an object carries the API of one release: `IOSurfacePropertyNames110.m`
(29 names), `…120.m`, `…140.m`, `…160.m` and `…180.m` (one each).

## What a caller does not get

A key is a name for a property. The **release's own `IOSurface` C API** — `IOSurfaceCreate`,
`IOSurfaceGetProperty`, `IOSurfaceLock`, `IOSurfaceUnlock`, `IOSurfaceSetPurgeable` and the rest, 226
exports in the armv7 shared cache of iOS 6.1.3 — is what a surface on this release actually is, and it
answers for the properties these keys name as far as the release's own store has them. Carrying the
keys does not add a property the release's store has no value for; it means an application that writes
one gets the name it wrote rather than a name nothing answers to.

## What is left of IOSurface, and what it needs

- **The class `IOSurface` and its 15 properties and 19 methods** (iOS 11), and the 9 functions
  (iOS 11, plus `IOSurfaceSetOwnershipIdentity` of 17.4). This is the whole modern surface written over
  the release's own C API: `-[IOSurface initWithProperties:]` is `IOSurfaceCreate` with the properties
  as a dictionary, the plane accessors are `IOSurfaceGetProperty` on the `…Plane…` keys, `lock`/
  `unlock` are `IOSurfaceLock`/`IOSurfaceUnlock` with the options and seed passed through, and the
  attachments are a dictionary the class keeps beside the surface.
- It is **one object per release** (11.0, 12.0 for the extra key, 17.4), and it is the piece that can
  be held to the host in both directions the way the keys were: macOS has the same C API and the same
  class, so `-[IOSurface initWithProperties:]`, a property read, a lock/unlock pair and the attachment
  dictionary are all comparable.
- It is not written in this delivery because it is a class with a lifetime (a locked surface, a use
  count, attachments that must survive a `dealloc`) rather than a table of names, and the rule of this
  project is that a class is written once with its behaviour — not sketched here and measured later.
