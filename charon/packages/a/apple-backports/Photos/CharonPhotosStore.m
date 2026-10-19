#import "CharonPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const CharonPhotosErrorDomain = @"PHPhotosErrorDomain";

@interface CharonPhotosThread : NSThread
@end

@implementation CharonPhotosThread

- (void)main
{
    @autoreleasepool {
        [[NSRunLoop currentRunLoop] addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        while (YES)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

@end

@interface CharonPhotosBlock : NSObject
@property (nonatomic, copy) dispatch_block_t block;
- (void)run;
@end

@implementation CharonPhotosBlock

- (void)run
{
    self.block();
}

@end

@implementation CharonPhotosStore

+ (CharonPhotosThread *)thread
{
    static CharonPhotosThread *thread;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        thread = [[CharonPhotosThread alloc] init];
        thread.name = @"space.kern0x1b.photos";
        [thread start];
    });
    return thread;
}

+ (ALAssetsLibrary *)library
{
    static ALAssetsLibrary *library;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        library = [[ALAssetsLibrary alloc] init];
    });
    return library;
}

+ (void)work:(void (^)(dispatch_block_t done))work
{
    if ([NSThread currentThread] == [self thread]) {
        work(^{});
        return;
    }
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    CharonPhotosBlock *wrapped = [[CharonPhotosBlock alloc] init];
    wrapped.block = ^{
        work(^{
            dispatch_semaphore_signal(finished);
        });
    };
    [wrapped performSelector:@selector(run) onThread:[self thread] withObject:nil waitUntilDone:NO];
    dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
}

+ (BOOL)canRead
{
    return [ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized;
}

+ (BOOL)canWrite
{
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    return status == ALAuthorizationStatusAuthorized || status == ALAuthorizationStatusNotDetermined;
}

// nil, with the library's error, when the release refuses the enumeration: a denied or restricted application, or a
// library whose data is unavailable.
+ (NSArray *)groupsOfTypes:(ALAssetsGroupType)types error:(NSError **)error
{
    __block NSMutableArray *groups = [NSMutableArray array];
    __block NSError *failed = nil;
    [self work:^(dispatch_block_t done) {
        [[self library] enumerateGroupsWithTypes:types usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (group)
                [groups addObject:group];
            else
                done();
        } failureBlock:^(NSError *problem) {
            failed = problem;
            done();
        }];
    }];
    if (failed) {
        if (error)
            *error = failed;
        return nil;
    }
    return groups;
}

+ (NSArray *)assetsOfGroup:(ALAssetsGroup *)group filter:(ALAssetsFilter *)filter sourceType:(PHAssetSourceType)sourceType
{
    NSMutableArray *found = [NSMutableArray array];
    Class assetClass = NSClassFromString(@"PHAsset");
    [group setAssetsFilter:filter ?: [ALAssetsFilter allAssets]];
    [group enumerateAssetsUsingBlock:^(ALAsset *asset, NSUInteger index, BOOL *stop) {
        if (asset)
            [found addObject:[[assetClass alloc] initWithCharonAsset:asset sourceType:sourceType]];
    }];
    return found;
}

+ (NSArray<PHAsset *> *)assetsOfSourceTypes:(PHAssetSourceType)sourceTypes filter:(ALAssetsFilter *)filter
{
    if (![self canRead])
        return @[];
    if (sourceTypes == 0)
        sourceTypes = PHAssetSourceTypeUserLibrary | PHAssetSourceTypeiTunesSynced;
    NSArray *kinds = @[@[@(PHAssetSourceTypeUserLibrary), @(ALAssetsGroupSavedPhotos)],
                       @[@(PHAssetSourceTypeiTunesSynced), @(ALAssetsGroupLibrary)],
                       @[@(PHAssetSourceTypeCloudShared), @(ALAssetsGroupPhotoStream)]];
    NSMutableArray *found = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSArray *kind in kinds) {
        PHAssetSourceType sourceType = (PHAssetSourceType)[kind[0] unsignedIntegerValue];
        if (!(sourceTypes & sourceType))
            continue;
        __block NSArray *assets = @[];
        [self work:^(dispatch_block_t done) {
            NSMutableArray *all = [NSMutableArray array];
            [[self library] enumerateGroupsWithTypes:[kind[1] unsignedIntegerValue] usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                if (group) {
                    [all addObjectsFromArray:[self assetsOfGroup:group filter:filter sourceType:sourceType]];
                } else {
                    assets = all;
                    done();
                }
            } failureBlock:^(NSError *error) {
                done();
            }];
        }];
        for (PHAsset *asset in assets) {
            if (![seen containsObject:asset.localIdentifier]) {
                [seen addObject:asset.localIdentifier];
                [found addObject:asset];
            }
        }
    }
    return found;
}

+ (NSArray<PHAsset *> *)assetsInGroupWithURL:(NSURL *)url filter:(ALAssetsFilter *)filter
{
    if (![self canRead])
        return @[];
    __block NSArray *assets = @[];
    [self work:^(dispatch_block_t done) {
        [[self library] groupForURL:url resultBlock:^(ALAssetsGroup *group) {
            if (group) {
                NSNumber *type = [group valueForProperty:ALAssetsGroupPropertyType];
                PHAssetSourceType sourceType = type.unsignedIntegerValue == ALAssetsGroupPhotoStream ? PHAssetSourceTypeCloudShared
                    : type.unsignedIntegerValue == ALAssetsGroupLibrary ? PHAssetSourceTypeiTunesSynced : PHAssetSourceTypeUserLibrary;
                assets = [self assetsOfGroup:group filter:filter sourceType:sourceType];
            }
            done();
        } failureBlock:^(NSError *error) {
            done();
        }];
    }];
    return assets;
}

+ (PHAssetCollection *)collectionForGroup:(ALAssetsGroup *)group
{
    return [[NSClassFromString(@"PHAssetCollection") alloc] initWithCharonGroup:group];
}

+ (NSArray<PHAssetCollection *> *)collectionsOfGroupTypes:(ALAssetsGroupType)types
{
    if (![self canRead])
        return @[];
    NSError *error = nil;
    NSArray *groups = [self groupsOfTypes:types error:&error];
    // A fetch has no way to report an error: the result is empty, as it is for an application that may not read, and the
    // refusal is said in the log.
    if (!groups)
        NSLog(@"Photos: the photo library refused to list its albums, so the fetch is empty: %@", error);
    NSMutableArray *found = [NSMutableArray array];
    for (ALAssetsGroup *group in groups)
        [found addObject:[self collectionForGroup:group]];
    return found;
}

+ (PHAssetCollection *)collectionWithIdentifier:(NSString *)identifier
{
    Class collectionClass = NSClassFromString(@"PHAssetCollection");
    if ([identifier hasPrefix:@"CHARON/SMART/"])
        return [[collectionClass alloc] initWithCharonSmartSubtype:(PHAssetCollectionSubtype)[[identifier substringFromIndex:13] integerValue]];
    NSURL *url = [NSURL URLWithString:[self resolvedIdentifier:identifier]];
    if (!url || ![self canRead])
        return nil;
    __block PHAssetCollection *found = nil;
    [self work:^(dispatch_block_t done) {
        [[self library] groupForURL:url resultBlock:^(ALAssetsGroup *group) {
            if (group)
                found = [self collectionForGroup:group];
            done();
        } failureBlock:^(NSError *error) {
            done();
        }];
    }];
    return found;
}

+ (PHAsset *)assetWithIdentifier:(NSString *)identifier
{
    NSURL *url = [NSURL URLWithString:[self resolvedIdentifier:identifier]];
    if (!url || ![self canRead])
        return nil;
    __block PHAsset *found = nil;
    [self work:^(dispatch_block_t done) {
        [[self library] assetForURL:url resultBlock:^(ALAsset *asset) {
            if (asset)
                found = [[NSClassFromString(@"PHAsset") alloc] initWithCharonAsset:asset sourceType:PHAssetSourceTypeUserLibrary];
            done();
        } failureBlock:^(NSError *error) {
            done();
        }];
    }];
    return found;
}

+ (NSArray<PHAssetCollection *> *)collectionsContainingAssetWithIdentifier:(NSString *)identifier
{
    NSString *resolved = [self resolvedIdentifier:identifier];
    NSMutableArray *found = [NSMutableArray array];
    for (PHAssetCollection *collection in [self collectionsOfGroupTypes:ALAssetsGroupAlbum | ALAssetsGroupEvent | ALAssetsGroupFaces | ALAssetsGroupSavedPhotos | ALAssetsGroupPhotoStream | ALAssetsGroupLibrary]) {
        for (PHAsset *asset in [collection charon_assets]) {
            if ([asset.localIdentifier isEqualToString:resolved]) {
                [found addObject:collection];
                break;
            }
        }
    }
    return found;
}

+ (NSString *)placeholdersPath
{
    NSString *base = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    return [[base stringByAppendingPathComponent:@"space.kern0x1b.photos"] stringByAppendingPathComponent:@"placeholders.plist"];
}

+ (NSMutableDictionary *)placeholders
{
    static NSMutableDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMutableDictionary dictionaryWithContentsOfFile:[self placeholdersPath]] ?: [NSMutableDictionary dictionary];
    });
    return table;
}

+ (NSString *)resolvedIdentifier:(NSString *)identifier
{
    NSMutableDictionary *table = [self placeholders];
    @synchronized (table) {
        return table[identifier] ?: identifier;
    }
}

+ (void)bindPlaceholderIdentifier:(NSString *)token toIdentifier:(NSString *)identifier
{
    NSMutableDictionary *table = [self placeholders];
    @synchronized (table) {
        table[token] = identifier;
        NSString *path = [self placeholdersPath];
        [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
        [table writeToFile:path atomically:YES];
    }
}

+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason
{
    return [NSError errorWithDomain:CharonPhotosErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: reason}];
}

+ (NSString *)identifierOfWrite:(void (^)(ALAssetsLibraryWriteImageCompletionBlock completion))write error:(NSError **)error
{
    __block NSURL *written = nil;
    __block NSError *failed = nil;
    [self work:^(dispatch_block_t done) {
        write(^(NSURL *url, NSError *problem) {
            written = url;
            failed = problem;
            done();
        });
    }];
    if (!written && error)
        *error = failed ?: [self errorWithCode:PHPhotosErrorInternalError reason:@"the photo library did not answer with the address of the asset"];
    return written.absoluteString;
}

+ (NSString *)writeImage:(UIImage *)image error:(NSError **)error
{
    return [self identifierOfWrite:^(ALAssetsLibraryWriteImageCompletionBlock completion) {
        [[self library] writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation completionBlock:completion];
    } error:error];
}

+ (NSString *)writeImageData:(NSData *)data metadata:(NSDictionary *)metadata error:(NSError **)error
{
    return [self identifierOfWrite:^(ALAssetsLibraryWriteImageCompletionBlock completion) {
        [[self library] writeImageDataToSavedPhotosAlbum:data metadata:metadata completionBlock:completion];
    } error:error];
}

+ (NSString *)writeVideoAtURL:(NSURL *)url error:(NSError **)error
{
    return [self identifierOfWrite:^(ALAssetsLibraryWriteImageCompletionBlock completion) {
        [[self library] writeVideoAtPathToSavedPhotosAlbum:url completionBlock:completion];
    } error:error];
}

+ (BOOL)findAlbumWithName:(NSString *)name found:(BOOL *)found error:(NSError **)error
{
    NSArray *groups = [self groupsOfTypes:ALAssetsGroupAlbum error:error];
    if (!groups)
        return NO;
    *found = NO;
    for (ALAssetsGroup *group in groups) {
        if ([[group valueForProperty:ALAssetsGroupPropertyName] isEqualToString:name])
            *found = YES;
    }
    return YES;
}

+ (ALAssetsGroup *)createAlbumWithName:(NSString *)name error:(NSError **)error
{
    __block ALAssetsGroup *made = nil;
    __block NSError *failed = nil;
    [self work:^(dispatch_block_t done) {
        [[self library] addAssetsGroupAlbumWithName:name resultBlock:^(ALAssetsGroup *group) {
            made = group;
            done();
        } failureBlock:^(NSError *problem) {
            failed = problem;
            done();
        }];
    }];
    if (!made && error)
        *error = failed ?: [self errorWithCode:PHPhotosErrorChangeNotSupported reason:@"the photo library made no album, as iOS 6 answers for a name already in use"];
    return made;
}

+ (BOOL)addAsset:(ALAsset *)asset toGroupWithURL:(NSURL *)url error:(NSError **)error
{
    __block BOOL added = NO;
    __block NSError *failed = nil;
    [self work:^(dispatch_block_t done) {
        [[self library] groupForURL:url resultBlock:^(ALAssetsGroup *group) {
            if (group) {
                added = [group addAsset:asset];
                if (!added)
                    failed = [self errorWithCode:PHPhotosErrorChangeNotSupported reason:@"the album refused the asset, as iOS 6 does for an album the application may not edit"];
            } else {
                failed = [self errorWithCode:PHPhotosErrorIdentifierNotFound reason:@"the album no longer exists"];
            }
            done();
        } failureBlock:^(NSError *problem) {
            failed = problem;
            done();
        }];
    }];
    if (!added && error)
        *error = failed;
    return added;
}

@end
