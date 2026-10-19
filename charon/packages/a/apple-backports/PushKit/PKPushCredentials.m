#import <PushKit/PushKit.h>

@interface PKPushCredentials ()
{
    PKPushType _type;
    NSData *_token;
}
@end

@implementation PKPushCredentials

@synthesize type = _type;
@synthesize token = _token;

- (instancetype)initWithCharonType:(PKPushType)type token:(NSData *)token
{
    if ((self = [super init])) {
        _type = [type copy];
        _token = [token copy];
    }
    return self;
}

@end
