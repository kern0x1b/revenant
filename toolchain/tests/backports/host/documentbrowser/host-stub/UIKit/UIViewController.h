#import <Foundation/Foundation.h>
#import "UIKit/UIViewControllerTransitioning.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController : NSObject
@property (nonatomic, strong, nullable) UIView *view;
- (instancetype)initWithNibName:(nullable NSString *)nibName bundle:(nullable NSBundle *)bundle;
@end

NS_ASSUME_NONNULL_END
