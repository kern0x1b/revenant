#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Symbols/NSSymbolEffect.h>

typedef NS_ENUM(NSInteger, RevenantSymbolEffectDirection) {
    RevenantSymbolEffectDirectionDefault,
    RevenantSymbolEffectDirectionUp,
    RevenantSymbolEffectDirectionDown,
};

@interface NSSymbolEffect (RevenantSymbolEffects)
@property (nonatomic, readonly) BOOL revenant_wholeSymbol;
@property (nonatomic, readonly) RevenantSymbolEffectDirection revenant_direction;
- (instancetype)initRevenantWithWholeSymbol:(BOOL)wholeSymbol direction:(RevenantSymbolEffectDirection)direction;
- (CAAnimation *)revenant_animationForView:(UIView *)view options:(NSSymbolEffectOptions *)options;
@end

@interface NSSymbolEffectOptions (RevenantSymbolEffects)
@property (nonatomic, readonly) BOOL revenant_repeating;
@property (nonatomic, readonly) NSInteger revenant_repeatCount;
@property (nonatomic, readonly) double revenant_speed;
- (instancetype)initRevenantWithRepeating:(BOOL)repeating repeatCount:(NSInteger)repeatCount speed:(double)speed;
@end

@interface UISymbolEffectCompletionContext (RevenantInit)
- (instancetype)initRevenantWithSender:(id)sender finished:(BOOL)finished;
@end
