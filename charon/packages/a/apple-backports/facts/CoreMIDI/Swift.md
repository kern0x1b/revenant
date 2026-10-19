# The 143 Swift rows of CoreMIDI: what they are and what building them needs (measured 2026-10-09)

The surface has 143 Swift-only rows for CoreMIDI: 4 classes (MIDIPacket.Builder, MIDIPacketList.Builder, MIDIEventList.Builder,
MIDIEventPacket.Builder), 60 methods, 33 properties, 14 structs, 32 typealiases. None is registered, and none is implemented.

Measured in the 26.2 SDK (charon/.agent-work/sdk-26.2, read only):

- The Swift interface, `usr/lib/swift/CoreMIDI.swiftmodule/arm64e-apple-ios.swiftinterface`, is 399 lines and declares 145 public
  types, functions and properties. It has no `@inlinable` declaration: every member is implemented in code the module links, not
  copied into the program.
- `System/Library/Frameworks/CoreMIDI.framework/CoreMIDI.tbd` exports no Swift symbol (no `$s` name): the implementation is not in
  the framework the C functions come from. The interface names its module link as `swiftCoreMIDI`, so it is a Swift library the
  operating system provides (on this release there is none: iOS 6.1.3 ships no Swift runtime).
- Every declaration carries an availability of iOS 14.0 or macOS 11.0, and the structs and builders are built on the C functions
  of the release: MIDIPacketListAdd and MIDIPacketListInit (6.1.3 has both), and the MIDIEventList functions this library carries
  (MIDIEventListInit, MIDIEventListAdd, MIDIEventPacketNext).

What building them needs, in this repository:

- A Swift module for the overlay, compiled for the port's architecture and the oldest release, linked as a library of the
  apple-backports package. The package holds no Swift file today (0 `.swift` files under packages/a/apple-backports).
- The Swift runtime: `charon@swift-runtime`, which the swift rule (rules/swift) requires for a port that compiles Swift, and which the
  backports build against. Whether that runtime builds and runs on 6.1.3 is not measured here.
- The C functions beneath, which this library and the release provide.

Not done in this pass: no Swift source, no library, no registry row. The Swift rows stay missing in the ledger until that build exists,
and the next step is to build a minimal overlay (MIDIPacket.Builder over MIDIPacketListAdd) and measure the runtime on 6.1.3.
