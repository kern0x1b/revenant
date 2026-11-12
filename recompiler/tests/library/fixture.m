#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RCFixture.h"
#include <dispatch/dispatch.h>

static NSInteger RCFCreated;

@implementation RCFToken
- (instancetype)initWithValue:(NSInteger)value
{
    self = [super init];
    if (self)
        _value = value;
    return self;
}
@end

@implementation RCFClient {
    NSInteger _seed;
    NSInteger _counter;
}

+ (RCFClient *)clientWithSeed:(NSInteger)seed
{
    RCFClient *client = [[RCFClient alloc] init];
    client->_seed = seed;
    RCFCreated++;
    return client;
}

- (NSInteger)bump
{
    return ++_counter;
}

- (NSInteger)seed
{
    return _seed;
}

- (NSInteger)describedLength
{
    return (NSInteger)[NSString stringWithFormat:@"client-%ld-%ld", (long)_seed, (long)_counter].length;
}

- (NSObject *)hostBundle
{
    return [NSBundle mainBundle];
}

- (RCFToken *)tokenForAction:(NSInteger)action
{
    return [[RCFToken alloc] initWithValue:_seed * 1000 + action * 10 + RCFCreated];
}

- (void)executeWithAction:(NSInteger)action completion:(void (^)(RCFToken *token, NSError *error))completion
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
