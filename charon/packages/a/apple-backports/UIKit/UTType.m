#import <MobileCoreServices/MobileCoreServices.h>
#import "CharonUTType.h"

// UTType (UniformTypeIdentifiers, iOS 14) is an object wrapper around the same Uniform Type
// Identifier a release since iOS 3 already names with a plain NSString/CFStringRef, and answers
// with the same UTType* C functions MobileCoreServices already carries on iOS 6 -
// UTTypeConformsTo, UTTypeCopyPreferredTagWithClass, UTTypeCopyDescription,
// UTTypeCreatePreferredIdentifierForTag - so nothing here is invented, only wrapped. Carried
// because -[UIDocumentPickerViewController initForOpeningContentTypes:asCopy:] (UIKit 14) and its
// three siblings take an array of these instead of the UTI strings the iOS 8-13 initialisers took
// (see UIDocumentPickerViewController.m), and iOS 6 never had UniformTypeIdentifiers to make them
// with. The identifiers behind the eleven constants below are the System-Declared Uniform Type
// Identifiers Apple has kept unchanged since the UTI system's introduction; each is exactly the
// identifier the real UTCoreTypes.h documents for the same constant name (checked against the
// local SDK's own header, not guessed). The constants are plain, non-const globals, the same way
// CFEmptyCollections.m's __NSArray0__/__NSDictionary0__ are: a recent SDK's own header declares
// them `UTType *const`, but that is a promise to the header's callers, not a constraint on how
// this backport's own translation unit stores them, so a constructor fills them in once, here.

@interface UTType ()
@property (nonatomic, readonly, copy) NSString *charon_identifier;
@end

@implementation UTType

@synthesize charon_identifier = _charon_identifier;

// Carried by UTTypeDeclarations14.m, not by this object, so the auto-synthesis of a property this
// implementation does not answer has to be turned off here: a synthesized accessor would be a second
// definition of the selector the category already adds (and modules/apple/backports.lua counts a
// category method only where the class does not answer the selector, so the class must not).
@dynamic version;
@dynamic referenceURL;
@dynamic supertypes;

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException format:@"+[UTType new] is unavailable"];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException format:@"-[UTType init] is unavailable"];
    return nil;
}

- (instancetype)charon_initWithIdentifier:(NSString *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self)
        _charon_identifier = [identifier copy];
    return self;
}

+ (instancetype)typeWithIdentifier:(NSString *)identifier
{
    if (!identifier.length)
        return nil;
    return [[self alloc] charon_initWithIdentifier:identifier];
}

+ (instancetype)typeWithTag:(NSString *)tag tagClass:(NSString *)tagClass conformingToType:(UTType *)supertype
{
    NSString *identifier = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag((__bridge CFStringRef)tagClass, (__bridge CFStringRef)tag, (__bridge CFStringRef)supertype.identifier));
    return [self typeWithIdentifier:identifier];
}

+ (NSArray<UTType *> *)typesWithTag:(NSString *)tag tagClass:(NSString *)tagClass conformingToType:(UTType *)supertype
{
    UTType *type = [self typeWithTag:tag tagClass:tagClass conformingToType:supertype];
    return type ? @[type] : @[];
}

+ (instancetype)typeWithFilenameExtension:(NSString *)filenameExtension
{
    return [self typeWithTag:filenameExtension tagClass:(NSString *)kUTTagClassFilenameExtension conformingToType:nil];
}

+ (instancetype)typeWithFilenameExtension:(NSString *)filenameExtension conformingToType:(UTType *)supertype
{
    return [self typeWithTag:filenameExtension tagClass:(NSString *)kUTTagClassFilenameExtension conformingToType:supertype];
}

+ (instancetype)typeWithMIMEType:(NSString *)mimeType
{
    return [self typeWithTag:mimeType tagClass:(NSString *)kUTTagClassMIMEType conformingToType:nil];
}

+ (instancetype)typeWithMIMEType:(NSString *)mimeType conformingToType:(UTType *)supertype
{
    return [self typeWithTag:mimeType tagClass:(NSString *)kUTTagClassMIMEType conformingToType:supertype];
}

- (NSString *)identifier
{
    return _charon_identifier;
}

- (NSString *)preferredFilenameExtension
{
    return CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_charon_identifier, kUTTagClassFilenameExtension));
}

- (NSString *)preferredMIMEType
{
    return CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_charon_identifier, kUTTagClassMIMEType));
}

- (NSString *)localizedDescription
{
    return CFBridgingRelease(UTTypeCopyDescription((__bridge CFStringRef)_charon_identifier));
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)tags
{
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    for (NSString *tagClass in @[(NSString *)kUTTagClassFilenameExtension, (NSString *)kUTTagClassMIMEType]) {
        NSString *tag = CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_charon_identifier, (__bridge CFStringRef)tagClass));
        if (tag)
            tags[tagClass] = @[tag];
    }
    return tags;
}

- (BOOL)isDynamic
{
    // 6.1.3 exports no UTTypeIsDynamic; this library carries one (UTTypeDynamic8.m), and a band
    // for 8.0 on re-exports the release's. The check stays for a build that has neither.
    if (UTTypeIsDynamic != NULL)
        return UTTypeIsDynamic((__bridge CFStringRef)_charon_identifier);
    return NO;
}

- (BOOL)isDeclared
{
    // As isDynamic above: UTTypeDynamic8.m carries UTTypeIsDeclared where the release has none.
    if (UTTypeIsDeclared != NULL)
        return UTTypeIsDeclared((__bridge CFStringRef)_charon_identifier);
    return YES;
}

- (BOOL)isPublicType
{
    return [_charon_identifier hasPrefix:@"public."];
}

- (BOOL)conformsToType:(UTType *)type
{
    return type != nil && UTTypeConformsTo((__bridge CFStringRef)_charon_identifier, (__bridge CFStringRef)type.identifier);
}

- (BOOL)isSupertypeOfType:(UTType *)type
{
    return type != nil && ![type isEqual:self] && [type conformsToType:self];
}

- (BOOL)isSubtypeOfType:(UTType *)type
{
    return type != nil && ![type isEqual:self] && [self conformsToType:type];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[UTType class]])
        return NO;
    return [_charon_identifier isEqualToString:[(UTType *)other identifier]];
}

- (NSUInteger)hash
{
    return _charon_identifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<UTType: %@>", _charon_identifier];
}

@end

UTType *UTTypeItem;
UTType *UTTypeContent;
UTType *UTTypeData;
UTType *UTTypeDirectory;
UTType *UTTypeURL;
UTType *UTTypeFileURL;
UTType *UTTypeText;
UTType *UTTypePlainText;
UTType *UTTypeUTF8PlainText;
UTType *UTTypeImage;
UTType *UTTypePDF;

__attribute__((constructor)) static void charon_uttype_constants(void)
{
    UTTypeItem = [UTType typeWithIdentifier:@"public.item"];
    UTTypeContent = [UTType typeWithIdentifier:@"public.content"];
    UTTypeData = [UTType typeWithIdentifier:@"public.data"];
    UTTypeDirectory = [UTType typeWithIdentifier:@"public.directory"];
    UTTypeURL = [UTType typeWithIdentifier:@"public.url"];
    UTTypeFileURL = [UTType typeWithIdentifier:@"public.file-url"];
    UTTypeText = [UTType typeWithIdentifier:@"public.text"];
    UTTypePlainText = [UTType typeWithIdentifier:@"public.plain-text"];
    UTTypeUTF8PlainText = [UTType typeWithIdentifier:@"public.utf8-plain-text"];
    UTTypeImage = [UTType typeWithIdentifier:@"public.image"];
    UTTypePDF = [UTType typeWithIdentifier:@"com.adobe.pdf"];

    // Handed to the index -[UTType supertypes] reads, with the constants of the catalogue files
    // beside this one; see UIKit/UTTypeCatalogueIndex.m.
    charon_uttype_catalogue_add(@[UTTypeItem, UTTypeContent, UTTypeData, UTTypeDirectory, UTTypeURL,
                                  UTTypeFileURL, UTTypeText, UTTypePlainText, UTTypeUTF8PlainText,
                                  UTTypeImage, UTTypePDF]);
}
