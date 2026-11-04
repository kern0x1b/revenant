#import <UIKit/UIKit.h>
#import "RevenantWebEngine.h"

void RevenantWithWebLock(void (^work)(void));
id RevenantWithWebLockValue(id (^work)(void));

@interface RevenantEngineHost : NSObject

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, readonly) id<RevenantEngineView> webView;
@property (nonatomic, readonly) UIScrollView *scrollView;

@end
