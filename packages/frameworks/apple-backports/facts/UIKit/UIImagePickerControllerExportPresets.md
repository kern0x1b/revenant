# The export presets of the image picker, iOS 11.0

Introduced in iOS 11.0: two settings of the image picker that say how the
picked item is handed over - whether a HEIF photo is converted to a format every
program reads, and which preset a movie is exported with - and the key under
which the picked item's `PHAsset` comes back.

Source: the header of SDK 16.4, which declares `imageExportPreset` with the
values `Compatible` (0) and `Current` and `videoExportPreset` as a copied
string, and UIKit of the arm64 shared cache of iOS 12.0, in whose class
metadata both are plain properties of the class, with their accessors, and whose
strings hold `UIImagePickerControllerPHAsset`. The accessors were not
disassembled: what is said of them is what the metadata and the header give.

## What the port answers

Both are stored on the picker and handed back as they were set, with the values
zero and nil for a picker nothing was set on, which is what the header's enum
makes of a default. Neither does anything on iOS 6:
- the picker of this release hands over a JPEG or the file the camera made, so
  there is nothing to convert, and `Current` and `Compatible` come out the same;
- it transcodes a movie by `videoQuality` and takes no export preset, so a
  preset set on it is kept and not applied, and the first one says so in the log.

`UIImagePickerControllerPHAsset` is carried with its own name as its value. The
Photos framework does not exist on this release, so the key is never in the
dictionary the picker delegate is given, and an application that reads it gets
`nil`. Both properties and the key are `inert` for that reason.
