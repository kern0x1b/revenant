#import <PhotosUI/PhotosUI.h>

@interface PHPickerFilter (Charon)
- (NSArray<NSString *> *)charon_mediaTypes;
@end

@interface PHPickerResult (Charon)
- (instancetype)initWithCharonItemProvider:(NSItemProvider *)itemProvider;
@end
