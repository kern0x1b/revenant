// The stand-in for the one UIKit interface the port's file needs, so its bodies can be run on the
// host. UIViewController is a view controller and the port asks it for its view to aim a
// transition at; nothing else of UIKit is touched, because everything else the file uses is
// Foundation, which the host has.
#import <Foundation/Foundation.h>
#import "UIKit/UIViewControllerTransitioning.h"

NS_ASSUME_NONNULL_BEGIN

// The run loop the transition's animation block is driven on, and the duration it will report, so
// the harness can run a transition through instead of only asking for its length.

@interface UIViewController : NSObject
@property (nonatomic, strong, nullable) UIView *view;
- (instancetype)initWithNibName:(nullable NSString *)nibName bundle:(nullable NSBundle *)bundle;
@end

NS_ASSUME_NONNULL_END
