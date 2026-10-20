#import "RevenantUTType.h"

UTType *UTTypeCompositeContent;

UTType *UTTypeDiskImage;

UTType *UTTypeResolvable;

UTType *UTTypeSymbolicLink;

UTType *UTTypeExecutable;

UTType *UTTypeMountPoint;

UTType *UTTypeAliasFile;

UTType *UTTypeURLBookmarkData;

UTType *UTTypeUTF16ExternalPlainText;

UTType *UTTypeUTF16PlainText;

UTType *UTTypeDelimitedText;

UTType *UTTypeCommaSeparatedText;

UTType *UTTypeTabSeparatedText;

UTType *UTTypeUTF8TabSeparatedText;

UTType *UTTypeRTF;

UTType *UTTypeHTML;

UTType *UTTypeXML;

UTType *UTTypeYAML;

UTType *UTTypeSourceCode;

UTType *UTTypeAssemblyLanguageSource;

UTType *UTTypeCSource;

UTType *UTTypeObjectiveCSource;

UTType *UTTypeSwiftSource;

UTType *UTTypeCPlusPlusSource;

UTType *UTTypeObjectiveCPlusPlusSource;

UTType *UTTypeCHeader;

UTType *UTTypeCPlusPlusHeader;

UTType *UTTypeScript;

UTType *UTTypeAppleScript;

UTType *UTTypeOSAScript;

UTType *UTTypeOSAScriptBundle;

UTType *UTTypeJavaScript;

UTType *UTTypeShellScript;

UTType *UTTypePerlScript;

UTType *UTTypePythonScript;

UTType *UTTypeRubyScript;

UTType *UTTypePHPScript;

UTType *UTTypeJSON;

UTType *UTTypePropertyList;

UTType *UTTypeXMLPropertyList;

UTType *UTTypeBinaryPropertyList;

UTType *UTTypeRTFD;

UTType *UTTypeFlatRTFD;

UTType *UTTypeWebArchive;

UTType *UTTypeJPEG;

UTType *UTTypeTIFF;

UTType *UTTypeGIF;

UTType *UTTypePNG;

UTType *UTTypeICNS;

UTType *UTTypeBMP;

UTType *UTTypeICO;

UTType *UTTypeRAWImage;

UTType *UTTypeSVG;

UTType *UTTypeLivePhoto;

UTType *UTTypeHEIF;

UTType *UTTypeHEIC;

UTType *UTTypeWebP;

UTType *UTType3DContent;

UTType *UTTypeUSD;

UTType *UTTypeUSDZ;

UTType *UTTypeRealityFile;

UTType *UTTypeSceneKitScene;

UTType *UTTypeARReferenceObject;

UTType *UTTypeAudiovisualContent;

UTType *UTTypeMovie;

UTType *UTTypeVideo;

UTType *UTTypeAudio;

UTType *UTTypeQuickTimeMovie;

UTType *UTTypeMPEG;

UTType *UTTypeMPEG2Video;

UTType *UTTypeMPEG2TransportStream;

UTType *UTTypeMP3;

UTType *UTTypeMPEG4Movie;

UTType *UTTypeMPEG4Audio;

UTType *UTTypeAppleProtectedMPEG4Audio;

UTType *UTTypeAppleProtectedMPEG4Video;

UTType *UTTypeAVI;

UTType *UTTypeAIFF;

UTType *UTTypeWAV;

UTType *UTTypeMIDI;

UTType *UTTypePlaylist;

UTType *UTTypeM3UPlaylist;

UTType *UTTypeFolder;

UTType *UTTypeVolume;

UTType *UTTypePackage;

UTType *UTTypeBundle;

UTType *UTTypePluginBundle;

UTType *UTTypeSpotlightImporter;

UTType *UTTypeQuickLookGenerator;

UTType *UTTypeXPCService;

UTType *UTTypeFramework;

UTType *UTTypeApplication;

UTType *UTTypeApplicationBundle;

UTType *UTTypeApplicationExtension;

UTType *UTTypeUnixExecutable;

UTType *UTTypeEXE;

UTType *UTTypeSystemPreferencesPane;

UTType *UTTypeArchive;

UTType *UTTypeGZIP;

UTType *UTTypeBZ2;

UTType *UTTypeZIP;

UTType *UTTypeAppleArchive;

UTType *UTTypeSpreadsheet;

UTType *UTTypePresentation;

UTType *UTTypeDatabase;

UTType *UTTypeMessage;

UTType *UTTypeContact;

UTType *UTTypeVCard;

UTType *UTTypeToDoItem;

UTType *UTTypeCalendarEvent;

UTType *UTTypeEmailMessage;

UTType *UTTypeInternetLocation;

UTType *UTTypeInternetShortcut;

UTType *UTTypeFont;

UTType *UTTypeBookmark;

UTType *UTTypePKCS12;

UTType *UTTypeX509Certificate;

UTType *UTTypeEPUB;

UTType *UTTypeLog;

__attribute__((constructor)) static void revenant_uttype_catalog_14(void)
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

    revenant_uttype_catalogue_add(@[UTTypeCompositeContent, UTTypeDiskImage, UTTypeResolvable, UTTypeSymbolicLink, UTTypeExecutable, UTTypeMountPoint, UTTypeAliasFile, UTTypeURLBookmarkData, UTTypeUTF16ExternalPlainText, UTTypeUTF16PlainText, UTTypeDelimitedText, UTTypeCommaSeparatedText, UTTypeTabSeparatedText, UTTypeUTF8TabSeparatedText, UTTypeRTF, UTTypeHTML, UTTypeXML, UTTypeYAML, UTTypeSourceCode, UTTypeAssemblyLanguageSource, UTTypeCSource, UTTypeObjectiveCSource, UTTypeSwiftSource, UTTypeCPlusPlusSource, UTTypeObjectiveCPlusPlusSource, UTTypeCHeader, UTTypeCPlusPlusHeader, UTTypeScript, UTTypeAppleScript, UTTypeOSAScript, UTTypeOSAScriptBundle, UTTypeJavaScript, UTTypeShellScript, UTTypePerlScript, UTTypePythonScript, UTTypeRubyScript, UTTypePHPScript, UTTypeJSON, UTTypePropertyList, UTTypeXMLPropertyList, UTTypeBinaryPropertyList, UTTypeRTFD, UTTypeFlatRTFD, UTTypeWebArchive, UTTypeJPEG, UTTypeTIFF, UTTypeGIF, UTTypePNG, UTTypeICNS, UTTypeBMP, UTTypeICO, UTTypeRAWImage, UTTypeSVG, UTTypeLivePhoto, UTTypeHEIF, UTTypeHEIC, UTTypeWebP, UTType3DContent, UTTypeUSD, UTTypeUSDZ, UTTypeRealityFile, UTTypeSceneKitScene, UTTypeARReferenceObject, UTTypeAudiovisualContent, UTTypeMovie, UTTypeVideo, UTTypeAudio, UTTypeQuickTimeMovie, UTTypeMPEG, UTTypeMPEG2Video, UTTypeMPEG2TransportStream, UTTypeMP3, UTTypeMPEG4Movie, UTTypeMPEG4Audio, UTTypeAppleProtectedMPEG4Audio, UTTypeAppleProtectedMPEG4Video, UTTypeAVI, UTTypeAIFF, UTTypeWAV, UTTypeMIDI, UTTypePlaylist, UTTypeM3UPlaylist, UTTypeFolder, UTTypeVolume, UTTypePackage, UTTypeBundle, UTTypePluginBundle, UTTypeSpotlightImporter, UTTypeQuickLookGenerator, UTTypeXPCService, UTTypeFramework, UTTypeApplication, UTTypeApplicationBundle, UTTypeApplicationExtension, UTTypeUnixExecutable, UTTypeEXE, UTTypeSystemPreferencesPane, UTTypeArchive, UTTypeGZIP, UTTypeBZ2, UTTypeZIP, UTTypeAppleArchive, UTTypeSpreadsheet, UTTypePresentation, UTTypeDatabase, UTTypeMessage, UTTypeContact, UTTypeVCard, UTTypeToDoItem, UTTypeCalendarEvent, UTTypeEmailMessage, UTTypeInternetLocation, UTTypeInternetShortcut, UTTypeFont, UTTypeBookmark, UTTypePKCS12, UTTypeX509Certificate, UTTypeEPUB, UTTypeLog]);
}

NSString *const UTTagClassFilenameExtension = @"public.filename-extension";
NSString *const UTTagClassMIMEType = @"public.mime-type";
