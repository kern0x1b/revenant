# The image of a bundle by name, iOS 8

Introduced in iOS 8.0: `+[UIImage imageNamed:inBundle:compatibleWithTraitCollection:]`, the image of any bundle, not only the main
one, chosen for a trait collection.

Source: the host's own UIKit, run beside the port through Mac Catalyst (`host/imagenamed/run.sh`): 110 lookups over a folder of
loose files - names with and without an extension, a JPEG, files of one, two and three scales, files for the pad - under no
traits and under every pair of display scale 1, 2, 3 with the phone and pad idioms. The answers of the release become
`device/imagenamed-expectations.h`, and `device/imagenamed.m` holds iOS 6 to them on the iPhone 4S and the iPad 2.

## What the port does as the system does

A name with no extension is a PNG. The file for the wanted scale is `name@2x`, `name@3x` or `name`; when it is not there the
release takes a larger scale first (the nearest above), then the smaller ones, nearest first: with a file of one scale and one of
three, a display of scale 2 gets the three. The pad's files carry `~ipad` and are preferred for the pad idiom over the plain one;
a plain file answers where there is none. The idiom and the scale come from the trait collection when it says them and are the
device's own when it does not (no collection, or a collection with no idiom or scale 0). The image answers the size the file
has divided by the scale of the file, and that scale. A name that is empty, absent or in another bundle's folder answers nil,
and a nil bundle is the main bundle. The file system decides the case of the name, as it does for the release: the recorder's Mac finds `PLAIN` for `plain.png`, the data partition of iOS 6 does not, and `device/imagenamed.m` expects what its own file system answers.

## What differs

The port looks at the loose files of the bundle. It does not read a compiled `Assets.car` for an image (the port reads the
catalogue for `NSDataAsset` only; `tools/assets-extract` writes a catalogue as loose files for a release with no CoreUI), and the
traits the release reads besides the idiom and the scale - dark, size class, language, the layout direction - do not choose the
image. Files named for the phone (`~iphone`) are chosen for the phone idiom by the port as iOS does; the host of the recorder is a
Mac, which does not choose them, so that answer is held by `device/imagenamed.m` itself. The main bundle falls back to
`+imageNamed:`, which is what finds an image of the release's own kind, such as one named in the application's icon set.
