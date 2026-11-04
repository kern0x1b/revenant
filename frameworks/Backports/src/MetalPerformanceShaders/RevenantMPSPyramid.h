#pragma once
#import "RevenantMPSTexture.h"

@interface MPSImagePyramid (RevenantMPSImagePyramidFilter)
- (const float *)revenant_mps_filter;
- (NSUInteger)revenant_mps_filterWidth;
- (NSUInteger)revenant_mps_filterHeight;
@end

static inline NSUInteger RevenantMPSPyramidExtent(NSUInteger base, NSUInteger level)
{
    NSUInteger extent = base >> level;
    return extent ? extent : 1;
}
