#import <Foundation/Foundation.h>

@implementation NSURL (CharonPromisedItem)

- (BOOL)charon_promisedItemIsReachable
{
    return [self checkPromisedItemIsReachableAndReturnError:NULL];
}

- (BOOL)getPromisedItemResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)error
{
    if ([self charon_promisedItemIsReachable])
        return [self getResourceValue:value forKey:key error:error];
    if (value)
        *value = nil;
    if (error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:@{NSURLErrorKey: self}];
    return NO;
}

- (NSDictionary<NSURLResourceKey, id> *)promisedItemResourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys error:(NSError **)error
{
    if (![self checkPromisedItemIsReachableAndReturnError:error])
        return nil;
    return [self resourceValuesForKeys:keys error:error];
}

- (BOOL)checkPromisedItemIsReachableAndReturnError:(NSError **)error
{
    if (self.isFileURL)
        return [[NSFileManager defaultManager] fileExistsAtPath:self.path];
    if (error)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:@{NSURLErrorKey: self}];
    return NO;
}

@end
