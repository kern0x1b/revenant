#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantDropPreviewUpdateCountKey;

@implementation UIDragItem (RevenantDropPreviewUpdate17)

- (void)setNeedsDropPreviewUpdate
{
    NSUInteger asked = [objc_getAssociatedObject(self, &RevenantDropPreviewUpdateCountKey) unsignedIntegerValue];
    objc_setAssociatedObject(self, &RevenantDropPreviewUpdateCountKey,
                            @(asked + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)revenant_dropPreviewUpdateCount
{
    return [objc_getAssociatedObject(self, &RevenantDropPreviewUpdateCountKey) unsignedIntegerValue];
}

@end
