#import <Foundation/Foundation.h>
#import "CharonUTType.h"

// UniformTypeIdentifiers' own spelling of NSItemProvider's representation API, iOS 16: the six
// members and two properties of NSItemProvider+UTType.h, each the same operation as the
// type-identifier member the port already carries, with the content type taken apart into the
// identifier its own -identifier returns.
//
// Nothing here is a second implementation. -initWithContentsOfURL:,
// -registerItemForTypeIdentifier:loadHandler:, -registeredTypeIdentifiers,
// -registeredTypeIdentifiersWithFileOptions:, -registerDataRepresentationForTypeIdentifier:...,
// -registerFileRepresentationForTypeIdentifier:..., -loadDataRepresentationForTypeIdentifier:... and
// -loadFileRepresentationForTypeIdentifier:... are the port's own members (NSItemProvider is iOS 11,
// NSItemProvider.m implements it over the release's own UTI functions), and UTType is a wrapper over
// the same Uniform Type Identifier those take. So each method below reduces to its type-identifier
// twin, and the round trip UTType -> identifier -> UTType is the system's own: -identifier is the
// identifier and nothing else.
//
// The two openInPlace: arguments are the file options of the twin.
// NSItemProviderFileOptionsOpenInPlace is the bit 1 and NSItemProviderFileOptionsNone is 0, which is
// why the older API takes the same thing as a mask.
//
// One release per object file: every selector below arrived in iOS 16 and none of them is a member of
// anything this release carries, so this object holds the API of one release.

// The header's openInPlace: is the one bit of the older API's file options mask:
// NSItemProviderFileOptions' own enumeration is NSItemProviderFileOptionOpenInPlace = 1 and no other
// case, so a YES is that mask and a NO is none of it.
static NSItemProviderFileOptions CharonItemProviderOpenInPlace(BOOL openInPlace)
{
    return openInPlace ? NSItemProviderFileOptionOpenInPlace : (NSItemProviderFileOptions)0;
}

@implementation NSItemProvider (CharonUTType16)

- (instancetype)initWithContentsOfURL:(NSURL *)fileURL
                          contentType:(UTType *)contentType
                          openInPlace:(BOOL)openInPlace
                          coordinated:(BOOL)coordinated
                           visibility:(NSItemProviderRepresentationVisibility)visibility
{
    // The header's rule for a nil contentType is to deduce the type from the file extension, which is
    // what -typeWithFilenameExtension: answers with the release's own UTTypeCreatePreferredIdentifierForTag;
    // a contentType given instead replaces that. The rest the header adds -- the representation's
    // visibility, the openInPlace file option, and the file's name copied into suggestedName -- is
    // registered on top of the provider -initWithContentsOfURL: builds, which is the same
    // representation the type-identifier API carries for the same file.
    self = [self init];
    if (self && fileURL) {
        NSString *identifier = contentType.identifier;
        if (!identifier.length)
            identifier = [UTType typeWithFilenameExtension:fileURL.pathExtension].identifier;
        NSURL *url = fileURL;
        if (identifier.length && url.isFileURL) {
            [self registerItemForTypeIdentifier:identifier loadHandler:^(NSItemProviderCompletionHandler completionHandler, Class expectedValueClass, NSDictionary *options) {
                completionHandler([NSData dataWithContentsOfURL:url], nil);
            }];
            [self registerFileRepresentationForTypeIdentifier:identifier
                                                   fileOptions:CharonItemProviderOpenInPlace(openInPlace)
                                                   visibility:visibility
                                                  loadHandler:^NSProgress *(void (^done)(NSURL *, BOOL, NSError *)) {
                done(url, coordinated, nil);
                return nil;
            }];
        }
        [self registerItemForTypeIdentifier:@"public.url" loadHandler:^(NSItemProviderCompletionHandler completionHandler, Class expectedValueClass, NSDictionary *options) {
            completionHandler(url.absoluteString, nil);
        }];
        self.suggestedName = url.lastPathComponent;
    }
    return self;
}

- (void)registerDataRepresentationForContentType:(UTType *)contentType
                                      visibility:(NSItemProviderRepresentationVisibility)visibility
                                     loadHandler:(NSProgress *(^)(void (^)(NSData *, NSError *)))loadHandler
{
    [self registerDataRepresentationForTypeIdentifier:contentType.identifier
                                           visibility:visibility
                                          loadHandler:loadHandler];
}

- (void)registerFileRepresentationForContentType:(UTType *)contentType
                                      visibility:(NSItemProviderRepresentationVisibility)visibility
                                      openInPlace:(BOOL)openInPlace
                                     loadHandler:(NSProgress *(^)(void (^)(NSURL *, BOOL, NSError *)))loadHandler
{
    [self registerFileRepresentationForTypeIdentifier:contentType.identifier
                                           fileOptions:CharonItemProviderOpenInPlace(openInPlace)
                                           visibility:visibility
                                          loadHandler:loadHandler];
}

- (NSArray<UTType *> *)registeredContentTypes
{
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    for (NSString *identifier in [self registeredTypeIdentifiers])
        [types addObject:[UTType typeWithIdentifier:identifier]];
    return types;
}

- (NSArray<UTType *> *)registeredContentTypesForOpenInPlace
{
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    for (NSString *identifier in [self registeredTypeIdentifiersWithFileOptions:NSItemProviderFileOptionOpenInPlace])
        [types addObject:[UTType typeWithIdentifier:identifier]];
    return types;
}

- (NSArray<UTType *> *)registeredContentTypesConformingToContentType:(UTType *)contentType
{
    // The list of registered types that are conformant to a given type, in the order they were
    // registered, which is the order -registeredTypeIdentifiers hands them over in. The conformance
    // test is the release's own UTTypeConformsTo, which -[UTType conformsToType:] already calls.
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    for (NSString *identifier in [self registeredTypeIdentifiers]) {
        UTType *type = [UTType typeWithIdentifier:identifier];
        if ([type conformsToType:contentType])
            [types addObject:type];
    }
    return types;
}

- (NSProgress *)loadDataRepresentationForContentType:(UTType *)contentType
                                   completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    return [self loadDataRepresentationForTypeIdentifier:contentType.identifier completionHandler:completionHandler];
}

- (NSProgress *)loadFileRepresentationForContentType:(UTType *)contentType
                                         openInPlace:(BOOL)openInPlace
                                   completionHandler:(void (^)(NSURL *, BOOL, NSError *))completionHandler
{
    // The twin this release carries takes no openInPlace: it hands out a copy of the file, and the
    // in-place form of the same question is -loadInPlaceFileRepresentationForTypeIdentifier:. That is
    // what the header's completion block's `openInPlace` parameter reports, so the pair is asked the
    // question the way that answers it rather than dropping the argument on the floor.
    if (openInPlace)
        return [self loadInPlaceFileRepresentationForTypeIdentifier:contentType.identifier completionHandler:completionHandler];
    return [self loadFileRepresentationForTypeIdentifier:contentType.identifier
                                     completionHandler:^(NSURL *URL, NSError *error) { completionHandler(URL, NO, error); }];
}

@end