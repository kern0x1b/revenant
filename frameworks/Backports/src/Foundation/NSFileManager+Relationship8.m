#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static BOOL revenant_resource_identity(NSURL *url, id *identity, NSError **error)
{
    return [url getResourceValue:identity forKey:NSURLFileResourceIdentifierKey error:error];
}

static BOOL revenant_directory_relationship(NSURLRelationship *relationship, NSURL *directoryURL, NSURL *otherURL, NSError **error)
{
    NSNumber *isDirectory = nil;
    if (![directoryURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:error])
        return NO;
    id directoryIdentity = nil;
    if (!revenant_resource_identity(directoryURL, &directoryIdentity, error))
        return NO;
    id otherIdentity = nil;
    if (!revenant_resource_identity(otherURL, &otherIdentity, error))
        return NO;
    if ([directoryIdentity isEqual:otherIdentity]) {
        *relationship = NSURLRelationshipSame;
        return YES;
    }
    if (isDirectory.boolValue) {
        NSURL *parent = otherURL;
        while (![parent.path isEqualToString:@"/"]) {
            parent = parent.URLByDeletingLastPathComponent;
            id parentIdentity = nil;
            if (!revenant_resource_identity(parent, &parentIdentity, error))
                return NO;
            if ([directoryIdentity isEqual:parentIdentity]) {
                *relationship = NSURLRelationshipContains;
                return YES;
            }
        }
    }
    *relationship = NSURLRelationshipOther;
    return YES;
}

@implementation NSFileManager (RevenantRelationship8)

- (BOOL)getRelationship:(NSURLRelationship *)outRelationship ofDirectoryAtURL:(NSURL *)directoryURL toItemAtURL:(NSURL *)otherURL error:(NSError **)error
{
    return revenant_directory_relationship(outRelationship, directoryURL, otherURL, error);
}

- (BOOL)getRelationship:(NSURLRelationship *)outRelationship ofDirectory:(NSSearchPathDirectory)directory inDomain:(NSSearchPathDomainMask)domainMask toItemAtURL:(NSURL *)url error:(NSError **)error
{
    NSSearchPathDomainMask domains = domainMask ? domainMask : NSAllDomainsMask;
    NSArray *candidates = [self URLsForDirectory:directory inDomains:domains];
    *outRelationship = NSURLRelationshipOther;
    for (NSURL *candidate in candidates) {
        if (![candidate checkResourceIsReachableAndReturnError:nil])
            continue;
        NSURLRelationship found = NSURLRelationshipOther;
        if (!revenant_directory_relationship(&found, candidate, url, error))
            return NO;
        if (found != NSURLRelationshipOther) {
            *outRelationship = found;
            return YES;
        }
    }
    return YES;
}

@end
