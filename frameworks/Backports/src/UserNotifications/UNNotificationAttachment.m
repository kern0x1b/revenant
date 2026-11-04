#import "RevenantUserNotifications.h"

NSString *const UNNotificationAttachmentOptionsTypeHintKey = @"UNNotificationAttachmentOptionsTypeHintKey";
NSString *const UNNotificationAttachmentOptionsThumbnailHiddenKey = @"UNNotificationAttachmentOptionsThumbnailHiddenKey";
NSString *const UNNotificationAttachmentOptionsThumbnailClippingRectKey = @"UNNotificationAttachmentOptionsThumbnailClippingRectKey";
NSString *const UNNotificationAttachmentOptionsThumbnailTimeKey = @"UNNotificationAttachmentOptionsThumbnailTimeKey";

static NSDictionary *revenant_attachment_types(void)
{
    static NSDictionary *types;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        types = @{
            @"jpg": @"public.jpeg",
            @"jpeg": @"public.jpeg",
            @"png": @"public.png",
            @"gif": @"com.compuserve.gif",
            @"mp3": @"public.mp3",
            @"m4a": @"com.apple.m4a-audio",
            @"wav": @"com.microsoft.waveform-audio",
            @"aif": @"public.aiff-audio",
            @"aiff": @"public.aiff-audio",
            @"caf": @"com.apple.coreaudio-format",
            @"mp4": @"public.mpeg-4",
            @"m4v": @"com.apple.m4v-video",
            @"mov": @"com.apple.quicktime-movie",
        };
    });
    return types;
}

static NSString *revenant_attachment_type(NSURL *URL, NSDictionary *options)
{
    id hint = options[UNNotificationAttachmentOptionsTypeHintKey];
    if ([hint isKindOfClass:[NSString class]] && [hint length] > 0)
        return hint;
    return revenant_attachment_types()[URL.pathExtension.lowercaseString];
}

static NSError *revenant_attachment_error(NSInteger code, NSString *reason)
{
    return [NSError errorWithDomain:UNErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: reason}];
}

@implementation UNNotificationAttachment {
@private
    NSString *_identifier;
    NSURL *_URL;
    NSString *_type;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (nullable instancetype)attachmentWithIdentifier:(NSString *)identifier URL:(NSURL *)URL options:(nullable NSDictionary *)options
                                            error:(NSError **)error
{
    NSAssert(identifier != nil, @"Invalid parameter not satisfying: %@", @"identifier != nil");
    NSFileManager *files = [NSFileManager defaultManager];
    BOOL directory = NO;
    if (!URL.isFileURL || ![files fileExistsAtPath:URL.path isDirectory:&directory] || directory || ![files isReadableFileAtPath:URL.path]) {
        if (error)
            *error = revenant_attachment_error(UNErrorCodeAttachmentInvalidURL, @"The attachment URL must name a readable file");
        return nil;
    }
    NSString *type = revenant_attachment_type(URL, options);
    if (!type) {
        if (error)
            *error = revenant_attachment_error(UNErrorCodeAttachmentUnrecognizedType, @"The attachment's type is not one of the recognised types");
        return nil;
    }
    return [[self alloc] initRevenantWithIdentifier:identifier URL:URL type:type];
}

- (instancetype)initRevenantWithIdentifier:(NSString *)identifier URL:(NSURL *)URL type:(NSString *)type
{
    if ((self = [super init])) {
        _identifier = [identifier copy];
        _URL = [URL copy];
        _type = [type copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
    NSURL *URL = [coder decodeObjectOfClass:[NSURL class] forKey:@"URL"];
    NSString *type = [coder decodeObjectOfClass:[NSString class] forKey:@"type"];
    if (!identifier || !URL || !type)
        return nil;
    return [self initRevenantWithIdentifier:identifier URL:URL type:type];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_URL forKey:@"URL"];
    [coder encodeObject:_type forKey:@"type"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSURL *)URL
{
    return _URL;
}

- (NSString *)type
{
    return _type;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UNNotificationAttachment class]])
        return NO;
    UNNotificationAttachment *other = object;
    return [_identifier isEqual:other.identifier] && [_URL isEqual:other.URL] && [_type isEqual:other.type];
}

- (NSUInteger)hash
{
    return _identifier.hash ^ _URL.hash ^ _type.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; identifier: %@, URL: %@, type: %@>", [self class], self, _identifier, _URL, _type];
}

@end
