# accessibilitymap - what this case covers, and what it owes

`run.sh` is a two-sided differential: the system's `AXBrailleMap` and the port's, compiled into one
program under two names, compared line by line. It is 52 questions, 51 of which answer the same and one
of which is a declared difference with both answers and a reason in `expected-differences.tsv`. The
number is printed by the run itself, so it is read rather than kept.

Two checks run beside it, each in its own program and each for a reason this file records rather than a
comment:

* `factory-probe.sh` asks how a **sized** map behaves. The header marks `-init` and `+new` unavailable
  and gives no other way to make one, so the system cannot be asked and the port's
  `+charon_mapWithDimensions:` is the only map with a size a caller chose. Seven checks.
* `protocol-check.sh` asks whether a caller can **find every protocol the registry claims**, by the name
  the registry gives it. The names come out of `registry/Accessibility`'s `kind: protocol` /
  `status: implemented` rows and the sources out of `modules/apple/backports.lua`'s own
  `protocol_sources()`; a name the registry does not hold answers nil and is the control.

## Owed

**The three protocol-name cases are not in the two-sided comparison, and the alias is why.** The
differential keeps its two halves from colliding by compiling the port half with
`-DAXBrailleMapRenderer=CharonPortAXBrailleMapRenderer`, and that alias renames the **protocol** as well
as the class. So in the port half the protocol is `CharonPortAXBrailleMapRenderer` and in the host half
`AXBrailleMapRenderer` belongs to the framework: two different names answer one question, and a lookup by
name cannot be compared across them. Measured both ways: `objc_getProtocol("AXBrailleMapRenderer")` in a
binary linking the port's own objects answers found, and the same call in the port half of the
differential answers nil for the real name.

What would settle it, and has not been done:

1. **Ask the port half for both names.** It answers `found` for the alias and `nil` for the real one, so
   a case could print both and compare only the alias against the host's real name - but that compares
   two different protocols, which is worse than not comparing, and it is not what this file wants.
2. **Drop the alias for the protocol lookup only**, by giving the port half the SDK's protocol
   declaration under the real name in a second translation unit. This is probably right and has not been
   tried; the risk is that the port half then links two protocols of one name and the check passes for
   the wrong reason.
3. **Record the host's answers and compare a port-only program against the record**, the arrangement
   `factory-probe.sh` already uses for a sized map. It is a weaker check - the expectation is a table in
   a file rather than a live answer - and it is what `protocol-check.sh` is today, except that its
   expectations are the checks it asserts rather than the host's numbers copied across.

Option 2 is the one to try first and the one this case owes. Until one of them is done, the protocol's
resolution is checked by a port-only program with a control, and not by a comparison with the system.
