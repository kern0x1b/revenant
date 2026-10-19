#import <PhotosUI/PhotosUI.h>

@interface PHPickerFilter (Revenant)
- (NSArray<NSString *> *)revenant_mediaTypes;
@end

@interface PHPickerResult (Revenant)
- (instancetype)initWithRevenantItemProvider:(NSItemProvider *)itemProvider;
@end
