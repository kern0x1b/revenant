# What the probe got wrong, and what caught it

The fault list for the single-section biquad and the reductions, kept because **every wrong answer in this
shape came from the harness and not from the port** - and because each one was caught by a check, which is the
only reason any of it survived to be reported. The next band should read this before writing a guest probe, and
should write its own entries here.

## The one that matters most

**The oracle was not the target.** The macOS arm64 host was used throughout while these rows are native on 6.0
armv7, and the host was wrong twice in ways that looked like findings:

- the reduction's order: macOS says the sum of `{1e30, 1, -1e30, 1, 1e-30, 3}` is **3**, which is the
  blocked-2 answer, and the 6.1.3 armv7 guest says **4**, which is sequential. Two differential failures that
  were never about the port's order;
- the biquad's float: a 1-ULP difference measured on macOS, attributed to a fused multiply-add the target
  does not have - armv7 VFP before VFPv4 has none at all. It survives on the target, so it is the release's
  own float behaviour and not the host's.

*Caught by:* building a guest probe and asking the release. **The macOS host is not an oracle for these rows and
must not be used as one.**

## The install, and three checks in a row that were each wrong

`xmake emulate install` reports `installing .. install ok!` and can leave the image holding a program from an
earlier build. Two guest runs then read output from a binary two edits old, and one of them was reported as a
control failing. Three attempts at the check, in order of how wrong they were:

1. **A sha256 of the two files.** Impossible to pass on a correct install, because the install signs the staged
   copy with `ldid -S` and the two are never byte-equal.
2. **A hash of the bytes before the code signature.** Not a weaker check but a meaningless one: `strip`
   rewrites exactly those bytes, and an unsigned build has none of them, so one side's region hashes as an empty
   file. It would have gone green on a stale install as readily as on a good one.
3. **LC_UUID, plus the copy not being older than what it was copied from.** Neither `strip` nor a signature
   changes LC_UUID. This is 7e035ac0's rule, `macho_uuid` and `verify_provenance` in the emulate plugin
   (platform.lua:426 and :452), and it is 7e035ac0's repro - not a check invented here.

*Caught by:* `strings` on the installed binary in the image's rootfs, asked for by the coordinator before a
run rather than after one. **Check that the binary under test is the binary that was built, before running it.**

## The rest, and what caught each

| fault | caught by |
| --- | --- |
| a 16-sample "bit-identical" match reported without checking a wider range; every later sample disagreed | extending the probe to the same 32 samples the port ran |
| a search reporting that **none** of five orders matched, when the port agreed with the release on all four inputs - the candidates were evaluated in **double** and compared with the **float** release's answer | the hand-computed control, which needs no host at all |
| an order case built from 1e8 against ones, which **cannot** distinguish any order because 1e8's ULP is 8 - it looked like a pass | printing the candidates' answers beside the host's and seeing they were all identical |
| a control that ran against the release's output, which is the very case that had already failed | pointing the control at the port's own output, a case known to be true |
| a one-element delay buffer where the header wants 2(M+1), so the host wrote over the test's own `sections` and the run died with no summary | the header's pseudocode, read before the buffer was sized; then AddressSanitizer |
| a `_Nonnull` sum-of-squares pointer passed as 0, which is a segfault in the release rather than a refusal | the crash, and the warning |
| `otool -Iv` reporting **zero** exports for a dylib that exports 177 symbols, read as "the six are not exported" | `nm -gU`, which agrees with the object count |
| the header's `ios(6.0)` marks taken for the release ladder, and then a claim that the host's delay layout was the opposite of the header's - read off a probe whose own indexing was broken | `release-split` over the object, and the host's own dumped `Delay` |
| a `planned` registry status that is not one of the four answers, failing the light guard for a commit | committing, which requires a clean guard - and **reading the guard's exit code, not its tail** |
| a `"utf-8".join` where `"\n".join` was meant, corrupting a source file | the link failing |
| `/tmp` scratch files after being told nothing goes there | being told again |
| `nm -gU` over a raw `dyld_shared_cache_armv7` finding **nothing at all**, read as "these names appear in no release" - for names that include one already measured at 6.0 | the control: a name already placed must come out at that release, so a run that finds nothing is a broken run |

## What to carry into the next probe

- **Build the control first, and prove it on a case already known to be true** - a hand-computed value, or the
  port's own output. A control that involves the oracle cannot catch a broken evaluator, because the oracle is
  what is in question.
- **Every comparison on the bit pattern**, never `==`: NaN never equals NaN and -0 equals +0.
- **A case that separates the candidates**, and a printout showing they differ, before believing a result that
  says they agree.
- **Check the binary before the run**, by UUID, every time.
- **The gate's exit code, not its last line.**

- **The ladder through the house tool**: `release-split` over an object that defines the names, or the emulate plugin's own `dyld.first_releases` cache - never by scraping the cache file. Every such run carries a control name, so a run that finds nothing about a name already placed is known to be broken rather than believed.
