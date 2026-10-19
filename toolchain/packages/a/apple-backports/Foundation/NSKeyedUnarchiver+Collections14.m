#import <Foundation/Foundation.h>

static id charon_unarchive_collection(NSData *data, NSError **error, id (^decode)(NSKeyedUnarchiver *unarchiver))
{
    NSError *failure = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&failure];
    if (!unarchiver) {
        if (error)
            *error = failure;
        return nil;
    }
    unarchiver.requiresSecureCoding = YES;
    unarchiver.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
    id decoded = decode(unarchiver);
    failure = unarchiver.error;
    if (failure) {
        if (error)
            *error = failure;
        return nil;
    }
    if (!decoded && error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderValueNotFoundError
                                 userInfo:@{NSDebugDescriptionErrorKey: [NSString stringWithFormat:@"requested key: '%@'", NSKeyedArchiveRootObjectKey]}];
    return decoded;
}

@implementation NSKeyedUnarchiver (CharonCollections)

+ (NSArray *)unarchivedArrayOfObjectsOfClass:(Class)cls fromData:(NSData *)data error:(NSError **)error
{
    return [self unarchivedArrayOfObjectsOfClasses:[NSSet setWithObject:cls] fromData:data error:error];
}

+ (NSArray *)unarchivedArrayOfObjectsOfClasses:(NSSet<Class> *)classes fromData:(NSData *)data error:(NSError **)error
{
    return charon_unarchive_collection(data, error, ^id(NSKeyedUnarchiver *unarchiver) {
        return [unarchiver decodeArrayOfObjectsOfClasses:classes forKey:NSKeyedArchiveRootObjectKey];
    });
}

+ (NSDictionary *)unarchivedDictionaryWithKeysOfClass:(Class)keyClass objectsOfClass:(Class)valueClass fromData:(NSData *)data error:(NSError **)error
{
    return [self unarchivedDictionaryWithKeysOfClasses:[NSSet setWithObject:keyClass] objectsOfClasses:[NSSet setWithObject:valueClass] fromData:data error:error];
}

+ (NSDictionary *)unarchivedDictionaryWithKeysOfClasses:(NSSet<Class> *)keyClasses objectsOfClasses:(NSSet<Class> *)valueClasses fromData:(NSData *)data error:(NSError **)error
{
    return charon_unarchive_collection(data, error, ^id(NSKeyedUnarchiver *unarchiver) {
        return [unarchiver decodeDictionaryWithKeysOfClasses:keyClasses objectsOfClasses:valueClasses forKey:NSKeyedArchiveRootObjectKey];
    });
}

@end
