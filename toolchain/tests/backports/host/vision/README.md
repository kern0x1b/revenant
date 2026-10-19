# run-crop.sh — the crop-and-scale rules, against Core ML's own image constructor

`sh tests/backports/host/vision/run-crop.sh`

What it measures: for each case, a picture and a target, the port's `charon_vision_pixels` and
Core ML's own `+[MLFeatureValue featureValueWithCGImage:pixelsWide:pixelsHigh:pixelFormatType:options:error:]`
under **the same option**, and the two pixel buffers compared byte for byte. Every case prints
`differing=N of M`.

Three things it does that a plain comparison would not, each because the check once failed without
them:

- **The port build compiles `Vision/CharonVisionBilinear.c`.** The kernel is not in the header, and a
  port build that leaves it out links against nothing and answers nothing.
- **Each side's origin is printed with `dladdr`, and the run fails if they are the same image.** The
  system build answers *both* sides with the framework's own constructor — it is a control, and it
  says so — but a port build that had silently collapsed into that would have read zero on every row.
  A zero that is the framework against itself is the failure this guards.
- **The verdict and the mutants are counted separately, and the mutants run whatever the verdict
  was.** A mutant stage that only ran on a green verdict would not run at all while a rule is being
  found, which is exactly when it is needed.

The mutant is the **destination inset put back into the sample position** — the bug the kernel
once had. It hashes the file before and after and fails the run if the patch changed nothing, because
a mutant that changes nothing is the pristine kernel and a green run of it proves nothing. A run that
prints `the mutant changed the file: <before> -> <after>` and then `the mutant is caught` is the
proof that the check is holding the port's geometry.

## Reading a run

| line | what it means |
| --- | --- |
| `the two answers come from: the port's … and the framework's …` | `dladdr` on each side; the run stops here if they match |
| `the system's own rows: both sides are CoreML` | the control, and a table whose zeros are not a verdict |
| `differing=N of M` per case | the port against Core ML, whole buffer, every byte, no tolerance |
| `port: same as the framework` / `port: DIFFERS` | the verdict |
| `the mutant changed the file: … -> …` | the mutant was applied; without this the run has failed |
| `mutants: 1 run, 0 surviving` | the count, separate from the verdict |

## The fixtures beside it

- `croprect.md` — where Core ML puts a picture, on twelve cases, with the port's own prediction
  beside each. A rule has to explain every row before anything in the library changes.
- The kernel's parameters and the impulse rows that identified them are in
  `facts/Vision/Vision.md`.

Both probes this check grew out of live in `.agent-work/runs/crop-probe/`, which is not in the tree.
