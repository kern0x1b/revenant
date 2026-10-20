# VideoToolbox's 135 string constants, and the release each arrived in

The VideoToolboxConstants<release>.m files define 135 string constants. Until the 6.1.3 gate stopped on this
family none of them had a registry row, and the gate says what that sounds like: "neither
the SDK, the registry nor a held release's own cache says which iOS release <name> arrived
in, and a VideoToolboxConstants file defines it".

The release each one is placed at is the SDK's OWN, read from its declaration: the
availability on the declaration's line where it is there, the line below where a // comment
sits between the name and its availability, and the lines above for the shapes that put it
there. Nothing is assigned from a neighbour, and nothing is left unsaid.

## Releases the 135 arrived in

- **8.0** — 5 constants
- **9.0** — 4 constants
- **11.0** — 8 constants
- **11.3** — 2 constants
- **12.0** — 2 constants
- **13.0** — 15 constants
- **14.0** — 7 constants
- **14.5** — 2 constants
- **15.0** — 11 constants
- **15.4** — 2 constants
- **16.0** — 12 constants
- **17.0** — 10 constants
- **17.4** — 5 constants
- **18.0** — 5 constants
- **26.0** — 45 constants

## The decisions, one per constant the SDK leaves open

- `kVTCompressionPropertyKey_PreserveDynamicHDRMetadata` — placed at **14.0**, because its availability is on the line BELOW the declaration, after a // comment, and that line states ios(14.0) - VTCompressionProperties.h:1183-1184.
  The SDK states the version itself, on a continuation line after a comment;
  this is a reading of where the SDK put it, not a judgement about the release.

## What this does not cover

A constant of an early release that 6.1.3 EXPORTS NATIVELY is not the port's to define, and
this file does not decide that: it is the cache that says, and that measurement is still owed.
The objects are split per release (VideoToolboxConstants<major>_<minor>.m), each holding the
constants its registry rows place at that release; check-constant-files.py holds that both ways,
with a control that a constant moved into another release's file is caught by name.
