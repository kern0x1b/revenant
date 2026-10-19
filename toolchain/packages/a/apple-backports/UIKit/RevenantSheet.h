#import <UIKit/UIKit.h>

@interface RevenantSheetDetentContext : NSObject
- (instancetype)initWithTraitCollection:(UITraitCollection *)traits maximumDetentValue:(CGFloat)maximum containerBounds:(CGRect)bounds;
@property (nonatomic, readonly) UITraitCollection *containerTraitCollection;
@property (nonatomic, readonly) CGFloat maximumDetentValue;
- (CGRect)_containerBounds;
@end

@interface UISheetPresentationControllerDetent (RevenantSheet)
+ (instancetype)revenant_customDetentWithIdentifier:(NSString *)identifier resolver:(CGFloat (^)(id context))resolver;
- (NSString *)revenant_identifier;
- (CGFloat)revenant_resolvedValueInContext:(id)context;
@end

@interface UISheetPresentationController (RevenantSheet)
- (void)revenant_invalidateDetents;
@end
