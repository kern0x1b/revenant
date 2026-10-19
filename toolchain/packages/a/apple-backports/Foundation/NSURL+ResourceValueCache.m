#import <Foundation/Foundation.h>

@implementation NSURL (CharonResourceValueCache)

- (void)removeCachedResourceValueForKey:(NSString *)key
{
    CFURLClearResourcePropertyCacheForKey((__bridge CFURLRef)self, (__bridge CFStringRef)key);
}

- (void)removeAllCachedResourceValues
{
    CFURLClearResourcePropertyCache((__bridge CFURLRef)self);
}

- (void)setTemporaryResourceValue:(id)value forKey:(NSString *)key
{
    CFURLSetTemporaryResourcePropertyForKey((__bridge CFURLRef)self, (__bridge CFStringRef)key, value ? (__bridge CFTypeRef)value : kCFNull);
}

@end
