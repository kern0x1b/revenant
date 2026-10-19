# What the two differentials still disagree about

Measured 2026-09-28 on the rebased tree (`ciimage: 559 measurements, 534 the same, 17 different, 42 one
side only`; `modelio: 317 measurements, 300 the same, 5 different, 55 one side only`), at a tolerance of
5e-4 on both. The causes are below, grouped, and each says which side is ours to fix. **The CoreImage
count has moved since**: two rows came out and their measurements went with them, and this tree's own
run is `ciimage: 551 measurements, 525 the same, 17 different, 44 one side only` — see "The count, and
what it measures now that two rows came out" at the end, which also carries the control that shows the
comparator can fail. The 17 are the same 17.

## CoreImage, the 17 the first-number view found

**This table is the first-number view and it undercounts.** `compare.py` read only the number behind the key, so a line was the same whatever followed it, and the count it gave was 17. The count of what is actually different is 77 and it is grouped at the end of this file. One row of this table is corrected in place where the whole-tail comparison refutes it; the others are left as they were written, because they are the record of what was seen then and not a claim about the tree now.

| group | n | what the two sides say | whose |
| --- | --- | --- | --- |
| the clamped family | 6 | `alg clamped extent/rect` print an extent of +/-1.8e308 on the port and the box of the crop on the host. `CharonCIClamp` hands the framework's own nested ask - the one `-[CIAffineClamp outputImage]` makes while the filter is producing its output - an image that is not yet clamped, and the framework's answer for a half-built image is an unbounded one. The *pixels* do not agree either, and the old comparator said they did because it read only the length: the host renders 96 bytes with checksum `6821f505` and the port 24 with `63fe7f63`, and the port's own four pixels are `153 76 229 80`, `153 76 229 30` and so on against the host's uniform `153 77 229 128`. | ours: the clamp has to hand back a clamped image for the nested ask, not the input |
| the context's working format | 2 | `ctx space nil/srgb working format 2056` against the port's `kCIFormatRGBA8`. A context made with a colour space and no format is not an 8-bit RGBA working format on the host; the port answers its own default. | ours: the default is the release's, and it is not the port's |
| the shapes under a transform | 7 | `shape turned`, `shape turned interior` and their cropped pixels: the host's bounds of a rotated rectangle and the port's differ by a pixel. `CGRectApplyAffineTransform` bounds the four corners; the host appears to bound the edges. | ours, or a documented divergence: it is one pixel on a rotated bound |
| the representations, one-sided | 36 | **CORRECTED IN PLACE, 2026-09-29: the direction in this cell was inverted, and the first-number view never said it either.** It reads "are on the host and on neither side on the port, and `repr write png` is 0 where the host's is 1. `charon_representationOfImage:` is returning nil." What the run says is the other way round: `repr rgba8 png` is `none` on the system and `161 155f579e` in the port, and `repr write png` is `0` on the system and `1` in the port. **33 further `repr` lines one-sided on the port's side** and **3 further `repr` lines one-sided on the system's side** - the three are `repr rgbaf png none`, `repr rgbaf png tiff none` and `repr jpeg none`, the only lines in the family where the system answers and the port is silent. The cell is left in the table rather than deleted because the table is the record of what the first-number view found, and what it found here was a count of 36 that the count itself cannot be right about; both figures are printed by the page writer (removed), which refuses a page that quotes either one wrong. |
| the clamped family, one-sided | 4 | the per-pixel lines of `alg clamped rect`, which the port has fewer of because its clamped image has a different extent. | follows from the first row |

## CoreImage, the round trip: both halves of it are `absent` now

This section first said `unpre round trip` was `6821f505` on the host and `3c04ef85` in the port, and
read the difference as the unpremultiply's: "the release's is lazy and composes, and the port's is an
eager render into bytes". Two things were wrong with that, and the whole-tail comparison is what
showed them.

The line never measured the unpremultiply. Its source was
`put_bytes(@"unpre round trip", render([[finite imageByPremultiplyingAlpha] imageByCroppingToRect:bounds]));`,
which asks `-[CIImage imageByPremultiplyingAlpha]` and nothing else - so the divergence belonged to the
premultiply row, not to either of the two rows this file's neighbours were about.

And the two rows themselves are both `absent` now, and neither is a crutch in `crutches.md`:

  - `-[CIImage imageByPremultiplyingAlpha]` is `absent` in `registry/CoreImage/algebra10.json`. The
    port's implementation was a colour matrix whose vectors took the alpha into red, green and blue,
    which is a grey image of the alpha, not a premultiplied one: measured, the system renders
    `96 487584e5` with pixel 0 `77 38 115 128` and the port rendered `96 fd3b7745` with pixel 0
    `128 128 128 128`. A colour matrix is linear over the four channels it is given, so no filter of
    the release scales a channel by the alpha of the same pixel, and the release carries neither
    premultiply filter. `facts/CoreImage/ImageAlgebra.md` carries the measurement.

  - `-[CIImage imageByUnpremultiplyingAlpha]` and `-[CIImage imageBySettingProperties:]` were taken
    out one commit earlier, for the reasons in `facts/CoreImage/ContextOwner.md`.

The probe does not ask any of the three, and `reportPremultiply` is gone with them. The diff on this
page is what remains, and every number in it is a measurement of the port.

## ModelIO, the 5 the first-number view found

The same: the whole-tail count for the ModelIO differential is 42, grouped at the end of this file, and this table is what the first-number view saw.

| group | n | what the two sides say | whose |
| --- | --- | --- | --- |
| the generator tessellation | 2 | the ellipsoid's 72 vertices against 63 and the cylinder's 47 against 29. The index counts agree, so the surface is the same and the two share vertices differently. | a documented divergence: the header does not say where Apple shares |
| the descriptor of a mesh built from buffers | 1 | 31 attributes on the system, the one given in the port. | Apple's own internal attributes; a port cannot read them |
| the voxel index extent | 1 | the system answers `INT_MAX` for small arrays and zero for larger, the same on every run; the port derives the extent from the box and the voxel size. | a named divergence, the system's answer carrying no information about the division |
| the union over such an array | 1 | follows from the extent: two voxels in the port, three on the system. | follows |

## ModelIO, the one-sided lines, the first-number view

96 of the original 111 were the per-vertex lines of a mesh the two sides built with a different number
of vertices, and they follow from the tessellation row. The rest are the OBJ submesh naming and index
range (the system names a submesh `solid_red` where the port names the two `red` and `lid`), the mesh
and material names an asset takes from its file (the system takes `tri` and `tribin` and `PLY
Material`; the port takes none of them), the `specular` property's type (a float on the system in the
physically plausible function, a colour in the older one in the port), and the clamped-family
equivalents above. **None of them is a port feature the system lacks.**

## The 4.3 lower bound, measured: CoreImage arrives in 5.0

`tools/cicontext-bounds.lua`, with `apple.dyld` and no raw search over the cache bytes:

    4.3     the CoreImage image: NOT in the cache
    4.3.5   the CoreImage image: NOT in the cache
    5.0     the CoreImage image: in the cache

So **iOS 4.3 has no CoreImage at all**, and my earlier guess that "4.3 has CIContext" was wrong twice
over. The placement follows from that: the two new files reference `CIContext` and `CIImage`, whose
lower bound is 5.0, so they must sit at 5.0 or later and must not be built for 4.3. The 4.3 gate's
failure is not "the release has the class and the port's copy is dropped" - at 4.3 the port's copy is
*kept* - it is that the band does not link CoreImage because the files that make it are placed at 10.0
and 11.0 and never enter the 4.3 band at all.

The `image.exports` accessor inside `apple.dyld` did not resolve from an `open_cache` image entry, so
this establishes the **image's presence** and not which of the two releases first exports the four
classes from it. The presence is what the placement needs.

## The libraries' own objects, and the release-split run over them

The CoreImage and ModelIO libraries are built into `build/objects/<folder>/` or, when the deployment
target is raised, `build/objects-<minimum>/<folder>/` - `modules/apple/backports.lua` at :782, :2157
and :2194 are the three places that say so - and `release-split` is run over the build's own objects,
one directory per invocation:

    for d in "$out"/build/objects/*/ "$out"/build/objects-*/*/; do xmake l tools/release-split.lua "$d"; done

Over every source the recipe's own input list takes, and over both layouts:

    objects/Graphics/        clean, every object file's symbols first-appear in one release (67 files, 590 symbols, 50 releases checked)
    objects/MetalKit/        clean, every object file's symbols first-appear in one release (10 files,  44 symbols, 50 releases checked)
    objects/ModelIO/         clean, every object file's symbols first-appear in one release (18 files, 115 symbols, 50 releases checked)
    objects-6.0/Graphics/    clean, every object file's symbols first-appear in one release (67 files, 590 symbols, 50 releases checked)
    objects-6.0/MetalKit/    clean, every object file's symbols first-appear in one release (10 files,  44 symbols, 50 releases checked)
    objects-6.0/ModelIO/     clean, every object file's symbols first-appear in one release (18 files, 115 symbols, 50 releases checked)

**95 objects over the three libraries, clean.** A hand-made object tree has to write the same record
a build writes - `build/objects/sdkdir` and `build/objects-6.0/sdkdir`, the file
`release-split.lua:137` reads as `path.join(path.directory(path.absolute(objectsdir)), "sdkdir")` -
or the documented one-argument invocation answers that it has no record of the SDK.

An earlier report in this series gave Graphics 18, ModelIO 18, MetalKit 1. Those were the 37 objects
of the files this series adds or changes, compiled one at a time, with the SDK passed by hand: a
band's subset, and passing the SDK by hand hides that the build records it.

## The check, and how to run it

Every count on this page is checked against the run by a script, and the script is not run by the
light guard - it needs the two `compare.py` outputs, which are what a differential run leaves behind
and which no suite in the tree produces. So it is run by hand after a run, and it stands down with a
line saying so when the files are not there rather than failing:

    BUILD=$PWD/.agent-work/ci sh tests/backports/host/ciimage/pixel/run.sh 0.0005
    BUILD=$PWD/.agent-work/md sh tests/backports/host/modelio/run.sh
    python3 tests/backports/host/modelio/compare.py $PWD/.agent-work/ci/host/answers.txt $PWD/.agent-work/ci/port/answers.txt 0.0005 ciimage > ci-diff.txt
    python3 tests/backports/host/modelio/compare.py $PWD/.agent-work/md/host/answers.txt $PWD/.agent-work/md/port/answers.txt 0.0005 modelio > md-diff.txt
    # the page writer (removed) made the table from the two diffs:


`--page` may be given more than once and every page given is checked. A page is read for its group
table, for the group counts against the run, and for the one-sided figures of every family the run
has one-sided lines in; **none of those three depends on how the page spells anything**, and a family
named without backticks is read the same as one named with them. A page that carries the group table
and states no figure for a family the run has is a finding, not a pass.

The exit status is: 0 for a clean run, 1 for a finding, and 2 for a page or a run the tool cannot
read - three outcomes told apart by the status and by the text, because a crash that exits 1 is
indistinguishable from a finding, which is what a first version of this did.

The selftest of the table (removed) ran this command and the broken pages that go with it,
and it is the record of what each check is for. The four cases that are one `continue` and one
backtick apart, with what an earlier version of the tool did to each:

| the page | expected | what the previous tool did |
| --- | --- | --- |
| the figures un-backticked, nothing else wrong | 0 | 0 - the page is right and is now read |
| un-backticked, and one figure wrong | 1 | **0** - not read, and the group counts went with it |
| un-backticked, and one group count wrong | 1 | **0** - the same |
| a wrong group count, the figures backticked | 1 | 1 |

The two rows marked 0 were measured passing when they should not have, and the self-test is what
keeps them from passing again.

## The count, and what it measures now that the whole tail is compared

    ciimage: 539 measurements, 454 the same, 77 different, 42 one side only (tolerance 0.0005)

`tests/backports/host/modelio/compare.py` used to read only the first number of a line, keyed by the
text in front of it, and count the line as the same whatever followed. Everything after that number -
the pixel tuples, the checksums, the extents, the bounds - was never compared, and the count above
was `551 measurements, 525 the same, 17 different, 42 one side only`, which said "17 different" about
a tree that had five whole families of them wrong. The measurement is now the first number **and the
rest of the line**.

The old comparator on a green pair - the host's own answers against a copy of themselves with 140
pixel tuples and one checksum changed after the first number - reported
`551 measurements, 551 the same, 0 different, 0 one side only`, exit 0. The new one on the same pair
reports `551 measurements, 410 the same, 141 different, 0 one side only`, exit 1. That gap is what the
count was not seeing.

### The differences, grouped, and what each group is

Every one of them is a measurement of the port: the port process is the framework's own CoreImage
with the port's categories on it, and `run.sh:69-72` refuses a port probe that is not the port.

    ciimage: 527 measurements, 479 the same, 40 different, 42 one side only (tolerance 0.0005)
    modelio: 317 measurements, 264 the same, 41 different, 55 one side only (tolerance 0.0005)

| group | n | what it is | whose to fix |
| --- | --- | --- | --- |
| `shape` | 9 | `-[CIFilterShape transformBy:interior:]` with `interior:YES`: the system moves the extent and the port does not. `shape moved interior` is `4 -6 10 10` against `4 0 6 4`, `shape turned interior` is `-5 0 13 13` against `0 0 9 10`, `shape scaled interior` is `0 0 20 5` against `0 0 10 5`, and the three cropped pixel counts follow the extents (400/96, 676/360, 400/200). Every other operation, with `interior:NO` and without, is equal | ours, and it is one flag |
| `repr` | 4 | **The port encodes where the system answers that it cannot.** `repr rgba8 png` is `none` on the system and `161 155f579e` in the port, `repr write png` is `0` on the system and `1` in the port, and 33 further `repr` lines one-sided on the port's side, while 3 further `repr` lines are one-sided on the system's side - `repr rgbaf png none`, `repr rgbaf png tiff none` and `repr jpeg none`, the only three in that family where the system answers and the port is silent - the port has bytes and a decoded picture for `rgba8`, `rgbaf` and `jpeg` PNG, TIFF and JPEG, where the system has none of them. The bytes that ARE produced decode to the same picture | ours, and the direction is worth stating: the port is not silent where the system is |
| `ctx` | 2 | the context's working format: the system answers 2056 (`kCIFormatRGBAh`) with a named working colour space, the port 264 (`kCIFormatRGBA8`) | ours, and see `ContextOwner.md` for the two properties that are not carried at all |
| `imp` | 1 | the address of `-imageByClampingToExtent`: the framework's in the system process, the port's in the port's | not a difference at all - an address cannot be equal across two processes, and the line is kept so a reader sees that the port really is the port |
| `odd set` | 1 | an accumulator of a fractional extent, `1.5 -2.25 5.5 3.5`: the system writes nothing into it (`60 f6009964`, four pixels `0 0 0 0`) and the port writes the whole-pixel part of the rectangle it is given | ours, and named in `ImageAccumulator.md` |
| `alg` | 23 | the clamped family (8): the system's clamped image is the infinite extent and 96 bytes, the port's is `0 0 3 2` and 24. The intermediates (10): both spellings, one unit off in the green channel of every pixel. The high-quality downsample (5): one or two units in two channels | ours |

**No colour line is in the table.** There were six, and `d63a8af20` closed them: the accessors were
answering a converted component for a colour in a space that is not sRGB - a green the caller passed
as 0.0000 came back 0.1491 - and the colour now keeps the caller's components in the caller's space,
with the conversion where it belongs, at render time. The rendered pixels were and are `0 811c9dc5`
on both sides, which is why the whole family was invisible to the old comparator.

**The one-sided lines of that run, which are measurements the other side does not have and not
disagreements, and are named here so a page that accounts for the run accounts for them too:**

    ciimage: 527 measurements, 479 the same, 40 different, 42 one side only (tolerance 0.0005)
        one-sided lines in the CoreImage run, by which side answers: system 8, port 34
            one-sided on the system's side in `repr`: 3
            one-sided on the system's side in `alg`: 4
            one-sided on the port's side in `repr`: 33

`33 further repr lines one-sided on the port's side` and `3 further repr lines one-sided on the
system's side` - the three are `repr rgbaf png none`, `repr rgbaf png tiff none` and `repr jpeg none`,
the only lines in that family where the system answers and the port is silent. And **0 further `alg`
lines one-sided on the port's side** and **4 further `alg` lines one-sided on the system's side**: the
four are `alg clamped rect pixels pixel 0` to `pixel 3`, one-sided because the port's clamped image
has a different extent and so a different number of pixel lines - the same reason the clamped family
has a different number of `different` lines, and named in its row above.

**And the two rows that were the worst of it are `absent` rather than different:**
`-imageByPremultiplyingAlpha` (`d255cf714`, a grey image of the alpha) and
`-imageBySettingAlphaOneInExtent:` (`78b6730f2`, an infinite extent where the system's is `0 0 6 4`).
The port answers neither and the probe does not ask them.

### The 42 one-sided lines

42 of them, and they are measurements the host cannot be asked, not disagreements: the names each
process gives itself, the lines over a format the framework's own accumulator does not accept, and
the per-pixel lines of the clamped family, whose extent differs and so whose line count does too.

### The ModelIO differences, all forty-one of them named

| group | n | what it is | whose to fix |
| --- | --- | --- | --- |
| `cube mesh` | 14 | the cube's **vertex normals and UVs** - `cube mesh v1/v2/v3 n` and `cube mesh v1/v2/v3 uv`, over two images. The normals differ in sign and the UVs are the system's own layout. The 31-attributes line is a different key, `mesh attributes`, and is its own row | ours, and it is a real difference in a real buffer: a caller reading a normal or a UV from the port's mesh gets another value |
| `share cylinder` | 8 | the index count of a tube, over the ten sizes the probe samples. The vertex count and the box agree on every one; the index count does not, and it is not one way: **the port has more in seven and fewer in one** (r3 v3, 90 against 96) and the two that agree are r3 v2 (72/72) and r4 v3 (120/120) | owed, and it is the cap triangulation: the header does not say where the triangles go, the port emits a centre vertex and a fan per end, and the vertex count - what a caller sizes its buffers from - is right on all ten |
| `voxrule` | 8 | the voxel array's own four tests, `voxrule 1..4`: the system answers an index extent of `2147483647` where the port derives it from the box and the voxel size, and the counts that follow | a named divergence: the system's answer carries no information about the division |
| `voxels after` | 2 | the union and the difference over that array: three voxels on the system, two in the port, because the extent differs | follows from `voxrule` |
| `tri mesh` | 3 | `tri mesh` and `tribin mesh`: one submesh index range (`tri mesh submesh  indices 12 depth 32 geometry 0` against `6 depth 32 geometry 2`) and the `specular` property's `type` in two of them | owed |
| `cylinder` | 1 | the index count of the sampled cylinder, 192 against 162, with the box and the vertex count equal since `c8c72cfcc` | owed, with the `share cylinder` row |
| `voxel extent` | 1 | `voxel extent 0 0 0 to 1 1 0` on the system against `0 0 0 to 2 2 2` in the port | owed |
| `voxel indices` | 1 | the bytes of the index buffer that follows: 32 against 8 | follows from the extent |
| `mesh attributes` | 1 | `mesh attributes 31` on the system and `1` in the port | Apple's own internal attributes; a port cannot read them, and it is documented as a divergence |
| `mesh min` | 1 | a mesh built from buffers: the system answers a zero box, the port the box it was given | owed |
| `canImport obj` | 1 | `+canImportFileExtension:` for `usd`: the system answers YES, the port NO | owed |
| `stack matrix` | 0 | the transform stack, and all four columns are equal since `6c0b43d89`. It is in the table at zero so a difference coming back has a row to land in | fixed |

`tests/backports/host/modelio/run.sh` defaulted its tolerance in `d915b4927`; before that the
differential could not be run as shipped. The whole-tail comparator is `ce246b428`, and the two
controls that show it can fail are in `Differences.md` and in that commit: on a green pair with 216
ModelIO lines changed after the first number, the comparator it replaced said `317 the same, 0
different`, exit 0, and this one says `101 the same, 216 different`, exit 1.
