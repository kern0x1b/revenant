# The body's joints: what ARKit names, and where the names were read

Everything on this page was read out of one file, `~/.charon/dyld/16.0/dyld_shared_cache_arm64e`
(the arm64e shared cache of iOS 16.0), with the project's own readers: `modules/apple/dyld.lua`
through `open_cache` for the address space, `tools/corpus/cache-value.lua` for an exported constant's
value, and `tools/corpus/skeleton-table.lua` (new, in this repository) for the tables inside
ARKitCore's image. No `ipsw` ran, nothing outside this repository was written, and the cache is read
only. Every address below is in that file's own address space.

The image is `/System/Library/PrivateFrameworks/ARKitCore.framework/ARKitCore`, which is where ARKit's
body tracking lives: `+[ARSkeletonDefinition defaultBody2DSkeletonDefinition]` and the 3D one are
methods of `ARSkeletonDefinition`, whose own method list is in ARKitCore's `__objc_methlist`.

## The eight exported joint names

`cache-value.lua` reads an exported data symbol's value and, when the declaration says it is a
pointer to a string, follows the pointer and reads the CFString's characters. Its own output, run
over the eight symbols with the widths their `NSString * const` declarations give:

```
#cache	arm64e	8
ARSkeletonJointNameRoot	/System/Library/PrivateFrameworks/ARKitCore.framework/ARKitCore	0x1d6d4fe80	...	root	8	8
ARSkeletonJointNameHead	...	0x1d6d4fe88	...	head_joint	8	8
ARSkeletonJointNameLeftShoulder	...	0x1d6d4feb0	...	left_shoulder_1_joint	8	8
ARSkeletonJointNameRightShoulder	...	0x1d6d4feb8	...	right_shoulder_1_joint	8	712
ARSkeletonJointNameLeftHand	...	0x1d6d4fe90	...	left_hand_joint	8	8
ARSkeletonJointNameRightHand	...	0x1d6d4fe98	...	right_hand_joint	8	8
ARSkeletonJointNameLeftFoot	...	0x1d6d4fea0	...	left_foot_joint	8	8
ARSkeletonJointNameRightFoot	...	0x1d6d4fea8	...	right_foot_joint	8	8
```

(The bytes and the widths are elided here to keep the table readable; the full run's verbatim output
is in the commit message of the change that fixed the values, and `tools/corpus/cache-value.lua`
prints all eleven columns unchanged.)

Controls, without which a read of eight strings means nothing:

- **All eight answered.** A symbol no image of the cache exports comes back as a line of dashes;
  eight answers is eight real symbols in ARKitCore's export table, not eight guesses.
- **The eight values are distinct and the addresses are eight apart** (`0x1d6d4fe80` through
  `0x1d6d4fea8`), which is what a table of eight exported pointers looks like, so each read is of
  the symbol it names and not of its neighbour.
- **The reader is reading, not recalling.** Seven of the eight names the release answers with end in
  `_joint` and both shoulder names carry a `_1`; nothing in the request that produced this table
  said so. A reader that answered from the declaration would have said `head`, `left_shoulder`.
- `ARSkeletonJointNameRightShoulder`'s storage reads 712 rather than 8, because it is not followed
  closely by another export of that image; the tool bounds a read by the distance to the next export
  and refuses a wider one, and the value came back whole.

So the seven names that this repository had without a `_joint` suffix, and the two that had no `_1`,
were wrong, and are now the release's own strings.

## The two-dimensional skeleton: seventeen joints, and their parents

`-[ARSkeletonDefinition defaultBody2DSkeletonDefinition]` is `0x1af1a93dc` in that image (the
function's own start, from ARKitCore's `LC_FUNCTION_STARTS`: the neighbours are `0x1af1a939c` and
`0x1af1a964c`, and its size is `0x270`). It builds the names array as a literal list and puts the
parent table in a constant `CFArray`, so both are read out of the image rather than guessed:

- **Names, in source order.** The list is nineteen `__cfstring` constants stored pairwise on the
  stack and handed to `[NSArray arrayWithObjects:count:]` with `w3 = 0x13`; seventeen of them when
  the count is `0x11`, which is the same list without the two ear joints, and **the seventeen is what
  Apple answers** (see the host below). Resolved through each constant's chars pointer, in the order
  the stores put them:

  | index | joint | index | joint |
  | --- | --- | --- | --- |
  | 0 | `head_joint` | 10 | `right_foot_joint` |
  | 1 | `neck_1_joint` | 11 | `left_upLeg_joint` |
  | 2 | `right_shoulder_1_joint` | 12 | `left_leg_joint` |
  | 3 | `right_forearm_joint` | 13 | `left_foot_joint` |
  | 4 | `right_hand_joint` | 14 | `right_eye_joint` |
  | 5 | `left_shoulder_1_joint` | 15 | `left_eye_joint` |
  | 6 | `left_forearm_joint` | 16 | `root` |
  | 7 | `left_hand_joint` | 17 | `right_ear_joint` |
  | 8 | `right_upLeg_joint` | 18 | `left_ear_joint` |
  | 9 | `right_leg_joint` | | |

- **Parents**, the constant `CFArray` at `0x1e0be6af0`: count 19 at `+8`, the values array at
  `0x1d6d90890` at `+16`, and each value an `NSNumber` in `__objc_intobj` whose integer is the
  third word of the object. The nineteen integers, in order:

  ```
  1, 16, 1, 2, 3, 1, 5, 6, 16, 8, 9, 16, 11, 12, 0, 0, -1, 14, 15
  ```

**Which of the two is the default, and the host settles it.** The initialiser asks one question of
its own (`bl 0x1af0c2c28` at `0x1af1a9430`) and builds the nineteen-joint list when the answer is
yes and the seventeen-joint list when it is not. This Mac's own ARKit answers seventeen:

```
$ xcrun clang -fobjc-arc -w probe.m -framework Foundation -o probe && ./probe
handle=0x36c5c0b48
class=0x2d9eb4bb0 name=ARSkeletonDefinition
definition=0x1014318e0
  [0] head_joint        [6]  left_forearm_joint   [12] left_leg_joint
  [1] neck_1_joint      [7]  left_hand_joint      [13] left_foot_joint
  [2] right_shoulder_1_joint  [8] right_upLeg_joint  [14] right_eye_joint
  [3] right_forearm_joint     [9] right_leg_joint     [15] left_eye_joint
  [4] right_hand_joint        [10] right_foot_joint   [16] root
  [5] left_shoulder_1_joint   [11] left_upLeg_joint
parentIndices count=17
  [0] 1    [4] 3    [8] 16   [12] 11   [16] -1
  [1] 16   [5] 1    [9] 8    [13] 12
  [2] 1    [6] 5    [10] 9   [14] 0
  [3] 2    [7] 6    [11] 16  [15] 0
```

Three independent reads of the seventeen, and all three agree: the count `w3 = 0x11` the initialiser
uses on that branch; the constant `CFArray` at `0x1e0be6b08` (count 17, values `0x1d6d90928`, integers
`1, 16, 1, 2, 3, 1, 5, 6, 16, 8, 9, 16, 11, 12, 0, 0, -1`); and the host above. The nineteen-joint
parent table is the seventeen-joint one with `14` and `15` appended, which is what appending
`right_ear_joint` and `left_ear_joint` at the end of the names does to it -- the two tables are one
table and a pair of ears.

Two further reads of the same seventeen, which agree:

1. Reading the table and the name order together, every parent is an ancestor of its joint in a way
   a body has to have: `head` hangs off `neck_1` (0 -> 1), `neck_1` off `root` (1 -> 16), each
   forearm off its shoulder and each hand off its forearm (3 -> 2, 4 -> 3, 6 -> 5, 7 -> 6), each leg
   off its upper leg (9 -> 8, 12 -> 11), each eye off `head` (14 -> 0, 15 -> 0), each ear off its eye
   (17 -> 14, 18 -> 15), and `root` off nothing (16 -> -1).
2. The name order was read twice from different places — once from the order the stores in the
   initialiser put the strings on the stack, once from the parent table's own consistency above —
   and the two orders are the same list.

The check that the reader is looking at this array and not a neighbour: the array's count field says
19, and so does the `movz w3, #0x13` in the initialiser that installs it, and its values are
`NSNumber`s in the same image's `__objc_intobj`, and one of them is the image's own `-1` (which is
what `root` needs and what nothing else in a parent table needs).

## The three-dimensional skeleton: 91 names, and a hierarchy that is not in the image

**Names.** ARKitCore's `__const` holds one hundred and eight consecutive `const char *` at
`0x1d6d4f988` through `0x1d6d4fce0`, all pointing into the same image's `__cstring`, and the run is
two tables side by side: seventeen CoreIK bone names (`hip`, `righthip`, `rightknee`, `rightfoot`,
`lefthip`, `leftknee`, `leftfoot`, `spine`, `centershoulder`, `centerhead`, `tophead`,
`leftshoulder`, `leftelbow`, `lefthand`, `rightshoulder`, `rightelbow`, `righthand`) and then, from
`0x1d6d4fa10`, the ninety-one joints. That the run is contiguous is what puts the joints' first
entry at `0x1d6d4fa10` rather than at the run's start. The ninety-one names,
in the order the table has them: `root`, `hips_joint`, `left_upLeg_joint`, `left_leg_joint`,
`left_foot_joint`, `left_toes_joint`, `left_toesEnd_joint`, `right_upLeg_joint`, `right_leg_joint`,
`right_foot_joint`, `right_toes_joint`, `right_toesEnd_joint`, `spine_1_joint` .. `spine_7_joint`,
`left_shoulder_1_joint`, `left_arm_joint`, `left_forearm_joint`, `left_hand_joint`,
`left_handIndexStart_joint`, `left_handIndex_1_joint` .. `left_handIndex_3_joint`,
`left_handIndexEnd_joint`, and the same six groups for `Mid`, `Pinky`, `Ring`, `Thumb` on the left,
then `neck_1_joint` .. `neck_4_joint`, `head_joint`, `jaw_joint`, `chin_joint`, `left_eye_joint`,
`left_eyeLowerLid_joint`, `left_eyeUpperLid_joint`, `left_eyeball_joint`, `nose_joint`,
`right_eye_joint`, `right_eyeLowerLid_joint`, `right_eyeUpperLid_joint`, `right_eyeball_joint`, and
the same shoulder/arm/forearm/hand groups on the right.

**The hierarchy is not a table in this image, and that is a measurement, not an estimate.**
`-[ARSkeletonDefinition initDefault3DSkeletonDefinition]` (`0x1af1a8fc4`, size `0x384`) builds both
arrays in a loop over a CoreIK rig: it asks CoreIK (`/System/Library/PrivateFrameworks/CoreIK
.framework/CoreIK`, reached through a branch stub at `0x1b4a92d90` and one at `0x1b4a92da0`) for the
name and the parent name of joint *i*, looks the parent name up in the name array, and appends the
index it finds. So the parent table is a result, not a constant. What the image does hold is the
rig description CoreIK reads, and this project's readers cannot read it: the slot that points at it
is in `__auth_ptr`, and the reader's `pointer_at` resolves it to an address inside `__text`
(`0x1d361cba8`, whose first words disassemble to a `sub w9, w9, #imm` prologue), which is a code
address and not a table. `__const` in this image holds no run of ninety-one small integers either:
the widest run with every value in `[-1, 90]` that a scan of `__const`, `__data` and `__objc_const`
found is 1644 words of a repeating eighteen-value pattern, and the run near `0x1af24ddc8` (which does
hold the `91` this rig has, and the `17` the two-dimensional one has) is that same kind of table.

So `parentIndices` for the three-dimensional definition is **not measured**, and nothing in this
repository answers it with a value that was not read.

What would measure it: the rig description CoreIK reads is a block of `0x16d0` bytes that
`-[ARSkeletonDefinition initDefault3DSkeletonDefinition]`'s two helpers copy out of an authenticated
pointer slot, and this project's readers do not decode that slot -- `pointer_at` on it answers an
address in `__text`. A reader for `DYLD_CHAINED_PTR_ARM64E_SHARED_CACHE` (the 16-bit target, 16-bit
high8, 19-bit next, 1-bit bind, 27-bit auth split) applied to `__auth_ptr` would give the block's
address, and the block's head would then say how many bones it has and in what order. Until that
reader exists the honest answer is that this table was not read, which is what the registry records.

## The host's answer for the three-dimensional definition is empty

The Catalyst ARKit on this Mac, which is the port's host oracle, answers the same question the image does, and it
answers with nothing. `+[ARSkeletonDefinition defaultBody3DSkeletonDefinition]` returns an object, and that object
has `jointCount` 0, no `jointNames` and no `parentIndices`. Measured by a one-file program compiled with the host's
flags (`-target $(uname -m)-apple-ios14.0-macabi`, the iOSSupport frameworks), on this Mac, against the 16.4 SDK.

So neither the image nor the host gives the three-dimensional joints, and the port cannot build the definition from
either. The two-dimensional table above is built from the image and checked against the host; the three-dimensional
one has no host data to check against. `defaultBody3DSkeletonDefinition` and `neutralBodySkeleton3D` stay owed
(`registry/ARKit/ios13skeleton.json`). The host's `neutralBodySkeleton3D` returns an `ARSkeleton3D`, whose transform
count was not read; it does not change the answer, because the definition it belongs to has no joints.

## What a reader needs to reproduce all of this

The readers used are the project's, and the two tools this work added are in `tools/corpus/`:

- `tools/corpus/cache-value.lua` (existing) for the eight exported constants.
- `tools/corpus/skeleton-table.lua` (new) for a table of pointers into one image's `__cstring`, for
  the ninety-one names, and for the constant `CFArray` of `NSNumber`s, for the parents.
- The method list, the `LC_FUNCTION_STARTS` boundaries, the branch-stub chain to CoreIK and the
  disassembly were read with `modules/apple/dyld.lua`'s `open_cache`, `image_symbols` and
  `read_address`, driven by `tools/corpus/skeleton-table.lua`.

One thing a reader of this page should know about the image's method lists, because it is the reason
an Objective-C inventory alone does not answer a question like this one: ARKitCore's own
`__objc_methlist` holds *small relative* method lists, `entsize_and_flags = 0xc000000f`, that is
twelve bytes per entry as three 32-bit chained-pointer offsets, with the selector read as
`selector_base + offset` and the implementation as `field + signed-36-bit offset`. The selector
resolves to a real string that way; a reader that assumes the full twenty-four-byte entry reads
neither.