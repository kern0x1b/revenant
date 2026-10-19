# SKNode (iOS 7, with the iOS 8 subscript and the iOS 9 move)

The iOS 7 surface of SpriteKit's `SKNode`: the node tree, the local transform, the frame, the hit tests and the
conversions. The port's objects are `SpriteKit/SpriteKit7.m` (the class), `SpriteKit/SpriteKit8.m` (the subscript,
in a category) and `SpriteKit/SpriteKit9.m` (`moveToParent:`, in a category), all declared by
`SpriteKit/CharonSpriteKit.h`. The config is `spritekit`, the library is `libSpriteKitBackports.dylib`. The rows are in
`registry/SpriteKit/ios7.json`, `ios8.json` and `ios9.json`.

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64, `SpriteKit.framework` from the host's SDK. The
committed check is `tests/backports/host/spritekit-node/`. `differential.m` is one runtime-only program (no SpriteKit
header, typed `objc_msgSend` casts, `NSClassFromString`) built against the host framework and against the port's three
objects. Both print the same 98 lines, and they are compared line by line. The control links a copy of `SpriteKit7.m`
in which a name is matched exactly instead of as an `fnmatch(3)` pattern. The control differs on 14 lines, which is
what makes the comparison meaningful. Run it with `sh tests/backports/host/spritekit-node/run.sh`.

The rules below are the host's answers, from that log.

### Defaults and the node

- A new node (`+node`, `-init`) has name nil, position (0,0), zPosition 0, zRotation 0, xScale and yScale 1, alpha 1,
  speed 1, paused NO, hidden NO, userInteractionEnabled NO, parent nil, no children and userData nil.
- `frame` and `calculateAccumulatedFrame` of a plain node are `{0,0,0,0}`.
- `setScale:2` sets xScale and yScale to 2. `zPosition` set to 4.5 reads back 4.5.

### The tree

- `addChild:` appends. `insertChild:atIndex:` at 0 puts the node first.
- Adding a node that already has a parent raises `NSInvalidArgumentException` (`addChild:` with the same node into the
  same parent, and into another parent, both raise). Adding a node to its own subtree raises too (self, and an ancestor
  added to a descendant). The tree is unchanged by the refused add.
- `addChild:nil` raises an exception whose `name` is the host's own text, `Attemped to add nil node` (spelled that way
  by the host). The port raises the same name.
- `insertChild:atIndex:` with a nil node and with an index past the end: see the crash cases below.
- `removeFromParent` clears the parent (measured on a childless node). On a node with no parent it does nothing.
- `removeChildrenInArray:` removes each listed node that is a child, and skips one that is not. The order of the others
  is kept.
- `removeAllChildren` empties the children, and each child's parent becomes nil.
- Moving a node: `removeFromParent` then `addChild:` (what `moveToParent:` does) appends the node to the new parent:
  after `moveToParent` of `c` to `a`, `a` lists `[x, c]`.

### Names and paths (`childNodeWithName:`, the subscript and the enumeration)

Measured on the host, with the children of a root `[a, b, b, c]` and the grammar tree described below.

- `childNodeWithName:` answers the first child in order that the path picks out. A name that is not a child answers nil,
  and a child's own children are not searched for a plain name.
- `/` separates components. A leading `/` is relative, so `/q` is `q`. A path ending in `/` (`q/`) answers nil, and so
  does `q//`.
- `//` searches descendants. It is breadth first: `//*` lists the children before the grandchildren. `//y` finds `y`
  under `a/x`.
- `.` is the node itself and `..` is its parent: `childNodeWithName:.` answers the root, `a/../b` answers `b`, and `a/.`
  answers `a`.
- A name is an `fnmatch(3)` pattern: `*` matches the first child, `b*` matches each child whose name starts with `b`, and
  `?` matches a one-character name. `c.` is not a match for `c`, so it answers nil.
- The subscript (`node[@"path"]`, iOS 8) answers the same matches as an array, in the same order: `subscript:b` gives
  `[b, b]`, `subscript:*` gives all four children, and `subscript:none` gives `[]`.
- `enumerateChildNodesWithName:usingBlock:` calls the block for each match in order; setting `stop` ends it (`enumerate:b
  stop` gives `[b]`).
- A path that names a node is matched among the node's children only: from a child, the name of its own parent does not
  answer (`name lookup from child: nil`).

The grammar tree in the log has these answers, which the port reproduces: `b*` child `b1`; `?` child `q`; `//*` child
`b1`; `//deep` and `q//deep` both `deep`; `q/` nil; `/q` `q`; `subscript b*` `[b1, bb]`; `subscript //*` `[b1, bb, q,
deep]`; `subscript //b` `[]` (the descendant named exactly `b` is absent); `subscript *` `[b1, bb, q]`; `multi b*/x`
`[x, x]`; `multi ../multi` `b2`; `multi ./b1` `b1`.

A nil or empty name in a path crashes the host: see the crash cases below. A name with a trailing `//` is unmeasured.

### Crash cases (tests/backports/host/spritekit-node/crash.m)

Each case runs in its own process, so a crash ends only that case, and the harness compares the output line and the exit
status. Measured on the host:

- `childNodeWithName:nil`, `childNodeWithName:@""`, `objectForKeyedSubscript:` with nil and with `@""`, and
  `enumerateChildNodesWithName:usingBlock:` with nil: the host is killed by SIGSEGV, with no exception. The port answers
  nil, an empty array and nothing, and does not crash.
- `insertChild:nil atIndex:0` raises an exception whose name is `Attemped to add nil node`, and whose reason describes
  the node it was added to: `Attemped to add nil node to parent: <SKNode> name:'(null)' position:{0, 0} scale:{1.00, 1.00}
  accumulatedFrame:{{0, 0}, {0, 0}}`. With a named node at (3,4), scale (2,0.5), the reason reads
  `... <SKNode> name:'root' position:{3, 4} scale:{2.00, 0.50} accumulatedFrame:{{3, 4}, {0, 0}}`. The port builds this
  text from the same fields. Other values (non-zero frames, subclass names) are not measured.
- `insertChild:atIndex:` at an index from 2 up to 2147483647 (2^31 - 1) on a one-child node: the host is killed, by SIGBUS
  or SIGSEGV depending on the index. The port raises `NSRangeException`, with the array's own reason.
- At an index of 2147483648 (2^31) or more, up to NSUIntegerMax: the host raises `NSRangeException` with reason
  `*** -[__NSArrayM insertObject:atIndex:]: index N beyond bounds [0 .. M]`. The port raises the same, because its insert
  is the array's own (no check in the port), so the reasons are identical on both sides.
- An index equal to the child count appends (measured: a two-child result at index 1 of one child).

### Transforms and conversions

- `convertPoint:(0,0) fromNode:h` to the root gives `(15,25)` for the tree in the log, and the reverse gives `(-15,-25)`.
- `convertPoint:(1,2) fromNode:h` to `g` (a sibling) gives `(6,7)`.
- With scale 2 on the parent the root point is `(22,41)`; with a rotation on the parent `(1,0)` gives `(-5,32)`.
- The local transform is the scale, then the rotation, then the translation, and the conversion goes through the scene
  root both nodes share. The port composes the same order (`CharonSKLocalTransform`).

### Frames, hit tests and equality

- A node with no content has a zero-size frame at its position. A node at (10,20) with no content reads its frame as
  `{10,20,0,0}`, and its child at (5,7) reads `{5,7,0,0}` in its parent's coordinates. The accumulated frame of the
  parent stays `{10,20,0,0}`: the child's frame is empty and adds nothing.
- `containsPoint:` of a plain node is NO. `nodesAtPoint:` of a plain node is empty, and `nodeAtPoint:` of a plain node is
  the node itself.
- `intersectsNode:` of two zero-size nodes is NO. The port answers NO for any empty accumulated frame; the host agrees on
  the zero-size case, which is the only one measured.
- `isEqualToNode:` is identity: the node itself is YES and a different node is NO. `isEqual:` is identity too.

### userData

- `userData` is nil on a new node and reads back the dictionary the application sets.

## Owed and unmeasured

Owed rows (in `registry/SpriteKit/ios7.json`) are the members that need a later object: `scene` is carried now (facts/SpriteKit/SKScene.md),
`physicsBody` (physics), `constraints` and `reachConstraints`, the attribute members (iOS 10), `focusBehavior` (iOS 11),
the action family (step 3), `initWithCoder:`, `nodeWithFileNamed:` (and its iOS 12 secure form), and the `NSCopying`
and `NSSecureCoding` conformances. `hasActions` is owed with the action family, so the differential does not probe it
either.

Unmeasured, and so not claimed by the port's behaviour:

- `nodeAtPoint:` and `nodesAtPoint:` with descendants that have non-zero frames: the order of the hits.
- `intersectsNode:` with non-zero frames, and with zero-width frames that are not zero-size.
- `moveToParent:` in its failure cases (a nil parent, a parent that is the node or its descendant). The port raises as
  `addChild:` does; the host is not measured.
- Exception reasons other than `addChild:nil`'s name, which is measured.
- `userData` copy semantics on set (whether the host copies the dictionary).
- `description`, and the containsPoint: answer of a subclass that overrides it.
- The constraints and reach constraints availability: the spec rows of those members carry no availability, so they
  are recorded at the class's 7.0, and the release they arrived in is unverified.

## Device

Not run on a device. The differential runs on the host (arm64). The three objects compile for `armv7-apple-ios6.1.3`
with `-Wall -Wextra -Werror` against the 26.2 SDK. The 16.4 build SDK is resolved by the gate. Until a device run exists,
the implementation is device-unverified.
