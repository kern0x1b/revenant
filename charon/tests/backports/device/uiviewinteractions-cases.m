#import <UIKit/UIKit.h>
#import "uiviewinteractions-cases.h"

// What a view does with the interactions it holds, as the system's own UIKit does it, so the
// port's three are held to the same answers. Every case is a question that has one answer and no
// judgement in it: is the interaction held, is a nil one refused and with what, is one already held
// added twice or moved from elsewhere, is removing one that is not held quietly nothing, and what
// the interaction's own willMoveToView:/didMoveToView: see on each of those.

// The interaction the cases add, conforming to UIInteraction as a real one does, and recording the
// two messages the protocol declares.
@interface InteractionProbe : NSObject <UIInteraction>
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSMutableArray<NSString *> *moved;
@end

@implementation InteractionProbe
@synthesize view = _view;
@synthesize moved = _moved;

- (instancetype)init
{
    if ((self = [super init]))
        _moved = [NSMutableArray array];
    return self;
}

- (void)willMoveToView:(UIView *)view
{
    [_moved addObject:view ? @"will:view" : @"will:nil"];
}

- (void)didMoveToView:(UIView *)view
{
    [_moved addObject:view ? @"did:view" : @"did:nil"];
}
@end

static NSString *uiview_Describe(id value)
{
    NSUInteger count = [value isKindOfClass:[NSArray class]] ? [value count] : 0;
    return [NSString stringWithFormat:@"%lu", (unsigned long)count];
}

static NSString *uiview_Outcome(void (^block)(void))
{
    @try {
        block();
        return @"survived";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}

void uiviewinteractions_run(UIViewInteractionsRecorder record)
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    InteractionProbe *interaction = [[InteractionProbe alloc] init];

    record(@"interactions.empty", uiview_Describe(view.interactions));
    record(@"interaction.movedBeforeAdd", [interaction.moved componentsJoinedByString:@","]);

    [view addInteraction:interaction];
    record(@"interactions.afterAdd", uiview_Describe(view.interactions));
    record(@"interaction.movedAfterAdd", [interaction.moved componentsJoinedByString:@","]);

    record(@"add.nil", uiview_Describe(nil) ? [NSString stringWithFormat:@"%@",
            uiview_Outcome(^{ [view addInteraction:nil]; })] : @"");
    // re-adding one already held
    NSUInteger before = view.interactions.count;
    [view addInteraction:interaction];
    record(@"reAdd.count", [NSString stringWithFormat:@"%lu->%lu", (unsigned long)before,
            (unsigned long)view.interactions.count]);
    record(@"reAdd.moved", [interaction.moved componentsJoinedByString:@","]);

    // removing one the view does not hold
    record(@"remove.other", uiview_Outcome(^{ [view removeInteraction:[[InteractionProbe alloc] init]]; }));
    record(@"interactions.afterRemoveOther", uiview_Describe(view.interactions));
    record(@"remove.nil", uiview_Outcome(^{ [view removeInteraction:nil]; }));

    [view removeInteraction:interaction];
    record(@"interactions.afterRemove", uiview_Describe(view.interactions));
    record(@"interaction.movedAfterRemove", [interaction.moved componentsJoinedByString:@","]);

    record(@"setNil", uiview_Outcome(^{ view.interactions = nil; }));

    // an interaction held by another view is moved, not duplicated
    UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    InteractionProbe *moving = [[InteractionProbe alloc] init];
    [other addInteraction:moving];
    [view addInteraction:moving];
    record(@"moveFromOther.view", [NSString stringWithFormat:@"%lu", (unsigned long)other.interactions.count]);
    record(@"moveFromOther.other", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);
}
