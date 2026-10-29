#import <UIKit/UIKit.h>
#import "RevenantWebEngine.h"

@interface RevenantEngineHost : NSObject

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, readonly) id<RevenantEngineView> webView;
@property (nonatomic, readonly) UIScrollView *scrollView;

@end
