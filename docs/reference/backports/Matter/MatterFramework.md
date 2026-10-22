# The Matter framework, iOS 12 to 26, on iOS 6

The Matter framework is carried by building connectedhomeip's own Darwin framework for the port's release. `revenant@matter`
(`packages/m/matter/xmake.lua`) runs that project's GN build of `libCHIP.a` with the port's toolchain, then compiles the
framework's hundred Objective-C++ sources over it. It stops before the link: the recipe raises at `xmake.lua:229`, because
`libMatterBackports` needs the Backports libraries, which are project targets a package cannot depend on yet. The link
measurements below are what the campaign produced by hand. Nothing here is re-typed: the classes are the Matter SDK's
classes, and their behaviour is connectedhomeip's.

The package's crypto is BoringSSL. The recipe sets `chip_crypto="boringssl"` in the GN arguments, and it fetches BoringSSL at
commit `9cac8a6` into the build tree under `third_party/boringssl/repo/src`, which this package does not change.

## The state of the build

- **All 125 objects compile for `armv7-apple-ios6.1.3`**: the 100 `MTR*` Objective-C++ of the framework and the 23
  app-layer C++ files its own Xcode target carries, read out of that target's Sources phase, plus the two generated
  Apple-spelling categories. The objects are built in the package's own source tree.
- **The link, run by hand over the 125 objects, succeeds** with `-Wl,-no_implicit_dylibs` (see the flag's reason below):
  `libMatterBackports.dylib`, 45 110 492 bytes, `MH_MAGIC ARM V7`, 1506 exported `MTR*` classes, 24 777 exported
  symbols, 382 undefined, install name `/usr/lib/revenant/org.revenant.backports/libMatterBackports.dylib`. The recipe
  does not carry the flag and does not reach its own link: the raise above stops it first.
- The four link experiments that found the flag, each one a link over the 125 objects: dropping the two sources the
  framework's target shares with `libCHIP.a` (`DescriptorCluster.cpp`, `AttributePersistenceProviderInstance.cpp`)
  still asserts, so the duplicate hypothesis is out; `-Wl,-no_implicit_dylibs` **links**; only `-lc++` without `-lc++abi`
  asserts; `-lc++abi` first asserts. So the miss is a symbol bound through a re-export that has no ordinal of its own,
  and libc++ re-exporting libc++abi is that re-export.
- The old state, for the record: **the link failed in the linker, not in Matter**. Revenant's `ld64 956.6` aborts with
  `Assertion failed: (it != _dylibToOrdinal.end()), function dylibToOrdinal, file OutputFile.cpp, line 5214` while
  encoding the symbol table. The 125 objects with `libCHIP.a`, libc++ and the two backports asserted; any one group of
  them, or two groups, linked. It was not the C++ runtime's install name, and it was not one object: dropping any one of
  at least a dozen different objects made it link, which is the signature of a defect in the linker rather than of any
  symbol in the input. `ld64` writes a snapshot of the run next to the output on each abort.

## The framework's sources, and what the port owes its delegates

The port's framework sources are upstream's, byte for byte. Measured, by sha1 of each file in the build tree against the
tag, `MTRDeviceController_Concrete.mm`, `MTRBaseDevice.mm`, `MTRCommissioningOperation.mm`, `MTRDevice_XPC.mm`,
`MTRDeviceController_XPC.mm` and `MTRDeviceControllerDataStore.mm` are identical. The recipe compiles the hundred sources
unmodified; the only files it adds are the two generated Apple-spelling categories. So every delegate call site
upstream has, the port has, at the same line of the same file.

A delegate protocol's methods are implemented by the **application**, not by the framework. The port owes the protocol's
metadata and the framework's calls to each method, and the calls are the framework's own: 26 mentions of
`MTRDeviceControllerDelegate`, 25 of `MTROperationalCredentialsDelegate`, 10 each of `MTRCommissioningDelegate`,
`MTRDeviceControllerStorageDelegate` and `MTROTAProviderDelegate`, and 4 of `MTRDeviceAttestationDelegate` in the
framework's `.mm` files.

**The XPC protocols are the framework's own process boundary.** `MTRXPCClientProtocol` is declared in
`XPC Protocol/MTRXPCClientProtocol.h`, used by `MTRDevice_XPC.h` and implemented by `MTRDeviceController_XPC.mm`, and
`MTRXPCServerProtocol` by the same file the other way. The client half is what a program implements when it drives a
controller in another process; the server half is what the framework implements when it is the one in that process.
`MTRDeviceController_XPC.mm` is among the hundred sources the port compiles unchanged, so both halves are carried.

## The framework's own availability switches

The framework's headers mark a member with the iOS release Matter shipped it in, and a member of a *newer* Matter
release is worse than marked: `MTRDefines.h:75` makes `MTR_PROVISIONALLY_AVAILABLE` expand to `NS_UNAVAILABLE`
unless `MTR_ENABLE_PROVISIONAL` is set. The first build of the wrapper therefore refused `MTRDataTypeSemanticTagStruct`
and its `mfgCode`, `MTRAttributePath`'s `label` and `auxiliaryType`, its `readPathsSupported` and
`simultaneousWritesSupported`, as *explicitly* unavailable, which is a hard error and not a warning a `-Wno-` flag turns off.

The framework's own build says what to do, in `src/darwin/Framework/Configs/Project.xcconfig:4`:

    GCC_PREPROCESSOR_DEFINITIONS = $(inherited) MTR_NO_AVAILABILITY=1 MTR_ENABLE_PROVISIONAL=1 MTR_ENABLE_UNSTABLE_API=1

All three are now the recipe's flags. The framework compiles itself with the availability marks off and with the
provisional and unstable API on, because it is the thing that ships them. The same project compiles its own availability
tests (`MTRAvailabilityTests.m`) with `-UMTR_NO_AVAILABILITY -Wno-unguarded-availability-new`, so the marks are off for the
framework and on exactly where they are the thing under test.

Choosing `-Wno-unguarded-availability-new` instead was the wrong fix: the marks in question are `NS_UNAVAILABLE`, a hard
error, so the build failed with the same six diagnostics. The right answer is the three definitions of the framework's own
xcconfig.

## What the port's release does not have, and what the build does about it

- **Signposts.** The framework's device browser, `MTRDeviceConnectivityMonitor.mm`, watches a peer's reachability
  through `nw_connection_*` of Network.framework (iOS 12) and the Darwin platform behind it uses the `os_signpost_*`
  family of libsystem (iOS 12). A release below 12 has neither. Network's connection is carried by
  `frameworks/Backports/src/Network/nw_connection.m`: a real datagram socket, the path reported by the path monitor the
  Foundation library already carries, and viability that means the kernel has a route to the address and the device's own
  reachability says the path is satisfied. The signposts are `revenant@apple-compat`'s: the system's own where a release
  has them, and here the header's answer for signposts that are turned off, with `os_signpost_enabled` false so the emit
  macros skip at their own test.
- **The SDK's own libc++.** `usr/include/assert.h` reaches the SDK's libc++ of iOS 6, whose headers this compiler does
  not understand. `-nostdinc++` with the port's `revenant@libcxx` is the spelling.
- **64-bit atomics on 32-bit ARM.** `ClockBase::mLastTimestamp` is taken and replaced with 64-bit `__atomic_*`
  operations, and clang gives `uint64_t` four bytes of alignment on `armv7-apple-ios`: `sizeof(struct { char c; uint64_t v; })`
  is 12 there, 16 on arm64. A doubleword atomic on ARM has to be eight-byte aligned to be defined at all, so the member is
  aligned (`packages/m/matter/patches/clock-alignment.patch`) rather than the warning turned off.
- **BLE advertisement connectability.** `BleConnectionDelegateImpl.mm` (pinned 3bcdd56b, lines 411-414) reads
  `CBAdvertisementDataIsConnectable` and returns when `[nil boolValue] == NO`, so an advertisement with no key is dropped.
  Measured: iOS 6.1.3's CoreBluetooth has no such key (no `kCBAdvDataIsConnectable` string in its cache, and its exports
  have no `_CBAdvertisementDataIsConnectable`), so connectability is never reported there. The port answers for the datum
  the OS lacks: an absent key counts as connectable (`packages/m/matter/patches/ble-connectable.patch`), since a
  commissionable device must be connectable. The pinned source cites no spec section for that, and the Matter core spec's
  BLE commissioning section has not been read in this tree. A connect that then fails is not reported by this file, which
  has no `didFailToConnectPeripheral`.
  - Status (v-matter8, 2026-10-14): the constant is carried by `libCoreBluetoothBackports.dylib`, the Backports
    `corebluetooth` (`frameworks/Backports/src/CoreBluetooth/CBAdvertisementDataIsConnectable.m`), linked before
    `-framework CoreBluetooth`. The import binds to the backport's string, `kCBAdvDataIsConnectable`, on 6.1.3 and is never
    null there. The absent-key branch of the patch now answers only for a release whose CoreBluetooth never sends the key.
    Measured on the installed dylib: `nm -m` reads `(undefined) external _CBAdvertisementDataIsConnectable (from libCoreBluetoothBackports)`.
- **Weak and bound imports, measured (v-matter8).** `_CCRandomGenerateBytes` is a weak reference bound to
  `libCommonCryptoBackports.dylib` (`nm -m` reads "weak external ... from libCommonCryptoBackports"). It is the random
  source of the BoringSSL the package builds (`crypto/rand_extra/ios.c`, line 25), so the reference is not null when the
  backport loads. `_os_unfair_lock_lock` and `_os_unfair_lock_unlock` are non-weak and bound to the packaged
  `libc++abi.1.dylib`. The apple-compat archive (`libapple-compat.a`) exports only `_os_unfair_lock_assert_owner` and
  `_os_unfair_lock_assert_not_owner` in the `os_unfair_lock` family, so the archive defines neither lock nor unlock and the
  link carries no second definition of either. Measured on the installed dylib: `nm -gU` reports neither as a defined symbol.
- **No Xcode, no pigweed.** GN's own `build/toolchain/custom` takes `target_cc`, `target_cxx` and `target_ar`, which
  bypasses `BUILDCONFIG.gn`'s os/cpu selection entirely. The compiler, the archiver and the flags are the toolchain's own,
  the same values `toolchain/modules/apple/cmake.lua` derives for a CMake build. `//build_overrides/pigweed_environment.gni`
  is a file upstream's bootstrap step writes; the install step writes it empty of declarations, which is what it comes to
  for a build with no pigweed environment.

## Not carried, and why

- The framework's own use of Network is its connection, and that is carried (`frameworks/Backports/src/Network/nw_connection.m`).
  The rest of Network (listeners, browsers, groups, the protocol options and the connection's data calls) is not carried.
- The framework's XPC surface (`MTRDeviceController+XPC`, `MTRDeviceOverXPC`) is carried as the framework writes it, over
  the release's own XPC, which iOS 6.1.3 has in the form it needs. No test in the tree checks whether every XPC service of
  the current framework answers on it.
- No differential test of the Matter behaviour is in the tree now. The earlier comparison against the host's own
  `Matter.framework` ran with tools that have been removed, so the behaviour of the library is not checked against the host.
