#import <PushKit/PushKit.h>

@interface PKPushPayload ()
{
    PKPushType _type;
    NSDictionary *_dictionaryPayload;
}
@end

@implementation PKPushPayload

@synthesize type = _type;
@synthesize dictionaryPayload = _dictionaryPayload;

- (instancetype)initWithCharonType:(PKPushType)type dictionaryPayload:(NSDictionary *)dictionaryPayload
{
    if ((self = [super init])) {
        _type = [type copy];
        _dictionaryPayload = [dictionaryPayload copy] ?: @{};
    }
    return self;
}

@end
