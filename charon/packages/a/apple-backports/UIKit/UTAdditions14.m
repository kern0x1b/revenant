#import <Foundation/Foundation.h>
#import "CharonUTType.h"

// UniformTypeIdentifiers' additions to NSString and NSURL, iOS 14 (UTAdditions.h): four methods,
// each the release's own path-extension machinery with the extension of the content type the release's
// own UTI functions name.
//
// The rule each of the four implements is stated in full by the header, and both halves of it are the
// release's own:
//
//   * the extension to append is -[UTType preferredFilenameExtension] of the content type, which is
//     UTTypeCopyPreferredTagWithClass(identifier, kUTTagClassFilenameExtension);
//   * an extension already on the last path component is left alone when that extension is already
//     valid for file system objects of the content type, and appended to when it is not -- which is
//     what -pathExtensionIsValidForType: is for on a release that has it, and what
//     UTTypeConformsTo against the type that claims that extension answers here. "readme" + plain text
//     gives "readme.txt"; "puppy.jpg" + UTTypeImage gives "puppy.jpg"; "puppy.jpg" + UTTypePlainText
//     gives "puppy.jpg.txt", each the header's own worked example.
//
// One release per object file: every selector below arrived in iOS 14 and none of them is a member of
// anything this release carries.

@interface UTType (CharonExtensions)
- (BOOL)charon_conformsToFilenameExtension:(NSString *)extension;
@end

@implementation UTType (CharonExtensions)

// Whether a file whose last path component ends in this extension is already a file system object of
// the receiver's type. The release's own answer to that question is its conformance table: an
// extension is valid for a type when the type the release resolves for the extension conforms to the
// receiver. -typeWithFilenameExtension: is what resolves it, and it is the release's
// UTTypeCreatePreferredIdentifierForTag underneath.
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
        // If the extension cannot be appended, the method gives back a copy of self.
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
    // The header's own note for this pair: "The resulting URL has a directory path if contentType
    // conforms to UTTypeDirectory", and the directory-ness of the receiver is its own.
    return [self URLByAppendingPathComponent:extended isDirectory:([self hasDirectoryPath] || [contentType conformsToType:UTTypeDirectory])];
}

@end