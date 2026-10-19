#ifndef REVENANT_VALUE_STORE_H
#define REVENANT_VALUE_STORE_H

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static inline NSArray<NSString *> *RevenantValuePropertyNames(Class cls)
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (Class current = cls; current && current != [NSObject class]; current = class_getSuperclass(current)) {
        unsigned int count = 0;
        objc_property_t *properties = class_copyPropertyList(current, &count);
        for (unsigned int index = 0; index < count; index++)
            [names addObject:[NSString stringWithUTF8String:property_getName(properties[index])]];
        free(properties);
    }
    return names;
}

static inline NSMutableDictionary *RevenantValueStore(id owner)
{
    static const char key;
    NSMutableDictionary *values = objc_getAssociatedObject(owner, &key);
    if (!values) {
        values = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(owner, &key, values, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return values;
}

static inline void RevenantValueSet(id owner, id value, NSString *key)
{
    if (!key)
        return;
    if (value)
        RevenantValueStore(owner)[key] = value;
    else
        [RevenantValueStore(owner) removeObjectForKey:key];
}

static inline id RevenantValueConvertProperties(id value, Class firstRoot, Class secondRoot);

static inline id RevenantValueConvert(id value, Class firstRoot, Class secondRoot)
{
    if (!value || value == [NSNull null])
        return nil;
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]])
        return value;
    if ([value isKindOfClass:[NSDate class]])
        return @([(NSDate *)value timeIntervalSinceReferenceDate]);
    if ([value isKindOfClass:[NSURL class]])
        return [(NSURL *)value absoluteString];
    if ([value isKindOfClass:[NSMeasurement class]])
        return @([(NSMeasurement *)value doubleValue]);
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *converted = [NSMutableArray array];
        for (id element in (NSArray *)value)
            [converted addObject:RevenantValueConvert(element, firstRoot, secondRoot) ?: [NSNull null]];
        return converted;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *converted = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id element, BOOL *stop) {
            id one = RevenantValueConvert(element, firstRoot, secondRoot);
            if (one)
                converted[[key description]] = one;
        }];
        return converted;
    }
    if ([(id)value respondsToSelector:@selector(revenant_valueForKey:)])
        return RevenantValueConvertProperties(value, firstRoot, secondRoot);
    return [value description];
}

static inline NSDictionary *RevenantValueConvertProperties(id value, Class firstRoot, Class secondRoot)
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (NSString *name in RevenantValuePropertyNames([value class])) {
        id held = RevenantValueStore(value)[name];
        if (!held)
            continue;
        id converted = RevenantValueConvert(held, firstRoot, secondRoot);
        if (converted)
            dictionary[name] = converted;
    }
    return dictionary;
}

static inline NSData *RevenantValueJSON(id value, Class firstRoot, Class secondRoot)
{
    NSDictionary *dictionary = RevenantValueConvertProperties(value, firstRoot, secondRoot);
    if (![NSJSONSerialization isValidJSONObject:dictionary])
        return [NSJSONSerialization dataWithJSONObject:@{} options:0 error:NULL];
    return [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
}

static inline NSSet<Class> *RevenantValueDecodableClasses(NSString *prefix)
{
    static NSMutableDictionary<NSString *, NSSet<Class> *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSMutableDictionary dictionary];
    });
    NSSet<Class> *known = cache[prefix];
    if (known)
        return known;
    NSMutableSet *found = [NSMutableSet set];
    int count = objc_getClassList(NULL, 0);
    if (count > 0) {
        Class *list = (Class *)malloc(sizeof(Class) * (size_t)count);
        count = objc_getClassList(list, count);
        for (int index = 0; index < count; index++)
            if ([NSStringFromClass(list[index]) hasPrefix:prefix])
                [found addObject:list[index]];
        free(list);
    }
    for (NSString *name in @[@"NSString", @"NSDate", @"NSNumber", @"NSData", @"NSURL", @"NSArray",
                             @"NSDictionary", @"NSMeasurement", @"NSDimension", @"NSNull"])
        if (NSClassFromString(name))
            [found addObject:NSClassFromString(name)];
    [cache setObject:found forKey:prefix];
    return found;
}

static inline void RevenantValueEncode(id value, NSCoder *coder)
{
    for (NSString *name in RevenantValuePropertyNames([value class])) {
        id held = [value valueForKey:name];
        if (held)
            [coder encodeObject:held forKey:name];
    }
}

static inline BOOL RevenantValueDecode(id value, NSCoder *coder, NSSet<Class> *allowed)
{
    BOOL whole = YES;
    for (NSString *name in RevenantValuePropertyNames([value class])) {
        if (![coder containsValueForKey:name])
            continue;
        id held = [coder decodeObjectOfClasses:allowed forKey:name];
        if (held)
            [value setValue:held forKey:name];
        else
            whole = NO;
    }
    return whole;
}

#define REVENANT_STRUCT_PROPERTY(Type, name)                                                 \
    -(Type)name {                                                                           \
        Type value = {};                                                                     \
        NSValue *boxed = [self revenant_valueForKey:@ #name];                                 \
        if (boxed)                                                                           \
            [boxed getValue:&value size:sizeof(Type)];                                      \
        return value;                                                                        \
    }                                                                                        \
    -(void)revenant_set##name:(Type)value {                                                   \
        [self revenant_setValue:[NSValue valueWithBytes:&value objCType:@encode(Type)]          \
                         forKey:@ #name];                                                    \
    }

#define REVENANT_VALUE_PROPERTY(Type, name)                                                   \
    -(Type)name { return (Type)[self revenant_valueForKey:@ #name]; }

#define REVENANT_SCALAR_PROPERTY(Type, name)                                                  \
    -(Type)name { return (Type)[[self revenant_valueForKey:@ #name] longLongValue]; }

#define REVENANT_DOUBLE_PROPERTY(Type, name)                                                  \
    -(Type)name { return (Type)[[self revenant_valueForKey:@ #name] doubleValue]; }

#define REVENANT_SCALAR_GETTER(Type, name, getter)                                           \
    -(Type)getter { return (Type)[[self revenant_valueForKey:@ #name] longLongValue]; }

#define REVENANT_VALUE_COPY_INITIALISER                                                       \
    -(instancetype)initWithRevenantValues:(NSDictionary *)values {                           \
        self = [super init];                                                                \
        if (self) {                                                                         \
            for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) { \
                id held = values[key];                                                       \
                [self revenant_setValue:[held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held \
                         forKey:key];                                                        \
            }                                                                                \
        }                                                                                    \
        return self;                                                                         \
    }

#endif
