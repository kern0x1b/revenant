#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIPrintPageRenderer (RevenantQuality14)

- (UIPrintRenderingQuality)currentRenderingQualityForRequestedRenderingQuality:(UIPrintRenderingQuality)requestedRenderingQuality
{
    return UIPrintRenderingQualityBest;
}

@end
