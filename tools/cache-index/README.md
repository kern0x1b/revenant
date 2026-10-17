# The dyld name index

**The first held rung of a name, answered from an index instead of from 15 caches.**

`strings -a ~/.charon/dyld/<release>/dyld_shared_cache_<arch> | grep -xF NAME`, once per name, over
every rung, per slice, per author, was how the workspace found when a class, selector, symbol or ivar
first appeared. It reads the whole cache per name. Measured on this machine, that is **6 ms per MB**:
0.42 s at 80 MB, 1.38 s at 233 MB, 3.07 s at 494 MB, 6.04 s at 1002 MB — and the ladder the port holds
is 50 releases and 24.6 GB, so **~148 s for one name** on an idle machine. Several authors did that at
once with the load at 19–22, which is the bottleneck.

Two tools, both read-only towards the caches:

    python3 tools/cache-index/build.py                 # read each cache once, write the index
    xmake l tools/cache-index/first-rung.lua NAME...   # name <TAB> first held rung, or NONE
    xmake l tools/cache-index/first-rung.lua --self-test

## Measured, on this machine (2026-09-30, 50 held rungs, 24.6 GB of cache, load 13-22)

| | cost |
| --- | --- |
| **BEFORE**, one name over the whole ladder, `strings -a CACHE \| grep -xF` per rung | **155.7 s** measured (a name no rung has, no early exit); 170.5 s for a second |
| **BEFORE**, one name that is found early (`_NSFileSize`, at 3.1.3) | 1.08 s measured |
| **BEFORE**, per-rung cost | 0.42 s at 80 MB, 1.38 s at 233 MB, 3.07 s at 494 MB, 6.04 s at 1002 MB — linear, **6 ms per MB** |
| **BEFORE**, 500 names | **21.6 hours** (155.7 s x 500) |
| **AFTER**, build the index once, all 50 rungs | 32.5 minutes of reading, niced, at load 15-19 |
| **AFTER**, 500 names, `first-rung.lua` | **1.90 s** (five runs: 2.00, 1.94, 1.90, 1.92, 1.90) |
| **AFTER**, 500 names, again after every index is current | 0.1 s to check 50 headers, nothing to read |
| **AFTER**, a single name | 1.9 s, and 0.1 s of that is the python start-up |
| index on disk | 448 MB for the 50 per-release files, 76 MB for the merged table |

The 500 names are a random sample of 500 real names drawn from the table (seed 1), not a
hand-picked easy set. The BEFORE figure is a measurement of ONE name over the whole ladder, scaled by
500: running 500 of them would have taken 21.6 hours, and the first attempt at three names was killed
at the 10-minute mark with two of the three unfinished.

## What it is

    $HOME/.charon/cache-index/<release>.names.gz    one name per line, sorted, deduplicated
    $HOME/.charon/cache-index/first-rung.tsv.gz     every name -> the first held rung carrying it

`first-rung.lua` reads the merged file once and binary searches it, so a lookup costs a few
milliseconds regardless of how many rungs there are. `--rungs NAME` answers from the per-release
indexes instead, which is what tells you a release *between* two that carry a name may lack it.

Each per-release file opens with one header line carrying the release, the architecture, the source
it was read from, and the cache's **mtime and size**. That is the staleness key: a second run costs 50
header reads and nothing else, and a cache fetched again is a different index. Both are needed and
neither alone: a copy that keeps only the size, or only the time, of the file it replaces would go
unseen — the same rule `modules/apple/dyld.lua`'s `ladder_signature()` uses for its own kept
measurements.

## Cost, and when not to run it

One process at a time, one release at a time, and `build.py` renices itself **and its child** to 19,
so it is safe to start from a loaded session. A cold build over the 50 held rungs reads 24.6 GB once
and takes minutes. It is not a build, so it does not go through `coordination/heavy.sh`, but it is not
free either. Afterwards every lookup is a read of a few MB.

The index is keyed by the cache, so **nothing here is ever stale by construction**: a rung whose cache
moved is rebuilt on the next run, and `--force` rebuilds every rung (which is what you want after
changing `names.lua`).

## What is in the index, and what is not

`tools/cache-index/names.lua` reads, per release:

| source | what it gives |
| --- | --- |
| `__TEXT,__objc_methname` | every registered selector — where a selector name lives |
| `__TEXT,__objc_classname` | every class name, private ones included, plus `_OBJC_CLASS_$_` and `_OBJC_METACLASS_$_` for each |
| `__TEXT,__objc_methtype` | type encodings, which authors grep when a name is a type |
| `__TEXT,__cstring` | C string literals — a selector built by `sel_registerName()` from a literal lives here, not in methname, and this is what `strings` read |
| the export trie | every **exported** symbol, through `dyld.load()`'s own reading — the same reading `tools/release-split.lua` makes, so a public symbol's answer rests on `dyld.lua` and not on a second opinion of the trie |
| the whole symbol table | every **defined** symbol, public or private. Not redundant with the trie: a private class is not exported, and on the armv7 cache of 6.1.3 the trie alone misses 37313 `_OBJC_` symbols that `strings -a` does report, among them `_OBJC_CLASS_$_APKeychainUtilities` and `_OBJC_CLASS_$_APNetworksController` |

**Both spellings** of an ObjC name are emitted, because authors ask for either: `_OBJC_CLASS_$_Foo` and
`Foo`. One is the symbol a client binds, the other is the name in the facts, and a lookup answering
only one would send someone to the other to check.

Two things are deliberately **not** in it, and both are stated because a reader comparing against
`strings -a` will see them:

- **`_OBJC_IVAR_$_Class.ivar`** — the `Class.ivar` mangled spelling a category's ivar carries in some
  other image's symbol table. The **ivar name itself** is in the index (it lives in `__objc_methname`,
  measured), and `tools/release-split.lua`'s own exclusion list treats `_OBJC_IVAR_$_` as internal, not
  API. Grep the bare name.
- **Runs with a control byte, and runs of nothing but spaces** — 19826 and 292 of them respectively in
  the cache of 6.1.3. `strings` splits the first into several and reports the second as part of a
  longer run, so neither is a name; keeping them would put entries in the index that no lookup means.

## "First" means the oldest held release that carries it

The ladder is the port's own: `dyld.held_ladder({"armv7","armv7s"})` in `modules/apple/dyld.lua`, oldest
first, armv7/armv7s preferred and arm64/arm64e for the releases after armv7's last. The answer is the
**oldest held release that carries the name**, because that is the release a port of it must support.

It is **not** the release that introduced the name. A symbol CoreLocation exports in 4.0, lacks in 4.3
and 4.3.5, and has again from 5.0 reads `4.0` — and a release between two that carry it may lack it.
That is the same condition `tools/release-split.lua` refuses a file over, and the reason this tool
sits **beside** `release-split.lua` rather than replacing it: that one asks which release a *ported
object* may claim, this one asks what a *name* first appears in, and the two answer differently by
design.

A name no held release carries prints `NONE`. That is what a nonsense name, a misspelling, a framework
this port does not carry, and a name that arrived after 18.0 all look like; the tool does not guess
between them.

## Reading it

`first-rung.lua` takes names as arguments, or one per line on stdin (`--stdin` to take both; blank
lines and `#` comments are skipped, so a list file can be read directly):

    xmake l tools/cache-index/first-rung.lua _NSFileSize NSFileSize 'setObject:forKey:'
    printf '%s\n' _NSFileSize NSFileSize | xmake l tools/cache-index/first-rung.lua
    xmake l tools/cache-index/first-rung.lua --rungs MTKTextureLoader

`--self-test` is the positive and negative controls: `_NSFileSize` must read `3.0`, `MTKTextureLoader`
must read `9.0`, a nonsense name must read `NONE`, both spellings of a class must be present, every
rung in the table must be one the ladder holds, and `get()` must agree with a whole-table walk on a
spread of names across every block. A tool that answered a rung for a name no release has would pass
a positive control alone, so the negative one is not optional.

## The 3.0 vs 3.1.3 disagreement, and which is right: **3.0**

Three answers existed for the same name and they do not agree:

| answer | where it came from |
| --- | --- |
| `4.3` | the workspace's own notes |
| `3.1.3` | `strings -a CACHE \| grep -xF _NSFileSize` — the method this tool replaces |
| `3.0` | this index |

**3.0 is right, and here is the whole measurement.** The name is in the `Foundation` of iPhone OS
3.0, at byte offset 1534962, and the bytes around it are

```
b'issions\x00_NSFileReferenceCount\x00_NSFileSize\x00_NSFileSystemFileNumber'
```

so `_NSFileSize` is a complete NUL-terminated name, preceded by a NUL and followed by a NUL, sitting
between two other real names. Three independent measurements agree it is there and is a defined
symbol of that library:

| measurement | result |
| --- | --- |
| offset 1534962 falls in | `__LINKEDIT` (fileoff 1163264, size 709952) — the **symbol table string table** |
| `nm -gU` on that file | `38502664 S _NSFileSize` — a defined symbol, `S` (in a section), not `U` (undefined) |
| this index, `--rungs _NSFileSize` | present in **all 50** held rungs, 3.0 onward |

**And `strings -a` cannot see it**, which is the whole disagreement:

| on that one file | |
| --- | --- |
| `strings -a \| grep -xF _NSFileSize` | **0 matches** |
| `strings -a \| grep -F _NSFileSize` (substring, not exact) | **0 matches** |
| distinct `nm -gU` names in the file | 2061 |
| of those, absent from `strings -a` | **2060 — 99.95 %** |

The missed ones are real API: `_NSAMPMDesignation`, `_NSAffineTransformStructIdentity`,
`_NSAllHashTableObjects`, `_NSAllMapTableKeys`, `_NSAllMapTableValues`, `_NSAllocateCollectable`, and
`_NSFileSize` among them.

**The cause is one sentence: `strings(1)` does not read a Mach-O symbol table.** `__LINKEDIT` is where
a Mach-O keeps its symbol table, and the name is in the table, not in a string section — so there is
no run of printable bytes for `strings` to find, because the bytes around the name are the *string
table's* delimiters, not a C string. Every symbol-table name in a binary is invisible to the old
method; only the names that also live in a `__TEXT` string section (selectors in
`__objc_methname`, class names in `__objc_classname`, literals in `__cstring`) were ever visible to
it. That is why the old answer was not merely late, it was *wrong by a release*, and why the notes'
`4.3` is wrong too: it was inherited from the same scan.

So: this index reads the **whole symbol table** (the export trie for what a client binds, and the full
defined-symbol range for what is there at all), which is what `__objc_protolist` and the rest of the
Objective-C metadata sit next to. A reader that changes the extraction should re-run the 2061/2060
count above: it is the number that says whether the index is a superset of what it replaces.

**The negative control is what makes the positive one mean anything**: a name in no release must
answer `NONE`, or a tool that answered a rung for everything would pass the first line alone.

## Licence and provenance: nothing is borrowed

Written for this repository; **no third-party code, no vendored source, no copied algorithm.** The
things it uses are all already in the tree or in the base system, and each is named where it is used:

| used | from | why |
| --- | --- | --- |
| `dyld.open_cache`, `dyld.load`, `dyld.held_ladder` ordering | `modules/apple/dyld.lua`, this repository | the cache format, the export trie, the ladder |
| `macho.read`, `macho.images`, `macho.image` | `modules/apple/macho.lua`, this repository | Mach-O load commands, segments, sections, symbol tables |
| `gzip` / `zlib` (GzipFile, `decompressobj`) | CPython standard library | the compressed index |
| `bisect` | CPython standard library | the search |
| `nm -gU`, `otool -ov` | cctools, base system | measurements quoted above, never in the tool's own path |

`names.lua` is the only file that reads a cache, and it does so by calling the two modules above: it
parses no Mach-O and no shared-cache structure of its own. Its two loops -- over `.sections` and over
a symbol table -- are the loops `macho.lua`'s `text_literals()` and `dyld.lua`'s `cached_library()`
already make, widened and pointed at a different address space; the reasons they cannot simply be
called are in the file's own header.

The measurements in this file come from the machine this was written on: `strings`, `nm` and
`stat` are base system tools, and the numbers are reproducible with the commands shown.

## Reuse, not a second parser

`names.lua` imports `modules/apple/dyld.lua` and `modules/apple/macho.lua` and calls
`dyld.open_cache`, `dyld.load`, `macho.read`, `macho.images` and `macho.image`. Every byte of Mach-O
and shared-cache parsing is theirs. The new code is two loops: one that walks `.sections` and takes the
NUL runs (the walk `macho.lua`'s own `text_literals()` does for a `__cstring` of a plain binary, and
which cannot be called because it takes a binary path and reads the file as one image — a shared
cache's header is `dyld_v1` and its images sit at the addresses the image table names), and one that
takes a whole symbol table (`dyld.lua`'s own `cached_library()` over the **external range only**,
widened). Neither re-implements a parser.

`build.py` restates only the directory walk and the architecture preference order, because the ladder
is Lua and `build.py` is python3. It calls `names.lua` for the reading.
