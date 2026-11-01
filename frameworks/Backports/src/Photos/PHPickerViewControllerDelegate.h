#import <Foundation/Foundation.h>

@class PHPickerViewController, PHPickerResult;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

API_UNAVAILABLE(watchos) NS_SWIFT_UI_ACTOR
@protocol PHPickerViewControllerDelegate <NSObject>

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_UNAVAILABLE(watchos);

@end

NS_HEADER_AUDIT_END(nullability, sendability)
