#import <UIKit/UIKit.h>
#import "presses-cases.h"

@interface PressesCounter : UIResponder
@property (nonatomic, strong) UIResponder *next;
@property (nonatomic, strong) NSMutableArray *calls;
@property (nonatomic) NSUInteger lastCount;
@end

@implementation PressesCounter
- (UIResponder *)nextResponder { return self.next; }
- (void)note:(NSString *)name presses:(NSSet *)presses
{
    if (!self.calls)
        self.calls = [NSMutableArray array];
    [self.calls addObject:name];
    self.lastCount = presses.count;
}
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event { [self note:@"began" presses:presses]; [super pressesBegan:presses withEvent:event]; }
- (void)pressesChanged:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event { [self note:@"changed" presses:presses]; [super pressesChanged:presses withEvent:event]; }
- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event { [self note:@"ended" presses:presses]; [super pressesEnded:presses withEvent:event]; }
- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event { [self note:@"cancelled" presses:presses]; [super pressesCancelled:presses withEvent:event]; }
@end

void presses_run(UIWindow *window, PressesRecorder record)
{
    UIPress *press = [[UIPress alloc] init];
    record(@"press.new", [NSString stringWithFormat:@"%@ phase=%ld type=%ld window=%d responder=%d recognizers=%d force=%.1f", NSStringFromClass([press superclass]), (long)press.phase, (long)press.type, press.window == nil, press.responder == nil, press.gestureRecognizers == nil, press.force]);
    record(@"press.enums", [NSString stringWithFormat:@"%ld %ld %ld %ld %ld %ld %ld | %ld %ld %ld %ld %ld", (long)UIPressTypeUpArrow, (long)UIPressTypeDownArrow, (long)UIPressTypeLeftArrow, (long)UIPressTypeRightArrow, (long)UIPressTypeSelect, (long)UIPressTypeMenu, (long)UIPressTypePlayPause, (long)UIPressPhaseBegan, (long)UIPressPhaseChanged, (long)UIPressPhaseStationary, (long)UIPressPhaseEnded, (long)UIPressPhaseCancelled]);
    UIPressesEvent *event = [[UIPressesEvent alloc] init];
    record(@"event.new", [NSString stringWithFormat:@"%@ presses=%lu type=%ld forRecognizer=%lu", NSStringFromClass([event superclass]), (unsigned long)event.allPresses.count, (long)event.type, (unsigned long)[event pressesForGestureRecognizer:[[UITapGestureRecognizer alloc] init]].count]);
    for (NSNumber *filled in @[@NO, @YES]) {
        PressesCounter *first = [[PressesCounter alloc] init];
        PressesCounter *second = [[PressesCounter alloc] init];
        first.next = second;
        NSSet *presses = filled.boolValue ? [NSSet setWithObject:press] : [NSSet set];
        [first pressesBegan:presses withEvent:event];
        [first pressesChanged:presses withEvent:event];
        [first pressesEnded:presses withEvent:event];
        [first pressesCancelled:presses withEvent:event];
        record([NSString stringWithFormat:@"responder.filled%@", filled], [NSString stringWithFormat:@"first=%@ second=%@ count=%lu", [first.calls componentsJoinedByString:@","], [second.calls componentsJoinedByString:@","], (unsigned long)second.lastCount]);
    }
    UIResponder *plain = [[UIResponder alloc] init];
    [plain pressesBegan:[NSSet setWithObject:press] withEvent:event];
    record(@"responder.plain", @"survives");
    UICollectionViewFlowLayout *current = [[UICollectionViewFlowLayout alloc] init];
    UICollectionViewFlowLayout *next = [[UICollectionViewFlowLayout alloc] init];
    UICollectionViewTransitionLayout *transition = [[UICollectionViewTransitionLayout alloc] initWithCurrentLayout:current nextLayout:next];
    record(@"transition.new", [NSString stringWithFormat:@"%@ progress=%.1f current=%d next=%d", NSStringFromClass([transition superclass]), transition.transitionProgress, transition.currentLayout == current, transition.nextLayout == next]);
    transition.transitionProgress = 0.5;
    [transition updateValue:0.7 forAnimatedKey:@"a"];
    record(@"transition.set", [NSString stringWithFormat:@"progress=%.1f value=%.1f other=%.1f", transition.transitionProgress, [transition valueForAnimatedKey:@"a"], [transition valueForAnimatedKey:@"b"]]);
}
