# The Security host cases: how they are built, and the trap that made one measure the host

These are **not** builds. A case is a `clang` compile and a run on this Mac, so the machine's load does
not apply to them and there is no heavy job: the only heavy things are a `heavy.sh` build and the gates.

`run-cases.sh` is the one command that runs the cases here, `check-digests.lua` included - the digests were the
one thing here that nothing ran, which is the defect this directory is about, so the driver runs it
first and counts its exit. Two scripts in this directory are run by `run.sh` and not by the driver, and this
says so rather than leaving "everything" to mean them: `gen-security-cases.lua` GENERATES the case file and
`run.sh` checks it, and `check-registered.lua` is run by `run.sh` with its `--control` (it was invoked by nothing
before `run.sh` called it; it passes, 18 in the list, 20 defined, 137 rows of kind constant, exit 0). It is not in the
driver's exit path. The driver builds each case **with the port sources
it is given**, feeds the output to that case's comparator, runs the mutations, and ends with
`N cases, M mutants, M noticed`. Every case prints exactly one verdict line - `GREEN`, `RED`, `CRASH`,
`BUILD`, `MISSING` or `NOTRUN` - and the tail fails if the number of `GREEN` lines is not the number of
cases, so a run cannot report coverage its own output does not show. It exits non-zero on any failure, on a mutation that goes unnoticed, and
on a case whose expected symbols are missing from its own binary, and on a digest below that no longer
matches the file it is pinned to. The digest line is a check, not a case: it is deliberately not in the
case or `GREEN` counts, so `N cases` still means the cases and nothing else.

**Every mutant is judged against a control on its own link line**, and that is a fourth thing the run
fails on: a mutant whose control is not green is reported `INVALID MUTANT` and is **not** counted as
noticed. The section below is the trap it exists for, and the numbers it produced on this tree are
`20 cases, 18 mutants, 17 noticed` with 18 green controls.

## The trap: a case that links too little measures the HOST, silently

A case compiled without one of the port sources it needs does not fail to build. The names it calls
resolve to the **host framework**, which has the same API, the case runs, prints plausible numbers, and
the comparator reports a difference that looks like a port bug. It is not one: the port code was never
in the process.

This happened for real. `protocol-metadata-accessors` was linked without
`SecProtocolMetadataAccessors13_0.m`, so three of its calls answered from the host - the port's binary
defines only **3 of the 17** port accessors, and `ciphersuite` came back `65535`, a value the port cannot
return at all.

**`nm -m` does not catch this.** It prints an address for a symbol the binary does not define, and the
address reads like a definition:

```
nm -m case | grep ciphersuite
  0000000100001254 (__TEXT,__text) external _sec_protocol_metadata_get_negotiated_ciphersuite
```

which looks defined. `nm -u` and the plain symbol table tell the truth:

```
nm -m case | grep ciphersuite
  (undefined) external _sec_protocol_metadata_get_negotiated_ciphersuite (from Security)
nm case | grep ' T _sec_protocol'
  _sec_protocol_metadata_get_negotiated_tls_ciphersuite     <- the TLS one, and only the TLS ones
```

`run-cases.sh` now checks, after every build, that every function each source defines is **defined** in
the binary, and fails with `MISSING <case> _<sym> ... it resolved to a dylib` when one did not. The
lesson generalises: **a case proves the port only if you check the port is in the process.**

## The same trap, one level up: a MUTANT linked against less than its case

A mutation is evidence that a comparison can tell a case from a broken one - and only if the mutant
was built the way the case is built. The three `sec-identity` mutants were not: `run_mutation` linked
the case, the mutant and at most one extra, while the case itself is built
`$H/sec-identity.m $SI $SI16 $LI $O`. So each mutant ran a binary missing three of its case's sources,
printed rows the case never produces, and went RED on **those**:

```
holder-class   MISSING
DIFFERS access-empty-true: got 0 and the port claims 1
DIFFERS holder-class: the port's options holder was not found
DIFFERS local-identity-holds: the case did not measure it
```

and the proof that this has nothing to do with any mutation: **a byte-identical copy of the unmutated
source on that same line is RED too**, while on the case's full line it is green. The counter was
reading the link and calling it coverage. One of them was worse than unattributable -
`sec-identity-noretain` drops the `CFRetain` in `sec_identity_copy_ref`, and mutated and unmutated
outputs were byte-identical, so the mutation was invisible to the case and its RED was entirely the link.

So `run_mutation` now takes the mutant's link line as arguments - `NAME COMPARE CASEFILE ORIGIN
[EXTRA...]`, where `ORIGIN` is the port source the mutant is a copy of and `EXTRA` is the rest of what
the case links - and builds the control first: the same line with the unmutated `ORIGIN` put back where
the mutant's copy goes. `must_not_compile`, the eighteenth mutant, is held to the same rule with the
sign flipped, because its verdict is a build FAILING and so its control is the unmutated line
BUILDING.

The F1 shape fed to the new driver, so the check is shown failing and not only passing:

```
INVALID MUTANT sec-identity-nocopy  the CONTROL is red ...: access-empty-true: got 0 and the port claims 1
INVALID MUTANT sec-identity-noretain the CONTROL is red ...: access-empty-true: got 0 and the port claims 1
INVALID MUTANT defaults-below-enum  the CONTROL is red ...: port-class: the port's CharonSecProtocolOptions was not found
run-cases: 3 failure(s) - 20 cases, 18 mutants, 14 noticed          EXIT=3
```

Three mutants, and `noticed` falls from 17 to 14: a mutation whose own line is wrong is not counted as
noticed, because the count is the run's claim about what it measured.

## Two more things that look like findings and are not

- A warning in a case's log is not necessarily a defect. The metadata-accessors case emits
  `-Wdeprecated-declarations` for `sec_protocol_metadata_get_negotiated_protocol_version` and
  `kSSLProtocolUnknown`, which the SDK deprecates in favour of the `tls_` spellings. The case calls the
  non-`tls_` names on purpose: those are the functions the port implements.
- A `-Wnonnull` warning in a port source usually means the header's result annotation, and the library's
  flags are `-Wall` without `-Werror`, so it compiles. It is recorded, not silenced.

## Output is unbuffered

The cases that can be crashed by a mutation call `setvbuf(stdout, NULL, _IONBF, 0)` at the top, so a
segfault cannot lose the rows printed before it. Without that, a crash makes the comparator say a row
"did not measure", which names a truncated buffer rather than the crash.

## Why the four red metadata-accessor rows were NOT a defect in the port or the case

They were red, and the worry was the right one: those accessors were merged on the reviewer's approval
**with no case running them**, so a red four rows could have meant the merged code was wrong. These are
the two explanations that were **ruled out, with the evidence**, so that the answer is on disk rather
than in a commit subject and a deleted file.

**1. It was not the host answering.** `nm -m` on the case binary the driver built:

```
0000000100001254 (__TEXT,__text) external _sec_protocol_metadata_get_negotiated_ciphersuite
0000000100001284 (__TEXT,__text) external _sec_protocol_metadata_peers_are_equal
0000000100001318 (__TEXT,__text) external _sec_protocol_metadata_challenge_parameters_are_equal
```

`(__TEXT,__text)` with an address **looks** like a definition, and that is the trap: `nm -m` prints an
address for a symbol the binary does not define. The truth is in the plain table and in `nm -u`, and it
is also visible as a count:

```
the driver's binary defined        3 port accessors
the same sources built by hand    17
nm -m case | grep ciphersuite  ->  (undefined) external _..._ciphersuite (from Security)
```

The host *could* have answered - `otool -L` shows `Security.framework` linked - and did.

**2. It was not a disagreement between the port and the case.** Built by hand from the same three sources
(`SecProtocolMetadata13_0.m`, `SecProtocolMetadataAccessors13_0.m`, `SecProtocolMetadataAccessors16_0.m`),
every row matched:

```
ciphersuite 0 0   peers-same-object 1 1   peers-two-objects 1 1   peers-one-null 0 0
peers-both-null 1 1   challenge-same 1 1   challenge-one-null 0 0
```

and reading the bodies agrees: both comparators return `true` for the same object and for two objects and
`false` when exactly one is NULL, and `get_negotiated_ciphersuite` returns `SSL_NULL_WITH_NULL_NULL`.
**65535 is a value the port cannot return at all.**

**The cause was mine, in the driver.** `protocol_case()` read `sources=$2` and was called with two source
arguments, so `$PMA` was dropped on the floor and never reached the link. `protocol-options-blocks` and the
metadata case are wired through the same `protocol_case`, which is why they were affected too.

**How to check this class in a second**, since it is not obvious: do not grep the driver for a comparator's
name - the driver constructs it as `compare-$name.lua`, so a literal grep for
`compare-protocol-options-blocks.lua` returns **0 while the case runs and is green**. Grep for the
`protocol_case` line, or read the summary line, which names how many cases were driven.

## The guard, and its measured limits

**The guard covers a case that reaches the port through a `sec_*` name, when the source defining that
name is linked.** It matches `sec_*` in the case and in the port sources and requires `_name` in the
case's own binary.

**It does NOT cover nine of the twenty cases**, and the list is what the code enforces, not what would
be nice. This section said "five" until this tree: five cases were named and four more were outside the
guard with an empty `called` set and no name anywhere. Measured per case, the way `run_case` builds
the set, eleven are inside the guard and nine are outside it - and the nine are the table:

| case | why it is outside the guard | proven by |
| --- | --- | --- |
| `network-fetch` | the port's functions are named as the HEADER names them (`SecTrustSetNetworkFetchAllowed`, ...), and the guard matches only `sec_*` | dropping `$N` leaves the case **GREEN, exit 0**, with `nm -u` showing those symbols undefined - the host answered |
| `supported`, `attributes`, `certificate-name` | they reach the port through `Charon*` helpers, which the guard does not match | same shape as `network-fetch` |
| `trust-result` | it resolves the port by `dlsym(RTLD_DEFAULT, ...)`, so there is no link-time reference to find at all | reading the case: the name is a **string** |
| `padding`, `verify-pairs` | the port's entry points are `Charon*` class names the host does not export, so a dropped source is caught by the LINK and not by the guard | dropping `$F`: `BUILD padding FAILED to build` on the undefined `_CharonSecurityPaddingFor`, and `BUILD verify-pairs FAILED to build` on `_CharonSecurityCarries` |
| `certificate-fields`, `certificate-name` | the same empty `called` set, and here the build still succeeds - the host answers the names the case uses - so what catches the drop is the COMPARISON | dropping `$D`: `RED certificate-fields DIFFERS null-out: a NULL out-parameter is errSecParam (-50)` |
| `protocol-options-flags` | it reaches the port through a `Charon*` holder class rather than a `sec_*` name, so its `called` set is empty; the drop is again caught by the comparison | dropping `$PF`: `RED protocol-options-flags DIFFERS port-class: the port's CharonSecProtocolFlags was not found` |

Four of those drops were run at once - `$F` from `padding` and from `verify-pairs`, `$D` from
`certificate-fields`, `$PF` from `protocol-options-flags` - and the run ends non-zero with the driver's
own tail check naming it: `16 GREEN verdict lines for 18 cases - the summary does not match the lines it
printed`, exit 1. The shape matters and it is not the same for all of them: for `padding` and
`verify-pairs` the LINK refuses the binary, and for `certificate-fields` and `protocol-options-flags` the
binary builds and the COMPARISON notices. In none of the four did the guard's `MISSING` branch fire,
which is exactly what an empty `called` set means. `certificate-name` is in the same row as
`certificate-fields` because its `called` set is empty for the same reason; the drop was not run for it
here and the row does not claim it was.

**And the newest case is inside the guard, by the same rule the list above is measured with.**
`sec-identity` calls six `sec_*` names - `sec_identity_create`,
`sec_identity_create_with_certificates`, `sec_identity_access_certificates`, `sec_identity_copy_ref`,
`sec_identity_copy_certificates_ref` and `sec_protocol_options_set_local_identity` - so its `called`
set is those six and the guard has something to check. Dropping `$SI` from its link line ends the run
non-zero, but by the LINK and not by `MISSING`:

```
BUILD  sec-identity FAILED to build          (the undefined symbol is CharonSecIdentity, which the
NOTRUN sec-identity  the build failed, so the case never ran        host has no such class)
run-cases: 1 failure(s) - 19 cases, 18 mutants, 17 noticed          EXIT=1
```

which is the same shape as `supported` and `verify-pairs` above: a case whose port entry points are
`Charon*` class names cannot fall through to the host, so the link refuses it before the guard is
reached. Both shapes end the run non-zero; they are not the same check.

**A source dropped from the link line CAN hide**, and `network-fetch` is the proof rather than my
assertion: the symbols resolve to the host's framework, the case compares numbers the host produced, and
it passes. What the guard does catch is a dropped source **whose functions the case reaches through a
`sec_*` name** - dropping `$PD`, `$PMA` or the 16.0 accessor source does fire `MISSING`.

The general fix is to stop matching a prefix and extract the port's definitions **by position** - the
last identifier before the `(` of a definition line - and then intersect that with every identifier the
case calls. I attempted the prefix route twice and it does not reach these names, so it is not claimed.

**`nm`'s own status is now captured where `set -e` cannot intercept it.** The earlier form
(`nm ... > file` then `nmstatus=$?` on the next line) never reached the assignment: the script ended on the
failing command, so the branch was unreachable and an `nm` failure killed the run silently. A stub `nm`
that exits 1 now produces **20** `BUILD ... nm -gU on the linked binary exited 1` lines, 0 cases counted,
and exit 20, where the real run is unchanged at **20/18/17**.

Still owed, none of it done:

1. **A source dropped from the link line is caught, and this was checked rather than assumed**: dropping
   `$PD`, `$PMA` or the 16.0 accessor source leaves the case calling a `sec_*` name, that name is still in
   the reference set **because the case file is itself on the link line**, the symbol is absent from the
   binary, and the guard fires. What it does **not** do is notice a
   source that was never linked because **nobody called its function** - the case has to reach the port
   through a `sec_*` name for the guard to have anything to check.
2. **The stale-mutant sweep is not landed**: `make-mutants.lua` runs after the early `mutate()` calls, so a
   sweep in the `else` beside it deletes the mutants that run has just written and the suite goes red.
   Measured on this tree by putting the sweep exactly there - `rm -f "$build"/mutant-*.m` - and running
   the driver:
   ```
   BUILD  make-mutants.lua reported success but mutant-blocks-challenge-into-keyupdate.m is ABSENT ...
   BUILD  make-mutants.lua reported success but mutant-data-halfpair.m is ABSENT ...
   run-cases: 10 failure(s) - 20 cases, 18 mutants, 12 noticed          EXIT=10
   ```
   It has to run before `make-mutants` and before the first `mutate()`.
3. **The missing-mutant-file check is reverted as unproven**: `must_not_compile` is required to see a
   build FAIL, and a mutant file that is simply absent makes the compiler fail for the wrong reason. Its
   control removed a file `make-mutants.lua` rewrites at the start of every run, so the control could not
   fail. Proving it needs a function-level test on a path that cannot exist.
4. **F2 - the guard builds its reference set from the case's own link line** and does not cover a case
   that resolves the port by `dlsym(RTLD_DEFAULT, ...)`, so `trust-result` can still measure the host and
   pass.

## Digests of the evidence this directory cites

Recomputed with `shasum -a 256` AFTER the last content change, on this tree, and checked by
`check-digests.lua` - which exits non-zero when this block is missing, when it covers fewer files
than the command below cites, when any digest does not match, or when a cited file cannot be read.
`run-cases.sh` runs it, so a pin that has gone stale ends the run non-zero; to run it by hand, run
`xmake l check-digests.lua` from this directory, which is the invocation its own docstring gives: the
script resolves the README and the files cited below from its own location and not from the working
directory, so the same run comes out the same from here, from the repository root or from anywhere else.

```
shasum -a 256 tests/backports/host/security/sec-object-wrappers.m \
         tests/backports/host/security/compare-sec-object-wrappers.lua \
         packages/a/apple-backports/Security/SecObjectWrappers12_0.m
```

    0e134f43b64166c4e55a12f1f000cd36b1ad422922c937c49ee27487b11ad00c  tests/backports/host/security/sec-object-wrappers.m
    38d1065dfd5eb70702bca6db5cca4d4cd7a451fa077ac7f8279911fa6ad8bab7  tests/backports/host/security/compare-sec-object-wrappers.lua
    c4fb20d9e4423c9127cbfdea7531b8a981a4aae89347106b2aa870ea33dbfbc9  packages/a/apple-backports/Security/SecObjectWrappers12_0.m

