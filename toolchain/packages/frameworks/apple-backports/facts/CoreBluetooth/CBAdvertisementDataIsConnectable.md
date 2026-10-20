# CBAdvertisementDataIsConnectable

The advertisement key that says a peripheral accepts a connection: `NSString *const CBAdvertisementDataIsConnectable`,
declared by CoreBluetooth of iOS 7.0 on. It lives in `libCoreBluetoothBackports.dylib`, built with the
`corebluetooth` config (`packages/frameworks/apple-backports/CoreBluetooth/CBAdvertisementDataIsConnectable.m`).

## What the release has

- The 6.1.3 shared cache (armv7) has no `kCBAdvDataIsConnectable` string: `grep -a -c kCBAdvDataIsConnectable
  ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7` answers 0.
- Its CoreBluetooth image exports no symbol with `IsConnectable` in its name:
  `xmake l tools/image-exports.lua 6.1.3 armv7 "CoreBluetooth.framework/CoreBluetooth" "IsConnectable"` answers
  `0 matching` of 92 exports.
- The advertisement keys the release's CoreBluetooth does carry are LocalName, ManufacturerData, ServiceData,
  ServiceUUIDs, HashedServiceUUIDs and TxPowerLevel. So on 6.1.3 an advertisement never reports connectability.

## What the host has

- The host's shared cache (macOS 27.0.1, `/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e.07`)
  holds the string, NUL-terminated, exactly `kCBAdvDataIsConnectable`
  (`grep -a -o -E '.{0,8}kCBAdvDataIsConnectable.{0,8}'` returns it between NULs).
- The iOS 26.2 SDK declares it at CoreBluetooth.framework/Headers/CBAdvertisementData.h:83 with `NS_AVAILABLE(10_9, 7_0)`.

## Behaviour

| input | answer |
|---|---|
| the constant, read by a caller | the NSString `kCBAdvDataIsConnectable`; the same text as the host's |
| the key in an advertisement dictionary of 6.1.3 | never present: the release does not send it |

The constant is a string. The library links no CoreBluetooth framework, so the Bluetooth central stays dlopen'd
(the note on CoreMIDIBackports in `modules/apple/backports.lua`).

## What the port does with it

The Matter stack imports the constant from `libMatterBackports.dylib`. Before this library the import was weak and bound
to nothing on 6.1.3 (`packages/frameworks/matter/facts/MatterFramework.md`, "BLE advertisement connectability"). With the library
linked before `-framework CoreBluetooth`, the import binds to the backport, and the absent-key branch of the BLE patch
only applies to a release whose CoreBluetooth never sends the key.

## Device status

Device-unverified: the host measures the host's string, and the 6.1.3 device has no key to compare with. The
string is measured, not assumed: it is the one the host's own shared cache holds.
