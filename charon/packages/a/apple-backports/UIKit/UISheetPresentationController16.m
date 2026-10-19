#import <UIKit/UIKit.h>
#import "CharonSheet.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

/* What iOS 16.0 added to the sheet: the inactive value, custom detents and the context they
   are resolved against. The rest of the class is UISheetPresentationController.m's. */

const CGFloat UISheetPresentationControllerDetentInactive = CGFLOAT_MAX;

@interface CharonSheetDetentContext (CharonResolution) <UISheetPresentationControllerDetentResolutionContext>
@end

@implementation CharonSheetDetentContext (CharonResolution)
@end

@implementation UISheetPresentationControllerDetent (CharonCustom)

+ (instancetype)customDetentWithIdentifier:(NSString *)identifier resolver:(CGFloat (^)(id<UISheetPresentationControllerDetentResolutionContext> context))resolver
{
    return [self charon_customDetentWithIdentifier:identifier resolver:resolver];
}

- (NSString *)identifier
{
    return [self charon_identifier];
}

- (CGFloat)resolvedValueInContext:(id<UISheetPresentationControllerDetentResolutionContext>)context
{
    return [self charon_resolvedValueInContext:context];
}

@end

@implementation UISheetPresentationController (CharonInvalidate)

- (void)invalidateDetents
{
    [self charon_invalidateDetents];
}

@end
