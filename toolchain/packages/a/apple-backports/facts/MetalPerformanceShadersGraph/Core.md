# The graph framework on this port: the builder side and the arithmetic family

`MPSGraphObject`, `MPSGraphType`, `MPSGraphShapedType`, `MPSGraphDevice`, `MPSGraphTensor`,
`MPSGraphOperation`, `MPSGraphTensorData`, `MPSGraph`, `MPSGraphExecutable`,
`MPSGraphExecutionDescriptor` and `MPSGraphExecutableExecutionDescriptor`, and the arithmetic family of
`MPSGraph`'s factory methods.

Source: the headers of `MetalPerformanceShadersGraph` in the SDK of iOS 16.4, which is the SDK this
package compiles against, for every signature; the 26.2 headers under
`toolchain/.agent-work/sdk-26.2/` for what 16.4 does not declare. The behaviour is measured against the
system's own MPSGraph by `tests/backports/host/mpsgraph/run.sh`.

## The model, and why it is a walk rather than a compiler

A graph is a description of work, and a tensor is a description of a result. Running a graph therefore
means walking the operations **in the order they were added** and asking each to fill its outputs from
its inputs and from the feeds: an operation can only read what an earlier one wrote, and the order they
were added is the order that guarantees it. A tensor's value is found by looking it up - a placeholder's
comes from the feeds, any other one's from the operation that produced it.

`MPSGraphExecutable` is then the graph itself. The release compiles a graph into device code and holds
the results on the device; this port holds them in the host memory behind an `MTLBuffer`, so there is
nothing to compile ahead of time and the executable is the graph plus the targets the compile named.
That is not a shortcut around the graph, it is the same graph with the storage the device already has.

## Where the arithmetic happens, and in what precision

Over the host memory behind an `MTLBuffer`, on the CPU, exactly as the matrix kernels in
`../MetalPerformanceShaders` do (`facts/MetalPerformanceShaders/Matrix.md`). The data type of the
operands decides the arithmetic, as it does there, through the same `RevenantMPSStore` and `RevenantMPSLoad`:
`RevenantMPSGraph.h` **includes** `RevenantMPS.h` rather than restating it, so an `MPSDataType` means one
thing in both families rather than two.

A result tensor's storage is a buffer of its own, made when the operation runs, so a run never writes
into a buffer the caller fed it.

## Four names the build's SDK does not declare

The iPhoneOS 16.4 SDK predates four names of the 26.2 surface:

* **`MPSGraphObject`** arrived in iOS 17, and every class of that surface descends from it there,
  while 16.4 has them descending from `NSObject`. It is declared in `RevenantMPSGraph.h` and implemented
  here, so a graph's objects have the root the 26.2 headers give them.
* `MPSGraphFFTDescriptor`, `MPSGraphImToColOpDescriptor` and
  `MPSGraphExecutableSerializationDescriptor` are in the 26.2 surface and not in the 16.4 headers.

The declarations are guarded on a host SDK that already has them - where redeclaring would be a
duplicate, and where the host's own classes are what a comparison must be against.

**Four registered names that no header the build compiles against declares** is a rule R4 item.

## The measuring, and where it stands

`tests/backports/host/mpsgraph/` compiles the same cases twice - once against the system's own
MPSGraph, once against these classes with the MPSGraph names mapped to `revenant` names and their
selectors prefixed - and compares the bytes of a buffer the case owns.

**Both execution routes work on this host**, measured directly:

* compiling with a shaped-type feed and running through
  `-[MPSGraphExecutable runWithMTLCommandQueue:inputsArray:resultsArray:executionDescriptor:]` over a
  result buffer the caller owns answers `[11 22 33 44]` for two 2x2 placeholders and one addition. This
  is the route the differential uses, because it is the only one where the answer lands somewhere the
  case can read: `MPSGraphTensorData` has no accessor for its bytes in either the 16.4 or the 26.2 SDK.
* `-[MPSGraph runWithFeeds:targetTensors:targetOperations:]` answers too, and is one call.

**What the differential found, in order.** All of these were bugs, and the first two were mine in the
harness rather than in the library:

* **A `memmove` on a null destination.** The interpreter made a result's storage from an empty `NSData`,
  which is a zero-length buffer whose `contents` is null. A result now takes a buffer of the shape's
  own size, made and zeroed when the tensor data is made.
* **The inputs paired with the feed tensors in the wrong order.** `-[MPSGraphExecutable
  runWithMTLCommandQueue:...]` took the feed tensors from the dictionary's key order, which is
  arbitrary, so the second operand reached the first tensor and every non-commutative operation read
 its arguments backwards: subtraction answered `9, 18, 27...` where the release answers `-9, -18,
 -27...`. The pairings are now in the graph's placeholder order, which is the order the caller passed
  the inputs in.
* **The harness overwrote its own inputs.** It remembered each *feed's* buffer as well as the result's,
  and read every remembered buffer back into the array it came from, so after the first case each input
  array held the previous case's output and both sides agreed on the wrong numbers. Only the result
  buffer is read back now.
* **A square root of a negative, three times.** I read the chain case - where the product is positive even
 where the sum is not, so no negative ever reaches the root - as the release's root answering a
  magnitude, and changed it to `fabs`. Measured over a feed of `(1, 2, 3, 4, -1, -2, -3, -4)`, the
  release answers `1, 1.41421, 1.73205, 2` and then four NaNs. It is a NaN, it is one again, and
  `MPSGraphOperationKindSqrt` now takes `sqrt(a)`: over the sixteen classes below the whole row is
  byte-identical to the release's, element for element.
* **A branch that decided a division, a reciprocal, a square root and a logarithm by itself.** Each of the
 four had a case for the values the arithmetic is undefined at - `b == 0.0`, `a == 0.0`, `a < 0.0`,
 `a <= 0.0` - and each of the first two chose its infinity from the sign of the dividend alone, so it had
  one answer where the arithmetic has two: `-1 / -0.0` is `+inf` and the division branch had only `-inf`
  for it, and a reciprocal of `-0.0` is `-inf` where the reciprocal branch had only `+inf`. The measured
  columns `reciprocal` and `divide` carry both zeroes, `ff800000` and `7f800000`, which is what the case
  file feeds now. IEEE division answers every one of them, so the four cases are the arithmetic itself.
* **A denormal, and a NaN of its own.** `RevenantMPSGraphAsZero` and `RevenantMPSGraphOwnNaN` are what a result
  leaves the release's arithmetic as, and they are in `RevenantMPSGraphApply` rather than in the store,
  because `RevenantMPSStore` is shared with the matrix and image families and because two kinds keep both: the
  measured table below has `abs` and `identity` returning `0x00000001` and `0x7f800001` unchanged.

**Where it stands, measured on macOS 27.0 build 26A428 (M4 Pro, Metal 4):
`tests/backports/host/mpsgraph/run.sh` ends `port: same as the system, case for case and bit for bit` and
`checks=15 failures=0` over `compared: 15 cases`.** Every case is byte-identical to the release's, and the
case file feeds all sixteen classes of the table below to each of them rather than the eight values that
first showed a difference. The planted build beside it is the control: `red control: the planted build
differs from the release in 13 of 15 cases`, which is every line of the run that is a case - the other two
are the graph device's type and a shaped type's data type, neither of which is a stored element.

What the release answers for each class, float32, one row per input and one column per unary operation.
Every cell is the four bytes it wrote:

| input | bits | sqrt | rsqrt | square | reciprocal | log | abs | sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| +1 | `3f800000` | `3f800000` | `3f800000` | `3f800000` | `3f800000` | `00000000` | `3f800000` | `3f800000` |
| -1 | `bf800000` | `7fc00000` | `7fc00000` | `3f800000` | `bf800000` | `7fc00000` | `3f800000` | `bf800000` |
| -0.0 | `80000000` | `80000000` | `ff800000` | `00000000` | `ff800000` | `ff800000` | `00000000` | `00000000` |
| 0.0 | `00000000` | `00000000` | `7f800000` | `00000000` | `7f800000` | `ff800000` | `00000000` | `00000000` |
| +inf | `7f800000` | `7f800000` | `00000000` | `7f800000` | `00000000` | `7f800000` | `7f800000` | `3f800000` |
| -inf | `ff800000` | `7fc00000` | `7fc00000` | `7f800000` | `80000000` | `7fc00000` | `7f800000` | `bf800000` |
| qNaN | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `00000000` |
| -qNaN | `ffc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `00000000` |
| denormal 0x00000001 | `00000001` | `00000000` | `7f800000` | `00000000` | `7f800000` | `ff800000` | `00000001` | `00000000` |
| denormal 0x007fffff | `007fffff` | `00000000` | `7f800000` | `00000000` | `7f800000` | `ff800000` | `007fffff` | `00000000` |
| -denormal 0x80000001 | `80000001` | `80000000` | `ff800000` | `00000000` | `ff800000` | `ff800000` | `00000001` | `00000000` |
| smallest normal 0x00800000 | `00800000` | `20000000` | `5f000000` | `00000000` | `7e800000` | `c2aeac50` | `00800000` | `3f800000` |
| 0x00ffffff | `00ffffff` | `203504f3` | `5eb504f4` | `00000000` | `7e000001` | `c2ad496b` | `00ffffff` | `3f800000` |
| 1e-20 | `0e8d1e59` | `27066639` | `57f3cf8f` | `00000000` | `706833b2` | `c287a965` | `0e8d1e59` | `3f800000` |
| 0x3f7fffff | `3f7fffff` | `3f7fffff` | `3f800000` | `3f7ffffe` | `3f800001` | `b3800000` | `3f7fffff` | `3f800000` |
| qNaN payload 0x7f800001 | `7f800001` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7fc00000` | `7f800001` | `00000000` |

Four things in it are worth naming, because each one is a rule rather than a value:

* **A denormal is read as a zero of the same sign and never answered.** `sqrt` of `0x00000001` is
  `00000000` and of `0x80000001` is `80000000`; `sign` of `0x00000001` is `00000000`; `reciprocal` of
  `0x00000001` is `7f800000`. The result is flushed as well as the operand, which is a different rule and
  shows in one row: `square` of `0x00800000` is `00000000`, because the square of the smallest normal is a
  denormal, while `square` of `0x3f7fffff` is `3f7ffffe`, which is neither.
* **A NaN a kind computes is the arithmetic's own.** Every computing column answers `7fc00000` for
 `ffc00000` and for the payload-carrying `7f800001` - the sign and the payload are both gone - and the
  two copying columns are the two that keep them: `abs` of `7f800001` is `7f800001`, and `identity` of
  `7f800001` is `7f800001` too.
* **A negative zero is a negative zero.** `sqrt` of `80000000` is `80000000`, where a `fabs` before the
  root could not have answered it.
* **`log` of a zero is `-inf` and `sign` of a NaN is `0`.** Both are in the table and neither needs a case
  of its own, which is the point of taking them out.

**A half is a different arithmetic on this host, and the port now carries the half of it that is a
rule.** The case file feeds the same sixteen classes in `MPSDataTypeFloat16` as in float32, and the run
compares the two families side by side: `tests/backports/host/mpsgraph/run.sh` reports
`port: same as the system on 17 of the 24 cases with a result buffer; 7 float16 cases differ in 22 of
their cells, recorded` and `checks=24 failures=0 recorded=7`. Every float32 case is byte-identical and
170 of the 192 half cells are.

What the release's half path answers where a float32 does not, and what `RevenantMPSGraphApply` now
answers the same way:

| | the release | measured on |
| --- | --- | --- |
| a zero result | `0000`, the sign gone | the identity of a half `-0.0` is `0000`, a square root of `-0.0` is `0000`, the reciprocal of `-inf` is `0000` |
| a NaN to the square, the absolute value | `7c00` | `7c00` for a NaN of either sign |
| a NaN to the identity, an addition, a subtraction | `7c00` or `fc00`, the NaN's own sign | `identity(0x7e00)` is `7c00` and `identity(0xfe00)` is `fc00`; `add(0x7c00, 0x7e00)` is `7c00` and `add(0xfc00, 0xfe00)` is `fc00` |
| a NaN to a reciprocal, a reverse square root, a logarithm | `0000` | `reciprocal(0x7e00)` is `0000`, `rsqrt(0x7e00)` is `0000`, `log(0x7e00)` is `0000` |
| a NaN to a square root | `7c00` for a positive one, `0000` for a negative one | the sign bit, read as a bit: a NaN compares false against everything |
| a NaN to the sign | `3c00` or `bc00` | the sign bit and not a comparison, so `sign(0xfe00)` is `bc00` |
| a negative argument to a square root, a reverse square root | `0000` | `sqrt(0xbc00)`, `sqrt(0x8001)` and `rsqrt(0xbc00)` are all `0000` |
| a zero to a reverse square root | `7c00` for either sign | `rsqrt(0x0000)` and `rsqrt(0x8000)` are both `7c00`, where the reciprocal of a negative zero is a negative infinity |
| a zero to a logarithm | `f98c`, which is `-45440` | `log(0x0000)` and `log(0x8000)` are both `f98c`, where IEEE answers `-inf` |
| anything else that is not a positive number, to a logarithm | `0000` | `log(0xbc00)`, `log(0x7c00)`, `log(0xfc00)` and `log(0xfe00)` are all `0000`, where IEEE answers a NaN, an infinity and two NaNs |
| a denormal | kept | `identity(0x0001)` is `0001` and `abs(0x8001)` is `0001`, where float32 answers `00000000` |

**A halfway half rounds away from zero here, and now does in the port's MPSGraph path.**
`RevenantMPSFloatToHalfRounded` in `../MetalPerformanceShaders/RevenantMPS.h` takes the rounding as an
argument, `RevenantMPSStoreRounded` passes it on to the narrowing, and the interpreter's two stores ask
for it; `RevenantMPSFloatToHalf` and `RevenantMPSStore` are the same functions with the even rounding and
every other family keeps calling those, so the matrix and image kernels do not move. Measured: an
addition of `2^-10` to 3.0 is exactly halfway between two halves and the release answers `4201`, and
a square root of `3c01` - `sqrt(1 + 2^-14 * 2)` - is exactly halfway and the release answers `3c01`,
where round-to-even gives `3c00`. **Four cells left the record when this was applied, not three**: it
also fixed a multiply of a half denormal by 0.5 and a division of one by -0.5, whose exact answers are
both halfway between two halves.

**The 18 cells that are still not the release's, and the rule attempted for each group.**
`tests/backports/host/mpsgraph/recorded-cells.txt` names each of them with the two sets of bytes, and the
comparison is per cell: a cell that is not on that list fails, and so does a cell on it whose bytes are
not the two written there, so neither a new divergence nor a stale record can pass.

**Seven are the release's own approximation**, within one unit in the last place of a half or near it:
`log(0x03ff)` and `log(0x0400)` are `c8db` where the correctly rounded half of the exact logarithm is
`c8da`, `log(0x1400)` is `c6ef` against `c6ee`, `log(0x3555)` is `bc66` against `bc65`, `rsqrt(0x3555)` is
`3eef` against `3eee`, and `sqrt(0x3c01)` is `3c01` against `3c00`. **Attempted and rejected**: that the
kernels keep their intermediate in a half, which is the shape the coordinator suggested. Three models
were measured against all sixteen cells of each kind - the operation narrowed once, `x` times a reverse
square root narrowed to a half, and a reverse square root of the narrowed reciprocal - and each explains
*fewer* cells than the single narrowing the port already does: 6, 7 and 7 of 16 against 8 for the square
root, 5 and 7 of 16 against 8 for the reverse square root. For the logarithm, three models - one
narrowing, a `log2` narrowed to a half and then multiplied by `ln2`, and a `log2` narrowed twice -
explain **0 of the 5** recorded cells. A half-precision intermediate is therefore not what is happening,
and what is left is the compiler's own approximation, whose coefficients are not derivable from the
specification. **Owed, not attempted further.**

**Eleven are the release's half binary arithmetic answering what no operation of the specification
produces**, and every one of them has an operand that is a zero, an infinity, a NaN or a denormal: a zero
times an infinity is `0000` where IEEE answers a NaN, an infinity times a NaN is `7c00` and a negative
infinity times a negative NaN is also `7c00` - the sign of the infinity gone - a positive NaN times a
denormal is `1e00` (`0.00585938`) and a negative NaN times 2.0 is `fc00`, a division of a NaN is `7c00`
and of a negative NaN is `fa00` (`-49152`), a division of `-1.0` by `-0.0` is `fc00` where IEEE answers
a positive infinity, and a subtraction of `+inf` and a NaN is `f800` (`-32768`) and of `-inf` and a NaN
is `7800` (`32768`). **Attempted and rejected**: the two suggestions, in the form each can be measured.
A half denormal read with the wrong exponent bias is ruled out by the ratios - the release's answers for
an operation with a denormal operand were 2x, 2x and 4x the exact value and `0.00585938`, and no single
exponent field gives a fixed ratio across them. A clamped or fast-math float path is ruled out by the
group's own answers: within one class of operand - one that is not a finite non-zero normal - the release
answers `0000`, `7c00`, `fc00`, `1e00` and `0000`, and no rule over the class produces five different
values. Five substitutions were measured against all eleven cells: IEEE itself explains 3, "a NaN operand
becomes the largest finite half" 1, "a NaN operand becomes an infinity" 2, "a zero operand makes the
product a zero" 5, and "computed in a float32 with denormals flushed" 2. Nothing explains a group.
**Owed, not attempted further**: a kernel that answers these is not a function of the operations the
specification names, and reproducing it bit for bit would be a table of its answers.

The buffer a half case needs is sixteen elements: `MPSNDArray` refuses a shorter one - "buffer is not
large enough. Must be 32 bytes", `MPSNDArray.mm:893` - so a half tensor in this harness cannot be
smaller than 32 bytes.

Two of the case file's cases are not counted as agreeing:

* **A constant** cannot be asked for at all on this host. `-[MPSGraph constantWithShape:dataType:values:name:]`
  aborts the process, so it is asked for **last**, after everything the host does answer, and the run
  stops there on the host side. An earlier version of the case file had it in the middle of the unary
  family, where it took seven cases down with it - and because the harness compared the shorter of the
  two runs, those seven counted as agreeing.
* **A placeholder's `dataType`** is the other one that is not comparable, for the reason below.

The harness now **fails on a length mismatch** rather than truncating to the shorter side, and names the
case each side last reached, so an abort in either run cannot be read as agreement.

One thing the harness did teach, and which is written into the case file: **reading a shaped type's
equality, or a placeholder's `dataType`, takes the release down** - it calls
`-[MPSGraphTensor tensorDataType]`, a selector its own `MPSGraphTensor` does not declare. So those
answers are not comparable on this host and the case file does not ask for them.

## The elementary family of 14.0, and what the release's own kernels do

Fifty-three methods of the 14.0 arithmetic, rounding, comparison, logical and activation surface are
written, in `MPSGraph14.m` and in the interpreter beside it: the transcendentals, the two roundings, the
six comparisons and the six logicals, the three questions about a value, the two remainders, a minimum, a
maximum, a division that answers no NaN, the select, the clamp, a ReLU and a sigmoid with their gradients.
Every one of them is asked over the case file's sixteen input classes in `MPSDataTypeFloat32` and in
`MPSDataTypeFloat16`, and **36 of the 53 come back with every cell of every case agreeing with the release in both
types** - the row of each is in the registry, and the run's verdict line is
`port: same as the system on 3609 of the 3808 cells with a result buffer; 3410 within the release's own
precision, 199 recorded` with `checks=128 failures=0`.

**A predicate's result is a boolean and the logical family's is not.** Measured on this host's own
MPSGraph over a rank-3 float32 operand: `isNaN`, `isFinite`, `isInfinite`, `equal`, `notEqual`,
`lessThan`, `lessThanOrEqualTo`, `greaterThan` and `greaterThanOrEqualTo` answer `MPSDataTypeBool`, which
is `MPSDataTypeAlternateEncodingBit | 8` (MPSCoreTypes.h:260) and **one byte** an element
(`MPSSizeofMPSDataType(MPSDataTypeBool)` is 1, measured), while `logicalAND`, `logicalOR`, `logicalNAND`,
`logicalNOR`, `logicalXOR`, `logicalXNOR`, `not` and `signbit` answer the operand's own type. The port
therefore has two builders - `revenant_mps_arithmetic:operands:name:` and
`revenant_mps_predicate:operands:name:` - and `RevenantMPSLoad` and `RevenantMPSStoreRounded` in
`../MetalPerformanceShaders/RevenantMPS.h` carry the one-byte type.

**A minimum and a maximum are `fmin` and `fmax`, not an operator.** Measured: a minimum of `+inf` and a
NaN is `0x7f800000`, of `-inf` and a NaN is `0xff800000` and of a NaN and `0x00000001` is `0x00000001`,
where a comparison would answer a NaN for each.

**Sixteen kinds read an operand as it is stored and do not see a denormal as a zero**, and the other kinds
do: `absolute`, `identity`, `signbit`, `negation`, `round`, both remainders, `minimum`, `maximum`,
`select`, `clamp`, and the five `sin`, `sinh`, `arcsin`, `asinh` and `atanh` - for those five the
release's own answer for a tiny argument is the argument, so `sin`, `sinh`, `arcsin`, `asinh` and `atanh`
of `0x00000001` are each `0x00000001` and of `0x80000001` are each `0x80000001`. Measured for the rest:
the negation of `0x00000001` is `0x80000001`, a modulo of `0x00000001` by `-2.0` is `0x00000001`, a
minimum of `0x00000001` and `0x7e00` is `0x00000001`, and a select whose predicate is a NaN takes the
branch it takes for any other non-zero. Three are **not** among them and are left out for that reason:
`arctangent`, the hyperbolic tangent and `erf` each answer `0x00000000` for `0x00000001` and
`0x80000001` for `0x80000001`, and a ReLU answers `0x00000000` for a denormal.

**A zero is a positive zero for `arctangent` and for the hyperbolic tangent, and for those two only.**
Measured: the arctangent and the hyperbolic tangent of `-0.0` are `0x00000000` where IEEE answers
`-0.0`, and the hyperbolic tangent of a negative denormal is `0x00000000` as well. The identity, a
reciprocal, a square root, a remainder, a minimum and a maximum all answer `-0.0` for a negative zero on
this host, measured, and are left alone - applying the rule to the whole family was tried and cost ten
cells that were right (`recorded-cells.txt` went from 196 to 208 and `identity`, `reciprocal`, `rint`,
`sqrt`, `divide`, `minimum`, `maximum`, `modulo`, `negative`, `select` and `round` each lost a float32
cell).

**A kind that keeps the NaN it was given keeps it only when it WAS given one.** Measured: the arcsine of a
NaN is that NaN, `0xffc00000` for a negative one, and the arcsine of `-inf` is `0x7fc00000` and not a NaN
of a negative sign.

**Seven kinds answer the NaN they were given and the rest answer the arithmetic's own.** The negation of
`0x7fc00000` is `0xffc00000`, which is what a sign-bit flip answers; `round`, `arcsin`, `arctangent`, the
hyperbolic arc-sine, the hyperbolic arc-tangent and `select` each keep the sign too, and `identity` copies
the NaN's bits outright. Every other kind that computes answers `0x7fc00000` for either sign.

**A round that lands on zero is a positive zero** (measured for `-0.0`, `-0x1p-126` and `-0x1p-20`, each
`0x00000000`, where C's `round(-0.0)` is `-0.0`).

**A sigmoid's gradient reads the source as the value that was activated, not as its answer.** Measured:
a `sigmoidGradient` of an incoming gradient of `1.0` over a source of `0.0` is `0x3e800000`, which is
`1.0` times the sigmoid of `0.0` times one minus the sigmoid of `0.0`.

**`divisionNoNaN` decides on the divisor and a NaN divisor is not one of them.** Measured: a zero divisor
answers `0x00000000` for every numerator, and a NaN divisor answers the arithmetic's NaN - `+inf` over
`0x7e00` is `0x7fc00000`, and `0xfe00` over `2.0` is `0x7fc00000`.

### One row per operation: how much of the release each candidate spelling reproduces

The coordinator's question for the float32 residue was which precision each operation is computed in, and
the answer is measured per operation rather than argued. `.agent-work/runs/probe/float32-spellings.c`
computes, for each of the eighteen transcendental operations, the sixteen answers under both spellings -
the `float` function and the `double` one rounded to a float on store - and they are compared with the
release's own sixteen from the harness's `system` run. **How many of the sixteen classes each spelling
gets right:**

| operation | `sinf` and friends | `sin` and friends, rounded once | the operation's own class |
| --- | --- | --- | --- |
| `cos` | 16 | 16 | exact |
| `atanh` | 16 | 16 | exact |
| `acosh` | 15 | 15 | 1 cell |
| `sinh` | 15 | 15 | exact, the 15th class being the flush |
| `exp2` | 15 | 15 | 3 cells, all in half |
| `tan` | 14 | 14 | 4 cells |
| `acos` | 14 | 15 | 1 cell |
| `exp10` | 14 | 14 | 1 cell |
| `cosh` | 14 | 14 | 2 cells |
| `asin` | 13 | 14 | 1 cell |
| `asinh` | 13 | 13 | 4 cells |
| `sigmoid` | 13 | 14 | 1 cell |
| `sin` | 12 | 12 | 3 cells |
| `log2` | 13 | 13 | 8 cells, all in half |
| `atan` | 11 | 13 | 6 cells, all in half |
| `log10` | 9 | 9 | 4 cells |
| `erf` | 5 | 5 | 8 cells |
| `tanh` | 4 | 4 | 9 cells |

The two columns are equal on twelve of the eighteen, because this machine's `sinf(1.0f)` and
`(float)sin(1.0)` are the same sixteen values - it is a correctly rounded float32 either way. The six
where they differ are `acos`, `asin`, `atan` and `sigmoid`, which the `double` spelling gets one class
more, and **none of the eighteen is exact under either spelling**. That is the measurement: the release's
transcendental kernels are Metal's own, and neither precision of the C function is them. The rows this
family registers are therefore the ones whose cells agree whatever the spelling, and they are named in
their own rows.

### What "the same arithmetic" means for a kernel that is not the C library's

Sixteen classes are not enough to measure a precision, so the sweep is **thirty-two**: the sixteen classes
above and then sixteen ordinary values - `2^-16` and `2^-15` and three quarters and seven eighths of each,
and one plus each of those, and their negatives - because those are the inputs whose last bit a kernel's own
rounding is decided on. Every case of every family runs over the whole thirty-two in both types, and the run
compares **3808 cells** where it compared 2048.

Where the two answers of a cell differ, the comparison asks how far apart they are in units in the last
place before it calls the cell a difference: the bit patterns are read as signed integers in sign-magnitude
order, so the distance is how many representable values lie between them; a zero of either sign is the same
value, and a NaN against a number is no distance at all and stays recorded whatever the tolerance says.

**And how far they may be is the specification's figure, not this differential's.** The source is the
*Metal Shading Language Specification*, version 2026-06-04, section **8.4 "ULPs and Relative Error"**: its
single-precision table is **Table 8.1** (pages 368-369) and its half-precision table is **Table 8.3**
(pages 373-374, which "applies to iOS and macOS, starting with Apple GPU Family 4 hardware" - what this
host is). `tests/backports/host/mpsgraph/tolerances.txt` carries the figures by table and page, and where a
row of either table reads "Correctly rounded" the figure is zero: the specification holds `sqrt`, `rsqrt`,
`rint`, `round`, `ceil` and `floor` to the correctly rounded answer, so those are compared byte for byte.
The figures that are here: `acos`, `acosh`, `asin`, `asinh` four and `atan`, `atanh` five in single
precision; `atan2` six; `cos`, `cosh`, `exp2`, `exp10`, `log2`, `log10`, `sin`, `sinh` four; `tan` six;
`tanh` five; `pow` sixteen. Every half figure is one, Table 8.3 giving one for each of them.

**Two operations of this family are in neither table, and that is what decides them.** The specification
does not define or bound `erf` at all, in either precision, so there is no documented bound to hold it to
and its fifteen cells are compared byte for byte and recorded where the two differ - its row stays
`missing`. A half `pow` is likewise absent from Table 8.3 while the single-precision `pow` is in Table 8.1,
so `pow` carries the single figure and its half cells are byte for byte. A sigmoid is not a function the
specification names either, so its figure is the sum of two it does: `sigmoid(x)` is one over one plus an
exponential of the negated argument, `exp` is four in Table 8.1 and one in Table 8.3, and `x / y` and
`1.0 / x` are "Correctly rounded" in the same two tables and add nothing - four and one.

**The measured distance, next to the figure it is held to.** Every operation's measured maximum over the
thirty-two classes is one or two units in the last place except three: the hyperbolic tangent's is eleven in
half against a figure of one, the arctangent's is three against a figure of one, and a power's is two in
half against no figure at all. All three are recorded cell by cell, which is what the record is for. The
other measured maxima sit at or inside their figure:

| operation | measured float32 | figure | measured float16 | figure |
| --- | --- | --- | --- | --- |
| `sin`, `cos`, `sinh`, `cosh`, `tan` | 1 | 4, 4, 4, 4, 6 | 1 | 1 |
| `asin`, `asinh` | 1 | 4 | 0 | 1 |
| `atan` | 0 | 5 | 3 | 1 |
| `atanh` | 0 | 5 | 0 | 1 |
| `atan2` | 1 | 6 | 0 | 1 |
| `acos`, `acosh` | 0 | 4 | 0 | 1 |
| `exp2`, `exp10`, `log2`, `log10` | 1 | 4 | 0 or 1 | 1 |
| `power` | 1 | 16 | 2 | none |
| `sigmoid` | 1 | 4 | 1 | 1 |
| `tanh` | 1 | 5 | 11 | 1 |
| `erf` | 2 | **none** | 1 | **none** |

**No non-transcendental case has a tolerance at all.** A predicate, a logical, both remainders, a minimum,
a maximum, a select, a clamp, a rounding, the three questions about a value, a ReLU and a ReLU gradient are
compared byte for byte in both types, and the six comparisons and the four orderings byte for byte as one
byte each. That is deliberate: their answers are a truth, a whole number or one of two orderings, and "within
N units in the last place" is not a thing for any of them.

**What a mutation does to it**: `port: same as the system on 3609 of the 3808 cells with a result buffer;
3410 within the release's own precision, 199 recorded`, `checks=128 failures=0`, and the planted build still
differs from the release in 128 of the 130 cases. The red control is why a tolerance is safe here: the plant
is every stored element off by one whole unit of the value, which is between 10^6 and 10^38 units in the
last place, so no figure anywhere near four can hide it.

### What a NaN, an infinity and a zero are in half, per operation

The release's half kernels do not agree with each other about a NaN, and each of them answers it its own
way. Measured over the case file's thirty-two classes, `RevenantMPSGraphHalfNaNOf` in the interpreter is the
table, one entry per kind, and this is what it says:

| a kind's answer in half for a NaN operand | the kinds | measured |
| --- | --- | --- |
| an infinity of the NaN's own sign | the arithmetic family (`abs`, `identity`, `add`, `subtract`, `square`), and `ceil`, `floor`, `round`, `select`, a ReLU's gradient, a ReLU | `0x7e00` is `0x7c00` and `0xfe00` is `0xfc00` |
| an infinity of the other sign | `negative` | the negation of `0x7e00` is `0xfc00` and of `0xfe00` is `0x7c00` |
| a zero | `sin`, `cos`, `logBase2` | each of `0x7e00` and `0xfe00` is `0x0000`, and so is each of them of an infinity of either sign |
| the canonical positive NaN | `asin`, `acos`, `asinh`, `acosh`, `atanh` | the arcsine, the hyperbolic arc-sine and the hyperbolic arc-tangent of `0xfe00` are `0x7e00` |
| a saturation at the NaN's sign | `erf`, `tanh` | `erf(0x7e00)` is `0x3c00` and `erf(0xfe00)` is `0xbc00`; the hyperbolic tangent the same |
| a saturation at one whatever the sign | `power` | a power of an infinity, of a NaN and of a negative ordinary value are all `0x3c00` |
| one for a positive NaN and a zero for a negative one | `sigmoid` | `sigmoid(0x7e00)` is `0x3c00` and `sigmoid(0xfe00)` is `0x0000` |
| read off the bit rather than off the class | `sqrt`, `sign` | the square root of `0x7e00` is `0x7c00` and of `0xfe00` is `0x0000`, and the sign of a NaN is the sign of the NaN |

**A zero is a positive zero in half, for every kind and not per operation.** Measured: the ceiling and the
floor and the sine of a positive zero, a product of a negative zero, the negation of a negative zero, a
maximum of `-1.0` and `-0.0`, a select whose value is a negative zero, a ReLU's gradient of a negative
ordinary source and an error function of a positive zero are each `0x0000`, where IEEE answers a zero of
the operand's own sign. The rule is applied after the half block and before the store, so it also covers
the kinds the half block does not reach.

Together the table and that rule took the run from 208 recorded cells to 166, and with the figures the
specification gives, **36 of the 58 cases of this family are clean in every type**: the six comparisons and the four orderings are clean in float32 only,
and the six remainders' float32 answers are the recorded group the previous pass measured.

### The recorded cells, grouped

`tests/backports/host/mpsgraph/recorded-cells.txt` names each of the 199 with the two runs' bytes, read
out of the run's own outputs by `.agent-work/record.py`. They are of three kinds, and none of them is a
tolerance:

* **The float32 cells that are not a difference in value**: the hyperbolic tangent's nine and the two sigmoid gradients' four, where the release's answer for a NaN, a zero or a denormal is not a number at all. The release's
  transcendentals are not the C library's, in either precision. Measured cell by cell over the sixteen
  classes: the release's `sin` of `1.0` is `0x3f576aa5`, this machine's own `sinf(1.0f)` is `0x3f576aa4`
  and `(float)sin(1.0)` is `0x3f576aa4` as well, and `0x3f576aa4` is the correctly rounded one - the exact
  value `0.8414709848` is nearer `0x3f576aa4` than `0x3f576aa5` - so the release's kernel is an
  approximation and neither spelling of the C function is it. The same holds for the rest of the family:
  `coshf(1.0f)` is `0x3fc583ab` and the release answers `0x3fc583aa`, `erff(1.0f)` is `0x3f57bb3d` against
  the release's `0x3f57bb3c`, and `tanhf(1.0f)` is `0x3f42f7d6` against the release's `0x3f42f7d5`.
  **Attempted and rejected**: giving each transcendental the float32 spelling when its operand is a
  float32, which is the one thing the measurement suggests a reader would try. Measured by building it
  and running the whole file: it fixes **no** cell and makes **five** differ - `acos` 0 to 1, `asin` 4 to
  5, `atan` 2 to 4, `atan2` 1 to 3 and `sigmoid` 1 to 2, 196 to 203 recorded. The tree therefore keeps one
  spelling, the double one, and the transcendental family's float32 cells stay recorded. What would remove
  them is the release's own polynomial, which is not in any header and is not derivable from the
  specification of the operation.
* **Most of the 208 are float16.** The same four kinds in `MPSDataTypeFloat16`, where the release's half kernels
  answer the special classes by rules of their own - the ones already measured for the arithmetic family
  are the table above - and where a per-operation half rule has not been derived yet. The families with
  the fewest are `expBase10` and `acosh` and `acos` and `rint` (none), `signbit` and `reLU` and `minimum`
  and `atanh` and `asinh` and `ceil` (one to three) and the ones with the most are `sigmoidGradient`
  (fourteen) and `tanh` (seven) and `erf` (seven).
* **8 boolean cells**, all of them a comparison whose float16 operand is a NaN: `lessThan` and
  `lessThanOrEqualTo` answer `true` for `+inf` against `0x7e00` and for `-NaN` against `2.0`, and
  `greaterThan` and `greaterThanOrEqualTo` answer `true` for `-inf` against `0xfe00` and for `0x7e00`
  against `0x0001`, where every other comparison of the same case answers what IEEE answers. The release's
  own diagnostic names the kernel: `ConvertBinaryCompareToZero expects the second operand to be zero`
  (MPSGraphUtilities.mm:254).
* **Cells of the pre-existing arithmetic family**, which the record already carried and which the same
  per-cell comparison re-checks.

**One thing the harness had to be taught.** The framework writes its own diagnostics to the same standard
output the cases go to, and with a block-buffered stream one of them landed in the middle of a case line: a
flush boundary split the sixteen halves of `subtract float16` and the line carried the tail of a warning
instead of its last four bytes. The case file now sets `setvbuf(stdout, NULL, _IOLBF, 0)`, so a case is one
line or nothing, and `run.sh` compares only the lines the case file marks `#case`, so the framework's
diagnostics are not cases. The size of the result table went from sixty-four to five hundred and twelve for
the same reason: it held one entry per case and there are a hundred and thirty now, so a hundred and
twenty-ninth case wrote past its own end.

Not written of this family: the soft-max pair, which is an axis reduction and wants the reduction
machinery first. The rest of the 14.0 surface - reductions, matmul, convolution, pooling, normalization,
the shape operations, control flow, random, the optimizers - is not written either, and each is a family
of the same shape.

## The arithmetic family, and the rest

Addition, subtraction, multiplication, division, and the unary operations negation, square,
reciprocal, square root, reverse square root, exponential, logarithm, absolute and sign. Each is a kind
in `RevenantMPSGraphOperationKind` and a case in the interpreter, so a family lands by adding a kind and a
function rather than by touching every other operation.

Not written: matmul, convolution, pooling, normalization, activation, shape operations,
control flow, random, optimizers, and the rest of the surface. Each is a family of the same shape, and
each wants the differential to run a graph end to end first.

## The reduction family of 14.0

A reduction is the first family here whose result is not the operand's shape, so it is walked by a
function of its own (`RevenantMPSGraphReduce` in `MPSGraphInterpreter14.m`) over the OPERAND rather than by
the element-at-a-time loop the arithmetic family uses, and `graph-cases.m` asks it through a case helper
of its own (`reduction_case`) that gives the compile a feed of the operand's shape and a destination of the
result's.

Measured against this host's own MPSGraph (macOS, Apple M4 Pro), over a 2x4 feed of
(1, 2, 3, 4 | 10, 20, 30, 40) and over the case file's sixteen input classes, in MPSDataTypeFloat32,
MPSDataTypeInt32 and MPSDataTypeFloat16. `bytes` is the release's own answer, little-endian, and every one
of them is byte-identical to the port's:

| question | answer |
| --- | --- |
| `reductionSumWithTensor:axis:0` over the 2x4 | shape (1, 4), `00003041 0000b041 00000442 00003042` = (11, 22, 33, 42) |
| `reductionSumWithTensor:axis:1` | shape (2, 1), `00002041 0000c842` = (10, 100) |
| `axis:-1` and `axes:@[1]` | the same bytes and the same (2, 1) as `axis:1` |
| `axis:-2` | the same bytes and the same (1, 4) as `axis:0` |
| `axes:@[@1, @0]` and `axes:@[@0, @1]` | both shape (1, 1), `0000dc42` = 110 |
| `axes:@[@0, @0]` | the same bytes and the same (1, 4) as `axes:@[@0]`: a set, so a repeated axis reduces once |
| `axes:@[]` | shape (2, 4) and the operand's own bytes: no axis is reduced |
| `axes:nil` | shape (1, 1), `0000dc42` = 110: nil is EVERY axis |
| `reductionProductWithTensor:axis:1` | `0000c041 00606a48` = (24, 240000) |
| `reductionMaximumWithTensor:axis:1` | `00008040 00002042` = (4, 40) |
| `reductionMinimumWithTensor:axis:1` | `0000803f 00002041` = (1, 10) |
| `meanOfTensor:axes:@[@1]` | `00002040 0000c841` = (2.5, 25); as int32 `ffffffff 02000000` = (-1, 2), the truncated quotients; as float16 `0041 8046` = (2.5, 6.5) |
| `varianceOfTensor:axes:@[@1]` | `0000a03f 0000fa42` = (1.25, 125); as int32 `01000000 01000000`; as float16 `003d 003d` = (1.25, 1.25) |
| `varianceOfTensor:meanTensor:axes:@[@1]` over the same feed and the mean of it | the same bytes as the variance above |

The three rules of the set of axes, which is what a caller can get wrong and what the port normalises:
a negative axis is counted from the end of the rank, the order written does not matter, and nil is every
axis while an empty array is none.

### The NaN in a reduction, which is the whole of the difference between the four extremes

Over a feed of (1, NaN, 3, 4 | NaN, 6, 7, 8), and then over a 2x4 whose eight elements are all NaN:

| operation | over a row with a NaN | over a row of nothing but NaNs |
| --- | --- | --- |
| `reductionMaximumWithTensor:axis:1` | (4, 8) - the NaN is skipped | `000080ff 000080ff` = negative infinity |
| `reductionMaximumPropagateNaNWithTensor:axis:1` | `0000c07f 0000c07f` = NaN | NaN |
| `reductionMinimumWithTensor:axis:1` | (1, 6) - the NaN is skipped | `0000807f 0000807f` = positive infinity |
| `reductionMinimumPropagateNaNWithTensor:axis:1` | NaN | NaN |

So the kernel seeds an infinity - negative for a maximum, positive for a minimum - and lets one comparison
decide the rest, and a NaN loses every comparison including one against another NaN. That is why a
maximum skips a NaN and why a reduced set of nothing but NaNs answers the seed rather than a NaN. The
propagating variants latch: a NaN that reaches an element is that element's answer and nothing after it
can move it. The sum, the product, the mean and the variance are different - over the same feed all four
answer NaN, because a NaN reaches the arithmetic and the arithmetic's own NaN is what leaves it.

### An axis outside the rank, which the release cannot answer at all

`reductionSumWithTensor:axis:5` over a 2x4 writes `invalid axes: 5` and then takes the process down with
`LLVM ERROR: Failed to infer result type(s)`, so there is no answer to record: the graph is never built.
A port cannot reproduce a process that is gone, and answering a tensor for it would be an answer the
release does not give, so the port raises `NSInvalidArgumentException` when the graph is built instead.
This is the one place in the reduction family where the port is not the release's answer in form, and it
is named in the row of every method of the family.

## The rest of the reduction family: 15.0's argument reductions and NaN-propagating extremes, and 15.3's truth folds

Eight rows: `reductionArgMaximumWithTensor:axis:name:` and `reductionArgMinimumWithTensor:axis:name:` and the
two `WithNaNPropagation` binary forms (15.0, `MPSGraphReductionOps150.m`), and `reductionAndWithTensor:` and
`reductionOrWithTensor:` in both forms (15.3, `MPSGraphReductionOps153.m`).

**How one walk serves three releases.** The walk over the family is a TABLE keyed by the operation's own
parameters, not by its kind: an operation says which combination it folds with (`@"combination"`), whether a
NaN latches (`@"propagateNaN"`), whether the answer is an index rather than a value (`@"index"`), and for the
elementwise half whether the kernel latches a NaN (`@"latchNaN"`). None of those words is a name of any
release's framework, so the 14.0 object that holds the walk and the axis arithmetic names nothing of 15.0 or
15.3, and each of those two objects names only its own four methods. That is the arrangement the coordinator
ruled for this family after v-mps3's report named the question; `relcheck`'s `check_releases` is what reads
it back out of the objects ("compiled 13 objects of MPSGraphBackports", "check_releases: every object of
MPSGraphBackports holds API of one release").

Every cell of every case below is byte-identical between the release and the port, in all three data types
the family is asked in, and none of them is on `recorded-cells.txt`.

### The argument reductions

| question, over the case file's 2x4 feeds | the release's answer | the port |
| --- | --- | --- |
| `reductionArgMaximumWithTensor:axis:1` over the sixteen classes | `00000000 00000000` = (0, 0) | identical |
| `reductionArgMinimumWithTensor:axis:1` over the same | `01000000 01000000` = (1, 1) | identical |
| `argMaximum` over (1, 2, 3, 4 \| 10, 20, 30, 40) | `03000000 03000000` = (3, 3) | identical |
| `argMinimum` over the same | `00000000 00000000` = (0, 0) | identical |
| `argMaximum` over (4, 4, 4, 9 \| 9, 9, 1, 1) | `03000000 00000000` = (3, 0) | identical |
| `argMinimum` over the same | `00000000 02000000` = (0, 2) | identical |
| `argMaximum` and `argMinimum` over a row of nothing but NaNs | `ffffffff ffffffff` = (-1, -1) | identical |
| `argMaximum` over the int32 and over the float16 feed | `03000000 03000000` = (3, 3) | identical |
| `argMaximum axis:0` and `argMinimum axis:0` over the ordinary feed | `01000000 01000000 01000000 01000000` and four zeros, a 1x4 | identical |
| `argMaximum axis:-1` | the same bytes as `axis:1` | identical |

So the rules, all measured: the answer is the index of the **first** element holding the extreme (the tied row
above is what says so - a comparison that replaced on equality would answer the last of the three); a NaN
loses every comparison and is never the answer wherever it sits (measured one NaN at a time at each of the
four positions of a row of four, and at both ends and the middle of a row of nine: `(nan, 1, 2, 3)` answers 3
for a maximum and 1 for a minimum, `(1, 2, 3, nan)` answers 2 and 0, and a row of nine with a NaN at either end
answers 8 and 7); a reduced set of nothing but NaNs answers **-1**, which is "nothing was found" rather than
an index into an empty set; the two signed zeros compare equal, so `(0, -0, 0, -0)` answers 0 for both; and
the answer is stored as **MPSDataTypeInt32** whatever the operand's own type was, which is why the case names
carry the result's type and where it came from.

### The two binary NaN-propagating extremes

The header states the rule (`isNaN(primary) || isNaN(secondary) ? NaN : min(primary, secondary)`) and the
measurement over the case file's sixteen classes in float32 and float16 confirms it: the four NaN positions
answer a NaN each and the four ordinary ones answer exactly what 14.0's pair answers over the same feeds
(`00000000 000080bf 00000080 000080ff` against a primary of (1, -1, +0, -0, +inf, -inf, NaN, -NaN) and a
secondary of (+0, -0, +inf, -inf, NaN, -NaN, 1.4e-45, 2)), so the four NaNs are the whole difference between
the two pairs.

**Every data type that is not a floating point one is refused, and the port refuses exactly that set.**
Measured on this host's own MPSGraph, one type at a time, over a feed of eight ascending bytes against eight
descending ones (which every one of these types reads as the same two numbers), both operations:

| operand type | the release over `minimumWithNaNPropagation` and over `maximumWithNaNPropagation` | the kernel it reaches for |
| --- | --- | --- |
| `MPSDataTypeFloat32`, `MPSDataTypeFloat16` | **answers** | - |
| `MPSDataTypeInt8` | raises `NSInvalidArgumentException` | `isNaN_i8` |
| `MPSDataTypeInt16` | raises | `isNaN_i16_i8` |
| `MPSDataTypeInt32` | raises | `isNaN_i_i8` |
| `MPSDataTypeInt64` | raises | `isNaN_i64_i8` |
| `MPSDataTypeUInt8` | raises | `isNaN_u8_i8` |
| `MPSDataTypeUInt16` | raises | `isNaN_u16_i8` |
| `MPSDataTypeUInt32` | raises | `isNaN_u_i8` |
| `MPSDataTypeUInt64` | raises | `isNaN_u64_i8` |
| `MPSDataTypeBool` | raises | `isNaN_i8` |

Every refusal is `-[__NSDictionaryM setObject:forKey:]: object cannot be nil (key: ...)` from inside the
framework's own kernel table, raised before a single element is written, and the key names the type it
wanted: there is no NaN kernel for an integer type, and a boolean is an integer type to it. So the port's
rule - refuse every data type that is not `MPSDataTypeFloat32` or `MPSDataTypeFloat16` - is the measured set
and not a guess, and it is asked of both operations over all nine types in
`tests/backports/host/mpsgraph/graph-cases.m`, each case built and run inside an `@try` because that is where
the release raises: `raised-NSInvalidArgumentException` on both sides of all eighteen.

This is the second place in this family where the port is not the release's answer in form, and it is named
in the row of both methods.

**In float16 this pair keeps the sign of a zero where 14.0's does not.** Measured over the same sixteen
classes: `maximumWithNaNPropagation` answers `8000` for a maximum of -1.0 and -0.0 and `8000` for a maximum
of +0.0 and -inf, where 14.0's `maximum` answers `0000` for the same two pairs - and the port's float32
answer is -0.0 for both, so it is the half kernel and not the pair. The port's half rule ("a zero is a
positive zero in half", one rule for every kind of 14.0, measured over nine kinds) therefore does not apply to
an operation that latches, and the walk reads that out of the operation's own parameters like everything else.

### The two truth folds

| question | the release's answer | the port |
| --- | --- | --- |
| `reductionAndWithTensor:axis:1` over the sixteen classes | `00000000 0000803f` = (0, 1) | identical |
| `reductionOrWithTensor:axis:1` over the same | `0000803f 0000803f` = (1, 1) | identical |
| both over the int32 feed | `00000000 01000000` and `01000000 01000000` | identical |
| both over the float16 feed | `003c003c` for each | identical |
| both over a row of nothing but NaNs | `0000803f 0000803f` = (1, 1) | identical |
| both over `axes:nil` (every axis, a 1x1) | `00000000` for the "and", `0000803f` for the "or" | identical |
| both over `axes:@[]` (no axis, a 2x4) | the operand's own bytes, `0000803f 000080bf 00000080 000080ff ...` | identical |
| both over `axes:@[@1, @0]` (a set, a 1x1) | `0000803f` | identical |

So: the answer is written in the **operand's own type** and not in a boolean (measured in float32, float16,
int32 and uint8), the test is against zero, so both signed zeros are false and a NaN is a nonzero like any
other value (an "and" of a row of nothing but NaNs is 1), the answer is one and not a truth of another kind
(0x3f800000, 0x3c00, 1, 1), and the axes are the family's own (nil every axis, an empty array none, a
descending set still a set).

**A reduced set of no axes is the identity, and the truth folds are what measure it.** Over `axes:@[]` both
of them answer the operand byte for byte, where a seed of each fold's identity would answer 1 and 0
everywhere. The walk therefore answers a reduction over no axis with the operand itself, and the rule is in
the walk rather than in the two folds because a sum and a product of the identity are the identity either way:
only a fold whose answer is not the element's own can tell the two apart.

## The gather family: sixteen shape and axis methods

Sixteen rows of the tensor-shape headers, in four objects: 14.0's `transposeTensor:dimension:withDimension:name:`
(in `MPSGraph14.m`), 15.0's `MPSGraphTensorShapeOps150.m` (two flattens, two broadcasts, three reverses),
15.4's `MPSGraphTensorShapeOps154.m` (four squeezes, three expanded dimensions) and 16.0's
`MPSGraphTensorShapeOps160.m` (the permutation transpose).

**One walk for all sixteen.** A gather is one question - for each axis of the result, which axis of the
operand feeds it, how many of the operand's axes it covers, and whether that one is reversed - so
`RevenantMPSGraphGatherPlan` derives that from the operation's parameters and `RevenantMPSGraphGather` walks it.
Which transformation it is (`@"gather"`), which of its parameter the caller wrote down (`@"gatherAxis"`,
`@"gatherDrop"`, `"gatherAdd"`, `@"gatherAxes"`, `@"gatherPermutation"`) or which of the operation's inputs
carries it instead (`@"gatherOperand"`), and every release's factory fills those in and names only its own
methods.

**The result's shape is derived at build time as well as at run time, because that is where the release
derives it.** The release infers an operation's result type when the graph is built - which is why an axis it
cannot use aborts there rather than at the run - so a caller can read `shape` off the tensor it was handed
before anything runs, and the port answers it there through `-[MPSGraph revenant_mps_gatherShapeOfTensor:
parameters:named:]`: the same plan the interpreter walks, asked with the operand's shape and no fed parameter.
A parameter the caller fed, or an operand whose own shape is not known yet (a gather of a fed gather), gives
nil there, and the interpreter puts the shape on when it runs the operation - which is what lets a shape the
caller FEEDS be the result's shape at all.

### What the differential compares, and what it found

`tests/backports/host/mpsgraph/run.sh` runs the family in SIX processes, one per form (`gather_transpose`,
`gather_flatten`, `gather_broadcast`, `gather_reverse`, `gather_squeeze`, `gather_expand`), because in one
process the release asserts partway through it: "Error: NDArray dimension length > INT_MAX"
(MPSNDArray.mm:831) over a flatten of a 2x4 that answers in a process of its own. **52 cases, over the sixteen
methods and their result shapes, and every cell and every shape is byte-identical to the release**:

| group | verdict line | cells |
| --- | --- | --- |
| `gather_transpose` | `checks=10 failures=0 recorded=0` | 168 |
| `gather_flatten` | `checks=6 failures=0 recorded=0` | 96 |
| `gather_broadcast` | `checks=8 failures=0 recorded=0` | 144 |
| `gather_reverse` | `checks=8 failures=0 recorded=0` | 64 |
| `gather_squeeze` | `checks=11 failures=0 recorded=0` | 84 |
| `gather_expand` | `checks=9 failures=0 recorded=0` | 88 |

**Each case prints its result's SHAPE as well as its bytes**, because a gather's answer is its shape as much
as its elements and the two do not go together: dropping a unit axis and adding one both move no element, so
only the shape line can see them. Two of the three defects below are invisible to the bytes and were found by
the shape line, which is why it is there. (Reading a shaped type's EQUALITY still takes the release down - it
calls a selector its own `MPSGraphTensor` does not declare - so the shape is printed and not compared.)

**Three defects the differential found in the port, and one in this page's own previous text.** All are the
release's answer and not a reading of it:

* **The walk's strides were wrong for every gather.** The last axis's stride is one and every earlier axis's
  is the next one's weighted by the next axis's extent; the code multiplied the LAST axis's extent into its
  own stride, so a rank of two came out (8, 4) where (4, 1) is right. Every case of the family failed on it
  and the two of a rank of three passed by luck.
* **A broadcast WRAPS where the release answers a zero.** The previous pass's own probe output says so - a 2x4
  into a 4x4 answers (1, 2, 3, 4, 10, 20, 30, 40) and then eight ZEROS - and the table below read it as each
  row twice. Measured again over a destination filled with the byte pattern 0xbd, where those eight elements
  are the release's zeros and not the caller's bytes and not a second copy of the row: a coordinate of the
  result past the operand's own extent has no element behind it and the release writes a zero there. An
  operand axis of extent ONE is different and is repeated along a result axis of any extent, which is what a
  1x2x4 into a 2x2x4 answers as the operand twice.
* **A flatten2D's result is of rank TWO.** The elements are the operand's own in order whichever way it is
  spelled, so only the shape line sees it: axis 0 of a 2x4 is a `1x8`, axis 1 of a 2x3x4 a `2x12` and axis 2
  of a 2x3x4 a `6x4`. The two axes are the product of the extents before the one named and the product of the
  rest.
* **The two-axis transpose keeps the operand's rank.** Measured, `dimension:0 withDimension:2` of a 2x3x4
  answers a 4x3x2 and the same axis named twice answers the operand itself, so the permutation the walk is
  given is the identity with those two entries exchanged rather than a two-entry ordering (which answered a
  rank of two whatever the operand's rank was). An expanded dimension's axis goes **at each index named** for
  the same reason: axes `@[@0, @2]` of a 2x4 is a `1x2x1x4` and `@[@0, @1]` a `1x1x2x4`, where inserting one
  axis into the result of the last answers a `1x2x4x1` and a `1x1x2x4`.

### The rules, all measured on this host's own MPSGraph

Over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40), over a 2x3x4 of the 1 to 24 a row-major operand holds, and over
the input classes (a positive and a negative, both zeros, both infinities and a NaN of each sign), every one of
them is a case of the differential above:

| operation | the release answers | the rule |
| --- | --- | --- |
| `transposeTensor:dimension:0 withDimension:1` | a 4x2 of (1, 10, 2, 20, 3, 30, 4, 40) | the row-major transpose, and the operand's rank is kept whatever it is |
| `transposeTensor:dimension:-1 withDimension:0` | the same bytes and the same 4x2 | a negative axis is counted from the end - and the header's own type for it is `NSUInteger`, which the release still reads as signed |
| `transposeTensor:dimension:0 withDimension:0` over a 2x3x4 | the operand's own bytes into the 2x3x4 | the same axis named twice is the identity |
| `transposeTensor:permutation:@[@1, @0]` | the same 4x2 and the same bytes as the two-axis form | a permutation of the whole ordering, one entry per axis of the operand |
| `transposeTensor:permutation:@[@2, @0, @1]` over a 2x3x4 | a 4x2x3 | and of any length |
| `squeezeTensor` over a 1x2x4 | a 2x4 of (1, 2, 3, 4, 5, 6, 7, 8) | every unit axis is dropped, and the rest keep their order |
| `squeezeTensor` over a 2x4 | the 2x4 itself | an operand with no unit axis is itself |
| `squeezeTensor:axes:@[]` and `axes:nil` over a 1x2x4 | a 1x2x4 | unlike the reduction family's axes, NONE is none: an empty array and a nil drop nothing |
| `expandDimsOfTensor:axis:0` over a 2x4 | a 1x2x4 of the same eight values | an axis of extent one at the index named |
| `expandDimsOfTensor:axis:2` and `axis:-1` | a 2x4x1 | and a negative axis may be the rank itself, which is that trailing unit axis |
| `expandDimsOfTensor:axes:@[@0, @2]` | a 1x2x1x4 | one axis at EACH index named, not one inserted after another |
| `flatten2DTensor:axis:0` over a 2x4 | a 1x8 of the same eight values | everything before the axis named collapses into one axis of their product, everything from it on into another |
| `flatten2DTensor:axis:1` over a 2x4 | the 2x4 itself | and axis 1 of a 2x3x4 is a 2x12 and axis 2 a 6x4 |
| `broadcastTensor:toShape:@[@4, @4]` | (1, 2, 3, 4, 10, 20, 30, 40) and then eight zeros | the operand aligns to the RIGHT, and a coordinate past its own extent is a zero |
| `broadcastTensor:toShape:@[@2, @2, @4]` | the 2x4 twice | an axis the shape adds at the front repeats the whole operand |
| `broadcastTensor:toShape:@[@1, @4]` | the 2x4 itself | the result's extent is the larger of the two on every axis they share |
| `broadcastTensor:toShape:@[@4, @4]` over a 1x2x4 of classes | each row of the 2x4 twice | an operand axis of extent one is repeated along a result axis of any extent |
| `reverseTensor` | (4, 3, 2, 1 \| 40, 30, 20, 10) | every axis is flipped when none is named |
| `reverseTensor:axes:@[@1]` | (4, 3, 2, 1 \| 40, 30, 20, 10) | only the axes named are flipped, and nothing else moves |
| `reverseTensor:axes:@[@0]` | (10, 20, 30, 40 \| 1, 2, 3, 4) | and over the classes, `axes:@[@-1]` answers what `axes:@[@1]` answers |
| `reverseTensor:axes:@[]` | every axis flipped | an empty array is every axis here as no axes at all is |

The squeeze, the expanded dimension and the flatten are therefore **one gather with the axes left alone** -
each of them answers the operand's own bytes in the operand's own order - and the transpose, the broadcast and
the reverse are one gather with them not.

### The five FED forms, which the differential cannot compare

The parameter a caller FEEDS - an axis, a set of axes, a shape - arrives as the operation's second input. The
first pass at this asked each of the five in a process of its own and recorded that **each of the five takes
the release down**, and that table was **this repository's own question asked into the wrong destination**:
`refusals.m`'s `fed()` helper sized the destination off the result's own shape, which over a fed parameter is
a vector of `-1` (the next section measures it), so the release was handed a buffer of ONE element and its
NDArray asserted about the buffer rather than about the operation. Re-measured with a destination the caller
gives - the written-down form's own shape - the table is:

| form | what the release does, asked into a destination of the written-down form's shape |
| --- | --- |
| `flatten2DTensor:axisTensor:` | answers exit 0, prints `result-shape -1x-1`, and writes **zeros** over the destination |
| `broadcastTensor:toShapeTensor:` | answers exit 0, prints `result-shape -1` (a fed `[4]`), and writes zeros |
| `reverseTensor:axesTensor:` | the framework asserts "non constant axes tensor" at the RUN (exit 134) - the one form of the five that is refused for its own sake |
| `squeezeTensor:axesTensor:` | answers exit 0, prints `result-shape -1x-1`, and writes zeros |
| `expandDimsOfTensor:axesTensor:` | answers exit 0, prints `result-shape -1`, and writes zeros |

and the reshape's own fed form prints `result-shape -1`, has its compiler print "the result shape is not
compatible with the input shape" (`MPSGraphUtilities.mm:310`), and then answers exit 0 with the destination
untouched - asked in a graph that ALSO holds the written-down reshape of the same operand, the same call
aborts at the compile with the same sentence (exit 134), which is what the band's probe measured and what
`refusals.txt` used to record. Both are the release; this file records the one `run.sh` re-runs.

**What the four answering forms WRITE is the gather**, byte for byte what the written-down form of the same call
writes - see the next section, which also retracts this band's own first claim that they write zeros. What is
left refused over a fed parameter in this family is the reverse alone, at the run.

So the four that answer are not comparable CASES for one reason only - each fed gather takes the process down
in a process that holds the rest of the family (the reason every family is its own process) - and not because
the release's values differ from the port's: they do not, they are the same gather. `refusals.txt`'s five fed
rows hold the release's own bytes for it, and its five `*-own` rows the shape it allocates. A fed parameter of a floating point type is refused by
the factory, because the release cannot build the graph over one at all; an int32 and an int64 of shape [1]
both answer, measured.

### What the release's own RESULT TENSOR carries over a fed parameter, measured, and the port's answer

The paragraph above is about what the release does to the PROCESS. This one is about what its own tensor says,
which is a question the harness can ask and the port could not answer before, because every fed form went
through `revenant_mps_operation:` and took the FIRST INPUT's shape - a shape nobody asked for.

Measured on this host's own MPSGraph over **thirty-seven configurations**, one case per process under a
timeout: `.agent-work/probe/fedshape.m`, driven by `fedshape.sh`, every stage flushed before the next is
entered so a case that dies says which stage it was in, and the raw run of every case beside it under
`.agent-work/runs/v-mps13/fedshape-<case>.out`. The release infers the result's type when the graph is built,
and over a fed parameter it infers as far as the graph already knows and writes **-1 for every extent the fed
value decides**. The `-1` is its own marker for an extent it could not resolve - the same one the two dynamic
extents of a written-down reshape print - and it is on the tensor **before the run and after it**.

The one number it reads out of the fed tensor is its own **single extent**, which is the count of axes the fed
parameter names. Everything else follows from that:

| form | the release's own result tensor, over a fed parameter |
| --- | --- |
| `reshapeTensor:withShapeTensor:` | the axes the fed tensor names: a fed `[2]` of a 2x4 is `-1x-1`, a fed `[1]` is `-1`, a fed `[4]` is `-1x-1x-1x-1`, and a fed 0D or a fed `[2, 2]` is **nil** |
| `flatten2DTensor:axisTensor:` | always `-1x-1`, whatever the axis is - a flatten2D's result is of rank two whatever it collapses - measured over a fed tensor of rank one, of two and of none |
| `squeezeTensor:axesTensor:` | the operand's rank LESS the axes named: one axis of a 1x2x4 is `-1x-1`, two axes of the same `-1`, one axis of a 1x1x2x4 `-1x-1x-1`, two axes of that `-1x-1`, and as many axes as the operand has is a result of rank ZERO, which is an **empty** shape |
| `expandDimsOfTensor:axesTensor:` | the axes the fed tensor names: a fed count of one is `-1`, of two `-1x-1`, at every rank of operand from two to four - the axis's own VALUE does not enter it |
| `reverseTensor:axesTensor:` | **the operand's own shape**, measured over fed axes of one and of two numbers at ranks of operand two and three |
| `broadcastTensor:toShapeTensor:` | the operand's own shape where the release carries one and a vector of `-1` where it does not - see below |
| the slice's gradient, both fed forms | **nil**, before the run and after it (`refusals.m`'s `slice-gradient-fed-shape` and `slice-gradient-fed`) |

**The port now carries the same vector**, in `RevenantMPSGraphFedGatherResultShape` in `MPSGraph14.m`, asked from
`-[MPSGraph revenant_mps_gather:tensor:fedParameter:parameters:name:]`, and the walk puts the real shape on when
the graph runs - the only moment a fed value is there to read it from. The slice's gradient carries no shape
at all, because what `revenant_mps_operation:` left on it was the shape of the INCOMING GRADIENT, which is the
shape of the region and not of the result.

The fed parameter of a rank the release will not read is refused by its own compiler with its own rule, and
that rule names the case the port answers: *"'mps.reshape' op operand #1 must be 0D tensor of mps index type
values or 1D tensor of mps index type values or unranked tensor of mps index type values, but got
'tensor<2x2xsi32'"* (`MPSGraphUtilities.mm:310`) over a fed shape of `[2, 2]`, whose result is `nil`; the fed
`[1]` the port answers is that rule's own case. A fed tensor of no rank is the rule's other case and its result
is `nil` as well.

**Two claims this page carried are corrected by the measurement.** The first: "the release's own result tensor
then carries no shape at all, before the run and after it" was true of the slice's gradient and of nothing
else. Over a fed gather parameter the release carries a vector of `-1`, or the operand's own shape, and the
`reverse` is the one form where that is the operand's own - so for that row nothing changed in the port and the
claim was simply wrong. The second: the fed parameter was measured only as something that takes the process
down. It does, over a fed tensor of two numbers or of no rank; over a fed tensor of one number four of the six
forms ANSWER, and what they answer is this:

> **Over a fed parameter the release's RUN COMPUTES THE GATHER.** On the caller's own destination, asked into
> the shape the written-down form of the same call answers, over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40):
> a fed flatten axis of 1 answers the operand's own eight values, fed axes of `[0]` over a 1x2x4 of the same
> pattern answer the region's own values with axis 0 dropped, and fed axes of `[0]` of a 2x4 expanded answer the
> operand's own values once down the new axis - byte for byte what the written-down form answers, which is what
> the port walks. **This is the correction of the claim the first pass of this band made, and the claim was
> wrong: it is not the release that writes zeros, it was this repository's own question, twice over.** A
> destination sized off the release's unresolved result shape is a ONE-ELEMENT buffer, and a fed tensor fed one
> number where its own shape says two reads its extents out of a buffer that is half empty - which, for an
> extent, is zero. Both were in this band's own probe; the fed tensor's byte count was the second of them and
> the first version of the probe handed it `MPSSizeofMPSDataType(type)` bytes whatever its shape said.

**On the path where the RELEASE allocates the result** - `-[MPSGraph runWithFeeds:targetTensors:targetOperations:]`,
which is `refusals.m`'s five `*-own` questions - it allocates the shape it resolved, and that is the -1 vector
with the extents filled in: a `2x4` for the flatten and for the squeeze, which is the written-down form's own
answer; an **`8`** for the expand, one axis of eight elements where the written-down form answers a `1x2x4`; a
**`4`** for a reshape to a fed `[4]`, the fed shape's own single extent; and the **operand's own `2x4`** for a
broadcast to a fed `[2, 4]`, which is this form's one measured divergence from the written-down answer. The
VALUES of a result the release allocated are not readable through any public accessor on this host - measured,
`class_copyPropertyList` on `MPSGraphTensorData` gives `shape`, `dataType` and `device` and nothing that reaches
the buffer, and `MPSNDArray`'s own headers are fifteen lines of imports in both the 16.4 and the 26.2 SDK - so
the shapes are what that path is asked for.

The harness asks the result's SHAPE of these forms and not their values, because over a fed parameter the
release's answer to the values is the same gather the written-down form gives and the differential already
compares that: `fed_shape_case` in `tests/backports/host/mpsgraph/graph-cases.m`, twelve cases over the six
forms and the two gradient forms, one per family, compared against the release and red for a port that carried
the operand's shape (measured: eleven of the twelve fail under the shape this port used to give). The VALUES
are held by `refusals.txt`, whose five fed rows now carry the release's own bytes for the gather.

**The broadcast is the one whose extents do not reduce to a rule.** Its RANK is the axes the fed tensor names in
all seven configurations measured, but its EXTENTS are the operand's own shape at a rank of operand two whatever
the fed numbers are (a 2x4 to a fed `[2]` holding `[2, 4]`, to one holding `[4, 4]` and to one holding
`[2, 2, 4]` all answer `2x4`), and a 2x2x4 to a fed `[3]` holding `[1, 2, 4]` answers `2x2x4` - while at the
same rank of operand a 1x2x4 answers `-1x2x4`, `-1x-1x2x4` and `-1x-1` where its own extents and its own rank
say `1x2x4` and `2x4`. No rule over the operand's rank, the fed tensor's own shape and the two ranks reproduces
all seven, and the release's own answer there describes neither the operand nor the broadcast. So the port
carries the operand's own shape, which is the release's answer in **two** of the seven, and the row of the
broadcast names the five it is not, with this measurement.

### The refusals, each measured, each with the release's own words

* **A squeeze of an axis whose extent is not one.** The release writes `squeezed axis must have length 1,
  input.shape[1] == 2` (MPSGraphUtilities.mm:3210) and then `LLVM ERROR: Failed to infer result type(s)`
  takes the process down. The port raises `NSInvalidArgumentException` when the graph is built.
* **A flatten's axis is not normalised the way the family's other axes are.** The release takes it as the
  unsigned number it is given, so `axis:-1` of a 2x4 is a dimension length of 4294967295 and it asserts
  (`Error: NDArray dimension length > INT_MAX`, MPSNDArray.mm:831). Measured and different from the same
  operation's siblings: an expanded dimension and a transpose both count a negative axis from the end and
  answer. The port raises for the flatten and counts for the other two, which is the release's own split.
* **A reverse of an axis outside the rank**: the release's own compiler writes `invalid axis: 5, axis must be
  in range - rank <= axis < rank, rank = 2` and then the process is gone. The port raises
  `NSInvalidArgumentException` when the graph is built.
* **A permutation that is not a permutation of the operand's axes**: `perm tensor length must equal input
  tensor rank, 1 != 3`, after which the process is gone. The port raises.
* **A transpose naming an axis outside the rank** is the one refusal the release does NOT make: it builds a
  tensor whose shape is nil and writes nothing at all
  (`probe-transpose-axis-outside.txt`: the shape line is `(null)` and the destination keeps the pattern it was
  filled with). The port raises, which is the named divergence every axis outside the rank in this library
  carries and the same one the reduction family raises.
* **An extent of zero** in a broadcast's shape is refused by the port; the release answers a tensor whose
  shape holds no elements and then takes the process down inside `MPSNDArray` ("device may not be nil",
  MPSNDArray.mm:759).

## The slice: an offset and a stride, and four shapes the release refuses

`sliceTensor:dimension:start:length:name:` and `sliceTensor:starts:ends:strides:name:`, both of 14.0 and both in
`MPSGraph14.m`. **Both are one gather with an OFFSET and a STRIDE** - the only thing the family adds to the
walk - and the header's two forms are the same walk, the simple one being a single axis with a stride of one
and an end of start + length. Compared in a process of their own (`gather_slice`): **9 cases, every cell and
every shape byte-identical to the release, `gather_slice checks=9 failures=0 recorded=0` over 44 cells**, the
red control differing from the release in 10 of the group's 21 case lines.

**The rules, each measured on this host's own MPSGraph:**

- **a negative start counts from the end of that axis**, as the header says: axis 1 of a 2x4 sliced from -2 for
  two answers (3, 4 | 7, 8).
- **the count of an axis is the SMALLER of what the range asks for and what the operand's own extent allows
  from the start.** A 2x4 sliced from 2 with an end of 9 answers a 2x2 and not a 2x7, and the start of 9 that
  does not fit at all is the release's own refusal below.
- **an axis the simple form does not name keeps the operand's own extent** (a start of zero, a stride of one
  and an end of that extent), which is why slicing axis 0 of a 2x4 answers a 1x4 and not a 1x1.
- **a negative stride walks the axis the other way round**: starts `@[@0, @3]`, ends `@[@2, @0]`, strides
  `@[@1, @-1]` over the 2x4 answers a 2x3 of (1, 2, 3 | 40, 30, 20).

**Four shapes the release refuses, each with its own words and each a question `refusals.m` asks in a process
of its own, with `refusals.txt` holding what it is measured to answer:**

* **a start past the end of the axis**: `'mps.slice' op failed: start value 9 does not fit dimension size (4)`,
  and the shape line is `(null)` before the process goes.
* **a length that runs past the end**: `length value 9 does not fit within the dimension size (4) with start
  value (2)`, likewise.
* **a stride of zero**: `'mps.strided_slice' op stride cannot be 0`.
* **a result of no elements**: this one the release does NOT refuse - it builds the tensor, the shape line
  prints `2x0` for a length of zero, and then `MPSNDArray` cannot make a buffer for it and asserts "device may
  not be nil" (MPSNDArray.mm:759), which takes the process down. The port raises
  `NSInvalidArgumentException` for all four where the graph is built, which is the named divergence every axis
  or extent the release refuses carries in this library.

## The slice family: the three masks, the gradient and the update

The ledger's other eleven slice rows, in four objects: 14.0's `MPSGraph14.m` (the masked slice and the two
gradients), 17.4's `MPSGraphTensorShapeOps174.m` (the two updates with the masks), 18.0's
`MPSGraphTensorShapeOps180.m` (the two updates without them) and 18.2's `MPSGraphTensorShapeOps182.m` (the two
fed slice forms and the two fed gradients). **One piece of arithmetic in three directions**: a start, an end
(or a size), a stride and a count per axis, and then

| direction | the result is | what is written | the walk |
| --- | --- | --- | --- |
| the slice | the region's own shape | the operand's elements at the region | the gather walk with an offset and a stride |
| the slice's **gradient** | the shape the forward pass's INPUT had | the gradient's elements at the region, the rest **written zeros** | a scatter |
| the slice's **update** | the data tensor's own shape | the data's own elements with the update written **over** the region | a copy and a scatter |

compared in a process of its own (`gather_slice_rest`): **24 cases, every cell and every shape byte-identical to
the release, `gather_slice_rest checks=24 failures=0 recorded=0` over 145 cells in 51 case lines**, with the red
control differing from the release in 24 of the 51, and **41 refusal questions** asked one process each in
`refusals.m`, of which fourteen are this family's.

### The three masks, each measured

Over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40), and every one of them in the differential:

* **A `startMask` bit means the start written down is NOT read, and the axis starts at ZERO.** A start of 5 and a
  start of -3 each answer what a start of 0 answers (both a 1x4 and a 2x4 respectively), so it is a replacement
  and not a clamp: a start of -3 that were clamped would start at 1 and answer one row, and it answers two.
* **An `endMask` bit means the end is not read either, and the axis runs to its own last element.** Measured: over
  axis 1 from a start of 1 it answers three elements - (2, 3, 4) and (20, 30, 40) - whether the written end is 0
  or -9. With a **negative stride** the masked end is the one *before* the axis begins, so the count reaches index
  0: an endMask over axis 1 with a stride of -1 from 3 answers four elements, (4, 3, 2, 1) and (40, 30, 20, 10).
  This is the one rule of the three where the masked value is *not* counted from the end of the axis, and it is
  why the two are two lines of code and not one.
* **A `squeezeMask` bit drops the axis from the RESULT's shape whatever its extent, and the elements are the
  mapped walk's own in order**, so a result of fewer axes holds the first of them. Measured: axis 0 of a 2x4 with
  its bit set answers a **rank of one** holding (1, 2, 3, 4); with two rows selected it answers the same rank of
  one over the same four values; axis 1 answers a rank of one holding (1, 10); and both bits together answer a
  **rank of zero** holding the first element. TensorFlow's own rule is narrower - the axis is dropped only where
  `startMask` or `endMask` names it as well - and the release does not carry that half: the axis goes whatever its
  extent and whatever else is masked with it. So the walk keeps the full shape of the mapped region as well as the
  result's own and copies the first of the one into the other.

### The gradient: the shape arrives as a tensor, and that is the whole difficulty

The header's words are "The shape of the forward pass input, that is the shape of the gradient output", and it
arrives as a **tensor**, so it is a shape the graph has to be told. There are exactly two ways to tell it:

* **A CONSTANT**, whose value is in the graph. The release then infers the result's type when the graph is built,
  and answers the gradient. Measured over a 2x4 of (1, 2, 3, 4 | 5, 6, 7, 8): the whole slice answers the
  gradient; a 1x3 gradient of row 0 answers (-1, -2, -3, 0 | 0, 0, 0, 0); a 1x2 gradient of columns 1 and 2
  answers (0, -1, -2, 0 | 0, 0, 0, 0); and **over a destination filled with the byte `0xbd` the zeros are
  written and not left**, which is what makes this a scatter over a zeroed result and not a copy of the region.
  This is the form the differential compares, and it is why the cases build the shape with
  `constantWithData:shape:dataType:`.
* **A FEED**, which is data. The release's own result tensor then carries **no shape at all**, before the run and
  after it, and the process writes the gradient's element 0 into the destination's element 0 and nothing else -
  measured over five shapes of the destination (2x4, 1, 8, 2x2, 2x4x1) and five of the forward input, all of
  them one element (`refusals.m`'s `slice-gradient-fed-shape` and `slice-gradient-fed`, both answering
  `result-shape nil`). **The port reads that shape when the graph runs and answers this gradient**, which is the
  header's own words; each of the four gradient rows names the divergence with this measurement.

Three gradients the release will not build, each in `refusals.m` and refused by the port where the graph is
built: a **`squeezeMask`** (alone and with the mask it pairs with) and a **stride above one**, both refused by
the release's own compiler ("Optimize Original Module MLIR pass manager failed"), and a **gradient whose shape is
not the region's**, which the release refuses in its own words and which is the check the port makes at build
time: *"'mps.strided_slice_gradient' op `grad_input`[0] = 1 should match dimension size: 2 deduced from
`fwd_shape`"*.

### The update: a copy, and then a scatter

Measured over a 2x4 of (100, 200, 300, 400 | 500, 600, 700, 800):

* **The update REPLACES and does not add.** A region of row 0, columns 1 and 2 updated with (-1, -2) answers
  (100, -1, -2, 400 | 500, 600, 700, 800): the data is byte for byte what it was everywhere else.
* **A negative stride writes the update's elements along the region's own order.** A region that walks axis 1
  from 3 with a stride of -1 and an update of (-1, -2, -3, -4) answers (100, 200, -2, -1 | 500, 600, -4, -3): the
  update's first element goes to index 3 and its second to index 2.
* **The update's shape must BE the region's.** One wider (a 2x4 update into a 1x2 region) is refused by the
  release's own NDArray (`MPSNDArray, initWithBufferImpl:offset:descriptor:isForNDArray...`) and one narrower
  (a 1x1 update into a 1x2 region) by its compiler; the port refuses both where the graph is built.
* **An `endMask` and a `squeezeMask` are refused on an update**, measured over three shapes of the update and
  three masks each, the same compiler's words. The port answers them; the rows name the divergence.

### The one fed parameter the release answers, and why

**The fed forms of the update (17.4 and 18.0) are the fed parameters this family answers**, measured with the
starts, the ends and the strides fed as int32 of shape `[2]` and the answer the written-down form's answer byte
for byte (`refusals.m`'s `slice-update-fed-answer`, which holds the line). The reason is the family rule the
whole page keeps coming back to:

> **A fed parameter the result's SHAPE depends on is a parameter the release cannot build a graph over.**

The update's result is the *data* tensor's shape, which the graph knows when the graph is built, so its index
parameters can be data. The slice's fed forms of 18.2 take their result's shape out of the fed starts and ends,
and they die: measured, an int32 of shape `[2]`, an int32 of shape `[1]`, an int64 of shape `[2]` and the size
form each print a result shape of **`-1x-1`** - the release's own way of saying it could not resolve the shape it
was given, the same `-1x-1` the reshape's two dynamic extents print - and then the process goes, with SIGSEGV
into a 2x4 destination and `NDArray dimension length > INT_MAX` (MPSNDArray.mm:759, exit 134) into a destination
of one element. A float32 of shape `[2]` prints the same `-1x-1`. **The port answers the header**: the fed
values are read when the graph runs, which is the only time a fed value is there to read. That is the same
ruling as the reduction axis and the five fed gathers, and each of the four 18.2 rows carries its own
measurement.

## The reshape: two rows, and the flat index

`reshapeTensor:withShape:name:` (14.0, in `MPSGraph14.m`) and `reshapeTensor:withShapeTensor:name:` (15.0, in
`MPSGraphTensorShapeOps150.m`). Both are one gather with the axes left alone and the result's shape the
caller's, and both are compared in a process of their own (`gather_reshape`): **11 cases, every cell and
every shape byte-identical to the release, `gather_reshape checks=11 failures=0 recorded=0` over 160 cells**,
with the red control differing from the release in 12 of the 25 case lines of that group.

**The answer is the flat index and not a mapping of axes.** Both shapes are row-major and the volumes match,
which is all the header asks for, so the result's element at a flat index is the operand's element at the same
flat index - measured: a 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40) answers those eight values over a 4x2, over a 2x4
and over a 1x8 alike, and NOT the transpose a 4x2 could be read as, and a 2x3x4 answers its own twenty-four in
order over a 6x4, over itself and over a 24x1. This is why the walk takes a flat mapping for this operation and
not the per-axis one every other gather uses: a 2x4 into a 4x2 puts one axis of the result across HALF of an
axis of the operand, which no per-axis mapping can say.

**A dynamic extent is the header's -1 and is resolved against the element count.** Measured: a 2x4 into
`@[@4, -1]` answers a 4x2, into `@[@-1, @4]` a 2x4, and into a shape of `@[@-1]` alone a shape of `8` - a rank
of one, which prints without an `x`.

**Three shapes the release refuses, each with its own words, each asked in a process of its own by
`refusals.m` and held in `refusals.txt`:**

* **A volume that does not match.** The release builds the tensor the caller asked for - the shape line prints
  `1x7` for a 2x4 into a 1x7 - and its own compiler refuses it: `'mps.reshape' op the result shape is not
  compatible with the input shape` (MPSGraphUtilities.mm:310), and the process is gone. The port raises
  `NSInvalidArgumentException` where the graph is built, which is the named divergence the family's other
  refusals carry.
* **Two dynamic extents**, which the header's own words rule out ("allowed to contain dynamic dimensions (-1)
  when the result type can be inferred unambiguously"). The release does not resolve them either: the shape
  line prints `-1x-1` and `MPSNDArray` then asserts "NDArray dimension length > INT_MAX" (MPSNDArray.mm:831)
  and takes the process down. The port refuses it where the graph is built.
* **The fed form.** Asked in a process of its own the process dies with SIGSEGV and writes nothing (exit 139),
  so there is no answer of the release for a case to compare against and the port's answer is its header's -
  the same named divergence the family's other five fed forms carry. An int32 and an int64 of shape [1] both
  answer on the port; a floating point shape is refused where the graph is built, because the release cannot
  build the graph over one at all.

## The cumulative family of 16.0

Sixteen rows in one object (`MPSGraphCumulativeOps160.m`): `cumulativeSum`, `cumulativeProduct`,
`cumulativeMaximum` and `cumulativeMinimum`, each in four forms - an axis written down with and without the
`exclusive:` and `reverse:` flags, and an axis fed at run time with and without them.

**The walk is the reduction family's fold along an axis**, and it shares the fold table and the step with
it: `RevenantMPSGraphFoldStep` is one function both walks call, so the seeds, the NaN rule and the four steps
are measured once. What the scan adds is a direction, an axis and a flag, all three read out of the
operation's parameters (`@scanCombination`, `@scanAxis`/`@scanAxisTensor`, `@scanExclusive`, `@scanReverse`),
so the 16.0 object names its sixteen methods and nothing of any other release.

### The rule, and what is measured

The accumulator is the result buffer and starts at the fold's seed, the walk goes along the axis in the
direction the flag says, and at each position the element joins the answer BEFORE that answer is written -
unless the answer is `exclusive`, which writes it first and folds the element in afterwards, so the position
the walk starts at holds the seed.

Over the case file's 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40), axis 1, every one of these byte-identical between
the release and the port in float32, int32 and float16:

| operation | inclusive | reverse | exclusive reverse |
| --- | --- | --- | --- |
| `cumulativeSum` | (1, 3, 6, 10 \| 10, 30, 60, 100) | (10, 9, 7, 4 \| 100, 90, 70, 40) | (9, 7, 4, 0 \| 90, 70, 40, 0) |
| `cumulativeProduct` | (1, 2, 6, 24 \| 10, 200, 6000, 240000) | (24, 24, 12, 4 \| 240000, 24000, 1200, 40) | (24, 12, 4, 1 \| 24000, 1200, 40, 1) |
| `cumulativeMaximum` | (1, 2, 3, 4 \| 10, 20, 30, 40) | (4, 4, 4, 4 \| 40, 40, 40, 40) | (4, 4, 4, -inf \| 40, 40, 40, -inf) |
| `cumulativeMinimum` | (1, 1, 1, 1 \| 10, 10, 10, 10) | (1, 2, 3, 4 \| 10, 20, 30, 40) | (2, 3, 4, +inf \| 20, 30, 40, +inf) |

(the exclusive columns' seeds are the type's extreme finite value, which is the next table, and the reverse
minimum and maximum over an increasing row are each the row itself read from the other end).

**The seed of the two extremes is the type's own extreme FINITE value, not an infinity.** Measured over one
exclusive scan of each, in each of the three data types the family is asked in:

| type | the maximum's seed | the minimum's seed |
| --- | --- | --- |
| `MPSDataTypeFloat32` | `ff7fffff` = -FLT_MAX | `7f7fffff` = +FLT_MAX |
| `MPSDataTypeFloat16` | `fbff` = -65504, the largest finite half | `7bff` = +65504 |
| `MPSDataTypeInt32` | -2147483648 | 2147483647 |

which is the identity of a comparison over the values that type can hold. The reduction family of 14.0 seeds
an **infinity** instead - measured, `reductionMaximumWithTensor:axis:1` over a row of nothing but NaNs
answers `0xff800000` - and that is a different kernel with a different measurement, and it is left as it is.
A sum's seed is the zero of the type and a product's its one, in every type measured.

**A scan's comparison is not strict where a reduction's is**, and that is measured rather than guessed: over
the sixteen classes, whose first row is (1, -1, -0.0, +0.0), a *reverse* cumulative maximum answers a NEGATIVE
zero at positions 1 and 2 where a strict comparison keeps the zero it already held, and an exclusive reverse
maximum answers a negative zero at positions 0 and 1 where a strict comparison would take the positive one it
was handed. So `RevenantMPSGraphFoldStep` takes both rules as arguments: the two reductions pass
"propagate a NaN, break a tie towards the held answer" and a scan passes "skip a NaN, break a tie towards the
new value", and the reduction family's own cases (a row of (0, -0, 0, -0) answers 0, the first of the equal
elements) are what pin its half of that.

**A NaN is skipped in a scan, as in a reduction**: over a row of (1, 2, 3, NaN) an exclusive reverse maximum
answers (3, 3, -FLT_MAX, -FLT_MAX) and an exclusive reverse minimum (2, 3, +FLT_MAX, +FLT_MAX), and over a row
of nothing but NaNs both answer the seed at every position. Nothing in this family latches a NaN - the two
propagating reductions of 14.0 are the only two that do, and they are in a different object.

**The other three questions the family asks.** A negative axis is counted from the end, measured (`axis:-1`
answers what `axis:1` answers). The result is the operand's own shape and data type, measured in all three
types - which is why this family needs no case helper of its own, unlike the reduction family whose result is
a different shape. And the accumulator is the result's own storage: measured, the cumulative sum of
(1, 2, 3, 4) in float16 is `4900` = 10, and the cumulative product of four halves of 65504 is an infinity from
the second step.

### The two refusals, both named in the row of every method

* **An axis outside the rank.** The release asserts and dies: `MPSGraphNDArrayScan.mm:253` writes
  `Axis = ... This class only supports axis = 0, 1, 2, 3` and takes the process with it. The port raises
  `NSInvalidArgumentException` - when the axis is written down, when the graph is built; when it is fed, when
  the graph runs, because then it is data and there is nothing earlier to refuse.
* **An axis fed as a floating point tensor.** The release cannot build the graph at all: its own compiler
  refuses the operand (`'mps.cumulative_sum' op operand #1 must be 0D tensor of mps index type values or
  static-shape defined tensor with shape equal to [1] ... but got 'tensor<1xf32>'`) and the process goes down
  with `failed assertion`, `MPSGraphExecutable.mm:4419`. The port raises `NSInvalidArgumentException` when the
  graph is built. An int32 and an int64 axis of shape [1] both answer, measured.

Neither is in the differential, and that is deliberate in both cases: the release's own answer is a process
that is gone, so there is nothing to compare a line against. Both are measurements in the rows instead.

## Pad and tile: the gather walk with two more rules

Four of the rows of the ledger's pad and tile pair, in `MPSGraph14.m` where 14.0 put them, compared in a
process of their own (`gather_padtile`): **75 cases, every cell and every shape byte-identical to the release,
`gather_padtile checks=36 failures=0 recorded=0` over 1128 cells in 75 case lines**, the red control differing
from the release in 33 of them, and fourteen refusal questions of their own.

* **A TILE is the gather walk with every axis REPEATED**: the result's axis k is the operand's axis k at
  `multiplier[k]` times its extent, and the coordinate of the result counts the operand's own extent over again.
  Measured over the 2x4 of (1, 2, 3, 4 | 10, 20, 30, 40): a multiplier of `(2, 3)` answers a `4x12` holding the
  operand three times over twice down, `(1, 3)` a `2x12` three times across, `(2, 1)` twice down, a multiplier of
  one the operand itself byte for byte, and `(2, 2, 2)` over a `2x3x4` the `4x6x8` of 192 elements - and **a pad
  of a rank of three answers as well**, which the two entries above used to deny.
* **A PAD is the walk with an offset per axis and the space outside the operand filled by the mode**, and every
  element of the result is written: the inside from the operand at the coordinate less that axis's left padding,
  and the outside by the mode. Every element matters because **a fresh `MTLBuffer` holds no answer at all** - an
  element the walk leaves alone is whatever the allocator gave it, which is how the first version of this fill
  answered the two constant modes with zeros that were not the release's zeros.
* **The pad's GRADIENT** is the same scatter the slice's is, with the left padding as its offset: the incoming
  gradient is of the **padded** shape and the region sits that axis's left padding into it, so the destination's
  coordinate is the incoming gradient's *less* that. Measured over an incoming gradient of (1 ... 24) and a
  padding of (1, 2) at the left and (1, 0) at the right of a 2x4: the release answers
  **9, 10, 11, 12 | 15, 16, 17, 18**, which is the incoming gradient's own rows 1 and 2, columns 2 to 5. The
  padding mode is not read - a gradient of a pad does not depend on what the padding was filled with - and the
  differential asks the zero mode beside the constant one to say so.

### The five modes the release answers, and the two it does not

| mode | what an element outside the operand is | measured (one at each end of axis 1) |
| --- | --- | --- |
| `MPSGraphPaddingModeConstant` | the caller's `constantValue`, written in the **result's** own type | 99 over a float32 2x4 |
| `MPSGraphPaddingModeZero` | zero | - |
| `MPSGraphPaddingModeClampToEdge` | the nearest element of the axis | `1, 1, 1, 2, 3, 4` |
| `MPSGraphPaddingModeReflect` | the mirror **across the edge** - index -1 is index +1 | `2, 1, 2, 3, 4, 3` |
| `MPSGraphPaddingModeSymmetric` | the mirror that **does repeat** the edge - index -1 is index 0 | `1, 1, 2, 3, 4, 4` |

Each axis is chosen on its own, because a pad is applied to every axis at once: an element outside the operand's
box on any axis is filled from the mirrored or clamped coordinate of *every* axis. The two mirrors are the pair
that is easy to get wrong - the reflect is neither the mirror about the last element (which answers
`3, 1, 2, 3, 4, 3`) nor one that repeats the edge (which answers `1, 1, 2, 3, 4, 4` and is the symmetric's).

**Two of the seven modes the release refuses**, with its own words, *after* it has built the result tensor:
`MPSGraphPaddingModePeriodic` and `MPSGraphPaddingModeAntiPeriodic` - "Unsupported paddingMode", exit 134. Both
are raised where the graph is built.

### The two mirrors' own reach, which is not one number for both

Measured on this host's own MPSGraph at extents 1, 2 and 3, on the left and on the right, over every padding
from 1 to 5. A `REFLECT` answers up to the axis **less one** and a `SYMMETRIC` up to the axis **itself**, and
one element more of either is refused by the release's compiler with its own words:

```
'mps.pad' op padding values too large at axis 0, max padding is 1, got 3      (MPSGraphUtilities.mm:956)
```

where the maximum it prints is 0 for a reflect on an axis of one, 1 for a reflect on an axis of two **and 2 for
a symmetric on that same axis** - which is the whole of the difference between the two limits. The port refused
`before >= extent` for both, so it refused a symmetric pad the release answers; that is what
`MPSGraphInterpreter14.m`'s pad branch carries now, as `reach = mode == 1 ? extent - 1 : extent`. The cases
that show it are `pad-symmetric-boundary`, `pad-symmetric-boundary-both`, `pad-symmetric-thin`,
`pad-symmetric-thin-rank3` and `pad-symmetric-thin-axis1`, and the two limits are `refusals.txt`'s
`pad-thin-reflect` (max 0, got 1) and `pad-thin-symmetric` (max 1, got 2). `pad-reflect-past-extent` stays as
the reach of the reflect one element short of the old rule, which is still what the release does.

### An axis shorter than the result by more than its own extent

Nothing above reached it, and it is the shape the tile gradient's own shifts ask for - a window of five over a
leading block of four pads a row of **one** back out to four. Measured on this host's own MPSGraph, a `1x4` of
`(1, 2, 3, 4)` padded by three at the left answers, for the modes that answer:

| mode | result | answer |
| --- | --- | --- |
| `Zero` | `4x4` | `0, 0, 0, 0 \| 0, 0, 0, 0 \| 0, 0, 0, 0 \| 1, 2, 3, 4` |
| `Constant` (99) | `4x4` | `99 x 12 \| 1, 2, 3, 4` |
| `ClampToEdge` | `4x4` | `1, 2, 3, 4` four times over |

So the operand's row lands at the row the offset puts it in and the space at the front holds the mode's own
value - **and the zero mode does not write it anywhere else**. That is the question a pass before this one
localised the tile gradient's failure to, and it does not hold: over the seven thin-axis cases of the family
(`pad-thin-zero`, `pad-thin-constant`, `pad-thin-clamp`, `pad-thin-right-zero`, `pad-thin-rank3-zero`,
`pad-thin-rank3-clamp`, `pad-thin-rank3-axis1-zero`) the port and the release were already byte-identical before
any change here, and still are. Padded on the **right** the operand's row lands at the first row and the three
at the back hold, which is the same walk read from the other end; a rank of three of the same shape answers too,
over the leading axis and over the axis just below it, so the fill is chosen on every axis at once.

### A pad of a rank of THREE answers, and the entry that said otherwise was this repository's own question

`refusals.m` held `pad-rank3-clamp` and `pad-rank3-symmetric` as refusals of a rank of three, both exiting 134
with "Invalid KernelDAG, equalShape for destination failed". **That measurement was of the wrong shape and the
refusal was of the destination, not of the pad**: the branch builds its destination with the OPERAND's shape and
the OPERAND's bytes, and a `2x3x4` padded by one at each end of every axis is a `4x5x6` - 480 bytes into 96.
Asked into a destination of the RESULT's shape the same pad answers in every mode, and `pad-rank3-clamp` and
`pad-rank3-symmetric` are now cases in `graph-cases.m` (the clamp and the symmetric answer the same bytes
there, because one element of padding on an axis of two or more is where the two mirrors and the clamp agree).
What the narrower destination really does is per mode and per rank, and is what the three entries now say:
`pad-destination-narrower-rank3-clamp` is refused by the release's multiary kernel
(`MPSNDArrayMultiaryKernel.mm:2475`), `pad-destination-narrower-rank3-constant` writes what fits and exits 0,
and `pad-destination-narrower-rank2` - a `4x6` into a `2x4`'s 32 bytes - writes what fits and exits 0 too.

### The tile's gradient: the rule is measured now, and the port does not reproduce it yet

`-[MPSGraph tileGradientWithIncomingGradientTensor:sourceTensor:withMultiplier:name:]` stays `missing`, and the
two passes before this one left a measurement in this page that **was wrong and is corrected here**. What they
recorded - "over an incoming gradient of ones the release answers the PRODUCT of the multiplier, 6 for (2, 3),
3 for (1, 3) and 9 for (3, 3)" - does not reproduce. Measured over a 2x4 source with a gradient of ones, the
release answers **1** for `(1, 1)`, `(2, 1)`, `(3, 1)` and `(4, 1)`, and **2** for `(1, 2)`, `(1, 3)`, `(2, 3)`
and `(3, 3)`: three multipliers with three different products and one answer. Over a 8x8x4 source it answers
**1** for `(2, 1, 1)`, `(3, 1, 1)` and `(5, 1, 1)`, **3** for `(1, 3, 1)`, **5** for `(1, 5, 1)`, **2** for
`(1, 1, 2)`, **4** for `(2, 2, 2)` and **9** for `(3, 3, 3)`. The rule behind those numbers is measured and is
below; the port does not reproduce it yet, and the row is not carried.

**What the operands may be, both refusals measured with the release's own words.**

* **The incoming gradient must be of the SOURCE'S OWN SHAPE, and the result is that shape too.** A gradient
  of the tiled result's shape is refused where the graph runs: "Incompatible shape for parameter at index 0"
  (MPSGraphExecutable.mm:4500). So is one of the same element count in another arrangement - measured, a 2x4
  source refuses an 8x1 and a 1x8 gradient with the same words. The result tensor is built before that and
  prints the source's shape.
* **The multiplier's length must be the rank.** The release's own compiler says "'mps.tile_gradient' op
  `input` rank: 2 should match `multiplier` length: 3" (MPSGraphUtilities.mm:1258) and the process goes with
  "Optimize Original Module MLIR pass manager failed".

**The rule, over the incoming gradient held as the source's own shape.** For a source of rank R with shape
`(s0 ... sR-1)` and a multiplier `m` of length R:

* **`m[0]` is not read at all.** Every multiplier whose leading entry is above one and whose remaining entries
  are all one answers the incoming gradient unchanged - measured over a 2x4 and over a 8x8x4, above. A
  multiplier of `(2, 1)` is the identity where the sum of the copies would answer it twice.
* **`m[j + 1]` is a WINDOW of `m[j + 1]` terms along axis j**, each term weighted **one**, at **axis j's own
  stride** (the product of the extents after it). A term whose coordinate leaves the axis is **dropped and not
  clamped**: measured over a gradient of ones and a 4x4 source, `(1, 3)` answers **3, 3, 2, 1** down the four
  rows - three terms, then two, then one - and `(1, 5)` answers **4, 3, 2, 1**, which is the same window of five
  with an axis of four cutting it short.
* **The windows compose**, so two axes give the sum over the PRODUCT of the windows and not the sum of two
  separate sums. Measured over a gradient of `(1 ... 32)` and a **4x4x2** source with a multiplier of
  `(3, 3, 3)`, the release answers **99, 108, 117, 126 | 135, 144, 153, 162 | 171, 180, 189, 198 | 174, 182,
  157, 164 | 138, 144, 150, 156 | 129, 134, 106, 110 | 81, 84, 87, 90 | 60, 62, 31, 32**, which is element for
  element the sum of the 3x3 window of the leading 4x4 block around each of the first eight and around each of
  the rest - and the sum of two separate windows would answer 5 terms where this answers 6.
* **A multiplier of zero answers zeros** (a 2x4 source, a multiplier of `(0, 2)`, a gradient of `(1 ... 8)`:
  eight zeros).

Three whole cases the rule predicts and the release answers, each in the differential's own terms:

| source | multiplier | gradient | the release answers |
| --- | --- | --- | --- |
| 2x4 | `(1, 1)` | 1 ... 8 | `1, 2, 3, 4, 5, 6, 7, 8` |
| 2x4 | `(4, 1)` | 1 ... 8 | `1, 2, 3, 4, 5, 6, 7, 8` |
| 2x4 | `(1, 3)` | 1 ... 8 | `6, 8, 10, 12, 5, 6, 7, 8` |
| 3x3 | `(1, 2)` | 1 ... 9 | `5, 7, 9, 11, 13, 15, 7, 8, 9` |
| 4x4 | `(1, 5)` | 1 ... 16 | `28, 30, 32, 34, 35, 37, 39, 41, 38, 40, 42, 44, 42, 44, 46, 48` |
| 2x3x4 | `(1, 3, 1)` | 1 ... 24 | `14, 16, 18, 20 | 22, 24, 26, 28 | 30, 32, 34, 36 | 13, 14, 15, 16 | 17, 18, 19, 20 | 21, 22, 23, 24` |
| 2x3x4 | `(1, 1, 3)` | 1 ... 24 | `15, 18, 21, 24 | 27, 30, 33, 36 | 39, 42, 45, 48 | 51, 54, 57, 60 | 38, 40, 42, 44 | 21, 22, 23, 24` |

### Why the row is `implemented`, and what it is not measured against

The port implements the rule above over the seam the family already has: the incoming gradient plus one term
per shift of every axis below the last, each term a slice of the INCOMING GRADIENT from `shift` to the end of
that axis at that axis's own stride, put back at the front with a `MPSGraphPaddingModeZero` pad. The pad is
what makes the dropped terms zeros - a gather's result coordinate with no element of the operand behind it is
not written at all, and the result's bytes are a fresh buffer's, so a term that is not padded would carry
whatever the allocator left. Each axis's window is taken of the incoming gradient and not of the running sum,
which is the composition the measurement shows, and a shift past the axis ends the window.

**The release reads past the end of the caller's gradient buffer for every multiplier that is not all ones,
the leading entry included, so those multipliers cannot be compared.** Measured with a sentinel planted
immediately after the operand's own elements in the same buffer:

| question | the gradient of (1 ... 16) over a 4x4 | the last row of the answer |
| --- | --- | --- |
| `tilegrad-1x2` - 1000 and up planted after the operand | `6, 8, 10, 12 \| 14, 16, 18, 20 \| 22, 24, 26, 28` | `13, 15, 17, 19` |
| `tilegrad-1x2-zero` - zeros planted after the operand | `6, 8, 10, 12 \| 14, 16, 18, 20 \| 22, 24, 26, 28` | `13, 14, 15, 16` |
| `tilegrad-1x1` - a multiplier of all ones | `1, 2, 3, 4 \| 5, 6, 7, 8 \| 9, 10, 11, 12 \| 13, 14, 15, 16` | `13, 14, 15, 16` |

The same graph, the same values, the same shape, and a last row that is a function of the bytes planted after
the operand: `13, 15, 17, 19` is the gradient's own last row plus the first four planted floats, and
`13, 14, 15, 16` is the gradient's own last row plus four zeros. It holds for the leading entry as well -
measured, a multiplier of `(4)` over a `4` answers `30, 32, 34, 36` and a multiplier of `(4, 1)` over a `4x4`
answers `18, 20, 22, 24 | 26, 28, 30, 32`, which is the gradient read at an offset that is not a window of it.
So:

* **the port's answer is the defined one** - the window with what ran off the end of the axis dropped - and no
  port reproduces a read of memory it does not own. This is a divergence from the release and the row says so
  with the measurement beside it;
* **the differential compares what can be compared**: the four multipliers whose answer is a function of the
  graph, all ones at rank of two and of one and a zero in either position. A window is not a case;
* `refusals.txt` holds the six `tilegrad-` questions that measure the windows over a planted sentinel, so the
  rule is recorded by a run a later reader repeats rather than by a line of prose here.

Two refusals the port makes where the release's answer is its heap are raised where the graph is built rather
than where it runs, and the row says so: a leading multiplier above the leading extent, and a negative entry.

## The run, async and encode forms, and the two shared events

Thirteen rows, and they are all **one walk** - the graph's own over its operations - because a port whose
operations are a walk has nothing to compile ahead of time, and the difference the release makes between the
synchronous, the async and the encode forms is what it does with the GPU afterwards. Compared in a process of
its own (`run_forms`): **23 case lines, every cell byte-identical to the release,
`run_forms checks=11 failures=0 recorded=0` over 88 cells**, the red control differing in 7 of the 23.

### The two shapes of answer, all of them compared now

| form | where the answer goes | measured over a 2x4 added to itself |
| --- | --- | --- |
| the form that **returns a dictionary** (`runWithMTLCommandQueue:...targetTensors:`, `runAsyncWithFeeds:...`, `runAsyncWithMTLCommandQueue:...targetTensors:...`, `encodeToCommandBuffer:...targetTensors:...`) | the release's **own** tensor data | one entry, the returned object is **not** the one the caller passed, and the caller's buffer still holds the byte `0xbd` it was filled with |
| the form that takes a **results dictionary** (`runWithMTLCommandQueue:...resultsDictionary:` and its async and encode twins) | into the data the caller put in it | `(2, 4, 6, 8 \| 20, 40, 60, 80)` in the caller's own buffer, byte for byte |

The dictionary form names no target tensors of its own, so **the dictionary's keys are what the walk computes**
- a caller who passes an empty dictionary gets an empty walk.

### What is compared, and the one thing that is not

**All three async forms ARE compared cell for cell.** Each is asked with its descriptor's own
`waitUntilCompleted` set, which is the header's own way of saying the call returns after the work is done, so
the answer is in the caller's dictionary when the call returns and the case reads it there. The previous pass of
this section said the host could not be asked at all, because a queue has no `-waitUntilCompleted`; that was
**the harness asking the wrong object** - the method is of the command buffer - and the coordinator's correction
is right. The descriptor's `completionHandler` and `scheduledHandler` are honoured around the walk on both
sides, each called with the results and a nil error.

**All three encode forms ARE compared cell for cell too, and this page's previous two passes said they could not
- both times for the wrong reason.** What is measured:

* **Where the buffer comes from.** `+[MPSCommandBuffer commandBufferFromCommandQueue:]` in
  `MetalPerformanceShaders.framework/Frameworks/MPSCore.framework/Headers/MPSCommandBuffer.h`, **inside the
  MetalPerformanceShaders umbrella** and in no MetalPerformanceShadersGraph header. The class is declared
  `@interface MPSCommandBuffer : NSObject <MTLCommandBuffer>`, so `-commit` and `-waitUntilCompleted` are its
  own methods and **the wait is on the buffer**, not on the queue: encode, `[buffer commit]`,
  `[buffer waitUntilCompleted]`, and then the caller's own buffer is read.
* **What the release answers.** The graph's results-dictionary form writes `(2, 4, 6, 8 | 20, 40, 60, 80)`
  into the destination the caller allocated - the same bytes the synchronous and the async dictionary forms
  answer over the same graph, and the port answers them too. The graph's returning form answers one entry, the
  release's own tensor data, and leaves the caller's buffer holding the `0xbd` it was filled with, which is the
  shape of answer the two other returning forms give. The executable's form writes the same bytes into the
  `resultsArray` the caller passed. The planted build answers `00004040` where the release and the port answer
  `00000040`, so the two byte-comparing cases are checked and not merely equal.
* **Why the earlier passes said otherwise, and both of the reasons were wrong.** A bare `alloc` raising
  `-[MPSCommandBuffer device]: unrecognized selector` measures **`-init`**, which that header marks
  `NS_UNAVAILABLE` and says to replace with `-initWithCommandBuffer:`; it says nothing about the factory.
  Measured on this host: the class is `MPSCommandBuffer`, the factory answers one, and it answers
  `-waitUntilCompleted` - on the object itself and on its `-rootCommandBuffer` alike. And "the harness imported
  only MetalPerformanceShadersGraph, so the declaration was never in view" is wrong twice over: the declaration
  is reachable from the graph umbrella as well, because `MetalPerformanceShadersGraph.h` imports `MPSGraph.h`,
  which imports `MPSGraphCore.h`, which imports `MetalPerformanceShaders.h`, which imports
  `MPSCore/MPSCore.h` - a file importing nothing but the graph umbrella compiles the call and links it against
  `MetalPerformanceShaders`, both measured. `graph-cases.m` now imports `MetalPerformanceShaders` for the class
  so the dependency is stated rather than transitive.

**The one thing that cannot be done here is waiting on a COMMAND QUEUE**, and that is not a limit on any of the
forms: asking a queue for `-waitUntilCompleted` raises
`-[AGGX16XFamilyCommandQueue waitUntilCompleted]: unrecognized selector`. That is why no case in this family
waits on a queue - the descriptor's own `waitUntilCompleted` and the command buffer's own
`-waitUntilCompleted` are what the cases use.

### The two shared events, measured

Both `MPSGraphExecutionDescriptor` and `MPSGraphExecutableExecutionDescriptor` declare
`-waitForEvent:value:` and `-signalEvent:atExecutionEvent:value:`, so both hold them. Measured on this host: a
fresh `id<MTLSharedEvent>`'s own `signaledValue` is **0**, and naming it in either descriptor does not change it -
so the only thing a run can do with one is to write it at the stage the caller named, and the one stage the
header names is `MPSGraphExecutionStageCompleted` (0). In the differential an event a run signals at that stage
reads **42** afterwards and **0** before, on both sides; the walk is the release's own and the result is byte for
byte.

A **wait** is checked and a run whose event has not reached the value the caller named is **refused**, naming the
event and the value, because this port's walk is on the CPU where there is no queue to block on - a refusal that
says so is an answer, and running early would be a silent wrong answer.

### What is not measured here

The rest of the shape family - `spaceToDepth`, `depthToSpace`, `spaceToBatch`, `batchToSpace`,
`nonZeroIndices`, the `gather*` and `scatter*` forms and the `topK`/`bottomK` pair - is not in this page and
not in the tree, and the tile's gradient is in the section above with its measurement there. `concat` and
`stack` have been in the tree since the section above was written and their measurement is there now, and so
are `split` and `coordinateAlongAxis`, whose measurement is in the section after that; this list is the rest
of the rows the ledger carried as `missing` for this family.

## The concat and stack family: the one walk whose result is SEVERAL operands

Four rows - the three concatenations MPSGraph arrived with in 14.0 and the stack of 15.4 - and they are the
first walk in this library that is **not** a gather of one operand. A gather maps each axis of the result to
an axis of THE operand; a concatenation maps a REGION of one axis of the result to each of the operands in
turn, and a stack maps one axis of the result - a new one, of extent as many operands - to which operand the
element came from. So the walk reads every input of the operation rather than the first, and the plan has one
thing the gather's has not: an offset and a length per operand along the axis named.

Measured on this host's own MPSGraph (macOS 27.0 build 26A428, M4 Pro, Metal 4), over the case file's 2x4 of
(1, 2, 3, 4 | 10, 20, 30, 40) beside one of (5, 6, 7, 8 | 50, 60, 70, 80) and one of
(9, 10, 11, 12 | 90, 100, 110, 120). Compared in a process of its own (`gather_concat`): **38 cases, every
cell byte-identical to the release, and the red control differing in 38 of the 81 case lines** - and `refusals.txt`
asks 63 questions, the eight of this family among them covering every shape the walk's arithmetic does not
bound. The red
control's count is unchanged by the two cases of an empty array, and that is right rather than a gap: those
two carry a shape and a data type and no stored element at all, so there is nothing in them for a plant that
shifts every stored element to move.

### The rule, which is one walk with one bit on it

| question | the release answers |
| --- | --- |
| end to end along an axis, two 2x4s | axis 0 is a 4x4 of the first 2x4 then the second; axis 1 is a 2x8 of their rows side by side |
| the same with three | axis 0 is a 6x4 of the three in the order written; axis 1 a 2x12 of their rows side by side |
| a negative axis | counted from the end: -2 answers what 0 answers and -1 what 1 answers |
| ONE operand | the identity: a 2x4 alone is a 2x4 of its own eight values |
| an extent of ONE **on** the axis laid along | not a broadcast but one element of the result: a 1x4 of (101, 102, 103, 104) laid along axis 0 beside a 2x4 is a 3x4 of (101, 102, 103, 104 \| 5, 6, 7, 8 \| 50, 60, 70, 80) |
| operands of DIFFERING LENGTH on the axis laid along | allowed, and the result is then neither of their lengths: a 2x4 beside a 2x1 laid along axis 1 is a 2x5 of (1, 2, 3, 4, 10 \| 20, 30, 40, 5, 6) |
| INTERLEAVED along an axis | operand i's coordinate c lands at the result's coordinate `i + c * (the number of operands)`, and the extent is the sum either way |
| INTERLEAVED with the operands of DIFFERENT length on that axis | **refused** - see below |
| stack at an axis | the result is of the operands' rank plus one and that axis is of extent as many operands: axis 1 of two 2x4s is a 2x2x4, axis 2 a 2x4x2 |
| a stack's negative axis | counted from the end of the RESULT's rank, one more than the operands': -3, -2, -1 answer what 0, 1, 2 answer |
| a stack of ONE operand | the operand itself with the new axis of extent one: a 1x2x4 of its own eight values |
| `interleave:NO` | exactly what the many-operand form answers, byte for byte |

The interleave measurement in full, because the header's own example covers one operand's worth and not the
rule: axis 1 of **two** is a 2x8 of (1, 5, 2, 6, 3, 7, 4, 8 | 10, 50, 20, 60, 30, 70, 40, 80); axis 1 of
**three** is a 2x12 of (1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12 | 10, 50, 90, 20, 60, 100, 30, 70, 110,
40, 80, 120); and axis 0 of three is a 6x4 whose rows are the operands' rows round again - row 0 the first
operand's row 0, row 1 the second's row 0, row 2 the third's row 0, row 3 the first's row 1 - which is the
same rule on the slowest-moving axis of the result, and is what says the rule is about the coordinate and not
about which axis of the result it happens to be.

### "Broadcast compatible" is not what the release takes

The header says of both (`MPSGraphTensorShapeOps.h`, `concatTensor:` and `stackTensors:`) that the inputs
"must be broadcast compatible along all other dimensions". **It is refused**, by its own compiler, with its
own words - `'mps.concat' op invalid input tensor shapes, all input shapes must match except at axis`
(MPSGraphUtilities.mm:748), after which the process goes down:

* a 1x4 beside a 2x4 with the concatenation on axis **1** is refused, because then the extent that differs is
  one the concatenation does not touch;
* two 2x4s beside a 1x4 stacked at axis **1** are refused, and so are a 1x4 and a 2x4 stacked at axis **0** -
  a stack has no extent to differ on, so *every* axis has to match.

An extent of one ON the axis laid along is therefore not a broadcast either, and that direction answers: it is
one element of the result, which is what `concat-thin-axis0` compares. So the header's sentence is loose in
both directions and the release's rule is the strict one; the port raises where the graph is built and the row
of each method says so.

### Interleaving is the one form that needs the operands to agree on the axis, and the release says so

The interleaved walk divides the result's coordinate by the number of operands, which lands inside the
operand it names **only if every operand is the same length on that axis**. The release enforces exactly
that, and says so in a sentence of its own which is neither of the two above:

    'mps.concat' op all input shapes must match along axis dimension when interleaving

(MPSGraphUtilities.mm:748), measured over the shape where the axis laid along is the only one whose extent
differs: a `2x4` beside a `2x1` on axis 1 is a `2x5` **end to end** - `concat-unequal-axis1`, which answers -
and is refused when they interleave, which is `refusals.txt`'s `concat-interleave-unequal`.

This is worth writing down because the port got it wrong first and a compiler warning is what said so. The
plan computed a per-operand `extents` list that nothing read, which is what `-Wunused-variable` names; the
list was the residue of the check that belongs there, and deleting the line instead of writing the check
would have left a documented public call - `concatTensors:dimension:interleave:` over operands of different
lengths, which is the very thing the header invites - reading past the end of the shorter operand's buffer,
because the division would have answered its elements 2, 3 and 4 where it holds two. The check is in the
plan rather than in the walk's per-element path, which is where the release has it too and where it costs
nothing: three orders of magnitude fewer comparisons for the same answer.

### And the last shape the walk's arithmetic does not bound: an operand of extent zero

Two operands laid along one axis, one of them **empty**. The offsets of the regions collapse - both start at
the same place - so a walk that lays them out by offset has nothing in the offsets to say which operand an
element belongs to. Measured on this host's own MPSGraph, with the zero first (the harder case):

    build:   shape 2x4, the other operand's length
    run:     failed assertion `[MPSNDArray initWithDevice:descriptor:isTextureBacked:] Error: device may not be nil'

So the release has **no answer at all** here rather than a refusal of its own: it builds the tensor and then
takes the process down inside its own array. The port refuses where the graph is built and the rows say so,
which is this library's standing arrangement for the shapes where the release's answer is an assertion and a
dead process - an axis outside the rank, a squeeze of an axis that is not of extent one, the eight other
questions in `refusals.txt`.

The ORDER of the two refusals on this axis is the release's, and it was measured rather than chosen: a `2x0`
beside a `2x4` **interleaved** is refused with the interleave sentence and not with this one, so the plan asks
that question first. That is why `concat-zero-extent` is a question of its own and not a variant of
`concat-interleave-unequal`.

A stack cannot reach either: its axis is a new one of extent as many operands, and an operand of extent zero
on some axis of its own is ordinary there.

### An axis outside the rank, and the two messages

Both are refused where the graph is BUILT, by the same compiler, with different words - because the release
builds a stack out of an **expanded dimension per operand** and then a concatenation, so for a stack the
expanded dimension is what names the axis first:

| question | the release's own words | where |
| --- | --- | --- |
| a concatenation at axis 2 of a rank of two | `invalid axis tensor: [2], axis must be in range -rank <= axis < rank, rank = 2` | MPSGraphUtilities.mm:748 |
| the interleave form at the same axis | the same sentence, byte for byte - so the flag changes nothing about what is refused | MPSGraphUtilities.mm:748 |
| a stack at axis 3 of two 2x4s | `invalid axis: 3, axis must be in range -\|rank\| <= axis < \|rank\|` | MPSGraphUtilities.mm:3237 |

and in every case `LLVM ERROR: Failed to infer result type(s):` follows and takes the process down. They are
`refusals.txt`'s `concat-axis-outside`, `concat-interleave-axis-outside` and `stack-axis-outside`.

### The header's other two sentences, and one of them is not the graph's to enforce

The header also says the operands "have the same type" and that the array is the operands themselves. Both
were measured, and they come out differently - one is the compiler's business and one is the graph's:

* **MIXED DATA TYPES are the release's COMPILER's refusal, not its graph's.** A float32 2x4 beside an int32
  2x4 concatenated on axis 1 builds a result tensor of shape 2x8 whose data type is **the first operand's**
  (0x10000020, float32), and only the compile refuses it, with `'mps.concat' op element type of operand and
  result differ` - the process survives and writes nothing. So the port, which takes the result's data type
  from the operands' own, agrees with the release about the tensor and has no graph-level check the release
  has; `refusals.txt`'s `concat-mixed-types` measures both halves.
* **AN EMPTY ARRAY builds a result tensor whose shape is nil**, and the process survives. Measured over the
  WHOLE path, because the first measurement here stopped at the build and the answer turns out to matter
  exactly where a build-time answer does not: `[MPSGraph concatTensors:@[] dimension:0]` and
  `[MPSGraph stackTensors:@[] axis:0]` build a result tensor of nil shape and **float32** (0x10000020),
  `compileWithDevice:feeds:@{} targetTensors:@[t]` returns an executable, and the run leaves the caller's
  destination exactly as it was. So the port builds the same tensor - no shape on it, no value in it - and the
  run's own copy-out finds nothing to copy, which leaves the destination as the caller had it. These are
  `graph-cases.m`'s `concat-empty` and `stack-empty`, which compare the shape and the data type on every run
  and are the only cases in the family with no result buffer.

  **This paragraph's earlier text said the port raised `NSInvalidArgumentException` here and called it a
  deliberate divergence from the release. That was wrong and is corrected.** The reasoning behind it - that a
  tensor of no shape is the one answer a caller cannot act on - is true of a *caller that wants an answer*, and
  irrelevant to the caller that merely has to keep running: an application written against the release builds
  this graph and takes no exception, so a port that raises takes down an application that works on the
  device. The rule this library follows is the release's own answer, and where the release has none to give
  (the eight refusal questions above, and the tile gradient's read past the end of the caller's buffer) the
  port refuses *and says so in the row*. Here the release has an answer and the port must have it too.

## The split and the coordinate along an axis: the walk that cuts regions OUT, and the walk with no operand

Seven rows and three seams of 15.4, and between them the two walks of this library that are neither a gather of
one operand nor an arithmetic over two. The **split** is the first operation here whose result is **several
tensors** - every other walk answers with one - so it is the first that needs an operation with an output
tensor of its own for each region and a run that fills every one of them. The **coordinate along an axis** is
the first walk with **no operand at all**: its value IS the coordinate, so what the caller hands it is a shape
and an axis and nothing else.

Measured on this host's own MPSGraph (macOS 27.0 build 26A428, M4 Pro, Metal 4). The answers the release gives
are compared cell for cell in a process of their own (`gather_split`): **37 cases, 362 cells, every cell
byte-identical to the release, `gather_split checks=67 failures=0 recorded=0`, and the red control differing
in 54 of the 107 case lines.** The refusals - sixteen of them, and most of what this family has - are in
`refusals.txt` with the release's own words.

### What a split is: the slice walk, once per region

A split's region i is the operand's own elements from the running total of the sizes before it to that total
plus its own size, along the axis named - so it is **the slice walk asked once per output**, with a region's
offset being the sum of the sizes before it, and nothing else in this family needed a walk of its own. Over a
2x4 of (1, 2, 3, 4 | 10, 20, 30, 40):

| question | the release answers |
| --- | --- |
| `@[@1, @3]` along axis 1 | a 2x1 of (1, 10) and a 2x3 of (2, 3, 4 \| 20, 30, 40) |
| `@[@3, @1]` along axis 1 | a 2x3 of (1, 2, 3 \| 10, 20, 30) and a 2x1 of (4 \| 40) - the regions are cut **in the order written** |
| `@[@1, @1]` along axis 0 | two 1x4s, (1, 2, 3, 4) and (10, 20, 30, 40) |
| a negative axis | counted from the end: -2 answers what 0 answers and -1 what 1 does |
| **one** size | the operand itself: `@[@4]` along axis 1 is the same 2x4, which is what the one-operand concatenation of 14.0 answers |
| a rank of **one** | `@[@1, @2]` along axis 0 of a `[3]` is a `[1]` and a `[2]` |
| a rank of three | `@[@1, @2]` along axis 1 of a 2x3x4 is a 2x1x4 and a 2x2x4; `@[@2, @1, @1]` along axis 2 is a 2x3x2 and two 2x3x1s |
| the data type | the **operand's own** in every case measured (0x10000020, float32) |

### The count's own rule, which is NOT dividing evenly, and the header's sentence about it is wrong

`splitTensor:numSplits:axis:name:` takes a count and the release turns it into a list. **The header's own two
sentences about it are wrong** - MPSGraphTensorShapeOps.h in the SDK of iOS 16.4 says this form "Splits the
input tensor along `axis` into `numsplits` result tensors of **equal size**. Requires that the length of the
input along `axis` is **divisible by** `numSplits`" - and both halves are measurably false: 5 into 3 is
`2 2 1` and 7 into 4 is `2 2 2 1`, which are not equal sizes, over extents that are not divisible by the
counts. It is the same kind of loose sentence as the concatenation family's "broadcast compatible" above, and
the row of the method says so with the measurement. The rule is measured
over **forty-two pairs**, one process each - every extent E in 1..8 against every count N in 1..4, which is
thirty-two, and then (9,3), (9,4), (10,3), (10,4), (11,4), (12,5), (13,5), (9,5), (16,5) and (17,6), which is
ten more - of which **the release refused twelve and answered thirty**, and **thirteen of those thirty have
sizes that are not all equal**, so those thirteen are the pairs where a walk that divided evenly would answer
something else. The rule is:

> **the first N-1 sizes are `ceil(E/N)` and the LAST is what is left.**

| E, N | sizes | E, N | sizes |
| --- | --- | --- | --- |
| 3, 2 | 2 1 | 7, 2 | 4 3 |
| 5, 2 | 3 2 | 7, 3 | 3 3 1 |
| 8, 2 | 4 4 | 5, 3 | 2 2 1 |
| 3, 3 | 1 1 1 | 8, 3 | 3 3 2 |
| 9, 3 | 3 3 3 | 10, 3 | 4 4 2 |
| 4, 4 | 1 1 1 1 | 7, 4 | 2 2 2 1 |
| 10, 4 | 3 3 3 1 | 11, 4 | 3 3 3 2 |
| 13, 5 | 3 3 3 3 1 | 17, 6 | 3 3 3 3 3 2 |

### Every pair measured, which is the whole of the table the rule was read off

Forty-two rows, one process each, from `.agent-work/probe/numsplit.m`; the raw run is
`.agent-work/runs/v-mps10/numsplit-table.txt` and a reader can re-ask any of them.

| E | N | the sizes the release answers |
| --- | --- | --- |
| 1 | 1 | `1` |
| 1 | 2 | **refused** |
| 1 | 3 | **refused** |
| 1 | 4 | **refused** |
| 2 | 1 | `2` |
| 2 | 2 | `1 1` |
| 2 | 3 | **refused** |
| 2 | 4 | **refused** |
| 3 | 1 | `3` |
| 3 | 2 | `2 1` |
| 3 | 3 | `1 1 1` |
| 3 | 4 | **refused** |
| 4 | 1 | `4` |
| 4 | 2 | `2 2` |
| 4 | 3 | **refused** |
| 4 | 4 | `1 1 1 1` |
| 5 | 1 | `5` |
| 5 | 2 | `3 2` |
| 5 | 3 | `2 2 1` |
| 5 | 4 | **refused** |
| 6 | 1 | `6` |
| 6 | 2 | `3 3` |
| 6 | 3 | `2 2 2` |
| 6 | 4 | **refused** |
| 7 | 1 | `7` |
| 7 | 2 | `4 3` |
| 7 | 3 | `3 3 1` |
| 7 | 4 | `2 2 2 1` |
| 8 | 1 | `8` |
| 8 | 2 | `4 4` |
| 8 | 3 | `3 3 2` |
| 8 | 4 | `2 2 2 2` |
| 9 | 3 | `3 3 3` |
| 9 | 4 | **refused** |
| 10 | 3 | `4 4 2` |
| 10 | 4 | `3 3 3 1` |
| 11 | 4 | `3 3 3 2` |
| 12 | 5 | **refused** |
| 13 | 5 | `3 3 3 3 1` |
| 9 | 5 | `2 2 2 2 1` |
| 16 | 5 | **refused** |
| 17 | 6 | `3 3 3 3 3 2` |

The count is **refused exactly when the last size would not be positive**, which
is when `(N-1)*ceil(E/N)` is not less than E: E=4 N=3, E=6 N=4, E=9 N=4, E=12 N=5, E=16 N=5, and every N above
E. The release's own compiler says so in its own words - `infer split sizes from total size=E and
num_splits=N failed.` (MPSGraphUtilities.mm:1543), then `LLVM ERROR: Failed to infer result type(s):` - and a
count of ZERO is refused the same way (`refusals.txt`'s `split-num-divisible`, `split-num-six-into-four`,
`split-num0`).

### What the release refuses about the sizes, and where the port refuses it

Every one of these is a refusal of the release, and the port raises `NSInvalidArgumentException` **where the
graph is built** for each of them, which is what this library does for every shape and axis the release
refuses, and what the row of each method says:

| question | what the release does |
| --- | --- |
| sizes that do **not add up** | BUILDS the result tensors - the shape line prints two 2x1s for `@[@1, @1]` and two 2x3s for `@[@3, @3]` of a 2x4 - and then its own compiler refuses the graph: `'mps.split' op sum of result dimension lengths along split axis must equal input dimension length along split axis` (MPSGraphUtilities.mm:1543), after which `Pass failed: MPSCopyDataFiles` takes the process down |
| a size of **zero** | builds the result tensor of no elements - the shape line prints **2x0** - and is refused as it assembles the results: `NSInvalidArgumentException`, `object cannot be nil`, from `-[__NSArrayM insertObject:atIndex:]` |
| a size of **minus one** | takes the process down **where the graph is built**, with SIGSEGV and no word at all |
| an **axis outside the rank** | the same sentence the concatenation's is - `invalid axis tensor: [2], axis must be in range -rank <= axis < rank, rank = 2` - from the split's own line 1543 of MPSGraphUtilities.mm, then `LLVM ERROR: Failed to infer result type(s):` |

### The sizes as a tensor: a constant answers, a placeholder does not

`splitTensor:splitSizesTensor:axis:name:` is the header's fed form, and what the release can do with it turns
out to be the whole question:

* a **constant** of `@[@1, @3]` along axis 1 of a 2x4 answers **exactly what the written-down `@[@1, @3]`
  answers** - a 2x1 of (1, 10) and a 2x3 of (2, 3, 4 | 20, 30, 40) - and so do constants of `@[@2, @2]`,
  `@[@3, @1]`, `@[@1, @1, @2]` and `@[@4]`, over an axis of 0 as well as of 1. Four cases of `gather_split`.
* a **placeholder**, which is what a caller who wants the sizes to arrive at run time makes, takes the release
  down **where the graph is built**, with SIGSEGV and nothing printed - measured over a sizes tensor of shape
  `[2]` and of shape `[1]`, an int32 and an int64 alike (`split-sizes-fed-placeholder`).

So the port reads a constant's value when the graph is built and refuses a placeholder there. **One thing
measured on the way, worth naming because it is what a caller has to do**: the release holds the fed
parameter as a constant of its own, so the value has to be paired with the caller's **own placeholder** and not
with the operation's first input - pairing it with the latter is refused at the run with `Input feed tensor not
found in placeholders, tensor corresponds to operation: mps_constant` (measured, exit 134).

### The coordinate: int32, counted from the end, and the one walk with no operand

`coordinateAlongAxis:withShape:name:` has no operand, so its result is not a gather of anything:

| question | the release answers |
| --- | --- |
| the result's data type | **MPSDataTypeInt32** (0x20000020) whatever the shape is, and not int64 - measured over ranks of one (`[1]`, `[3]`, `[5]`), two (2x3, 1x1) and three (2x3x4, 1x1x1) |
| the value | the coordinate of the axis named: axis 0 of a 2x3 is (0, 0, 0 \| 1, 1, 1), axis 1 is (0, 1, 2 \| 0, 1, 2), axis 0 of a `[5]` is (0, 1, 2, 3, 4), axis 1 of a 2x3x4 is (0, 1, 2 \| 0, 1, 2) four times over, axis 2 of a 2x3x4 is (0, 1, 2, 3) repeated six times |
| an extent of **one** | a single zero, whatever the axis and the rank |
| the axis | counted **from the end of the rank**: -1 answers what 1 answers and -2 what 0 does |
| an axis **outside** the rank | `'mps.get_coordinates' op invalid axis: 3.` and `'mps.get_coordinates' op invalid axis: -4.` of a 2x3x4, and `invalid axis: 1.` of a rank of one (MPSGraphUtilities.mm:1678) - the operation's own name, which is neither a split nor a gather - then `LLVM ERROR: Failed to infer result type(s):` |
| a shape of **no axes** (`@[]`) | builds a result of rank zero and is refused with the same sentence, `invalid axis: 0.` |
| a shape with a **zero extent** | is the one extent this family does NOT refuse at the build - measured, a coordinate of a `[0]` is a `[0]` and of a `2x0` a `2x0`, both int32 - but the release's own RUN then refuses the destination with `object cannot be nil` from `-[__NSArrayM insertObject:atIndex:]`, because a buffer of no bytes does not exist (measured on this host: `newBufferWithLength:0` and `newBufferWithBytes:length:0` both answer nil). So there is no run to answer and the port refuses the shape where the graph is built (`coord-zero-extent`), as it does for every extent the release will not run |

The three **fed** forms, and the same rule as the split's sizes: a **constant** answers and answers exactly
what the written-down form answers (an int32 constant of `@[@2, @4]` at axis 1 is the same 2x4 of coordinates;
an int32 constant axis of 1, 0 or -1 is the same 2x4 the written-down axis answers - six cases of
`gather_split`), and a **placeholder** is refused:

| fed form | what the release does with a placeholder |
| --- | --- |
| `coordinateAlongAxisTensor:withShape:name:` | takes the process down **where the graph is built**, with SIGSEGV and no word at all, for an axis of 1, of 0, of -1 and of 5 alike. A **floating point** axis is refused by its own compiler: `'mps.get_coordinates' op operand #1 must be 0D tensor of mps index type values or static-shape defined tensor with shape equal to [1] or unranked tensor of mps index type values` - the same sentence the fed gather parameters of this library raise |
| `coordinateAlongAxis:withShapeTensor:name:` | builds a result tensor whose shape is **-1x-1** and goes down with it (exit 134), for an int32 and an int64 alike |
| `coordinateAlongAxisTensor:withShapeTensor:name:` | the same, and the fed shape's -1x-1 is what it prints first |

### A retracted measurement, because it was mine and it was wrong

The first probe of the constant-sizes form read `@[@1, @3]` as `2x1` and `2x1` and called it a release
misdirection. It was **a probe bug**: the constant's NSData was built with the number of bytes its SHAPE had
*axes* (`@[@2]`.count = 1, so four bytes) instead of the number of elements it holds, so the release read a
two-element int32 constant out of four bytes. With the length right it answers `2x1` and `2x3`, byte for byte
what the written-down sizes answer. The corrected probe is `.agent-work/probe/family2c.m` and the four
constants are cases of `gather_split`; nothing in the rows rests on the wrong reading.

## The block-moving family: four operations that are ONE chain of three walks

Eight rows and two seams, of 15.0 and 16.1: the **space-to-depth** and **depth-to-space** of 15.0, each with two
axes of a block and the axis the blocks go to and the axis they come from, and the **space-to-batch** and
**batch-to-space** of 16.1, which are the same thing with any number of spatial axes and a rectangular block.

**Nothing in this family is a walk of its own.** Every one of the four operations is three walks this library
already had, in this order:

1. a **reshape** that splits each spatial axis into its block rows and its block columns - or merges them back
   and splits the batch axis instead, which is the same statement the other way round;
2. the **permutation transpose** of 16.0, which carries the batch axis's own piece and the block's own
   coordinates into the order the flag names;
3. the reshape that collapses that group back into the single axis the result has.

So the seam is `-revenant_mps_blockShuffle:spatial:batch:block:toBatch:shuffle:name:` and what is worth writing
down is the **order the axes are held in** and **the rules the release refuses the family by**.

Measured on this host's own MPSGraph (macOS 27.0 build 26A428, M4 Pro, Metal 4) and compared cell for cell in a
process of its own (`gather_spacebatch`): **49 cases, 1416 cells, every cell byte-identical to the release,
`gather_spacebatch: same as the system on 1416 of the 1416 cells with a result buffer; 1416 within the
release's own precision, 0 recorded`, `checks=23 failures=0 recorded=0`, and the red control differing from the
release in 24 of the 49 case lines.**

### The one thing that was wrong, and it took the whole family with it

The permutation the transpose reads is the **operand's axes in the operand's own order with the batch axis
replaced by the woven group**, and the collapse after it is of **that run of adjacent axes** rather than of a
prefix. An earlier version of the seam appended the block ROWS to the woven group as well, which made the
permutation one entry per spatial axis longer than the split tensor has axes. The symptom was not a wrong
answer: the family's own process **died on its very first case** with

> `MPSGraph: s was asked to transpose with a permutation of 7 entries for a rank-5 tensor`

so no case of the family past the first was ever compared against the release, and the `wip` commit that
introduced the seam reported sixteen of eighteen cases green - a number measured before that edit and not after
it. The order above is what fixes it, and what the two cases that first showed it are:

| case | the release answers | what the port answered |
| --- | --- | --- |
| one spatial axis `@[@2]` over a `[3, 4, 6]` with batch axis 0 and a block of `@[@2]` | a **`[6, 4, 3]`** | a `[6, 3, 4]` |
| three spatial axes `@[@0, @1, @2]` over a `[2, 2, 4, 2]` with the **batch axis last** | a **`[1, 1, 2, 16]`** | a `[16, 1, 1, 2]` |

Both are the result's AXIS ORDER, and both say the same thing: the axes after the batch axis were being put in
the split layout's order rather than the operand's. With the order fixed, a one-spatial-axis graph carries the
answer of the general form over two axes with one of them of extent one, and the batch axis's own position is
what the three-axes case pins down.

### What the release's own ordering is, in the words of the measurement

* **The block's own coordinates run with the LAST spatial axis fastest.** That is what makes the 2D form's
  `(widthAxis, heightAxis)` the general form's `spatialAxes @[@heightAxis, @widthAxis]`: measured, the two
  forms over the same operand and the same block answer **byte for byte the same values**.
* **Block dimension `i` belongs to spatial axis `i`, and the result's axes are the operand's own in the
  operand's own order.** Both halves are measured over a `[2, 4, 8]` whose batch axis is 0, and they are two
  halves of one fact - a list written the other way round is the same operation read positionally:

  | `spatialAxes` | `blockDimensions` | the release answers | what it says |
  | --- | --- | --- | --- |
  | `@[@1, @2]` | `@[@4, @2]` | a **`[16, 1, 4]`** | axis 1 over **its own** block of 4 is 1, axis 2 over its own block of 2 is 4 - the result holds the **operand's** axes |
  | `@[@2, @1]` | `@[@4, @2]` | a **`[16, 2, 2]`** | the same two numbers read positionally against the other list: the block of 4 now belongs to axis 2 |
  | `@[@1, @2]` | `@[@2, @4]` | a `[16, 2, 2]` of `(1, 5, 17, 21, 33, 37, ...)` | the blocks swapped, so each axis has its own block again - and **different bytes** from the line below |
  | `@[@2, @1]` | `@[@4, @2]` | a `[16, 2, 2]` of `(1, 5, 17, 21, ... , 9, 13, 25, 29, ...)` | the same shape, not the same bytes |
  | `@[@1, @2]` | `@[@2, @2]` | a `[8, 1, 2]` over a `[2, 2, 4]` | with an **equal** block the two orders are a `[8, 1, 2]` each and **still not the same bytes** |

  The bytes differ because **the block's own coordinate `k` runs in the LIST's order, with the last of them
  fastest**, whichever order that is - so writing the list the other way round with the blocks swapped
  assigns each block coordinate to the other axis.
* **The flag says which of the batch coordinate and the block's own is fastest in the result's batch axis.**
  With `usePixelShuffleOrder=NO` the batch coordinate is the fastest, and the result's `d'` is `d + D*k`; with
  `YES` it is the slowest and `d'` is `d*(the product of the block) + k`, where `k` is the block's own
  coordinate in its row-major order with the last spatial axis fastest. Over the `[3, 4, 6]` with a 2x2 block:

  | the operand's element | `d'` with NO | `d'` with YES |
  | --- | --- | --- |
  | `(0, 0, w even)` | 0 | 0 |
  | `(0, 0, w odd)` | 3 | 1 |
  | `(1, 0, w even)` | 1 | 4 |
  | `(0, 1, w even)` | 6 | 2 |

  which is the header's own sentence measured: the block's values "contiguously within the depthAxis
  dimension" with YES and "interleaved with existing values" without it.
* **The result's shape** is the operand's own with the batch axis made `D` times the product of the block and
  every spatial axis made `extent / block` - `[3, 4, 6]` -> `[12, 2, 3]` - and for the other direction the same
  statement the other way round.
* **Each operation is the inverse of its partner with the same flag, and the round trip is the identity**, for
  both flags and for both the general and the 2D form. That is the header's own "This operation is the inverse
  of" sentence measured rather than assumed, and it is why the two directions are one chain here run forwards
  and one run backwards.

### The block rule is the same rule in two operations' own words

A block has to be an extent of one **and** to fit the axis it is a block of, and *which* of those two rules
that is depends on the direction, because the two directions move the blocks opposite ways:

| direction | the rule | the release's sentence, over a `[3, 4, 6]` and a `[12, 2, 3]` |
| --- | --- | --- |
| blocks IN (`spaceToBatch`, `spaceToDepth2D`) | each block **divides its own extent**, because every spatial axis becomes `extent / block` | ``Invalid `block_dimensions[1] = 5 for input size[2] = 6``, and the 2D form's `block_size (3) must be multiple of height 4` |
| blocks OUT (`batchToSpace`, `depthToSpace2D`) | the **product** of the blocks divides the batch axis, because the batch axis is the one that shrinks - which for the 2D form, with ONE block size for two axes, is the **square** of the block over the depth axis | ``Invalid prod(`block_dimensions`) = 4 for input[2] = 2``, and the 2D form's `block_size (3) squared (9) must be multiple of depth 12` |

This was the one divergence the last pass found and fixed, and the fix is in this object rather than in the
seam: the seam quotes the general form's sentence for both directions, and `depthToSpace2DTensor:` - which is
15.0's own method in 15.0's own object - now asks its own rule in the 2D form's own words before it reaches
the seam.

### The refusals, and the moment each one happens at

Every one of these is in `refusals.txt` with the release's own words and the exit status it was measured to
have. The moment matters as much as the text: **an axis outside the rank is refused where the graph is
BUILT**, with the result's shape nil and the release's own `LLVM ERROR: Failed to infer result type(s):`
behind it, while **a degenerate pair of axes and a block that does not divide are refused where the graph is
COMPILED**, after the release has built a result of a shape of its own.

| question | the release's words | moment | the shape it had built |
| --- | --- | --- | --- |
| an axis outside the rank, general form | `'mps.space_to_batch' op invalid axis: 3, axis must be in range - rank <= axis < rank, rank = 3` | build | nil |
| an axis outside the rank, 2D form | `invalid width_axis (3) for shape of rank 3`, and a negative one lands there too as `invalid width_axis (2147483647)` - the header's own `NSUInteger` making the caller write it | build | nil |
| the same axis twice | `'mps.space_to_batch' op axis must be unique` | build | nil |
| the batch axis among the spatial ones | ``'mps.batch_to_space' op `batch_axis` = 0 must be unique from `spatial_axes` `` | build | a shape, `12x2x6` |
| as many block dimensions as spatial axes | ``must have same size as `block_dimensions` `` | build | nil |
| a block that does not divide | ``Invalid `block_dimensions[1] = 5 for input size[2] = 6`` | compile | `30x2x1` |
| a degenerate pair of axes | `'mps.space_to_depth_2d' op Invalid degenerate axes: depth_axis (1) height_axis (1) for shape of rank 3` | compile | `3x16x3` |
| a block that does not divide, 2D, in | `block_size (3) must be multiple of height 4` | compile | `27x1x2` |
| a block that does not divide, 2D, out | `block_size (3) squared (9) must be multiple of depth 12` | compile | `1x6x9` |

The port asks every one of them **where the graph is built**, with the release's own sentence, which is this
library's rule for every extent the release will not run. That is a difference of moment and not of rule, and
the rows of the family say so.

### The 15.0 FED pair, measured before any row claimed it - and again, because one of the four answers was wrong

`spaceToDepth2DTensor:widthAxisTensor:heightAxisTensor:depthAxisTensor:blockSize:usePixelShuffleOrder:name:`
and its partner take their **three axes as tensors** and their block size written down - which is the header's
own shape, and which the previous pass had declared but **never asked of the release**. The first probe is
`.agent-work/probe/fed2d.m` and its raw run `.agent-work/runs/v-mps11/fed2d-all.txt`; the second is
`.agent-work/probe/fedrun.m` of this band with `.agent-work/runs/v-mps12/fedrun-*.out` beside it, and the
differential's own questions are in `refusals.txt` (`block-s2d-fed-axis-*`, `block-d2s-fed-axis-placeholder`).

* **A CONSTANT of shape `[1]` answers exactly what the written-down axes answer**, byte for byte, in both
  directions and under both flags - measured over the same `[3, 4, 6]` of 1 to 72 with the same axes of 2, 1 and
  0 and the same block of 2. An **int64** of shape `[1]` answers the same, so the release takes a shape of
  four or of eight bytes.
* **A constant of NO rank is not constructible at all.** The release's own
  `+constantWithData:shape:dataType:` takes the process down with ``failed assertion `shape.count > 0 failed, a
  constant must be passed a ranked shape'`` (exit 134), so the axis tensor has to be written with a rank.
* **A constant of MORE THAN ONE NUMBER builds the graph and leaves the result carrying no shape**, so there is
  nothing for a caller to read before the run and nothing to run into.
* **A PLACEHOLDER answers at RUN TIME, in BOTH directions and under both flags**, which is the answer this pair
  is built on: the release builds the graph with the result carrying **no shape at all**,
  `-compileWithDevice:` still hands back an executable, and the run writes **exactly what the written-down axes
  write** into the destination the caller gave it - the `12x2x3` of `(1, 3, 5, 13, 15, 17, 25, ... | 2, 4, 6,
  14, ...)` and, without the flag, `(1, 3, 5, 13, 15, 17, 2, 4, 6, ...)`, and the `3x4x6` of
  `(1, 19, 2, 20, 3, 21, 37, ... | 1, 7, 2, 8, 3, 9, 13, ...)` under the flag - exit 0. A placeholder of
  shape `[0]` (0D) answers the same, an **int64** placeholder answers the same as an int32 one, and one fed
  axis with the other two constants answers the same again in both directions.
* **A fed placeholder of MORE THAN ONE NUMBER, and a fed float32 axis, are refused by the release's own
  verifier**, at the **COMPILE** - the result tensor comes back with no shape at all and it is
  `-compileWithDevice:` that takes the process down - with the verifier's own rule about the tensor:
  `'mps.space_to_depth_2d' op operand #1 must be 0D tensor of mps index type values or static-shape defined
  tensor with shape equal to [1] or unranked tensor of mps index type values`, naming what it got,
  `'tensor<2xsi32>'` and `'tensor<1xf32>'` (exit 134, both directions). This port asks the same rule with the
  same sentence, **where the graph is built** - the moment every other extent of this library is asked at, and
  the only moment this port has for it.
* **A fed axis whose VALUE the release cannot use is refused by the release in the RUN**, which is the only
  moment there is: a width axis of 3 over a rank of 3 takes the process down with the written-down form's own
  sentence, `'mps.space_to_depth_2d' op invalid width_axis (3) for shape of rank 3` (exit 134). The other two
  of the family's refusals the release answers with a buffer it flags as an error in the same breath - a
  degenerate pair of axes (`'mps.space_to_depth_2d' op Invalid degenerate axes: depth_axis (1) height_axis (1)
  for shape of rank 3`, exit 0, the first eighteen elements and then zeros) and a block of 3 over a height of 4
  (`block_size (3) must be multiple of height 4`, exit 0, a partial buffer) - so this port refuses all three,
  at the run, with the release's own sentence.

### The 16.1 fed LISTS answer, and the rows that said they do not were measuring the wrong thing

The general form's two fed rows - `spaceToBatchTensor:spatialAxesTensor:batchAxisTensor:blockDimensionsTensor:...`
and its inverse - said a parameter that arrives as data is one the release cannot build a graph over, and the
port **refused a placeholder where the graph is built**. Measured over the `[3, 4, 6]` of 1 to 72 with the
spatial axes `@[@1, @2]`, the batch axis `@0` and the block `@[@2, @2]`, **each of the three parameters fed in
turn and in both directions** (`.agent-work/probe/fedlists.m`, one case per process under a timeout):

* the release builds a graph whose result tensor carries **no shape**,
* `-compileWithDevice:` **hands back an executable**,
* the **run writes exactly what the written-down axes write** over the same operand - the `12x2x3` of
  `(1, 3, 5, 13, 15, 17, 25, ... | 2, 4, 6, 14, ...)` and, the other way, the `3x4x6` of
  `(1, 19, 2, 20, 3, 21, 37, ...)` - **exit 0** in all six.

So this is the 2D form's fed pair with the **lists** the general form hands over, and the plan takes them as it
takes the 2D form's two. `revenant_mps_fedBlockShuffle:` now builds one operation of the family with the operand
and the three tensors, and the interpreter reads the three lists when the graph runs and asks
`RevenantMPSGraphBlockShufflePlan` - through `revenant_mps_runBlockShuffleChain:into:from:operation:values:`, which
is the 2D pair's own three walks (a reshape into the split shape, the permutation transpose and the merge back)
factored out so that both ask it rather than one of them repeating it. What the release refuses over a fed list
is a **floating point** one, at the graph's own building, and that is where the port refuses it.

Three things the measurement had to get right, each of them this band's own first attempt:

* **only the FED list goes into the feeds.** A constant is in the graph and not a feed, and one there is the
  release's own *"Input feed tensor not found in placeholders, tensor corresponds to operation: mps_constant"*
  (`MPSGraphExecutable.mm:1990`) - which is what the first version of the probe asked, in all six cases.
* **the fed list's buffer is its ELEMENT COUNT and not its rank.** A list of two axes is declared `[2]` - one
  axis of extent two - and fed **eight** bytes; four is the release's *"buffer is not large enough. Must be 8
  bytes"* (`MPSNDArray.mm:893`), the same refusal this page already records once for a destination sized off a
  `-1`.
* **the feeds go in the graph's own PLACEHOLDER ORDER**, so the operand's placeholder is made first; otherwise
  the release reads the float operand where it expects the int32 list - *"Incompatible element type for
  parameter at index 0, mlir module expected element type si32 but received f32"*
  (`MPSGraphExecutable.mm:4490`).

### The BATCH AXIS outside the rank, both directions, and the port's own sentence was wrong twice

The general form's batch axis had **no question in the harness at all**: the fed 2D form's own question
(`block-s2d-fed-axis-outside-at-run`) is about a fed axis refused at the RUN, and nothing asked the WRITTEN-DOWN
pair about a batch axis outside the rank, in either direction. Measured now over the `[3, 4, 6]` of 1 to 72 and
the `8x2x2` (`refusals.m`'s `block-s2b-batch-outside`, `block-b2s-batch-outside`,
`block-s2b-batch-negoutside`, `block-b2s-batch-negoutside`):

* the result tensor comes back with **no shape**, and the release's own **compiler** prints its sentence and
  takes the process down with it, **exit 134**, in both directions - *"'mps.space_to_batch' op invalid axis: 3,
  axis must be in range - rank <= axis < rank, rank = 3"* (`MPSGraphUtilities.mm:1171`) and *"'mps.batch_to_space'
  op invalid axis: 3, ..."* (`MPSGraphUtilities.mm:1119`). The **moment is the compile**, not the graph's own
  building, which is the difference the rows of this family already name for the fed verifier's refusals.
* a **negative** axis outside the same range is refused with the axis **AS IT WAS GIVEN** - `-4`, not the `-1`
  the plan counts it to - and the range itself is **-rank to rank-1**, not 0 to rank-1, because a negative axis
  inside that range is one this family counts from the end.

Both of those were wrong in the port's own refusal, and are fixed in
`RevenantMPSGraphBlockShufflePlan`: it printed the counted axis (`-1` where the release prints `-4`) and its prose
said "axis 0 to rank-1 is all it has" where the release's rule is `-rank <= axis < rank`. The port still refuses
**where the graph is built**, which is this library's moment and the only one it has, and now says the release's
sentence with the release's range.

### The depth-to-space over fed axes DOES answer, and the previous pass's hang was not this question

The previous pass recorded that the **depth-to-space over fed placeholder axes was measured not to return
within 300 s**, and left it out of `refusals.txt` because a question that hangs would hang `run.sh`. Measured
again here under a timeout of 120 s per case, over six configurations - both directions, both flags, an int32
and an int64 axis, a 0D axis, one axis fed with the other two constant, and a destination of the other
direction's shape - **it answers in every one of them, and five consecutive runs of it are byte for byte the
same**: the graph builds, the compile hands back an executable, the run writes the written-down form's values
into the caller's destination and the process exits 0 (`block-d2s-fed-axis-placeholder`, which asks for it in
`run.sh` itself, with no timeout, because it does not need one).

Two things the second probe found on the way, both of them its own and neither of them an answer of the
release: a destination of the **other** direction's shape does not hang either - the release writes its own
flat bytes into the caller's buffer and reads them back through the shape the caller gave, so an answer
differs from the same operation asked into a buffer of the right shape - and an int64 axis has to be fed in a
buffer of **eight** bytes, or the release refuses the caller's own feed in its NDArray (`buffer is not large
enough. Must be 8 bytes`, exit 134), which is a probe's artefact and not the pair's answer.

## The non-zero indices of 17.0: the one result of this library that is a LIST

`-[MPSGraph nonZeroIndicesOfTensor:name:]` is not a tensor of the operand's shape. Its answer is one row of the
operand's RANK coordinates for every element of the operand that is not a zero, in the operand's own row-major
order, in `MPSDataTypeInt32`; and its LENGTH is the count of those elements, which is data, so nothing in the
graph knows it when the graph is built. That is what makes it a walk of its own
(`RevenantMPSGraphNonZeroCount` and `RevenantMPSGraphNonZero` in `MPSGraphInterpreter14.m`), a shape the walk puts
on the output tensor when the operation runs, and a copy-out that has to know the destination's own shape
(`RevenantMPSGraphWriteInto` in `RevenantMPSGraph.h`, which both run paths end at).

Measured on this host's own MPSGraph (macOS 27.0 build 26A428, M4 Pro, Metal 4) with the probe
`.agent-work/probe/nonzero.m`, one case per process, and every case of the differential
(`gather_nonzero` in `tests/backports/host/mpsgraph/`) asked **in a process of its own** - see the last
paragraph of this section for why that is not optional.

**The shape the result tensor carries is `-1` by the operand's rank**, whatever the operand's data type was and
before the run and after it: `-1x3` over a `[3, 4, 6]`, `-1x1` over a `[6]`, `-1x2` over a `[4, 6]`, and the
data type `0x20000020` (`MPSDataTypeInt32`) over a float32, an int32 and a float16 operand alike. So the
`-1` is the release's own marker for the extent it cannot resolve - the same one the two dynamic extents of a
written-down reshape print - and the rank it CAN resolve. `refusals.txt`'s `nonzero-result-shape` asks it.

**What counts as non-zero is the operand read the way this library reads one everywhere else**, and the
measurement is one candidate at a time at element 30 or 31 of a `[3, 4, 6]`, because an answer of exactly one
row is written into *every* row of the destination (below) and a coordinate of `(0,0,0)` is the same bytes as
the zero an unreached row is given:

| the one non-zero candidate | float32 | float16 |
| --- | --- | --- |
| `0x7fc00000`, a NaN | non-zero | non-zero |
| `0x7f800000`, an infinity | non-zero | - |
| `0x00000001`, a denormal | **a zero** | non-zero |
| `0x80000000`, a NEGATIVE zero | **a zero** | **a zero** |
| `0x00000000`, a positive zero | a zero | a zero |

So a float32 denormal is a zero because `RevenantMPSGraphAsZero` reads one as a zero of the same sign (the rule
this library already measured for the arithmetic family), a half denormal is not because the half path keeps
one, and a negative zero is a zero in both because `-0.0 == 0.0` is true and that is the test. The walk is
therefore `RevenantMPSGraphAsZero(RevenantMPSLoad(...), type) != 0.0` - the load every other walk here reads with,
and no rule of its own.

**The caller's destination does NOT decide the count, and this family writes the WHOLE destination.** Four
measurements, all over a `[3, 4, 6]` and a destination filled with the byte `0xbd` before the run:

* the rows the answer does not reach are a **written zero**: five non-zero elements into seventy-two rows
  writes five rows of coordinates and sixty-seven rows of zeros, and no cell of the destination is left at
  `0xbd`;
* **an answer of exactly ONE row is written into every row of the destination**: a `[3, 4, 6]` whose only
  non-zero element is the seventy-second answers `(2,3,5)` in each of a twelve-row, a seventy-two-row and a
  two-hundred-row destination, identically on three runs of one executable. A count of two is not broadcast -
  the two ends of the same operand answer two rows and sixty-seven zeros - so this is a rule of its own and not
  the general one;
* a destination with FEWER rows than the answer has **cuts the answer short** (three indices into a two-row
  destination are the first two), and more rows never add to the count;
* the rows are written `rank` cells apart in the destination's OWN last extent, so a destination of shape `3x4`
  keeps its fourth cell at `0xbd` and a destination of rank one has the three cells of the answer written into
  the front of a nine-cell buffer.

A destination of **no rows** is the one shape the release cannot be given: the process goes down inside its own
NDArray with `buffer is not large enough. Must be 12 bytes` (`MPSNDArray.mm:893`), and with a buffer of no
bytes at all one line earlier and with another of its own sentences (`Error: device may not be nil`,
`MPSNDArray.mm:759`). `refusals.txt`'s `nonzero-destination-no-rows`, `nonzero-result-shape` and
`nonzero-destination-five-rows`.

**Four cells of a seventy-two-row destination are not this operation's answer at all**, and they are recorded
in `recorded-cells.txt` with both runs' bytes rather than reproduced. The release writes `3` at cell 197 of a
count of two, `2` there of a count of three, and `3` at cell 203 and `2` at cell 206 of a count of five - over a
destination of seventy-two rows and only there, and only at a count of two, three or five: a count of one is
written into every row, a count of seventy-two fills every row with a coordinate, and no destination of ten
rows or fewer, nor of twelve, twenty-four or seventy-two with a smaller count, carries any of them. Each is
determinate (five processes of one case each print the same bytes) and **none of the four is a coordinate of
any element of the operand**. What was tried against them: that they are the answer's rows at an offset (they
are not - a count of five has two of them and a count of two has one, and a count of three's value is not the
count's own), and that they are the last axis's coordinates of the elements at those positions (element 65 of
a `[3, 4, 6]` is `(2,3,5)`, and the cell holds `2`). They are the release's own scratch reaching the caller's
buffer, the port writes the operation's answer there, which is a zero, and that is the whole difference
between the two runs: `gather_nonzero checks=24 failures=0 recorded=4` over 2106 cells in 51 cases.

**Why the family asks every case in a process of its own.** Run in one process - which is what every other
family in this differential does - **seven of the twenty-four cases answer rows that are not this operation's
answer at all**: `two-ends` answers its two own rows and then a `(3,0,0)` at row sixty-five, `rank1` of a `[6]`
answers `0` and `5` and then `3, 2, 5` in its last three rows, and `rank2` of a `[4, 6]` answers its two own
rows and then fifteen more that are coordinates of no element of its operand. Three runs of the whole family
print byte-identical answers, so it is not a race; the same case asked as the only non-zero graph in a process
of its own answers exactly what the operation computes. So `family_gather_nonzero` spawns one process per case
with `posix_spawn` - not `fork`, which would hand the child a copy of this process's Metal device and of
everything it has already built, which is the state the measurement is about - and the differential is
byte-for-byte on every case.

## The R4 names this band adds, in full

The SDK this package compiles against, the iPhoneOS 16.4 one, declares none of these: they are the private
surface this library's own files use to share their own state, and each is a registered implemented name or a
method of its object's own class rather than of a category - which is the one shape `carried_api` does not read,
so it is named here in the facts and not only in the registry.

* `-[MPSGraph revenant_mps_addOperationOfKind]` - MPSGraph14.m
* `-[MPSState revenant_mps_appendBuffer]` - MPSState11.m
* `-[MPSState revenant_mps_appendResource]` - MPSState11.m
* `-[MPSState revenant_mps_appendTexture]` - MPSState11.m
* `-[MPSGraph revenant_mps_arithmetic]` - MPSGraph14.m
* `-[MPSMatrixRandom revenant_mps_batchOver]` - MPSMatrixRandom13.m
* `-[MPSMatrixRandom revenant_mps_configureWithDataType]` - MPSMatrixRandom13.m, MPSMatrixRandomMTGP3213.m, MPSMatrixRandomPhilox13.m
* `-[MPSMatrixCopy revenant_mps_destinationAtIndex]` - MPSMatrixCopy11.m, MPSMatrixCopyDescriptor11.m
* `-[MPSCNNConvolutionDescriptor revenant_mps_fold]` - MPSCNNConvolutionDescriptor10.m
* `-[MPSCNNBatchNormalization revenant_mps_foldFromDataSource]` - MPSCNNBatchNormalization12.m
* `-[MPSCNNConvolutionWeightsAndBiasesState revenant_mps_listOfBufferSizes]` - MPSCNNConvolutionWeightsAndBiasesState11.m
* `-[MPSGraph revenant_mps_nanPropagatingExtreme:secondaryTensor:lesser:name:]` - MPSGraphReductionOps150.m, the one method 15.0's two NaN-propagating extremes share
* `-[MPSMatrixCopyDescriptor revenant_mps_offsetsAtIndex]` - MPSMatrixCopy11.m, MPSMatrixCopyDescriptor11.m
* `-[MPSGraph revenant_mps_operation]` - MPSGraph14.m
* `-[MPSGraph revenant_mps_predicate]` - MPSGraph14.m
* `-[MPSGraph revenant_mps_reduction:axes:tensor:parameters:name:]` - MPSGraph14.m, the seam every release's reduction factory goes through
* `-[MPSGraph revenant_mps_reductionOf:tensor:combination:kind:propagatesNaN:name:]` - MPSGraph14.m
* `-[MPSGraph revenant_mps_runOperation]` - MPSGraph14.m, MPSGraphInterpreter14.m
* `-[MPSMatrixLogSoftMax revenant_mps_setLogarithmic]` - MPSMatrixLogSoftMax12.m, MPSMatrixSoftMax12.m
* `-[MPSCNNPooling revenant_mps_setMaximum]` - MPSCNNPooling10.m
* `-[MPSCNNConvolutionDescriptor revenant_mps_setNeuronParameterC]` - MPSCNNConvolutionDescriptor10.m
* `-[MPSGraph revenant_mps_setOutputTensors]` - MPSGraph14.m, MPSGraphOperation14.m
* `-[MPSGraph revenant_mps_setParameters]` - MPSGraph14.m, MPSGraphOperation14.m
* `-[MPSCNNKernel revenant_mps_setWindowWidth]` - MPSCNNKernel10.m, MPSCNNPooling10.m
* `-[MPSMatrixCopy revenant_mps_sourceAtIndex]` - MPSMatrixCopy11.m, MPSMatrixCopyDescriptor11.m
* `-[MPSState revenant_mps_temporaryWithBlock]` - MPSState11.m
* `-[MPSMatrixCopyDescriptor revenant_mps_withCount]` - MPSMatrixCopyDescriptor11.m
* `-[MPSTemporaryMatrix revenant_mps_withReadCount]` - MPSTemporaryMatrix11.m, MPSTemporaryVector12.m
* `-[MPSMatrixRandom revenant_mps_wordAtIndex]` - MPSMatrixRandom13.m
* `-[MPSCNNPooling revenant_mps_zeroPadSizeX]` - MPSCNNPooling10.m
* `-[MPSCNNPooling revenant_mps_zeroPadSizeY]` - MPSCNNPooling10.m
* `-[MPSGraph revenant_mps_constantShapeOfTensor:]` - MPSGraph14.m, the shape a constant tensor holds and nil for
  any other, which is how a slice's gradient is given the shape of its forward input before the graph runs
* `-[MPSGraph revenant_mps_gatherShapeOfTensor:parameters:named:]` - MPSGraphInterpreter14.m,
  the gather walk's own plan asked when the graph is built, so that the output tensor
  carries its result's shape before anything runs
* `-[MPSGraph revenant_mps_slice:inputs:parameters:name:]` - MPSGraph14.m, the one seam the slice family's eleven
  methods and the pad's and the tile's four go through: a gather in one direction, a scatter in the others
* `-[MPSGraph revenant_mps_split:axis:sizes:numSplits:name:]` - MPSGraph14.m, the one seam in this library that
  answers with SEVERAL tensors: one output tensor per region, each with its own shape
* `-[MPSGraph revenant_mps_splitSizes:numSplits:axis:ofShape:named:]` - MPSGraphInterpreter14.m, the sizes a split
  cuts by, and the three refusals about them, asked both when the graph is built and when it runs
* `-[MPSGraph revenant_mps_coordinates:fedAxis:shape:fedShape:name:]` - MPSGraph14.m, the walk with no operand: the
  shape and the axis, written down or held in a constant

**Which half of this list is current, and which is not.** The graph's names are read out of the graph's own
compiled objects with `nm` and are current for this tree: `relcheck` compiled twenty of them - the slice family's
three objects of 17.4, 18.0 and 18.2 among them - and held every one to a single release. The matrix and CNN entries are a snapshot of an earlier pass and are short of the tree:
measured against the sources, `MPSPredicate16.m` carries `revenant_mps_permitsExecution`, `MPSImagePyramid16.m`
carries three (`revenant_mps_filter`, `revenant_mps_filterWidth`, `revenant_mps_filterHeight`) and `MPSNDArray13.m`
carries four (`revenant_mps_wholeShapeOf:`, `revenant_mps_makeBuffer`, `revenant_mps_elementCount`,
`revenant_mps_bufferStrides:`), and none of those eight is named above. Nothing in the graph family rests on the
gap in the rest of the list, because the registry check reads the built libraries and not this page - but the
page is wrong about the tree there until the whole library's objects are read again, which is what the closing
sentence describes.

The graph's are the interpreter's - its kinds, its per-operation wiring, its element accessors and the seams its
releases' factories share - and the matrix and CNN families' are the window, the fold, the state and the copy
descriptor's. None of them is called by an application. The list is regenerated from the objects whenever a family changes.
