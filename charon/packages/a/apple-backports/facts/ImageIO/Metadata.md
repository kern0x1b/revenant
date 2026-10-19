# The metadata tag container of iOS 7, on a release whose ImageIO has no metadata tree

`CGImageMetadata` and `CGImageMetadataTag` arrived in iOS 7. iOS 6.1.3 and 4.3 have neither the
container nor the tags, and they are carried in `.gen/ImageIO/ImageIOMetadata7.m`, written from `spec/ImageIO/property-map.tsv`.

## Why the whole surface is one object

`tools/cache-index/first-rung.lua`, asked for each of the 26 `CGImageMetadata*` and `CGImageSource*`
symbols the iOS 7 headers declare, over the 50 held rungs (2026-09-30,
`.agent-work/runs/io-rungs.txt`): **every one of them first appears on the 7.0 rung** and on no rung
below it. The three rungs below 7.0 that carry the ladder's low end - 3.0, 4.0, 4.3, 5.0, 5.1.1,
6.0, 6.1, 6.1.3, 6.1.4, 6.1.6 - carry none of them. So one object holds all 26 and `release-split`
has nothing to split.

What iOS 6 does export is used, not defined: `CGImageSourceCopyMetadataAtIndex` and the eight
`kCGImageMetadataNamespace...` names are the release's own (`registry/ImageIO/exported.json`,
`facts/ImageIO/ImageIOExports.md`), and the prefixes are carried as strings by
`Graphics/ImageIONames70.m` and `Graphics/ImageIONames113.m`. The default-prefix table in the object
asks which public namespace constant the caller passed, so no namespace URI is written in this
library at all.

## What the host answers, and where the port differs

`tests/backports/host/imageio-metadata/` is the differential: `cases.m` is compiled twice, once
against the host's own ImageIO and once against this object, and `run.sh` compares the two outputs
line by line. Measured 2026-10-03, after the image-property bridge arrived here:
`imageio-metadata: 2195 cases compared, 2 declared differences, mutation RED`.

**A function has one name in both libraries, so the two builds are two programs.** Linking this
object and the host's ImageIO into one program cannot be done - the linker sees one definition twice -
which is why the port's own object is read out of the executable by `dladdr` and the run fails if any
of these functions is still ImageIO's. That check is in the port build itself, not assumed.

`tests/backports/host/imageio/run.sh` is not a differential for this family and never was: it links
the host's ImageIO on both sides of all five of its checks, so it compares the host with itself. The
four `ImageIO` name pages that carried headline counts named no harness at all.

### A tag created with a NULL prefix takes the public prefix of its namespace

`CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, "Name", ...)` answers `prefix=exif`,
and the same for all ten public namespaces (`default-prefix exif..xmpRights`, ten cases, both builds).
A namespace with no public prefix and no prefix of its own cannot be resolved, and the port answers
NULL - which is the one declared difference:

| case | host | port |
| --- | --- | --- |
| `tag unknown-ns-no-prefix` | a non-NULL tag whose every accessor answers nil and whose type is `-1` | NULL |

The port follows `CGImageMetadata.h`: "Returns NULL if a tag could not be created with the specified
parameters."

### `kCGImageMetadataTypeDefault` reads the type off the CFType of the value

`default string 1`, `default number 1`, `default array 3`, `default dictionary 6`, both builds. A
number becomes a string, as the host does.

### An array's or a structure's bare strings become tags, and an array element is named by its position

`value default array elements`: a tag built from `@[@"a", @"b"]` answers an array of two
`CGImageMetadataTag`s named `[0]` and `[1]`, in the tag's own namespace and prefix; a structure's
value answers `{F = <tag F>}`. The header says the elements "must be either a CFStringRef or
CGImageMetadataTagRef"; the host resolves a bare string into a tag, so the port does the same.

### The two opaque types are identified, and anything else is refused

iOS 6 exports `CGImageSourceCopyMetadataAtIndex` and answers an object of the **release's own class**,
which is not a metadata container this library laid out. Every entry point asks `CFGetTypeID` first
and answers NULL for anything else (`PORTONLY foreign-tag`, `foreign-metadata`, `foreign-copy`), so a
caller that mixes the release's metadata with this container is told no instead of being made to read
memory that is not ours.

The host traps (SIGTRAP) on the three `_Nonnull` arguments `CGImageMetadataTagCreate` declares
(`xmlns`, `name`, `value`); the port refuses with NULL, and those three refusals are recorded as
port-only records because there is no host answer to compare.

## What this commit does not carry

Nine `CGImageMetadata*` functions of the same iOS 7 surface - the path, matching, enumeration and XMP
half - arrive in the next commits of this slice, and their registry rows still say `absent`. What is
refused here and why is in each row.
## The path half (the second commit of this slice)

Seven more functions of the same iOS 7 surface arrive with it, and the differential grows from 33 cases to
89: `set`/`string`/`tag-at` for eight paths (a string, a number, a field of a structure, an array, an
element of it, an unregistered prefix, an unknown namespace, a path with no prefix at all), a tag set
through `CGImageMetadataSetTagWithPath`, a parent tag and a write inside it, three removes, four
registrations and the paths an enumeration gives its block for.

What the measurement decided, each of which the port does:

- **A path with an unregistered prefix fails** (`set unregistered 0`), and so does an unknown namespace
  and a path whose first step names no prefix at all. `CGImageMetadata.h`: "Creating tags will fail if a
  prefix is encountered that has not been registered."
- **The containers a path needs are made** ("All tags required to reach the final tag will be created, if
  needed. Tags will be created with default types (ordered arrays)"): a field becomes a structure, an
  index becomes an ordered array, and the tags made on the way carry the namespace and prefix of the step
  that named them.
- **A tag a path hands back is a copy, value included**, so changing it does not change the container,
  which is what the header's warning about committing a changed parent asks of the caller.
- **`CGImageMetadataCopyTags` hands out copies too** ("a shallow copy of all top-level tags") and in the
  host's order: by name, then by prefix. A tag named `Made` added to a container holding `Flash`,
  `Orientation` and `subject` answers second on the host, not last.
- **Registering a prefix again is a re-registration, not a refusal.** The host answers `true` and hands
  back no error for a second registration of the same prefix to another namespace, so the port does the
  same; `kCGImageMetadataErrorPrefixConflict` is named by the header but the host does not raise it here,
  so the port does not invent it.
- **Writing into a parent tag changes the parent, not the container**, and a parent holding a scalar grows
  a structure to hold the new child - both measured: after `SetValueWithPath(metadata, parent, "RedEyeMode")`
  the host's container is unchanged and the parent answers `on`.

Two declared differences are on top of the one above, both in
`tests/backports/host/imageio-metadata/known-differences.txt`: a tag created for a namespace with no prefix
answers NULL rather than a degenerate tag, and `CGImageMetadataCopyStringValueWithPath` on a tag holding an
array answers NULL rather than the array's first element.

### Two shapes the port had to be taught by the host

- **The prefix of a path is matched by text, not by pointer identity.** The public prefixes are constants
  (the release's own, or `Graphics/ImageIONames70.m`'s), while the prefix inside a path is a string this
  library made by parsing; the first version compared pointers and refused every path, which the harness
  showed as `set string 0` against the host's `set string 1`.
- **A path step travels as a dictionary, not as a C struct.** A struct of ARC-managed fields passing
  through a function and an `NSValue` made clang emit three copy/destroy helpers with external linkage;
  `tools/release-split.lua`'s exclusion list covers the `___copy_helper_block_*` family and not those, so
  they would read as API symbols of a file that has none.

## What this slice does not carry

`CGImageMetadataCreateXMPData` and `CGImageMetadataCreateFromXMPData` are the XMP half of the same iOS 7
surface, and `CGAnimateImageDataWithBlock` and `CGAnimateImageAtURLWithBlock` the animation pair. Their
registry rows still carry the reason main gave them, which is not a decision this slice made; what each
needs is named in the delivery. The image-property half is not among them: the two
`...MatchingImageProperty` functions arrived here on 2026-10-03 and are measured below.

## The rows that are decided, not carried: the release's own objects

Six of the thirty rows take or hand back an object ImageIO itself owns, and on iOS 6 there is no public way
to reach inside one. `registry/ImageIO/absent_ImageIO.json` carried them as `absent` with the reason "the
function arrived in iOS N, and nothing in iOS 6 has what it names", which is not a decision: it is the
sentence a row gets before anyone has asked what the port could do about it.

What settles them is one measured fact each, from `tools/cache-index/first-rung.lua` over the 50 held rungs
(2026-09-30, `.agent-work/runs/io-rungs.txt`), and the shape of the objects:

| row | first held rung | decision |
| --- | --- | --- |
| `CGImageDestinationAddImageAndMetadata()` | 7.0 | absent |
| `CGImageDestinationCopyImageSource()` | 7.0 | absent |
| `CGImageSourceRemoveCacheAtIndex()` | 7.0 | inert, and it says so once |
| `CGImageDestinationAddAuxiliaryDataInfo()` | 11.0 | absent |
| `CGImageSourceCopyAuxiliaryDataInfoAtIndex()` | 11.0 | absent |
| `CGImageSourceGetPrimaryImageIndex()` | 12.0 | absent |

The reason is the same in the five `absent` rows: the release's `CGImageDestinationRef` and
`CGImageSourceRef` are objects of its own private classes, and the release exports no other symbol that
reads or writes their internal state. Its own `CGImageSourceCopyMetadataAtIndex` hands back an object of
its own private class, and there is no public call that converts it to or from anything else - so a metadata
container this library made cannot be given to the release's destination, and the release's destination
cannot be asked which source or which primary frame it holds. Carrying them would mean carrying the
release's whole ImageIO object model, which is a different port and not this row.

`CGImageSourceRemoveCacheAtIndex` is the one that is safe to accept and do nothing: it asks the release to
free memory it is holding for itself, nothing is written or dropped from the file, and the memory stays
memory the release was already keeping. That is the registry README's own case for `inert` - "a hint to a
scheduler it does not run". It is built, and it logs one line the first time it is called, which
`tests/backports/host/imageio-metadata/run.sh` counts in the port's own stderr and which a planted change
to that line empties, so the claim is checked rather than asserted.

### One limitation, stated because a caller can trip over it

`CGImageMetadataTagGetTypeID` answers `CFDictionaryGetTypeID`. iOS 6's SDK ships no `CFRuntime.h` and no
`CFTypeRegisterStruct`, so a new CF type cannot be registered the way one is on a newer release, and the tag
this library makes is a dictionary carrying a marker. Every entry point here therefore checks the marker as
well as the type id, and refuses an object without it - which is why the three `PORTONLY foreign-*` records
answer NULL. The consequence for a caller is that the type id alone does not tell a tag from a dictionary
of its own: `CFGetTypeID` on an `NSDictionary` the caller made answers the same number. This is a
limitation of the release's public CF surface, not a shortcut in the check, and it is written here so that a
caller deciding between `CGImageMetadataTagGetTypeID` and the marker knows what the number is worth.

## The image-property bridge: the whole table, measured (measured 2026-10-01, carried and corrected 2026-10-03)

`CGImageMetadataCopyTagMatchingImageProperty` and `CGImageMetadataSetValueMatchingImageProperty` map a
(kCGImageProperty dictionary, property) pair onto an XMP tag. `CGImageMetadata.h:520-580` says what the
mapping is and says it is partial: "Metadata Working Group guidance is factored into the mapping of
CGImageProperties to XMP compatible CGImageMetadataTags. For example, kCGImagePropertyExifDateTimeOriginal
will get the value of the corresponding XMP tag, which is photoshop:DateCreated" and "Not all dictionaries
and properties are supported at this time."

So neither function is a search over the names in a tree. Both are ONE LOOKUP in a table of 357 rows, and
the table is measured rather than transcribed: `tests/backports/host/imageio-metadata/table.sh` asks the
host's own `CGImageMetadataSetValueMatchingImageProperty` to write a value for each of the **518**
(dictionary, property) pairs the SDK's own `CGImageProperties.h` declares - one process per pair, because a
pair the host cannot answer for has to be recordable on its own - and reads the tag it wrote back out of the
tree. The row IS what the host answered. `tools/gen/property_map.lua` writes the table into
`.gen/ImageIO/ImageIOMetadata7.m` from that run.

    PAIRS: 518, generated from the SDK's CGImageProperties.h by tools/gen/property_map.lua
    TABLE: 518 pairs, 357 the host maps, 161 it does not, 0 TRAP it (SIGTRAP)
    AGREE: 357/357 answer the tag the set wrote, 357/357 answer it in a fresh tree, 357/357 answer NULL in an empty one
      167     http://iptc.org/std/Iptc4xmpExt/2008-02-29/ Iptc4xmpExt
       94     http://ns.adobe.com/exif/1.0/ exif
       21     http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/ Iptc4xmpCore
       18     http://ns.adobe.com/photoshop/1.0/ photoshop
       15     http://ns.adobe.com/tiff/1.0/ tiff
       13     http://cipa.jp/exif/1.0/ exifEX
       12     http://purl.org/dc/elements/1.1/ dc
        9     http://ns.adobe.com/exif/1.0/aux/ aux
        7     http://ns.adobe.com/xap/1.0/ xmp
        1     http://ns.adobe.com/xap/1.0/rights/ xmpRights
      NOT MAPPED by dictionary: 66 {DNG} 27 {TGA} 25 {IPTC} 18 {PNG} 8 {GIF} 6 {WebP} 6 {HEICS} 5 {JFIF}
    imageio-table: 518 pairs, 357 mapped, 161 not mapped, 0 trapped

**The 161 pairs the host does not map are the header's own sentence about a partial table, by name.** Every
JFIF, GIF, HEICS, WebP, TGA and DNG property is among them, along with 18 of PNG's, 25 of IPTC's and 66 of
DNG's - while every one of the 76 Exif, 32 GPS, 20 TIFF and 9 ExifAux properties IS mapped. The set
direction answers false and writes no tag for those 161, and the lookup answers NULL, which is what "not
supported at this time" means. GPS mapping 32 of 32 into `exif:*` is also why every GPS property answers at
no name of its own below: its XMP tag is not called after it.

**No rule of thumb produced these rows, which is why this is 357 measurements and not a convention.** Twelve
TIFF and IPTC properties land in `dc:*` and seven in `xmp:*` out of the same dictionaries;
`kCGImagePropertyExifDateTimeOriginal` is `photoshop:DateCreated` while `kCGImagePropertyExifDateTimeDigitized`
is `exif:DateTimeDigitized`; `kCGImagePropertyExifISOSpeed` is `exifEX:ISOSpeed` (the CIPA namespace
`http://cipa.jp/exif/1.0/`, not Adobe's exif one); and `kCGImagePropertyExifLensSerialNumber` is
`exifEX:LensSerialNumber` while `kCGImagePropertyExifAuxLensSerialNumber` is `aux:LensSerialNumber` - the
same name in two namespaces, which is the fact the next paragraph is about.

**The host's own two functions agree with each other on all 357 rows**, which is what makes this one table
and not two: after the set direction wrote its tag, the lookup answers that tag in that tree, and it also
answers it in a fresh tree holding only that tag, and it answers NULL in an empty tree. `table.sh` asserts
all three counts, so a host that stopped agreeing would be visible there and not only in the port's diff.

### Three rules the table does not say, each measured and each in the differential

- **The namespace is part of the match.** A tree holding `exifEX:LensSerialNumber` answers NULL for
  (`ExifAux`, `LensSerialNumber), and one holding `aux:LensSerialNumber` answers NULL for (`Exif`,
  `LensSerialNumber). With both in the tree each pair answers its own tag. `Rating` says the same thing a
  second way: `xmp:Rating` is what `kCGImagePropertyIPTCStarRating` maps to and `Iptc4xmpExt:Rating` is what
  `kCGImagePropertyIPTCExtRating` maps to.
- **The prefix is NOT part of the match.** A tag whose namespace and name are the row's and whose prefix is
  one the caller registered (`charonprobe:ISOSpeed` in the `cipa.jp` namespace) is answered.
- **Only the top level of the tree is searched.** A tree holding `exif:Sub{exif:DateTimeOriginal}` answers
  NULL for (`Exif`, `DateTimeOriginal), and one holding `exif:Sub{photoshop:DateCreated}` - the name that
  property really maps to - answers NULL too. Nothing below a structure or inside an array is found.

And the mapped tag wins over the property's own name in both orders: a tree holding `photoshop:DateCreated`
and `exif:DateTimeOriginal` answers `photoshop:DateCreated`, and one holding them the other way round
answers the same, while a tree holding only `exif:DateTimeOriginal` answers NULL.

### A number is written as the string XMP spells it

The set direction's value comes back a `CFString` for every scalar number. These are XMP's own three scalar
types, and the number's own `CFNumber` type decides between them:

| passed | CFNumber type | written |
| --- | --- | --- |
| `@3`, `@-2`, `@(1234567890123LL)` | integer | `3`, `-2`, `1234567890123` |
| `@3.0`, `@3.5f`, `@1.5`, `@0.1`, `@(1e20)` | float or double | `3.000000`, `3.500000`, `1.500000`, `0.100000`, `100000000000000000000.000000` |
| `@YES`, `@NO` | `CFBoolean` | `True`, `False` |

`CFNumberIsFloatType` is what separates the first two rows, so the port asks it and formats with `%lld` or
`%f` accordingly - the spelling is CF's and XMP's, not this library's. An array and a dictionary are handed
to the path writer as the caller passed them, which is what "The same value restrictions apply as in
CGImageMetadataTagCreate" asks for, and the tag's type is read off the value's CFType as before (measured: a
string and a number both write a `String` tag, an array an `ArrayOrdered` one). A second set for the same
pair keeps one tag and its second value.

### The same spelling everywhere, and the element rule that came with it (2026-10-03)

The spelling above is not a property of the image-property bridge: **the host's tag API spells a number the
same way**, and the port's answer did not. Measured on the host for all three entry points:

| asked of the host | tag type | the tag's value |
| --- | --- | --- |
| `CGImageMetadataTagCreate(ns, prefix, "N", kCGImageMetadataTypeDefault, @7)` | 1 (String) | a `CFString` |
| `CGImageMetadataTagCreate(..., @3.0)` and `(@1.5)` and `(@YES)` | 1 | `CFString` |
| `CGImageMetadataTagCreate(ns, prefix, "N", (CGImageMetadataType)1, @3.5)` - an explicit String type | 1 | `CFString` |
| `CGImageMetadataSetValueWithPath(m, NULL, "exif:N", @7)` | 1 | a `CFString`, and the host's own packet says `<exif:N>7</exif:N>` |

So the conversion belongs where a tag's own value is set, which is `CGImageMetadataTagCreate`: the path writer
builds its tag there and the image-property bridge writes through the path writer, so all three agree from one
place and there is no second copy of the spelling. The harness now prints the **value** of every tag it makes
through either path - `tagline()` always did - and it adds a plant that keeps the `CFNumber`, which moves 48
of the number records:

    MUTATION 5: keeping the CFNumber moves 48 of the number records, which print the tag's value

**What a number inside a container is, measured with the same probe, is NOT a string.** A tag made from
`@[@"s", @1, @YES, @2.5, @[@"nested"], @{@"k": @"v"}]` holds

    [ a tag named [0] of type String holding "s", 1, true, 2.5, an array holding "nested", a structure holding k = "v" ]

and a tag made from `@{@"s": @"str", @"n": @7, @"b": @YES, @"r": @1.25, @"a": @[@"x"], @"d": @{@"k": @"v"}}` holds

    { a tag named s of type String holding "str", 7, true, 1.25, an array holding "x", a structure holding k = "v" }

So the rule is narrower than "an array value holds tags", which is what this file said before this measurement
and which is right only for an array of strings: **a string becomes a tag - named by its position in an array
and by its key in a structure - and every other element is held as it is**, and the wrapping is **one level
deep**, so the string inside the nested array stays a string. The host's own packet for that array writes three
`<rdf:li>` elements and leaves out both the boolean and the two containers, which is the same answer. The
port's `charon_wrap` wrapped every element before, which made a number a tag holding the string `"2.500000"`
where the host holds the number itself; that is fixed here too, and the harness's
`tag number in array`, `tag number in structure` and `tag number in path array` records are what say so.

### What the 2026-10-01 reading of this pair list said, and why it was wrong

This section was first written on 2026-10-01 from the same host and the same pair list, and it concluded
that the oracle answers one direction and refuses the other: "173 of 192 pairs TRAP the host (SIGTRAP), the
other 19 answer false and write no tag. So a port implementation of that row could not be checked against
this oracle at all." Both halves were the harness's own defects, and both were found by measuring the same
pairs again rather than by reading them:

1. **The trap was in the probe.** `property-mapping.m` printed the tag it had just read with
   `[NSString appendFormat:@"%@", <a const char *>]`, and a `%@` with a C string sends
   `-respondsToSelector:` to a stack address, where the ObjC runtime answers with a trap.
   `CGImageMetadataSetValueMatchingImageProperty` had already returned true and written its tag before that
   line ran - the trap is after the write, in the probe's own printing. With the format fixed, all 192
   pairs answer and **173 of them answer true**, the same 173 this table carries for that slice of the list,
   and `mapping.sh` asserts that number now instead of asserting that there are traps.
2. **The names that printed as NULL were not NULL.** `CFStringGetCStringPtr` answers NULL for a string it
   cannot hand back in place, which is most of ImageIO's own tag names: **89 of the 357 names this table
   carries** printed `(null)` that way while `CFStringGetLength` and `CFCopyDescription` both answered the
   real name - a `tiff:Make` tag came out with its name, its prefix and its value all reading "(null)". The
   probe copies the C string out now, into one of four rotating buffers because one printf uses three of them.

The corrected run, `tests/backports/host/imageio-metadata/mapping.sh`:

    LOOKUP: 192 pairs, 87 answered at the property's own name, 105 answered at no name
    SET: 192 pairs, 0 TRAP the host (SIGTRAP), 192 answer, 173 of those answer true
    imageio-mapping: lookup 87/192 at the property's own name, set 173/192 answered true

The 87 and the 105 are still right, and they are a different measurement: a container is built holding the
property's own name in each of the nine public namespaces and the pair is asked which container answers,
which says how many of those 192 map to a tag named after the property itself. The 105 that answer at no
name are the Metadata Working Group ones the header describes - `kCGImagePropertyExifDateTimeOriginal` is
answered by `photoshop:DateCreated`, and a container holding `exif:DateTimeOriginal` is not what the host
looks at - and the table above says what each of them maps to instead.

### The XMP pair is measurable, and here is the oracle

`CGImageMetadataCreateXMPData` answers plain UTF-8 RDF/XML with no `<?xpacket?>` wrapper, and
`evidence/xmp-flash.bin` (311 bytes) and `evidence/xmp-array.bin` (541 bytes) are what it produced for one
string-valued tag and for an array plus a number:

    <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="XMP Core 6.0.0">
     <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about=""
          xmlns:exif="http://ns.adobe.com/exif/1.0/"
          ...
    <tiff:Orientation>1</tiff:Orientation>

Two more measured facts about it: `CGImageMetadataCreateXMPData` of an EMPTY metadata answers **NULL** (not
an empty packet), and a tag is written in the *element* form even when its value is a string. The parse
direction answers a hand-written packet with 3 tags - the two properties, plus one in
`http://ns.apple.com/ImageIO/1.0/` that the host derives from the packet itself. `evidence/xmp-dump.txt` has
all three.

Both rows are therefore implementable and checkable in both directions - a writer that is compared byte for
byte with the host's, and a reader compared on the tree it produces - and that is the next thing this
family needs. It is not in this series.
