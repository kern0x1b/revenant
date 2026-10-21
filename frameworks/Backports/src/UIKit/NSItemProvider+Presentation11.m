#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantProviderSizeKey;
static const char RevenantProviderStyleKey;
static const char RevenantProviderTeamDataKey;

@implementation NSItemProvider (RevenantPresentation11)

- (CGSize)preferredPresentationSize
{
    NSValue *stored = objc_getAssociatedObject(self, &RevenantProviderSizeKey);
    return stored ? stored.CGSizeValue : CGSizeZero;
}

- (void)setPreferredPresentationSize:(CGSize)preferredPresentationSize
{
    objc_setAssociatedObject(self, &RevenantProviderSizeKey, [NSValue valueWithCGSize:preferredPresentationSize], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIPreferredPresentationStyle)preferredPresentationStyle
{
    return (UIPreferredPresentationStyle)[objc_getAssociatedObject(self, &RevenantProviderStyleKey) integerValue];
}

- (void)setPreferredPresentationStyle:(UIPreferredPresentationStyle)preferredPresentationStyle
{
    objc_setAssociatedObject(self, &RevenantProviderStyleKey, @(preferredPresentationStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSData *)teamData
{
    return objc_getAssociatedObject(self, &RevenantProviderTeamDataKey);
}

- (void)setTeamData:(NSData *)teamData
{
    objc_setAssociatedObject(self, &RevenantProviderTeamDataKey, teamData, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
