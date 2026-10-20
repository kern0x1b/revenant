#import <SafariServices/SafariServices.h>

@implementation SFSafariViewControllerActivityButton

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"Misuse of SFSafariViewControllerActivityButton interface. Use -initWithTemplateImage:extensionIdentifier: instead."];
    return nil;
}

- (instancetype)initWithTemplateImage:(UIImage *)templateImage extensionIdentifier:(NSString *)extensionIdentifier
{
    self = [super init];
    if (self) {
        _templateImage = templateImage;
        _extensionIdentifier = [extensionIdentifier copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithTemplateImage:[coder decodeObjectOfClass:[UIImage class] forKey:@"templateImage"]
                   extensionIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"extensionIdentifier"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_templateImage forKey:@"templateImage"];
    [coder encodeObject:_extensionIdentifier forKey:@"extensionIdentifier"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithTemplateImage:_templateImage extensionIdentifier:_extensionIdentifier];
}

@end
