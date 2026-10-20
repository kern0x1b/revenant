# The name of a colour space, iOS 11.0

`CGColorSpaceGetName` was made public in iOS 11.0. It answers the name a colour
space holds, as a string that stays valid as long as the space does, and nothing
has to release it.

Source: CoreGraphics of the arm64 shared cache of iOS 12.0, `_CGColorSpaceGetName`
at `0x182b69080` and `_CGColorSpaceCopyName` at `0x182b69090`; an iPad 2 running
6.1.3; the host's CoreGraphics through `tests/backports/host/graphics11`.

## What it is

The release reads the name out of the space and answers it. `CGColorSpaceCopyName`
answers the same object with a retain. For a `NULL` space, and for a space that
holds no name, both answer `NULL`. Two spaces of the same name answer the same
string.

On iOS 6 `CGColorSpaceCopyName` is there, `CGColorSpaceGetName` is not, and the
copy already gives the names: `kCGColorSpaceDeviceRGB`, `kCGColorSpaceDeviceGray`
and `kCGColorSpaceDeviceCMYK` for the three device spaces. The package answers
what the copy answers, without the retain: the strings it hands out are kept in
one set for the life of the process, so that the same name is the same object and
nothing the caller does can free it. The set holds one string for each name, and
names are few.

## Where iOS 6 differs

`CGColorSpaceCreateWithName` on iOS 6 makes a space for `kCGColorSpaceGenericRGB`,
`kCGColorSpaceGenericGray` and `kCGColorSpaceGenericCMYK` only. For the others
(`kCGColorSpaceSRGB`, `kCGColorSpaceDisplayP3`, `kCGColorSpaceGenericRGBLinear`,
`kCGColorSpaceAdobeRGB1998`) it answers `NULL`. The constants
`kCGColorSpaceSRGB`, `kCGColorSpaceGenericRGBLinear` and `kCGColorSpaceAdobeRGB1998`
are there, though they make no space; `kCGColorSpaceDisplayP3`,
`kCGColorSpaceLinearSRGB` and the extended and ITU ones are not.

The space made for `kCGColorSpaceGenericRGB` is the device RGB space: its copy of
the name is `kCGColorSpaceDeviceRGB`. iOS 12 answers `kCGColorSpaceGenericRGB` for
it. The package cannot tell the two apart, so a call on such a space answers
`kCGColorSpaceDeviceRGB`. This is the one departure.

## kCGColorSpaceGenericLab

Introduced in 11.0 and, on iOS 6, missing as a symbol. The package carries the
constant with the value iOS 12 holds, `kCGColorSpaceGenericLab`. iOS 6 cannot make
a Lab space by name, so `CGColorSpaceCreateWithName` answers `NULL` for it, the
same answer it gives for every name it does not make.

The constants that arrived in 12.3 and 12.6 (`kCGColorSpaceExtendedLinearDisplayP3`,
`kCGColorSpaceExtendedLinearITUR_2020`, `kCGColorSpaceDisplayP3_HLG`,
`kCGColorSpaceDisplayP3_PQ_EOTF`, `kCGColorSpaceITUR_2020_HLG`,
`kCGColorSpaceITUR_2020_PQ_EOTF`) are not carried: the newest iOS 12 image this
package reads is 12.0, and the host's CoreGraphics gives values for the HLG and PQ
names that differ from their symbols, so a value written down without reading it
would be an invention.
