#import "CharonUTType.h"

// UniformTypeIdentifiers' system type catalogue, iOS 14: the 119 constants of SDK 26.2's
// UTCoreTypes.h whose availability the corpus places in this band, out of the 14.0 the file declares.
// Every identifier below is the `UTI:` line of that constant's own doc comment in
// System/Library/Frameworks/UniformTypeIdentifiers.framework/Headers/UTCoreTypes.h of
// charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk -- transcribed one row per constant, nothing recalled
// and nothing inferred from the identifier's own shape. One value is not the header's:
// UTTypeInternetShortcut, where the header repeats the identifier of the constant directly above it
// and the system's own UniformTypeIdentifiers answers com.microsoft.internet-shortcut (measured, and
// re-measured on every run of tests/backports/host/uttypeconstants, which reads the value out of the
// host rather than out of this file). facts/UIKit/UTTypeCatalogue.md carries the whole table.
//
// One release per object file: this object holds the 14.0 catalogue only, and the files beside it hold
// the other bands, so every symbol first appears in exactly one release and release-split is clean.
// The constants are plain, non-const globals filled in once by a constructor, the way UIKit/UTType.m
// already fills the eleven it carried first and the way CFEmptyCollections.m fills
// __NSArray0__/__NSDictionary0__: a recent SDK's header declares these `UTType *const`, but that is a
// promise to the header's callers, not a constraint on how this backport's translation unit stores
// them.

// UTTypeCompositeContent is public.composite-content.
UTType *UTTypeCompositeContent;

// UTTypeDiskImage is public.disk-image.
UTType *UTTypeDiskImage;

// UTTypeResolvable is com.apple.resolvable.
UTType *UTTypeResolvable;

// UTTypeSymbolicLink is public.symlink.
UTType *UTTypeSymbolicLink;

// UTTypeExecutable is public.executable.
UTType *UTTypeExecutable;

// UTTypeMountPoint is com.apple.mount-point.
UTType *UTTypeMountPoint;

// UTTypeAliasFile is com.apple.alias-file.
UTType *UTTypeAliasFile;

// UTTypeURLBookmarkData is com.apple.bookmark.
UTType *UTTypeURLBookmarkData;

// UTTypeUTF16ExternalPlainText is public.utf16-external-plain-text.
UTType *UTTypeUTF16ExternalPlainText;

// UTTypeUTF16PlainText is public.utf16-plain-text.
UTType *UTTypeUTF16PlainText;

// UTTypeDelimitedText is public.delimited-values-text.
UTType *UTTypeDelimitedText;

// UTTypeCommaSeparatedText is public.comma-separated-values-text.
UTType *UTTypeCommaSeparatedText;

// UTTypeTabSeparatedText is public.tab-separated-values-text.
UTType *UTTypeTabSeparatedText;

// UTTypeUTF8TabSeparatedText is public.utf8-tab-separated-values-text.
UTType *UTTypeUTF8TabSeparatedText;

// UTTypeRTF is public.rtf.
UTType *UTTypeRTF;

// UTTypeHTML is public.html.
UTType *UTTypeHTML;

// UTTypeXML is public.xml.
UTType *UTTypeXML;

// UTTypeYAML is public.yaml.
UTType *UTTypeYAML;

// UTTypeSourceCode is public.source-code.
UTType *UTTypeSourceCode;

// UTTypeAssemblyLanguageSource is public.assembly-source.
UTType *UTTypeAssemblyLanguageSource;

// UTTypeCSource is public.c-source.
UTType *UTTypeCSource;

// UTTypeObjectiveCSource is public.objective-c-source.
UTType *UTTypeObjectiveCSource;

// UTTypeSwiftSource is public.swift-source.
UTType *UTTypeSwiftSource;

// UTTypeCPlusPlusSource is public.c-plus-plus-source.
UTType *UTTypeCPlusPlusSource;

// UTTypeObjectiveCPlusPlusSource is public.objective-c-plus-plus-source.
UTType *UTTypeObjectiveCPlusPlusSource;

// UTTypeCHeader is public.c-header.
UTType *UTTypeCHeader;

// UTTypeCPlusPlusHeader is public.c-plus-plus-header.
UTType *UTTypeCPlusPlusHeader;

// UTTypeScript is public.script.
UTType *UTTypeScript;

// UTTypeAppleScript is com.apple.applescript.text.
UTType *UTTypeAppleScript;

// UTTypeOSAScript is com.apple.applescript.script.
UTType *UTTypeOSAScript;

// UTTypeOSAScriptBundle is com.apple.applescript.script-bundle.
UTType *UTTypeOSAScriptBundle;

// UTTypeJavaScript is com.netscape.javascript-source.
UTType *UTTypeJavaScript;

// UTTypeShellScript is public.shell-script.
UTType *UTTypeShellScript;

// UTTypePerlScript is public.perl-script.
UTType *UTTypePerlScript;

// UTTypePythonScript is public.python-script.
UTType *UTTypePythonScript;

// UTTypeRubyScript is public.ruby-script.
UTType *UTTypeRubyScript;

// UTTypePHPScript is public.php-script.
UTType *UTTypePHPScript;

// UTTypeJSON is public.json.
UTType *UTTypeJSON;

// UTTypePropertyList is com.apple.property-list.
UTType *UTTypePropertyList;

// UTTypeXMLPropertyList is com.apple.xml-property-list.
UTType *UTTypeXMLPropertyList;

// UTTypeBinaryPropertyList is com.apple.binary-property-list.
UTType *UTTypeBinaryPropertyList;

// UTTypeRTFD is com.apple.rtfd.
UTType *UTTypeRTFD;

// UTTypeFlatRTFD is com.apple.flat-rtfd.
UTType *UTTypeFlatRTFD;

// UTTypeWebArchive is com.apple.webarchive.
UTType *UTTypeWebArchive;

// UTTypeJPEG is public.jpeg.
UTType *UTTypeJPEG;

// UTTypeTIFF is public.tiff.
UTType *UTTypeTIFF;

// UTTypeGIF is com.compuserve.gif.
UTType *UTTypeGIF;

// UTTypePNG is public.png.
UTType *UTTypePNG;

// UTTypeICNS is com.apple.icns.
UTType *UTTypeICNS;

// UTTypeBMP is com.microsoft.bmp.
UTType *UTTypeBMP;

// UTTypeICO is com.microsoft.ico.
UTType *UTTypeICO;

// UTTypeRAWImage is public.camera-raw-image.
UTType *UTTypeRAWImage;

// UTTypeSVG is public.svg-image.
UTType *UTTypeSVG;

// UTTypeLivePhoto is com.apple.live-photo.
UTType *UTTypeLivePhoto;

// UTTypeHEIF is public.heif.
UTType *UTTypeHEIF;

// UTTypeHEIC is public.heic.
UTType *UTTypeHEIC;

// UTTypeWebP is org.webmproject.webp.
UTType *UTTypeWebP;

// UTType3DContent is public.3d-content.
UTType *UTType3DContent;

// UTTypeUSD is com.pixar.universal-scene-description.
UTType *UTTypeUSD;

// UTTypeUSDZ is com.pixar.universal-scene-description-mobile.
UTType *UTTypeUSDZ;

// UTTypeRealityFile is com.apple.reality.
UTType *UTTypeRealityFile;

// UTTypeSceneKitScene is com.apple.scenekit.scene.
UTType *UTTypeSceneKitScene;

// UTTypeARReferenceObject is com.apple.arobject.
UTType *UTTypeARReferenceObject;

// UTTypeAudiovisualContent is public.audiovisual-content.
UTType *UTTypeAudiovisualContent;

// UTTypeMovie is public.movie.
UTType *UTTypeMovie;

// UTTypeVideo is public.video.
UTType *UTTypeVideo;

// UTTypeAudio is public.audio.
UTType *UTTypeAudio;

// UTTypeQuickTimeMovie is com.apple.quicktime-movie.
UTType *UTTypeQuickTimeMovie;

// UTTypeMPEG is public.mpeg.
UTType *UTTypeMPEG;

// UTTypeMPEG2Video is public.mpeg-2-video.
UTType *UTTypeMPEG2Video;

// UTTypeMPEG2TransportStream is public.mpeg-2-transport-stream.
UTType *UTTypeMPEG2TransportStream;

// UTTypeMP3 is public.mp3.
UTType *UTTypeMP3;

// UTTypeMPEG4Movie is public.mpeg-4.
UTType *UTTypeMPEG4Movie;

// UTTypeMPEG4Audio is public.mpeg-4-audio.
UTType *UTTypeMPEG4Audio;

// UTTypeAppleProtectedMPEG4Audio is com.apple.protected-mpeg-4-audio.
UTType *UTTypeAppleProtectedMPEG4Audio;

// UTTypeAppleProtectedMPEG4Video is com.apple.protected-mpeg-4-video.
UTType *UTTypeAppleProtectedMPEG4Video;

// UTTypeAVI is public.avi.
UTType *UTTypeAVI;

// UTTypeAIFF is public.aiff-audio.
UTType *UTTypeAIFF;

// UTTypeWAV is com.microsoft.waveform-audio.
UTType *UTTypeWAV;

// UTTypeMIDI is public.midi-audio.
UTType *UTTypeMIDI;

// UTTypePlaylist is public.playlist.
UTType *UTTypePlaylist;

// UTTypeM3UPlaylist is public.m3u-playlist.
UTType *UTTypeM3UPlaylist;

// UTTypeFolder is public.folder.
UTType *UTTypeFolder;

// UTTypeVolume is public.volume.
UTType *UTTypeVolume;

// UTTypePackage is com.apple.package.
UTType *UTTypePackage;

// UTTypeBundle is com.apple.bundle.
UTType *UTTypeBundle;

// UTTypePluginBundle is com.apple.plugin.
UTType *UTTypePluginBundle;

// UTTypeSpotlightImporter is com.apple.metadata-importer.
UTType *UTTypeSpotlightImporter;

// UTTypeQuickLookGenerator is com.apple.quicklook-generator.
UTType *UTTypeQuickLookGenerator;

// UTTypeXPCService is com.apple.xpc-service.
UTType *UTTypeXPCService;

// UTTypeFramework is com.apple.framework.
UTType *UTTypeFramework;

// UTTypeApplication is com.apple.application.
UTType *UTTypeApplication;

// UTTypeApplicationBundle is com.apple.application-bundle.
UTType *UTTypeApplicationBundle;

// UTTypeApplicationExtension is com.apple.application-and-system-extension.
UTType *UTTypeApplicationExtension;

// UTTypeUnixExecutable is public.unix-executable.
UTType *UTTypeUnixExecutable;

// UTTypeEXE is com.microsoft.windows-executable.
UTType *UTTypeEXE;

// UTTypeSystemPreferencesPane is com.apple.systempreference.prefpane.
UTType *UTTypeSystemPreferencesPane;

// UTTypeArchive is public.archive.
UTType *UTTypeArchive;

// UTTypeGZIP is org.gnu.gnu-zip-archive.
UTType *UTTypeGZIP;

// UTTypeBZ2 is public.bzip2-archive.
UTType *UTTypeBZ2;

// UTTypeZIP is public.zip-archive.
UTType *UTTypeZIP;

// UTTypeAppleArchive is com.apple.archive.
UTType *UTTypeAppleArchive;

// UTTypeSpreadsheet is public.spreadsheet.
UTType *UTTypeSpreadsheet;

// UTTypePresentation is public.presentation.
UTType *UTTypePresentation;

// UTTypeDatabase is public.database.
UTType *UTTypeDatabase;

// UTTypeMessage is public.message.
UTType *UTTypeMessage;

// UTTypeContact is public.contact.
UTType *UTTypeContact;

// UTTypeVCard is public.vcard.
UTType *UTTypeVCard;

// UTTypeToDoItem is public.to-do-item.
UTType *UTTypeToDoItem;

// UTTypeCalendarEvent is public.calendar-event.
UTType *UTTypeCalendarEvent;

// UTTypeEmailMessage is public.email-message.
UTType *UTTypeEmailMessage;

// UTTypeInternetLocation is com.apple.internet-location.
UTType *UTTypeInternetLocation;

// UTTypeInternetShortcut is com.microsoft.internet-shortcut.
UTType *UTTypeInternetShortcut;

// UTTypeFont is public.font.
UTType *UTTypeFont;

// UTTypeBookmark is public.bookmark.
UTType *UTTypeBookmark;

// UTTypePKCS12 is com.rsa.pkcs-12.
UTType *UTTypePKCS12;

// UTTypeX509Certificate is public.x509-certificate.
UTType *UTTypeX509Certificate;

// UTTypeEPUB is org.idpf.epub-container.
UTType *UTTypeEPUB;

// UTTypeLog is public.log.
UTType *UTTypeLog;

__attribute__((constructor)) static void charon_uttype_catalog_14(void)
{
    UTTypeCompositeContent = [UTType typeWithIdentifier:@"public.composite-content"];
    UTTypeDiskImage = [UTType typeWithIdentifier:@"public.disk-image"];
    UTTypeResolvable = [UTType typeWithIdentifier:@"com.apple.resolvable"];
    UTTypeSymbolicLink = [UTType typeWithIdentifier:@"public.symlink"];
    UTTypeExecutable = [UTType typeWithIdentifier:@"public.executable"];
    UTTypeMountPoint = [UTType typeWithIdentifier:@"com.apple.mount-point"];
    UTTypeAliasFile = [UTType typeWithIdentifier:@"com.apple.alias-file"];
    UTTypeURLBookmarkData = [UTType typeWithIdentifier:@"com.apple.bookmark"];
    UTTypeUTF16ExternalPlainText = [UTType typeWithIdentifier:@"public.utf16-external-plain-text"];
    UTTypeUTF16PlainText = [UTType typeWithIdentifier:@"public.utf16-plain-text"];
    UTTypeDelimitedText = [UTType typeWithIdentifier:@"public.delimited-values-text"];
    UTTypeCommaSeparatedText = [UTType typeWithIdentifier:@"public.comma-separated-values-text"];
    UTTypeTabSeparatedText = [UTType typeWithIdentifier:@"public.tab-separated-values-text"];
    UTTypeUTF8TabSeparatedText = [UTType typeWithIdentifier:@"public.utf8-tab-separated-values-text"];
    UTTypeRTF = [UTType typeWithIdentifier:@"public.rtf"];
    UTTypeHTML = [UTType typeWithIdentifier:@"public.html"];
    UTTypeXML = [UTType typeWithIdentifier:@"public.xml"];
    UTTypeYAML = [UTType typeWithIdentifier:@"public.yaml"];
    UTTypeSourceCode = [UTType typeWithIdentifier:@"public.source-code"];
    UTTypeAssemblyLanguageSource = [UTType typeWithIdentifier:@"public.assembly-source"];
    UTTypeCSource = [UTType typeWithIdentifier:@"public.c-source"];
    UTTypeObjectiveCSource = [UTType typeWithIdentifier:@"public.objective-c-source"];
    UTTypeSwiftSource = [UTType typeWithIdentifier:@"public.swift-source"];
    UTTypeCPlusPlusSource = [UTType typeWithIdentifier:@"public.c-plus-plus-source"];
    UTTypeObjectiveCPlusPlusSource = [UTType typeWithIdentifier:@"public.objective-c-plus-plus-source"];
    UTTypeCHeader = [UTType typeWithIdentifier:@"public.c-header"];
    UTTypeCPlusPlusHeader = [UTType typeWithIdentifier:@"public.c-plus-plus-header"];
    UTTypeScript = [UTType typeWithIdentifier:@"public.script"];
    UTTypeAppleScript = [UTType typeWithIdentifier:@"com.apple.applescript.text"];
    UTTypeOSAScript = [UTType typeWithIdentifier:@"com.apple.applescript.script"];
    UTTypeOSAScriptBundle = [UTType typeWithIdentifier:@"com.apple.applescript.script-bundle"];
    UTTypeJavaScript = [UTType typeWithIdentifier:@"com.netscape.javascript-source"];
    UTTypeShellScript = [UTType typeWithIdentifier:@"public.shell-script"];
    UTTypePerlScript = [UTType typeWithIdentifier:@"public.perl-script"];
    UTTypePythonScript = [UTType typeWithIdentifier:@"public.python-script"];
    UTTypeRubyScript = [UTType typeWithIdentifier:@"public.ruby-script"];
    UTTypePHPScript = [UTType typeWithIdentifier:@"public.php-script"];
    UTTypeJSON = [UTType typeWithIdentifier:@"public.json"];
    UTTypePropertyList = [UTType typeWithIdentifier:@"com.apple.property-list"];
    UTTypeXMLPropertyList = [UTType typeWithIdentifier:@"com.apple.xml-property-list"];
    UTTypeBinaryPropertyList = [UTType typeWithIdentifier:@"com.apple.binary-property-list"];
    UTTypeRTFD = [UTType typeWithIdentifier:@"com.apple.rtfd"];
    UTTypeFlatRTFD = [UTType typeWithIdentifier:@"com.apple.flat-rtfd"];
    UTTypeWebArchive = [UTType typeWithIdentifier:@"com.apple.webarchive"];
    UTTypeJPEG = [UTType typeWithIdentifier:@"public.jpeg"];
    UTTypeTIFF = [UTType typeWithIdentifier:@"public.tiff"];
    UTTypeGIF = [UTType typeWithIdentifier:@"com.compuserve.gif"];
    UTTypePNG = [UTType typeWithIdentifier:@"public.png"];
    UTTypeICNS = [UTType typeWithIdentifier:@"com.apple.icns"];
    UTTypeBMP = [UTType typeWithIdentifier:@"com.microsoft.bmp"];
    UTTypeICO = [UTType typeWithIdentifier:@"com.microsoft.ico"];
    UTTypeRAWImage = [UTType typeWithIdentifier:@"public.camera-raw-image"];
    UTTypeSVG = [UTType typeWithIdentifier:@"public.svg-image"];
    UTTypeLivePhoto = [UTType typeWithIdentifier:@"com.apple.live-photo"];
    UTTypeHEIF = [UTType typeWithIdentifier:@"public.heif"];
    UTTypeHEIC = [UTType typeWithIdentifier:@"public.heic"];
    UTTypeWebP = [UTType typeWithIdentifier:@"org.webmproject.webp"];
    UTType3DContent = [UTType typeWithIdentifier:@"public.3d-content"];
    UTTypeUSD = [UTType typeWithIdentifier:@"com.pixar.universal-scene-description"];
    UTTypeUSDZ = [UTType typeWithIdentifier:@"com.pixar.universal-scene-description-mobile"];
    UTTypeRealityFile = [UTType typeWithIdentifier:@"com.apple.reality"];
    UTTypeSceneKitScene = [UTType typeWithIdentifier:@"com.apple.scenekit.scene"];
    UTTypeARReferenceObject = [UTType typeWithIdentifier:@"com.apple.arobject"];
    UTTypeAudiovisualContent = [UTType typeWithIdentifier:@"public.audiovisual-content"];
    UTTypeMovie = [UTType typeWithIdentifier:@"public.movie"];
    UTTypeVideo = [UTType typeWithIdentifier:@"public.video"];
    UTTypeAudio = [UTType typeWithIdentifier:@"public.audio"];
    UTTypeQuickTimeMovie = [UTType typeWithIdentifier:@"com.apple.quicktime-movie"];
    UTTypeMPEG = [UTType typeWithIdentifier:@"public.mpeg"];
    UTTypeMPEG2Video = [UTType typeWithIdentifier:@"public.mpeg-2-video"];
    UTTypeMPEG2TransportStream = [UTType typeWithIdentifier:@"public.mpeg-2-transport-stream"];
    UTTypeMP3 = [UTType typeWithIdentifier:@"public.mp3"];
    UTTypeMPEG4Movie = [UTType typeWithIdentifier:@"public.mpeg-4"];
    UTTypeMPEG4Audio = [UTType typeWithIdentifier:@"public.mpeg-4-audio"];
    UTTypeAppleProtectedMPEG4Audio = [UTType typeWithIdentifier:@"com.apple.protected-mpeg-4-audio"];
    UTTypeAppleProtectedMPEG4Video = [UTType typeWithIdentifier:@"com.apple.protected-mpeg-4-video"];
    UTTypeAVI = [UTType typeWithIdentifier:@"public.avi"];
    UTTypeAIFF = [UTType typeWithIdentifier:@"public.aiff-audio"];
    UTTypeWAV = [UTType typeWithIdentifier:@"com.microsoft.waveform-audio"];
    UTTypeMIDI = [UTType typeWithIdentifier:@"public.midi-audio"];
    UTTypePlaylist = [UTType typeWithIdentifier:@"public.playlist"];
    UTTypeM3UPlaylist = [UTType typeWithIdentifier:@"public.m3u-playlist"];
    UTTypeFolder = [UTType typeWithIdentifier:@"public.folder"];
    UTTypeVolume = [UTType typeWithIdentifier:@"public.volume"];
    UTTypePackage = [UTType typeWithIdentifier:@"com.apple.package"];
    UTTypeBundle = [UTType typeWithIdentifier:@"com.apple.bundle"];
    UTTypePluginBundle = [UTType typeWithIdentifier:@"com.apple.plugin"];
    UTTypeSpotlightImporter = [UTType typeWithIdentifier:@"com.apple.metadata-importer"];
    UTTypeQuickLookGenerator = [UTType typeWithIdentifier:@"com.apple.quicklook-generator"];
    UTTypeXPCService = [UTType typeWithIdentifier:@"com.apple.xpc-service"];
    UTTypeFramework = [UTType typeWithIdentifier:@"com.apple.framework"];
    UTTypeApplication = [UTType typeWithIdentifier:@"com.apple.application"];
    UTTypeApplicationBundle = [UTType typeWithIdentifier:@"com.apple.application-bundle"];
    UTTypeApplicationExtension = [UTType typeWithIdentifier:@"com.apple.application-and-system-extension"];
    UTTypeUnixExecutable = [UTType typeWithIdentifier:@"public.unix-executable"];
    UTTypeEXE = [UTType typeWithIdentifier:@"com.microsoft.windows-executable"];
    UTTypeSystemPreferencesPane = [UTType typeWithIdentifier:@"com.apple.systempreference.prefpane"];
    UTTypeArchive = [UTType typeWithIdentifier:@"public.archive"];
    UTTypeGZIP = [UTType typeWithIdentifier:@"org.gnu.gnu-zip-archive"];
    UTTypeBZ2 = [UTType typeWithIdentifier:@"public.bzip2-archive"];
    UTTypeZIP = [UTType typeWithIdentifier:@"public.zip-archive"];
    UTTypeAppleArchive = [UTType typeWithIdentifier:@"com.apple.archive"];
    UTTypeSpreadsheet = [UTType typeWithIdentifier:@"public.spreadsheet"];
    UTTypePresentation = [UTType typeWithIdentifier:@"public.presentation"];
    UTTypeDatabase = [UTType typeWithIdentifier:@"public.database"];
    UTTypeMessage = [UTType typeWithIdentifier:@"public.message"];
    UTTypeContact = [UTType typeWithIdentifier:@"public.contact"];
    UTTypeVCard = [UTType typeWithIdentifier:@"public.vcard"];
    UTTypeToDoItem = [UTType typeWithIdentifier:@"public.to-do-item"];
    UTTypeCalendarEvent = [UTType typeWithIdentifier:@"public.calendar-event"];
    UTTypeEmailMessage = [UTType typeWithIdentifier:@"public.email-message"];
    UTTypeInternetLocation = [UTType typeWithIdentifier:@"com.apple.internet-location"];
    UTTypeInternetShortcut = [UTType typeWithIdentifier:@"com.microsoft.internet-shortcut"];
    UTTypeFont = [UTType typeWithIdentifier:@"public.font"];
    UTTypeBookmark = [UTType typeWithIdentifier:@"public.bookmark"];
    UTTypePKCS12 = [UTType typeWithIdentifier:@"com.rsa.pkcs-12"];
    UTTypeX509Certificate = [UTType typeWithIdentifier:@"public.x509-certificate"];
    UTTypeEPUB = [UTType typeWithIdentifier:@"org.idpf.epub-container"];
    UTTypeLog = [UTType typeWithIdentifier:@"public.log"];

    // Handed to the index -[UTType supertypes] reads; see UIKit/UTTypeCatalogueIndex.m.
    charon_uttype_catalogue_add(@[UTTypeCompositeContent, UTTypeDiskImage, UTTypeResolvable, UTTypeSymbolicLink, UTTypeExecutable, UTTypeMountPoint, UTTypeAliasFile, UTTypeURLBookmarkData, UTTypeUTF16ExternalPlainText, UTTypeUTF16PlainText, UTTypeDelimitedText, UTTypeCommaSeparatedText, UTTypeTabSeparatedText, UTTypeUTF8TabSeparatedText, UTTypeRTF, UTTypeHTML, UTTypeXML, UTTypeYAML, UTTypeSourceCode, UTTypeAssemblyLanguageSource, UTTypeCSource, UTTypeObjectiveCSource, UTTypeSwiftSource, UTTypeCPlusPlusSource, UTTypeObjectiveCPlusPlusSource, UTTypeCHeader, UTTypeCPlusPlusHeader, UTTypeScript, UTTypeAppleScript, UTTypeOSAScript, UTTypeOSAScriptBundle, UTTypeJavaScript, UTTypeShellScript, UTTypePerlScript, UTTypePythonScript, UTTypeRubyScript, UTTypePHPScript, UTTypeJSON, UTTypePropertyList, UTTypeXMLPropertyList, UTTypeBinaryPropertyList, UTTypeRTFD, UTTypeFlatRTFD, UTTypeWebArchive, UTTypeJPEG, UTTypeTIFF, UTTypeGIF, UTTypePNG, UTTypeICNS, UTTypeBMP, UTTypeICO, UTTypeRAWImage, UTTypeSVG, UTTypeLivePhoto, UTTypeHEIF, UTTypeHEIC, UTTypeWebP, UTType3DContent, UTTypeUSD, UTTypeUSDZ, UTTypeRealityFile, UTTypeSceneKitScene, UTTypeARReferenceObject, UTTypeAudiovisualContent, UTTypeMovie, UTTypeVideo, UTTypeAudio, UTTypeQuickTimeMovie, UTTypeMPEG, UTTypeMPEG2Video, UTTypeMPEG2TransportStream, UTTypeMP3, UTTypeMPEG4Movie, UTTypeMPEG4Audio, UTTypeAppleProtectedMPEG4Audio, UTTypeAppleProtectedMPEG4Video, UTTypeAVI, UTTypeAIFF, UTTypeWAV, UTTypeMIDI, UTTypePlaylist, UTTypeM3UPlaylist, UTTypeFolder, UTTypeVolume, UTTypePackage, UTTypeBundle, UTTypePluginBundle, UTTypeSpotlightImporter, UTTypeQuickLookGenerator, UTTypeXPCService, UTTypeFramework, UTTypeApplication, UTTypeApplicationBundle, UTTypeApplicationExtension, UTTypeUnixExecutable, UTTypeEXE, UTTypeSystemPreferencesPane, UTTypeArchive, UTTypeGZIP, UTTypeBZ2, UTTypeZIP, UTTypeAppleArchive, UTTypeSpreadsheet, UTTypePresentation, UTTypeDatabase, UTTypeMessage, UTTypeContact, UTTypeVCard, UTTypeToDoItem, UTTypeCalendarEvent, UTTypeEmailMessage, UTTypeInternetLocation, UTTypeInternetShortcut, UTTypeFont, UTTypeBookmark, UTTypePKCS12, UTTypeX509Certificate, UTTypeEPUB, UTTypeLog]);
}

// UTTagClass.h carries two tag classes, and their values are the same two strings the release's own
// MobileCoreServices declares as kUTTagClassFilenameExtension and kUTTagClassMIMEType --
// UniformTypeIdentifiers' spelling of the same two, whose values the host's own answers with are
// public.filename-extension and public.mime-type, read on every run of
// tests/backports/host/uttypeconstants. They are `NSString *const` in the SDK's own header, and a
// const object needs its initializer at its definition, so unlike the UTType constants above these
// two are not filled in by the constructor.
NSString *const UTTagClassFilenameExtension = @"public.filename-extension";
NSString *const UTTagClassMIMEType = @"public.mime-type";
