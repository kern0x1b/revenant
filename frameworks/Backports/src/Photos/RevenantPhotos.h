#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

@interface RevenantPhotosStore : NSObject
+ (ALAssetsLibrary *)library;
+ (BOOL)canRead;
+ (BOOL)canWrite;
+ (NSArray<PHAsset *> *)assetsOfSourceTypes:(PHAssetSourceType)sourceTypes filter:(ALAssetsFilter *)filter;
+ (NSArray<PHAsset *> *)assetsInGroupWithURL:(NSURL *)url filter:(ALAssetsFilter *)filter;
+ (NSArray<PHAssetCollection *> *)collectionsOfGroupTypes:(ALAssetsGroupType)types;
+ (PHAssetCollection *)collectionWithIdentifier:(NSString *)identifier;
+ (PHAsset *)assetWithIdentifier:(NSString *)identifier;
+ (NSArray<PHAssetCollection *> *)collectionsContainingAssetWithIdentifier:(NSString *)identifier;
+ (NSString *)resolvedIdentifier:(NSString *)identifier;
+ (void)bindPlaceholderIdentifier:(NSString *)token toIdentifier:(NSString *)identifier;
+ (NSString *)writeImageData:(NSData *)data metadata:(NSDictionary *)metadata error:(NSError **)error;
+ (NSString *)writeImage:(UIImage *)image error:(NSError **)error;
+ (NSString *)writeVideoAtURL:(NSURL *)url error:(NSError **)error;
+ (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason;
+ (BOOL)findAlbumWithName:(NSString *)name found:(BOOL *)found error:(NSError **)error;
+ (ALAssetsGroup *)createAlbumWithName:(NSString *)name error:(NSError **)error;
+ (BOOL)addAsset:(ALAsset *)asset toGroupWithURL:(NSURL *)url error:(NSError **)error;
@end

@interface RevenantPhotosTransaction : NSObject
+ (RevenantPhotosTransaction *)current;
+ (void)run:(dispatch_block_t)changes then:(void (^)(BOOL success, NSError *error))completion;
+ (BOOL)runAndWait:(dispatch_block_t)changes error:(NSError **)error;
- (void)addChange:(id)change;
- (NSArray *)changes;
- (void)refuseWithReason:(NSString *)reason;
@end

@interface PHPhotoLibrary () {
    NSHashTable *_observers;
    dispatch_queue_t _delivery;
    id _listening;
}
@end

@interface PHObject (Revenant)
- (instancetype)initWithRevenantLocalIdentifier:(NSString *)identifier;
@end

@interface PHFetchResult (Revenant)
- (instancetype)initWithRevenantObjects:(NSArray *)objects;
- (instancetype)initWithRevenantQuery:(NSArray *(^)(void))query options:(PHFetchOptions *)options;
- (PHFetchResult *)revenant_refetched;
- (BOOL)revenant_wantsIncrementalChangeDetails;
@end

@interface PHObject (RevenantChange)
- (PHObject *)revenant_refetched;
- (BOOL)revenant_sameStateAs:(PHObject *)other;
@end

@interface PHChange (Revenant)
- (instancetype)initWithRevenantUserInfo:(NSDictionary *)userInfo;
@end

@interface PHFetchOptions (Revenant)
- (NSArray *)revenant_apply:(NSArray *)objects;
@end

@interface PHAsset (Revenant)
- (instancetype)initWithRevenantAsset:(ALAsset *)asset sourceType:(PHAssetSourceType)sourceType;
- (ALAsset *)revenant_asset;
- (BOOL)isLocallyAvailable;
@end

@interface PHAssetCollection (Revenant)
- (instancetype)initWithRevenantGroup:(ALAssetsGroup *)group;
- (instancetype)initWithRevenantSmartSubtype:(PHAssetCollectionSubtype)subtype;
- (NSArray<PHAsset *> *)revenant_assets;
- (ALAssetsGroup *)revenant_group;
@end

@interface PHAssetChangeRequest (Revenant)
- (NSDictionary *)revenant_metadata;
@end
