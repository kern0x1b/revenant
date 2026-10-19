#import <Foundation/Foundation.h>

static NSMutableDictionary *charon_registration(void)
{
    static NSMutableDictionary *registration;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        registration = [NSMutableDictionary dictionary];
    });
    return registration;
}

@interface CharonSuiteDefaults : NSUserDefaults
@property (nonatomic, copy) NSString *charon_suite;
@end

@implementation CharonSuiteDefaults

@synthesize charon_suite;

- (id)objectForKey:(NSString *)key
{
    if (![key isKindOfClass:[NSString class]])
        return nil;
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)self.charon_suite));
    if (value)
        return value;
    @synchronized(charon_registration()) {
        return charon_registration()[key];
    }
}

- (void)setObject:(id)value forKey:(NSString *)key
{
    if (!value) {
        [self removeObjectForKey:key];
        return;
    }
    if (![NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0])
        [NSException raise:NSInvalidArgumentException format:@"Attempt to insert non-property list object %@ for key %@", value, key];
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)self.charon_suite);
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUserDefaultsDidChangeNotification object:self];
}

- (void)removeObjectForKey:(NSString *)key
{
    CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, (__bridge CFStringRef)self.charon_suite);
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUserDefaultsDidChangeNotification object:self];
}

- (NSString *)stringForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]])
        return value;
    if ([value isKindOfClass:[NSNumber class]])
        return [value stringValue];
    return nil;
}

- (NSArray *)arrayForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

- (NSDictionary *)dictionaryForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

- (NSData *)dataForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    return [value isKindOfClass:[NSData class]] ? value : nil;
}

- (NSArray *)stringArrayForKey:(NSString *)key
{
    NSArray *array = [self arrayForKey:key];
    for (id item in array)
        if (![item isKindOfClass:[NSString class]])
            return nil;
    return array;
}

- (NSInteger)integerForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
}

- (float)floatForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(floatValue)] ? [value floatValue] : 0;
}

- (double)doubleForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
}

- (BOOL)boolForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
        NSString *lower = [value lowercaseString];
        return [lower isEqualToString:@"yes"] || [lower isEqualToString:@"true"] || [lower isEqualToString:@"1"];
    }
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (NSURL *)URLForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSData class]])
        return [NSKeyedUnarchiver unarchiveObjectWithData:value];
    if ([value isKindOfClass:[NSString class]])
        return [NSURL fileURLWithPath:[value stringByExpandingTildeInPath]];
    return nil;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key
{
    [self setObject:@(value) forKey:key];
}

- (void)setFloat:(float)value forKey:(NSString *)key
{
    [self setObject:@(value) forKey:key];
}

- (void)setDouble:(double)value forKey:(NSString *)key
{
    [self setObject:@(value) forKey:key];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key
{
    [self setObject:@(value) forKey:key];
}

- (void)setURL:(NSURL *)url forKey:(NSString *)key
{
    if (!url) {
        [self removeObjectForKey:key];
        return;
    }
    if (url.isFileURL)
        [self setObject:[url.path stringByAbbreviatingWithTildeInPath] forKey:key];
    else
        [self setObject:[NSKeyedArchiver archivedDataWithRootObject:url] forKey:key];
}

- (void)registerDefaults:(NSDictionary *)dictionary
{
    @synchronized(charon_registration()) {
        [charon_registration() addEntriesFromDictionary:dictionary];
    }
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *result;
    @synchronized(charon_registration()) {
        result = [NSMutableDictionary dictionaryWithDictionary:charon_registration()];
    }
    CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)self.charon_suite, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keys) {
        NSDictionary *values = CFBridgingRelease(CFPreferencesCopyMultiple(keys, (__bridge CFStringRef)self.charon_suite, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
        [result addEntriesFromDictionary:values];
        CFRelease(keys);
    }
    return result;
}

- (BOOL)synchronize
{
    return CFPreferencesAppSynchronize((__bridge CFStringRef)self.charon_suite);
}

@end

@implementation NSUserDefaults (CharonSuiteName)

- (instancetype)initWithSuiteName:(NSString *)suitename
{
    if (!suitename)
        return [self init];
    if ([suitename isEqualToString:NSGlobalDomain] || [suitename isEqualToString:[NSBundle mainBundle].bundleIdentifier])
        return nil;
    CharonSuiteDefaults *defaults = [[CharonSuiteDefaults alloc] init];
    defaults.charon_suite = suitename;
    return defaults;
}

@end
