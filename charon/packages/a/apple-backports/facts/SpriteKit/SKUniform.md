# SKUniform (iOS 8)

The iOS 8 surface of SpriteKit's `SKUniform`: the class, its three factories, its three initialisers, and its
`name`, `uniformType`, `floatValue` and `textureValue` properties, plus `NSCopying` and `NSSecureCoding`.
The port's object is `SpriteKit/SpriteKit8.m` (config `spritekit`, library `libSpriteKitBackports.dylib`), declared
by `SpriteKit/CharonSpriteKit.h`. The declarations are the generator's (`spec/SpriteKit/declarations.tsv`, the rows
`introduced` 8.0 by the SDK's availability). The rows are in `registry/SpriteKit/ios8.json`.

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64, `SpriteKit.framework` from the host's
`MacOSX.sdk`. The probes ran as plain programs that print what the class answers (the probe sources are kept in the
run directory, not committed). The committed check is `tests/backports/host/spritekit-uniform/`: one source built
against the host framework and against the port's object, with the outputs compared line by line. It passes
with 24 lines identical, and a control whose `setFloatValue:` does not move a None uniform to Float fails on one line.

Measured on the host:

- `uniformWithName:` makes a uniform of type None (0), float 0, texture nil. A nil name is accepted and reads back
  as nil. An empty name reads back as the empty string.
- `uniformWithName:float:` makes a Float (1) uniform with the value given. `-0.0` reads back as `-0`.
- `uniformWithName:texture:` makes a Texture (8) uniform. A nil texture is accepted and stays nil (measured with nil,
  and with a real `SKTexture` from `textureWithImageNamed:`, which reads back as set).
- The three initialisers (`initWithName:`, `initWithName:float:`, `initWithName:texture:`) give the same types and
  values as the factories of the same names. `alloc` then `init` gives a None uniform with name nil.
- `floatValue` set on a None uniform makes it a Float (measured: None then 3.5 reads back as type 1). Set on a Float
  uniform, it changes the value and not the type (7.25, type 1). Set on a Texture uniform, it changes the value and
  not the type (2, type 8). **The rule is the same for both payloads: a None uniform takes the type of the payload it
  is given, and any other type is kept.**
- `textureValue` set to a real `SKTexture` on a None uniform makes it Texture (8). Set to nil on a None uniform
  also makes it Texture (8): measured by `differential.m`, which first found the port wrong on this case. Set to nil
  on a Float uniform keeps Float (1), and on a Texture uniform keeps Texture (8). Set to a texture on a Float uniform
  keeps Float (1) and reads the texture back.
- `copy` gives a new object (not the same pointer) with the same name, type, float value and texture. `isEqual:`
  is identity: two uniforms made with the same name and value are not equal. This is what the host does; the port
  does not define `isEqual:` or `hash` either.
- `supportsSecureCoding` is YES. An archive made with `requiringSecureCoding:YES` round-trips the name, the type and
  the float value (measured for a Float uniform with 9.5, and a None uniform). A texture uniform round-trips its
  texture on the host, where the texture class exists.
- `description` is not claimed. On the host it prints `type:'Float'` for a None uniform in one probe and
  `type:'(null)'` for the same kind of uniform in another, so it is not a stable answer to measure; the port keeps
  NSObject's description.

## Why the port's bodies are its own, and what they do not claim

- `SKTexture` is SpriteKit's own class and the release has none. The port never names it as a class. A texture is
  the object the caller hands in, and the archive reads its class with `NSClassFromString(@"SKTexture")` at run time,
  so no SpriteKit symbol is imported. A strong reference would make dyld stop the application at launch on a
  release without SpriteKit.
- The archive keys are the port's own. The host's archive format is not claimed: a port archive is read back by the
  port, and the round trip is the claim.
- Nothing draws. A shader needs SpriteKit's renderer, which the port does not carry, so the uniform is held for the
  application and read back. `SKShader` is not in this object.
- The header `CharonSpriteKit.h` declares only the iOS 8 surface and does not import `<SpriteKit/SpriteKit.h>`. The
  SDK declares later members of `SKUniform` (the iOS 10 vector and matrix uniforms), and an implementation that
  includes it is incomplete for every release below 10: clang warns on each of them, which is the cause to avoid.
- The enumeration values are the SDK's (`spec/SpriteKit/declarations.tsv`, 0 to 8), and the host's measured types
  match them (None 0, Float 1, Texture 8).

## Owed

The iOS 10 uniforms (`uniformWithName:vectorFloat2/3/4:`, the matrix factories, their initialisers and the
`vectorFloat*Value` and `matrixFloat*Value` properties) are not carried in this object; they are owed rows in
`registry/SpriteKit/ios8.json` and go in their own object of release 10. The deprecated `floatVector*Value` and
`floatMatrix*Value` aliases (SDK availability 7.0, deprecated 10.0) are owed too: their types are GLKit's, which
the port does not carry.

## Device

Not run on a device. The differential is built for the host (arm64). The armv7 object compiles with
`-Wall -Wextra -Werror` against the 26.2 SDK for `armv7-apple-ios6.1.3` and exports the class, its ivars and the
protocol metadata of its conformances only. The 16.4 build SDK is resolved by the gate. Until a device run exists,
the implementation is device-unverified.
