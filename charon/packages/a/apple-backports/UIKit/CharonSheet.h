#import <UIKit/UIKit.h>

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
