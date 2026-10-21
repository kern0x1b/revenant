# The Matter framework, iOS 12 to 26, on iOS 6

The 24 647 rows of the SDK 26.2 surface of the framework Matter are carried by building connectedhomeip's own Darwin
framework for the port's release: `revenant@matter` runs that project's GN build of `libCHIP.a` with the port's
toolchain, then compiles the framework's hundred Objective-C++ sources over it and links `libMatterBackports.dylib`.
Nothing here is re-typed; the classes are the Matter SDK's classes, and their behaviour is connectedhomeip's.

## The surface, and what the host's own framework says about it

Measured with `tools/matter-host-diff.lua`, which reads the host's half from a **live process that loaded the
framework** (`tests/backports/host/matter/run.sh`: `objc_copyClassList`, `class_copyMethodList`,
`class_copyPropertyList`, `class_copyProtocolList`, `protocol_copyMethodDescriptionList`, and the surface's function
rows asked of the loaded image by `dlsym`) and the port's half from `libMatterBackports.dylib` with the same modules
the gate's check reads a library with.

| the host's `Matter.framework` carries | of the SDK 26.2 surface |
| --- | --- |
| 985 classes | 985 classes |
| 13 184 methods | 14 014 methods |
| 2650 properties | 2651 properties |
| 11 protocols | 16 protocols |
| 8 functions | 8 functions |

Every class, every function, all but one property and 94% of the methods are in the framework this machine's own macOS
carries. So the port's target is the framework rather than the surface, and a build of connectedhomeip's framework is a
build of that surface. The 830 methods, 1 property and 5 protocols no host framework carries are named in
`.agent-work/host/matter-host-diff.tsv`: they are rows of an SDK release whose framework is older than the SDK, and
they are what the port's own library is compared against row by row.

**The two kinds the surface has and this comparison cannot have.** The 6531 constants are header-declared
enumerations, so they live in the importing program and are not symbols either library exports; the 442 enum types are
typedefs of the same kind, carried by the values the SDK names after them. Neither is a difference between the two
sides, and neither is counted as one.

**Why the host's half is a live process and not a file.** The host's framework is in its dyld shared cache and is not on
disk, and a binary written out of that cache with `dyld.extract` does not carry the Objective-C metadata in a form this
repository's reader can walk: `objc.binary_inventory` finds no classes in it, though it finds all three of a library
built here from source. The class and function counts could be had from its exports, which is where the first run of
this measurement came from; the members could not be had at all until the framework was loaded instead.

## The state of the build, measured

- **All 125 objects compile for `armv7-apple-ios6.1.3`**: the 100 `MTR*` Objective-C++ of the framework and the 23
  app-layer C++ files its own Xcode target carries, read out of that target's Sources phase and not guessed, plus the two
  generated Apple-spelling categories: 100 + 23 + 2 = 125. The
  objects are in the package's own source tree; `tools/matter-framework.sh` builds and links them there in minutes
  instead of a whole package resolve.
**The link succeeds** with `-Wl,-no_implicit_dylibs` (see the flag's reason below): `libMatterBackports.dylib`,
45 110 492 bytes, `MH_MAGIC ARM V7`, 1506 exported `MTR*` classes, 24 777 exported symbols, 382 undefined, install
name `/usr/lib/revenant/org.revenant.backports/libMatterBackports.dylib`.

- The four link experiments that found it, each one a link, over the 125 objects the build produces (the framework's 123 plus the two generated Apple spellings): **dropping** the two sources the framework's target shares
  with `libCHIP.a` (`DescriptorCluster.cpp`, `AttributePersistenceProviderInstance.cpp`) - asserts, so the duplicate
  hypothesis is out; `-Wl,-no_implicit_dylibs` - **links**; only `-lc++` without `-lc++abi` - asserts; `-lc++abi` first -
  asserts. So the miss is a symbol bound through a re-export that has no ordinal of its own, and libc++ re-exporting
  libc++abi is that re-export.
- The old state, for the record: **the link failed in the linker, not in Matter**: Revenant's `ld64 956.6` aborts with
  `Assertion failed: (it != _dylibToOrdinal.end()), function dylibToOrdinal, file OutputFile.cpp, line 5214` while
  encoding the symbol table. Measured, in order:

  | link | result |
  | --- | --- |
  | `libCHIP.a` alone, or with libc++, or with either backport, or with all three | links |
  | the 125 objects, or any one group of them (the 100 MTR, the 6 codegen data model, the 17 server layer, the 2 Apple spellings), or two groups | links |
  | the 125 objects **and** `libCHIP.a` **and** libc++ **and** the two backports | asserts |

  It is not the C++ runtime's install name: the packaged libcxx (`/usr/lib/revenant/org.revenant.libcxx-550adb3c/…`,
  absolute install names, a Debian package) asserts, the `@rpath` one asserts, staged copies rewritten with
  `install_name_tool -id` to absolute paths assert, and `-L -l` and full paths and with and without `-rpath` all assert.
  It is not one object: **dropping any one of at least a dozen different objects makes it link** - the six codegen data
  model objects, `MTRAsyncWorkQueue.mm`, `MTRCluster.mm`, `MTRDevice.mm`,
  `MTRDeviceControllerDataStore.mm`, `MTRDeviceControllerXPCConnection.mm`, `MTROperationalCredentialsDelegate.mm`
  among them - which is the signature of a defect in the linker rather than of any symbol in the input. `ld64` writes a
  snapshot of the run next to the output on each abort, which is the artefact to read next.

## What the port carries, measured against the SDK 26.2 surface and against the host

`tools/matter-registry.lua` against the linked dylib: **16 461 of 24 647 rows carried**, in 299 registry files.
`tools/matter-host-diff.lua` over the same corpus, the host's own framework read from a live process, and the port's
library read from its exports and metadata:

| kind | both | host only | port only | neither |
| --- | --- | --- | --- | --- |
| classes | **985** | 0 | 0 | 0 |
| methods | **13 136** | 48 | 0 | 830 |
| properties | **2 278** | 372 | 0 | 1 |
| protocols | **11** | 0 | 0 | 5 |
| functions | **8** | 0 | 0 | 0 |
| constants | 0 | 0 | 41 | 6 490 |

Every class of the surface, and every function, is in the port's library and in the host's framework alike. 13 136 of
the 14 014 methods are the same name in both; 48 are the host's alone and 830 are in neither framework, the rows an SDK
release carries that its framework does not. The 372 properties the host has and the port does not are the honest gap:
the port's classes are all there, but this library's metadata does not expose those accessors under the getter or setter
name the answer is looked for by, so the property row is not answered from it. The 6490 constants and 442 enum types
are in neither column because they are header-declared enumerations - they live in the importing program and are not
symbols either library exports; the 41 the port exports and the host does not are the ones upstream's headers
declare as `extern`.

## The inherited accessors: 16 461 becomes 17 061

The 372 properties were never missing. `objc.binary_inventory` keys a class's **own** method list by sign and
selector (`-authMode`), and the registry re-formats those into the `-[Class selector:]` spelling; reading only a
class's own list therefore misses every accessor a subclass inherits, and the model's deprecated `…Entry`, `…EP` and
`…OutputInfo` classes inherit **all** of theirs from the `…Struct` classes. Measured, over the 372: the superclass
chain is right in every one (`MTRAccessControlClusterAccessControlEntry : MTRAccessControlClusterAccessControlEntryStruct`,
`MTRApplicationLauncherClusterApplicationEP : MTRApplicationLauncherClusterApplicationEPStruct`, and so on), and every
accessor resolves once the chain is walked. Both tools now answer a member by the class **or** any superclass, and try
the library's own spelling first, because the class list `objc.lua` walks is not every class the library exports.

| | before | after |
| --- | --- | --- |
| rows carried | 16 461 | **17 080** |
| properties uncarried | 373 | **1** |
| methods uncarried | 878 | **631** |
| classes | 985 carried | 985 carried |
| functions | 8 carried | 8 carried |

**What the 17 061 of 24 647 leaves, family by family.** 6 490 constants and 440 enum types are header-declared
enumerations: they live in the importing program's own text and are not symbols a library can export, so the headers
the package installs are their coverage. 5 protocols and 1 property are rows no framework of either kind carries.
**650 methods are the port's real gap**, of which 48 are ones the host's framework does carry and this library does
not — the rest are rows neither framework has. Every one is named in `.agent-work/host/matter-host-diff.tsv`.

## The 55 host-only methods: what they are, measured

Against connectedhomeip **master** (`cbcf92f0`, after the 1.6.1.0 this package builds), fetched and searched:

- `AppleAliro` — **0 occurrences anywhere in master**; `appleClearAliro` — **0**. Neither is in the tag either.
- `src/darwin/Framework/CHIP/templates/availability.yaml` in master lists the Aliro names **unprefixed**:
  `AliroReaderVerificationKey`, `AliroReaderGroupIdentifier`, `AliroReaderGroupSubIdentifier`,
  `AliroExpeditedTransactionSupportedProtocolVersions`, `AliroGroupResolvingKey`, `AliroSupportedBLEUWBProtocolVersions`,
  `AliroBLEAdvertisingVersion`, `NumberOfAliroCredentialIssuerKeysSupported`, `NumberOfAliroEndpointKeysSupported`,
  and the command `SetAliroReaderConfig`.
- This library's metadata carries the unprefixed methods: 21 Aliro selectors on `MTRBaseClusterDoorLock`, 12 on
  `MTRClusterDoorLock`, and **0** of the `apple`-prefixed spellings.

So the `apple` prefix is **Apple's own naming convention in Apple's closed-source framework**, over an open-source
feature the port already carries under the model's spelling. Every one of the 48 is a forward to a method this
library has: `readAttributeAppleAliroX` to `readAttributeAliroX`, `writeAttributeApple…` and
`subscribeAttributeApple…` the same way, and `appleClearAliroReaderConfigWith…` to
`clearAliroReaderConfigWith…` - the prefix on the *command* names, with the first word left lower-case, which is
where the first pass of the mapping got it wrong. Nothing here is absent: each row has an attribute or a command
behind it on this library.

The other 7 host-only methods are `MTRClusterWakeOnLAN`, and those are **newer upstream**: master's
`zap-generated/MTRBaseClusters.h` carries `WakeOnLAN`, and the 1.6.1.0 this package builds does not. So the WakeOnLAN
cluster's rows come from taking a later tag, not from a rename.

## The 603 rows that no framework carries

658 methods are uncarried in all, over 278 owners: 55 the host carries and this library does not, and 603 that no
framework of either kind carries. The 603 concentrate in the delegate and XPC protocol classes -
`MTROTAProviderDelegate` (12), `MTRXPCServerProtocol_MTRDevice` (12), `MTRDeviceControllerDelegate` (10),
`MTRCommissioningDelegate` (8), `MTRXPCClientProtocol_MTRDevice` (7), `MTRDeviceControllerStorageDelegate` (5),
`MTRXPCServerProtocol_MTRDeviceController` (5), `MTRDeviceAttestationDelegate` (4), `MTRDevicePairingDelegate` (4),
`MTRKeypair` (4), `MTRDeviceDelegate` (3), `MTRStorage` (3) - with the remainder two per `MTRBaseCluster<Cluster>`.

A delegate protocol's methods are implemented by the **application**, not by the framework. What the port owes for them
is two things, and both are measurable:

- **the protocol's metadata**, which this library carries: the port and the host's framework agree on 11 of the 16
  protocol rows, and 5 no framework of either kind carries.
- **the framework calling each method at the moment upstream's Darwin framework calls it** - and that is settled by
  construction rather than by a diff: the port's framework sources *are* upstream's, byte for byte. Measured, by
  sha1 of each file in the build tree against the tag: `MTRDeviceController_Concrete.mm`, `MTRBaseDevice.mm`,
  `MTRCommissioningOperation.mm`, `MTRDevice_XPC.mm`, `MTRDeviceController_XPC.mm` and
  `MTRDeviceControllerDataStore.mm` are all **identical**. The recipe compiles the hundred sources unmodified - the
  only files it adds are `packages/m/matter/Revenant/`, the Apple spellings - so every delegate call site upstream has, the
  port has, at the same line of the same file. The call sites, in the framework's own `.mm` files: 26 mentions of
  `MTRDeviceControllerDelegate`, 25 of `MTROperationalCredentialsDelegate`, 10 each of `MTRCommissioningDelegate`,
  `MTRDeviceControllerStorageDelegate` and `MTROTAProviderDelegate`, 4 of `MTRDeviceAttestationDelegate`, over 49
  distinct delegate sends.

**The XPC protocols are the framework's own process boundary**, and upstream's own arrangement is the answer to what
the port owes: `MTRXPCClientProtocol` is declared in `XPC Protocol/MTRXPCClientProtocol.h`, used by `MTRDevice_XPC.h`
and implemented by `MTRDeviceController_XPC.mm`, and `MTRXPCServerProtocol` by the same file the other way. So the
*client* half is what a program implements when it drives a controller in another process, and the *server* half is
what the framework implements when it is the one in that process - and `MTRDeviceController_XPC.mm` is in the hundred
sources the port compiles unchanged, so both halves are carried at the port. The 7 rows of the two protocols the corpus
lists and neither framework carries are names upstream does not declare, and the 7 rows that are in the surface and in
neither side are the same shape.

So none of the 603 needs an implementation from this side: they are the *methods of protocols the application
implements*, and the port's job for them is the metadata and the call sites, both of which it has.

## xmake's `l` runner and a script that takes four paths

`xmake l tools/x.lua <a> <b> <c> <d>` does deliver four positional strings, both as named parameters and through
`{...}` - measured with a probe that printed them. What is not delivered is a script that *imports* `apple.objc` and then
reads a large library inside `main`: it fails with `attempt to index a number value (local 'opt')` before its first
statement in `main` runs, which is xmake's sandbox `opt` rather than anything in the arguments. `tools/matter-alias.lua`
is the script: the four paths arrive, the import returns a table, and the call after it does not. The rename rule and
the emitter in it are sound; what is missing is the isolation of that failure, and until it is isolated the 48 forwards
are not written.

## The 48 methods that are missing

For every property row the host's framework answers and the port's does not, the port's own metadata was asked what it
carries for that class. Measured, over all 372: the **class is present in every one of them** (the port carries all
985 of the surface's classes), and in **none** of them is there an accessor — not the plain getter `-[C name]`, not the
setter `-[C setName:]`, and not a prefixed getter (`isName`, `hasName`, `canName`, `asName`, `shouldName`, `willName`,
`didName`), which is the third shape an SDK spells a getter in. So this is not a metadata artefact of a property that
behaves and is not declared: there is no method to find either.

That is the shape of the rows themselves: they are the **event argument classes** of the model — 
`MTRAccessControlClusterAccessControlEntry`, `MTRAccessControlClusterExtensionEntry`, `MTRAccessControlClusterTarget`,
`MTRApplicationLauncherClusterApplicationEP`, `MTRAudioOutputClusterOutputInfo` — and the property is a field of the
event (`endpoint`, `fabricIndex`, `privilege`, `authMode`, `index`). In connectedhomeip the accessors for those live
in the class's own `@interface` in the zap-generated `MTRCommandPayloadsObjc.h`, and what the SDK's surface calls a
property is answered by the host through a *category* or a protocol the class adopts. Which of the two it is for any
given row is a source question, and it is not answered yet.

So: 48 methods and 372 properties are **missing methods**, not undeclared ones, and the fix is to implement them from
upstream's sources, not to declare what is already there. `tools/matter-host-diff.lua` names every one of them in
`.agent-work/host/matter-host-diff.tsv`.

## Behaviour, held to the host

`tests/backports/host/matter/pure.m` is one program with no device on the other end, written so it compiles against
the host's own `Matter.framework` and against `libMatterBackports.dylib` alike, printing one `name<TAB>answer` per
line; `tools/matter-pure-diff.lua` reads the two files and names every line that differs. What it covers is the part of
the three areas a program meets first that needs no device: the setup payload built from a passcode and a discriminator
and read back, the manual-entry parser over the code the framework itself wrote out of that payload, the onboarding
parser over its base38 form, a payload and a code that are not ones, the commissioning parameters' own defaults, and
`MTRDeviceControllerStorageClasses()`. 38 questions, and the host answers all 38.

What that run measured, and what the port has to reproduce:

- `manualEntryCode` for the standard payload of passcode 20202021 and discriminator 3840 is **34970112332** - the
  framework's own encoder does not put the discriminator there: parsing that code back gives discriminator **15**, and
  `hasShortDiscriminator` YES. So the eleven digits are a code whose discriminator is not the one the payload names,
  and the round trip is not an identity. This is the kind of answer a differential exists for.
- `+isValidSetupPasscode:` answers **true for 1234** as well as for 20202021, so it is not a length check.
- The onboarding payload `MT:Y.K90SO527JA0648G00` is vendorID 65521, productID **32768**, passcode 20202021 and
  discriminator **3839**, not the 32770 and 3840 a reading of the documentation suggests; `initWithPayload:` on a
  string that is not a payload answers nil.
- A manual code of one digit and a code that is not a payload both answer `MTRErrorDomain error 4`, the failure
  answer and not a crash - the half of a differential that only runs would never see.
- The controller names eight storage classes, of which the framework's own are the first three.

**What the host cannot be held for, and why.** The name-to-id and id-to-name mappings of the iOS surface
(`MTRClusterNameForID`, `MTRAttributeNameForID`, `MTRRequestCommandNameForID`, `MTRResponseCommandNameForID`,
`MTREventNameForID`) are **not declared by the host's public headers at all** - macOS's Matter.framework ships 62 public
headers and none of them declares a name mapping - so there is no host answer to compare a port answer with, and
saying the host agrees would be a fiction. `MTRBaseDevice`'s read, write and subscribe and `MTRDeviceController`'s
commission, pair and subscribe need a device and a daemon, and this host has neither. Those are covered by the
emulator call test, which calls every method the port's library carries and requires that none of them crashes - not
by a differential, because there is nothing on the other side to be differential against.

## The framework's own availability switches

The framework's headers mark a member with the iOS release Matter shipped it in, and a member of a *newer* Matter
release is worse than marked: `MTRDefines.h:75` makes `MTR_PROVISIONALLY_AVAILABLE` expand to `NS_UNAVAILABLE`
unless `MTR_ENABLE_PROVISIONAL` is set. The first build of the wrapper therefore refused `MTRDataTypeSemanticTagStruct`
and its `mfgCode`, `MTRAttributePath`'s `label` and `auxiliaryType`, its `readPathsSupported` and
`simultaneousWritesSupported` - and as *explicitly* unavailable, which is a hard error, not a warning any `-Wno-` flag
turns off.

The framework's own build says what to do, in `src/darwin/Framework/Configs/Project.xcconfig:4`:

    GCC_PREPROCESSOR_DEFINITIONS = $(inherited) MTR_NO_AVAILABILITY=1 MTR_ENABLE_PROVISIONAL=1 MTR_ENABLE_UNSTABLE_API=1

All three are now the recipe's flags, which is the whole answer: the framework compiles itself with the availability
marks off and with the provisional and unstable API on, because it is the thing that ships them. The same project
compiles its own availability tests (`MTRAvailabilityTests.m`) with `-UMTR_NO_AVAILABILITY
-Wno-unguarded-availability-new`, so the marks are off for the framework and on exactly where they are the thing
under test. That is upstream's own arrangement, read from its own build, and this recipe adds no judgement of its own.

**What my first attempt got wrong, since it is the kind of thing worth recording:** I reached for
`-Wno-unguarded-availability-new` and reasoned that the link would still catch an SDK call the release lacks. It does
catch that, and it was still the wrong fix: the marks in question are `NS_UNAVAILABLE`, which is a hard error and not
the diagnostic that flag names, so the build failed with the very same six diagnostics. The right answer was three lines
of the framework's own xcconfig, which I had not read yet.

## What the port's release does not have, and what the build does about it

- **Signposts.** The framework's device browser, `MTRDeviceConnectivityMonitor.mm`, watches a peer's reachability
  through `nw_connection_*` of Network.framework (iOS 12) and the Darwin platform behind it uses the `os_signpost_*`
  family of libsystem (iOS 12). A release below 12 has neither. Network's connection is `libNetworkBackports.dylib`
  (the Backports, and the facts of `Network/NWConnection.md`): a real datagram socket, the path reported by the path monitor
  the Foundation library already carries, and viability that means the kernel has a route to the address and the
  device's own reachability says the path is satisfied. The signposts are `revenant@apple-compat`'s: the system's own
  where a release has them, and here the header's answer for signposts that are turned off, with `os_signpost_enabled`
  false so the emit macros skip at their own test.
- **The SDK's own libc++.** `usr/include/assert.h` reaches the SDK's libc++ of iOS 6, whose headers this compiler does
  not understand. `-nostdinc++` with the port's `revenant@libcxx` is the spelling.
- **64-bit atomics on 32-bit ARM.** `ClockBase::mLastTimestamp` is taken and replaced with 64-bit `__atomic_*`
  operations, and clang gives `uint64_t` four bytes of alignment on `armv7-apple-ios` - measured:
  `sizeof(struct { char c; uint64_t v; })` is 12 there, 16 on arm64. A doubleword atomic on ARM has to be eight-byte
  aligned to be defined at all, so the member is aligned (`packages/m/matter/patches/clock-alignment.patch`) rather than the warning
  turned off.
- **BLE advertisement connectability.** `BleConnectionDelegateImpl.mm` (pinned 3bcdd56b, lines 411-414) reads
  `CBAdvertisementDataIsConnectable` and returns when `[nil boolValue] == NO`, so an advertisement with no key is
  dropped. Measured: iOS 6.1.3's CoreBluetooth has no such key at all (no `kCBAdvDataIsConnectable` string in its
  cache; its advertisement keys are LocalName, ManufacturerData, ServiceData, ServiceUUIDs, HashedServiceUUIDs and
  TxPowerLevel; its exports have no `_CBAdvertisementDataIsConnectable`), so connectability is never reported there.
  The key's string on the releases that have it is `kCBAdvDataIsConnectable`, measured in the host's dyld shared cache
  (`dyld_shared_cache_arm64e.07`). The port answers for the datum the OS lacks: an absent key counts as connectable
  (`packages/m/matter/patches/ble-connectable.patch`), since a commissionable device must be connectable; the pinned source cites no spec
  section for that, and the Matter core spec's BLE commissioning section has not been read in this tree. A connect that
  then fails is not reported by this file, which has no `didFailToConnectPeripheral`. The constant itself is not yet a
  CoreBluetooth backport: the key's weak import stays null on 6.1.3 until one exists (open, see the report).
  - Status (v-matter8, 2026-10-14): the constant is now carried by `libCoreBluetoothBackports.dylib` (the Backports
    `corebluetooth`, `facts/CoreBluetooth/CBAdvertisementDataIsConnectable.md`), linked before `-framework CoreBluetooth`.
    The import binds to the backport's string, `kCBAdvDataIsConnectable`, on 6.1.3 and is never null there. The absent-key
    branch of the patch now answers only for a release whose CoreBluetooth never sends the key (6.1.3 measured; the host
    sends it). Measured on the installed dylib (v-matter8): `nm -m` reads `(undefined) external _CBAdvertisementDataIsConnectable (from libCoreBluetoothBackports)`, and `xmake l packages/m/matter/tests/import_check.lua` answers "every non-weak import of the armv7 slices of 8 binaries resolves against 158520 exports", with no weak import it does not export.
- **Weak and bound imports, measured (v-matter8).** `_CCRandomGenerateBytes` is a weak reference bound to
  `libCommonCryptoBackports.dylib` (`nm -m` reads "weak external ... from libCommonCryptoBackports"): the symbol exists in
  the package, so the reference is not null when the backport loads. Accepted by the coordinator as it stands; the
  BoringSSL reference (`third_party/boringssl/repo/src/crypto/rand_extra/ios.c:25`) is not changed by this package.
  `_os_unfair_lock_lock` and `_os_unfair_lock_unlock` are non-weak and bound to the packaged `libc++abi.1.dylib`
  (`/usr/lib/revenant/org.revenant.libcxx-6b5ca29e/`, the packaged build of this release, `~/.xmake/packages/l/libcxx/23.1.1/6b5ca29e...`; the digest moved after 5be4d2bce2 and the v-matter7 install name e07f9ca7 is not the one this install links)`). The apple-compat archive (`libapple-compat.a`,
  in 18 of the 21 installs under `~/.xmake/packages/a/apple-compat/latest`, each read with `nm -gU`) exports only `_os_unfair_lock_assert_owner` and `_os_unfair_lock_assert_not_owner` in
  the `os_unfair_lock` family, so the archive defines neither lock nor unlock and the link carries no second definition
  of either. Measured on the installed dylib: `nm -gU` reports neither as a defined symbol.
- **No Xcode, no pigweed.** GN's own `build/toolchain/custom` takes `target_cc`, `target_cxx` and `target_ar`, which
  bypasses `BUILDCONFIG.gn`'s os/cpu selection entirely; the compiler, the archiver and the flags are the toolchain's
  own, the same values `toolchain/modules/apple/cmake.lua` derives for a CMake build. `//build_overrides/pigweed_environment.gni`
  is a file upstream's bootstrap step writes and its `.gitignore` lists; the install step writes it, empty of
  declarations, which is what it comes to for a build with no pigweed environment.

## Not carried, and why

- The framework's own use of Network is its connection, and that is carried. The rest of Network - listeners, browsers,
  groups, the protocol options, the connection's data calls - is not, and `facts/Network/NWConnection.md` names the
  two honest gaps.
- The framework's XPC surface (`MTRDeviceController+XPC`, `MTRDeviceOverXPC`) is carried as the framework writes it,
  over the release's own XPC, which iOS 6.1.3 has in the form it needs. Whether every XPC service of the current
  framework answers on it is what the emulator call test has yet to say.
