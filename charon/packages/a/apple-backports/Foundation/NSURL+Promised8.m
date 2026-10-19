#import <Foundation/Foundation.h>

/* A promised item: a file the system may not have downloaded yet, and the values it will have once it
   has. On the port's own release every promised item is a file the file system already has, so the
   three methods read the file the way -getResourceValue:forKey:error: does and say so with the
   release's own error when there is no such file: NSCocoaErrorDomain 260, the error the host answers
   for a promised value of a file that is not there (measured).

   There is one case this cannot reach: a placeholder whose bytes are still in the iCloud daemon's
   hands. 6.1.3 has no entry point that asks the daemon for a promised item's values, so such a key
   answers the documented "no value" with the same error rather than a guess. */

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
