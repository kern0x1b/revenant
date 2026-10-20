# Tools

The developer tools under `toolchain/tools/`. They are Lua run with `./xmakew l` unless noted, and none of them is part of a port's build. The folders with a tool of their own are described here; the rest are the generators and measurements behind the packages, whose `cmd_*.lua`, `*.lua` and `README` names say what they do.

## assets-extract

`toolchain/tools/assets-extract/` writes what a compiled asset catalogue (`Assets.car`) holds as loose files, so an application that carries one runs on a release whose UIKit cannot read it. iOS 6 has no CoreUI, and `+[UIImage imageNamed:]` finds nothing in a catalogue; it does load loose files, which is what the tool writes.

    xmake l tools/assets-extract/assets-extract.lua [--scales 1,2,3] [--keep-appearance] Assets.car OUTPUT-FOLDER

It is a macOS tool and a step of the conversion, run on the resource stage of the build, not on the device. It uses the CoreUI of the Mac, which decodes every format Xcode writes. `tests/addon/assets_extract_test.lua` checks it, and extracts the catalogue named by `REVENANT_TEST_ASSET_CATALOGUE` when that is set. Exit codes: 0 on success, 64 for a bad command line, 65 for a file that is not a compiled catalogue, 69 on a machine without CoreUI.

What comes out:

- `NAME.png`, `NAME@2x.png`, `NAME@3x.png`, and `NAME~ipad.png` where an iPad variant differs. A name with a slash makes a folder. Packed-image atlases are not images and are left out. Vector documents come out as images at every scale asked for.
- `AssetCatalogImages.plist`: for each name, its variants with `file`, `scale`, `idiom`, `width`, `height` in pixels, `capInsets`, `resizingMode`, `template` and `vector`.
- `icons/NAME-WxH[~ipad].png` and `AssetCatalogIcons.plist` for the application icon sets.
- `AssetCatalogColors.plist`: each named colour as sRGB components; with `--keep-appearance`, the other appearances too.
- `data/NAME` for each data set that is not a PDF.

Left out: the dark appearance, Display P3 renditions, size classes, device subtypes, right-to-left and localisations, and the television, car and watch idioms. The `@3x` files are written for later releases; iOS 6 ignores them. The template rendering mode and cap insets are in the plist, not the files: the code that names an image sets them.

## cache-index

`toolchain/tools/cache-index/` answers "in which release does this name first appear" from an index, instead of reading every held cache for each name. Reading one name over the whole ladder of held releases takes minutes; the index is read once and a lookup is a binary search.

    xmake l tools/cache-index/build.lua                 read each cache once, write the index
    xmake l tools/cache-index/first-rung.lua NAME...    name, a tab, the first held rung, or NONE
    xmake l tools/cache-index/first-rung.lua --self-test

The index is written to `$HOME/.revenant/cache-index/`: one file per release of the names it holds, and `first-rung.tsv.gz` for every name. "First" means the oldest held release that carries the name, on the ladder `dyld.held_ladder({"armv7","armv7s"})` gives in `modules/apple/dyld.lua`. The reading child runs under `nice -n 19`; a cold build reads the whole ladder once and takes a long time, so run it one at a time.

## Measured constants

`toolchain/tools/corpus/cfconst.tsv` holds the constants of 31 objects in seven frameworks (558 declarations): each row is one declaration with its object, its imports, the release and architecture of the dyld cache its value was read from, its type, its name and its initialiser. `tools/gen/measured.lua` writes each object into `.gen/<Framework>/` when the generator runs; none of them is committed.

    REVENANT_ROOT=$PWD xmake l tools/corpus/cfconst-check.lua    reads the caches the table names

The check reads each symbol through `tools/corpus/cache-value.lua` and the project's reader, `modules/apple/dyld.lua`, and compares what the cache holds with the initialiser: a string by its text, a number by its float32 bits, a struct field by field, one word per field at the cache's pointer size. A row whose value differs fails the check. There is no pin. A row the reader cannot judge is reported as not judged, and the check fails if it judged none.

Two rules the table follows. Where a header and a release's own image disagree, the release is the one that is right. A struct the reader does not read is recorded with its reason, not guessed.

## Other tool folders

| Folder | What it holds |
| --- | --- |
| `found/` | the declaration reader: a clang-based extractor (`decls.cc`) and the Lua that turns its output into facts (`facts.lua`) |
| `intents/` | the App Intents generators: `objects.lua` and `gen-intents.lua` for the objects, `generate.lua` for the registry it drives (`gen-causes.lua`, `gen-registry.lua`), with their class groups and data |
| `corpus/` | the measured tables and the readers of the caches (`cache-images.lua`, `cache-value.lua`) |
