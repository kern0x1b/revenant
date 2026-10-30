#import <UIKit/UIKit.h>
#import "RevenantWebEngine.h"

// Runs work while the engine's web thread lock is held. The engine runs the page on its web thread and holds the lock
// while it does, so the main thread takes it around each synchronous engine call and around the state that call changes.
// The lock is recursive. The policy and frame-load callbacks run on the web thread, so they already hold it.
void RevenantWithWebLock(void (^work)(void));
id RevenantWithWebLockValue(id (^work)(void));

@interface RevenantEngineHost : NSObject

- (instancetype)initWithFrame:(CGRect)frame;

@property (nonatomic, readonly) id<RevenantEngineView> webView;
@property (nonatomic, readonly) UIScrollView *scrollView;

@end
