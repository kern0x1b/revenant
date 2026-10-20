#import <Foundation/Foundation.h>
#import "RevenantUTType.h"

@interface UTType (RevenantExtensions)
- (BOOL)revenant_conformsToFilenameExtension:(NSString *)extension;
@end

@implementation UTType (RevenantExtensions)

- (BOOL)revenant_conformsToFilenameExtension:(NSString *)extension
{
    if (!extension.length)
        return NO;
    UTType *resolved = [UTType typeWithFilenameExtension:extension];
    return resolved != nil && [resolved conformsToType:self];
}

@end

static NSString *RevenantPathComponentForType(NSString *partialName, UTType *contentType, BOOL *appended)
{
    NSString *existing = partialName.pathExtension;
    if (existing.length && [contentType revenant_conformsToFilenameExtension:existing]) {
        *appended = NO;
        return partialName;
    }
    NSString *extension = contentType.preferredFilenameExtension;
    if (!extension.length) {
        *appended = NO;
        return partialName;
    }
    *appended = YES;
    return [partialName stringByAppendingPathExtension:extension];
}

@implementation NSString (RevenantUTAdditions14)

- (NSString *)stringByAppendingPathComponent:(NSString *)partialName conformingToType:(UTType *)contentType
{
    if (!partialName)
        return [self copy];
    BOOL appended = NO;
    NSString *component = RevenantPathComponentForType(partialName, contentType, &appended);
    return [self stringByAppendingPathComponent:component];
}

- (NSString *)stringByAppendingPathExtensionForType:(UTType *)contentType
{
    BOOL appended = NO;
    NSString *extended = RevenantPathComponentForType(self.lastPathComponent, contentType, &appended);
    return appended ? extended : [self copy];
}

@end

@implementation NSURL (RevenantUTAdditions14)

- (NSURL *)URLByAppendingPathComponent:(NSString *)partialName conformingToType:(UTType *)contentType
{
    if (!partialName)
        return [self copy];
    BOOL appended = NO;
    NSString *component = RevenantPathComponentForType(partialName, contentType, &appended);
    return [self URLByAppendingPathComponent:component isDirectory:[contentType conformsToType:UTTypeDirectory]];
}

- (NSURL *)URLByAppendingPathExtensionForType:(UTType *)contentType
{
    BOOL appended = NO;
    NSString *extended = RevenantPathComponentForType(self.lastPathComponent, contentType, &appended);
    if (!appended)
        return [self copy];
    return [self URLByAppendingPathComponent:extended isDirectory:([self hasDirectoryPath] || [contentType conformsToType:UTTypeDirectory])];
}

@end
