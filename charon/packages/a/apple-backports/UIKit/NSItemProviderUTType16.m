#import <Foundation/Foundation.h>
#import "CharonUTType.h"

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
    if (openInPlace)
        return [self loadInPlaceFileRepresentationForTypeIdentifier:contentType.identifier completionHandler:completionHandler];
    return [self loadFileRepresentationForTypeIdentifier:contentType.identifier
                                     completionHandler:^(NSURL *URL, NSError *error) { completionHandler(URL, NO, error); }];
}

@end
