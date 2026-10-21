#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char RevenantWebLinkPreviewKey;
static const char RevenantWebPictureInPictureKey;

@implementation UIWebView (RevenantOptions9)

- (BOOL)allowsLinkPreview
{
    return [objc_getAssociatedObject(self, &RevenantWebLinkPreviewKey) boolValue];
}

- (void)setAllowsLinkPreview:(BOOL)allowsLinkPreview
{
    objc_setAssociatedObject(self, &RevenantWebLinkPreviewKey, @(allowsLinkPreview), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsPictureInPictureMediaPlayback
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantWebPictureInPictureKey);
    return stored ? stored.boolValue : YES;
}

- (void)setAllowsPictureInPictureMediaPlayback:(BOOL)allowsPictureInPictureMediaPlayback
{
    objc_setAssociatedObject(self, &RevenantWebPictureInPictureKey, @(allowsPictureInPictureMediaPlayback), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
