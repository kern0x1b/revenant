# ImageIO and CoreVideo names the release already exports

The SDK dates many ImageIO and CoreVideo names after iOS 6, and asked one by one with `dlsym`,
iOS 6 exports a few of them. They are the release's own and are not carried here, and the rest are absent.

Source: an iPad 2 running 6.1.3 and the iOS 6.0 emulator, which agree.

## What the release exports

`CGImageSourceCopyMetadataAtIndex`, the eight `kCGImageMetadataNamespace...` names of Exif, ExifAux,
DublinCore, IPTCCore, Photoshop, TIFF, XMPBasic and XMPRights, `kCGImagePropertyPNGCompressionFilter` and
`kCGImageSourceSubsampleFactor`. What they do was not compared with a newer release: the names
are exported, which is what an application that links against them needs, and nothing more is claimed.

The rest of the metadata API of ImageIO (`CGImageMetadata...`, `CGImageDestination...Metadata...`) and the
other names of ImageIO and CoreVideo that arrived after iOS 6 are not exported, so a weak reference to them is
NULL, and the registry records them as absent.

## Since which release

ImageIO exports `kCGImageSourceSubsampleFactor` from 4.0 (3.1.3's cache has it in another image) and the
other ten from 5.0.

The registry's `introduced` is the first release on the armv7 cache ladder (3.1.3 to 10.3.4) whose
library the SDK puts the name in exports it (`dyld.exported_at` with `dyld.sdk_owners`, the measure the gate
takes), not the SDK header's date; 3.1.3 is the lowest rung held, so it means "3.1.3 or earlier". The same pass
gives `kCGColorSpaceDisplayP3` 9.3 as the control, so the ladder does not answer its lowest rung for everything.
