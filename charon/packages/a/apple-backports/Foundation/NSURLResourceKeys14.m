#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/xattr.h>

NSURLResourceKey const NSURLContentTypeKey = @"NSURLContentTypeKey";
NSURLResourceKey const NSURLFileContentIdentifierKey = @"NSURLFileContentIdentifierKey";
NSURLResourceKey const NSURLMayShareFileContentKey = @"NSURLMayShareFileContentKey";
NSURLResourceKey const NSURLMayHaveExtendedAttributesKey = @"NSURLMayHaveExtendedAttributesKey";
NSURLResourceKey const NSURLIsPurgeableKey = @"NSURLIsPurgeableKey";
NSURLResourceKey const NSURLIsSparseKey = @"NSURLIsSparseKey";
NSURLResourceKey const NSURLVolumeSupportsFileProtectionKey = @"NSURLVolumeSupportsFileProtectionKey";

static NSArray *charon_resource_keys(void)
{
    return @[NSURLContentTypeKey, NSURLFileContentIdentifierKey, NSURLMayShareFileContentKey, NSURLMayHaveExtendedAttributesKey, NSURLIsPurgeableKey, NSURLIsSparseKey, NSURLVolumeSupportsFileProtectionKey];
}

id charon_resource_value(NSString *path, NSString *key);

id charon_resource_value(NSString *path, NSString *key)
{
    struct stat status;
    if (lstat(path.fileSystemRepresentation, &status) != 0)
        return nil;
    if ([key isEqualToString:NSURLMayShareFileContentKey] || [key isEqualToString:NSURLIsPurgeableKey])
        return @NO;
    if ([key isEqualToString:NSURLIsSparseKey])
        return @(S_ISREG(status.st_mode) && (off_t)status.st_blocks * 512 < status.st_size);
    if ([key isEqualToString:NSURLMayHaveExtendedAttributesKey])
        return @(listxattr(path.fileSystemRepresentation, NULL, 0, XATTR_NOFOLLOW) > 0);
    if ([key isEqualToString:NSURLVolumeSupportsFileProtectionKey]) {
        struct statfs volume;
        if (statfs(path.fileSystemRepresentation, &volume) == 0 && ((volume.f_flags & 0x00000080) || !strcmp(volume.f_fstypename, "apfs")))
            return @YES;
        return @([[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL][NSFileProtectionKey] != nil);
    }
    return nil;
}

@interface CharonResourceKeysInstaller : NSObject
@end

@implementation CharonResourceKeysInstaller

+ (void)load
{
    id known = nil;
    if ([[NSURL fileURLWithPath:@"/"] getResourceValue:&known forKey:@"NSURLIsSparseKey" error:NULL] && known)
        return;
    Class cls = [NSURL class];
    SEL single = @selector(getResourceValue:forKey:error:);
    Method singleMethod = class_getInstanceMethod(cls, single);
    if (singleMethod) {
        IMP original = method_getImplementation(singleMethod);
        class_replaceMethod(cls, single, imp_implementationWithBlock(^BOOL(NSURL *URL, id *value, NSString *key, NSError **error) {
            if (!URL.isFileURL || ![charon_resource_keys() containsObject:key])
                return ((BOOL (*)(id, SEL, id *, id, NSError **))original)(URL, single, value, key, error);
            NSString *path = URL.path;
            id existing = nil;
            if (!((BOOL (*)(id, SEL, id *, id, NSError **))original)(URL, single, &existing, NSURLNameKey, error))
                return NO;
            if (value)
                *value = charon_resource_value(path, key);
            return YES;
        }), method_getTypeEncoding(singleMethod));
    }
    SEL many = @selector(resourceValuesForKeys:error:);
    Method manyMethod = class_getInstanceMethod(cls, many);
    if (manyMethod) {
        IMP original = method_getImplementation(manyMethod);
        class_replaceMethod(cls, many, imp_implementationWithBlock(^NSDictionary *(NSURL *URL, NSArray *keys, NSError **error) {
            NSMutableArray *ours = [NSMutableArray array], *theirs = [NSMutableArray array];
            for (NSString *key in keys)
                [URL.isFileURL && [charon_resource_keys() containsObject:key] ? ours : theirs addObject:key];
            if (!ours.count)
                return ((id (*)(id, SEL, id, NSError **))original)(URL, many, keys, error);
            NSDictionary *base = ((id (*)(id, SEL, id, NSError **))original)(URL, many, theirs.count ? theirs : @[NSURLNameKey], error);
            if (!base)
                return nil;
            NSMutableDictionary *merged = [NSMutableDictionary dictionary];
            for (NSString *key in theirs) {
                if (base[key])
                    merged[key] = base[key];
            }
            NSString *path = URL.path;
            for (NSString *key in ours) {
                id value = charon_resource_value(path, key);
                if (value)
                    merged[key] = value;
            }
            return merged;
        }), method_getTypeEncoding(manyMethod));
    }
}

@end
