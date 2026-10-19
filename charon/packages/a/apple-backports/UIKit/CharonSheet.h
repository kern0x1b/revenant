#import <UIKit/UIKit.h>

/* What a detent is resolved against: the traits and the largest value of the sheet, and the
   container's bounds, which the medium detent reads as UIKit's own does (its private
   _containerBounds). UISheetPresentationController16.m makes it adopt
   UISheetPresentationControllerDetentResolutionContext, which is iOS 16.0's. */
@interface CharonSheetDetentContext : NSObject
- (instancetype)initWithTraitCollection:(UITraitCollection *)traits maximumDetentValue:(CGFloat)maximum containerBounds:(CGRect)bounds;
@property (nonatomic, readonly) UITraitCollection *containerTraitCollection;
@property (nonatomic, readonly) CGFloat maximumDetentValue;
- (CGRect)_containerBounds;
@end

@interface UISheetPresentationControllerDetent (CharonSheet)
+ (instancetype)charon_customDetentWithIdentifier:(NSString *)identifier resolver:(CGFloat (^)(id context))resolver;
- (NSString *)charon_identifier;
- (CGFloat)charon_resolvedValueInContext:(id)context;
@end

@interface UISheetPresentationController (CharonSheet)
- (void)charon_invalidateDetents;
@end
