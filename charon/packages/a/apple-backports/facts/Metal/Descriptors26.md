# The Metal 4 descriptors, and the tile pipeline's colour attachments

120 rows: the seventeen classes of Metal 4 that say what a pipeline is built FROM, and the two classes
of iOS 11 that say what a tile pipeline's colour attachments are. They are all plain data holders. The
case for carrying them is the same case the 16.0 and 14.0 families make and no other: a descriptor asks
the device nothing, so an application that fills one gets an object it can read, copy and reset, and the
half that is not there is named below and in each row's `effect`.

## The commands and their output

```
sh tests/backports/host/metal-census/descriptors26.sh
```

```
the differential, against Apple's own objects, with no device created:
  the DEVICE objects define all of them under Apple's own names (MTL4PipelineOptions and 22 more)
  ok   the control: ZZZNoSuchNameCharonR16 is not a class of this framework
  ok   fresh: shaderValidation: the port 0 and Apple's own object 0
  ok   copy of a changed one: shaderReflection: the port 2 and Apple's own object 2
  ok   fresh: maxCallStackDepth, and it is Apple's own 1 and not a zero: the port 1 and Apple's own object 1
  ok   fresh: writeMask, and it is MTLColorWriteMaskAll: the port 15 and Apple's own object 15
  ok   fresh: sourceRGBBlendFactor, and it is One: the port 1 and Apple's own object 1
  ok   a write copies: the slot holds a copy on both sides, not the object handed in
  ok   a nil empties the slot: the format is the default on both sides
  ok   fresh: options is nil on both sides, and NOT a fresh MTL4PipelineOptions
  ok   fresh: rasterSampleCount, and it is Apple's own 1: the port 1 and Apple's own object 1
  ok   fresh: vertexDescriptor IS an object on both sides
  ok   fresh: maxVertexAmplificationCount, and it is Apple's own 1: the port 1 and Apple's own object 1
  ok   fresh: isRasterizationEnabled is YES on both sides
  ok   fresh: vertexStaticLinkingDescriptor is an object on both sides
  ok   tile colour attachment 7: both sides answer a descriptor
  ok   fresh MTL4FunctionDescriptor is an object, and it has no members to compare
136 checks, each one against Apple's own object
all checks passed
the control: a mutation that does not compile is RUN FAILED, not red
  ok   RUN FAILED: the broken mutation did not build, and no binary was left to run
the mutations: one per thing the port decides that a header does not state
  red  the attachment's fresh write mask:   fresh: writeMask, and it is MTLColorWriteMaskAll: the port 2 and Apple's own object 15
  red  the options' copy carrying shaderReflection:   copy of a changed one: shaderReflection: the port 0 and Apple's own object 2
  red  the render pipeline's fresh rasterSampleCount:   fresh: rasterSampleCount, and it is Apple's own 1: the port 0 and Apple's own object 1
  red  the array's copy semantics on a write:   a write copies: the slot holds a copy on both sides, not the object handed in
  red  the stage's fresh maxCallStackDepth:   fresh: maxCallStackDepth, and it is Apple's own 1 and not a zero: the port 0 and Apple's own object 1
  red  the render pipeline's fresh vertex descriptor:   fresh: vertexDescriptor IS an object on both sides
  red  the tile array's getter:   tile colour attachment 0: both sides answer a descriptor
descriptors26: the differential is green, the control is RUN FAILED, and all seven mutants are red
```

**The seam, in one line.** The port's seventeen 26.0 classes and its two 11.0 classes are compiled under
other names, together, in one translation unit the script writes, and both copies are in one binary with
Apple's own; the case asks each side by its own name. The rename is a `#define` inside that unit and not
a `-D` on the command line: the same file with the same flags and the same `-D` produced an object
carrying Apple's name in one invocation and the port's in another, from one command line
(`facts/Metal/DeviceOnThisMachine.md` and `mdltexture.sh` are where that is written down). The binary is
asked for the renamed symbols and the run stops if they are absent, because a case that read Apple's
class and called it the port's would agree with itself.

**No device is created, and the reason is that a descriptor asks for none** - both sides are
`[[X alloc] init]`. That is measured, on a machine that HAS one, in
`facts/Metal/DeviceOnThisMachine.md`; the old reason (`MTLCreateSystemDefaultDevice()` hangs without a
GPU) was false and is gone.

## The values, and which of them a header does not give

Every default in the port is Apple's own, measured against a fresh object of Apple's class. The ones a
header states are stated there and measured anyway; the ones it does not are the ones worth having:

| what | Apple's own fresh value | where |
|---|---|---|
| `MTL4PipelineDescriptor.options` | **nil** | the header does not say, and an implementer would guess a fresh options |
| `MTL4RenderPipelineDescriptor.vertexDescriptor` | **an object**, a fresh `MTLVertexDescriptor` | ditto, and the opposite guess |
| the `null_resettable` static linking descriptors | **objects** on a fresh descriptor | `null_resettable` says the getter may hand one back; the port makes one on first use and the compute and tile descriptors make one in `-init` |
| `rasterSampleCount`, `maxVertexAmplificationCount` | **1** | not 0 |
| `isRasterizationEnabled` | **YES** | not NO |
| `MTL4PipelineStageDynamicLinkingDescriptor.maxCallStackDepth` | **1** | not 0 |
| the colour attachment's write mask | **15**, `MTLColorWriteMaskAll` | |
| its source factors / destination factors / operations | **One / Zero / Add** | the header says so, and it is measured |
| its pixel format | **0**, `MTLPixelFormatInvalid` | |
| the colour attachment array | **eight slots** | the header declares two members and no bound; indices 0 to 7 answer a descriptor and index 8 fails Apple's own assertion |
| the tile colour attachment array | **eight slots** | the same measurement, out of process |
| `requiredThreadsPerThreadgroup` and the mesh ones | **0 x 0 x 0** | not 1 x 1 x 1 |

**The two eight-slot bounds are measured OUT OF PROCESS, one index per invocation**, because index 8
triggers an assertion that STOPS the process: a case that asked 0 to 8 in one run would die at 8 having
compared nothing after it. That is the same shape as the four-slot measurement
`facts/Metal/Descriptors16.md` records for the 14.0 family, and the same reason.

## The three things a mutation had to be spent on, and what two of them were first

The seven mutations are one per thing the port decides that a header does not state. Three of them were
**wrong on the first attempt** and the harness said so, which is the reason to keep the mutations:

* **M1** was the attachment's write mask and is red. **M2** was the base's `options` SETTER, and it came
  back GREEN - nothing in the case ever sets `options` to nil, so nothing observed it. It is now the
  options' `-copyWithZone:` dropping `shaderReflection`, and the case was strengthened to copy a
  descriptor a caller has CHANGED, because two copies of two fresh objects agree whatever the copy does.
* **M4** was the array's reset of a nil, and it came back GREEN: the getter makes a descriptor when the
  slot is empty, so emptying a slot and resetting it are the same thing through the only way in. A reset
  nothing can observe is not proved by a green run. The port keeps the reset because the header asks for
  it (`MTL4RenderPipeline.h`: "You can safely set the color attachment at any legal index to nil. This
  has the effect of resetting that attachment descriptor's state to its default values"), and M4 is now
  the copy semantics of a write, which the case does compare. What a nil shows is named in the case:
  the slot is empty again, so the getter answers a fresh descriptor and the format is the default on
  both sides.

## The Metal 4 render pass descriptor, and THREE bounds its sample positions have

18 rows, and every measured default is a zero, a nil or one NO - which is worth measuring anyway,
because it is the answer a reader would guess. The three attachment OBJECTS on a fresh pass are the
ones a nil getter would get wrong, and the colour attachment array is the same eight-slot array
MTLRenderPassDescriptor's own uses.

**The two sample-position methods are the only members here that are an array rather than a number,
and FIVE of their bounds came out of Apple's own assertions rather than out of the header.** Each line
below is quoted from a file captured out of the framework's stderr, one invocation per bound, so the
wording and the line numbers are Metal's:

| what is refused | Apple's own line, captured from its stderr | the port |
|---|---|---|
| a count that is not a sample count | line 417: ``count (3) is not a supported sample count for custom positions. count must be 0, 2, 4 or 8.`` | refuses any other count, naming the four |
| an **x** coordinate outside [0, 1) | line 433: ``Provided sample position x-coodicate (1.500000) at index 1 is not within the range [0,1).`` | refuses, naming the index and the value |
| a **y** coordinate outside [0, 1) | line 435: ``Provided sample position y-coodicate (1.500000) at index 1 is not within the range [0,1).`` | refuses, naming the index and the value |
| a read whose count is **smaller** than what is programmed | line 449: ``Non-zero count (2) does not match the number of programmed custom sample positions (4).`` | refuses |
| a read whose count is **larger** than what is programmed | line 449: ``Non-zero count (8) does not match the number of programmed custom sample positions (4).`` | refuses |

**AND ONE COUNT THAT IS NOT A REFUSAL**, because a table of refusals with nothing else in it would be
satisfied by a port that refuses everything: a read with a count of **zero** asserts nothing and answers
the programmed count. That is the count a caller uses to ask how many there are without room for them,
and both sides answer 4 to it.

**The word is "coodicate".** This page's first draft and the port's two message strings both had
"coodificate", and it is Apple's own typo in neither place: all four lines above are quoted from
captured stderr and every one of them reads `coodicate`. The port's messages now spell it as Metal
spells it, because a message that quotes Metal's wording has to be Metal's wording.

**AND THE TWO DISABLE SPELLINGS DIFFER, which is the one a reader would get wrong.** With two
positions programmed, `setSamplePositions:NULL count:0` leaves the object holding **TWO** - a NULL
pointer stores nothing - while the same call with a non-NULL pointer and a count of 0 leaves it holding
**NONE**, which is what `MTL4RenderPass.h:107` means by "or 0 to disable custom sample positions". Both
are measured, both are in the differential, and the port does what Apple's object does.

**What its equality does and does not compare** is measured too, and it is the same shape as the tile
pipeline's array: the DEPTH and STENCIL attachments are compared member by member - neither class
carries an `-isEqual:` of its own, yet two fresh ones are equal on Apple's side and changing one's
`clearDepth` makes them differ - while the COLOUR attachments are not compared at all, because
`MTLRenderPassColorAttachmentDescriptorArray` carries no `-isEqual:` either, two fresh arrays are NOT
equal, and two fresh render passes ARE.

## The acceleration structure geometry descriptors, and the four defaults a guess gets wrong

Seven more classes, 64 rows, and the same kind of thing: a geometry descriptor says which buffers hold
a geometry and in what shape, and asks the device nothing. The four defaults below are Apple's own,
measured against a fresh object of Apple's class, and every one of them is a value the enumeration or a
zero would have got wrong:

| what | Apple's own fresh value | the wrong guess |
|---|---|---|
| `allowDuplicateIntersectionFunctionInvocation` | **YES** | NO |
| a triangle's `vertexFormat` | **30**, `MTLVertexFormatFloat3` | 0, a fresh enumeration |
| a triangle's `indexType` | **1**, `MTLIndexTypeUint32` | 0 |
| a curve's `radiusFormat` | **28**, `MTLVertexFormatFloat` - ONE component | 29, `Float2` |
| a bounding box's `boundingBoxStride` | **24**, three float32s | 0 |

**The radius format is the one worth writing down twice**: this file's own first assertion for it said
`MTLVertexFormatFloat2`, and the measurement said 28 - which is `MTLVertexFormatFloat`, one component,
because a radius is one number. The assertion was wrong and the measurement corrected it; both the
assertion and the port's comment now say Float and name 28.

The three motion descriptors are the same three shapes with a second buffer per vertex, and the header
spells that with a plural - `vertexBuffers`, `boundingBoxBuffers`, `controlPointBuffers` - which this
file keeps.

**What none of them is for**: a ray tracing unit, which this port's hardware has not. That is the same
half `facts/Metal/Metal16Absence.md` records for the 16.0 family, and every row's `effect` says it.

## Value equality, which Apple's own objects have and the port now has too

**Measured on Apple's side, class by class**: all twenty-three MTL4* classes carry an `-isEqual:` and an
`-hash` OF THEIR OWN, and the two iOS 11 tile classes carry NEITHER. Measured with
`class_copyMethodList`, not read off a header. For each of the sixteen: two freshly made objects are
equal, their hashes agree, and a copy equals its source.

So the port has all sixteen, member by member, and neither of the two 11.0 classes - which keeps
NSObject's identity equality, as Apple's does.

```
sh tests/backports/host/metal-census/descriptors26.sh
```

```
Apple's own answers to the value-equality questions, in a binary of their own:
  the port's value equality IS Apple's own, member for member: 75 answers agree
    MTL4PipelineOptions fresh-equal yes
    MTL4PipelineOptions fresh-hash-same yes
    MTL4PipelineOptions copy-equal yes
descriptors26: the differential is green, the Apple-side answers agree, the control is RUN FAILED, and all nine mutants are red
```

**Two binaries and a diff, not one case asking both sides**, and the reason is worth the lines it takes:
asking Apple's `-isEqual:` in a binary that also carries the port's classes trapped - measured, a
Trace/BPT trap inside `objc_opt_respondsToSelector` at the first such call, reproducibly. So
`descriptors26-apple.m` asks Apple's own objects the same questions in a binary with no class of the
port's in it, `descriptors26-value.m` asks the port's, and the script diffs the two runs.

### Four defects the measurement found, each of which a compile could not

1. **`[nil isEqual:nil]` is NO.** A message to nil answers zero, so an equality written
   `![self.a isEqual:other.a]` says two objects that have no value for that member are NOT equal. Every
   class with an object member answered exactly that, and only those: measured, the first run of the
   value case failed 29 checks on 10 classes. The pointer shortcut `self.a != other.a && ![self.a
   isEqual:other.a]` is what every object member now carries, and it is not decoration.
2. **THE TILE DESCRIPTOR DOES NOT COMPARE ITS COLOUR ATTACHMENTS.** Apple's own
   `MTLTileRenderPipelineColorAttachmentDescriptorArray` carries no `-isEqual:` - measured, its own
   method list has neither it nor `-hash` - so two fresh arrays are two objects that are not equal,
   and yet two fresh `MTL4TileRenderPipelineDescriptor`s on Apple's side ARE equal, also measured. An
   equality that compared the attachments could not answer that. The render and mesh descriptors beside
   it DO compare theirs, because their array is `MTL4RenderPipelineColorAttachmentDescriptorArray` and
   that one carries an `-isEqual:` of its own.
3. **APPLE'S `MTLVertexDescriptor` HAS VALUE EQUALITY, AND OURS DID NOT** - and that is two releases
   away. A Metal 4 render pipeline descriptor compares its vertex descriptor, so without it two fresh
   render descriptors on this port were not equal where Apple's are. `MTLVertexDescriptor8.m` now has it,
   comparing its two arrays element by element through their own getters and member by member, because
   the two array classes are the SDK's PROTOCOLS here and carry no `-isEqual:` of their own.
4. **`MTL4FunctionDescriptor` HAD NO `-copyWithZone:`, AND A FILE-LEVEL `#pragma` WAS HIDING IT.** The
   26.2 header declares the class as `NSObject <NSCopying>`; `#pragma clang diagnostic ignored
   "-Wprotocol"` turned the warning into a silence. The pragma is gone, the method is there, and this
   file builds with no diagnostic silenced.

### The two mutations that hold the member list to the measurement

A class that compared NOTHING answers "equal" to three of the four questions and to the fourth, so the
fourth - change one named member and ask again - is the one that holds it to the member list. M8 drops
`shaderReflection` from the options' equality and is red on exactly that check; M9 drops the DEPTH of the
compute descriptor's required threadgroup size, and the case changes the depth alone so a mutation that
only dropped the width or the height would still be caught.

## What none of these objects is for, and which rows say so

**Nothing in this port reads a descriptor made here.** There is no `MTL4CommandQueue`, no
`MTL4CommandBuffer` and no pipeline state this port builds from any of these, so an application that
fills one gets an object it can read, copy and reset - and no object to hand it to.

The mesh pipeline is the sharpest case, and it is the same argument `facts/Metal/Metal16Absence.md`
makes for the 16.0 mesh descriptor: its three `MTL4FunctionDescriptor` members ARE the pipeline's
object, mesh and fragment stages rather than values this port can hold, and this port's rendering path
is Metal over OpenGL ES 2.0 (`facts/Metal/RenderPath.md`), which has no mesh stage and no geometry or
tessellation stage either.

Each row's `effect` says exactly that, because `implemented` owes a reader the measured behaviour
INCLUDING the part that is not there.

## What is not measured here

**What a pipeline built from any of these would DO.** That needs a Metal 4 command queue and a pipeline
state, and neither is in this port - which is a statement about the port and not about the host, and it
is the same absence the 16.0 family records. Every member of these classes IS measured, against Apple's
own object, on the member the header names.