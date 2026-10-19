#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonLists.h"

static const char CharonSeparatorVisualEffectKey;

static UIVisualEffect *charon_separator_visual_effect(UIListSeparatorConfiguration *configuration)
{
    return objc_getAssociatedObject(configuration, &CharonSeparatorVisualEffectKey);
}

@implementation UIListSeparatorConfiguration (CharonVisualEffect15)

- (UIVisualEffect *)visualEffect
{
    return charon_separator_visual_effect(self);
}

- (void)setVisualEffect:(UIVisualEffect *)visualEffect
{
    objc_setAssociatedObject(self, &CharonSeparatorVisualEffectKey, [visualEffect copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_takeVisualEffectFrom:(UIListSeparatorConfiguration *)other
{
    [self setVisualEffect:charon_separator_visual_effect(other)];
}

- (BOOL)charon_visualEffectIsEqualTo:(UIListSeparatorConfiguration *)other
{
    UIVisualEffect *mine = charon_separator_visual_effect(self);
    UIVisualEffect *theirs = charon_separator_visual_effect(other);
    if (mine == theirs)
        return YES;
    if (!mine || !theirs)
        return NO;
    return [mine isEqual:theirs];
}

- (void)charon_encodeVisualEffectWithCoder:(NSCoder *)coder
{
    [coder encodeObject:charon_separator_visual_effect(self) forKey:@"visualEffect"];
}

- (void)charon_decodeVisualEffectWithCoder:(NSCoder *)coder
{
    UIVisualEffect *effect = [coder decodeObjectOfClass:[UIVisualEffect class] forKey:@"visualEffect"];
    if (effect)
        [self setVisualEffect:effect];
}

@end
