#import <Foundation/Foundation.h>
#import "CharonUTType.h"

@interface UTType (CharonExtensions)
- (BOOL)charon_conformsToFilenameExtension:(NSString *)extension;
@end

@implementation UTType (CharonExtensions)

- (BOOL)charon_conformsToFilenameExtension:(NSString *)extension
{
    if (!extension.length)
        return NO;
    UTType *resolved = [UTType typeWithFilenameExtension:extension];
    return resolved != nil && [resolved conformsToType:self];
}

@end

static NSString *CharonPathComponentForType(NSString *partialName, UTType *contentType, BOOL *appended)
{
    NSString *existing = partialName.pathExtension;
    if (existing.length && [contentType charon_conformsToFilenameExtension:existing]) {
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

@implementation NSString (CharonUTAdditions14)

- (NSString *)stringByAppendingPathComponent:(NSString *)partialName conformingToType:(UTType *)contentType
{
    if (!partialName)
        return [self copy];
    BOOL appended = NO;
    NSString *component = CharonPathComponentForType(partialName, contentType, &appended);
    return [self stringByAppendingPathComponent:component];
}

- (NSString *)stringByAppendingPathExtensionForType:(UTType *)contentType
{
    BOOL appended = NO;
    NSString *extended = CharonPathComponentForType(self.lastPathComponent, contentType, &appended);
    return appended ? extended : [self copy];
}

@end

@implementation NSURL (CharonUTAdditions14)

- (NSURL *)URLByAppendingPathComponent:(NSString *)partialName conformingToType:(UTType *)contentType
{
    if (!partialName)
        return [self copy];
    BOOL appended = NO;
    NSString *component = CharonPathComponentForType(partialName, contentType, &appended);
    return [self URLByAppendingPathComponent:component isDirectory:[contentType conformsToType:UTTypeDirectory]];
}

- (NSURL *)URLByAppendingPathExtensionForType:(UTType *)contentType
{
    BOOL appended = NO;
    NSString *extended = CharonPathComponentForType(self.lastPathComponent, contentType, &appended);
    if (!appended)
        return [self copy];
    return [self URLByAppendingPathComponent:extended isDirectory:([self hasDirectoryPath] || [contentType conformsToType:UTTypeDirectory])];
}

@end
