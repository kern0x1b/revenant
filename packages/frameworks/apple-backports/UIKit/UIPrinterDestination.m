#import <UIKit/UIKit.h>

static NSString *const kRevenantDestinationURLKey = @"URL";
static NSString *const kRevenantDestinationDisplayNameKey = @"displayName";
static NSString *const kRevenantDestinationTXTRecordKey = @"txtRecord";

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
        _URL = [[coder decodeObjectOfClass:[NSURL class] forKey:kRevenantDestinationURLKey] copy];
        _displayName = [coder decodeObjectOfClass:[NSString class] forKey:kRevenantDestinationDisplayNameKey];
        _txtRecord = [coder decodeObjectOfClass:[NSData class] forKey:kRevenantDestinationTXTRecordKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
        return;
    [coder encodeObject:_URL forKey:kRevenantDestinationURLKey];
    [coder encodeObject:_displayName forKey:kRevenantDestinationDisplayNameKey];
    [coder encodeObject:_txtRecord forKey:kRevenantDestinationTXTRecordKey];
}

@end
