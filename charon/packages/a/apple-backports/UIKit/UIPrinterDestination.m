#import <UIKit/UIKit.h>

static NSString *const kCharonDestinationURLKey = @"URL";
static NSString *const kCharonDestinationDisplayNameKey = @"displayName";
static NSString *const kCharonDestinationTXTRecordKey = @"txtRecord";

@implementation UIPrinterDestination {
    NSURL *_URL;
    NSString *_displayName;
    NSData *_txtRecord;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithURL:(NSURL *)url
{
    if ((self = [super init]))
        _URL = [url copy];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
        return nil;
    if ((self = [super init])) {
        _URL = [[coder decodeObjectOfClass:[NSURL class] forKey:kCharonDestinationURLKey] copy];
        _displayName = [coder decodeObjectOfClass:[NSString class] forKey:kCharonDestinationDisplayNameKey];
        _txtRecord = [coder decodeObjectOfClass:[NSData class] forKey:kCharonDestinationTXTRecordKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
        return;
    [coder encodeObject:_URL forKey:kCharonDestinationURLKey];
    [coder encodeObject:_displayName forKey:kCharonDestinationDisplayNameKey];
    [coder encodeObject:_txtRecord forKey:kCharonDestinationTXTRecordKey];
}

@end
