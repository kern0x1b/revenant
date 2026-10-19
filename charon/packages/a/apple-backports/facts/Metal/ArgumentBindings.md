# Argument bindings: the five objects a kernel's resources are described by

When a kernel's arguments are bound, each resource is described by a *binding*: what it is, how
it is read, and the numbers that describe the memory behind it. Those bindings are plain data.
None of them asks the device anything, which is the whole case for carrying them — a port that
dispatches a device pointer and the three thread identifiers still has to hand these back when a
caller asks what a kernel binds. They are in `Metal/MTLArgumentBinding16.m`, one object, which
`release-split` on it reports `clean, every object file's symbols first-appear in one release
(1 files, 0 symbols, 50 releases checked)`. **The 16.0 the rows carry is the ladder's band, not a
measurement of this object**: the tool placed **0 symbols**, because every symbol the object defines
is port-internal (`CharonMetal`-prefixed, which the tool excludes by design), so there is nothing in
it for the tool to place in any release.

## The rows

| protocol | header | the port's class | kind it answers |
| --- | --- | --- | --- |
| `MTLBinding` | `MTLArgument.h:335-343` | `CharonMetalBinding` | the base; buffer |
| `MTLBufferBinding` | `MTLArgument.h:346-352` | `CharonMetalBufferBinding` | `MTLBindingTypeBuffer` (0) |
| `MTLTextureBinding` | `MTLArgument.h:361-366` | `CharonMetalTextureBinding` | `MTLBindingTypeTexture` (2) |
| `MTLThreadgroupBinding` | `MTLArgument.h:355-358` | `CharonMetalThreadgroupBinding` | `MTLBindingTypeThreadgroupMemory` (1) |
| `MTLObjectPayloadBinding` | `MTLArgument.h:369-372` | `CharonMetalObjectPayloadBinding` | `MTLBindingTypeObjectPayload` (34) |

`MTLBinding` declares `name`, `type`, `access`, `index`, `used` (`isUsed`) and `argument`
(`isArgument`); the four derive from it and add only their own memory numbers. The base carries ONE
implementation of those six and the four **inherit** it; only `-type` is overridden per class,
because only the kind differs. (They used to re-synthesize all five as well, which under ARC gave
each its own shadowing ivars — five implementations where the header declares one.)

**An earlier revision of these facts was wrong about the payload's kind.** It said the header gives
an object payload no kind of its own and that a payload rides in the buffer. The header does the
opposite: `MTLBindingTypeObjectPayload = 34` (`MTLArgument.h:179` in 16.4, `:76` in 26.2),
documented "This binding represents an object payload." The object, the case, the table and the
registry all carried that wrong claim; all four now say 34, and `M4` is red on an object answering
the buffer kind.

## The numbers are the header's, not chosen here

`MTLArgument.h:169-171` gives `MTLBindingTypeBuffer = 0`, `MTLBindingTypeThreadgroupMemory = 1`,
`MTLBindingTypeTexture = 2`, and `:218-220` gives `MTLArgumentAccessReadOnly = 0`,
`ReadWrite = 1`, `WriteOnly = 2`. The case compares the port's values against exactly these.

## Why 16.0, and what that word means

The 16.0 is the cache ladder's band for this family, and the ladder reports that **no release is held between
12.0 and 16.0**, so 16.0 means **"after 12.0, and by 16.0" — a band, not a measured first
release**. The object's name carries 16 because the family is the 16.0 API. The rows say 16.0
because that is the band the ladder chose.

## What the case measures, and what it cannot

A host comparison **is possible in principle and impossible here**, and the case says so rather
than substituting a round trip of the port's object against itself, which would prove only that
the port agrees with the port. A host `MTLDevice` has no
`newArgumentEncoderWithBufferIndex:error:` — the whole family is behind an argument buffer — so
there is no host binding to compare against. What is measured instead is the header-fixed
constants above, plus each class's own values.

Each row is proved by a mutant that breaks **only that class** and goes red on **that class's own
assertion** and on no other. The harness is committed, in-tree, and is the only way these numbers are
produced:

```
sh tests/backports/host/metal-census/argbinding.sh
```

| mutant | breaks | red line |
| --- | --- | --- |
| `M0` | the base's `-type` | `MTLBinding: the base answers the kind it was built as` |
| `M1` | `CharonMetalBufferBinding`'s `-type` | `MTLBufferBinding: its type is MTLBindingTypeBuffer` |
| `M2` | `CharonMetalTextureBinding`'s `-type` | `MTLTextureBinding: its type is MTLBindingTypeTexture` |
| `M3` | `CharonMetalThreadgroupBinding`'s `-type` | `MTLThreadgroupBinding: its type is MTLBindingTypeThreadgroupMemory` |
| `M4` | `CharonMetalObjectPayloadBinding`'s `-type` | `MTLObjectPayloadBinding: its type is MTLBindingTypeObjectPayload (34)` |
| `M5` | the shared `used` write | `MTLBinding: it reads back its name, index, access and both flags` |

Three things in the harness exist because they failed here once:

- **A mutation that does not build is `RUN FAILED`, never red.** It reported a green run: a mutation
  compiled with a wrong `-I` depth left the previous binary in place, so the case ran against an
  object that no longer existed. Every build removes its outputs first, and the broken mutation is a
  permanent control in the script.
- **A mutation is scoped to its class, not matched by text.** The five `-type` getters answer three
  different constants, so a plain text replace hits whichever comes first — an early revision
  "mutated" the base and reported green.
- **The port's classes must be defined in the binary** (`prove_defined`, `SELF_TEST=1` for both
  halves), or the case measures Apple's Metal, which is on the host too.

Two rows were uncovered when this was first written and the case had to be corrected rather than the
mutants explained away. All four subclasses **override** `-type`, so before the base was asked
directly a break in the base's own `-type` reached nothing and no mutant there could go red. And
nothing asserted that the payload had a kind, so `M4` stayed green — and when it was finally asked,
the answer it found was **wrong**: 34, not the buffer.

## What is measured, and what is not

Measured, each by its own mutant in `argbinding.sh`: the kind (`-type`) of all five rows, and the
base's `name`, `index`, `access`, `used` and `argument` — the last two through the one shared
implementation, so `M5` breaks the shared write and the base's own flag assertion names it.

**Not measured, by name:** `bufferAlignment`, `bufferDataSize`, `bufferDataType`,
`bufferStructType`, `bufferPointerType`, `textureType`, `textureDataType`, `isDepthTexture`,
`arrayLength`, `threadgroupMemoryAlignment`, `threadgroupMemoryDataSize`,
`objectPayloadAlignment` and `objectPayloadDataSize`. The header declares them `readonly` and fixes
no value for any of them, so there is no oracle to compare against, and a round trip of the port's
own object against itself would prove only that the port agrees with the port. They are carried, and
the case and the registry's effects say so rather than leaving it to be guessed.

## `MTLArgumentEncoder`: still owed, and what the port answers

The encoder is the other half and is **not** in this object. `MTLArgumentEncoder` is a *protocol*
(`MTLDevice.h:32-354`), and the port vends no class for it. What the port answers, measured
(`tests/backports/host/metal-census/argencoder.m`, a binary linking the binding object and
nothing else from Metal):

- `NSClassFromString(@"MTLArgumentEncoder")` → **nil**. No class, so no object and **no members to
  call** — the same answer a device with no argument buffers gives.
- The port's whole class set in that binary is **exactly its five bindings**, so the nil is the
  port not vending an encoder, not a runtime that cannot be asked.
- `NSProtocolFromString(@"MTLArgumentEncoder")` → **non-nil**, and this does **not** measure the
  port: a binary linking only Foundation already has Apple's protocol names registered
  (`MTLArgumentEncoder` FOUND with 2 conforming classes, `MTLBinding` FOUND with 6, 1277
  protocols in the process). It measures the host's own Metal metadata.

**This overturned a claim in the registry.** The `MTLArgumentEncoder` row's effect read "the
protocol is not there: `NSProtocolFromString` answers nil". That is false on a host and was
replaced with the measurement above. The protocol name resolving is not evidence that the port
vends the protocol; the class query and the port's own class set are what answer for the port.

### The factory is vendored, and it answers nil

The two factories are `-[MTLFunction newArgumentEncoderWithBufferIndex:error:]` and its
reflection-taking twin (`MTLLibrary.h:156-169`), and the port **implements both** at
`Metal/CharonMetalLibrary.m:113` and `:118`, each a `return nil`. That is deliberate and is
recorded in the source: a missing method *raises* on call, while a method that answers nil is a
call that *returns*, so a caller that probes gets a value instead of a crash.

This is a **source fact, not a measurement**, and the case says so rather than implying
otherwise: `CharonMetalFunction` is implemented in the same object as the library, which
references `CharonMetalDevice`, and that object needs EAGL context headers this host case does not
carry — so the call could not be made here without adding a fake to link against, and a fake was
not added.

**Plan, still owed:** the encoder needs an argument-buffer facility first — a buffer of argument
buffers on the device — and only then an encoder that binds a resource at an index into one,
replacing the nil the factories return today. The bindings above are the description such an
encoder would read, which is why they were worth carrying first.
