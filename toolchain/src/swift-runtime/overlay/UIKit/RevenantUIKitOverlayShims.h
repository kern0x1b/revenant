#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIAction (RevenantOverlayInitializers)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier handler:(UIActionHandler)handler NS_SWIFT_NAME(init(revenantTitle:image:identifier:handler:));
@end

@interface UIMenu (RevenantOverlayInitializers)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier options:(UIMenuOptions)options children:(NSArray *)children NS_SWIFT_NAME(init(revenantTitle:image:identifier:options:children:));
@end

NS_ASSUME_NONNULL_END
