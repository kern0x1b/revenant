#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static id revenant_collection_fail(NSCoder *coder, NSString *reason)
{
    if (coder.decodingFailurePolicy == NSDecodingFailurePolicyRaiseException)
        [NSException raise:NSInvalidUnarchiveOperationException format:@"%@", reason];
    [coder failWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderReadCorruptError userInfo:@{NSDebugDescriptionErrorKey: reason}]];
    return nil;
}

static BOOL revenant_is_collection(id object)
{
    return [object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSSet class]] || [object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSOrderedSet class]];
}

static NSString *revenant_public_name(id object)
{
    for (Class cls in @[[NSMutableString class], [NSString class], [NSNumber class], [NSData class], [NSDate class], [NSMutableArray class], [NSArray class], [NSMutableDictionary class], [NSDictionary class], [NSMutableSet class], [NSSet class], [NSMutableOrderedSet class], [NSOrderedSet class], [NSNull class], [NSURL class], [NSUUID class], [NSValue class]]) {
        if ([object isKindOfClass:cls])
            return NSStringFromClass(cls);
    }
    return NSStringFromClass([object class]);
}

static BOOL revenant_belongs(id object, NSSet *classes)
{
    Class named = NSClassFromString(revenant_public_name(object));
    for (Class cls in classes) {
        if ([object isKindOfClass:cls] || (named && [cls isSubclassOfClass:named]))
            return YES;
    }
    return NO;
}

static NSString *revenant_described(Class cls)
{
    NSString *path = [NSBundle bundleForClass:cls].bundlePath;
    return [NSString stringWithFormat:@"'%@' (%p)%@", NSStringFromClass(cls), (__bridge void *)cls, path ? [NSString stringWithFormat:@" [%@]", path] : @""];
}

static NSString *revenant_unexpected(NSString *key, id object, NSSet *allowed)
{
    NSMutableArray *lines = [NSMutableArray array];
    for (Class cls in allowed)
        [lines addObject:[NSString stringWithFormat:@"    \"%@\"", revenant_described(cls)]];
    return [NSString stringWithFormat:@"value for key '%@' was of unexpected class %@.\nAllowed classes are:\n {(\n%@\n)}", key, revenant_described(NSClassFromString(revenant_public_name(object)) ?: object_getClass(object)), [lines componentsJoinedByString:@",\n"]];
}

static Class revenant_family(id object)
{
    Class family = Nil;
    for (Class cls in @[[NSDictionary class], [NSArray class], [NSOrderedSet class], [NSSet class]]) {
        if ([object isKindOfClass:cls])
            family = cls;
    }
    return family;
}

static NSArray *revenant_members(id object)
{
    Class family = revenant_family(object);
    if (family == [NSDictionary class])
        return [[object allKeys] arrayByAddingObjectsFromArray:[object allValues]];
    if (family == [NSArray class])
        return object;
    if (family == [NSOrderedSet class])
        return [object array];
    return family ? [object allObjects] : nil;
}

static NSString *revenant_validate(NSCoder *coder, id collection, Class root, NSSet *allowed)
{
    for (id member in revenant_members(collection)) {
        if (!revenant_belongs(member, allowed))
            return revenant_unexpected(@"NS.objects", member, allowed);
        if (root && revenant_family(member))
            return [NSString stringWithFormat:@"*** -[%@ decodeObjectForKey:]: value for key (NS.objects) contains too many nested (%@)s", NSStringFromClass([coder class]), revenant_public_name(member)];
    }
    return nil;
}

static id revenant_collection_decode(NSCoder *coder, SEL selector, NSSet *classes, NSString *key, Class container)
{
    if (!classes)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: classes cannot be nil", NSStringFromClass([coder class]), NSStringFromSelector(selector)];
    NSMutableArray *nested = [NSMutableArray array];
    for (Class cls in classes) {
        if ([cls isSubclassOfClass:[NSArray class]] || [cls isSubclassOfClass:[NSSet class]] || [cls isSubclassOfClass:[NSDictionary class]] || [cls isSubclassOfClass:[NSOrderedSet class]])
            [nested addObject:[NSString stringWithFormat:@"\t\t'%@' (%p)%@", NSStringFromClass(cls), (__bridge void *)cls, [NSBundle bundleForClass:cls].bundlePath ? [NSString stringWithFormat:@" [%@]", [NSBundle bundleForClass:cls].bundlePath] : @""]];
    }
    if (nested.count)
        return revenant_collection_fail(coder, [NSString stringWithFormat:@"*** -[%@ %@]: This method only supports decoding non-nested collections. Please remove the following or use '-decodeObjectOfClasses: forKey:' instead: \n\t(\n%@\n\t)\n",
                                                                       NSStringFromClass([coder class]), NSStringFromSelector(selector), [nested componentsJoinedByString:@"\n"]]);
    if (!coder.requiresSecureCoding)
        [NSException raise:NSInvalidUnarchiveOperationException format:@"*** -[%@ _decodeCollectionOfClass:allowedClasses:forKey:]: This method only supports secure coding.", NSStringFromClass([coder class])];
    NSMutableSet *allowed = [classes mutableCopy];
    [allowed addObjectsFromArray:@[container, [NSString class], [NSNumber class], [NSData class]]];
    id decoded = nil;
    @try {
        decoded = [coder decodeObjectOfClasses:[NSSet setWithObject:[NSObject class]] forKey:key];
    } @catch (NSException *exception) {
        if (coder.decodingFailurePolicy == NSDecodingFailurePolicyRaiseException)
            @throw;
        return revenant_collection_fail(coder, exception.reason ?: exception.name);
    }
    if (!decoded)
        return nil;
    Class family = revenant_family(decoded);
    if (!revenant_belongs(decoded, allowed))
        return revenant_collection_fail(coder, revenant_unexpected(key, decoded, allowed));
    NSString *reason = revenant_validate(coder, decoded, family, allowed);
    if (reason)
        return revenant_collection_fail(coder, reason);
    if (![decoded isKindOfClass:container])
        return revenant_collection_fail(coder, [NSString stringWithFormat:@"value for key '%@' was not an %@ (got %@)", key, NSStringFromClass(container), [container isSubclassOfClass:[NSDictionary class]] ? NSStringFromClass([decoded class]) : revenant_public_name(decoded)]);
    return decoded;
}

@implementation NSCoder (RevenantCollections)

- (NSArray *)decodeArrayOfObjectsOfClass:(Class)cls forKey:(NSString *)key
{
    return revenant_collection_decode(self, _cmd, [NSSet setWithObject:cls], key, [NSArray class]);
}

- (NSArray *)decodeArrayOfObjectsOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key
{
    return revenant_collection_decode(self, _cmd, classes, key, [NSArray class]);
}

- (NSDictionary *)decodeDictionaryWithKeysOfClass:(Class)keyClass objectsOfClass:(Class)objectClass forKey:(NSString *)key
{
    return [self revenant_decodeDictionaryWithKeysOfClasses:[NSSet setWithObject:keyClass] objectsOfClasses:[NSSet setWithObject:objectClass] forKey:key selector:_cmd];
}

- (NSDictionary *)decodeDictionaryWithKeysOfClasses:(NSSet<Class> *)keyClasses objectsOfClasses:(NSSet<Class> *)objectClasses forKey:(NSString *)key
{
    return [self revenant_decodeDictionaryWithKeysOfClasses:keyClasses objectsOfClasses:objectClasses forKey:key selector:_cmd];
}

- (NSDictionary *)revenant_decodeDictionaryWithKeysOfClasses:(NSSet *)keyClasses objectsOfClasses:(NSSet *)objectClasses forKey:(NSString *)key selector:(SEL)selector
{
    if (!keyClasses || !objectClasses)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: classes cannot be nil", NSStringFromClass([self class]), NSStringFromSelector(selector)];
    NSDictionary *decoded = revenant_collection_decode(self, selector, [keyClasses setByAddingObjectsFromSet:objectClasses], key, [NSDictionary class]);
    if (!decoded)
        return nil;
    for (id object in decoded) {
        if (!revenant_belongs(object, keyClasses))
            return revenant_collection_fail(self, [NSString stringWithFormat:@"dictionary for key '%@' contained a key of class '%@' which is not in the allowed key classes", key, revenant_public_name(object)]);
    }
    for (id object in [decoded allValues]) {
        if (!revenant_belongs(object, objectClasses))
            return revenant_collection_fail(self, [NSString stringWithFormat:@"dictionary for key '%@' contained a value of class '%@' which is not in the allowed object classes", key, revenant_public_name(object)]);
    }
    return decoded;
}

@end
