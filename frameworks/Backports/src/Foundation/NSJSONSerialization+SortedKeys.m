#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define REVENANT_JSON_PRETTY (1UL << 0)
#define REVENANT_JSON_SORTED_KEYS (1UL << 1)
#define REVENANT_JSON_FRAGMENTS (1UL << 2)
#define REVENANT_BACKPORT_EXPORT __attribute__((visibility("default")))
#define REVENANT_FOUNDATION_IOS_11 1443.0

typedef NSData *(*revenant_data_function)(id, SEL, id, NSUInteger, NSError **);

static revenant_data_function revenant_original_data;

static NSData *revenant_original(id object, NSUInteger options, NSError **error)
{
    return revenant_original_data([NSJSONSerialization class], @selector(dataWithJSONObject:options:error:), object, options, error);
}

static NSString *revenant_indentation(NSUInteger depth)
{
    return [@"" stringByPaddingToLength:depth * 2 withString:@"  " startingAtIndex:0];
}

static NSComparisonResult revenant_compare_keys(id left, id right)
{
    NSComparisonResult localized = [left localizedStandardCompare:right];
    if (localized != NSOrderedSame)
        return localized;
    NSData *a = [left dataUsingEncoding:NSUTF8StringEncoding];
    NSData *b = [right dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger common = MIN(a.length, b.length);
    int order = memcmp(a.bytes, b.bytes, common);
    if (order != 0)
        return order < 0 ? NSOrderedAscending : NSOrderedDescending;
    if (a.length == b.length)
        return NSOrderedSame;
    return a.length < b.length ? NSOrderedAscending : NSOrderedDescending;
}

static BOOL revenant_scalar(id value, NSMutableString *out, NSError **error)
{
    NSData *wrapped = revenant_original(@[value], REVENANT_JSON_FRAGMENTS, error);
    if (wrapped == nil)
        return NO;
    NSString *text = [[NSString alloc] initWithData:wrapped encoding:NSUTF8StringEncoding];
    [out appendString:[text substringWithRange:NSMakeRange(1, text.length - 2)]];
    return YES;
}

static BOOL revenant_write(id value, NSUInteger depth, BOOL pretty, NSMutableString *out, NSError **error)
{
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        NSArray *keys = [[dictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
            return revenant_compare_keys(left, right);
        }];
        if (keys.count == 0) {
            [out appendString:pretty ? [@"{\n\n" stringByAppendingString:[revenant_indentation(depth) stringByAppendingString:@"}"]] : @"{}"];
            return YES;
        }
        [out appendString:pretty ? @"{\n" : @"{"];
        for (NSUInteger index = 0; index < keys.count; index++) {
            id key = keys[index];
            if (![key isKindOfClass:[NSString class]]) {
                if (error)
                    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
                return NO;
            }
            if (index > 0)
                [out appendString:pretty ? @",\n" : @","];
            if (pretty)
                [out appendString:revenant_indentation(depth + 1)];
            if (!revenant_scalar(key, out, error))
                return NO;
            [out appendString:pretty ? @" : " : @":"];
            if (!revenant_write(dictionary[key], depth + 1, pretty, out, error))
                return NO;
        }
        [out appendString:pretty ? [@"\n" stringByAppendingString:[revenant_indentation(depth) stringByAppendingString:@"}"]] : @"}"];
        return YES;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        if (array.count == 0) {
            [out appendString:pretty ? [@"[\n\n" stringByAppendingString:[revenant_indentation(depth) stringByAppendingString:@"]"]] : @"[]"];
            return YES;
        }
        [out appendString:pretty ? @"[\n" : @"["];
        for (NSUInteger index = 0; index < array.count; index++) {
            if (index > 0)
                [out appendString:pretty ? @",\n" : @","];
            if (pretty)
                [out appendString:revenant_indentation(depth + 1)];
            if (!revenant_write(array[index], depth + 1, pretty, out, error))
                return NO;
        }
        [out appendString:pretty ? [@"\n" stringByAppendingString:[revenant_indentation(depth) stringByAppendingString:@"]"]] : @"]"];
        return YES;
    }
    return revenant_scalar(value, out, error);
}

REVENANT_BACKPORT_EXPORT NSData *revenant_sorted_keys_data(id object, NSUInteger options, NSError **error)
{
    BOOL container = [object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSArray class]];
    if (!container && !(options & REVENANT_JSON_FRAGMENTS))
        return revenant_original(object, options & ~REVENANT_JSON_SORTED_KEYS, error);
    NSMutableString *out = [NSMutableString string];
    if (!revenant_write(object, 0, (options & REVENANT_JSON_PRETTY) != 0, out, error))
        return nil;
    return [out dataUsingEncoding:NSUTF8StringEncoding];
}

static NSData *revenant_data_with_json_object(id self, SEL _cmd, id object, NSUInteger options, NSError **error)
{
    if (!(options & REVENANT_JSON_SORTED_KEYS))
        return revenant_original_data(self, _cmd, object, options, error);
    return revenant_sorted_keys_data(object, options, error);
}

__attribute__((constructor)) static void revenant_sorted_keys_install(void)
{
    Method method = class_getClassMethod([NSJSONSerialization class], @selector(dataWithJSONObject:options:error:));
    if (method == NULL)
        return;
    revenant_original_data = (revenant_data_function)method_getImplementation(method);
    if (NSFoundationVersionNumber >= REVENANT_FOUNDATION_IOS_11)
        return;
    method_setImplementation(method, (IMP)revenant_data_with_json_object);
}
