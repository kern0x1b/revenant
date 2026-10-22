#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

BOOL revenant_trash_item(NSFileManager *manager, NSURL *url, NSString *trash, NSURL **resulting, NSError **error);

BOOL revenant_trash_item(NSFileManager *manager, NSURL *url, NSString *trash, NSURL **resulting, NSError **error)
{
    if (!url.isFileURL) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnsupportedSchemeError userInfo:@{NSURLErrorKey: url}];
        return NO;
    }
    if (![manager fileExistsAtPath:url.path]) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:@{NSURLErrorKey: url}];
        return NO;
    }
    if (![manager createDirectoryAtPath:trash withIntermediateDirectories:YES attributes:nil error:error])
        return NO;
    NSString *name = url.lastPathComponent;
    NSString *base = name.stringByDeletingPathExtension, *extension = name.pathExtension;
    NSString *target = [trash stringByAppendingPathComponent:name];
    for (NSUInteger copy = 2; [manager fileExistsAtPath:target]; copy++) {
        NSString *numbered = [NSString stringWithFormat:@"%@ %lu", base, (unsigned long)copy];
        target = [trash stringByAppendingPathComponent:extension.length ? [numbered stringByAppendingPathExtension:extension] : numbered];
    }
    NSURL *destination = [NSURL fileURLWithPath:target isDirectory:[url hasDirectoryPath]];
    if (![manager moveItemAtURL:url toURL:destination error:error])
        return NO;
    if (resulting)
        *resulting = destination;
    return YES;
}

@implementation NSFileManager (RevenantTrash11)

- (BOOL)trashItemAtURL:(NSURL *)url resultingItemURL:(NSURL **)outResultingURL error:(NSError **)error
{
    return revenant_trash_item(self, url, [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"], outResultingURL, error);
}

@end
