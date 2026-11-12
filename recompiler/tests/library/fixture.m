#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RCFixture.h"
#include <dispatch/dispatch.h>

static NSInteger RCFCreated;

@implementation RCFToken
- (instancetype)initWithValue:(NSString *)value
{
    self = [super init];
    if (self)
        _value = [value copy];
    return self;
}
@end

@implementation RCFClient {
    NSString *_siteKey;
}

+ (RCFClient *)clientWithSiteKey:(NSString *)siteKey
{
    RCFClient *client = [[RCFClient alloc] init];
    client->_siteKey = [siteKey copy];
    RCFCreated++;
    return client;
}

- (NSInteger)bump
{
    return ++_counter;
}

- (NSString *)siteKey
{
    return _siteKey;
}

- (NSObject *)hostBundle
{
    return [NSBundle mainBundle];
}

- (NSString *)bundleIdentifier
{
    return [[NSBundle mainBundle] bundleIdentifier];
}

- (RCFToken *)tokenForAction:(NSString *)action
{
    return [[RCFToken alloc] initWithValue:[NSString stringWithFormat:@"%@:%@:%ld", _siteKey, action, (long)RCFCreated]];
}

- (void)executeWithAction:(NSString *)action completion:(void (^)(RCFToken *token, NSError *error))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion([self tokenForAction:action], nil);
    });
}

- (NSUInteger)threadNumber
{
    return [[NSThread currentThread] isMainThread] ? 1 : 2;
}
@end
