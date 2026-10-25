#import "RevenantSCNJitter.h"

static const NSUInteger RevenantSCNJitterSamples = 8;

static float revenant_halton(NSUInteger index, NSUInteger base)
{
    float result = 0;
    float fraction = 1;
    while (index > 0) {
        fraction /= (float)base;
        result += fraction * (float)(index % base);
        index /= base;
    }
    return result;
}

@implementation RevenantSCNJitter

+ (NSUInteger)sampleCount
{
    return RevenantSCNJitterSamples;
}

+ (void)offsetForFrame:(NSUInteger)frame x:(float *)x y:(float *)y
{
    NSUInteger index = frame % RevenantSCNJitterSamples + 1;
    *x = revenant_halton(index, 2) - 0.5f;
    *y = revenant_halton(index, 3) - 0.5f;
}

+ (float)weightForAccumulated:(NSUInteger)accumulated
{
    return 1.0f / (float)(accumulated + 1);
}

@end
