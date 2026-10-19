# MTLArgumentDescriptor, iOS 11

`MTLArgumentDescriptor` is the class `MTLDevice.h` declares at 11.0. It is in
`Metal/MTLArgumentDescriptor11.m`, and it is a plain data holder: one member of an argument buffer, described
by its data type, binding index, array length, access, texture type and constant block alignment. It asks no
device anything. The argument encoder that would lay such a member out is not in this port (see
`MTLArgumentBinding16.m`), so nothing here hands a value back to a device.

## What is measured, and against what

`tests/backports/host/argument-descriptor/run.sh` builds the port's class for Catalyst beside Apple's Metal in one
process, renamed `RevenantHostMTLArgumentDescriptor`, and compares its members with Apple's: a fresh descriptor (from
the class method and from `new`), one with every member set away from its default, a copy of that one, and the
original after the copy was taken. Equality and the hash are compared too. A mutant that makes the fresh texture
type 1D turns the fresh comparison red, and it does.

Apple's values, measured on the macOS host:

| member | fresh |
| --- | --- |
| `dataType` | `MTLDataTypeNone` (0) |
| `index`, `arrayLength` | 0 |
| `access` | `MTLBindingAccessReadOnly` (0) |
| `textureType` | `MTLTextureType2D` (2) |
| `constantBlockAlignment` | 0 (the default alignment) |

Copy: a new object with the same six members; changing the original afterwards does not change the copy.

Equality: by value. A copy is equal to its original and hashes the same; a set descriptor is not equal to a fresh one.

## What Apple accepts, measured

Apple's validator aborts the process on a value it does not accept (`validateMTLDataType`, `validateMTLBindingAccess`),
so each value was tried in a forked child, on Apple's object and on the port's. The result is the same for both,
and `run.sh` checks it for every value from 0 to 255 (data type) and 0 to 4 (access).

- **Data type**: accepted 0 to 60, 78 to 88, 115 to 118, 121 to 124, 127 to 135 and 139. Nothing from 140 to 255.
  The port accepts exactly these and raises `NSInvalidArgumentException` for any other value, which uncaught ends
  the process with the same status (6, SIGABRT) Apple's abort gives.
- **Access**: accepted 0 (read-only), 1 (read-write) and 2 (write-only). 3 and above abort on both sides.
- **Texture type**: not validated. Apple reads back 99 after setting it, and the port does the same.

**Not measured:** the accepted data types above 60 are the host's own. The host is a newer macOS than iOS 11, so
which of 78 to 139 an iOS 11 device accepted is not known here. The port follows the host, which is what the
differential can see. The values from 256 up are not measured.

## What is not carried

- The description string. Apple's `-description` names an internal class (`MTLArgumentDescriptorInternal`) and
  lists the members; the port uses NSObject's.
- The class itself: the host returns an instance of `MTLArgumentDescriptorInternal`, and the port returns
  `MTLArgumentDescriptor`. Only the members are compared, not the class name.
