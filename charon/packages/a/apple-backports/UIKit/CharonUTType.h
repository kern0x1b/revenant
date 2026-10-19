#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UTType : NSObject <NSCopying>

@property (readonly, copy) NSString *identifier;
@property (readonly, nullable, copy) NSString *preferredFilenameExtension;
@property (readonly, nullable, copy) NSString *preferredMIMEType;
@property (readonly, nullable, copy) NSString *localizedDescription;
@property (readonly, copy) NSDictionary<NSString *, NSArray<NSString *> *> *tags;
@property (readonly, getter=isDynamic) BOOL dynamic;
@property (readonly, getter=isDeclared) BOOL declared;
@property (readonly, getter=isPublicType) BOOL publicType;
@property (readonly, nullable) NSNumber *version;
@property (readonly, nullable) NSURL *referenceURL;

+ (nullable instancetype)typeWithIdentifier:(NSString *)identifier;
+ (nullable instancetype)typeWithFilenameExtension:(NSString *)filenameExtension;
+ (nullable instancetype)typeWithFilenameExtension:(NSString *)filenameExtension conformingToType:(nullable UTType *)supertype;
+ (nullable instancetype)typeWithMIMEType:(NSString *)mimeType;
+ (nullable instancetype)typeWithMIMEType:(NSString *)mimeType conformingToType:(nullable UTType *)supertype;
+ (nullable instancetype)typeWithTag:(NSString *)tag tagClass:(NSString *)tagClass conformingToType:(nullable UTType *)supertype;
+ (NSArray<UTType *> *)typesWithTag:(NSString *)tag tagClass:(NSString *)tagClass conformingToType:(nullable UTType *)supertype;

- (BOOL)conformsToType:(UTType *)type;
- (BOOL)isSupertypeOfType:(UTType *)type;
- (BOOL)isSubtypeOfType:(UTType *)type;

@property (readonly) NSSet<UTType *> *supertypes;

@end

@interface UTType (LocalConstants)

+ (UTType *)exportedTypeWithIdentifier:(NSString *)identifier;
+ (UTType *)exportedTypeWithIdentifier:(NSString *)identifier conformingToType:(UTType *)parentType;
+ (UTType *)importedTypeWithIdentifier:(NSString *)identifier;
+ (UTType *)importedTypeWithIdentifier:(NSString *)identifier conformingToType:(UTType *)parentType;

@end

FOUNDATION_EXPORT UTType *UTTypeItem;
FOUNDATION_EXPORT UTType *UTTypeContent;
FOUNDATION_EXPORT UTType *UTTypeData;
FOUNDATION_EXPORT UTType *UTTypeDirectory;
FOUNDATION_EXPORT UTType *UTTypeURL;
FOUNDATION_EXPORT UTType *UTTypeFileURL;
FOUNDATION_EXPORT UTType *UTTypeText;
FOUNDATION_EXPORT UTType *UTTypePlainText;
FOUNDATION_EXPORT UTType *UTTypeUTF8PlainText;
FOUNDATION_EXPORT UTType *UTTypeImage;
FOUNDATION_EXPORT UTType *UTTypePDF;

// Charon's own index of the catalogue above, filled by each UTTypeCatalogue<BAND>.m and read by
// -[UTType supertypes]; declared here because the catalogue files and the class are separate
// objects. Not API: no SDK header declares either name, and both begin `charon_`, which is how
// modules/apple/backports.lua reads a symbol of this library's own.
FOUNDATION_EXPORT void charon_uttype_catalogue_add(NSArray *types);
FOUNDATION_EXPORT NSArray *charon_uttype_catalogue_types(void);

FOUNDATION_EXPORT NSString *const UTTagClassFilenameExtension;
FOUNDATION_EXPORT NSString *const UTTagClassMIMEType;


// The system type catalogue UniformTypeIdentifiers declares, transcribed from the
// `UTI:` line of each constant's own doc comment in SDK 26.2's UTCoreTypes.h; see
// facts/UIKit/UTTypeCatalog.md for the table and for the one identifier the header gets wrong.
FOUNDATION_EXPORT UTType *UTTypeCompositeContent;
FOUNDATION_EXPORT UTType *UTTypeDiskImage;
FOUNDATION_EXPORT UTType *UTTypeResolvable;
FOUNDATION_EXPORT UTType *UTTypeSymbolicLink;
FOUNDATION_EXPORT UTType *UTTypeExecutable;
FOUNDATION_EXPORT UTType *UTTypeMountPoint;
FOUNDATION_EXPORT UTType *UTTypeAliasFile;
FOUNDATION_EXPORT UTType *UTTypeURLBookmarkData;
FOUNDATION_EXPORT UTType *UTTypeUTF16ExternalPlainText;
FOUNDATION_EXPORT UTType *UTTypeUTF16PlainText;
FOUNDATION_EXPORT UTType *UTTypeDelimitedText;
FOUNDATION_EXPORT UTType *UTTypeCommaSeparatedText;
FOUNDATION_EXPORT UTType *UTTypeTabSeparatedText;
FOUNDATION_EXPORT UTType *UTTypeUTF8TabSeparatedText;
FOUNDATION_EXPORT UTType *UTTypeRTF;
FOUNDATION_EXPORT UTType *UTTypeHTML;
FOUNDATION_EXPORT UTType *UTTypeXML;
FOUNDATION_EXPORT UTType *UTTypeYAML;
FOUNDATION_EXPORT UTType *UTTypeCSS;
FOUNDATION_EXPORT UTType *UTTypeSourceCode;
FOUNDATION_EXPORT UTType *UTTypeAssemblyLanguageSource;
FOUNDATION_EXPORT UTType *UTTypeCSource;
FOUNDATION_EXPORT UTType *UTTypeObjectiveCSource;
FOUNDATION_EXPORT UTType *UTTypeSwiftSource;
FOUNDATION_EXPORT UTType *UTTypeCPlusPlusSource;
FOUNDATION_EXPORT UTType *UTTypeObjectiveCPlusPlusSource;
FOUNDATION_EXPORT UTType *UTTypeCHeader;
FOUNDATION_EXPORT UTType *UTTypeCPlusPlusHeader;
FOUNDATION_EXPORT UTType *UTTypeScript;
FOUNDATION_EXPORT UTType *UTTypeAppleScript;
FOUNDATION_EXPORT UTType *UTTypeOSAScript;
FOUNDATION_EXPORT UTType *UTTypeOSAScriptBundle;
FOUNDATION_EXPORT UTType *UTTypeJavaScript;
FOUNDATION_EXPORT UTType *UTTypeShellScript;
FOUNDATION_EXPORT UTType *UTTypePerlScript;
FOUNDATION_EXPORT UTType *UTTypePythonScript;
FOUNDATION_EXPORT UTType *UTTypeRubyScript;
FOUNDATION_EXPORT UTType *UTTypePHPScript;
FOUNDATION_EXPORT UTType *UTTypeMakefile;
FOUNDATION_EXPORT UTType *UTTypeJSON;
FOUNDATION_EXPORT UTType *UTTypePropertyList;
FOUNDATION_EXPORT UTType *UTTypeXMLPropertyList;
FOUNDATION_EXPORT UTType *UTTypeBinaryPropertyList;
FOUNDATION_EXPORT UTType *UTTypeRTFD;
FOUNDATION_EXPORT UTType *UTTypeFlatRTFD;
FOUNDATION_EXPORT UTType *UTTypeWebArchive;
FOUNDATION_EXPORT UTType *UTTypeJPEG;
FOUNDATION_EXPORT UTType *UTTypeTIFF;
FOUNDATION_EXPORT UTType *UTTypeGIF;
FOUNDATION_EXPORT UTType *UTTypePNG;
FOUNDATION_EXPORT UTType *UTTypeICNS;
FOUNDATION_EXPORT UTType *UTTypeBMP;
FOUNDATION_EXPORT UTType *UTTypeICO;
FOUNDATION_EXPORT UTType *UTTypeRAWImage;
FOUNDATION_EXPORT UTType *UTTypeSVG;
FOUNDATION_EXPORT UTType *UTTypeLivePhoto;
FOUNDATION_EXPORT UTType *UTTypeHEIF;
FOUNDATION_EXPORT UTType *UTTypeHEIC;
FOUNDATION_EXPORT UTType *UTTypeHEICS;
FOUNDATION_EXPORT UTType *UTTypeWebP;
FOUNDATION_EXPORT UTType *UTTypeEXR;
FOUNDATION_EXPORT UTType *UTTypeDNG;
FOUNDATION_EXPORT UTType *UTTypeJPEGXL;
FOUNDATION_EXPORT UTType *UTType3DContent;
FOUNDATION_EXPORT UTType *UTTypeUSD;
FOUNDATION_EXPORT UTType *UTTypeUSDZ;
FOUNDATION_EXPORT UTType *UTTypeRealityFile;
FOUNDATION_EXPORT UTType *UTTypeSceneKitScene;
FOUNDATION_EXPORT UTType *UTTypeARReferenceObject;
FOUNDATION_EXPORT UTType *UTTypeAudiovisualContent;
FOUNDATION_EXPORT UTType *UTTypeMovie;
FOUNDATION_EXPORT UTType *UTTypeVideo;
FOUNDATION_EXPORT UTType *UTTypeAudio;
FOUNDATION_EXPORT UTType *UTTypeQuickTimeMovie;
FOUNDATION_EXPORT UTType *UTTypeMPEG;
FOUNDATION_EXPORT UTType *UTTypeMPEG2Video;
FOUNDATION_EXPORT UTType *UTTypeMPEG2TransportStream;
FOUNDATION_EXPORT UTType *UTTypeMP3;
FOUNDATION_EXPORT UTType *UTTypeMPEG4Movie;
FOUNDATION_EXPORT UTType *UTTypeMPEG4Audio;
FOUNDATION_EXPORT UTType *UTTypeAppleProtectedMPEG4Audio;
FOUNDATION_EXPORT UTType *UTTypeAppleProtectedMPEG4Video;
FOUNDATION_EXPORT UTType *UTTypeAVI;
FOUNDATION_EXPORT UTType *UTTypeAIFF;
FOUNDATION_EXPORT UTType *UTTypeWAV;
FOUNDATION_EXPORT UTType *UTTypeMIDI;
FOUNDATION_EXPORT UTType *UTTypePlaylist;
FOUNDATION_EXPORT UTType *UTTypeM3UPlaylist;
FOUNDATION_EXPORT UTType *UTTypeFolder;
FOUNDATION_EXPORT UTType *UTTypeVolume;
FOUNDATION_EXPORT UTType *UTTypePackage;
FOUNDATION_EXPORT UTType *UTTypeBundle;
FOUNDATION_EXPORT UTType *UTTypePluginBundle;
FOUNDATION_EXPORT UTType *UTTypeSpotlightImporter;
FOUNDATION_EXPORT UTType *UTTypeQuickLookGenerator;
FOUNDATION_EXPORT UTType *UTTypeXPCService;
FOUNDATION_EXPORT UTType *UTTypeFramework;
FOUNDATION_EXPORT UTType *UTTypeApplication;
FOUNDATION_EXPORT UTType *UTTypeApplicationBundle;
FOUNDATION_EXPORT UTType *UTTypeApplicationExtension;
FOUNDATION_EXPORT UTType *UTTypeUnixExecutable;
FOUNDATION_EXPORT UTType *UTTypeEXE;
FOUNDATION_EXPORT UTType *UTTypeSystemPreferencesPane;
FOUNDATION_EXPORT UTType *UTTypeArchive;
FOUNDATION_EXPORT UTType *UTTypeGZIP;
FOUNDATION_EXPORT UTType *UTTypeBZ2;
FOUNDATION_EXPORT UTType *UTTypeZIP;
FOUNDATION_EXPORT UTType *UTTypeAppleArchive;
FOUNDATION_EXPORT UTType *UTTypeTarArchive;
FOUNDATION_EXPORT UTType *UTTypeSpreadsheet;
FOUNDATION_EXPORT UTType *UTTypePresentation;
FOUNDATION_EXPORT UTType *UTTypeDatabase;
FOUNDATION_EXPORT UTType *UTTypeMessage;
FOUNDATION_EXPORT UTType *UTTypeContact;
FOUNDATION_EXPORT UTType *UTTypeVCard;
FOUNDATION_EXPORT UTType *UTTypeToDoItem;
FOUNDATION_EXPORT UTType *UTTypeCalendarEvent;
FOUNDATION_EXPORT UTType *UTTypeEmailMessage;
FOUNDATION_EXPORT UTType *UTTypeInternetLocation;
FOUNDATION_EXPORT UTType *UTTypeInternetShortcut;
FOUNDATION_EXPORT UTType *UTTypeFont;
FOUNDATION_EXPORT UTType *UTTypeBookmark;
FOUNDATION_EXPORT UTType *UTTypePKCS12;
FOUNDATION_EXPORT UTType *UTTypeX509Certificate;
FOUNDATION_EXPORT UTType *UTTypeEPUB;
FOUNDATION_EXPORT UTType *UTTypeLog;
FOUNDATION_EXPORT UTType *UTTypeAHAP;
FOUNDATION_EXPORT UTType *UTTypeGeoJSON;
FOUNDATION_EXPORT UTType *UTTypeLinkPresentationMetadata;

NS_ASSUME_NONNULL_END
