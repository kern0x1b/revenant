#import <UIKit/UIKit.h>
#import "RevenantSheet.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

const CGFloat UISheetPresentationControllerDetentInactive = CGFLOAT_MAX;

@interface RevenantSheetDetentContext (RevenantResolution) <UISheetPresentationControllerDetentResolutionContext>
@end

@implementation RevenantSheetDetentContext (RevenantResolution)
@end

@implementation UISheetPresentationControllerDetent (RevenantCustom)

+ (instancetype)customDetentWithIdentifier:(NSString *)identifier resolver:(CGFloat (^)(id<UISheetPresentationControllerDetentResolutionContext> context))resolver
{
    return [self revenant_customDetentWithIdentifier:identifier resolver:resolver];
}

- (NSString *)identifier
{
    return [self revenant_identifier];
}

- (CGFloat)resolvedValueInContext:(id<UISheetPresentationControllerDetentResolutionContext>)context
{
    return [self revenant_resolvedValueInContext:context];
}

@end

@implementation UISheetPresentationController (RevenantInvalidate)

- (void)invalidateDetents
{
    [self revenant_invalidateDetents];
}

@end
