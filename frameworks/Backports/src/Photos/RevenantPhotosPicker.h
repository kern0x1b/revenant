#import <PhotosUI/PhotosUI.h>

@interface PHPickerFilter (Revenant)
- (NSArray<NSString *> *)revenant_mediaTypes;
+ (PHPickerFilter *)revenant_filterOfSubtype:(PHAssetMediaSubtype)subtype;
@end

@interface PHPickerResult (Revenant)
- (instancetype)initWithRevenantItemProvider:(NSItemProvider *)itemProvider;
@end
