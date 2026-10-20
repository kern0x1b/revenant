#import <Foundation/Foundation.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
@interface UIDocumentBrowserTransitionController : NSObject <UIViewControllerAnimatedTransitioning>

- (instancetype)init NS_UNAVAILABLE;

@property (strong, nonatomic, nullable) NSProgress *loadingProgress;

@property (weak, nullable, nonatomic) UIView *targetView;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
