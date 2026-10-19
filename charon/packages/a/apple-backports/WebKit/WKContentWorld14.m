#import "CharonWebKit.h"

@implementation WKContentWorld {
@private
    NSString *_name;
}

+ (WKContentWorld *)pageWorld
{
    static WKContentWorld *world;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        world = [[WKContentWorld alloc] init];
    });
    return world;
}

+ (WKContentWorld *)defaultClientWorld
{
    static WKContentWorld *world;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        world = [[WKContentWorld alloc] init];
    });
    return world;
}

+ (WKContentWorld *)worldWithName:(NSString *)name
{
    static NSMutableDictionary *named;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        named = [[NSMutableDictionary alloc] init];
    });
    @synchronized (named) {
        WKContentWorld *world = named[name];
        if (!world) {
            world = [[WKContentWorld alloc] init];
            world->_name = [name copy];
            named[name] = world;
        }
        return world;
    }
}

- (NSString *)name
{
    return _name;
}

@end

@implementation WKUserContentController (CharonContentWorld14)

- (void)removeScriptMessageHandlerForName:(NSString *)name contentWorld:(WKContentWorld *)contentWorld
{
    [self removeScriptMessageHandlerForName:name];
}

@end
