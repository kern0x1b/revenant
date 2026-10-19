#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation UTType {
    NSString *_identifier;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if ((self = [super init]))
        _identifier = [identifier copy];
    return self;
}

- (void)dealloc
{
    [_identifier release];
    [super dealloc];
}

- (NSString *)identifier { return _identifier; }

+ (UTType *)typeWithIdentifier:(NSString *)identifier
{
    if (!identifier)
        return nil;
    return [[[UTType alloc] initWithIdentifier:identifier] autorelease];
}

+ (UTType *)typeWithMIMEType:(NSString *)mimeType
{
    if (!mimeType)
        return nil;
    CFStringRef identifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
        (CFStringRef)mimeType, NULL);
    UTType *type = identifier ? [UTType typeWithIdentifier:(NSString *)identifier] : nil;
    if (identifier)
        CFRelease(identifier);
    return type;
}

+ (UTType *)typeWithFilenameExtension:(NSString *)filenameExtension
{
    if (!filenameExtension)
        return nil;
    CFStringRef identifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
        (CFStringRef)filenameExtension, NULL);
    UTType *type = identifier ? [UTType typeWithIdentifier:(NSString *)identifier] : nil;
    if (identifier)
        CFRelease(identifier);
    return type;
}

- (NSString *)preferredMIMEType
{
    CFStringRef tag = UTTypeCopyPreferredTagWithClass((CFStringRef)_identifier, kUTTagClassMIMEType);
    return tag ? [(NSString *)tag autorelease] : nil;
}

- (NSString *)preferredFilenameExtension
{
    CFStringRef tag = UTTypeCopyPreferredTagWithClass((CFStringRef)_identifier, kUTTagClassFilenameExtension);
    return tag ? [(NSString *)tag autorelease] : nil;
}

- (BOOL)isDeclared
{
    return UTTypeIsDeclared((CFStringRef)_identifier);
}

- (BOOL)isDynamic
{
    return UTTypeIsDynamic((CFStringRef)_identifier);
}

- (NSArray<NSString *> *)tags:(NSString *)tagClass
{
    CFArrayRef tags = UTTypeCopyAllTagsWithClass((CFStringRef)_identifier, (CFStringRef)tagClass);
    return tags ? [(NSArray *)tags autorelease] : @[];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)tags
{
    return @{
        (NSString *)kUTTagClassMIMEType : [self tags:(NSString *)kUTTagClassMIMEType],
        (NSString *)kUTTagClassFilenameExtension : [self tags:(NSString *)kUTTagClassFilenameExtension],
    };
}

- (BOOL)conformsToType:(UTType *)type
{
    if (!type)
        return NO;
    return UTTypeConformsTo((CFStringRef)_identifier, (CFStringRef)type.identifier);
}

@end

#import <objc/runtime.h>
static const void *webKitIOS6AttributionKey = &webKitIOS6AttributionKey;

@implementation NSURLRequest (WebKitIOS6Attribution)
- (NSURLRequestAttribution)attribution
{
    NSNumber *stored = objc_getAssociatedObject(self, webKitIOS6AttributionKey);
    return stored ? (NSURLRequestAttribution)[stored integerValue] : NSURLRequestAttributionDeveloper;
}
@end

@implementation NSMutableURLRequest (WebKitIOS6Attribution)
- (void)setAttribution:(NSURLRequestAttribution)attribution
{
    objc_setAssociatedObject(self, webKitIOS6AttributionKey, @(attribution), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation NSError (WebKitIOS6UnderlyingErrors)
- (NSArray<NSError *> *)underlyingErrors
{
    NSError *underlying = [[self userInfo] objectForKey:NSUnderlyingErrorKey];
    return underlying ? @[underlying] : @[];
}
@end

@implementation UIScreen (WebKitIOS6EDR)
- (CGFloat)currentEDRHeadroom { return 1.0; }
- (CGFloat)potentialEDRHeadroom { return 1.0; }
@end

@interface NSURLRequest (WebKitIOS6NetworkSPI)
@end

@implementation NSURLRequest (WebKitIOS6NetworkSPI)
- (BOOL)_privacyProxyFailClosed { return NO; }
- (BOOL)_privacyProxyFailClosedForUnreachableNonMainHosts { return NO; }
- (BOOL)_useEnhancedPrivacyMode { return NO; }
- (BOOL)_schemeWasUpgradedDueToDynamicHSTS { return NO; }
- (BOOL)_preventHSTSStorage { return NO; }
- (BOOL)_ignoreHSTS { return NO; }
@end

@interface NSMutableURLRequest (WebKitIOS6NetworkSPI)
@end

@implementation NSMutableURLRequest (WebKitIOS6NetworkSPI)
- (void)_setPrivacyProxyFailClosed:(BOOL)value { (void)value; }
- (void)_setPrivacyProxyFailClosedForUnreachableNonMainHosts:(BOOL)value { (void)value; }
- (void)_setUseEnhancedPrivacyMode:(BOOL)value { (void)value; }
- (void)_setSchemeWasUpgradedDueToDynamicHSTS:(BOOL)value { (void)value; }
- (void)_setPreventHSTSStorage:(BOOL)value { (void)value; }
- (void)_setIgnoreHSTS:(BOOL)value { (void)value; }
@end

@interface NSURLConnection (WebKitIOS6Timing)
@end

@implementation NSURLConnection (WebKitIOS6Timing)
- (NSDictionary *)_timingData { return nil; }
@end
