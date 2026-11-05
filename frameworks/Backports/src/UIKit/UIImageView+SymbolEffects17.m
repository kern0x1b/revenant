#import "RevenantSymbolEffects.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static NSString *const revenant_effect_key_prefix = @"revenant.symbolEffect.";
static NSUInteger revenant_effect_count;

@interface RevenantSymbolEffectRun : NSObject <CAAnimationDelegate>
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSSymbolEffect *effect;
@property (nonatomic, copy) UISymbolEffectCompletion completion;
@end

@implementation RevenantSymbolEffectRun

@synthesize view = _view;
@synthesize effect = _effect;
@synthesize completion = _completion;

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished
{
    UISymbolEffectCompletion completion = self.completion;
    self.completion = nil;
    if (completion)
        completion([[UISymbolEffectCompletionContext alloc] initRevenantWithSender:self.view effect:self.effect finished:finished]);
}

@end

@implementation UIImageView (RevenantSymbolEffects)

- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect
{
    [self addSymbolEffect:symbolEffect options:[NSSymbolEffectOptions options] animated:YES completion:nil];
}

- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options
{
    [self addSymbolEffect:symbolEffect options:options animated:YES completion:nil];
}

- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated
{
    [self addSymbolEffect:symbolEffect options:options animated:animated completion:nil];
}

- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated completion:(UISymbolEffectCompletion)completionHandler
{
    NSSymbolEffectOptions *effectOptions = options ?: [NSSymbolEffectOptions options];
    CAAnimation *animation = [symbolEffect revenant_animationForView:self options:effectOptions];
    UISymbolEffectCompletion completion = [completionHandler copy];
    if (!animation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
                completion([[UISymbolEffectCompletionContext alloc] initRevenantWithSender:self effect:symbolEffect finished:NO]);
        });
        return;
    }
    RevenantSymbolEffectRun *run = [[RevenantSymbolEffectRun alloc] init];
    run.view = self;
    run.effect = symbolEffect;
    run.completion = completion;
    animation.delegate = run;
    revenant_effect_count++;
    [self.layer addAnimation:animation forKey:[revenant_effect_key_prefix stringByAppendingFormat:@"%lu", (unsigned long)revenant_effect_count]];
}

- (void)removeAllSymbolEffects
{
    for (NSString *key in [self.layer.animationKeys copy]) {
        if ([key hasPrefix:revenant_effect_key_prefix])
            [self.layer removeAnimationForKey:key];
    }
}

- (void)removeAllSymbolEffectsWithOptions:(NSSymbolEffectOptions *)options
{
    [self removeAllSymbolEffects];
}

- (void)removeAllSymbolEffectsWithOptions:(NSSymbolEffectOptions *)options animated:(BOOL)animated
{
    [self removeAllSymbolEffects];
}

@end
