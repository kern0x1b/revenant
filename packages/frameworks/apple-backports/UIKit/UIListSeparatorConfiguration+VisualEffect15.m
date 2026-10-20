#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantLists.h"

static const char RevenantSeparatorVisualEffectKey;

static UIVisualEffect *revenant_separator_visual_effect(UIListSeparatorConfiguration *configuration)
{
    return objc_getAssociatedObject(configuration, &RevenantSeparatorVisualEffectKey);
}

@implementation UIListSeparatorConfiguration (RevenantVisualEffect15)

- (UIVisualEffect *)visualEffect
{
    return revenant_separator_visual_effect(self);
}

- (void)setVisualEffect:(UIVisualEffect *)visualEffect
{
    objc_setAssociatedObject(self, &RevenantSeparatorVisualEffectKey, [visualEffect copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_takeVisualEffectFrom:(UIListSeparatorConfiguration *)other
{
    [self setVisualEffect:revenant_separator_visual_effect(other)];
}

- (BOOL)revenant_visualEffectIsEqualTo:(UIListSeparatorConfiguration *)other
{
    UIVisualEffect *mine = revenant_separator_visual_effect(self);
    UIVisualEffect *theirs = revenant_separator_visual_effect(other);
    if (mine == theirs)
        return YES;
    if (!mine || !theirs)
        return NO;
    return [mine isEqual:theirs];
}

- (void)revenant_encodeVisualEffectWithCoder:(NSCoder *)coder
{
    [coder encodeObject:revenant_separator_visual_effect(self) forKey:@"visualEffect"];
}

- (void)revenant_decodeVisualEffectWithCoder:(NSCoder *)coder
{
    UIVisualEffect *effect = [coder decodeObjectOfClass:[UIVisualEffect class] forKey:@"visualEffect"];
    if (effect)
        [self setVisualEffect:effect];
}

@end
