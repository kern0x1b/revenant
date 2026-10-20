#import <MobileCoreServices/MobileCoreServices.h>
#import "RevenantUTType.h"

@interface UTType ()
@property (nonatomic, readonly, copy) NSString *revenant_identifier;
@end

@implementation UTType

@synthesize revenant_identifier = _revenant_identifier;

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

- (instancetype)revenant_initWithIdentifier:(NSString *)identifier __attribute__((objc_method_family(init)))
{
    self = [super init];
    if (self)
        _revenant_identifier = [identifier copy];
    return self;
}

+ (instancetype)typeWithIdentifier:(NSString *)identifier
{
    if (!identifier.length)
        return nil;
    return [[self alloc] revenant_initWithIdentifier:identifier];
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
    return _revenant_identifier;
}

- (NSString *)preferredFilenameExtension
{
    return CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_revenant_identifier, kUTTagClassFilenameExtension));
}

- (NSString *)preferredMIMEType
{
    return CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_revenant_identifier, kUTTagClassMIMEType));
}

- (NSString *)localizedDescription
{
    return CFBridgingRelease(UTTypeCopyDescription((__bridge CFStringRef)_revenant_identifier));
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)tags
{
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    for (NSString *tagClass in @[(NSString *)kUTTagClassFilenameExtension, (NSString *)kUTTagClassMIMEType]) {
        NSString *tag = CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)_revenant_identifier, (__bridge CFStringRef)tagClass));
        if (tag)
            tags[tagClass] = @[tag];
    }
    return tags;
}

- (BOOL)isDynamic
{
    if (UTTypeIsDynamic != NULL)
        return UTTypeIsDynamic((__bridge CFStringRef)_revenant_identifier);
    return NO;
}

- (BOOL)isDeclared
{
    if (UTTypeIsDeclared != NULL)
        return UTTypeIsDeclared((__bridge CFStringRef)_revenant_identifier);
    return YES;
}

- (BOOL)isPublicType
{
    return [_revenant_identifier hasPrefix:@"public."];
}

- (BOOL)conformsToType:(UTType *)type
{
    return type != nil && UTTypeConformsTo((__bridge CFStringRef)_revenant_identifier, (__bridge CFStringRef)type.identifier);
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
    return [_revenant_identifier isEqualToString:[(UTType *)other identifier]];
}

- (NSUInteger)hash
{
    return _revenant_identifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<UTType: %@>", _revenant_identifier];
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

__attribute__((constructor)) static void revenant_uttype_constants(void)
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

    revenant_uttype_catalogue_add(@[UTTypeItem, UTTypeContent, UTTypeData, UTTypeDirectory, UTTypeURL,
                                  UTTypeFileURL, UTTypeText, UTTypePlainText, UTTypeUTF8PlainText,
                                  UTTypeImage, UTTypePDF]);
}
