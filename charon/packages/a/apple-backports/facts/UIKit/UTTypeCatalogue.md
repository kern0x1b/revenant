# UniformTypeIdentifiers' system type catalogue, iOS 14

Every constant `UTCoreTypes.h` declares and this port does not already carry, with the Uniform Type
Identifier behind it, one row each.

## Where each identifier came from

The `UTI:` line of the constant's own doc comment in
`System/Library/Frameworks/UniformTypeIdentifiers.framework/Headers/UTCoreTypes.h` of the SDK the API
comes from -- `charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk` -- transcribed, one row per constant.
Nothing here is recalled and nothing is inferred from the identifier's own shape. Two independent SDK
drops agree with that reading on all 129 of them: MacOSX26.5.sdk and MacOSX27.sdk carry the same 140
constants with the same 140 identifiers, and the port's own 16.4 SDK carries the 119 of them that
existed then.

The one value that is not the header's is `UTTypeInternetShortcut`. Every SDK drop's `UTCoreTypes.h`
documents it as `com.apple.internet-location`, which is the identifier of the constant directly above it
in the same file -- a copy-and-paste in Apple's own header, present in MacOSX26.5, MacOSX27 and 16.4
alike. The system's own UniformTypeIdentifiers answers `com.microsoft.internet-shortcut`, and that is
what the port uses.

## What the host differential measures

`tests/backports/host/uttypeconstants` reads each of the 129 identifiers back off the host's own
UniformTypeIdentifiers, one `dlsym` per constant, and compares it against
`expected-identifiers.tsv` beside it -- the table above, never the port's answer. Its last run:

```
uttypeconstants: 129 identifiers compared against the host's own constants
UTTagClassFilenameExtension = public.filename-extension
UTTagClassMIMEType = public.mime-type
UTTypeInternetShortcut = com.microsoft.internet-shortcut, UTTypeInternetLocation = com.apple.internet-location (the header says com.apple.internet-location for both)
uttypeconstants: 141 checks, 0 different
```

The two tag classes are checked against the host's own values and against the release's own
`kUTTagClassFilenameExtension` / `kUTTagClassMIMEType`, which carry the same two strings -- the release's
spelling and UniformTypeIdentifiers' are one tag class each, so a type built from one is the same type
as one built from the other.

## How the constants are stored

Plain, non-`const` globals filled in once by a `constructor` function, the way `UIKit/UTType.m` already
fills the eleven it carried first and the way `CFEmptyCollections.m` fills
`__NSArray0__`/`__NSDictionary0__`. A recent SDK's header declares these `UTType *const`, but that is a
promise to the header's callers, not a constraint on how this backport's translation unit stores them.

The two tag classes are the exception: the SDK's own `UTTagClass.h` declares them `NSString *const`, and
a `const` object needs its initializer at its definition, so they carry theirs there.

## One object per release band

`UTTypeCatalogue14.m`, `UTTypeCatalogue15.m`, `UTTypeCatalogue17.m`, `UTTypeCatalogue18.m` and
`UTTypeCatalogue182.m` hold the 119, 1, 1, 7 and 1 constants whose availability the corpus places in their
band (UTTypeJPEGXL is 18.2, and the gate refused it beside the seven of 18.0). An object holds the API
of exactly one release, which is what `release-split` and `check_releases` read off an object's own
symbols, so a file holding 14.0 and 17.0 constants would be one band carrying two releases' API.

## What each constant is on this release

A `UTType` is a wrapper over the Uniform Type Identifier, and the release's own UTI functions
(`UTTypeConformsTo`, `UTTypeCopyPreferredTagWithClass`, `UTTypeCopyDescription`,
`UTTypeCreatePreferredIdentifierForTag`, `UTTypeIsDeclared`, `UTTypeIsDynamic`) answer every question
about it. So a constant is the type for its identifier, and what the release knows about that identifier
is what a caller of the constant gets.

Where the release's 2012 UTI database knows nothing about an identifier -- `com.apple.haptics.ahap` and
the other types iOS 14 added are the ones -- the release's conformance and tags answer nothing for it.
That is the release's answer and this port does not improve on it: `-isDeclared` says what
`UTTypeIsDeclared` says, and for an identifier the 2012 database never heard of, that is NO.

## The catalogue table

| Constant | Identifier |
| --- | --- |
14.0	UTTypeCompositeContent	public.composite-content
14.0	UTTypeDiskImage	public.disk-image
14.0	UTTypeResolvable	com.apple.resolvable
14.0	UTTypeSymbolicLink	public.symlink
14.0	UTTypeExecutable	public.executable
14.0	UTTypeMountPoint	com.apple.mount-point
14.0	UTTypeAliasFile	com.apple.alias-file
14.0	UTTypeURLBookmarkData	com.apple.bookmark
14.0	UTTypeUTF16ExternalPlainText	public.utf16-external-plain-text
14.0	UTTypeUTF16PlainText	public.utf16-plain-text
14.0	UTTypeDelimitedText	public.delimited-values-text
14.0	UTTypeCommaSeparatedText	public.comma-separated-values-text
14.0	UTTypeTabSeparatedText	public.tab-separated-values-text
14.0	UTTypeUTF8TabSeparatedText	public.utf8-tab-separated-values-text
14.0	UTTypeRTF	public.rtf
14.0	UTTypeHTML	public.html
14.0	UTTypeXML	public.xml
14.0	UTTypeYAML	public.yaml
18.0	UTTypeCSS	public.css
14.0	UTTypeSourceCode	public.source-code
14.0	UTTypeAssemblyLanguageSource	public.assembly-source
14.0	UTTypeCSource	public.c-source
14.0	UTTypeObjectiveCSource	public.objective-c-source
14.0	UTTypeSwiftSource	public.swift-source
14.0	UTTypeCPlusPlusSource	public.c-plus-plus-source
14.0	UTTypeObjectiveCPlusPlusSource	public.objective-c-plus-plus-source
14.0	UTTypeCHeader	public.c-header
14.0	UTTypeCPlusPlusHeader	public.c-plus-plus-header
14.0	UTTypeScript	public.script
14.0	UTTypeAppleScript	com.apple.applescript.text
14.0	UTTypeOSAScript	com.apple.applescript.script
14.0	UTTypeOSAScriptBundle	com.apple.applescript.script-bundle
14.0	UTTypeJavaScript	com.netscape.javascript-source
14.0	UTTypeShellScript	public.shell-script
14.0	UTTypePerlScript	public.perl-script
14.0	UTTypePythonScript	public.python-script
14.0	UTTypeRubyScript	public.ruby-script
14.0	UTTypePHPScript	public.php-script
15.0	UTTypeMakefile	public.make-source
14.0	UTTypeJSON	public.json
14.0	UTTypePropertyList	com.apple.property-list
14.0	UTTypeXMLPropertyList	com.apple.xml-property-list
14.0	UTTypeBinaryPropertyList	com.apple.binary-property-list
14.0	UTTypeRTFD	com.apple.rtfd
14.0	UTTypeFlatRTFD	com.apple.flat-rtfd
14.0	UTTypeWebArchive	com.apple.webarchive
14.0	UTTypeJPEG	public.jpeg
14.0	UTTypeTIFF	public.tiff
14.0	UTTypeGIF	com.compuserve.gif
14.0	UTTypePNG	public.png
14.0	UTTypeICNS	com.apple.icns
14.0	UTTypeBMP	com.microsoft.bmp
14.0	UTTypeICO	com.microsoft.ico
14.0	UTTypeRAWImage	public.camera-raw-image
14.0	UTTypeSVG	public.svg-image
14.0	UTTypeLivePhoto	com.apple.live-photo
14.0	UTTypeHEIF	public.heif
14.0	UTTypeHEIC	public.heic
18.0	UTTypeHEICS	public.heics
14.0	UTTypeWebP	org.webmproject.webp
18.0	UTTypeEXR	com.ilm.openexr-image
18.0	UTTypeDNG	com.adobe.raw-image
18.2	UTTypeJPEGXL	public.jpeg-xl
14.0	UTType3DContent	public.3d-content
14.0	UTTypeUSD	com.pixar.universal-scene-description
14.0	UTTypeUSDZ	com.pixar.universal-scene-description-mobile
14.0	UTTypeRealityFile	com.apple.reality
14.0	UTTypeSceneKitScene	com.apple.scenekit.scene
14.0	UTTypeARReferenceObject	com.apple.arobject
14.0	UTTypeAudiovisualContent	public.audiovisual-content
14.0	UTTypeMovie	public.movie
14.0	UTTypeVideo	public.video
14.0	UTTypeAudio	public.audio
14.0	UTTypeQuickTimeMovie	com.apple.quicktime-movie
14.0	UTTypeMPEG	public.mpeg
14.0	UTTypeMPEG2Video	public.mpeg-2-video
14.0	UTTypeMPEG2TransportStream	public.mpeg-2-transport-stream
14.0	UTTypeMP3	public.mp3
14.0	UTTypeMPEG4Movie	public.mpeg-4
14.0	UTTypeMPEG4Audio	public.mpeg-4-audio
14.0	UTTypeAppleProtectedMPEG4Audio	com.apple.protected-mpeg-4-audio
14.0	UTTypeAppleProtectedMPEG4Video	com.apple.protected-mpeg-4-video
14.0	UTTypeAVI	public.avi
14.0	UTTypeAIFF	public.aiff-audio
14.0	UTTypeWAV	com.microsoft.waveform-audio
14.0	UTTypeMIDI	public.midi-audio
14.0	UTTypePlaylist	public.playlist
14.0	UTTypeM3UPlaylist	public.m3u-playlist
14.0	UTTypeFolder	public.folder
14.0	UTTypeVolume	public.volume
14.0	UTTypePackage	com.apple.package
14.0	UTTypeBundle	com.apple.bundle
14.0	UTTypePluginBundle	com.apple.plugin
14.0	UTTypeSpotlightImporter	com.apple.metadata-importer
14.0	UTTypeQuickLookGenerator	com.apple.quicklook-generator
14.0	UTTypeXPCService	com.apple.xpc-service
14.0	UTTypeFramework	com.apple.framework
14.0	UTTypeApplication	com.apple.application
14.0	UTTypeApplicationBundle	com.apple.application-bundle
14.0	UTTypeApplicationExtension	com.apple.application-and-system-extension
14.0	UTTypeUnixExecutable	public.unix-executable
14.0	UTTypeEXE	com.microsoft.windows-executable
14.0	UTTypeSystemPreferencesPane	com.apple.systempreference.prefpane
14.0	UTTypeArchive	public.archive
14.0	UTTypeGZIP	org.gnu.gnu-zip-archive
14.0	UTTypeBZ2	public.bzip2-archive
14.0	UTTypeZIP	public.zip-archive
14.0	UTTypeAppleArchive	com.apple.archive
18.0	UTTypeTarArchive	public.tar-archive
14.0	UTTypeSpreadsheet	public.spreadsheet
14.0	UTTypePresentation	public.presentation
14.0	UTTypeDatabase	public.database
14.0	UTTypeMessage	public.message
14.0	UTTypeContact	public.contact
14.0	UTTypeVCard	public.vcard
14.0	UTTypeToDoItem	public.to-do-item
14.0	UTTypeCalendarEvent	public.calendar-event
14.0	UTTypeEmailMessage	public.email-message
14.0	UTTypeInternetLocation	com.apple.internet-location
14.0	UTTypeInternetShortcut	com.microsoft.internet-shortcut
14.0	UTTypeFont	public.font
14.0	UTTypeBookmark	public.bookmark
14.0	UTTypePKCS12	com.rsa.pkcs-12
14.0	UTTypeX509Certificate	public.x509-certificate
14.0	UTTypeEPUB	org.idpf.epub-container
14.0	UTTypeLog	public.log
17.0	UTTypeAHAP	com.apple.haptics.ahap
18.0	UTTypeGeoJSON	public.geojson
18.0	UTTypeLinkPresentationMetadata	com.apple.linkpresentation.metadata
