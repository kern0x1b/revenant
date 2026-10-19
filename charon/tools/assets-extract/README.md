# assets-extract

`assets-extract` writes what a compiled asset catalogue (`Assets.car`) holds as loose files, so an application that carries one
runs on a release whose UIKit cannot read it: iOS 6 has no CoreUI, and `+[UIImage imageNamed:]` finds no image in a catalogue.
The loose files are what that method has always loaded, so an application needs no reader of its own on the device and no
memory for one.

The catalogue is read by the CoreUI of the Mac that runs the tool, which decodes every format Xcode writes - the compressions
(`lzvn`, `lzfse`, `deepmap`, `deepmap2`, `palette-img`), the atlases of packed images and the vector documents. It is a macOS
tool and a step of the conversion, not of the device.

## Use

    tools/assets-extract/assets-extract.sh [--scales 1,2,3] [--keep-appearance] Assets.car OUTPUT-FOLDER

The first call builds `assets-extract` into `$CHARON_ASSETS_EXTRACT_CACHE` (default `$TMPDIR/charon-assets-extract`). The tool
prints one line of counts and exits 0; it exits 64 for a bad command line, 65 when the file is not a compiled catalogue and 69
on a machine with no CoreUI. Call it on the resource stage, with the catalogue of the application and the folder the bundle
is being made in, and copy the output beside the application's other resources.

## What comes out

- `NAME.png`, `NAME@2x.png`, `NAME@3x.png` for every image the catalogue names, and `NAME~ipad.png`, `NAME@2x~ipad.png` where the
  catalogue has an iPad variant that differs from the one for every device. A name with a slash makes a folder. The names of
  packed-image atlases (`ZZZZPackedAsset…`) are not images and are left out.
- A vector document is drawn at every scale asked for and comes out as images too.
- `AssetCatalogImages.plist`: for every name, its variants - `file`, `scale`, `idiom` (`universal`, `phone`, `pad`), `width` and
  `height` in pixels, `capInsets` (top, left, bottom, right, in points, zero when the image is not sliced), `resizingMode` (the
  CoreUI value, -1 for an image that is not sliced), `template` (rendering mode template) and `vector`.
- `icons/NAME-WxH[~ipad].png` for every size of an application icon set, and `AssetCatalogIcons.plist` listing them; the icon
  sets are not images by name.
- `AssetCatalogColors.plist`: for every named colour, `any` and, with `--keep-appearance`, the other appearances, as sRGB
  components (red, green, blue, alpha).
- `data/NAME` for every data set that is not a PDF document.

Images are converted to sRGB with premultiplied alpha and written as PNG.

## What it leaves out

Variants a release before iOS 7 cannot ask for: the dark appearance, wide-gamut (Display P3) renditions, size classes,
device subtypes (screen heights), right-to-left directions and localizations, and the idioms of the television, car and watch.
The copies of one rendition Xcode stores for different GPUs are one. The `@3x` files are written for a later release; iOS 6
ignores them. The template rendering mode and the cap insets are in the plist, not in the files: the code that names an image
sets them, as it would have on the release the catalogue was built for.
