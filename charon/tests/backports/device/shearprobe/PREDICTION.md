# What the 6.1.3 guest run of the port's shear engine is predicted to answer

Written before the run, in the same commit as the probe, and not edited after it. Every number below is a
prediction; the run's own output is what settles them, and where the two differ the run's answer is the one
that goes in the report and the port.

The question: **the port's integer shear engine against the release's own `ARGB8888` shear, over one filter
the release made, on iPhone3,1 6.1.3 10B329.** Every term of the mapping this port implements has so far been
measured on macOS's vImage. Only a scale of one has ever been run against the 6.1.3 guest (v-tail-a11,
v-tail-a12). This is the run at the scales the rows are written for.

## What is compared, and why not the bytes

The release on 6.1.3 exports `vImageVerticalShear_ARGB8888` and `vImageHorizontalShear_ARGB8888` and no
16-bit shear at all - the sixteen-bit forms arrive at 7.0 - so the two engines cannot be handed the same
pixel type and their output bytes are not comparable: the release stores `round(sum/divisor)` in the input's
own 0..255 units and the port stores `round(sum/rowsum * 65535)` in 0..65535, so the same convolution is two
different stored numbers with no exact relation between them.

**What IS comparable is which `(phase, base)` pair each destination sample reads.** That is the whole of the
mapping, it is shape-independent, and it can be read off each engine's own bytes without any model of either:

* a source whose channel 0 carries `MAX` at exactly one position along the shear and `0` everywhere else,
  with a zero backColor, makes destination sample `y` answer `store(row[p][j] * MAX / divisor)` where `j` is
  that source position's offset in the row the engine chose - every other tap reads zero or reads the zero
  backColor. One tap, so the answer is that one weight and nothing else;
* running that for every source position gives, for each `y`, the row's own weight profile shifted to where
  the engine put it;
* every `(phase, base)` whose profile reproduces all of the observed answers is a candidate, and the number of
  candidates is part of the answer, not something to be hidden by picking one.

Both engines are treated by the same instrument, and the instrument's model is the one v-tail-a12 measured on
this very device: the release's own Q14 integers summed over the row it uses, divided by the divisor, rounded
half up into the stored type. It scored 768 of 768 at a scale of one, 1344 of 1344 at two and 480 of 480 at a
half there, so it is a measured model of this release, not an assumed one.

The port's own pair is also computed a third way, by the port's own `CharonResamplePhase` fed the mapping
`CharonShearRun` implements, and printed beside the pair recovered from the port's bytes. If those two ever
disagree the instrument is wrong and the run says so on its own face.

## The predictions

**P1 - nothing is refused.** `CharonResampleFilterOf` returns 1 for the release's filter at all five scales
(v-tail-a13 measured the 6.1.3 armv7 header shape on this device, nine of nine), `CharonShearReady` returns
`kvImageNoError` at every case, and both engines return `kvImageNoError` at every case. Confidence: high.

**P2 - the control, a scale of one.** At a scale of one, translate 0, slope 0, on both axes, the release's
own bytes fit `(phase 0, base = the destination's own coordinate)` at EVERY destination sample and the port's
bytes fit the same pair. That is v-tail-a11's measured identity on this device, and this run re-establishes it
through the identification rather than by reading the output: the instrument is useless if it cannot find it.
Confidence: high.

**P3 - the three exact scales agree.** At scales 2, 0.5 and 0.25 the release's and the port's pairs are EQUAL
at every destination sample, on both axes, at all seven translates of the sweep. Those three reciprocals are
exact, so every algebraic rearrangement of the mapping is the same double and nothing can separate; both sides
run the same expression. Confidence: high. **If this fails, something is wrong with the instrument or the
filter, not with the release.**

**P4 - 0.75 on the vertical, and I do not predict which way.** At 0.75 on the vertical, either the release's
pairs equal the port's at every destination sample, or they differ at some. What I do predict is the SHAPE of
any difference: **every destination sample whose mapped centre is not exactly on a phase boundary agrees**, and
every one that differs has `frac(centre) * 64` an exact integer. 0.75 stores `1.3333333333333333`, the only
inexact reciprocal of the five, and v-tail-a14 measured on macOS that the vertical's remaining 524 failures are
all of that shape - at a centre of 2.5 against 2.4999999999999996, one ulp of the anchor decides between two
adjacent phases. Confidence in the shape: high. Confidence in the direction: **none**, and I will not pretend
otherwise. Either the release truncates at 0.75 as macOS's does and the 524 are a macOS-only artefact, or the
release rounds and truncating is macOS's own later rule. Per the brief the RELEASE wins for the port's
arithmetic either way.

**P5 - the tie at 1/128.** At the off-grid translate 1/128, the horizontal's tie still goes UP and the
vertical's still goes DOWN. v-tail-a14 measured that on macOS over eighty cells and both axes, and the two
rules are two different functions' inner loops on one release; 6.1.3 is an older and much narrower
implementation and may round both the same way. Confidence: medium. A vertical that ties upward is the
release's answer and it replaces the truncation.

**P6 - the divisor is still not separable.** Dividing by the row's own sum and by 16384 both give the same
identified pairs at every destination sample of every case. The rows are within 5 of 16384 on
this release, which is the whole of why. Confidence: medium-high; v-tail-a12 could not separate them either,
and this run carries the question explicitly by identifying under both divisors and reporting the two.

**P7 - ambiguity is reported, never resolved.** Some destination samples cannot be pinned to one pair, because
a negative lobe stores as 0 in eight bits and a weight of zero stores as 0 too. Those lines say `ambig` with
the number of candidates; no line ever picks one of several.

**P8 - the slope is not in this run.** Slope 0 throughout. The slope's cross coordinate is a separate term of
the mapping, it is not what this brief asks about, and leaving it out keeps the 0.75 boundary set readable.
Saying so is part of the prediction: a reader must not take the run's agreement as covering the slope.

## What would make the run untrustworthy, and is checked

* **A stale image.** The gate compares the built binary's `LC_UUID` against the installed copy in **this
  project's own image**, named by asking xmake for `project.name() .. "-" .. hash.strhash32(os.projectdir())`
  and never by a glob. `xmake emulate install` has been observed printing "install ok!" and leaving the
  image's copy alone.
* **A child's output lost.** On this guest a forked child's writes to standard output do not reach the
  runner's capture (v-crutch6 measured it: twelve children each printed one line, not one line arrived). Each
  case is a forked child that answers through a pipe, and the parent - whose own output does arrive - prints
  it. A child that dies is reported with `WTERMSIG`, never with `WEXITSTATUS` alone.
* **The instrument silently wrong.** The same source file is compiled for the host and run against macOS's
  vImage first, where the answer is already known: the port and macOS agree everywhere except 0.75 on the
  vertical, and they differ only at exact phase boundaries (v-tail-a14's 524 of 616). An instrument that does
  not reproduce THAT on the host does not go to the guest.
---

# The prediction for the Q32 engine (v-tail-a17), written before this run

**P1 to P8 above were written for the PREVIOUS engine, the one whose mapping was a `double` centre with a
half pixel and a per-axis tie rule. They are superseded, and they are left standing rather than edited: what
they predicted and what the run answered is the record of how the mapping was got wrong. This section is the
prediction for the engine that replaced it, and it is written from the reading of the release's instructions
alone (facts/Accelerate/vImageGeometry.md, "The release's own position arithmetic" and "The two open terms
closed") plus the 1210-pair score that reading makes against a15's own guest log - not from the port's code
and not from anything this run will print.**

The port now carries the release's own arithmetic: a Q32 fixed-point accumulator, `A0 = (int64)(start * 2^32)`
truncating, advanced by `(int64)(recip * 2^32)` per destination sample, with
`phase = ((A & 0xffffffff) >> (32 - exponent)) & (phases - 1)` and the centre tap at `(A >> 32) + K0`.

**P9 - every scale, both axes, every translate: the release's and the port's pairs are EQUAL at every
destination sample either engine names.** Not "off a scale of one", not "except a boundary": everywhere. The
reading scores 1210 of 1210 named samples over exactly these seventy cases on a15's log, and the port now
computes that reading, so the prediction is that the count of `differ` is zero in all seventy summaries.
Confidence: high. **If this fails, the engine is not the reading** - the port's own bytes and the port's own
function are printed side by side, so the run says which of the two moved.

**P10 - the 0.75 vertical reads `21 42 63 21 42 63`, and its first four destination samples are BLANK.** The
phase sequence is `S mod 2^32 = 0x55555555`, a third of a pixel short of a third, read a third short at every
sample. `along 0..3` are out of the picture at that shape and no pair can be recovered there, which is why the
earlier reading of this run could not see the one sample where a truncating and a flooring conversion differ
- `along 2`, whose truncated fraction is exactly zero. Confidence: high.

**P11 - the horizontal at 0.75 names phase 0 where a flooring conversion would name 63.** Five named samples
in a15's log - `along 1` at translate 1, `along 2` at -1, `along 2` at 0.5, `along 1` at -0.5 and `along 2` at
1/128 - are where the release's own bytes name phase 0 (and 42 at 1/128) and a floor names 63 (and 41). Those
five are the run's own check on the conversion, on the axis where the knife edge falls inside the picture.
Confidence: high, and it is the one prediction here that a wrong engine fails LOUDLY rather than quietly.

**P12 - the scale of one is still an exact identity**, `(phase 0, base = the destination's coordinate)`, on both
axes: at a scale of one the reciprocal is exactly 1, so the step is exactly `2^32`, the accumulator's fraction
is 0 at every sample and the base advances by exactly one. Confidence: high.

**P13 - the divisor is still not separable on this release**, as P6 said: the rows are within 5 of 16384 and
the two divisors name the same pairs. The run carries it by identifying under both and reporting the count.
Confidence: medium-high.

**P14 - the twenty-four arrangements still score zero against the release**, and now for a reason the run can
show: none of them has an accumulator in it, so none of them can produce the `21 42 63` cycle. The port's own
arm is the Q32 model now, and the table is kept because "the release is not in this family" is a claim a
reader will want to see scored rather than told.

**P15 - the slope is still not in this run** (P8). What the run covers is the translate and the scale on both
axes, and the slope's cross term is read from the instructions and measured by nothing yet.
