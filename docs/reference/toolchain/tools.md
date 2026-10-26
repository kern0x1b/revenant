# Tools

The developer tools under `toolchain/tools/`. They are Lua run with `./xmakew l -P .` unless noted, and none of them is part of a port's build. The folders with a tool of their own are described here; the rest are the generators and measurements behind the packages, whose `cmd_*.lua`, `*.lua` and `README` names say what they do.

## assets_extract

`toolchain/tools/assets_extract/` writes what a compiled asset catalogue (`Assets.car`) holds as loose files, so an application that carries one runs on a release whose UIKit cannot read it. iOS 6 has no CoreUI, and `+[UIImage imageNamed:]` finds nothing in a catalogue; it does load loose files, which is what the tool writes.

    ./xmakew l -P . toolchain/tools/assets_extract/assets_extract.lua [--scales 1,2,3] [--keep-appearance] Assets.car OUTPUT-FOLDER

It is a macOS tool and a step of the conversion, run on the resource stage of the build, not on the device. It uses the CoreUI of the Mac, which decodes every format Xcode writes. `tests/addon/assets_extract_test.lua` checks it, and extracts the catalogue named by `REVENANT_TEST_ASSET_CATALOGUE` when that is set. Exit codes: 0 on success, 64 for a bad command line, 65 for a file that is not a compiled catalogue, 69 on a machine without CoreUI.

What comes out:

- `NAME.png`, `NAME@2x.png`, `NAME@3x.png`, and `NAME~ipad.png` where an iPad variant differs. A name with a slash makes a folder. Packed-image atlases are not images and are left out. Vector documents come out as images at every scale asked for.
- `AssetCatalogImages.plist`: for each name, its variants with `file`, `scale`, `idiom`, `width`, `height` in pixels, `capInsets`, `resizingMode`, `template` and `vector`.
- `icons/NAME-WxH[~ipad].png` and `AssetCatalogIcons.plist` for the application icon sets.
- `AssetCatalogColors.plist`: each named colour as sRGB components; with `--keep-appearance`, the other appearances too.
- `data/NAME` for each data set that is not a PDF.

Left out: the dark appearance, Display P3 renditions, size classes, device subtypes, right-to-left and localisations, and the television, car and watch idioms. The `@3x` files are written for later releases; iOS 6 ignores them. The template rendering mode and cap insets are in the plist, not the files: the code that names an image sets them.

## cache_index

`toolchain/tools/cache_index/` answers "in which release does this name first appear" from an index, instead of reading every held cache for each name. Reading one name over the whole ladder of held releases takes minutes; the index is read once and a lookup is a binary search.

    ./xmakew l -P . toolchain/tools/cache_index/build.lua                 read each cache once, write the index
    ./xmakew l -P . toolchain/tools/cache_index/first_rung.lua NAME...    name, a tab, the first held rung, or NONE
    ./xmakew l -P . toolchain/tools/cache_index/first_rung.lua --self-test

The index is written to `.cache/cache-index/`: one file per release of the names it holds, and `first-rung.tsv.gz` for every name. "First" means the oldest held release that carries the name, on the ladder `dyld.held_ladder({"armv7","armv7s"})` gives in `modules/apple/dyld.lua`. The reading child runs under `nice -n 19`; a cold build reads the whole ladder once and takes a long time, so run it one at a time.

## order_file

`toolchain/tools/order_file/order_file.lua` turns the block profile of an emulator run into an order file for ld64's `-order_file`: the functions of the binary that the run executed, hottest first, one symbol per line with its Mach-O underscore. The run is an emulator boot with `--perf-block-profile`, whose `perf/block-profile.tsv` the tool reads.

    ./xmakew l -P . toolchain/tools/order_file/order_file.lua --llvm-bin DIR [--image NAME] BLOCK-PROFILE BINARY OUTPUT

`DIR` is the `bin` folder of the llvm package with its `libraries` config, which installs `llvm-nm` and `llvm-objdump` beside clang. `BINARY` is the host copy of the program the run executed, and `--image` is the name the profile gives it (its basename, by default). The symbols come from `llvm-nm -n` and the `__TEXT` base from `llvm-objdump --private-headers`. The packaged test `toolchain_packages/order_file_test` builds a program, writes a profile for it and checks the order that comes out. Its use is in [the optimisation measurements](optimisation.md).

## Other tools

`toolchain/tools/recipe_digests.lua` writes the `port/digest.lua` of every recipe from the recipe and the
modules it runs, so a changed source is a changed package. It is run by hand, after a recipe's sources change.
