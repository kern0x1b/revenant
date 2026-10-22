#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSFileVersion (RevenantProperties8)

- (NSPersonNameComponents *)originatorNameComponents
{
    return nil;
}

- (BOOL)hasLocalContents
{
    return YES;
}

- (BOOL)hasThumbnail
{
    return NO;
}

+ (void)getNonlocalVersionsOfItemAtURL:(NSURL *)url completionHandler:(void (^)(NSArray<NSFileVersion *> *nonlocalFileVersions, NSError *error))completionHandler
{
    NSError *error = nil;
    NSArray *versions = nil;
    NSNumber *ubiquitous = nil;
    if (![url checkResourceIsReachableAndReturnError:&error]) {
        versions = nil;
    } else if ([url getResourceValue:&ubiquitous forKey:NSURLIsUbiquitousItemKey error:NULL] && ubiquitous.boolValue) {
        error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError
                                userInfo:@{NSURLErrorKey: url, NSLocalizedDescriptionKey: @"The versions stored in iCloud cannot be listed on this system."}];
    } else {
        versions = @[];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(versions, error);
    });
}

@end
