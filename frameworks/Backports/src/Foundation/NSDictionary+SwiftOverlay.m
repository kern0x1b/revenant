#import <Foundation/Foundation.h>

@interface NSDictionary (RevenantSwiftOverlay)
- (id)__swiftInitWithDictionary_NSDictionary:(NSDictionary *)other __attribute__((objc_method_family(init)));
- (id)__swift_objectForKeyedSubscript:(id)key;
@end

@interface NSMutableDictionary (RevenantSwiftOverlay)
- (id)__swift_objectForKeyedSubscript:(id)key;
- (void)__swift_setObject:(id)object forKeyedSubscript:(id)key;
@end

@implementation NSDictionary (RevenantSwiftOverlay)

- (id)__swiftInitWithDictionary_NSDictionary:(NSDictionary *)other
{
    return [self initWithDictionary:other];
}

- (id)__swift_objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

@end

@implementation NSMutableDictionary (RevenantSwiftOverlay)

- (id)__swift_objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

- (void)__swift_setObject:(id)object forKeyedSubscript:(id)key
{
    if (object == nil) {
        [self removeObjectForKey:key];
        return;
    }
    [self setObject:object forKey:key];
}

@end
