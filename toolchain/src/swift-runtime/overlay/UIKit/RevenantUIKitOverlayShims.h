#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIAction (RevenantOverlayInitializers)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier handler:(UIActionHandler)handler NS_SWIFT_NAME(init(revenantTitle:image:identifier:handler:));
@end

@interface UIMenu (RevenantOverlayInitializers)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier options:(UIMenuOptions)options children:(NSArray *)children NS_SWIFT_NAME(init(revenantTitle:image:identifier:options:children:));
@end

extern char OBJC_CLASS_$_UIPointerShape __attribute__((weak_import));

static inline Class _Nullable revenant_pointer_shape_class(void)
{
    return &OBJC_CLASS_$_UIPointerShape ? (__bridge Class)(void *)&OBJC_CLASS_$_UIPointerShape : Nil;
}

static inline UIPointerShape *_Nullable revenant_pointer_shape_with_path(UIBezierPath *path) NS_SWIFT_NAME(revenantPointerShape(path:))
{
    Class shape = revenant_pointer_shape_class();
    return shape ? (UIPointerShape *)[shape shapeWithPath:path] : nil;
}

static inline UIPointerShape *_Nullable revenant_pointer_shape_rounded_rect(CGRect rect, CGFloat radius) NS_SWIFT_NAME(revenantPointerShape(roundedRect:cornerRadius:))
{
    Class shape = revenant_pointer_shape_class();
    return shape ? (UIPointerShape *)[shape shapeWithRoundedRect:rect cornerRadius:radius] : nil;
}

static inline UIPointerShape *_Nullable revenant_pointer_shape_beam(CGFloat length, UIAxis axis) NS_SWIFT_NAME(revenantPointerShape(beamWithPreferredLength:axis:))
{
    Class shape = revenant_pointer_shape_class();
    return shape ? (UIPointerShape *)[shape beamWithPreferredLength:length axis:axis] : nil;
}

NS_ASSUME_NONNULL_END
