// The release's CIFeature, as a stand-in for the port build only. The release carries this base class with the instance
// selectors -type, -bounds and -init (tools/corpus inventory of the 6.1.3 cache, facts/CoreImage/Features.md), and the
// port's three subclasses override the first two. What a fresh CIFeature answers on the release is not measured here:
// this build does not run on 6.1.3, so the stand-in answers nil and CGRectZero, and the fresh-instance lines of the
// port side are the subclasses' own answers over that stand-in.

#import <CoreImage/CoreImage.h>

@implementation CIFeature

- (NSString *)type
{
    return nil;
}

- (CGRect)bounds
{
    return CGRectZero;
}

@end
